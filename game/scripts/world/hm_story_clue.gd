class_name HMStoryClue
extends StaticBody3D
## No automatic proximity trigger: E, line of sight, reach, act and duplicate gates.
@export var flag_id: String = ""
@export var minimum_act: int = 1
@export var event_kind: String = "discover"
@export var display_name: String = "Village evidence"
@export var evidence_text: String = ""

func is_valid(catalog: HMCatalog) -> bool:
	var row: Dictionary = catalog.by_id("story", "discoveries", flag_id)
	return not row.is_empty() and ["discover", "encounter"].has(event_kind) and minimum_act == int(row.get("minimum_act", 0))
