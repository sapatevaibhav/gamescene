class_name Studio
extends Node3D
## The scene being made: world, cast, atmosphere, camera, recording, script
## (timeline cues), shot list and undo history. Owns the simulation loop.

signal scene_changed
signal cast_changed
signal recording_changed(on: bool)

var style_key := "blocky"
var world: Node3D = null  # VoxelWorld or TerrainWorld
var actor_layer := Node3D.new()
var actors: Array[Actor] = []
var player: Actor = null
var atmo := Atmosphere.new()
var camera := CameraRig.new()
var recorder := Recorder.new()
var tools: EditorTools

var project_id := ""
var project_name := ""
var in_studio := false
var dirty := false
var _save_t := 0.0

## Timeline cues: [{actor: name, action, start, dur, text, x, z}]
var cues: Array = []
## Shot list for film export: [{name, mode, shot, target, dur, dist, height, points, title, fade_in, fade_out}]
var shots: Array = []
## Cast state when the scene starts playing (positions, behaviours).
var start_state: Array = []
var scene_seed := 1
## Timeline clock while directing ("Play scene").
var playing := false
var play_t := 0.0
var _fired := {}

var input_move := Vector2.ZERO
var input_jump := false
var input_sprint := false

var _undo: Array = []
var _redo: Array = []
var _time := 0.0


func _ready() -> void:
	add_child(atmo)
	actor_layer.name = "Cast"
	add_child(actor_layer)
	camera.studio = self
	add_child(camera)
	camera.current = true
	recorder.studio = self
	add_child(recorder)
	recorder.finished.connect(func(_p, _s): recording_changed.emit(false))
	tools = EditorTools.new()
	tools.studio = self
	add_child(tools)
	atmo.apply_quality()


# ---------------------------------------------------------------- scenes

func _clear() -> void:
	if recorder.active:
		recorder.stop()
	tools.set_tool("")
	for a in actors:
		a.dispose()
	actors.clear()
	player = null
	if world:
		world.queue_free()
		remove_child(world)
	world = null
	cues = []
	shots = []
	start_state = []
	playing = false
	_undo.clear()
	_redo.clear()
	Kit.clear_cache()


func _make_world(key: String) -> void:
	style_key = key
	var sty := Styles.get_style(key)
	Kit.shade = sty["shade"]
	if sty["world"] == "voxel":
		Blocks.init()
		world = VoxelWorld.new()
	else:
		var tw := TerrainWorld.new()
		tw.grass_density = App.q()["grass"]
		tw.set_style(key)
		world = tw
	world.name = "World"
	add_child(world)
	atmo.set_style(key)


func new_scene(key: String) -> void:
	_clear()
	_make_world(key)
	world.new_world(key)
	scene_seed = randi() % 100000
	App.sim_rng.seed = scene_seed
	await _default_cast()
	App.settings["frame"] = "full"
	App.settings["fov"] = 70.0
	App.settings["shake"] = false
	App.settings["dof"] = false
	atmo.apply_mood(Styles.get_style(key)["mood"])
	camera.load_view({"mode": "third", "yaw": PI, "pitch": 0.3, "dist": 6.0}, {})
	shots = default_shots()
	capture_start()
	atmo.register_lights(world)
	scene_changed.emit()
	cast_changed.emit()


func _default_cast() -> void:
	var vox: bool = world.is_voxel
	var size := float(Styles.SIZE)
	var cx := size / 2 + 0.5
	var cz := size / 2 - 6 if vox else size / 2 - 3.5
	var pos := [[0, -3], [-5, -6], [3, -2], [5, -3], [-3, -1], [1.5, -5.5]] if vox else [[0, -3.5], [3.5, -1], [-2.6, 1.2], [-1.3, 2.4], [2.4, 2.6], [1.6, -5], [-5, -4], [5.5, -5]]
	var presets := Rigs.presets_for(style_key)
	var cast: Array = Rigs.DEFAULT_CAST.get(style_key, [])
	for i in cast.size():
		var row: Array = cast[i]
		var preset: String = row[0]
		var p: Dictionary = presets.get(preset, {})
		var off: Array = pos[i % pos.size()]
		add_actor({"name": row[1], "look": {"preset": preset}, "behavior": row[2] if row.size() > 2 else "idle",
			"lines": (p.get("lines", []) as Array).duplicate(), "x": cx + off[0], "z": cz + off[1],
			"yaw": 0.0 if i == 0 else App.sim_randf() * 6.0, "isPlayer": i == 0})


