class_name HMUndergroundAudio
extends Node3D
## Steps 37–38: original, non-musical spatial ambience and sparse narrative
## answers. Audio may guide the player but NEVER triggers progress or depicts
## the unseen entity. No random event gates; already-discovered flags persist.
const BUS_AMBIENCE: String = "HM_Coastal"
const BUS_UNDERGROUND: String = "HM_Underground"
const BUS_STORY: String = "HM_Story"
var ambience_players: Dictionary = {}
var response_players: Dictionary = {}
var actor: HMFirstPerson
var enabled: bool = false
var update_elapsed: float = 0.0
var fired_flags: Dictionary = {}

func build(underground: HMUndergroundSites, sites: Dictionary) -> void:
	if not ambience_players.is_empty():
		return
	_ensure_bus(BUS_AMBIENCE, -18.0)
	_ensure_bus(BUS_UNDERGROUND, -14.0)
	_ensure_bus(BUS_STORY, -5.0)
	_spawn_loop("well", underground.locations["well_listening"], BUS_UNDERGROUND, 0)
	_spawn_loop("mine", underground.locations["mine_seal"], BUS_UNDERGROUND, 1)
	_spawn_loop("undercroft", underground.locations["undercroft"], BUS_UNDERGROUND, 2)
	_spawn_loop("bell", sites["brinewick/site_15"].position + Vector3(0, 2.5, 0), BUS_AMBIENCE, 3)
	# Quiet working-village sound beds are localised and never unlock progress.
	_spawn_loop("quay_swell", sites["brinewick/site_02"].position + Vector3(-2.0, 1.0, 0), BUS_AMBIENCE, 5)
	_spawn_loop("mine_headland_wind", sites["brinewick/site_19"].position + Vector3(1.0, 2.5, 0), BUS_AMBIENCE, 6)
	_spawn_response("bell_first_strike", sites["brinewick/site_15"].position + Vector3(0, 2.5, 0), 0)
	_spawn_response("mine_voice_heard", sites["brinewick/site_18"].position + Vector3(0, 2, 0), 1)
	_spawn_response("containment_understood", sites["brinewick/site_17"].position + Vector3(0, 1.6, 0), 2)
	_spawn_response("cycle_test", sites["brinewick/site_15"].position + Vector3(0, 2.3, 0), 3)

func bind_player(player: HMFirstPerson) -> void:
	actor = player

func set_active(active: bool) -> void:
	enabled = active
	for node: Variant in ambience_players.values():
		var audio: AudioStreamPlayer3D = node
		if enabled:
			if not audio.playing:
				audio.play()
		else:
			audio.stop()
	for node: Variant in response_players.values():
		var audio: AudioStreamPlayer3D = node
		if not enabled:
			audio.stop()

func emit_story_response(flag_id: String) -> bool:
	# The caller has already succeeded at a single deliberate E/transaction.
	# No event makes itself repeatable or carries narrative state outside save.
	if not enabled or not response_players.has(flag_id) or fired_flags.has(flag_id):
		return false
	fired_flags[flag_id] = true
	var node: AudioStreamPlayer3D = response_players[flag_id]
	node.play()
	return true

func _physics_process(delta: float) -> void:
	if not enabled or actor == null:
		return
	update_elapsed += delta
	if update_elapsed < 0.22:
		return
	update_elapsed = 0.0
	# Real colliders attenuate sound across cliff, masonry and gallery walls.
	# The engine's 3D distance attenuation remains authoritative in free space.
	var from: Vector3 = actor.view_camera.global_position
	for node: Variant in ambience_players.values() + response_players.values():
		var audio: AudioStreamPlayer3D = node
		var target: Vector3 = audio.global_position
		var query := PhysicsRayQueryParameters3D.create(from, target, 1)
		query.exclude = [actor.get_rid()]
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		var blocked: bool = not hit.is_empty() and Vector3(hit["position"]).distance_to(target) > 0.7
		audio.volume_db = -17.0 if blocked else -3.0

func _ensure_bus(label: String, gain: float) -> void:
	var index: int = AudioServer.get_bus_index(label)
	if index == -1:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, label)
	AudioServer.set_bus_volume_db(index, gain)
	if label == BUS_UNDERGROUND and AudioServer.get_bus_effect_count(index) == 0:
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.58
		reverb.damping = 0.67
		reverb.wet = 0.16
		AudioServer.add_bus_effect(index, reverb)

func _spawn_loop(id: String, at: Vector3, bus_name: String, voice: int) -> void:
	var node := AudioStreamPlayer3D.new()
	node.name = "Audible_" + id
	node.position = at
	node.bus = bus_name
	node.max_distance = 27.0
	node.unit_size = 7.5
	node.stream = _original_audio(voice, true)
	add_child(node)
	ambience_players[id] = node

func _spawn_response(flag_id: String, at: Vector3, voice: int) -> void:
	var node := AudioStreamPlayer3D.new()
	node.name = "OneTime_" + flag_id
	node.position = at
	node.bus = BUS_STORY
	node.max_distance = 30.0
	node.unit_size = 6.0
	node.stream = _original_audio(voice + 4, false)
	add_child(node)
	response_players[flag_id] = node

static func _original_audio(voice: int, loop: bool) -> AudioStreamWAV:
	# Deterministic low, filtered creaks / hollow wind / nonverbal responses.
	# These are synthesised sound effects, not recorded speech or music.
	const RATE: int = 11025
	var seconds: int = 8 if loop else 3
	var samples: int = RATE * seconds
	var frames := PackedByteArray()
	frames.resize(samples * 2)
	var phase: float = float(voice + 1) * 0.71
	for i: int in range(samples):
		var t: float = float(i) / float(RATE)
		var envelope: float = 1.0 if loop else sin(PI * t / float(seconds))
		var wind: float = sin(TAU * (34.0 + float(voice) * 5.0) * t + 0.7 * sin(TAU * 0.375 * t))
		var rough: float = sin(TAU * (59.0 + float(voice) * 7.0) * t + phase)
		var shimmer: float = sin(TAU * 121.0 * t + phase * 2.0)
		var amplitude: float = (wind * 0.40 + rough * 0.21 + shimmer * 0.055) * envelope
		var n: int = clampi(int(amplitude * 5500.0), -32767, 32767)
		frames.encode_s16(i * 2, n)
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = RATE
	sound.stereo = false
	sound.data = frames
	if loop:
		sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sound.loop_begin = 0
		sound.loop_end = samples
	return sound
