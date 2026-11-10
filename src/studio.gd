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
var sound := SoundDirector.new()
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
## Keyframes for timeline mode (actor and camera tracks).
var timeline := Timeline.new()
## Sound clips on the timeline: [{src, start, dur, vol}] (see SoundDirector).
var audio: Array = []
## Timeline clock while directing ("Play scene").
var playing := false
## Frozen on the playhead (timeline mode): only the player can move.
var paused := false
var play_t := 0.0
var _fired := {}

var input_move := Vector2.ZERO
var input_jump := false
var input_sprint := false
var input_crouch := false

var _undo: Array = []
var _redo: Array = []
var _time := 0.0
var _heard := false


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
	sound.studio = self
	add_child(sound)
	recorder.started.connect(sound.restart)
	tools = EditorTools.new()
	tools.studio = self
	add_child(tools)
	atmo.apply_quality()


# ---------------------------------------------------------------- scenes

func _clear() -> void:
	if recorder.active:
		if recorder.can_suspend():
			recorder.suspend()
		else:
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
	audio = []
	sound.stop_all()
	timeline.clear()
	start_state = []
	playing = false
	paused = false
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
	elif sty["world"] == "pixel":
		world = PixelWorld.new()
	elif sty["world"] == "pixeltop":
		world = PixelTopWorld.new()
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
	App.reset_scene_defaults()
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
	if is_side():
		# Spread along the village street, all on the one lane.
		cz = PixelWorld.LANE
		pos = [[0, 0], [-6, 0], [3, 0], [-3, 0], [8, 0], [-10, 0], [5.5, 0], [1.5, 0]]
	var presets := Rigs.presets_for(style_key)
	var cast: Array = Rigs.DEFAULT_CAST.get(style_key, [])
	for i in cast.size():
		var row: Array = cast[i]
		var preset: String = row[0]
		var p: Dictionary = presets.get(preset, {})
		var off: Array = pos[i % pos.size()]
		if i >= pos.size():
			# More cast than spots: shift the second round so nobody shares a spot.
			off = [float(off[0]) + 1.6, float(off[1]) + 1.4]
		var beh: String = row[2] if row.size() > 2 else "idle"
		if i > 0 and beh == "follow" and p.get("group", "people") == "animals":
			# Pets start a step beside the player.
			off = [float(pos[0][0]) + 1.3, float(pos[0][1]) + (0.0 if is_side() else 0.9)]
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
	var off: float = world.load_offset
	if off != 0.0:
		_shift_legacy(d, off)
	var st: Dictionary = d.get("settings", {})
	App.reset_scene_defaults()
	for k in st:
		if App.SCENE_KEYS.has(k):
			App.settings[k] = st[k]
	scene_seed = int(d.get("seed", randi() % 100000))
	App.sim_rng.seed = scene_seed
	for c in d.get("cast", []):
		var p: Array = c.get("pos", [40, 0, 40])
		add_actor({"name": c.get("name", "Someone"), "look": c.get("look", {}), "behavior": c.get("behavior", "idle"), "notice": c.get("notice", true),
			"lines": c.get("lines", []), "x": p[0], "y": p[1], "z": p[2], "yaw": c.get("yaw", 0.0), "isPlayer": c.get("player", false)})
	if player == null and not actors.is_empty():
		player = actors[0]
	if player == null:
		var presets := Rigs.presets_for(style_key)
		add_actor({"name": "You", "look": {"preset": presets.keys()[0]}, "isPlayer": true, "x": 40.0, "z": 36.0})
	camera.load_view(d.get("view", {}), d.get("cine", {}))
	cues = d.get("cues", [])
	audio = (d.get("audio", []) as Array).filter(func(c): return c is Dictionary and c.has("src"))
	timeline.load_data(d.get("keys", {}))
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


## Moves everything positioned in an old, smaller world into the centre of
## the current one.
func _shift_legacy(d: Dictionary, off: float) -> void:
	var mv := func(p: Array) -> Array: return [float(p[0]) + off, p[1], float(p[2]) + off]
	for c in d.get("cast", []):
		c["pos"] = mv.call(c.get("pos", [24, 0, 24]))
	for c in d.get("cues", []):
		if c.has("x"):
			c["x"] = float(c["x"]) + off
			c["z"] = float(c["z"]) + off
	for s in d.get("start", []):
		s["pos"] = mv.call(s.get("pos", [24, 0, 24]))
	var cine: Dictionary = d.get("cine", {})
	for pt in cine.get("points", []):
		pt["p"] = mv.call(pt.get("p", [0, 0, 0]))
	for sh in d.get("shots", []):
		for pt in sh.get("points", []):
			pt["p"] = mv.call(pt.get("p", [0, 0, 0]))