func default_shots() -> Array:
	return [
		{"name": "Establishing", "mode": "cine", "shot": "crane", "target": "", "dur": 5.0, "dist": 9.0, "height": 4.0, "title": "", "fade_in": true},
		{"name": "Hero close-up", "mode": "cine", "shot": "push", "target": "", "dur": 4.0, "dist": 4.0, "height": 1.6},
		{"name": "Orbit", "mode": "cine", "shot": "orbit", "target": "", "dur": 6.0, "dist": 6.0, "height": 2.2, "fade_out": true},
	]


func load_data(d: Dictionary) -> String:
	d = ProjectStore.migrate(d)
	var style: String = d.get("style", "blocky")
	if not Styles.STYLES.has(style) or not d.has("world"):
		return "That file isn’t a GameScene project."
	_clear()
	_make_world(style)
	if world.is_voxel:
		world.load_data(d["world"])
	else:
		world.load_data(d["world"], style)
	var st: Dictionary = d.get("settings", {})
	for k in st:
		if App.SCENE_KEYS.has(k):
			App.settings[k] = st[k]
	scene_seed = int(d.get("seed", randi() % 100000))
	App.sim_rng.seed = scene_seed
	for c in d.get("cast", []):
		var p: Array = c.get("pos", [24, 0, 24])
		add_actor({"name": c.get("name", "Someone"), "look": c.get("look", {}), "behavior": c.get("behavior", "idle"), "notice": c.get("notice", true),
			"lines": c.get("lines", []), "x": p[0], "y": p[1], "z": p[2], "yaw": c.get("yaw", 0.0), "isPlayer": c.get("player", false)})
	if player == null and not actors.is_empty():
		player = actors[0]
	if player == null:
		var presets := Rigs.presets_for(style_key)
		add_actor({"name": "You", "look": {"preset": presets.keys()[0]}, "isPlayer": true, "x": 24.0, "z": 20.0})
	camera.load_view(d.get("view", {}), d.get("cine", {}))
	cues = d.get("cues", [])
	shots = d.get("shots", [])
	if shots.is_empty():
		shots = default_shots()
	start_state = d.get("start", [])
	if start_state.is_empty():
		capture_start()
	atmo.apply()
	atmo.register_lights(world)
	scene_changed.emit()
	cast_changed.emit()
	return ""


func serialize() -> Dictionary:
	var settings := {}
	for k in App.SCENE_KEYS:
		settings[k] = App.settings[k]
	return {"app": "gamescene", "v": App.SCHEMA_VERSION, "name": project_name, "style": style_key, "seed": scene_seed,
		"world": world.serialize(), "cast": actors.map(func(a): return a.to_dict(a == player)),
		"settings": settings, "cine": camera.cine_dict(), "view": camera.to_dict(),
		"cues": cues, "shots": shots, "start": start_state}


func mark_dirty() -> void:
	dirty = true
	_save_t = 1.5


func save_now(with_thumb := false) -> void:
	if project_id == "" or world == null:
		return
	var img: Image = null
	if with_thumb:
		img = await recorder.thumbnail()
	if not ProjectStore.save(project_id, serialize(), img):
		App.toast("Couldn’t save. Is the device storage full?")
	dirty = false


# ---------------------------------------------------------------- undo

## Snapshot before an edit. Cheap enough for 48x48 worlds.
func checkpoint() -> void:
	_undo.append(JSON.stringify({"world": world.serialize(), "cast": actors.map(func(a): return a.to_dict(a == player))}))
	if _undo.size() > 40:
		_undo.pop_front()
	_redo.clear()


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func undo() -> void:
	_swap(_undo, _redo)


