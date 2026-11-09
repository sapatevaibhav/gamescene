class_name Atmosphere
extends Node3D
## Sky, sun/moon, fog, post-processing, weather and the day/night cycle.
## `apply()` maps the web build's mood/time/weather model onto Godot's
## Environment so the same project settings look the same, only better.

const SKY_SHADER := preload("res://src/shaders/sky.gdshader")
const C_NIGHT := Color("0b1430")
const C_DUSK := Color("f0956a")
const C_SUNLOW := Color("ffb27a")
const C_SUNHI := Color("fff4e2")
const C_MOON := Color("9db4ff")

var env := Environment.new()
var world_env := WorldEnvironment.new()
var sun := DirectionalLight3D.new()
var fill := DirectionalLight3D.new()
var sky_mat := ShaderMaterial.new()
var rain: GPUParticles3D
var snow: GPUParticles3D
var style := "blocky"
## 0 at noon, 1 at midnight; lamps and windows brighten with it.
var night := 0.0
var _sun_energy := 1.0
var _flash := 0.0
var _flash_wait := 8.0
var _sky_col := Color()
var _lights: Array[Light3D] = []


func _ready() -> void:
	var sky := Sky.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 1.0
	env.fog_sky_affect = 0.0
	env.fog_depth_curve = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6
	env.ssao_power = 1.3
	env.ssil_radius = 4.0
	env.adjustment_enabled = true
	env.volumetric_fog_density = 0.0
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_detail_spread = 1.6
	env.volumetric_fog_gi_inject = 0.6
	env.volumetric_fog_anisotropy = 0.6
	world_env.environment = env
	add_child(world_env)

	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.2
	sun.light_angular_distance = 0.6
	add_child(sun)
	# Soft opposite fill so faces in shadow keep shape (the old hemisphere light).
	fill.shadow_enabled = false
	fill.light_energy = 0.12
	fill.light_specular = 0.0
	fill.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(fill)
	_build_weather()


func _build_weather() -> void:
	rain = GPUParticles3D.new()
	rain.amount = 2600
	rain.lifetime = 1.1
	rain.preprocess = 1.0
	rain.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(22, 1, 22)
	pm.direction = Vector3(0.08, -1, 0.04)
	pm.spread = 2.0
	pm.initial_velocity_min = 20.0
	pm.initial_velocity_max = 26.0
	pm.gravity = Vector3(0, -12, 0)
	rain.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.018, 0.65)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(0.78, 0.84, 0.95, 0.38)
	rm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	rm.billboard_keep_scale = true
	q.material = rm
	rain.draw_pass_1 = q
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain.emitting = false
	rain.visible = false
	add_child(rain)

	snow = GPUParticles3D.new()
	snow.amount = 2200
	snow.lifetime = 7.0
	snow.preprocess = 7.0
	snow.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	var sm := ParticleProcessMaterial.new()
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sm.emission_box_extents = Vector3(24, 1, 24)
	sm.direction = Vector3(0, -1, 0)
	sm.spread = 25.0
	sm.initial_velocity_min = 1.2
	sm.initial_velocity_max = 2.2
	sm.gravity = Vector3(0.25, -0.9, 0.1)
	sm.turbulence_enabled = true
	sm.turbulence_noise_strength = 0.6
	sm.turbulence_noise_scale = 4.0
	sm.scale_min = 0.6
	sm.scale_max = 1.3
	snow.process_material = sm
	var fq := QuadMesh.new()
	fq.size = Vector2(0.09, 0.09)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.95))
	g.set_color(1, Color(1, 1, 1, 0))
	gt.gradient = g
	gt.width = 32
	gt.height = 32
	fm.albedo_texture = gt
	fq.material = fm
	snow.draw_pass_1 = fq
	snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	snow.emitting = false
	snow.visible = false
	add_child(snow)


