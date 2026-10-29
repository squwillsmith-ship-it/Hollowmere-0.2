extends Node
## Production Brinewick shares the original manually operated salvage UI, economy and saves.
## The engineering yard is retained only for explicit regression and scripted tests.

enum ViewState { TITLE, PLAYING, PAUSED }

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

var current_view: ViewState = ViewState.TITLE
var title_menu: ColorRect
var pause_menu: ColorRect
var controls_hint: Label
var stage: Node3D
var use_brinewick: bool = false
var force_brinewick_for_tests: bool = false
var player: HMFirstPerson
var open_button: Button
var resume_button: Button
var inspector: HMInspector
var reticle: Label
var inspection_panel: PanelContainer
var inspection_title: Label
var inspection_status: Label
var inspection_details: Label
var toolbelt: HMToolbelt
var tool_label: Label
var economy_label: Label
var feedback_label: Label
var interface_settings := HMInterfaceSettings.new()
var hud_canvas: CanvasLayer
var inventory_overlay: PanelContainer
var inventory_text: Label
var radial_overlay: PanelContainer
var radial_buttons: Array[Button] = []
var settings_overlay: PanelContainer
var control_bindings := HMControlBindings.new()
var binding_buttons: Dictionary = {}
var binding_capture_action: String = ""
var binding_help: Label
var action_feedback: HMActionFeedback
var tool_visual: HMToolViewModel
var feedback_age: float = 8.0
var reticle_feedback_time: float = 0.0
var ui_open: String = ""
var yard_service: HMYardService
var shop_index: int = 0
const SHOP_ITEMS: Array[String] = ["pack_straps", "walking_shoes", "hammer_grip",
	"crowbar_handle", "saw_teeth", "cart_bearings"]
var pending_find_tool: bool = false
var finale_armed_id: String = ""
var finale_armed_until_ms: int = 0
var finale_panel: ColorRect
var finale_text: Label
var epilogue_audio: AudioStreamPlayer
var evidence_overlay: PanelContainer
var evidence_text: Label
var bell_cargo: HMFinaleCargo
var lifecycle: HMPartLifecycle
var pending_release: bool = false
var pending_risky_release: bool = false
var risk_armed_part: String = ""
var risk_armed_until_ms: int = 0
const RISK_ARM_MS: int = 5000
var work_session: HMWorkSession
var work_ready: bool = false
var work_cooldown: float = 0.0
var work_focus: String = ""
var work_needs_release: bool = false
const WORK_INTERVAL: float = 0.42  # engineering value, not final balancing
const POSE_CHECKPOINT_SECONDS: float = 12.0
var pose_checkpoint_elapsed: float = 0.0
# Player-operated local sling handling aid, not a new tool tier or reward.
var rigged_component_id: String = ""


func _ready() -> void:
	interface_settings.load_local()
	use_brinewick = force_brinewick_for_tests or (not OS.get_cmdline_args().has("--script")
		and not OS.get_cmdline_user_args().has("--smoke-test")
		and not OS.get_cmdline_user_args().has("--engineering-yard"))
	_build_stage()
	tool_visual = HMToolViewModel.new()
	player.view_camera.add_child(tool_visual)
	control_bindings.load_local()
	if use_brinewick:
		assert(HMCoastalPresentation.apply(stage, interface_settings.clearer_fog))
	toolbelt = HMToolbelt.new()
	toolbelt.initialize(inspector.catalog)
	work_session = HMWorkSession.new()
	# --script runs are isolated acceptance tests, not player save sessions.
	var should_persist: bool = not OS.get_cmdline_args().has("--script") and not OS.get_cmdline_user_args().has("--smoke-test") and not OS.get_cmdline_user_args().has("--brinewick-smoke-test")
	work_ready = work_session.initialize(inspector.catalog, toolbelt, should_persist,
		"brinewick_world" if use_brinewick else "engineering_manual_work")
	# Old Step20 saves carry default origin but no actual pose checkpoint.
	if work_ready and work_session.has_checkpointed_player_pose():
		var player_pose: Dictionary = toolbelt.state["world"]["carriers"]["player"]
		if not player.restore_pose(player_pose):
			push_error("Saved player pose failed physical validation")
	yard_service = HMYardService.new()
	yard_service.initialize(toolbelt, work_session)
	if use_brinewick:
		var village: HMBrinewickBlockout = stage as HMBrinewickBlockout
		assert(village != null and village.district_sites != null)
		village.underground_audio.bind_player(player)
		assert(yard_service.configure_stations(village.district_sites.get_yard_station_positions()))
		yard_service.add_manual_sorting_bench(
			village.site_nodes["brinewick/site_11"].position + Vector3(1.8, 0.5, -0.6))
	if not work_ready:
		push_error("Unable to open player save: " + work_session.last_error)
	lifecycle = HMPartLifecycle.new()
	lifecycle.name = "PartLifecycle"
	stage.add_child(lifecycle)
	lifecycle.bind_stage(stage)
	lifecycle.reconcile(toolbelt.state)
	_sync_tool_context()
	_build_interface()
	_refresh_controls_hint()
	interface_settings.apply_audio()
	inspector.inspection_changed.connect(_on_inspection_changed)
	show_menu()
	print("HOLLOWMERE_BOOT_OK version=0.0.20-qa")
	if "--brinewick-smoke-test" in OS.get_cmdline_user_args():
		assert(use_brinewick and stage is HMBrinewickBlockout)
		assert(lifecycle.installed.size() >= 55)
		assert(yard_service.pad_center == (stage as HMBrinewickBlockout).district_sites.get_yard_station_positions()["pad"])
		show_stage()
		assert(current_view == ViewState.PLAYING and player.movement_enabled and inspector.enabled)
		show_menu()
		print("HOLLOWMERE_BRINEWICK_SMOKE_OK")
		get_tree().quit(0)
		return
	if "--smoke-test" in OS.get_cmdline_user_args():
		assert(stage != null and player != null and title_menu != null)
		show_stage()
		assert(current_view == ViewState.PLAYING and player.movement_enabled)
		pause_stage()
		assert(current_view == ViewState.PAUSED and not player.movement_enabled)
		resume_stage()
		assert(current_view == ViewState.PLAYING and player.movement_enabled)
		show_menu()
		assert(current_view == ViewState.TITLE and not player.movement_enabled)
		stage.free()
		print("HOLLOWMERE_SMOKE_OK")
		get_tree().quit(0)