func redo() -> void:
	_swap(_redo, _undo)


func _swap(from: Array, to: Array) -> void:
	if from.is_empty():
		return
	to.append(JSON.stringify({"world": world.serialize(), "cast": actors.map(func(a): return a.to_dict(a == player))}))
	var d: Dictionary = JSON.parse_string(from.pop_back())
	if world.is_voxel:
		world.load_data(d["world"])
	else:
		world.load_data(d["world"], style_key)
	_restore_cast(d["cast"])
	atmo.register_lights(world)
	mark_dirty()
	cast_changed.emit()


func _restore_cast(cast: Array) -> void:
	for a in actors:
		a.dispose()
	actors.clear()
	player = null
	for c in cast:
		var p: Array = c["pos"]
		add_actor({"name": c["name"], "look": c["look"], "behavior": c["behavior"], "notice": c.get("notice", true), "lines": c.get("lines", []),
			"x": p[0], "y": p[1], "z": p[2], "yaw": c["yaw"], "isPlayer": c.get("player", false)})


# ---------------------------------------------------------------- cast

func actor_by_id(id: int) -> Actor:
	for a in actors:
		if a.id == id:
			return a
	return null


func actor_by_name(n: String) -> Actor:
	for a in actors:
		if a.name == n:
			return a
	return null


func spot_ok(x: float, z: float) -> bool:
	var y: float = world.ground_at(x, z)
	if world.is_voxel and y >= 22:
		return false
	return not world.body_blocked(Vector3(x, y, z))


func find_spot(x: float, z: float) -> Vector2:
	if spot_ok(x, z):
		return Vector2(x, z)
	var size := float(Styles.SIZE)
	var r := 0.8
	while r < 8:
		for k in 10:
			var a := k / 10.0 * TAU + r
			var nx := clampf(x + cos(a) * r, 1.5, size - 1.5)
			var nz := clampf(z + sin(a) * r, 1.5, size - 1.5)
			if spot_ok(nx, nz):
				return Vector2(nx, nz)
		r += 0.6
	return Vector2(x, z)


func add_actor(o: Dictionary) -> Actor:
	if actors.size() >= int(App.q()["cast"]):
		App.toast("That’s the cast limit for this device’s quality setting.")
		return null
	if not o.has("y"):
		var s := find_spot(float(o.get("x", 24)), float(o.get("z", 24)))
		o["x"] = s.x
		o["z"] = s.y
		o["y"] = world.ground_at(s.x, s.y)
	var a := Actor.new(self, o)
	actors.append(a)
	if o.get("isPlayer", false):
		player = a
	a.set_look(a.look)
	return a


func remove_actor(a: Actor) -> void:
	if a == player:
		return
	a.dispose()
	actors.erase(a)
	if int(camera.cine.get("target", 0)) == a.id:
		camera.cine["target"] = 0
	mark_dirty()
	cast_changed.emit()


func set_player(a: Actor) -> void:
	if a == player:
		return
	player = a
	a.set_behavior("idle")
	mark_dirty()
	cast_changed.emit()


func spawn_near() -> Vector2:
	var b := player.pos if player else Vector3(24, 0, 24)
	var ang := randf() * TAU
	var d := 2.0 + randf() * 2.5
	var size := float(Styles.SIZE)
	return Vector2(clampf(b.x + cos(ang) * d, 1.5, size - 1.5), clampf(b.z + sin(ang) * d, 1.5, size - 1.5))


func gather_point() -> Vector3:
	if player:
		return player.pos
	return Vector3(24, 0, 24)


func count_behavior(b: String) -> int:
	var n := 0
	for a in actors:
		if a.behavior == b:
			n += 1
	return n


## Who a fleeing actor runs from: the player, or any chasing monster nearby.
func nearest_threat(a: Actor) -> Actor:
	var best: Actor = null
	var bd := 7.0
	for b in actors:
		if b == a:
			continue
		if b != player and b.behavior != "chase":
			continue
		var d := Vector2(b.pos.x - a.pos.x, b.pos.z - a.pos.z).length()
		if d < bd:
			bd = d
			best = b
	return best


