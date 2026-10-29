"""Step 5 Python reference checks of the persistence *contract*.

These tests do NOT execute/compile Godot GDScript. They validate the catalog,
transaction-state semantics, checksums, backup logic, and inspect that the Godot
source implements the matching API. Run native Godot test_step05.gd separately.
"""
from __future__ import annotations
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/'game'/'data'/'v1'
CAT={p.stem:json.loads(p.read_text()) for p in DATA.glob('*.json')}
PARTS={p['id']:p for p in CAT['sample_parts']['parts']}
SCRIPTS=ROOT/'game'/'scripts'/'save'


def canonical(data): return json.dumps(data,sort_keys=True,separators=(',',':'),ensure_ascii=False)
def fingerprint(): return hashlib.sha256(canonical(CAT).encode()).hexdigest()
def outputs_for(pid,quality):
    part=PARTS[pid]
    return {pid+'/out/'+child['suffix']:dict(id=pid+'/out/'+child['suffix'],source_part_id=pid,site_id=part['site_id'],allocation=copy.deepcopy(child['allocation']),condition=quality,location='world_released',protected=False,processed=False,position=[0.,0.,0.],carrier_id='') for child in part['outputs']}
def fresh():return dict(save_schema_version=1,data_schema_version=1,revision=0,world={'parts':{p:{'phase':'attached','work':0} for p in PARTS},'outputs':{},'carriers':{'player':{'position':[0.,0.,0.],'yaw':0.},'carts':{}}},economy={'schema_version':1,'credits':0,'registered':{},'sold':{},'upgrades':{}},progress={'act':1,'tools':['hands'],'discoveries':[],'encounters':[],'ending':'none','requisition_flags':[]},completed_transactions={})

def validate(state):
    if (state['revision']!=len(state['completed_transactions']) or not state['progress']['tools'] or state['economy']['credits']<0):return False
    all_o={}
    for pid,rec in state['world']['parts'].items():
        if pid not in PARTS or rec['phase'] not in ('attached','released') or rec['work']<0 or rec['work']>PARTS[pid]['work_units']:return False
        if rec['phase']=='released':
            if PARTS[pid]['protected']:return False
            all_o.update(outputs_for(pid,'intact'))
    if set(all_o)!=set(state['world']['outputs']):return False
    for oid,out in state['world']['outputs'].items():
        if out['allocation']!=all_o[oid]['allocation'] or out['source_part_id']!=all_o[oid]['source_part_id'] or out['condition'] not in ('intact','damaged'):return False
        if out['location'] in ('registered','sold') and oid not in state['economy']['registered']:return False
        if (oid in state['economy']['registered'])!=(out['location'] in ('registered','sold')):return False
        if (oid in state['economy']['sold'])!=(out['location']=='sold'):return False
        if out['location']=='carried' and out['carrier_id']!='player':return False
        if out['location'] not in ('carried','cart') and out['carrier_id']:return False
    sales=0
    for oid,payment in state['economy']['sold'].items():
        if oid not in state['economy']['registered'] or payment!=price(state['world']['outputs'][oid]):return False
        sales+=payment
    costs=0
    for upgrade_id,number in state['economy']['upgrades'].items():
        item=next((x for x in CAT['upgrades']['upgrades'] if x['id']==upgrade_id),None)
        if item is None or number>len(item['levels']):return False
        costs+=sum(level['price'] for level in item['levels'][:number])
    return state['economy']['credits']==sales-costs

def price(out):
    amounts={x['id']:x['credits_per_unit'] for x in CAT['materials']['families']}
    gross=sum(units*amounts[family] for family,units in out['allocation'].items())
    return gross if out['condition']=='intact' else gross*CAT['materials']['damaged_value_multiplier_percent']//100


