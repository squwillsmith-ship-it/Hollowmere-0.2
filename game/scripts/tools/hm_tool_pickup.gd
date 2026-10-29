class_name HMToolPickup
extends StaticBody3D
## A world discovery requires player input, an unobstructed ray and close range.
## This is a noncanonical engineering-yard test prop, not a final tool placement.
@export var tool_id: String = ""
@export var minimum_act: int = 1


func is_valid_discovery(catalog: HMCatalog) -> bool:
	var definition: Dictionary = catalog.by_id("tools", "tools", tool_id)
	return not definition.is_empty() and String(definition.get("discovery", "")) == "world"