func on_line_spoken(a: Actor, text: String, dur: float) -> void:
	recorder.show_subtitle(a.name, text, dur)


func _separate() -> void:
	for i in actors.size():
		for j in range(i + 1, actors.size()):
			var a := actors[i]
			var b := actors[j]
			var dx := b.pos.x - a.pos.x
			var dz := b.pos.z - a.pos.z
			var d := sqrt(dx * dx + dz * dz)
			if d < 0.62 and d > 1e-4 and absf(a.pos.y - b.pos.y) < 1.5:
				var push := (0.62 - d) / 2.0
				var nx := dx / d * push
				var nz := dz / d * push
				_try_move(a, -nx, -nz)
				_try_move(b, nx, nz)


func _try_move(o: Actor, x: float, z: float) -> void:
	o.pos.x += x
	o.pos.z += z
	if world.body_blocked(o.pos):
		o.pos.x -= x
		o.pos.z -= z


# ---------------------------------------------------------------- script & shots

func capture_start() -> void:
	start_state = actors.map(func(a): return {"id": a.id, "pos": [a.pos.x, a.pos.y, a.pos.z], "yaw": a.yaw, "behavior": a.base_behavior})


## Puts the cast back where the scene starts and reseeds the simulation so
## every take of the same scene plays out identically.
func reset_to_start() -> void:
	for s in start_state:
		var a := actor_by_id(int(s.get("id", -1)))
		if a == null:
			continue
		var p: Array = s["pos"]
		a.pos = Vector3(p[0], p[1], p[2])
		a.vel = Vector3.ZERO
		a.yaw = s["yaw"]
		a.goto = {}
		a.speak_t = 0
		a.set_behavior(s["behavior"])
		a.home = a.pos
		a.t = 0.0
		a.wait = 0.5
		a.next_line = 3.0
		a.turn_t = 0.0
	App.sim_rng.seed = scene_seed
	play_t = 0.0
	_fired.clear()


func play_scene(on: bool) -> void:
	playing = on
	if on:
		reset_to_start()


func _run_cues(dt: float) -> void:
	if not playing:
		return
	play_t += dt
	for i in cues.size():
		var c: Dictionary = cues[i]
		var a := actor_by_name(str(c.get("actor", "")))
		if a == null:
			continue
		var s: float = float(c.get("start", 0))
		var e: float = s + float(c.get("dur", 3))
		var action: String = c.get("action", "idle")
		var active := play_t >= s and play_t < e
		if active and not _fired.has(i):
			_fired[i] = true
			match action:
				"say":
					a.say(str(c.get("text", "...")), float(c.get("dur", 3)))
				"walkto", "runto":
					a.goto = {"x": float(c.get("x", a.pos.x)), "z": float(c.get("z", a.pos.z)), "run": action == "runto"}
				_:
					a.set_behavior(action, false)
		elif not active and _fired.get(i, false) == true and play_t >= e:
			_fired[i] = false
			if action != "say" and action != "walkto" and action != "runto":
				a.set_behavior(a.base_behavior, false)


func script_length() -> float:
	var t := 0.0
	for c in cues:
		t = maxf(t, float(c.get("start", 0)) + float(c.get("dur", 3)))
	return t


func apply_shot(shot: Dictionary) -> void:
	var target := actor_by_name(str(shot.get("target", "")))
	camera.cine["target"] = target.id if target else 0
	var mode: String = shot.get("mode", "cine")
	if mode == "cine":
		camera.cine["shot"] = shot.get("shot", "orbit")
		camera.cine["dur"] = float(shot.get("cycle", shot.get("dur", 6.0)) ) * (2.0 if shot.get("shot", "") in ["dolly", "crane", "push"] else 1.0)
		camera.cine["dist"] = float(shot.get("dist", 6))
		camera.cine["height"] = float(shot.get("height", 2.2))
		if shot.has("points") and (shot["points"] as Array).size() >= 2:
			camera.cine["points"] = shot["points"]
		camera.mode = "cine"
		camera.cine_reset()
	else:
		camera.set_mode(mode)


