class_name HMFinaleChoice
extends StaticBody3D
## Protected physical choice. Targeted by the same first-hit inspect ray as tools.
@export var ending_id: String = ""
@export var display_name: String = ""

func is_valid() -> bool:
	return ["bell_delivery", "repair_escape"].has(ending_id)
