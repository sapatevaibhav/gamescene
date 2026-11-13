extends Node
## Living scenes: hang-out circles, reactions to what happens nearby,
## feelings (friends, rivals, fears), running from monsters, campfires and
## other effects, and held poses with the pose library. Every style.

const Fx := preload("res://tests/fixtures.gd")
const DT := 1.0 / 30.0

var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		push_error("FAIL: " + what)
	else:
		print("ok   ", what)


func _ready() -> void:
	var studio := Studio.new()
	add_child(studio)
	await get_tree().process_frame
	for style in Styles.STYLE_ORDER:
		await studio.new_scene(style)
		studio.in_studio = false  # stepped by hand
		App.settings["reactions"] = true
		_groups(studio, style)
		_reactions(studio, style)
		_feelings(studio, style)
		_fire(studio, style)
		_effects_saved(studio, style)
		_poses(studio, style)
		_deterministic(studio, style)
	_library()
	await _model_pose(studio)
	print("FAILS: ", fails)
	get_tree().quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- helpers

## Only the player (far off in a corner) and the given new characters.
func _cast(studio: Studio, specs: Array) -> Array:
	for a in studio.actors.duplicate():
		if a != studio.player:
			studio.remove_actor(a)
	studio.fx.clear()
	_put(studio, studio.player, 8.0, 8.0)
	var out := []
	var presets := Rigs.presets_for(studio.style_key)
	for sp in specs:
		var key := ""
		for k in presets:
			var grp: String = sp.get("group", "people")
			if presets[k].get("group", "people") == grp and (grp != "people" or not presets[k].get("creature")):
				key = k
				break
		if key == "":
			out.append(null)
			continue
		var a := studio.add_actor({"name": sp["name"], "look": {"preset": key}, "behavior": sp.get("b", "idle"), "x": sp["x"], "z": sp["z"]})
		a.notice = false
		_put(studio, a, sp["x"], sp["z"])
		out.append(a)
	studio.capture_start()
	return out


func _put(studio: Studio, a: Actor, x: float, z: float) -> void:
	var s := studio.find_spot(x, z)
	var zz := PixelWorld.LANE if studio.is_side() else s.y
	a.pos = Vector3(s.x, studio.world.ground_at(s.x, zz), zz)
	a.home = a.pos
	a.vel = Vector3.ZERO


func _run(studio: Studio, secs: float) -> void:
	for i in int(secs / DT):
		studio._sim_step(DT)
		for a in studio.actors:
			a.animate(DT, a == studio.player)


func _d(a: Actor, b) -> float:
	var p: Vector3 = b.pos if b is Actor else b
	return Vector2(a.pos.x - p.x, a.pos.z - p.z).length()


# ---------------------------------------------------------------- groups

func _groups(studio: Studio, style: String) -> void:
	var c := _cast(studio, [{"name": "A", "b": "group", "x": 38.0, "z": 40.0}, {"name": "B", "b": "group", "x": 41.0, "z": 41.0},
		{"name": "C", "b": "group", "x": 40.0, "z": 37.5}, {"name": "D", "b": "group", "x": 30.0, "z": 30.0}])
	studio.reset_to_start()
	_run(studio, 6.0)
	var a: Actor = c[0]
	ok(not a.circle.is_empty(), "%s: a hanger-out joins a circle" % style)
	var mem: Array = a.circle.get("m", [])
	ok(mem.size() >= 3 and mem.has(c[1]) and mem.has(c[2]), "%s: the three close together share one circle (%d)" % [style, mem.size()])
	var seated := 0
	for m in mem:
		var slot: Vector2 = a.circle["slots"][m.id]
		if Vector2(slot.x - m.pos.x, slot.y - m.pos.z).length() < 0.7:
			seated += 1
	ok(seated == mem.size(), "%s: everyone reached their place (%d of %d)" % [style, seated, mem.size()])
	var spoke := false
	for i in 8:
		_run(studio, 0.5)
		spoke = spoke or a.circle.get("speaker") != null
	ok(spoke, "%s: they take turns to talk" % style)
	if not studio.is_side():
		var cc: Vector3 = a.circle["c"]
		var facing := Vector2(sin(a.yaw), cos(a.yaw)).dot(Vector2(cc.x - a.pos.x, cc.z - a.pos.z).normalized())
		ok(facing > 0.5, "%s: and face the middle (%.2f)" % [style, facing])
	# Rivals never share a circle.
	var d: Actor = c[3]
	d.rel[a.name] = "rival"
	a.rel[d.name] = "rival"
	_put(studio, d, a.pos.x + 1.5, a.pos.z)
	_run(studio, 2.0)
	ok(not studio.groups.any(func(g): return (g["m"] as Array).has(a) and (g["m"] as Array).has(d)), "%s: rivals never share a circle" % style)
	a.set_behavior("idle")
	_run(studio, 0.2)
	ok(a.circle.is_empty() and not (c[1].circle.get("m", []) as Array).has(a), "%s: leaving the behaviour leaves the circle" % style)