func export_film() -> bool:
	if shots.is_empty():
		App.toast("Add at least one shot first.")
		return false
	reset_to_start()
	playing = not cues.is_empty()
	var vs := get_viewport().get_visible_rect().size
	var ok := recorder.start(App.export_size(vs.x / vs.y), int(App.settings["fps"]), shots)
	if ok:
		recording_changed.emit(true)
	return ok


func start_take() -> bool:
	if App.settings.get("restart", true) and camera.mode == "cine":
		camera.cine_reset()
	if not cues.is_empty():
		play_scene(true)
	var vs := get_viewport().get_visible_rect().size
	var ok := recorder.start(App.export_size(vs.x / vs.y), int(App.settings["fps"]))
	if ok:
		recording_changed.emit(true)
	return ok


func stop_take() -> void:
	recorder.stop()


# ---------------------------------------------------------------- loop

func _update_player(dt: float) -> void:
	var a := player
	if a == null:
		return
	var mv := input_move
	var cam_free := camera.mode == "free"
	var yaw_ref := camera.yaw_now() if camera.mode == "cine" else camera.yaw
	var speed := 0.0
	if not cam_free and mv.length() > 0.05:
		var f := Vector2(-sin(yaw_ref), -cos(yaw_ref))
		var r := Vector2(cos(yaw_ref), -sin(yaw_ref))
		var dx := f.x * mv.y + r.x * mv.x
		var dz := f.y * mv.y + r.y * mv.x
		var l := maxf(sqrt(dx * dx + dz * dz), 0.0001)
		speed = (1.6 if input_sprint else 4.6) * minf(1.0, mv.length())
		a.vel.x = dx / l * speed
		a.vel.z = dz / l * speed
		if camera.mode != "first":
			var want := atan2(dx, dz)
			a.yaw += clampf(U.wrap_a(want - a.yaw), -12 * dt, 12 * dt)
	else:
		a.vel.x = 0
		a.vel.z = 0
	if camera.mode == "first":
		a.yaw = camera.yaw + PI
	if input_jump and a.on_ground and not cam_free:
		a.vel.y = 7.6
	var was := a.blocked
	a.move_body(dt)
	if world.is_voxel and App.device["auto_jump"] and a.blocked and a.on_ground and speed > 0.5 and was:
		a.vel.y = 7.6
	if camera.mode == "third":
		a.hy = clampf(U.wrap_a(camera.yaw + PI - a.yaw), -1, 1)
		a.hp = clampf(camera.pitch * 0.5, -0.5, 0.5)
	else:
		a.hy = 0
		a.hp = 0


func _process(delta: float) -> void:
	if world == null or not in_studio:
		return
	var dt := App.fixed_dt if App.fixed_dt > 0.0 else minf(delta, 0.05)
	_time += dt
	_run_cues(dt)
	_update_player(dt)
	for a in actors:
		if a != player:
			a.update_npc(dt)
	_separate()
	for a in actors:
		a.animate(dt, a == player)
	if player and is_instance_valid(player.root()):
		player.root().visible = camera.mode != "first"
	camera.move_input = input_move if camera.mode == "free" else Vector2.ZERO
	camera.update_camera(dt)
	_hide_actors_near_camera()
	atmo.tick(dt, camera.global_position)
	world.animate(dt, _time)
	recorder.tick(dt)
	if dirty and not recorder.active:
		_save_t -= delta
		if _save_t <= 0:
			save_now()


func _hide_actors_near_camera() -> void:
	var cp := camera.global_position
	for a in actors:
		if a.rig.is_empty() or (a == player and camera.mode == "first"):
			continue
		var dx := cp.x - a.pos.x
		var dz := cp.z - a.pos.z
		var top := a.pos.y + a.height() + 0.2
		a.root().visible = not (dx * dx + dz * dz < 0.64 and cp.y > a.pos.y - 0.2 and cp.y < top)