def apply(state,txid,op,**arg):
    if txid in state['completed_transactions'] or not txid:raise ValueError('replay')
    out=copy.deepcopy(state)
    parts=out['world']['parts'];goods=out['world']['outputs'];economy=out['economy']
    pid=arg.get('pid','');oid=arg.get('oid','')
    if op=='work':
        p=PARTS[pid];assert parts[pid]['phase']=='attached' and p['tool_id'] in out['progress']['tools'];assert arg['cycles']>0
        parts[pid]['work']=min(p['work_units'],parts[pid]['work']+arg['cycles'])
    elif op=='release':
        p=PARTS[pid];assert not p['protected'] and parts[pid]['phase']=='attached' and parts[pid]['work']==p['work_units']
        assert not any(parts[k]['phase']=='attached' for k in p['supports'])
        parts[pid]['phase']='released';goods.update(outputs_for(pid,'intact'))
    elif op=='pickup':
        assert goods[oid]['location'] in ('world_released','staged');goods[oid]['location']='carried';goods[oid]['carrier_id']='player'
    elif op=='unload':
        assert goods[oid]['location']=='carried';assert arg.get('pad',False);goods[oid]['location']='receiving_pad';goods[oid]['carrier_id']=''
    elif op=='register':
        assert goods[oid]['location']=='receiving_pad' and oid not in economy['registered']
        economy['registered'][oid]=copy.deepcopy(goods[oid]);goods[oid]['location']='registered'
    elif op=='sale':
        assert goods[oid]['location']=='registered' and oid not in economy['sold']
        payment=price(goods[oid]);economy['sold'][oid]=payment;economy['credits']+=payment;goods[oid]['location']='sold'
    elif op=='purchase':
        u=next(x for x in CAT['upgrades']['upgrades'] if x['id']==arg['upgrade']);current=economy['upgrades'].get(u['id'],0)
        assert u['applies_to'] in ('player','cart') or u['applies_to'] in out['progress']['tools']
        cost=u['levels'][current]['price'];assert economy['credits']>=cost
        economy['credits']-=cost;economy['upgrades'][u['id']]=current+1
    else:raise ValueError(op)
    out['revision']+=1;out['completed_transactions'][txid]=out['revision']
    assert validate(out)
    return out

class ReferenceStore:
    def __init__(self,folder):self.root=folder;self.state=fresh();self.recovered=False
    def _file(self,name):return self.root/name
    def encode(self,s):
        data=canonical(s);return canonical(dict(format='hollowmere_save_v1',content_sha256=fingerprint(),payload_json=data,payload_sha256=hashlib.sha256(data.encode()).hexdigest()))
    def _read(self,name):
        try:
            w=json.loads(self._file(name).read_text());p=w['payload_json'];s=json.loads(p)
            if w['format']=='hollowmere_save_v1' and w['content_sha256']==fingerprint() and hashlib.sha256(p.encode()).hexdigest()==w['payload_sha256'] and validate(s):return s
        except (OSError,ValueError,KeyError,TypeError):pass
        return None
    def save(self,state):
        assert validate(state)
        temp=self._file('main.writing');temp.write_text(self.encode(state))
        assert self._read('main.writing')==state
        main=self._file('main');prev=self._file('main.previous')
        if main.exists():
            if self._read('main') is None:main.unlink()
            else:main.replace(prev)
        temp.replace(main);self.state=copy.deepcopy(state)
    def load(self):
        found=self._read('main')
        if found is None:found=self._read('main.previous');self.recovered=found is not None
        if found is None:raise ValueError('corrupt/absent')
        self.state=found
        return found