func serialize() -> Dictionary:
	var settings := {}
	for k in App.SCENE_KEYS:
		settings[k] = App.settings[k]
	return {"app": "gamescene", "v": App.SCHEMA_VERSION, "name": project_name, "style": style_key, "seed": scene_seed,
		"world": world.serialize(), "cast": actors.map(func(a): return a.to_dict(a == player)),
		"settings": settings, "cine": camera.cine_dict(), "view": camera.to_dict(),
		"cues": cues, "keys": timeline.to_data(), "audio": audio, "shots": shots, "start": start_state}


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
	if is_side():
		# Only left and right exist.
		for k in range(1, 40):
			for sgn in [1.0, -1.0]:
				var nx := clampf(x + sgn * k * 0.5, 1.5, float(Styles.SIZE) - 1.5)
				if spot_ok(nx, z):
					return Vector2(nx, z)
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


## Pixel 2D: a side-on world where everyone shares one lane.
func is_side() -> bool:
	return world != null and world.get("is_side") == true


## Pixel 2D top view.
func is_top() -> bool:
	return world != null and world.get("is_top") == true


## Either Pixel 2D view: pointed at with the mouse, never mouse-looked.
func is_flat() -> bool:
	return is_side() or is_top()


func add_actor(o: Dictionary) -> Actor:
	if actors.size() >= int(App.q()["cast"]):
		App.toast("That’s the cast limit for this device’s quality setting.")
		return null
	if is_side():
		o["z"] = PixelWorld.LANE
	if not o.has("y"):
		var s := find_spot(float(o.get("x", 40)), float(o.get("z", 40)))
		o["x"] = s.x
		o["z"] = s.y if not is_side() else PixelWorld.LANE
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


## Renames a character and everything that refers to them by name (script
## cues, keyframe track, shot subjects).
func rename_actor(a: Actor, new_name: String) -> void:
	var old := a.name
	if old == new_name:
		return
	a.name = new_name
	for c in cues:
		if str(c.get("actor", "")) == old:
			c["actor"] = new_name
	for sh in shots:
		if str(sh.get("target", "")) == old:
			sh["target"] = new_name
	timeline.rename_track(old, new_name)
	a.refresh_tag()
	mark_dirty()


# ---------------------------------------------------------------- director mode
# While the scene is paused on the playhead, edits are recorded into the
# script at that moment instead of changing the scene start.

func directing() -> bool:
	return playing and paused


## Puts a character somewhere from this moment on (a jump key).
func direct_move(a: Actor, p: Vector3) -> void:
	a.pos = p
	a.vel = Vector3.ZERO
	a.home = p
	a.goto = {}
	a.target = {}
	timeline.set_key(a.name, Timeline.actor_key(play_t, a, true))
	a.animate(0.0, a == player)
	mark_dirty()


## Starts an action for a character from this moment (a script cue).
func direct_action(a: Actor, action: String, dur := 5.0) -> void:
	var t := snappedf(play_t, 0.01)
	cues.append({"actor": a.name, "action": action, "start": t, "dur": dur})
	a.goto = {}
	a.set_behavior(action, false)
	_fired[cues.size() - 1] = true
	mark_dirty()


func set_player(a: Actor) -> void:
	if a == player:
		return
	player = a
	a.set_behavior("idle")
	mark_dirty()
	cast_changed.emit()


func spawn_near() -> Vector2:
	var b := player.pos if player else Vector3(40, 0, 40)
	var ang := randf() * TAU
	var d := 2.0 + randf() * 2.5
	var size := float(Styles.SIZE)
	return Vector2(clampf(b.x + cos(ang) * d, 1.5, size - 1.5), clampf(b.z + sin(ang) * d, 1.5, size - 1.5))


func gather_point() -> Vector3:
	if player:
		return player.pos
	return Vector3(40, 0, 40)


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
	sound.speech(a)


func _separate() -> void:
	if is_side():
		# 2D side view: one lane, so characters walk past each other.
		return
	for i in actors.size():
		for j in range(i + 1, actors.size()):
			var a := actors[i]
			var b := actors[j]
			var dx := b.pos.x - a.pos.x
			var dz := b.pos.z - a.pos.z
			var d := sqrt(dx * dx + dz * dz)
			if d < 0.62 and d > 1e-4 and absf(a.pos.y - b.pos.y) < 1.5 and not (a.keyed or b.keyed):
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
		a.reset_sim(Vector3(p[0], p[1], p[2]), float(s["yaw"]), str(s["behavior"]))
	App.sim_rng.seed = scene_seed
	play_t = 0.0
	_fired.clear()


func play_scene(on: bool) -> void:
	playing = on
	paused = false
	if on:
		reset_to_start()
	else:
		for a in actors:
			a.keyed = false


## Has anything to play: script cues or keyframes.
func has_script() -> bool:
	return not cues.is_empty() or not timeline.keys.is_empty() or not audio.is_empty()