# ---------------------------------------------------------------- reactions

func _reactions(studio: Studio, style: String) -> void:
	var c := _cast(studio, [{"name": "Hitter", "x": 40.0, "z": 40.0}, {"name": "Victim", "x": 41.0, "z": 40.0},
		{"name": "Pal", "x": 43.0, "z": 43.0}, {"name": "Foe", "x": 37.0, "z": 43.0}, {"name": "Onlooker", "x": 44.0, "z": 37.0}])
	var hitter: Actor = c[0]
	var victim: Actor = c[1]
	var pal: Actor = c[2]
	var foe: Actor = c[3]
	var onl: Actor = c[4]
	pal.rel["Victim"] = "friend"
	foe.rel["Victim"] = "rival"
	studio.reset_to_start()
	_run(studio, 0.2)
	victim.on_hit(hitter)
	_run(studio, 0.1)
	ok(pal.behavior == "fight" and pal.foe == hitter, "%s: a friend stands up for the one who was hit" % style)
	ok(foe.react_act == "laugh" and foe.react_t > 0.0, "%s: a rival laughs at them" % style)
	ok(onl.look_who == hitter, "%s: a bystander turns to look" % style)
	var d0 := _d(pal, hitter)
	_run(studio, 1.0)
	ok(_d(pal, hitter) < d0 or _d(pal, hitter) < 1.5, "%s: the friend goes for the hitter" % style)
	_run(studio, 6.0)
	ok(pal.behavior == "idle" and pal.foe == null, "%s: then goes back to what they were doing (%s)" % [style, pal.behavior])
	App.settings["reactions"] = false
	studio.reset_to_start()
	_run(studio, 0.2)
	victim.on_hit(hitter)
	_run(studio, 0.1)
	ok(pal.behavior == "idle" and foe.react_t <= 0.0, "%s: no reactions with the scene setting off" % style)
	App.settings["reactions"] = true


# ---------------------------------------------------------------- feelings

