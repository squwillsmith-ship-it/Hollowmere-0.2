class_name HMRecoveredOutput
extends StaticBody3D
## A visible, blocked-by-physics, uncollected output of an authored part.
## Stable output ID and source provenance are stored in HMSaveState, not NodePaths.
@export var output_id: String = ""
@export var source_part_id: String = ""