class TestStep05(unittest.TestCase):
    def make_worked_release(self):
        s=fresh();s['progress']['tools'].append('claw_hammer')
        s=apply(s,'work','work',pid='fixture/shed/roof_patch',cycles=2)
        return apply(s,'release','release',pid='fixture/shed/roof_patch')
    def test_01_v1_and_stable_part_ids(self):
        self.assertTrue(validate(fresh()));self.assertEqual(len(PARTS),len(set(PARTS)));self.assertEqual(set(fresh()['world']['parts']),set(PARTS))
    def test_02_no_premature_release(self):
        with self.assertRaises(AssertionError):apply(fresh(),'wrong','release',pid='fixture/shed/roof_patch')
    def test_03_released_parent_and_children(self):
        s=self.make_worked_release();self.assertEqual(s['world']['parts']['fixture/shed/roof_patch']['phase'],'released');self.assertEqual(len(s['world']['outputs']),2)
    def test_04_replay_transaction_id(self):
        s=self.make_worked_release()
        with self.assertRaises(ValueError):apply(s,'release','release',pid='fixture/shed/roof_patch')
    def test_05_no_remote_delivery(self):
        s=self.make_worked_release();oid='fixture/shed/roof_patch/out/boards'
        with self.assertRaises(AssertionError):apply(s,'r1','register',oid=oid)
    def test_06_manual_pickup_unload_register(self):
        s=self.make_worked_release();oid='fixture/shed/roof_patch/out/boards'
        s=apply(s,'p','pickup',oid=oid)
        with self.assertRaises(AssertionError):apply(s,'u','unload',oid=oid,pad=False)
        s=apply(s,'u','unload',oid=oid,pad=True);s=apply(s,'r','register',oid=oid)
        self.assertEqual(s['economy']['credits'],0);self.assertEqual(sum(s['economy']['registered'][oid]['allocation'].values()),4)
    def test_07_sale_once_and_credits(self):
        s=self.make_worked_release();oid='fixture/shed/roof_patch/out/boards'
        for op in ['pickup','unload','register','sale']:
            kw={'pad':True} if op=='unload' else {}
            s=apply(s,op,op,oid=oid,**kw)
        self.assertEqual(s['economy']['credits'],price(s['world']['outputs'][oid]));self.assertTrue(validate(s))
        with self.assertRaises(AssertionError):apply(s,'extra','sale',oid=oid)
    def test_08_damaged_quality_counts_same_units(self):
        self.assertLess(price({'allocation':{'timber':4},'condition':'damaged'}),price({'allocation':{'timber':4},'condition':'intact'}))
    def test_09_forged_child_rejected(self):
        s=self.make_worked_release();s['world']['outputs']['free_lumber']=copy.deepcopy(next(iter(s['world']['outputs'].values())))
        self.assertFalse(validate(s))
    def test_10_parent_child_impossibility(self):
        s=self.make_worked_release();s['world']['parts']['fixture/shed/roof_patch']['phase']='attached';self.assertFalse(validate(s))
    def test_11_disk_roundtrip(self):
        with tempfile.TemporaryDirectory() as t:
            st=ReferenceStore(Path(t));state=self.make_worked_release();st.save(state);self.assertEqual(ReferenceStore(Path(t)).load(),state)
    def test_12_backup_rotation(self):
        with tempfile.TemporaryDirectory() as t:
            st=ReferenceStore(Path(t));a=fresh();st.save(a);b=apply(a,'b','work',pid='fixture/shed/loose_rope',cycles=1);st.save(b)
            self.assertEqual(st._read('main.previous'),a);self.assertEqual(st._read('main'),b)
    def test_13_corrupt_primary_fallback(self):
        with tempfile.TemporaryDirectory() as t:
            st=ReferenceStore(Path(t));a=fresh();st.save(a);b=apply(a,'b','work',pid='fixture/shed/loose_rope',cycles=1);st.save(b)
            st._file('main').write_text('bad checksum');reader=ReferenceStore(Path(t))
            self.assertEqual(reader.load(),a);self.assertTrue(reader.recovered)
    def test_14_both_corrupt_refuses_reset(self):
        with tempfile.TemporaryDirectory() as t:
            st=ReferenceStore(Path(t));st._file('main').write_text('bad');st._file('main.previous').write_text('bad')
            with self.assertRaises(ValueError):st.load()
    def test_15_credit_math_detects_mutation(self):
        s=self.make_worked_release();s['economy']['credits']=100;self.assertFalse(validate(s))
    def test_16_code_state_api_exists(self):
        code='\n'.join(p.read_text() for p in SCRIPTS.glob('*.gd'))
        for token in ['class_name HMSaveState','class_name HMTransactions','class_name HMSaveStore','func open_slot','func commit','func _read_checked','func _write_snapshot','completed_transactions','payload_sha256','registered','receiving_pad','get("explicit_confirmation"']:
            self.assertIn(token,code)
    def test_17_no_old_tool_tier(self):
        code='\n'.join(p.read_text() for p in SCRIPTS.glob('*.gd'))
        self.assertNotIn('hatchet',code);self.assertNotIn('tier_five',code)
    def test_18_slot_name_and_engine_suite_available(self):
        code=(SCRIPTS/'hm_save_store.gd').read_text();self.assertIn('^[A-Za-z0-9_-]{1,40}$',code)
        self.assertTrue((ROOT/'game'/'tests'/'test_step05.gd').exists())

if __name__=='__main__':unittest.main()
