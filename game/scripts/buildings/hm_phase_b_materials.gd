class_name HMPhaseBMaterials
extends RefCounted
## V03 restrained neutral PBR overlays for authored faceted geometry.
## Vertex tint remains the source of hue; these textures only add low-frequency
## wear. No material table/save/catalogue changes and no runtime image synthesis.
const ROOT: String = "res://assets/materials/phase_b/"
const PROFILES: Array[String] = ["stone", "slate", "timber", "lime", "deck"]
static var _albedo_cache: Dictionary = {}
static var _rough_cache: Dictionary = {}

static func supports(profile: String) -> bool:
	return PROFILES.has(profile)

static func albedo(profile: String) -> Texture2D:
	if not supports(profile):
		return null
	if not _albedo_cache.has(profile):
		_albedo_cache[profile] = load(ROOT + profile + "_albedo.png") as Texture2D
	return _albedo_cache[profile] as Texture2D

static func roughness(profile: String) -> Texture2D:
	if not supports(profile):
		return null
	if not _rough_cache.has(profile):
		_rough_cache[profile] = load(ROOT + profile + "_roughness.png") as Texture2D
	return _rough_cache[profile] as Texture2D

static func make_tinted(profile: String, tint: Color, facets: bool = true) -> StandardMaterial3D:
	assert(supports(profile), "Phase B surface profile must be authored")
	var mat := StandardMaterial3D.new()
	mat.resource_name = "HMPB_" + profile
	mat.albedo_color = tint
	mat.albedo_texture = albedo(profile)
	mat.roughness = 1.0
	mat.roughness_texture = roughness(profile)
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.45,0.45,0.45)
	mat.vertex_color_use_as_albedo = facets
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED if facets else BaseMaterial3D.CULL_BACK
	return mat
