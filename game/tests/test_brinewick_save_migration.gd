extends SceneTree
## Real save envelope migration from exactly the prior 75 catalogue entries.
var errors: Array[String] = []
func require(ok: bool, reason: String) -> void:
	if not ok:
		errors.append(reason)
		push_error("BRINEWICK MIGRATION: " + reason)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var catalog := HMCatalog.new()
	require(catalog.load_all(), "New catalogue loads")
	var previous := HMCatalog.new()
	previous.tables = catalog.tables.duplicate(true)
	var all: Array = previous.tables["sample_parts"]["parts"]
	previous.tables["sample_parts"]["parts"] = all.slice(0,75)
	require(previous.entries("sample_parts","parts").size() == 75, "Original 75 part IDs retained")
	var slot: String = "brinewick_additive_migration_fixture"
	for ext: String in ["",".previous",".writing"]:
		var path: String = ProjectSettings.globalize_path(HMSaveStore.SAVE_DIRECTORY.path_join(slot+".hmsave.json"+ext))
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	var writer := HMSaveStore.new()
	require(writer.open_slot(previous,slot), "Previous version opens")
	var state: Dictionary = writer.snapshot()
	state["world"]["parts"]["village/06/net_store/net_rack"]["work"] = 1
	writer.state = state
	require(writer.save_now(), "Prior signed snapshot persisted")
	var reloaded := HMSaveStore.new()
	require(reloaded.open_slot(catalog,slot), "Strict append-only migration accepted")
	if not reloaded.state.is_empty():
		require(reloaded.state["world"]["parts"].size() == 351, "New 276 appended, preserving prior 75")
		require(int(reloaded.state["world"]["parts"]["village/06/net_store/net_rack"]["work"]) == 1, "Old partial work survives")
		require(HMSaveState.validate(catalog,reloaded.state).is_empty(), "Reopened state validates")
	for ext: String in ["",".previous",".writing"]:
		var path: String = ProjectSettings.globalize_path(HMSaveStore.SAVE_DIRECTORY.path_join(slot+".hmsave.json"+ext))
		if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
	if errors.is_empty():
		print("HOLLOWMERE_BRINEWICK_MIGRATION_OK")
		quit(0)
	else:
		quit(1)
