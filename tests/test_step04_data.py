#!/usr/bin/env python3
"""Engine-independent schema, balance-invariant and ledger-fixture tests for Step 4.
Run: python -m unittest discover -s tests -p 'test_step04*.py' -v
Not a replacement for Godot GDScript compilation or native Windows testing.
"""
import copy
import csv
import json
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/'game/data/v1'
FAMILIES={'timber','stone','fired_clay','iron','copper_bronze','fibres','glass','mineral_fill'}
TIERS={'hands':1,'claw_hammer':2,'crowbar':3,'pickaxe':3,'saw':4}

def load():
 return {p.stem:json.loads(p.read_text()) for p in DATA.glob('*.json')}


def allocation_valid(a, allow_empty=False):
 return isinstance(a,dict) and (allow_empty or bool(a)) and all(k in FAMILIES and type(v)==int and v>0 for k,v in a.items())


def sums(outputs):
 output={}
 for row in outputs:
  for k,v in row['allocation'].items():output[k]=output.get(k,0)+v
 return output


def graph_issues(parts):
 by_id={p['id']:p for p in parts}
 issues=[]
 for p in parts:
  if p['id'] in p['supports']:issues.append('self link')
  for dep in p['supports']:
   if dep not in by_id:issues.append('missing '+dep)
   elif by_id[dep]['building_id']!=p['building_id']:issues.append('cross-building '+dep)
 def visit(key,visiting,visited):
  if key in visiting:return True
  if key in visited:return False
  visiting.add(key)
  for dep in by_id[key]['supports']:
   if dep in by_id and visit(dep,visiting,visited):return True
  visiting.remove(key);visited.add(key)
  return False
 seen=set()
 if any(visit(k,set(),seen) for k in by_id):issues.append('cycle')
 return issues

class Ledger:
 def __init__(self,d):
  self.d=d;self.registered={};self.sold={};self.credits=0;self.upgrade_levels={}
 def register(self,lot,on_pad):
  if not on_pad or lot.get('location')!='receiving_pad' or lot.get('protected',False) or lot['id'] in self.registered or not allocation_valid(lot['allocation']):return False
  part=next((x for x in self.d['sample_parts']['parts'] if x['id']==lot.get('source_part_id')),None)
  if part is None or part['protected'] or part['site_id']!=lot.get('site_id'):return False
  if not any(lot['id']==part['id']+'/out/'+o['suffix'] and lot['allocation']==o['allocation'] for o in part['outputs']):return False
  self.registered[lot['id']]=copy.deepcopy(lot)
  return True
 def units(self):return sum(sum(l['allocation'].values()) for l in self.registered.values())
 def price(self,lot):
  prices={x['id']:x['credits_per_unit'] for x in self.d['materials']['families']}
  value=sum(prices[k]*v for k,v in lot['allocation'].items())
  return (value*self.d['materials']['damaged_value_multiplier_percent'])//100 if lot['condition']=='damaged' else value
 def sell(self,lot_id):
  if lot_id not in self.registered or lot_id in self.sold:return False
  value=self.price(self.registered[lot_id]);self.sold[lot_id]=value;self.credits+=value;return True
 def buy(self,upgrade_id,owned):
  u=next((u for u in self.d['upgrades']['upgrades'] if u['id']==upgrade_id),None)
  if not u or u['applies_to'] not in ('player','cart') and u['applies_to'] not in owned:return False
  level=self.upgrade_levels.get(upgrade_id,0)
  if level>=len(u['levels']) or self.credits < u['levels'][level]['price']:return False
  self.credits-=u['levels'][level]['price'];self.upgrade_levels[upgrade_id]=level+1;return True