## Jumps the scene to `t` seconds by replaying the simulation from the scene
## start (or from the current time when seeking forward) at a fixed step, so
## the result matches what playback shows. Leaves the scene paused there.
func seek(t: float) -> void:
	t = maxf(0.0, t)
	if not playing or t < play_t - 1e-4:
		reset_to_start()
		playing = true
	paused = true
	var saved := [input_move, input_jump, input_sprint, input_crouch]
	input_move = Vector2.ZERO
	input_jump = false
	input_sprint = false
	input_crouch = false
	var step := 1.0 / 30.0
	var guard := 0
	while play_t < t - 1e-5 and guard < 100000:
		_sim_step(minf(step, t - play_t))
		guard += 1
	input_move = saved[0]
	input_jump = saved[1]
	input_sprint = saved[2]
	input_crouch = saved[3]
	for a in actors:
		a.animate(step, a == player)


## Drives keyframed characters at the current time. Moving characters face
## where they're going; standing ones turn to their keyed facing.
func _apply_keys(dt: float) -> void:
	if not playing or timeline.keys.is_empty():
		return
	var starts := {}
	for s in start_state:
		starts[int(s.get("id", -1))] = s
	var prev := play_t - dt if play_t - dt > 1e-5 else -1.0
	for a in actors:
		for k in timeline.jumps_crossed(a.name, prev, play_t):
			var kp: Array = k["p"]
			a.pos = Vector3(kp[0], kp[1], kp[2])
			a.yaw = float(k.get("yaw", a.yaw))
			a.vel = Vector3.ZERO
			a.home = a.pos
			a.goto = {}
			a.target = {}
		var pose := timeline.actor_pose(a.name, play_t, starts.get(a.id, {}))
		if pose.is_empty():
			if a.keyed:
				a.keyed = false
				a.vel = Vector3.ZERO
				a.home = a.pos
			continue
		a.keyed = true
		var p: Vector3 = pose["pos"]
		var g: float = world.ground_at(p.x, p.z)
		if absf(g - p.y) < 1.2:
			p.y = g
		var v := (p - a.pos) / maxf(dt, 1e-4)
		a.vel = Vector3(v.x, 0, v.z)
		a.pos = p
		a.on_ground = true
		if Vector2(v.x, v.z).length() > 0.3:
			a.yaw += clampf(U.wrap_a(atan2(v.x, v.z) - a.yaw), -10 * dt, 10 * dt)
		else:
			a.yaw += clampf(U.wrap_a(float(pose["yaw"]) - a.yaw), -6 * dt, 6 * dt)


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
	for c in audio:
		t = maxf(t, float(c.get("start", 0)) + SoundDirector.clip_len(c))
	return maxf(t, timeline.length())


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
	elif mode == "keys" and not timeline.has_track(Timeline.CAM):
		camera.set_mode("third")
	else:
		camera.set_mode(mode)


## The film export size for the current window and settings.
func export_size() -> Vector2i:
	var vs := get_viewport().get_visible_rect().size
	return App.export_size(vs.x / vs.y)


## An unfinished film export of this scene that can carry on, or {}.
func unfinished_export() -> Dictionary:
	return Recorder.find_job(self, int(App.settings["fps"]))


## Exports the shot list from the scene start. `resume` carries on an
## unfinished export (from unfinished_export()).
func export_film(resume: Dictionary = {}) -> bool:
	if shots.is_empty():
		App.toast("Add at least one shot first.")
		return false
	reset_to_start()
	_time = 0.0
	playing = has_script()
	paused = false
	# A resumed export keeps the size it started at, whatever the window is now.
	var size := Vector2i(int(resume["w"]), int(resume["h"])) if resume.has("w") else export_size()
	var ok := recorder.start(size, int(App.settings["fps"]), shots, resume)
	if ok:
		recording_changed.emit(true)
	return ok


