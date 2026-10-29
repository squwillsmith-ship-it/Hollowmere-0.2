class_name HMInspectTarget
extends StaticBody3D
## Stable authored catalogue identity attached to physical collider, never node path.
@export var part_id: String = ""

func is_catalogued(catalog: HMCatalog) -> bool:
	return not part_id.is_empty() and not catalog.by_part_id(part_id).is_empty()
