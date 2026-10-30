class_name HMCoastalPresentation
extends RefCounted
## Step 43 visual unification: conservative climate and readability parameters.
## Geometry, physics, salvage IDs, story and building materials are untouched.
const NORMAL_FOG: float = 0.0025
const CLEARER_FOG: float = 0.0014
const OVERCAST_SKY: Color = Color("74817f")
const COASTAL_HAZE: Color = Color("848e87")
const AMBIENCE: Color = Color("a6afa4")
const LIGHT: Color = Color("ede0c9")

static func apply(world: Node3D, clearer_fog: bool = false) -> bool:
	var environment: WorldEnvironment = world.get_node_or_null("CoastalEnvironment") as WorldEnvironment
	var sun: DirectionalLight3D = world.get_node_or_null("OvercastCoastalSun") as DirectionalLight3D
	if environment == null or sun == null or environment.environment == null:
		return false
	var sky: Environment = environment.environment
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = OVERCAST_SKY
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = AMBIENCE
	sky.ambient_light_energy = 0.27
	sky.fog_enabled = true
	sky.fog_density = CLEARER_FOG if clearer_fog else NORMAL_FOG
	sky.fog_light_color = COASTAL_HAZE
	sun.light_color = LIGHT
	sun.light_energy = 1.12
	sun.shadow_enabled = true
	return true

static func audit(world: Node3D) -> Dictionary:
	var environment: WorldEnvironment = world.get_node_or_null("CoastalEnvironment") as WorldEnvironment
	var sun: DirectionalLight3D = world.get_node_or_null("OvercastCoastalSun") as DirectionalLight3D
	if environment == null or sun == null or environment.environment == null:
		return {"ok": false, "reason": "Coastal lighting nodes absent"}
	var sky: Environment = environment.environment
	return {
		"ok": sky.fog_enabled and sky.fog_density > 0.0
			and sky.background_color == OVERCAST_SKY and sun.shadow_enabled,
		"fog_density": sky.fog_density,
		"key_energy": sun.light_energy,
		"sky_color": sky.background_color.to_html(false)
	}