class Step04Tests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.d=load()
 def test_every_catalog_version(self):
  self.assertEqual(set(self.d),{'materials','tools','upgrades','requisitions','locations','story','sample_parts','landmark_parts','visual_reference_index','brinewick_step25_blockout','brinewick_district_builds','campaign_sites'})
  self.assertTrue(all(t['schema_version']==1 for t in self.d.values()))
  self.assertEqual(len(self.d['landmark_parts']['parts']),54)
  self.assertEqual(len(self.d['sample_parts']['parts']),297)
  self.assertEqual(len({p['id'] for p in self.d['sample_parts']['parts']+self.d['landmark_parts']['parts']}),351)
 def test_exact_eight_salvage_families_and_binary_condition(self):
  families=self.d['materials']['families'];self.assertEqual({m['id'] for m in families},FAMILIES)
  self.assertEqual(len(families),8);self.assertEqual(self.d['materials']['condition_states'],['intact','damaged'])
  self.assertTrue(all(m['credits_per_unit']>0 for m in families))
  self.assertIn(self.d['materials']['damaged_value_multiplier_percent'],range(101))
 def test_tool_permissions_and_discovery(self):
  tools=self.d['tools']['tools'];self.assertEqual({t['id']:t['tier'] for t in tools},TIERS)
  self.assertEqual(sum(t['discovery']=='innate' for t in tools),1)
  self.assertTrue(all(t['discovery']=='world' for t in tools if t['id']!='hands'))
  self.assertTrue(all(t['operations'] for t in tools))
  for t in tools:self.assertTrue(t['id']!='hands' or t['operations']==['collect_loose','lift_movable','inspect'])
  self.assertNotIn('loosen_masonry',next(t['operations'] for t in tools if t['id']=='crowbar'))
  self.assertNotIn('pry_substantial_timber',next(t['operations'] for t in tools if t['id']=='pickaxe'))
 def test_upgrade_effects_cannot_grant_capability(self):
  allowed=set(self.d['upgrades']['allowed_modifiers'])
  for u in self.d['upgrades']['upgrades']:
   self.assertIn(u['modifier'],allowed)
   self.assertNotIn('tier',u);self.assertNotIn('new_capabilities',u)
   self.assertTrue(u['levels']);self.assertTrue(all(x['price']>0 for x in u['levels']))
  self.assertEqual(len({u['id'] for u in self.d['upgrades']['upgrades']}),len(self.d['upgrades']['upgrades']))
 def test_site_and_story_flags(self):
  loc=self.d['locations']['sites'];self.assertEqual(len(loc),21)
  sites={s['id'] for s in loc};self.assertEqual(len(sites),21)
  discoveries=self.d['story']['discoveries'];self.assertEqual(len({s['id'] for s in discoveries}),len(discoveries))
  for e in discoveries:
   self.assertIn(e['location_id'],sites)
   self.assertIn(e['minimum_act'],range(1,5));self.assertTrue(e['one_time'])
  self.assertEqual({x['id'] for x in self.d['story']['ending_flags']},{'bell_delivery','repair_escape'})
  self.assertTrue(all(x['requires_explicit_choice'] for x in self.d['story']['ending_flags']))
 def test_four_non_live_requisitions_reference_known_flags(self):
  req=self.d['requisitions']['requisitions'];self.assertEqual({x['act'] for x in req},set(range(1,5)))
  flags={d['id'] for d in self.d['story']['discoveries']}
  for r in req:
   self.assertTrue(r['fixture_only']);self.assertGreater(r['min_registered_units'],0)
   self.assertGreater(r['min_distinct_sites'],0)
   self.assertTrue(set(r['requires_flags'])<=flags)
   self.assertTrue(set(r['required_tool_ids'])<=set(TIERS))
   self.assertTrue(set(r['families'])<=FAMILIES)
 def test_example_part_material_conservation(self):
  parts=self.d['sample_parts']['parts'];self.assertEqual(len({x['id'] for x in parts}),len(parts));self.assertGreaterEqual(len(parts),10)
  by_tool={x['id']:x for x in self.d['tools']['tools']};site_ids={x['id'] for x in self.d['locations']['sites']}
  for p in parts:
   self.assertIn(p['tool_id'],by_tool)
   self.assertIn(p['operation'],by_tool[p['tool_id']]['operations'])
   self.assertEqual(p['tier'],by_tool[p['tool_id']]['tier'])
   self.assertIn(p['site_id'],site_ids)
   self.assertTrue(allocation_valid(p['allocation'],allow_empty=True))
   self.assertEqual(p['allocation'],sums(p['outputs']),p['id'])
   self.assertEqual(len({o['suffix'] for o in p['outputs']}),len(p['outputs']))
   self.assertTrue(all(allocation_valid(o['allocation']) for o in p['outputs']))
  self.assertFalse(graph_issues(parts),graph_issues(parts))
 def test_mutated_schema_rejects_unsupported_graph(self):
  parts=copy.deepcopy(self.d['sample_parts']['parts']);parts[0]['supports'].append(parts[0]['id'])
  self.assertTrue(graph_issues(parts))
  parts=copy.deepcopy(self.d['sample_parts']['parts']);parts[1]['outputs'][0]['allocation']['timber']+=1
  self.assertNotEqual(parts[1]['allocation'],sums(parts[1]['outputs']))
 def test_early_complete_shed_and_heavy_frame_gating(self):
  parts=self.d['sample_parts']['parts'];shed=[p for p in parts if p['building_id']=='FIXTURE-SHED-A'];self.assertTrue(shed)
  self.assertTrue(all(p['tier']<=2 for p in shed))
  house={p['id']:p for p in parts};self.assertEqual(house['fixture/house/beam']['tier'],4)
  self.assertIn('fixture/house/slate_patch',house['fixture/house/beam']['supports'])
  self.assertTrue(house['fixture/harbour/bell']['protected'])
  self.assertTrue(house['fixture/mine/inner_seal']['protected'])
 def test_registered_then_sold_once_and_upgrade_independent(self):
  led=Ledger(self.d);p=next(p for p in self.d['sample_parts']['parts'] if p['id']=='fixture/shed/roof_patch')
  children=[{'id':p['id']+'/out/'+o['suffix'],'source_part_id':p['id'],'site_id':p['site_id'],'allocation':o['allocation'],'condition':'intact','location':'world_released'} for o in p['outputs']]
  self.assertFalse(led.register(children[0],True));self.assertEqual(led.units(),0)
  children[0]['location']='receiving_pad'
  forged={**children[0], 'allocation':{'timber':4000}}
  self.assertFalse(led.register(forged,True), 'Forged quantities must not be accepted')
  forged={**children[0], 'id':children[0]['id']+'-duplicate'}
  self.assertFalse(led.register(forged,True), 'Forged child identity must not be accepted')
  self.assertTrue(led.register(children[0],True))
  self.assertFalse(led.register(children[0],True));self.assertEqual(led.units(),4)
  self.assertTrue(led.sell(children[0]['id']));payout=led.credits
  self.assertFalse(led.sell(children[0]['id']));self.assertEqual(led.credits,payout)
  led.credits=30;self.assertTrue(led.buy('pack_straps',['hands']))
  self.assertEqual(led.units(),4);self.assertEqual(led.upgrade_levels['pack_straps'],1)
  self.assertFalse(led.buy('saw_teeth',['hands','claw_hammer']))
  c=children[0];damaged={**c,'condition':'damaged'}
  self.assertLess(led.price(damaged),led.price(c))
  self.assertEqual(sum(damaged['allocation'].values()),sum(c['allocation'].values()))
 def test_protected_cannot_register(self):
  led=Ledger(self.d);p={'id':'fixture/harbour/bell/out/bell','allocation':{'copper_bronze':15},'condition':'intact','location':'receiving_pad','protected':True}
  self.assertFalse(led.register(p,True));self.assertEqual(led.credits,0)
 def test_visual_register_proposals_not_spawned(self):
  v=self.d['visual_reference_index'];objects=v['object_archetypes'];buildings=v['proposed_buildings']
  self.assertEqual(len(objects),264);self.assertEqual(len({x['id'] for x in objects}),264)
  self.assertEqual(len(buildings),30);self.assertEqual(len({x['id'] for x in buildings}),30)
  self.assertEqual(v['kind'],'REFERENCE_ONLY_DO_NOT_INSTANTIATE')
  self.assertTrue(all(x['status'] in ('R','W') for x in objects))
  self.assertEqual(sum(x['status']=='R' for x in objects),96)
  self.assertEqual(sum(x['status']=='W' for x in objects),168)
  fixture_ids={x['building_id'] for x in self.d['sample_parts']['parts']}
  self.assertTrue(all(x.startswith(('FIXTURE-','BW-')) for x in fixture_ids))
  self.assertTrue(all(x['id'] not in fixture_ids for x in buildings))
 def test_no_missing_source_files_or_modified_bootstrap(self):
  for p in ['game/scripts/main.gd','game/scenes/main.tscn','game/project.godot']:
   self.assertTrue((ROOT/p).exists())
  self.assertIn('HOLLOWMERE_BOOT_OK', (ROOT/'game/scripts/main.gd').read_text())

if __name__=='__main__':unittest.main(verbosity=2)
