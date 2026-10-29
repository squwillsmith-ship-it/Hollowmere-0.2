class_name HMActionFeedback
extends Node
## Original deterministic material-specific Foley synthesiser for deliberate
## player actions. These are practical authored procedural sources, not music.
## No auto-work, hidden effects or extra salvage transactions.
const BUS: String = "HM_Feedback"
const RATE: int = 22050
const DURATION: float = 0.36
var player: AudioStreamPlayer
var cache: Dictionary = {}
var last_event_ms: int = -9999

func _ready() -> void:
	var index: int = AudioServer.get_bus_index(BUS)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_volume_db(index, -11.0)
	player = AudioStreamPlayer.new()
	player.bus = BUS
	player.volume_db = -5.5
	add_child(player)

func notify(result: Dictionary, tool_id: String = "hands", material: String = "timber") -> void:
	if player == null:
		return
	var successful: bool = bool(result.get("ok", false))
	var event_class: String = "good" if successful else "blocked"
	var key: String = tool_id + ":" + material + ":" + event_class
	if not cache.has(key):
		cache[key] = generate(tool_id, material, successful)
	player.stop()
	player.stream = cache[key]
	player.play()

static func generate(tool_id: String, material: String, success: bool) -> AudioStreamWAV:
	# Two pitched resonances, a seeded mineral/wood transient and a diminishing
	# rasp. Different source spectra for hammer, stone pick, iron bar and saw.
	var sample_count: int = roundi(RATE * (DURATION if success else 0.17))
	var raw := PackedByteArray()
	raw.resize(sample_count * 2)
	var seed: int = absi((tool_id + "/" + material + "/" + str(success)).hash()) + 731
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var base: float = 215.0
	match tool_id:
		"hands": base = 118.0
		"claw_hammer": base = 295.0
		"crowbar": base = 418.0
		"pickaxe": base = 610.0
		"saw": base = 455.0
	if material == "stone" or material == "mineral_fill":
		base *= 1.33
	elif material == "iron" or material == "copper_bronze":
		base *= 1.61
	elif material == "fibres":
		base *= 0.60
	elif material == "fired_clay":
		base *= 1.17
	var noise_previous: float = 0.0
	for i: int in range(sample_count):
		var t: float = float(i) / float(RATE)
		var u: float = float(i) / float(sample_count)
		var attack: float = minf(1.0, u * 150.0)
		var decay: float = pow(1.0 - u, 3.0 if success else 5.5)
		var noise: float = rng.randf_range(-1.0, 1.0)
		var filtered: float = (noise - noise_previous) * 0.5
		noise_previous = noise
		var clang: float = sin(TAU * base * t) * 0.42
		var overtone: float = sin(TAU * base * 2.71 * t) * 0.18
		var grit: float = filtered * (0.28 if material == "stone" else 0.17)
		if tool_id == "saw":
			var tooth_pulse: float = absf(sin(TAU * 32.0 * t))
			grit = filtered * tooth_pulse * 0.37
			clang *= 0.26
		elif tool_id == "crowbar":
			clang += sin(TAU * (base * 0.41 + t * 260.0) * t) * 0.24
		elif tool_id == "hands":
			clang *= 0.20
			grit *= 1.25
		if not success:
			clang *= 0.26
			overtone *= 0.25
		var amplitude: float = (clang + overtone + grit) * decay * attack
		raw.encode_s16(i * 2, clampi(roundi(amplitude * 9400.0), -32767, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	stream.mix_rate = RATE
	stream.data = raw
	return stream
