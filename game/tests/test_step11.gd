extends SceneTree
## Real Godot 4.7.2 acceptance for support ordering and safe release.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_verify")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("STEP11 FAILED: " + message)

func _verify() -> void:
	var c := HMCatalog.new()
	check(c.load_all(), "Fixture catalog loads")
	var state: Dictionary = HMSaveState.fresh(c)
	var all: Array = state["world"]["parts"].keys()
	var posts: String = "fixture/shed/posts"
	var rail: String = "fixture/shed/upper_rail"
	var patch: String = "fixture/shed/roof_patch"
	check(HMSupportGraph.direct_dependents(c, posts, all) == [rail], "Posts directly support the rail")
	check(HMSupportGraph.cascade(c, posts, all)["dependent_ids"] == [patch, rail], "Transitive cascade is deterministic and complete")
	check(not HMSupportGraph.release_diagnostic(c, posts, all)["allowed_safe"], "Loaded posts are blocked")
	check(HMSupportGraph.release_diagnostic(c, posts, all)["reason"].contains(rail), "Warnings identify exact removable part")
	check(HMSupportGraph.release_diagnostic(c, patch, all)["allowed_safe"], "Topmost layer has no dependents")
	check(HMSupportGraph.direct_dependents(c, posts, [posts]) == [], "Cleared dependencies no longer block")
	check(HMRules.inspect_release(c, posts, all, ["claw_hammer"], [], false).get("at_risk", []) == [rail], "Safe rule delegates to authored graph")
	var description: Dictionary = HMInspectionRules.describe(c, posts, all, ["claw_hammer"], [], true, "claw_hammer", state["world"]["parts"])
	check(not description.get("read_only_actionable", true), "Blocked support cannot be worked")
	check(description.get("support_cascade", []).size() == 2, "Inspection shows all downstream components")
	check(description.get("details", "").contains(rail), "Detailed inspection contains ID of first removable part")
	check(HMSupportGraph.release_diagnostic(c, "fixture/harbour/bell", all)["reason"].contains("Protected"), "Protected component cannot be released")

	var packed: PackedScene = load("res://scenes/main.tscn")
	var app: Node = packed.instantiate()
	get_root().add_child(app)
	await process_frame
	app.call("show_stage")
	var player: HMFirstPerson = app.get("player") as HMFirstPerson
	var inspector: HMInspector = app.get("inspector") as HMInspector
	player.global_position = Vector3(-3.8, 0.96, 8.0)
	for i: int in range(5):
		await physics_frame
	check(inspector.probe().get("part_id", "") == rail, "Physical ray strikes authored support rail")
	check(inspector.probe().get("details", "").contains(patch), "Raycast inspection names first supported item even before tool discovery")
	check(not app.call("perform_release_once").get("ok", false), "R key cannot remove an unworked loaded support")
	app.call("show_menu")
	app.free()
	if failures.is_empty():
		print("HOLLOWMERE_STEP11_TEST_OK")
		quit(0)
	else:
		print("HOLLOWMERE_STEP11_TEST_FAIL count=", failures.size())
		quit(1)
