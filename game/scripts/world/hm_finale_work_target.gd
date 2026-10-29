class_name HMFinaleWorkTarget
extends StaticBody3D
## An actual reachable, first-hit world mechanism. E commits one manual step.
@export var action_id: String = ""
@export var display_name: String = ""

func is_valid() -> bool:
    return HMCampaignRules.TASKS.has(action_id)
