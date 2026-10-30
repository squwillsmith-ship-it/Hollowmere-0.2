class_name HMG3VillageSiteContext
extends Node3D
## G3 whole-village structural context, 21 stable site IDs. Every member is
## VISUAL ONLY / permanently non-salvageable retaining-stone, kerb or
## weather-worn outside framing. Not a replacement for the real building
## colliders, story actors, Godot-owned 345 salvage targets or future G4 art.
const STONE: Color = Color("777367")
const LIGHT_STONE: Color = Color("898477")
const OAK: Color = Color("675442")
const DARK: Color = Color("534a3f")
const HARBOUR: Color = Color("81796d")
var covered_site_ids: Dictionary = {}
var individual_members: int = 0
var district_totals: Dictionary = {}
const ZONES: Dictionary = {
    "brinewick/site_01":"waterfront", "brinewick/site_02":"waterfront",
    "brinewick/site_03":"waterfront", "brinewick/site_04":"waterfront",
    "brinewick/site_05":"waterfront", "brinewick/site_06":"waterfront",
    "brinewick/site_07":"waterfront", "brinewick/site_08":"waterfront",
    "brinewick/site_09":"civic", "brinewick/site_10":"civic",
    "brinewick/site_11":"civic", "brinewick/site_12":"upland",
    "brinewick/site_13":"headland", "brinewick/site_14":"headland",
    "brinewick/site_15":"civic", "brinewick/site_16":"headland",
    "brinewick/site_17":"headland", "brinewick/site_18":"headland",
    "brinewick/site_19":"headland", "brinewick/site_20":"waterfront",
    "brinewick/site_21":"waterfront"
}
func build(sites: Dictionary) -> void:
    if not covered_site_ids.is_empty():
        return
    var keys: Array = sites.keys()
    keys.sort()
    for value: Variant in keys:
        var id: String = String(value)
        if not ZONES.has(id):
            push_error("G3 unregistered or duplicate village site " + id)
            continue
        var site: Node3D = sites[id] as Node3D
        if site == null:
            push_error("G3 missing original site owner " + id)
            continue
        var group := Node3D.new()
        group.name = "G3NonSalvageSiteFootings"
        group.set_meta("g3_original_site_id",id)
        group.set_meta("g3_only_permanent_cosmetic",true)
        group.set_meta("g3_no_physical_collision",true)
        site.add_child(group)
        var number: int = int(id.get_file().trim_prefix("site_"))
        var kind: String = String(ZONES[id])
        _build_context(group,number,kind)
        covered_site_ids[id]=group
        district_totals[kind]=int(district_totals.get(kind,0))+1
    set_meta("g3_covered_original_sites",covered_site_ids.size())
    set_meta("g3_noncolliding_site_context",true)

