extends SceneTree
var errors: Array[String] = []
func _initialize() -> void:
	call_deferred("run_tests")
func check(ok: bool, label: String) -> void:
	if not ok:
		errors.append(label)
		push_error("STEP19 FAIL: " + label)
func run_tests() -> void:
	var cat := HMCatalog.new()
	check(cat.load_all(), "Catalog loaded")
	var manifest: Dictionary = HMBuildingPrefab.read_manifest("res://data/v1/buildings/cottage_working_01.json")
	check(not manifest.is_empty(), "Versioned reusable authored manifest exists")
	check(HMBuildingPrefab.validate(manifest, cat).is_empty(), "Manifest geometry and stable IDs valid")
	var duplicate: Dictionary = manifest.duplicate(true)
	duplicate["parts"].append(duplicate["parts"][0].duplicate(true))
	check(not HMBuildingPrefab.validate(duplicate, cat).is_empty(), "Duplicate authored IDs rejected")
	var unregistered: Dictionary = manifest.duplicate(true)
	unregistered["parts"][0]["id"] = "fabricated/part"
	check(not HMBuildingPrefab.validate(unregistered, cat).is_empty(), "Unknown part IDs rejected")
	var no_geometry: Dictionary = manifest.duplicate(true)
	no_geometry["parts"][0]["geometry"] = []
	check(not HMBuildingPrefab.validate(no_geometry, cat).is_empty(), "Empty structural geometry rejected")
	if errors.is_empty():
		print("HOLLOWMERE_STEP19_TEST_OK")
		quit(0)
	else:
		quit(1)
