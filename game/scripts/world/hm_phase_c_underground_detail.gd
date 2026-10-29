class_name HMPhaseCUndergroundDetail
extends Node3D
## V10: protected underground atmospheric joinery, never salvage/collision.
## Sightlines and corridor physics remain owned by HMUndergroundSites.
var zones_dressed: int = 0

func build(protected: HMUndergroundSites) -> void:
    if zones_dressed > 0:
        return
    var zones: Dictionary = protected.locations
    for id: String in ["well_listening","mine_seal","undercroft","bell_house"]:
        if not zones.has(id):
            push_error("Missing protected Phase C zone: " + id)
            continue
        var position: Vector3 = zones[id]
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        if id == "well_listening":
            # Wall-edge stratification well above the listening footway.
            for side: float in [-1.0,1.0]:
                for i: int in range(4):
                    _box(st, position + Vector3(side*3.91,1.35,-4.4+float(i)*2.7),
                        Vector3(0.055,0.10,0.72+float(i%2)*0.17),Color("686a5f") * (0.82+float(i)*0.040))
            _box(st,position+Vector3(0,2.65,0),Vector3(6.8,0.16,0.27),Color("5c4c3b"))
        elif id == "mine_seal":
            # Timber and mineral seams occupy upper wall margins only;
            # inner seal and corridor remain physically and visually open.
            for i: int in range(4):
                var x: float = position.x - 24.0 + float(i)*6.6
                for side: float in [-1.0,1.0]:
                    _box(st,Vector3(x,8.53,position.z + side*2.32),
                        Vector3(0.12,1.25,0.055),Color("675541"))
                _box(st,Vector3(x,9.49,position.z),Vector3(0.2,0.15,3.9),Color("675541"))
        elif id == "undercroft":
            # No centre-span slab: keep the previously occluded player
            # camera clear and let the existing side wall define volume.
            for i: int in range(4):
                var z: float = position.z - 2.6 + float(i)*1.6
                for side: float in [-1.0,1.0]:
                    _box(st,Vector3(position.x + side*4.57,11.14,z),
                        Vector3(0.09,0.20,0.66),Color("736e63"))
        else:
            for x_side: float in [-3.35,3.35]:
                for z_side: float in [-3.35,3.35]:
                    _box(st,position+Vector3(x_side,4.78,z_side),
                        Vector3(0.27,0.08,0.29),
                        Color("777064").darkened(0.035 if x_side < 0.0 else 0.07))
        var art := MeshInstance3D.new()
        art.name = "PhaseCProtectedStrata_" + id
        art.mesh = st.commit()
        var finish := StandardMaterial3D.new()
        finish.vertex_color_use_as_albedo = true
        finish.roughness = 1.0
        art.material_override = finish
        add_child(art)
        zones_dressed += 1
    set_meta("protected_visuals_no_new_story_or_salvage",true)

static func _box(st: SurfaceTool, center: Vector3, dims: Vector3, tint: Color) -> void:
    HMPhaseCSurfaceDetail._box(st,center,dims,tint)