func _physics_process(delta: float) -> void:
	if current_view == ViewState.PLAYING and work_ready:
		pose_checkpoint_elapsed += delta
		if pose_checkpoint_elapsed >= POSE_CHECKPOINT_SECONDS:
			pose_checkpoint_elapsed = 0.0
			_checkpoint_player_pose()
	if yard_service != null and work_ready and is_instance_valid(player):
		var hauling: bool = is_bell_being_hauled()
		player.carrying_load = hauling or not yard_service.holding_id().is_empty()
		player.loaded_speed_multiplier = (0.52 if hauling else HMUpgradeEffects.loaded_speed_multiplier(
				inspector.catalog, toolbelt.state["economy"]))
	if pending_release:
		pending_release = false
		var intent_risky: bool = pending_risky_release
		pending_risky_release = false
		if current_view == ViewState.PLAYING and not Input.is_action_pressed("hm_work"):
			if intent_risky:
				perform_risky_release_once()
			else:
				_disarm_risk()
				perform_release_once()
	if not risk_armed_part.is_empty() and (
		Time.get_ticks_msec() > risk_armed_until_ms or not Input.is_action_pressed("hm_risk_modifier")):
		_disarm_risk()
	if pending_find_tool:
		pending_find_tool = false
		if current_view == ViewState.PLAYING and work_ready:
			var pickup: HMToolPickup = inspector.aimed_tool_pickup()
			if pickup != null and int(toolbelt.state["progress"]["act"]) >= pickup.minimum_act 					and toolbelt.find_from_world(pickup.tool_id):
				pickup.queue_free()
				_sync_tool_context()
				_update_tool_label()
				_report_manual_feedback({"ok": true, "evidence": "New tool discovered through manual exploration"})
			else:
				var clue: HMStoryClue = inspector.aimed_story_clue()
				if clue != null:
					_after_yard_action(_story_clue_action(clue))
				else:
					var choice: HMFinaleChoice = inspector.aimed_finale_choice()
					if choice != null:
						_after_yard_action(manual_finale(choice))
					else:
						var mechanism: HMFinaleWorkTarget = inspector.aimed_finale_work_target()
						if mechanism != null:
							_after_yard_action(manual_finale_operation(mechanism))
						else:
							var rig: Dictionary = manual_rig_sling()
							if bool(rig.get("ok", false)):
								_report_manual_feedback(rig)
	if not work_ready or current_view != ViewState.PLAYING or not ui_open.is_empty() or (DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
		_reset_work_hold()
		return
	work_cooldown = maxf(0.0, work_cooldown - delta)
	if not Input.is_action_pressed("hm_work"):
		work_focus = ""
		work_needs_release = false
		return
	var info: Dictionary = inspector.probe()
	var target_id: String = String(info.get("part_id", ""))
	if target_id.is_empty():
		work_focus = ""
		work_needs_release = true
		return
	if work_focus != target_id:
		if work_needs_release:
			return
		work_focus = target_id
		work_needs_release = true
	if work_cooldown > 0.0:
		return
	var result: Dictionary = perform_work_once()
	if bool(result.get("ok", false)):
		work_cooldown = HMUpgradeEffects.work_interval(inspector.catalog,
				toolbelt.state["economy"], toolbelt.selected_tool_id, WORK_INTERVAL)
	else:
		work_cooldown = WORK_INTERVAL


func _reset_work_hold() -> void:
	work_focus = ""
	# A button carried through pause/focus loss must be released before work
	# can resume, preventing one unintended action on menu dismissal.
	work_needs_release = Input.is_action_pressed("hm_work")
	work_cooldown = 0.0


func perform_work_once() -> Dictionary:
	# Real single-shot test hook and manual work executor. No direct source ID
	# from a UI button is trusted: reacquire the first physical ray hit.
	if not work_ready or current_view != ViewState.PLAYING or not inspector.enabled:
		return {"ok": false, "reason": "Player not actively working"}
	if not yard_service.holding_id().is_empty() or is_bell_being_hauled():
		return {"ok": false, "reason": "Unload carried goods before ordinary dismantling"}
	var info: Dictionary = inspector.probe()
	if info.is_empty():
		return {"ok": false, "reason": "No clear target"}
	var result: Dictionary = work_session.work_once(info, true, inspector.access_aids, Input.is_action_pressed("hm_risk_modifier"))
	if bool(result.get("ok", false)):
		_sync_tool_context()
		inspector._publish(inspector.probe())
		if lifecycle != null:
			lifecycle.animate_work_impact(String(info.get("part_id", "")))
		_report_manual_feedback(result)
	return result


func _after_yard_action(result: Dictionary) -> Dictionary:
	if bool(result.get("ok", false)):
		_sync_finale_visuals()
		lifecycle.reconcile(toolbelt.state)
		_sync_tool_context()
		inspector._publish(inspector.probe())
	if feedback_label != null:
		feedback_label.text = String(result.get("evidence", "Done: " + String(result.get("operation", "")))) if bool(result.get("ok", false)) else String(result.get("reason", "Not available"))
		feedback_age = 0.0
	_report_manual_feedback(result, true)
	return result


func _report_manual_feedback(result: Dictionary, preserve_message: bool = false) -> void:
	if action_feedback != null:
		var material: String = "timber"
		var pid: String = String(result.get("part_id", work_focus))
		if not pid.is_empty() and inspector != null and inspector.catalog != null:
			var authored: Dictionary = inspector.catalog.by_part_id(pid)
			var allocation: Dictionary = authored.get("allocation", {})
			if not allocation.is_empty():
				material = String(allocation.keys()[0])
		action_feedback.notify(result, toolbelt.selected_tool_id, material)
	if tool_visual != null and current_view == ViewState.PLAYING:
		tool_visual.play_action(toolbelt.selected_tool_id, bool(result.get("ok", false)))
	reticle_feedback_time = 0.12 if bool(result.get("ok", false)) else 0.07
	if feedback_label != null:
		feedback_age = 0.0
		feedback_label.modulate.a = 1.0
		if not preserve_message:
			feedback_label.text = String(result.get("evidence", "Work completed")) if bool(result.get("ok", false)) else String(result.get("reason", "Action blocked"))


func manual_lift_or_place() -> Dictionary:
	if is_bell_being_hauled():
		return {"ok": false, "reason": "The hauled bell occupies both hands and the sledge"}
	if not work_ready or current_view != ViewState.PLAYING:
		return {"ok": false, "reason": "Only active gameplay may move salvage"}
	if yard_service.holding_id().is_empty():
		return _after_yard_action(yard_service.lift(inspector.probe()))
	var drop_location: Vector3 = player.global_position - player.view_camera.global_transform.basis.z * 1.35
	return _after_yard_action(yard_service.stage(drop_location))


func manual_unload() -> Dictionary:
	if not work_ready or current_view != ViewState.PLAYING:
		return {"ok": false}
	return _after_yard_action(yard_service.unload(player.global_position))


func manual_register() -> Dictionary:
	if not work_ready or current_view != ViewState.PLAYING:
		return {"ok": false}
	return _after_yard_action(yard_service.register_lot(player.global_position))


func manual_sell() -> Dictionary:
	if not work_ready or current_view != ViewState.PLAYING:
		return {"ok": false}
	return _after_yard_action(yard_service.sell_lot(player.global_position))


func manual_purchase() -> Dictionary:
	if not work_ready or current_view != ViewState.PLAYING:
		return {"ok": false}
	return _after_yard_action(yard_service.buy(player.global_position, SHOP_ITEMS[shop_index]))


func manual_rig_sling() -> Dictionary:
	# Manual E at the actual nearby first-hit beam. Re-rig after a cold load.
	if not work_ready or current_view != ViewState.PLAYING or not ui_open.is_empty():
		return {"ok": false, "reason": "Rigging requires active play"}
	var info: Dictionary = inspector.probe()
	var pid: String = String(info.get("part_id", ""))
	if pid.is_empty() or not bool(info.get("reachable", false)):
		return {"ok": false, "reason": "Aim directly at a nearby timber member"}
	var component: Dictionary = inspector.catalog.by_part_id(pid)
	if not component.get("requires_access_aids", []).has("sling"):
		return {"ok": false, "reason": "This part does not require a sling"}
	if String(toolbelt.state["world"]["parts"].get(pid, {}).get("phase", "")) != "attached":
		return {"ok": false, "reason": "Component already removed"}
	if rigged_component_id == pid:
		return {"ok": false, "reason": "Sling already attached"}
	# Preparation never creates goods, completes work, grants a tool or credits.
	rigged_component_id = pid
	inspector.access_aids = ["sling"]
	inspector._publish(inspector.probe())
	return {"ok": true, "evidence": "Sling manually secured; now work and release the supported beam"}


func _story_clue_action(clue: HMStoryClue) -> Dictionary:
	var progress: Dictionary = toolbelt.state["progress"]
	if inspector.story_flags.has(clue.flag_id):
		_show_evidence(clue)
		return {"ok": true, "operation": "read_evidence", "evidence": clue.evidence_text}
	if int(progress["act"]) < clue.minimum_act:
		return {"ok": false, "reason": "Evidence emerges in a later act"}
	var result: Dictionary = work_session.commit_player_progress({
		"op": clue.event_kind, "flag_id": clue.flag_id,
		"transaction_id": "manual_world_event:" + clue.flag_id, "user_initiated": true})
	if bool(result.get("ok", false)):
		result["evidence"] = clue.evidence_text
		_show_evidence(clue)
		if use_brinewick:
			(stage as HMBrinewickBlockout).underground_audio.emit_story_response(clue.flag_id)
	return result


func is_bell_being_hauled() -> bool:
	if toolbelt == null or toolbelt.state.is_empty():
		return false
	var actions: Array = toolbelt.state.get("progress", {}).get("finale_actions", [])
	return actions.has("bell_hitch") and not actions.has("bell_unload")


func _sync_finale_visuals() -> void:
	if not use_brinewick or toolbelt == null or toolbelt.state.is_empty():
		return
	if bell_cargo == null:
		bell_cargo = HMFinaleCargo.new()
		player.add_child(bell_cargo)
	var actions: Array = toolbelt.state["progress"].get("finale_actions", [])
	bell_cargo.visible = is_bell_being_hauled()
	var village: HMBrinewickBlockout = stage as HMBrinewickBlockout
	if village.campaign_sites != null:
		for action_id: String in village.campaign_sites.work_nodes:
			var target: HMFinaleWorkTarget = village.campaign_sites.work_nodes[action_id]
			var complete: bool = actions.has(action_id)
			target.set_meta("operation_completed", complete)
			# Keep used equipment visible as environmental storytelling.
			var mesh: MeshInstance3D = target.get_child(0) as MeshInstance3D
			if mesh != null:
				mesh.transparency = 0.45 if complete else 0.0
	if village.underground_sites != null:
		var original_bell: StaticBody3D = village.underground_sites.get_node_or_null(
			"UndercroftBellAndContainment/BellMount") as StaticBody3D
		if original_bell != null:
			original_bell.visible = not actions.has("bell_lower")
			original_bell.collision_layer = 0 if actions.has("bell_lower") else 1
		var cast_bell: MeshInstance3D = village.underground_sites.get_node_or_null(
			"UndercroftBellAndContainment/CastBellBody") as MeshInstance3D
		if cast_bell != null:
			cast_bell.visible = not actions.has("bell_hitch")
			cast_bell.position.y = (village.underground_sites.locations["bell_house"].y +
				(1.45 if actions.has("bell_lower") else 3.52))
		# Protected mechanical fixtures respond to completed player work.
		var facilities: Node3D = village.underground_sites.get_node_or_null(
			"ProtectedTidalMechanismAndEscape")
		if facilities != null:
			for component_id: String in ["TidalFloat", "SlidingStoneWeight"]:
				var part: Node3D = facilities.get_node_or_null(component_id) as Node3D
				if part != null:
					var done: bool = actions.has("float_reset") if component_id == "TidalFloat" else actions.has("weight_tension")
					part.set_meta("mechanically_restored",done)
		var at_pad: MeshInstance3D = village.get_node_or_null("ProtectedBellAtReceivingPad") as MeshInstance3D
		if at_pad == null:
			at_pad = MeshInstance3D.new()
			at_pad.name = "ProtectedBellAtReceivingPad"
			var model := CylinderMesh.new()
			model.top_radius = 0.54
			model.bottom_radius = 0.86
			model.height = 1.35
			model.radial_segments = 13
			at_pad.mesh = model
			var metal := StandardMaterial3D.new()
			metal.albedo_color = Color("74664a")
			metal.metallic = 0.65
			metal.roughness = 0.54
			at_pad.material_override = metal
			at_pad.position = Vector3(-20.2,2.82,15.7)
			village.add_child(at_pad)
		at_pad.visible = actions.has("bell_unload")


func _show_evidence(clue: HMStoryClue) -> void:
	if current_view != ViewState.PLAYING or clue == null:
		return
	evidence_text.text = clue.display_name.to_upper() + "\n\n" + clue.evidence_text
	_open_overlay("evidence")


func manual_finale_operation(target: HMFinaleWorkTarget) -> Dictionary:
	if not work_ready or not use_brinewick or current_view != ViewState.PLAYING:
		return {"ok": false, "reason": "Final work requires active gameplay"}
	if target == null or inspector.aimed_finale_work_target() != target:
		return {"ok": false, "reason": "Aim at the physical mechanism"}
	var id: String = target.action_id
	var reason: String = HMCampaignRules.work_blocker(toolbelt.state, id)
	if not reason.is_empty():
		return {"ok": false, "reason": reason}
	var task: Dictionary = HMCampaignRules.TASKS[id]
	if toolbelt.selected_tool_id != String(task["tool"]):
		return {"ok": false, "reason": "Equip " + String(task["tool"]) + " before working"}
	# Both finale routes alter protected village machinery. Explicitly warn
	# before the *first* operation irrevocably commits to that route;
	# document confirmation remains a separate final E+E decision.
	if id == "bell_clamps" or id == "float_reset":
		var pending: Array = toolbelt.state["progress"].get("finale_actions", [])
		if pending.is_empty():
			var start_key: String = "start:" + id
			var now: int = Time.get_ticks_msec()
			if finale_armed_id != start_key or now > finale_armed_until_ms:
				finale_armed_id = start_key
				finale_armed_until_ms = now + 8000
				return {"ok": false, "reason": "This begins a permanent " +
					("bell recovery" if id == "bell_clamps" else "containment repair") +
					" route. Press E again here within 8 seconds to proceed."}
			finale_armed_id = ""
	if id == "bell_hitch" and not yard_service.holding_id().is_empty():
		return {"ok": false, "reason": "Empty your pack before hauling the bell"}
	if id == "bell_unload":
		if not is_bell_being_hauled() or not HMSalvageLogistics.nearby(
				player.global_position, yard_service.pad_center, HMYardService.YARD_RADIUS):
			return {"ok": false, "reason": "Physically pull the loaded sledge to the boatyard receiving pad"}
	var result: Dictionary = work_session.commit_player_progress({
		"op": "finale_action", "action_id": id,
		"world_target_validated": true, "site_id": task["site"],
		"selected_tool_id": toolbelt.selected_tool_id,
		"transaction_id": "manual_finale_operation:" + id, "user_initiated": true})
	if bool(result.get("ok", false)):
		result["evidence"] = "Completed by hand: " + target.display_name
		if id == "cycle_test":
			(stage as HMBrinewickBlockout).underground_audio.emit_story_response("cycle_test")
	return result


func manual_finale(choice: HMFinaleChoice) -> Dictionary:
	# The first E reads the physical decision. A second E within eight seconds
	# is the irreversible confirmation; looking elsewhere cannot commit it.
	if not work_ready or current_view != ViewState.PLAYING or not use_brinewick:
		return {"ok": false, "reason": "Not in active Brinewick gameplay"}
	if choice == null or inspector.aimed_finale_choice() != choice:
		return {"ok": false, "reason": "Aim at the actual finale document"}
	var ending: String = choice.ending_id
	var blocker: String = HMCampaignRules.finale_blocker(toolbelt.state, ending)
	if not blocker.is_empty():
		return {"ok": false, "reason": blocker}
	var now: int = Time.get_ticks_msec()
	if finale_armed_id != ending or now > finale_armed_until_ms:
		finale_armed_id = ending
		finale_armed_until_ms = now + 8000
		return {"ok": false, "reason": "Press E again on this document within 8 seconds to confirm " + choice.display_name}
	finale_armed_id = ""
	var result: Dictionary = work_session.commit_player_progress({
		"op": "ending", "ending_id": ending, "explicit_confirmation": true,
		"finale_validated": true, "finale_site": HMCampaignRules.required_site(ending),
		"transaction_id": "manual_finale:" + ending, "user_initiated": true})
	if bool(result.get("ok", false)):
		_show_finale(ending)
	return result


func _show_finale(ending: String) -> void:
	_checkpoint_player_pose()
	if use_brinewick: (stage as HMBrinewickBlockout).underground_audio.set_active(false)
	current_view = ViewState.PAUSED
	player.enable_movement(false)
	inspector.set_enabled_inspection(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	finale_text.text = ("THE BELL IS TAKEN\n\nThe company receives its requested salvage and the bell. "
		+ "Marin's sentence is discharged. The signal that held the galleries quiet is gone. "
		+ "What might answer it remains unheard." if ending == "bell_delivery" else
		"THE SIGNAL HOLDS\n\nThe bell remains with the restored tidal mechanism. "
		+ "Marin leaves by the prepared secondary berth without company permission. "
		+ "The village grows quiet; Mara's fate remains unresolved.")
	finale_panel.show()
	if ending == "bell_delivery" and epilogue_audio != null:
		epilogue_audio.play()


func manual_requisition() -> Dictionary:
	if not work_ready or current_view != ViewState.PLAYING:
		return {"ok": false, "reason": "Only player actions can advance contract"}
	if not use_brinewick or not HMSalvageLogistics.nearby(player.global_position,
			yard_service.counter_center, HMYardService.YARD_RADIUS):
		return _after_yard_action({"ok": false, "reason": "Read company ledger at boatyard counter"})
	var progress: Dictionary = toolbelt.state["progress"]
	var act: int = int(progress["act"])
	var req_id: String = "req_act_0" + str(act)
	if progress["requisition_flags"].has(req_id):
		return _after_yard_action(work_session.commit_player_progress({
			"op": "advance_act", "transaction_id": "manual_advance_act:" + str(act), "user_initiated": true}))
	return _after_yard_action(work_session.commit_player_progress({
		"op": "requisition", "requisition_id": req_id, "user_initiated": true,
		"transaction_id": "manual_requisition:" + req_id}))


func manual_process() -> Dictionary:
	if not work_ready or current_view != ViewState.PLAYING:
		return {"ok": false}
	return _after_yard_action(yard_service.process_lot(inspector.probe(), player.global_position))


func _refresh_economy_hud() -> void:
	if economy_label == null:
		return
	var econ: Dictionary = toolbelt.state["economy"]
	var upgrade: String = SHOP_ITEMS[shop_index]
	var data: Dictionary = inspector.catalog.by_id("upgrades", "upgrades", upgrade)
	var level: int = int(econ["upgrades"].get(upgrade, 0))
	var levels: Array = data.get("levels", [])
	var price: String = "MAX" if level >= levels.size() else str(levels[level].get("price", 0)) + " credits"
	var carry: String = yard_service.holding_id()
	economy_label.text = "Credits: " + str(econ["credits"]) + " | Pack: " + ("empty" if carry.is_empty() else carry.get_file()) + " / " + str(HMSalvageLogistics.capacity(econ)) + " units" \
		+ "\nJ next: " + String(data.get("name", upgrade)) + " Lv" + str(level) + " (" + price + "), K buy at counter"


func _released_into_clear_space(info: Dictionary) -> Dictionary:
	# Let a loose lot settle on the player's side of the authored fixture
	# instead of spawning within its rack/face collider. Still local release.
	var adjusted: Dictionary = info.duplicate(true)
	var hit: Array = info.get("hit_position", [])
	if hit.size() == 3 and is_instance_valid(player):
		var point := Vector3(float(hit[0]), float(hit[1]), float(hit[2]))
		var offset: Vector3 = player.view_camera.global_position - point
		offset.y = 0.0
		if offset.length_squared() > 0.001:
			point += offset.normalized() * 0.85
		adjusted["hit_position"] = [point.x, maxf(0.26, point.y), point.z]
	return adjusted


func request_release() -> void:
	if current_view == ViewState.PLAYING:
		pending_release = true
		pending_risky_release = Input.is_action_pressed("hm_risk_modifier")


func perform_release_once() -> Dictionary:
	if not work_ready or current_view != ViewState.PLAYING or not inspector.enabled:
		return {"ok": false, "reason": "Release disabled outside play"}
	if not yard_service.holding_id().is_empty():
		return {"ok": false, "reason": "Place carried salvage before removing building parts"}
	var info: Dictionary = inspector.probe()
	if info.is_empty() or String(info.get("part_id", "")).is_empty():
		return {"ok": false, "reason": "Aim directly at a physical component"}
	var result: Dictionary = work_session.release_once(_released_into_clear_space(info), true, inspector.access_aids)
	if bool(result.get("ok", false)):
		_reset_work_hold()
		lifecycle.animate_release(String(info.get("part_id", "")))
		if rigged_component_id == String(info.get("part_id", "")):
			rigged_component_id = ""
			inspector.access_aids.clear()
		lifecycle.reconcile(toolbelt.state)
		_sync_tool_context()
		inspector._publish(inspector.probe())
	_report_manual_feedback(result)
	return result


func _disarm_risk() -> void:
	risk_armed_part = ""
	risk_armed_until_ms = 0


func perform_risky_release_once() -> Dictionary:
	# Two distinct G+R presses on the same freshly raycast authored part.
	# First press ONLY arms; second within five seconds may commit the bound
	# one-time transaction. An interruption or focus change invalidates arm.
	if not work_ready or current_view != ViewState.PLAYING or not inspector.enabled \
			or not yard_service.holding_id().is_empty() \
			or not Input.is_action_pressed("hm_risk_modifier"):
		_disarm_risk()
		return {"ok": false, "reason": "Risk requires deliberate G+R in play"}
	var info: Dictionary = inspector.probe()
	var pid: String = String(info.get("part_id", ""))
	if pid.is_empty() or not bool(info.get("reachable", false)):
		_disarm_risk()
		return {"ok": false, "reason": "No nearby physical support selected"}
	var active: Array = inspector.active_ids
	var risks: Dictionary = HMSupportGraph.release_diagnostic(inspector.catalog, pid, active)
	if risks.get("direct_ids", []).is_empty() or not risks.get("protected_ids", []).is_empty() \
			or bool(risks.get("truncated", false)):
		_disarm_risk()
		return {"ok": false, "reason": "No permitted limited local risk on this component"}
	var part: Dictionary = inspector.catalog.by_part_id(pid)
	var record: Dictionary = toolbelt.state["world"]["parts"].get(pid, {})
	if String(record.get("phase", "")) != "attached" \
			or int(record.get("work", -1)) != int(part.get("work_units", 0)):
		_disarm_risk()
		return {"ok": false, "reason": "Manually finish work before risky release"}
	if risk_armed_part != pid or Time.get_ticks_msec() > risk_armed_until_ms:
		risk_armed_part = pid
		risk_armed_until_ms = Time.get_ticks_msec() + RISK_ARM_MS
		return {"ok": false, "armed": true, "reason": "Release G+R, then press G+R again to confirm limited local damage"}
	_disarm_risk()
	var result: Dictionary = work_session.release_once(_released_into_clear_space(info), true, inspector.access_aids, true)
	if bool(result.get("ok", false)):
		_reset_work_hold()
		lifecycle.animate_release(String(info.get("part_id", "")))
		if rigged_component_id == String(info.get("part_id", "")):
			rigged_component_id = ""
			inspector.access_aids.clear()
		lifecycle.reconcile(toolbelt.state)
		_sync_tool_context()
		inspector._publish(inspector.probe())
	_report_manual_feedback(result)
	return result


func request_find_tool() -> void:
	# Input intent waits for the next physics frame before validating range/LOS.
	if current_view == ViewState.PLAYING:
		pending_find_tool = true


func _sync_tool_context() -> void:
	_refresh_economy_hud()
	inspector.owned_tools = toolbelt.owned_ids()
	inspector.current_act = int(toolbelt.state["progress"]["act"])
	inspector.story_flags = toolbelt.state["progress"]["discoveries"].duplicate() + toolbelt.state["progress"]["encounters"].duplicate()
	inspector.finale_actions = toolbelt.state["progress"].get("finale_actions", []).duplicate()
	inspector.selected_tool_id = toolbelt.selected_tool_id
	if tool_visual != null and tool_visual.equipped != toolbelt.selected_tool_id:
		tool_visual.select_tool(toolbelt.selected_tool_id)
	var scan: Array[Node] = [stage]
	while not scan.is_empty():
		var fixture: Node = scan.pop_back()
		if fixture is HMToolPickup and toolbelt.is_owned((fixture as HMToolPickup).tool_id):
			fixture.queue_free()
			continue
		for child: Node in fixture.get_children():
			scan.append(child)
	inspector.work_records = toolbelt.state["world"]["parts"].duplicate(true)
	inspector.output_records = toolbelt.state["world"]["outputs"].duplicate(true)
	inspector.active_ids.clear()
	for part_id: Variant in inspector.work_records:
		if String(inspector.work_records[part_id].get("phase", "")) == "attached":
			inspector.active_ids.append(String(part_id))
	_sync_finale_visuals()


func _update_tool_label() -> void:
	if tool_label != null:
		tool_label.text = "Equipped: " + toolbelt.tool_name() + "    Discovered: " + str(toolbelt.owned_ids().size()) + "/5" + "    " + control_bindings.display("hm_tool_next") + " cycle  /  equipped slots 1–5"


func _select_slot(slot: int) -> void:
	if toolbelt.select_slot(slot):
		_reset_work_hold()
		_disarm_risk()
		_sync_tool_context()
		_update_tool_label()


func _process(delta: float) -> void:
	if inspection_panel.visible:
		inspection_details.visible = Input.is_action_pressed("hm_inspect")
	if feedback_label != null and feedback_age < 5.0:
		feedback_age += delta
		feedback_label.modulate.a = clampf(1.0 - feedback_age / 4.0, 0.0, 1.0)
	if reticle != null:
		reticle_feedback_time = maxf(0.0, reticle_feedback_time - delta)
		reticle.scale = Vector2.ONE * (1.0 + 0.18 * reticle_feedback_time / 0.12)


func _input(event: InputEvent) -> void:
	# Capture before Godot's menu shortcuts; Esc always cancels remapping.
	if binding_capture_action.is_empty() or settings_overlay == null or not settings_overlay.visible:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		_cancel_binding_capture()
		get_viewport().set_input_as_handled()
		return
	var binding: String = HMControlBindings.binding_from_event(event)
	if binding.is_empty():
		return
	if control_bindings.change_binding(binding_capture_action, binding):
		control_bindings.save_local()
		var button: Button = binding_buttons[binding_capture_action]
		button.text = control_bindings.display(binding_capture_action)
		binding_help.text = "Saved locally. Escape remains reserved for menus."
		binding_capture_action = ""
		_refresh_controls_hint()
		_update_tool_label()
	else:
		binding_help.text = "Already assigned or invalid. Choose another key/button, or Esc to cancel."
	get_viewport().set_input_as_handled()


func _begin_rebind(action: String) -> void:
	if not HMControlBindings.LABELS.has(action):
		return
	_cancel_binding_capture()
	binding_capture_action = action
	binding_help.text = "Press a keyboard key or mouse button for: " + String(HMControlBindings.LABELS[action]) + " (Esc cancels)"
	(binding_buttons[action] as Button).text = "Press a key..."


func _cancel_binding_capture() -> void:
	if not binding_capture_action.is_empty() and binding_buttons.has(binding_capture_action):
		(binding_buttons[binding_capture_action] as Button).text = control_bindings.display(binding_capture_action)
	binding_capture_action = ""


func _hide_settings() -> void:
	_cancel_binding_capture()
	settings_overlay.hide()
	title_menu.process_mode = Node.PROCESS_MODE_INHERIT
	pause_menu.process_mode = Node.PROCESS_MODE_INHERIT
	if current_view == ViewState.TITLE:
		open_button.grab_focus()
	else:
		resume_button.grab_focus()


func _on_inspection_changed(info: Dictionary) -> void:
	inspection_panel.visible = current_view == ViewState.PLAYING and not info.is_empty()
	if info.is_empty():
		return
	inspection_title.text = String(info.get("title", ""))
	inspection_status.text = String(info.get("status", ""))
	var focused: String = String(info.get("part_id", ""))
	if not focused.is_empty() and inspector.catalog.by_part_id(focused).get(
			"requires_access_aids", []).has("sling"):
		inspection_status.text += (" | Sling rigged" if rigged_component_id == focused
			else " | " + control_bindings.display("hm_find_tool") + " to rig sling")
	if not risk_armed_part.is_empty() and String(info.get("part_id", "")) == risk_armed_part \
			and Time.get_ticks_msec() <= risk_armed_until_ms:
		inspection_status.text += " | G+R again to confirm local damage"
	inspection_details.text = String(info.get("details", ""))


func _unhandled_input(event: InputEvent) -> void:
	if settings_overlay != null and settings_overlay.visible:
		if event.is_action_pressed("ui_cancel") and not event.is_echo():
			_hide_settings()
			get_viewport().set_input_as_handled()
		return
	if not event.is_echo() and not ui_open.is_empty():
		if event.is_action_pressed("ui_cancel") or (ui_open == "inventory" and event.is_action_pressed("hm_inventory")) or (ui_open == "radial" and event.is_action_pressed("hm_tool_radial")):
			_close_overlay()
			get_viewport().set_input_as_handled()
		return
	if current_view == ViewState.PLAYING and not event.is_echo():
		if event.is_action_pressed("hm_inventory"):
			_open_overlay("inventory")
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("hm_tool_radial"):
			_open_overlay("radial")
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("hm_lift_place"):
			manual_lift_or_place()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("hm_unload"):
			manual_unload()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("hm_register"):
			manual_register()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("hm_sell"):
			manual_sell()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("hm_process"):
			manual_process()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("hm_shop_next"):
			shop_index = (shop_index + 1) % SHOP_ITEMS.size()
			_refresh_economy_hud()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("hm_requisition"):
			manual_requisition()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("hm_shop_buy"):
			manual_purchase()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("hm_release"):
			request_release()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("hm_find_tool"):
			request_find_tool()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("hm_tool_next"):
			_reset_work_hold()
			_disarm_risk()
			toolbelt.cycle()
			_sync_tool_context()
			_update_tool_label()
			get_viewport().set_input_as_handled()
			return
		for slot: int in range(1, 6):
			if event.is_action_pressed("hm_tool_" + str(slot)):
				_select_slot(slot)
				get_viewport().set_input_as_handled()
				return
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if current_view == ViewState.PLAYING:
			pause_stage()
		elif current_view == ViewState.PAUSED:
			resume_stage()
		get_viewport().set_input_as_handled()


func _checkpoint_player_pose() -> void:
	if not work_ready or current_view != ViewState.PLAYING or not is_instance_valid(player):
		return
	if not work_session.checkpoint_player_pose(player.read_pose()):
		push_warning("Player pose save failed: " + work_session.last_error)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_checkpoint_player_pose()


func show_menu() -> void:
	_checkpoint_player_pose()
	_close_overlay(false)
	current_view = ViewState.TITLE
	_reset_work_hold()
	_disarm_risk()
	player.enable_movement(false)
	if tool_visual != null: tool_visual.visible = false
	if use_brinewick: (stage as HMBrinewickBlockout).underground_audio.set_active(false)
	_cancel_binding_capture()
	pending_find_tool = false
	pending_release = false
	pending_risky_release = false
	inspector.set_enabled_inspection(false)
	stage.visible = false
	if use_brinewick: (stage as HMBrinewickBlockout).underground_audio.set_active(false)
	if finale_panel != null: finale_panel.hide()
	title_menu.show()
	pause_menu.hide()
	controls_hint.hide()
	tool_label.hide()
	if economy_label != null: economy_label.hide()
	if feedback_label != null: feedback_label.hide()
	reticle.hide()
	inspection_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	open_button.grab_focus()


func show_stage() -> void:
	_close_overlay(false)
	if not work_ready:
		return
	current_view = ViewState.PLAYING
	stage.visible = true
	if use_brinewick: (stage as HMBrinewickBlockout).underground_audio.set_active(true)
	if finale_panel != null: finale_panel.hide()
	title_menu.hide()
	pause_menu.hide()
	controls_hint.show()
	tool_label.show()
	economy_label.show()
	feedback_label.show()
	_refresh_economy_hud()
	player.enable_movement(true)
	if tool_visual != null: tool_visual.visible = true
	inspector.set_enabled_inspection(true)
	reticle.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# A completed historical or current save is an enduring ending, not an
	# opportunity to resume dismantling after the narrative concludes.
	var stored_ending: String = String(toolbelt.state["progress"].get("ending", "none"))
	if stored_ending != "none":
		_show_finale(stored_ending)


func pause_stage() -> void:
	_checkpoint_player_pose()
	_close_overlay(false)
	if current_view != ViewState.PLAYING:
		return
	current_view = ViewState.PAUSED
	_reset_work_hold()
	_disarm_risk()
	player.enable_movement(false)
	if tool_visual != null: tool_visual.visible = false
	pending_find_tool = false
	pending_release = false
	pending_risky_release = false
	inspector.set_enabled_inspection(false)
	if use_brinewick: (stage as HMBrinewickBlockout).underground_audio.set_active(false)
	tool_label.hide()
	economy_label.hide()
	feedback_label.hide()
	reticle.hide()
	inspection_panel.hide()
	pause_menu.show()
	controls_hint.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resume_button.grab_focus()


func resume_stage() -> void:
	_close_overlay(false)
	if current_view != ViewState.PAUSED:
		return
	current_view = ViewState.PLAYING
	pause_menu.hide()
	controls_hint.show()
	tool_label.show()
	economy_label.show()
	feedback_label.show()
	player.enable_movement(true)
	if tool_visual != null: tool_visual.visible = true
	if use_brinewick: (stage as HMBrinewickBlockout).underground_audio.set_active(true)
	inspector.set_enabled_inspection(true)
	reticle.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _solid_box(parent: Node3D, size: Vector3, at: Vector3, colour: Color, part_name: String, fixture_id: String = "") -> void:
	# Visible and collision geometry share the same transform, so there are
	# no invisible walls after we later replace this test fixture with assets.
	var obstacle: StaticBody3D
	if fixture_id.is_empty():
		obstacle = StaticBody3D.new()
	else:
		obstacle = HMInspectTarget.new()
		(obstacle as HMInspectTarget).part_id = fixture_id
	obstacle.name = part_name
	obstacle.position = at
	obstacle.collision_layer = 1
	obstacle.collision_mask = 2
	parent.add_child(obstacle)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.93
	mesh.material = material
	visual.mesh = mesh
	obstacle.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.name = "SolidCollision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	obstacle.add_child(collision)


func _tool_discovery_prop() -> void:
	# Noncanonical demonstration prop. Only explicit E + first-hit ray
	# may perform the Step05 find_tool transaction.
	var tool := HMToolPickup.new()
	tool.name = "HammerDiscoveryFixture"
	tool.tool_id = "claw_hammer"
	tool.position = Vector3(2.6, 1.38, 6.2)
	tool.collision_layer = 1
	tool.collision_mask = 2
	stage.add_child(tool)
	var shape := CollisionShape3D.new()
	shape.name = "SolidCollision"
	var prism := BoxShape3D.new()
	prism.size = Vector3(0.45, 0.42, 0.24)
	shape.shape = prism
	tool.add_child(shape)
	var visible := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = prism.size
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("8d7861")
	material.metallic = 0.15
	material.roughness = 0.78
	mesh.material = material
	visible.mesh = mesh
	tool.add_child(visible)


func _build_stage() -> void:
	if use_brinewick:
		var village := HMBrinewickBlockout.new()
		village.name = "PlayableBrinewick"
		village.spawn_exploration_player = false
		stage = village
		add_child(stage)
		player = PLAYER_SCENE.instantiate() as HMFirstPerson
		player.position = Vector3(-18, 3.05, 18)
		stage.add_child(player)
		inspector = HMInspector.new()
		inspector.name = "Inspector"
		player.add_child(inspector)
		assert(inspector.setup(player))
		return
	stage = Node3D.new()
	stage.name = "WalkableTestYard"
	add_child(stage)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("333e42")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b4c0bb")
	settings.ambient_light_energy = 0.5
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -35, 0)
	sun.light_color = Color("ffe1ac")
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	stage.add_child(sun)

	_solid_box(stage, Vector3(28.0, 0.4, 26.0), Vector3(0, -0.2, 0), Color("5e6253"), "SolidGround")
	# An unfinished open-sided timber shelter, just for walk-through and collision tests.
	for x: float in [-2.0, 2.0]:
		for z: float in [-2.0, 2.0]:
			_solid_box(stage, Vector3(0.28, 2.7, 0.28), Vector3(x, 1.35, z), Color("69513b"), "TimberPost", "fixture/shed/posts" if x == -2.0 and z == 2.0 else "")
	for z: float in [-2.0, 2.0]:
		_solid_box(stage, Vector3(4.3, 0.28, 0.28), Vector3(0, 2.65, z), Color("796047"), "RoofBeam")
	for x: float in [-2.0, 2.0]:
		_solid_box(stage, Vector3(0.28, 0.28, 4.3), Vector3(x, 2.65, 0), Color("796047"), "RoofBeam")
	for i: int in range(5):
		_solid_box(stage, Vector3(0.7, 0.12, 4.0), Vector3(-1.5 + i * 0.75, 2.92, 0), Color("88745b"), "RoofPlank")
	# Step20 six-part cottage prefab: same authored fixture IDs as the original
	# tested house schema, so existing saves and one-time transactions retain IDs.
	var cottage_data: Dictionary = HMBuildingPrefab.read_manifest("res://data/v1/buildings/cottage_working_01.json")
	var cottage: Node3D = HMBuildingPrefab.build(cottage_data, _cottage_catalog())
	assert(cottage != null, "Working cottage manifest must build")
	stage.add_child(cottage)
	# Close-range inspection rack; located beyond first two metres of Step06 walking tests.
	_solid_box(stage, Vector3(1.2, 0.15, 1.0), Vector3(0, 0.93, 4.7), Color("68503d"), "InspectionRack")
	for leg_x: float in [-0.45, 0.45]:
		_solid_box(stage, Vector3(0.12, 0.9, 0.12), Vector3(leg_x, 0.45, 4.7), Color("6d5743"), "RackLeg")
	_solid_box(stage, Vector3(0.45, 0.65, 0.42), Vector3(0, 1.3, 4.7), Color("8b8165"), "RopeSample", "fixture/shed/loose_rope")
	_solid_box(stage, Vector3(0.45, 0.7, 0.45), Vector3(4.0, 1.35, 5.0), Color("8b7450"), "ProtectedBellSample", "fixture/harbour/bell")
	# Two-unit hammer panel placed at hand height for Step09 repeated-work QA.
	# The high roof remains only geometry; do not duplicate authored part IDs.
	_solid_box(stage, Vector3(0.7, 0.65, 0.28), Vector3(-2.6, 1.35, 6.2),
		Color("88745b"), "WorkPanelSample", "fixture/shed/roof_patch")
	# Separate rail fixture shares catalogued support chain, without inventing a
	# canonical village footprint. Its dependency is the roof panel.
	_solid_box(stage, Vector3(0.74, 0.48, 0.28), Vector3(-3.8, 1.35, 6.2),
		Color("796047"), "SupportRailSample", "fixture/shed/upper_rail")
	_tool_discovery_prop()
	# Temporary physical pad, workbench and supply counter near the test entrance.
	_solid_box(stage, Vector3(2.4, 0.08, 2.2), Vector3(8.0, 0.04, 8.0),
		Color("777260"), "ManualReceivingPad")
	_solid_box(stage, Vector3(1.1, 0.5, 0.7), Vector3(6.3, 0.25, 8.0),
		Color("81644c"), "ManualSortingBench")
	_solid_box(stage, Vector3(0.7, 0.9, 1.4), Vector3(10.2, 0.45, 8.0),
		Color("766752"), "SupplyLedgerCounter")
	# A short obstacle circuit. Natural timber/stone colours avoid retired blue walls.
	_solid_box(stage, Vector3(2.0, 0.65, 1.5), Vector3(-5.0, 0.325, 1.0), Color("78705e"), "StoneObstacle")
	_solid_box(stage, Vector3(1.0, 1.0, 1.0), Vector3(5.0, 0.5, -3.5), Color("71553c"), "SupplyCrate")
	_solid_box(stage, Vector3(5.0, 1.6, 0.4), Vector3(5.8, 0.8, 2.5), Color("887d69"), "CollisionWall")
	for edge: float in [-13.8, 13.8]:
		_solid_box(stage, Vector3(0.35, 0.65, 26.0), Vector3(edge, 0.325, 0), Color("696458"), "BoundaryWall")
	for edge: float in [-12.8, 12.8]:
		_solid_box(stage, Vector3(28.0, 0.65, 0.35), Vector3(0, 0.325, edge), Color("696458"), "BoundaryWall")

	player = PLAYER_SCENE.instantiate() as HMFirstPerson
	player.position = Vector3(0, 0.96, 8.0)
	stage.add_child(player)
	inspector = HMInspector.new()
	inspector.name = "Inspector"
	player.add_child(inspector)
	var inspection_ready: bool = inspector.setup(player)
	assert(inspection_ready)


func _refresh_controls_hint() -> void:
	if controls_hint == null:
		return
	controls_hint.text = "Move " + control_bindings.display("hm_forward") + "/" + control_bindings.display("hm_left") + "/" + control_bindings.display("hm_backward") + "/" + control_bindings.display("hm_right") \
		+ " • Work " + control_bindings.display("hm_work") + " • Release " + control_bindings.display("hm_release") + " • Inspect " + control_bindings.display("hm_inspect") \
		+ " • Interact " + control_bindings.display("hm_find_tool") + " • Inventory " + control_bindings.display("hm_inventory") \
		+ "\nLift " + control_bindings.display("hm_lift_place") + " • Register " + control_bindings.display("hm_register") + " • Sell " + control_bindings.display("hm_sell") \
		+ " • Tool wheel " + control_bindings.display("hm_tool_radial") + " • Esc pause / Settings to rebind"


func _label(message: String, size: int) -> Label:
	var result := Label.new()
	result.text = message
	result.add_theme_font_size_override("font_size", roundi(float(size) * interface_settings.font_scale))
	result.set_meta("base_font_size", size)
	result.add_theme_color_override("font_color", Color.WHITE if interface_settings.high_contrast else Color("eee6d6"))
	return result


func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	hud_canvas = canvas
	add_child(canvas)
	title_menu = ColorRect.new()
	title_menu.color = Color(0.055, 0.075, 0.075, 0.97)
	title_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(title_menu)
	var layout := VBoxContainer.new()
	layout.position = Vector2(72, 100)
	layout.add_theme_constant_override("separation", 19)
	title_menu.add_child(layout)
	layout.add_child(_label("HOLLOWMERE", 52))
	layout.add_child(_label("Brinewick  /  first-person engineering build", 22))
	layout.add_child(_label("Death-row work order: recover the abandoned village for a sentence discharge.", 18))
	layout.add_child(_label("Playable Brinewick — integrated salvage work in progress" if use_brinewick else "Salvage recovery loop — engineering yard", 28))
	layout.add_child(_label("WASD move  •  I inventory  •  Tab tool radial  •  Hold mouse work  •  R safe release  •  G+R risky  •  F inspect  •  E find  •  Q/1–5 tools", 17))
	layout.add_child(_label("C carry/drop • U unload • N register • M sell • J/K shop • B submit/advance contract • H sort", 17))
	open_button = Button.new()
	open_button.text = "Enter Brinewick" if use_brinewick else "Enter walkable test yard"
	open_button.custom_minimum_size = Vector2(365, 52)
	open_button.pressed.connect(show_stage)
	layout.add_child(open_button)
	var title_settings := Button.new()
	title_settings.text = "Settings / rebind controls"
	title_settings.custom_minimum_size = Vector2(365, 42)
	title_settings.pressed.connect(_show_settings)
	layout.add_child(title_settings)
	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.custom_minimum_size.y = 45
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	layout.add_child(quit_button)

	pause_menu = ColorRect.new()
	pause_menu.color = Color(0.055, 0.075, 0.075, 0.93)
	pause_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(pause_menu)
	var paused_layout := VBoxContainer.new()
	paused_layout.position = Vector2(72, 110)
	paused_layout.add_theme_constant_override("separation", 20)
	pause_menu.add_child(paused_layout)
	paused_layout.add_child(_label("PAUSED", 46))
	resume_button = Button.new()
	resume_button.text = "Resume (Esc)"
	resume_button.custom_minimum_size = Vector2(325, 52)
	resume_button.pressed.connect(resume_stage)
	paused_layout.add_child(resume_button)
	var accessible := Button.new()
	accessible.text = "Settings / volume / rebind controls"
	accessible.pressed.connect(_show_settings)
	paused_layout.add_child(accessible)
	var back := Button.new()
	back.text = "Return to title"
	back.custom_minimum_size.y = 45
	back.pressed.connect(show_menu)
	paused_layout.add_child(back)

	controls_hint = _label("I inventory • Tab tool radial • WASD Move • Mouse work • R release • G+R risky • C carry/drop • U unload • N register • M sell\nH workbench sort • J/K shop • B contract/advance • E discover • Q/1–5 equip • F details • Esc pause", 15)
	controls_hint.position = Vector2(18, 18)
	controls_hint.custom_minimum_size.x = 1050
	controls_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas.add_child(controls_hint)
	tool_label = _label("", 18)
	tool_label.position = Vector2(18, 78)
	canvas.add_child(tool_label)
	_update_tool_label()
	economy_label = _label("", 16)
	economy_label.position = Vector2(18, 109)
	canvas.add_child(economy_label)
	feedback_label = _label("", 16)
	feedback_label.position = Vector2(18, 163)
	canvas.add_child(feedback_label)
	_refresh_economy_hud()

	reticle = _label("+", 22)
	reticle.anchor_left = 0.5
	reticle.anchor_right = 0.5
	reticle.anchor_top = 0.5
	reticle.anchor_bottom = 0.5
	reticle.offset_left = -8
	reticle.offset_top = -15
	reticle.offset_right = 12
	reticle.offset_bottom = 15
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(reticle)

	inspection_panel = PanelContainer.new()
	inspection_panel.anchor_left = 0.5
	inspection_panel.anchor_right = 0.5
	inspection_panel.anchor_top = 1.0
	inspection_panel.anchor_bottom = 1.0
	inspection_panel.offset_left = -260
	inspection_panel.offset_right = 260
	inspection_panel.offset_top = -185
	inspection_panel.offset_bottom = -25
	inspection_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(inspection_panel)
	var details_column := VBoxContainer.new()
	details_column.add_theme_constant_override("separation", 5)
	inspection_panel.add_child(details_column)
	inspection_title = _label("", 22)
	inspection_status = _label("", 16)
	inspection_details = _label("", 15)
	inspection_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspection_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspection_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_column.add_child(inspection_title)
	details_column.add_child(inspection_status)
	details_column.add_child(_label("Hold F for material and support details", 13))
	details_column.add_child(inspection_details)
	_build_step18_panels()
	# Readable evidence can be reopened after discovery; no automatic lore grants.
	evidence_overlay = PanelContainer.new()
	evidence_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	evidence_overlay.custom_minimum_size = Vector2(790,510)
	evidence_overlay.offset_left = -395
	evidence_overlay.offset_top = -255
	evidence_overlay.offset_right = 395
	evidence_overlay.offset_bottom = 255
	hud_canvas.add_child(evidence_overlay)
	var evidence_stack := VBoxContainer.new()
	evidence_stack.add_theme_constant_override("separation", 14)
	evidence_overlay.add_child(evidence_stack)
	evidence_stack.add_child(_label("FOUND IN BRINEWICK — EXAMINED EVIDENCE",20))
	var story_scroll := ScrollContainer.new()
	story_scroll.custom_minimum_size = Vector2(750,355)
	evidence_stack.add_child(story_scroll)
	evidence_text = _label("",20)
	evidence_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	evidence_text.custom_minimum_size = Vector2(720,0)
	story_scroll.add_child(evidence_text)
	var close_evidence := Button.new()
	close_evidence.text = "Fold and put away (Esc)"
	close_evidence.pressed.connect(_close_overlay)
	evidence_stack.add_child(close_evidence)
	evidence_overlay.hide()
	# One locked completion screen for each of the approved two outcomes.
	finale_panel = ColorRect.new()
	finale_panel.color = Color(0.045, 0.062, 0.063, 0.97)
	finale_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(finale_panel)
	var end_layout := VBoxContainer.new()
	end_layout.position = Vector2(72, 110)
	end_layout.custom_minimum_size = Vector2(880, 0)
	finale_panel.add_child(end_layout)
	finale_text = _label("", 26)
	finale_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_layout.add_child(finale_text)
	var return_button := Button.new()
	return_button.text = "Return to title"
	return_button.custom_minimum_size = Vector2(330, 55)
	return_button.pressed.connect(show_menu)
	end_layout.add_child(return_button)
	finale_panel.hide()
	epilogue_audio = AudioStreamPlayer.new()
	epilogue_audio.name = "UnseenDepartureSound"
	epilogue_audio.bus = "HM_Story" if use_brinewick else "Master"
	epilogue_audio.stream = HMUndergroundAudio._original_audio(9, false)
	epilogue_audio.volume_db = -8.0
	add_child(epilogue_audio)
	action_feedback = HMActionFeedback.new()
	action_feedback.name = "ManualActionSoundFeedback"
	add_child(action_feedback)


func _inventory_summary() -> String:
	# Read-only presentation of persisted physical lots; never changes state.
	var world: Dictionary = toolbelt.state.get("world", {})
	var outputs: Dictionary = world.get("outputs", {})
	var counts: Dictionary = {}
	for key: Variant in outputs:
		var lot: Dictionary = outputs[key]
		var location: String = String(lot.get("location", "unknown"))
		counts[location] = int(counts.get(location, 0)) + 1
	var lines: Array[String] = ["Carrying: " + ("none" if yard_service.holding_id().is_empty() else yard_service.holding_id()),
		"Pack capacity: " + str(HMSalvageLogistics.capacity(toolbelt.state["economy"])) + " units",
		"Recovered physical lots:"]
	for loc: String in ["world_released", "staged", "carried", "receiving_pad", "registered", "sold"]:
		lines.append("  " + loc.replace("_", " ") + ": " + str(counts.get(loc, 0)))
	lines.append("Tools found: " + ", ".join(toolbelt.available_ids()))
	lines.append("This screen does not pick up, register, sell or sort materials.")
	lines.append("\n" + HMContractLedger.summary(inspector.catalog, toolbelt.state))
	return "\n".join(lines)


func _open_overlay(which: String) -> void:
	if current_view != ViewState.PLAYING or not ui_open.is_empty():
		return
	_reset_work_hold()
	_disarm_risk()
	ui_open = which
	if tool_visual != null: tool_visual.visible = false
	player.enable_movement(false)
	inspector.set_enabled_inspection(false)
	reticle.hide()
	inspection_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if which == "evidence":
		evidence_overlay.show()
	elif which == "inventory":
		inventory_text.text = _inventory_summary()
		inventory_overlay.show()
	elif which == "radial":
		var options: Array = inspector.catalog.entries("tools", "tools")
		for i: int in range(radial_buttons.size()):
			var id: String = String(options[i]["id"])
			radial_buttons[i].disabled = not toolbelt.is_owned(id)
			radial_buttons[i].text = toolbelt.tool_name(id) + ("  [not found]" if radial_buttons[i].disabled else "")
		radial_overlay.show()


func _close_overlay(restore: bool = true) -> void:
	ui_open = ""
	if evidence_overlay != null: evidence_overlay.hide()
	if inventory_overlay != null: inventory_overlay.hide()
	if radial_overlay != null: radial_overlay.hide()
	_cancel_binding_capture()
	if settings_overlay != null: settings_overlay.hide()
	if title_menu != null: title_menu.process_mode = Node.PROCESS_MODE_INHERIT
	if pause_menu != null: pause_menu.process_mode = Node.PROCESS_MODE_INHERIT
	if restore and current_view == ViewState.PLAYING and is_instance_valid(player):
		player.enable_movement(true)
		if tool_visual != null: tool_visual.visible = true
		inspector.set_enabled_inspection(true)
		reticle.show()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _choose_radial(id: String) -> void:
	if ui_open != "radial" or not toolbelt.is_owned(id):
		return
	if toolbelt.select_tool(id):
		_reset_work_hold()
		_disarm_risk()
		_sync_tool_context()
		_update_tool_label()
	_close_overlay()


func _apply_ui_preferences(root: Node) -> void:
	if root is Label and root.has_meta("base_font_size"):
		var label: Label = root as Label
		label.add_theme_font_size_override("font_size", roundi(float(root.get_meta("base_font_size")) * interface_settings.font_scale))
		label.add_theme_color_override("font_color", Color.WHITE if interface_settings.high_contrast else Color("eee6d6"))
	for child: Node in root.get_children():
		_apply_ui_preferences(child)
	player.mouse_sensitivity = interface_settings.mouse_sensitivity


func _set_audio_preference(level: float, field: String) -> void:
	interface_settings.set(field, level)
	interface_settings.save_local()
	interface_settings.apply_audio()


func _show_settings() -> void:
	if current_view != ViewState.PAUSED and current_view != ViewState.TITLE:
		return
	settings_overlay.show()
	if current_view == ViewState.PAUSED:
		pause_menu.process_mode = Node.PROCESS_MODE_DISABLED
		resume_button.release_focus()
	else:
		title_menu.process_mode = Node.PROCESS_MODE_DISABLED
		open_button.release_focus()
	if binding_buttons.has("hm_forward"):
		(binding_buttons["hm_forward"] as Button).grab_focus()


func _build_step18_panels() -> void:
	inventory_overlay = PanelContainer.new()
	inventory_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	inventory_overlay.custom_minimum_size = Vector2(830, 620)
	inventory_overlay.offset_left = -415
	inventory_overlay.offset_top = -310
	inventory_overlay.offset_right = 415
	inventory_overlay.offset_bottom = 310
	hud_canvas.add_child(inventory_overlay)
	var inventory_col := VBoxContainer.new()
	inventory_overlay.add_child(inventory_col)
	inventory_col.add_child(_label("INVENTORY / PHYSICAL SALVAGE (I closes)", 23))
	inventory_text = _label("", 16)
	inventory_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_col.add_child(inventory_text)
	inventory_overlay.hide()

	radial_overlay = PanelContainer.new()
	radial_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	radial_overlay.custom_minimum_size = Vector2(610, 500)
	radial_overlay.offset_left = -305
	radial_overlay.offset_top = -250
	radial_overlay.offset_right = 305
	radial_overlay.offset_bottom = 250
	hud_canvas.add_child(radial_overlay)
	var center := Control.new()
	center.custom_minimum_size = Vector2(610, 500)
	radial_overlay.add_child(center)
	var heading := _label("TOOLS — discovered only (Tab closes)", 23)
	heading.position = Vector2(85, 24)
	center.add_child(heading)
	var definitions: Array = inspector.catalog.entries("tools", "tools")
	for i: int in range(definitions.size()):
		var row: Dictionary = definitions[i]
		var id: String = String(row["id"])
		var angle: float = float(i) / float(definitions.size()) * TAU - PI / 2.0
		var button := Button.new()
		button.custom_minimum_size = Vector2(165, 55)
		button.position = Vector2(220 + cos(angle) * 165, 235 + sin(angle) * 148)
		button.text = toolbelt.tool_name(id)
		button.pressed.connect(_choose_radial.bind(id))
		center.add_child(button)
		radial_buttons.append(button)
	radial_overlay.hide()

	settings_overlay = PanelContainer.new()
	settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	settings_overlay.custom_minimum_size = Vector2(870, 630)
	settings_overlay.offset_left = -435
	settings_overlay.offset_top = -315
	settings_overlay.offset_right = 435
	settings_overlay.offset_bottom = 315
	hud_canvas.add_child(settings_overlay)
	var settings_scroll := ScrollContainer.new()
	settings_scroll.custom_minimum_size = Vector2(815, 590)
	settings_overlay.add_child(settings_scroll)
	var settings_col := VBoxContainer.new()
	settings_col.custom_minimum_size.x = 795
	settings_col.add_theme_constant_override("separation", 8)
	settings_scroll.add_child(settings_col)
	settings_col.add_child(_label("SETTINGS — LOCAL ONLY", 24))
	var font_row := HBoxContainer.new()
	font_row.add_child(_label("Text size", 17))
	var fonts := OptionButton.new()
	for size: float in HMInterfaceSettings.FONT_SCALES:
		fonts.add_item(str(roundi(size * 100.0)) + "%")
	fonts.select(HMInterfaceSettings.FONT_SCALES.find(interface_settings.font_scale))
	fonts.item_selected.connect(func(index: int) -> void:
		interface_settings.font_scale = HMInterfaceSettings.FONT_SCALES[index]
		interface_settings.save_local()
		_apply_ui_preferences(hud_canvas))
	font_row.add_child(fonts)
	settings_col.add_child(font_row)
	var contrast := CheckButton.new()
	contrast.text = "Higher text contrast"
	contrast.button_pressed = interface_settings.high_contrast
	contrast.toggled.connect(func(on: bool) -> void:
		interface_settings.high_contrast = on
		interface_settings.save_local()
		_apply_ui_preferences(hud_canvas))
	settings_col.add_child(contrast)
	var fog := CheckButton.new()
	fog.text = "Reduce distance fog for readability"
	fog.button_pressed = interface_settings.clearer_fog
	fog.toggled.connect(func(on: bool) -> void:
		interface_settings.clearer_fog = on
		interface_settings.save_local()
		if use_brinewick:
			HMCoastalPresentation.apply(stage, on))
	settings_col.add_child(fog)
	settings_col.add_child(_label("Mouse sensitivity", 16))
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.0008
	sensitivity.max_value = 0.004
	sensitivity.step = 0.0001
	sensitivity.custom_minimum_size.x = 350
	sensitivity.value = interface_settings.mouse_sensitivity
	sensitivity.value_changed.connect(func(value: float) -> void:
		interface_settings.mouse_sensitivity = value
		interface_settings.save_local()
		_apply_ui_preferences(hud_canvas))
	settings_col.add_child(sensitivity)
	for field: String in ["master_volume", "ambience_volume", "feedback_volume"]:
		var volume_row := HBoxContainer.new()
		var volume_label := _label(field.replace("_", " ").capitalize(), 16)
		volume_label.custom_minimum_size.x = 180
		volume_row.add_child(volume_label)
		var volume := HSlider.new()
		volume.min_value = 0.0
		volume.max_value = 1.0
		volume.step = 0.05
		volume.custom_minimum_size.x = 340
		volume.value = float(interface_settings.get(field))
		volume.value_changed.connect(_set_audio_preference.bind(field))
		volume_row.add_child(volume)
		settings_col.add_child(volume_row)
	settings_col.add_child(_label("KEYBOARD / MOUSE — select a binding below", 18))
	binding_help = _label("Escape always opens/closes menus; duplicate bindings are rejected.", 14)
	settings_col.add_child(binding_help)
	var bindings_scroll := ScrollContainer.new()
	bindings_scroll.custom_minimum_size = Vector2(810, 205)
	settings_col.add_child(bindings_scroll)
	var mapping := VBoxContainer.new()
	mapping.add_theme_constant_override("separation", 3)
	bindings_scroll.add_child(mapping)
	for action: String in HMControlBindings.LABELS:
		var row := HBoxContainer.new()
		var caption := _label(String(HMControlBindings.LABELS[action]), 16)
		caption.custom_minimum_size.x = 340
		row.add_child(caption)
		var bind_button := Button.new()
		bind_button.custom_minimum_size = Vector2(240, 30)
		bind_button.text = control_bindings.display(action)
		bind_button.pressed.connect(_begin_rebind.bind(action))
		binding_buttons[action] = bind_button
		row.add_child(bind_button)
		mapping.add_child(row)
	var settings_footer := HBoxContainer.new()
	var reset_button := Button.new()
	reset_button.text = "Restore default bindings"
	reset_button.pressed.connect(func() -> void:
		_cancel_binding_capture()
		control_bindings.restore_defaults()
		for action: String in binding_buttons:
			(binding_buttons[action] as Button).text = control_bindings.display(action)
		_refresh_controls_hint()
		_update_tool_label()
		binding_help.text = "Default bindings restored and saved.")
	settings_footer.add_child(reset_button)
	var back_button := Button.new()
	back_button.text = "Back (Esc)"
	back_button.pressed.connect(_hide_settings)
	settings_footer.add_child(back_button)
	settings_col.add_child(settings_footer)
	settings_overlay.hide()
	_apply_ui_preferences(hud_canvas)


func _cottage_catalog() -> HMCatalog:
	var result := HMCatalog.new()
	assert(result.load_all())
	return result