## Applies device quality (post effects and shadow resolution).
func apply_quality() -> void:
	var qd := App.q()
	env.ssao_enabled = qd["ssao"]
	env.ssil_enabled = qd["ssil"]
	env.glow_enabled = qd["glow"]
	env.volumetric_fog_enabled = qd["vfog"]
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if qd["shadow"] >= 4096 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 90.0
	RenderingServer.directional_shadow_atlas_set_size(qd["shadow"], true)
	rain.amount = 2600 if qd["shadow"] >= 4096 else 1200
	snow.amount = 2200 if qd["shadow"] >= 4096 else 1000
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = qd["scale"]
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if qd["scale"] < 1.0 else Viewport.SCALING_3D_MODE_BILINEAR
		vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_4X][qd["msaa"]]
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if qd["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED
	if style in ["pixel", "pixeltop"]:
		# Crisp pixel art: no upscaling blur, anti-aliasing, fog or bloom.
		env.ssao_enabled = false
		env.ssil_enabled = false
		env.glow_enabled = false
		env.volumetric_fog_enabled = false
		if vp:
			vp.scaling_3d_scale = 1.0
			vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED


func set_style(key: String) -> void:
	style = key
	match key:
		"anime":
			env.adjustment_saturation = 1.08
			env.adjustment_contrast = 1.05
			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.tonemap_exposure = 1.12
		"lowpoly":
			env.adjustment_saturation = 1.08
			env.adjustment_contrast = 1.0
			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.tonemap_exposure = 1.05
		"pixel", "pixeltop":
			env.adjustment_saturation = 1.0
			env.adjustment_contrast = 1.0
			env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			env.tonemap_exposure = 1.0
		_:
			env.adjustment_saturation = 1.05
			env.adjustment_contrast = 1.02
			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.tonemap_exposure = 1.04
	env.fog_enabled = not key in ["pixel", "pixeltop"]
	apply_quality()


func apply_mood(key: String) -> void:
	var m: Dictionary = Styles.MOODS.get(key, {})
	if m.is_empty():
		return
	App.settings["mood"] = key
	App.settings["time"] = m["time"]
	App.settings["weather"] = m["weather"]
	App.settings["fog"] = m["fog"]
	apply()


## Recomputes sky, light and fog from App.settings (the web `applySky`).
func apply() -> void:
	var s := App.settings
	var sty := Styles.get_style(style)
	var t: float = s["time"]
	var a := (t - 6.0) / 12.0 * PI
	var sy := sin(a)
	var day := clampf(sy * 1.8 + 0.25, 0, 1)
	var dusk := clampf(1.0 - absf(sy) * 3.5, 0, 1)
	night = 1.0 - day
	var mood: Dictionary = Styles.MOODS.get(s["mood"], {})
	var c_day := U.col(sty["sky"])
	var sky := C_NIGHT.lerp(c_day, day).lerp(C_DUSK, dusk * 0.55)
	var weather: String = s["weather"]
	if weather == "rain":
		sky = U.shade(sky, 0.62)
	elif weather == "snow":
		sky = sky.lerp(Color("c9d3df"), 0.4)
	if mood.has("sky"):
		sky = U.col(mood["sky"])
	_sky_col = sky
	var fog_c: Color = U.col(mood["fogC"]) if mood.has("fogC") else sky

	# Sun or moon.
	var la := a if sy > 0 else a + PI
	var size := float(Styles.SIZE)
	var sun_pos := Vector3(size / 2 + cos(la) * 50, absf(sin(la)) * 60 + 12, size / 2 + 22)
	var center := Vector3(size / 2, 0, size / 2)
	var energy: float
	var sun_col: Color
	if sy > 0:
		sun_col = C_SUNLOW.lerp(C_SUNHI, clampf(sy * 3, 0, 1))
		energy = lerpf(0.35, 1.25, clampf(sy * 2, 0, 1))
	else:
		sun_col = C_MOON
		energy = 0.2
	if mood.has("light"):
		sun_col = U.col(mood["light"])
	if weather != "clear":
		energy *= 0.5
	var ambient := lerpf(0.18, 0.75, day)
	if mood.has("sky") and not mood.has("dim"):
		ambient = 0.85
		energy = maxf(energy, 0.8)
	if mood.has("dim"):
		ambient *= mood["dim"]
		energy = 0.2
	var light_k: float = sty.get("light", 1.0)
	energy *= lerpf(1.0, light_k, 0.6)
	_sun_energy = energy
	sun.light_color = sun_col
	sun.light_energy = energy
	sun.global_transform = Transform3D.IDENTITY
	sun.look_at_from_position(sun_pos, center, Vector3.UP)
	fill.look_at_from_position(center - (sun_pos - center), center, Vector3.UP)
	fill.light_color = sky.lerp(Color.WHITE, 0.5)
	fill.light_energy = 0.1 + 0.1 * day

	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = ambient
	env.ambient_light_color = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# Sky shader.
	var top := U.shade(sky, 0.78).lerp(Color(0.18, 0.36, 0.78), 0.25 * day)
	var horizon := sky.lerp(Color.WHITE, 0.32 * day)
	if mood.has("fogC"):
		horizon = horizon.lerp(fog_c, 0.6)
	sky_mat.set_shader_parameter("sky_top", top)
	sky_mat.set_shader_parameter("sky_horizon", horizon)
	sky_mat.set_shader_parameter("ground_color", U.shade(fog_c, 0.7))
	sky_mat.set_shader_parameter("sun_color", sun_col)
	sky_mat.set_shader_parameter("sun_size", 0.9996 if sy > 0 else 0.9998)
	var clear := weather == "clear" and not mood.has("fogC")
	sky_mat.set_shader_parameter("stars", clampf(1.0 - day * 1.4, 0, 1) * (1.0 if clear else 0.15))
	var cover := 0.5
	if weather == "rain":
		cover = 0.95
	elif weather == "snow":
		cover = 0.85
	elif mood.has("dim"):
		cover = 0.0
	sky_mat.set_shader_parameter("clouds", cover)
	sky_mat.set_shader_parameter("cloud_color", Color(lerpf(0.25, 1, day), lerpf(0.28, 1, day), lerpf(0.38, 1, day)) * (0.7 if weather == "rain" else 1.0))
	sky_mat.set_shader_parameter("horizon_haze", 1.0 if clear else 0.3)

	# Fog: the web used linear fog between fog*.3 and fog (shorter in bad weather).
	var far: float = s["fog"] * (1.0 if weather == "clear" else 0.6)
	env.fog_light_color = horizon if not mood.has("fogC") else fog_c
	env.fog_depth_begin = s["fog"] * 0.3
	env.fog_depth_end = far * 1.25
	env.fog_aerial_perspective = 0.35
	env.volumetric_fog_albedo = fog_c.lerp(Color.WHITE, 0.4)
	var vf := 0.006
	if mood.has("dim"):
		vf = 0.03
	elif weather != "clear":
		vf = 0.02
	elif dusk > 0.3:
		vf = 0.012
	if style == "anime" and vf < 0.014:
		# Soft light shafts through the canopy.
		vf = 0.014
	env.volumetric_fog_density = vf
	var toon_sky := style == "anime"
	sky_mat.set_shader_parameter("cloud_toon", 1.0 if toon_sky else 0.0)
	sky_mat.set_shader_parameter("cloud_sharp", 0.1 if toon_sky else 0.35)
	sky_mat.set_shader_parameter("cloud_scale", 0.95 if toon_sky else 1.6)
	env.glow_intensity = 0.55 + 0.5 * night

	rain.visible = weather == "rain"
	rain.emitting = rain.visible
	snow.visible = weather == "snow"
	snow.emitting = snow.visible
	_update_night_lights()


func sky_color() -> Color:
	return _sky_col


func light_color() -> Color:
	return sun.light_color


## Registers lamp/window lights so they fade in at dusk.
func register_lights(root: Node) -> void:
	_lights.clear()
	_collect_lights(root)
	_update_night_lights()


func _collect_lights(n: Node) -> void:
	if n is OmniLight3D or n is SpotLight3D:
		var l := n as Light3D
		if not l.has_meta("base_energy"):
			l.set_meta("base_energy", l.light_energy)
		_lights.append(l)
	for c in n.get_children():
		_collect_lights(c)


func _update_night_lights() -> void:
	var cap: int = App.q()["lights"]
	var k := 0.12 + 0.88 * clampf(night * 1.4, 0, 1)
	var i := 0
	for l in _lights:
		if not is_instance_valid(l):
			continue
		l.visible = i < cap
		l.light_energy = float(l.get_meta("base_energy", 1.0)) * k
		i += 1


## Per-frame: day/night cycle, weather following the camera, lightning.
func tick(dt: float, cam_pos: Vector3) -> void:
	if App.settings["cycle"]:
		App.settings["time"] = fmod(float(App.settings["time"]) + dt * 0.1, 24.0)
		apply()
	var above := cam_pos + Vector3(0, 13, 0)
	if rain.visible:
		rain.global_position = above
	if snow.visible:
		snow.global_position = cam_pos + Vector3(0, 9, 0)
	if App.settings["weather"] == "rain":
		_flash_wait -= dt
		if _flash_wait <= 0.0:
			_flash_wait = 7.0 + App.sim_randf() * 12.0
			_flash = 0.22
		if _flash > 0.0:
			_flash -= dt
			var f := 1.0 if fmod(_flash, 0.08) > 0.04 else 0.4
			sun.light_energy = _sun_energy + 2.5 * f
			env.ambient_light_energy = 1.4 * f
		elif sun.light_energy != _sun_energy:
			sun.light_energy = _sun_energy
			apply()