func _feelings(studio: Studio, style: String) -> void:
	var c := _cast(studio, [{"name": "Timid", "x": 40.0, "z": 40.0}, {"name": "Bully", "x": 46.0, "z": 40.0}, {"name": "Buddy", "x": 12.0, "z": 30.0}])
	var timid: Actor = c[0]
	var bully: Actor = c[1]
	var buddy: Actor = c[2]
	timid.rel["Bully"] = "scared"
	timid.rel["Buddy"] = "friend"
	studio.reset_to_start()
	_run(studio, 0.5)
	ok(timid.behavior == "idle", "%s: calm while the one they fear is away" % style)
	_put(studio, bully, timid.pos.x + 2.5, timid.pos.z)
	_run(studio, 0.2)
	ok(timid.behavior == "flee" and timid.threat == bully, "%s: runs from someone they're scared of" % style)
	var d0 := _d(timid, bully)
	_run(studio, 1.5)
	ok(_d(timid, bully) > d0 + 0.5, "%s: and gets away (%.1f → %.1f m)" % [style, d0, _d(timid, bully)])
	_run(studio, 4.0)
	_put(studio, bully, 70.0, 70.0)
	_run(studio, 3.0)
	ok(timid.behavior == "idle", "%s: settles down afterwards (%s)" % [style, timid.behavior])
	_put(studio, buddy, timid.pos.x + 2.0, timid.pos.z + (0.0 if studio.is_side() else 1.0))
	_run(studio, 0.2)
	ok(timid.react_act == "wave" and timid.look_who == buddy, "%s: greets a friend who comes close" % style)
	# Monsters on the hunt send people running.
	if Rigs.presets_for(studio.style_key).values().any(func(p): return p.get("group", "") == "mobs"):
		var m := _cast(studio, [{"name": "Villager", "x": 40.0, "z": 40.0}, {"name": "Beast", "group": "mobs", "b": "chase", "x": 43.0, "z": 40.0}])
		var v: Actor = m[0]
		var beast: Actor = m[1]
		ok(beast != null and beast.is_monster(), "%s: monsters are known as monsters" % style)
		studio.reset_to_start()
		beast.pos = v.pos + Vector3(2.5, 0, 0)
		_run(studio, 0.2)
		ok(v.behavior == "flee", "%s: people run from a monster on the hunt" % style)
		v.set_behavior("flee")
		v.threat = null
		v.temp_t = 0.0
		ok(studio.nearest_threat(v) == beast, "%s: and Run away runs from monsters too" % style)


# ---------------------------------------------------------------- fire

func _fire(studio: Studio, style: String) -> void:
	var c := _cast(studio, [{"name": "Camper", "b": "gather", "x": 40.0, "z": 48.0}, {"name": "Toasty", "x": 40.0, "z": 44.0}])
	var camper: Actor = c[0]
	var toasty: Actor = c[1]
	var at := Vector3(toasty.pos.x, toasty.pos.y, toasty.pos.z)
	ok(studio.fx.add("fire", at) == 0, "%s: a campfire can be placed" % style)
	var n := studio.fx.node(0)
	ok(n != null and n.find_children("*", "MultiMeshInstance3D", true, false).size() == 3, "%s: with flames, embers and smoke" % style)
	ok(studio.is_flat() or n.has_meta("light"), "%s: and firelight in 3D" % style)
	var fp := Vector3(studio.fx.items[0]["x"], studio.fx.items[0]["y"], studio.fx.items[0]["z"])
	studio.reset_to_start()
	_run(studio, 1.0)
	ok(_d(toasty, fp) >= 0.75, "%s: someone standing in the fire steps out (%.2f m)" % [style, _d(toasty, fp)])
	_run(studio, 8.0)
	ok(_d(camper, fp) < 3.2 and _d(camper, fp) > 0.8, "%s: Gather goes round the campfire (%.1f m)" % [style, _d(camper, fp)])
	ok(not studio.fx.blocks(80.0 - 5.0, 5.0) and studio.fx.blocks(fp.x, fp.z), "%s: wanderers keep out of the fire" % style)
	# The flicker comes from the scene clock.
	if n.has_meta("light"):
		studio.fx.animate(3.0)
		var e1: float = (n.get_meta("light") as OmniLight3D).light_energy
		studio.fx.animate(3.4)
		studio.fx.animate(3.0)
		ok(is_equal_approx(e1, (n.get_meta("light") as OmniLight3D).light_energy), "%s: firelight flickers the same at the same moment" % style)


