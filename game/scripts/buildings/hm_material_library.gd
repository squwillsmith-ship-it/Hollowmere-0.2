class_name HMMaterialLibrary
extends RefCounted
## Step21 shared production-study PBR textures for modular prefab geometry.
## All textures are ordinary source-colour / grayscale PNGs compatible with
## glTF 2.0 baseColor + metallicRoughness. No new salvage material or save IDs.

const ROOT: String = "res://assets/materials/step21/"
const MATERIALS: Array[String] = [
	"aged_timber", "weathered_timber", "dark_timber", "salt_grey_timber",
	"cream_infill", "patched_infill"]

static var _cache: Dictionary = {}

static func supports(material_key: String) -> bool:
	return MATERIALS.has(material_key)

static func get_shared(material_key: String) -> StandardMaterial3D:
	if not supports(material_key):
		return null
	if _cache.has(material_key):
		return _cache[material_key] as StandardMaterial3D
	var albedo: Texture2D = load(ROOT + material_key + "_albedo.png") as Texture2D
	var rough: Texture2D = load(ROOT + material_key + "_roughness.png") as Texture2D
	if albedo == null or rough == null:
		push_error("Step21 material images not imported: " + material_key)
		return null
	var material := StandardMaterial3D.new()
	material.resource_name = "HM21_" + material_key
	material.albedo_texture = albedo
	material.albedo_color = Color.WHITE
	material.metallic = 0.0
	material.roughness = 1.0
	material.roughness_texture = rough
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	_cache[material_key] = material
	return material