func start_take() -> bool:
	if App.settings.get("restart", true) and camera.mode == "cine":
		camera.cine_reset()
	if has_script():
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
	if a == null or a.keyed:
		return
	if is_side():
		_update_player_side(a, dt)
		return
	if is_top():
		_update_player_top(a, dt)
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
		# Shift sprints, Ctrl crouch-walks.
		var base := 4.6
		if input_crouch:
			base = 1.8
		elif input_sprint:
			base = 7.8
		speed = base * minf(1.0, mv.length())
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
	a.crouch = input_crouch and a.on_ground
	if input_jump and a.on_ground and not cam_free and not input_crouch:
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
		if _heard:
			sound.stop_all()
			_heard = false
		return
	_heard = true
	if recorder.holding():
		# An export on hold (paused, cooling down, or warming up): freeze.
		return
	var dt := App.fixed_dt if App.fixed_dt > 0.0 else minf(delta, 0.05)
	_time += dt
	if playing and paused:
		# Frozen on the playhead: only the one you control moves (to pose them).
		_update_player(dt)
	else:
		_sim_step(dt)
	for a in actors:
		a.animate(dt, a == player)
	if player and is_instance_valid(player.root()):
		player.root().visible = camera.mode != "first"
	camera.move_input = input_move if camera.mode == "free" else Vector2.ZERO
	camera.update_camera(dt)
	_hide_actors_near_camera()
	atmo.tick(dt, camera.global_position)
	world.animate(dt, _time)
	# Wind, water and clouds run on the scene clock, not the engine's.
	RenderingServer.global_shader_parameter_set("scene_time", _time)
	sound.tick(dt)
	recorder.tick(dt)
	if dirty and not recorder.active:
		_save_t -= delta
		if _save_t <= 0:
			save_now()


## Pixel 2D controls: left/right walk (Shift runs), up or Space jumps, up
## and down climb ladders, Ctrl crouches.
func _update_player_side(a: Actor, dt: float) -> void:
	var mv := input_move
	var cam_free := camera.mode == "free"
	var speed := 0.0
	if not cam_free and absf(mv.x) > 0.05:
		var base := 1.8 if input_crouch else (7.2 if input_sprint else 4.2)
		speed = base * minf(1.0, absf(mv.x))
		a.vel.x = signf(mv.x) * speed
		a.yaw = PI / 2 if mv.x > 0 else -PI / 2
	else:
		a.vel.x = 0.0
	var w: PixelWorld = world
	a.on_ladder = not cam_free and w.ladder_at(a.pos) and (absf(mv.y) > 0.2 or (a.on_ladder and not a.on_ground))
	if a.on_ladder:
		a.vel.y = mv.y * 3.5 if absf(mv.y) > 0.2 else 0.0
	elif not cam_free and a.on_ground and not input_crouch and (input_jump or mv.y > 0.6):
		a.vel.y = 7.6
	a.crouch = input_crouch and a.on_ground
	var was := a.blocked
	a.move_body(dt)
	# Hop up one-tile steps while walking into them (like the blocky style).
	if App.device["auto_jump"] and a.blocked and was and a.on_ground and speed > 0.5 and not a.on_ladder:
		a.vel.y = 7.6
	a.hy = 0
	a.hp = 0


## Pixel 2D top view: WASD walks north, west, south and east (Shift runs).
func _update_player_top(a: Actor, dt: float) -> void:
	var mv := input_move
	if camera.mode != "free" and mv.length() > 0.05:
		var base := 1.8 if input_crouch else (7.2 if input_sprint else 4.2)
		var d := Vector2(mv.x, -mv.y)
		var l := minf(1.0, d.length())
		d = d.normalized()
		a.vel.x = d.x * base * l
		a.vel.z = d.y * base * l
		a.yaw = atan2(d.x, d.y)
	else:
		a.vel.x = 0.0
		a.vel.z = 0.0
	a.crouch = input_crouch
	a.move_body(dt)
	# Doors: step into a house, or back out of it. Pets come along.
	var w: PixelTopWorld = world
	var dest: Variant = w.portal_at(a.pos)
	if dest is Vector3:
		var from := a.pos
		a.pos = dest
		a.vel = Vector3.ZERO
		var k := 0
		for b in actors:
			if b != a and b.behavior == "follow" and Vector2(b.pos.x - from.x, b.pos.z - from.z).length() < 8.0:
				k += 1
				b.pos = dest + Vector3(0.9 * (1 if k % 2 else -1), 0, 0.2)
				b.vel = Vector3.ZERO
				b.home = b.pos
		camera.snap_to(a.pos)


## One simulation tick: script clock, keyframes, player, NPCs, crowding.
func _sim_step(dt: float) -> void:
	_run_cues(dt)
	_apply_keys(dt)
	_update_player(dt)
	for a in actors:
		if a != player and not a.keyed:
			a.update_npc(dt)
	_separate()


func _hide_actors_near_camera() -> void:
	var cp := camera.global_position
	for a in actors:
		if a.rig.is_empty() or (a == player and camera.mode == "first"):
			continue
		var dx := cp.x - a.pos.x
		var dz := cp.z - a.pos.z
		# A sleeper lies flat: only hide them when the camera is down in them.
		var top := a.pos.y + (0.6 if a.behavior == "sleep" else a.height() + 0.2)
		a.root().visible = not (dx * dx + dz * dz < 0.64 and cp.y > a.pos.y - 0.2 and cp.y < top)


func _notification(what: int) -> void:
	# Partners point at each other; break the loop so both are freed on exit.
	if what == NOTIFICATION_PREDELETE:
		for a in actors:
			a.partner = null