func _effects_saved(studio: Studio, style: String) -> void:
	studio.fx.clear()
	for k in SceneFx.ORDER:
		studio.fx.add(k, Vector3(30 + SceneFx.ORDER.find(k) * 3, 0, 30))
	ok(studio.fx.items.size() == 4 and studio.fx.get_children().filter(func(n): return not n.is_queued_for_deletion()).size() == 4, "%s: every effect can be placed" % style)
	studio.checkpoint()
	studio.fx.remove_at(studio.fx.index_near(Vector3(30, 0, 30), 1.8))
	ok(studio.fx.items.size() == 3, "%s: and removed" % style)
	studio.undo()
	ok(studio.fx.items.size() == 4, "%s: undo brings it back" % style)
	var d := studio.serialize()
	ok((d["fx"] as Array).size() == 4 and int(d["v"]) == App.SCHEMA_VERSION, "%s: effects are saved with the scene" % style)
	var a := studio.actors[1] if studio.actors.size() > 1 else null
	if a:
		a.rel = {studio.player.name: "friend"}
		a.base_pose = Poses.builtin("salute")
		a.pose = a.base_pose
		d = studio.serialize()
	var err := studio.load_data(JSON.parse_string(JSON.stringify(d)))
	ok(err == "" and studio.fx.items.size() == 4 and studio.fx.items[1]["k"] == "sparkles", "%s: and load back" % style)
	if a:
		var b := studio.actor_by_name(a.name)
		ok(b.rel.get(studio.player.name, "") == "friend" and b.base_pose.get("key", "") == "salute", "%s: feelings and poses are saved too" % style)
		studio.rename_actor(studio.player, "Hero")
		ok(b.rel.get("Hero", "") == "friend", "%s: renaming someone keeps feelings about them" % style)
	studio.in_studio = false


# ---------------------------------------------------------------- poses

func _poses(studio: Studio, style: String) -> void:
	var c := _cast(studio, [{"name": "Poser", "b": "pose", "x": 40.0, "z": 40.0}])
	var a: Actor = c[0]
	a.pose = Poses.builtin("cheer")
	a.base_pose = a.pose
	studio.reset_to_start()
	_run(studio, 0.5)
	ok(a.pos.distance_to(Vector3(studio.start_state[1]["pos"][0], a.pos.y, studio.start_state[1]["pos"][2])) < 0.2, "%s: holding a pose stands still" % style)
	if a.rig.get("kind", "") == "sprite":
		ok(PixelSprites.state_frame(a, 0.0)[0] == "cel1", "%s: a sprite shows its arms-up frame" % style)
	else:
		var arm: Node3D = a.rig["armR"]
		ok(arm.rotation.x < -2.5, "%s: both arms go up (%.2f)" % [style, arm.rotation.x])
	# A short reaction pose shows over the behaviour, then ends.
	a.set_behavior("idle")
	a.react("pose:surprised", 0.5)
	ok(a.shown() == "pose" and a.shown_pose().get("key", "") == "surprised", "%s: reactions can show a pose" % style)
	_run(studio, 0.7)
	ok(a.shown() == "idle", "%s: just for a moment" % style)
	# A pose cue: held for its time, then back to the scene's own.
	a.set_behavior("pose")
	a.base_pose = Poses.builtin("hips")
	a.pose = a.base_pose
	studio.capture_start()
	studio.cues = [{"actor": a.name, "action": "pose", "start": 0.5, "dur": 1.0, "pose": Poses.builtin("bow")}]
	studio.play_scene(true)
	_run(studio, 1.0)
	ok(a.pose.get("key", "") == "bow", "%s: a pose cue changes the pose" % style)
	_run(studio, 1.0)
	ok(a.pose.get("key", "") == "hips", "%s: and the scene's pose comes back after it" % style)
	studio.play_scene(false)
	studio.cues = []


func _deterministic(studio: Studio, style: String) -> void:
	var c := _cast(studio, [{"name": "A", "b": "group", "x": 38.0, "z": 40.0}, {"name": "B", "b": "group", "x": 41.0, "z": 41.0},
		{"name": "C", "b": "group", "x": 40.0, "z": 37.5}, {"name": "D", "b": "fight", "x": 44.0, "z": 44.0}, {"name": "E", "b": "wander", "x": 45.0, "z": 42.0}])
	c[0].rel["B"] = "friend"
	c[4].rel["D"] = "scared"
	var runs := []
	for k in 2:
		studio.reset_to_start()
		_run(studio, 8.0)
		runs.append(studio.actors.map(func(a): return "%.3f,%.3f,%s" % [a.pos.x, a.pos.z, a.behavior]))
	ok(runs[0] == runs[1], "%s: groups and reactions replay the same every take" % style)


