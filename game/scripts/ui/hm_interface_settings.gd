class_name HMInterfaceSettings
extends RefCounted
## Persistent, local presentation preferences. No economy/save/campaign authority.
const PATH: String = "user://interface-settings.cfg"
const FONT_SCALES: Array[float] = [1.0, 1.25, 1.5]
var font_scale: float = 1.0
var high_contrast: bool = false
var mouse_sensitivity: float = 0.0019
var clearer_fog: bool = false
var master_volume: float = 0.8
var ambience_volume: float = 0.75
var feedback_volume: float = 0.8

func load_local(path: String = PATH) -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	font_scale = float(config.get_value("accessibility", "font_scale", 1.0))
	if not FONT_SCALES.has(font_scale):
		font_scale = 1.0
	high_contrast = bool(config.get_value("accessibility", "high_contrast", false))
	clearer_fog = bool(config.get_value("accessibility", "clearer_fog", false))
	mouse_sensitivity = clampf(float(config.get_value("controls", "mouse_sensitivity", 0.0019)), 0.0008, 0.004)
	master_volume = clampf(float(config.get_value("audio", "master_volume", 0.8)), 0.0, 1.0)
	ambience_volume = clampf(float(config.get_value("audio", "ambience_volume", 0.75)), 0.0, 1.0)
	feedback_volume = clampf(float(config.get_value("audio", "feedback_volume", 0.8)), 0.0, 1.0)

func apply_audio() -> void:
	_apply_bus("Master", master_volume, 0.0)
	_apply_bus("HM_Coastal", ambience_volume, -18.0)
	_apply_bus("HM_Underground", ambience_volume, -14.0)
	_apply_bus("HM_Feedback", feedback_volume, -11.0)

static func _apply_bus(bus: String, level: float, original_db: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, level <= 0.0)
	AudioServer.set_bus_volume_db(index, original_db + linear_to_db(maxf(0.001, level)))

func save_local(path: String = PATH) -> Error:
	var config := ConfigFile.new()
	config.set_value("accessibility", "font_scale", font_scale)
	config.set_value("accessibility", "high_contrast", high_contrast)
	config.set_value("accessibility", "clearer_fog", clearer_fog)
	config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "ambience_volume", ambience_volume)
	config.set_value("audio", "feedback_volume", feedback_volume)
	return config.save(path)
