extends SceneTree
## Transaction-level full four-act economic campaign simulation (not a GUI
## player-playthrough). Uses actual catalogue-backed manual work, physical-lot
## lifecycle events, one-time evidence flags and both real finale sequences.
var catalog: HMCatalog
var state: Dictionary
var serial: int = 0
var problems: Array[String] = []

func ensure(ok: bool, label: String) -> void:
    if not ok:
        problems.append(label)
        push_error("FOUR ACTS: " + label)

func action(event: Dictionary) -> Dictionary:
    serial += 1
    event["transaction_id"] = "campaign_explicit_" + str(serial)
    event["user_initiated"] = true
    var outcome: Dictionary = HMTransactions.apply(catalog, state, event)
    if bool(outcome.get("ok", false)):
        state = outcome["state"]
    return outcome

func _initialize() -> void:
    call_deferred("_run")

func _find_tool(id: String) -> void:
    ensure(bool(action({"op":"find_tool","tool_id":id,"source":"world_discovery"}).get("ok",false)),
        "Deliberate tool discovery " + id)

func _evidence(id: String) -> void:
    var row: Dictionary = catalog.by_id("story","discoveries",id)
    var kind: String = "encounter" if String(row.get("kind", "")) == "one_time_encounter" else "discover"
    ensure(bool(action({"op":kind,"flag_id":id}).get("ok",false)),
        "One-time manually inspected story " + id)

func _recovered_units() -> int:
    var count: int = 0
    for lot: Variant in state["economy"]["registered"].values():
        for amount: Variant in lot.get("allocation",{}).values():
            count += int(amount)
    return count

func _collect_until(req_id: String) -> void:
    var req: Dictionary = catalog.by_id("requisitions","requisitions",req_id)
    var defs: Array = catalog.entries("sample_parts","parts")
    for row: Variant in defs:
        if HMRules.requisition_met(catalog,req_id,state["economy"],
                state["progress"]["tools"],state["progress"]["discoveries"]+state["progress"]["encounters"]):
            return
        var def: Dictionary = row
        var pid: String = String(def["id"])
        if bool(def.get("protected",false)) or String(state["world"]["parts"][pid]["phase"]) != "attached":
            continue
        var aids: Array = []
        var owned: Array = state["progress"]["tools"]
        if not HMRules.can_use(catalog,pid,owned):
            continue
        var active: Array = []
        for id: Variant in state["world"]["parts"]:
            if String(state["world"]["parts"][id]["phase"]) == "attached":
                active.append(String(id))
        var release: Dictionary = HMRules.inspect_release(catalog,pid,active,owned,aids)
        if not bool(release.get("allowed",false)):
            continue
        var work: Dictionary = action({"op":"partial_work","part_id":pid,"cycles":int(def["work_units"])})
        if not bool(work.get("ok",false)):
            continue
        var done: Dictionary = action({"op":"release","part_id":pid,"access_aids":[],
            "spawn_origin":[1.0,1.0,1.0]})
        if not bool(done.get("ok",false)):
            continue
        for result: Variant in HMRules.make_outputs(catalog,pid,"intact"):
            var lot_id: String = String(result["id"])
            if not HMSalvageLogistics.can_lift(state["world"],state["economy"],lot_id):
                continue
            if not action({"op":"pickup","output_id":lot_id,"carrier":"carried"}).get("ok",false):
                continue
            ensure(bool(action({"op":"unload","output_id":lot_id,
                "receiving_pad_confirmed":true,"position":[8.0,0.3,8.0]}).get("ok",false)),
                "Manually unload authentic part " + lot_id)
            ensure(bool(action({"op":"register","output_id":lot_id}).get("ok",false)),
                "Register authentic conserved physical lot " + lot_id)

func _run() -> void:
    catalog = HMCatalog.new()
    ensure(catalog.load_all(), "Load actual village content")
    state = HMSaveState.fresh(catalog)
    var bell: Dictionary = {}
    for act: int in range(1,5):
        if act == 1:
            _evidence("bell_first_strike")
        if act == 2:
            _find_tool("claw_hammer")
            _find_tool("crowbar")
            _find_tool("pickaxe")
            _evidence("mine_voice_heard")
        if act == 3:
            _find_tool("saw")
            _evidence("aldren_remains_found")
        if act == 4:
            _evidence("containment_understood")
            _evidence("mara_escape_clues")
        var req_id: String = "req_act_0" + str(act)
        _collect_until(req_id)
        ensure(HMRules.requisition_met(catalog,req_id,state["economy"],
            state["progress"]["tools"],state["progress"]["discoveries"]+state["progress"]["encounters"]),
            "Requisition " + str(act) + " is achievable using real catalogue salvage")
        ensure(bool(action({"op":"requisition","requisition_id":req_id}).get("ok",false)),
            "Manual requisition submit " + str(act))
        if act < 4:
            ensure(bool(action({"op":"advance_act"}).get("ok",false)),
                "Manually advance to act " + str(act+1))
    ensure(_recovered_units() >= 65,"Four-act recovery registers at least 65 conserved units")
    bell = state.duplicate(true)
    var original_serial: int = serial
    for action_id: String in HMCampaignRules.BELL:
        var spec: Dictionary = HMCampaignRules.TASKS[action_id]
        ensure(bool(action({"op":"finale_action","action_id":action_id,
            "world_target_validated":true,"site_id":spec["site"],"selected_tool_id":spec["tool"]}).get("ok",false)),
            "Manually complete bell operation " + action_id)
    ensure(bool(action({"op":"ending","ending_id":"bell_delivery",
        "explicit_confirmation":true,"finale_validated":true,"finale_site":"brinewick/site_15"}).get("ok",false)),
        "Bell delivered only after manual hauling chain")
    ensure(HMSaveState.validate(catalog,state).is_empty(),"Bell ending save is valid")
    state = bell
    serial = original_serial
    for action_id: String in HMCampaignRules.REPAIR:
        var spec: Dictionary = HMCampaignRules.TASKS[action_id]
        ensure(bool(action({"op":"finale_action","action_id":action_id,
            "world_target_validated":true,"site_id":spec["site"],"selected_tool_id":spec["tool"]}).get("ok",false)),
            "Manually complete containment work " + action_id)
    ensure(bool(action({"op":"ending","ending_id":"repair_escape",
        "explicit_confirmation":true,"finale_validated":true,"finale_site":"brinewick/site_21"}).get("ok",false)),
        "Escape recorded only after physical containment repair")
    ensure(HMSaveState.validate(catalog,state).is_empty(),"Repair ending save is valid")
    if problems.is_empty():
        print("HOLLOWMERE_FOUR_ACTS_TRANSACTION_OK registered_units=" + str(_recovered_units()))
        quit(0)
    else:
        quit(1)