# ---------------------------------------------------------------- library

func _library() -> void:
	ok(Poses.FILE.begins_with("user://test_projects/"), "the pose library goes to the test scratch folder")
	ok(Poses.library().is_empty(), "the pose library starts empty")
	var p := Poses.builtin("salute")
	Poses.set_joint(p, "upperArmR", Vector2(-1.0, 1.2))
	ok(not p.has("sprite"), "an edited pose works out its own sprite frame")
	ok(Poses.save_pose("My salute", p), "a pose saves to the library")
	ok(Poses.save_pose("my salute", Poses.builtin("bow")) and Poses.library().size() == 1, "saving under the same name replaces it")
	ok(Poses.library()[0].get("spine", [0, 0])[0] > 0.5 and Poses.library()[0]["name"] == "my salute", "with the new angles")
	var m := Poses.mirrored(Poses.builtin("victory"))
	ok(Poses.joint(m, "upperArmL").x < -2.5 and Poses.joint(m, "upperArmR").x > -1.0, "mirroring swaps left and right")
	ok(Poses.delete_pose("my salute") and Poses.library().is_empty(), "and a saved pose can be deleted")
	ok(Poses.sprite_frame({"upperArmL": [-2.8, 0], "upperArmR": [-2.8, 0]}) == "cel1" and Poses.sprite_frame({"lift": -0.24, "upperLegL": [-1.5, 0], "upperLegR": [-1.5, 0]}) == "sit",
		"custom poses pick a sprite frame from the arms and legs")


## An imported humanoid holds a pose with its own bones (elbows too).
func _model_pose(studio: Studio) -> void:
	var tmp := "user://test_projects/fixtures/"
	DirAccess.make_dir_recursive_absolute(tmp)
	ok(Fx.save(Fx.build({"names": Fx.MIXAMO}), tmp + "posey.glb") == OK, "made a test character")
	var mid := ModelRig.import_file(ProjectSettings.globalize_path(tmp + "posey.glb"))
	await studio.new_scene("anime")
	studio.in_studio = false
	var a := studio.add_actor({"name": "Posey", "look": {"model": mid}, "behavior": "pose", "x": 40.0, "z": 40.0, "yaw": 0.0})
	a.notice = false
	a.pose = Poses.builtin("cheer")
	for i in 20:
		a.animate(DT, false)
	var sk: Skeleton3D = a.rig["skel"]
	var bones: Dictionary = a.rig["bones"]
	var b: int = bones["upperArmR"]
	var p0 := sk.global_transform * sk.get_bone_global_pose(b).origin
	var p1 := sk.global_transform * sk.get_bone_global_pose(ModelRig._main_child(sk, b)).origin
	ok((p1 - p0).normalized().y > 0.6, "an imported character raises its arm for the pose (%s)" % (p1 - p0).normalized())
	# After saying a line they go back to their action (talking used to
	# stick for good on imported characters).
	a.set_behavior("wave")
	a.say("Hello!", 1.0)
	ok(ModelRig._state(a, 0.0) == "talk", "an imported character talks while saying a line")
	for i in 40:
		a.animate(DT, false)
	ok(ModelRig._state(a, 0.0) == "wave", "then goes back to its action (%s)" % ModelRig._state(a, 0.0))
	# Sitting and lying rest the body on the ground (whatever the rig's hip
	# height), not at a fixed drop that left long-legged models in mid-air.
	for beh in ["sit", "sleep"]:
		a.set_behavior(beh)
		for i in 20:
			a.animate(DT, false)
		var hy := (sk.global_transform * sk.get_bone_global_pose(int(bones["hips"]))).origin.y - a.pos.y
		ok(hy > 0.03 and hy < 0.22, "an imported character %s on the ground (hips %.2f m up)" % ["sits" if beh == "sit" else "lies", hy])
