class_name HMCatalog
extends RefCounted
## Data-only Step 4 content, loaded from versioned JSON in res://data/v1/.
## No scene creation, passive salvage or save migration occurs here.

const ROOT: String = "res://data/v1/"
const FILES = [
	"materials", "tools", "upgrades", "requisitions", "locations",
	"story", "sample_parts", "visual_reference_index"
]

var tables: Dictionary = {}
var errors: PackedStringArray = []


func load_all() -> bool:
	tables.clear()
	errors.clear()
	for table_name: String in FILES:
		var path: String = ROOT + table_name + ".json"
		if not FileAccess.file_exists(path):
			errors.append("Missing data file: " + path)
			continue
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			errors.append("Unreadable data file: " + path)
			continue
		var json := JSON.new()
		var err: Error = json.parse(file.get_as_text())
		if err != OK or not (json.data is Dictionary):
			errors.append("Invalid JSON object: " + path + " / " + json.get_error_message())
			continue
		var parsed: Dictionary = json.data
		if int(parsed.get("schema_version", -1)) != 1:
			errors.append("Unsupported data version: " + path)
			continue
		tables[table_name] = parsed
	# Preserve existing table identity and save migration's append-only contract.
	# New real architecture is sourced from a single part definition asset.
	var authored_path: String = ROOT + "landmark_parts.json"
	if not FileAccess.file_exists(authored_path):
		errors.append("Missing authored building components " + authored_path)
	else:
		var authored: Variant = JSON.parse_string(FileAccess.get_file_as_string(authored_path))
		if not (authored is Dictionary) or int(authored.get("schema_version", -1)) != 1 \
				or not (authored.get("parts", null) is Array):
			errors.append("Invalid landmark part manifest")
		else:
			var seen: Dictionary = {}
			for existing: Variant in tables["sample_parts"]["parts"]:
				seen[String(existing.get("id", ""))] = true
			for part: Variant in authored["parts"]:
				if not (part is Dictionary):
					errors.append("Malformed landmark part")
					continue
				var id: String = String(part.get("id", ""))
				if id.is_empty() or seen.has(id):
					errors.append("Duplicate landmark part ID " + id)
					continue
				seen[id] = true
				tables["sample_parts"]["parts"].append(part)
	return errors.is_empty()


func entries(table_name: String, array_name: String) -> Array:
	if not tables.has(table_name):
		return []
	var data: Dictionary = tables[table_name]
	var result: Variant = data.get(array_name, [])
	if result is Array:
		return result
	return []


func by_id(table_name: String, array_name: String, object_id: String) -> Dictionary:
	for item: Variant in entries(table_name, array_name):
		if item is Dictionary and String(item.get("id", "")) == object_id:
			return item
	return {}


func by_part_id(object_id: String) -> Dictionary:
	return by_id("sample_parts", "parts", object_id)