func _build_context(parent: Node3D,site_no: int,zone: String) -> void:
    # Distinct fixed construction footprints, never scattered across the
    # centre where player hands, discovery records or manual haul routes run.
    var pattern: int = site_no % 4
    var contour: float = 5.8 if zone=="waterfront" else (
        6.7 if zone=="civic" else 8.4)
    # Site 13 and 18 have bigger existing architectural masses; the
    # details are OUTSIDE their footprint and do not block the doors.
    if site_no==13 or site_no==18:
        contour=10.0
    for side: int in [-1,1]:
        var x: float = float(side)*(contour+.31*(pattern%2))
        for i: int in range(3):
            var z: float = -3.6+float(i)*3.55
            var stagger: float = float((i+site_no)%3)*.11
            var base_h: float = .23+.06*float((i+site_no)%3)
            var p:=Vector3(x,base_h*.5,z+stagger)
            if zone=="headland":
                _stone(parent,p,Vector3(.84,base_h,1.45),
                    LIGHT_STONE if i%2==0 else STONE,site_no+i)
            elif zone=="civic" or zone=="upland":
                _stone(parent,p,Vector3(.78,base_h,1.24),
                    STONE if i%2==0 else HARBOUR,site_no+i)
            else:
                _stone(parent,p,Vector3(.59,base_h,1.46),
                    HARBOUR if i%2==0 else STONE,site_no+i)
    # A specific approach or structural signature for every site, outside
    # the main entry path; these are intentionally not new loot IDs.
    match site_no:
        1,2,20,21:
            _post(parent,Vector3(-4.8,.42,-4.25),
                Vector3(-4.8,1.42,-4.25),.22,OAK)
            _post(parent,Vector3(4.8,.40,-4.35),
                Vector3(4.8,1.36,-4.35),.21,DARK)
        3,4,5,6:
            _post(parent,Vector3(-4.9,.14,-4.5),
                Vector3(-4.9,1.45,-4.5),.13,OAK)
            _post(parent,Vector3(4.9,.14,-4.5),
                Vector3(4.9,1.37,-4.5),.15,DARK)
        7,8,10,12:
            _post(parent,Vector3(-4.7,.26,-4.65),
                Vector3(-4.7,1.37,-4.65),.16,OAK)
            _post(parent,Vector3(4.7,.26,-4.65),
                Vector3(4.7,1.21,-4.65),.14,OAK)
        9,11,15:
            _stone(parent,Vector3(-5.1,.27,-5.1),
                Vector3(1.28,.54,1.13),LIGHT_STONE,site_no+2)
            _stone(parent,Vector3(5.1,.23,-5.2),
                Vector3(1.16,.46,.98),STONE,site_no+3)
        13,14,16,17:
            _stone(parent,Vector3(-5.5,.46,-8.3),
                Vector3(1.32,.92,.92),STONE,site_no+4)
            _stone(parent,Vector3(5.5,.38,-8.5),
                Vector3(1.04,.76,1.12),LIGHT_STONE,site_no+6)
        18,19:
            # Mining approaches must remain open toward the east (mine),
            # so only north/south retaining piles are introduced.
            _stone(parent,Vector3(-4.2,.32,-8.25),
                Vector3(1.55,.64,1.05),STONE,site_no+3)
            _stone(parent,Vector3(-4.9,.29,8.15),
                Vector3(1.35,.58,1.12),LIGHT_STONE,site_no+1)

func _stone(parent: Node3D,at: Vector3,size: Vector3,
        color: Color,salt: int) -> void:
    var item := MeshInstance3D.new()
    item.name = "G3FittedRoughMasonry"
    var stone := CylinderMesh.new()
    stone.top_radius = maxf(size.x,size.z)*.49
    stone.bottom_radius = maxf(size.x,size.z)*.53
    stone.height = size.y
    stone.radial_segments = 7+salt%3
    stone.rings = 1
    item.mesh = stone
    item.scale = Vector3(size.x/maxf(size.x,size.z),1,
        size.z/maxf(size.x,size.z))
    item.rotation_degrees = Vector3(0,float((salt*29)%61),0)
    item.position=at
    var material := StandardMaterial3D.new()
    material.albedo_color = color * (.94+.015*float(salt%6))
    material.roughness = .98
    item.material_override=material
    item.set_meta("g3_noncolliding",true)
    parent.add_child(item)
    individual_members+=1

func _post(parent: Node3D,a: Vector3,b: Vector3,
        thickness: float,tint: Color) -> void:
    var item := MeshInstance3D.new()
    item.name="G3WeatheredEdgePost"
    var beam := BoxMesh.new()
    beam.size=Vector3(thickness,(b-a).length(),thickness*.82)
    item.mesh=beam
    item.position=(a+b)*.5
    item.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
    var finish := StandardMaterial3D.new()
    finish.albedo_color=tint
    finish.roughness=.98
    item.material_override=finish
    item.set_meta("g3_noncolliding",true)
    parent.add_child(item)
    individual_members+=1
