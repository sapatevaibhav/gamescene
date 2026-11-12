extends Node
## Characters (0.18): the animation library imports a clip and plays it on a
## different rig (other bone names, A-pose instead of T-pose, rolled bone
## axes, Z-up armature) with the limbs pointing the same way; spring bones
## (hair) lag behind movement, settle back and replay exactly; faces show
## feelings for actions. Models are made in code (tests/fixtures.gd).

const Fx := preload("res://tests/fixtures.gd")

var fails := 0
var tmp := "user://test_projects/fixtures/"


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		push_error("FAIL: " + what)
	else:
		print("ok   ", what)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(tmp)
	ok(AnimLib.DIR.begins_with("user://test_projects/"), "the library goes to the test scratch folder")
	# The clip: Mixamo names, T-pose.
	ok(Fx.save(Fx.build({"names": Fx.MIXAMO, "wave": true}), tmp + "wave.glb") == OK, "made a Mixamo-style clip file")
	var lib_id := AnimLib.import_file(ProjectSettings.globalize_path(tmp + "wave.glb"))
	ok(lib_id != "", "imported it (%s)" % (lib_id if lib_id != "" else AnimLib.last_error))
	var clips := AnimLib.all_clips()
	ok(clips.size() == 1 and str(clips[0][1]) == "Wave" and absf(float(clips[0][2]) - 1.03) < 0.05, "the library lists the Wave clip (%s)" % [clips])
	var key: String = clips[0][0] if not clips.is_empty() else ""
	# The character: VRoid names, A-pose, rolled axes, Z-up, hair, face shapes.
	ok(Fx.save(Fx.build({"names": Fx.VROID, "a_pose": true, "roll": true, "z_up": true, "hair": true,
		"shapes": ["Fcl_ALL_Joy", "Fcl_ALL_Angry", "Fcl_ALL_Sorrow", "Fcl_EYE_Close"]}), tmp + "girl.glb") == OK, "made a VRoid-style character")
	var model_id := ModelRig.import_file(ProjectSettings.globalize_path(tmp + "girl.glb"))
	ok(model_id != "", "imported the character")
	var st := Studio.new()
	add_child(st)
	await get_tree().process_frame
	await st.new_scene("anime")
	st.in_studio = false  # driven by hand
	var a := st.add_actor({"name": "Kavya", "look": {"model": model_id, "anims": {"wave": key}}, "x": 40.0, "z": 40.0, "yaw": 0.0})
	a.notice = false
	_retarget(a, key)
	_springs(st, a)
	_feelings(a)
	_save(st, a, key)
	_dances_and_chat(st)
	print("FAILS: ", fails)
	get_tree().quit(1 if fails > 0 else 0)


## World position of a body slot's bone, or of its main child (the far end).
func _pt(a: Actor, slot: String, child := false) -> Vector3:
	var sk: Skeleton3D = a.rig["skel"]
	var b: int = a.rig["bones"][slot]
	if child:
		b = ModelRig._main_child(sk, b)
	return sk.global_transform * sk.get_bone_global_pose(b).origin


func _dir(a: Actor, slot: String) -> Vector3:
	return (_pt(a, slot, true) - _pt(a, slot)).normalized()


func _run(a: Actor, behavior: String, secs: float) -> void:
	a.set_behavior(behavior)
	a.vel = Vector3.ZERO
	for i in int(secs * 30):
		a.animate(1.0 / 30.0, false)


func _retarget(a: Actor, key: String) -> void:
	var bones: Dictionary = a.rig["bones"]
	ok(bones.has("upperArmR") and bones.has("lowerArmR") and bones.has("hips"), "the VRoid rig's limbs are found")
	_run(a, "idle", 0.3)
	var left_rest := _dir(a, "upperArmL")
	ok(left_rest.y < -0.5, "idle (no clip): the A-pose arms hang down (%s)" % left_rest)
	_run(a, "wave", 0.95)
	ok(ModelRig.library_clip(a, "wave") == key, "waving uses the library clip")
	var up := _dir(a, "upperArmR")
	var fore := _dir(a, "lowerArmR")
	ok(up.angle_to(Vector3.UP) < deg_to_rad(15), "the right arm swings up as in the clip (%.0f° from straight up)" % rad_to_deg(up.angle_to(Vector3.UP)))
	ok(fore.angle_to(Vector3.UP) < deg_to_rad(15), "and the forearm with it (%.0f°)" % rad_to_deg(fore.angle_to(Vector3.UP)))
	# The clip's left arm stays out to the side (T-pose), so ours does too:
	# the A-pose arm is lined up with the clip's rest pose.
	var left := _dir(a, "upperArmL")
	ok(left.angle_to(Vector3.RIGHT) < deg_to_rad(15), "the left arm follows the clip's pose, out to the side (%.0f°)" % rad_to_deg(left.angle_to(Vector3.RIGHT)))
	var hips_y := _pt(a, "hips").y - a.pos.y
	ok(absf(hips_y - 0.53 * a.height()) < 0.15 * a.height(), "the hips stay at hip height (%.2f m)" % hips_y)
	# Halfway through the clip, halfway up.
	_run(a, "idle", 0.1)
	_run(a, "wave", 0.5)
	var half := _dir(a, "upperArmR")
	var ang := rad_to_deg(half.angle_to(Vector3.UP))
	ok(ang > 30 and ang < 60, "half a second in, the arm is halfway up (%.0f° from straight up)" % ang)
	# Another action without a clip still uses the built-in pose.
	ok(ModelRig.library_clip(a, "dance") == "", "actions without a clip keep the built-in pose")
	a.look["anims"] = {"wave": "missing#0"}
	ok(ModelRig.library_clip(a, "wave") == "", "a missing clip falls back to the built-in pose")
	a.look["anims"] = {"wave": key}


func _springs(st: Studio, a: Actor) -> void:
	var sp: SpringRig = a.rig.get("springs")
	ok(sp != null and sp.joints.size() == 3, "the hair strand (J_Sec_Hair1_01..03) becomes a spring chain (%d joints)" % (sp.joints.size() if sp else 0))
	if sp == null:
		return
	ok(not SpringRig.is_spring_name("J_Bip_L_UpperArm") and SpringRig.is_spring_name("HairBack_02") and SpringRig.is_spring_name("Skirt_F_01")
		and not SpringRig.is_spring_name("HairHead_spine"), "body bones are never springs")
	st.actor_layer.add_child(a.root()) if a.root().get_parent() == null else null
	var root := a.root()
	var tip := func() -> Vector3:
		var sk: Skeleton3D = a.rig["skel"]
		var b: int = sp.joints[2]["b"]
		return sk.global_transform * sk.get_bone_global_pose(b).origin
	a.set_behavior("idle")
	a.reset_sim(a.pos, 0.0, "idle")
	for i in 30:
		a.animate(1.0 / 30.0, false)
	var settled: Vector3 = tip.call() - root.global_position
	# Dash sideways for half a second: the hair trails behind.
	var lag := 0.0
	for i in 15:
		a.pos.x += 0.12
		a.animate(1.0 / 30.0, false)
		lag = maxf(lag, ((tip.call() - root.global_position) - settled).x * -1.0)
	ok(lag > 0.02, "moving fast, the hair trails behind (%.3f m)" % lag)
	for i in 60:
		a.animate(1.0 / 30.0, false)
	var back: Vector3 = tip.call() - root.global_position
	ok(back.distance_to(settled) < 0.02, "standing still, it settles back (%.3f m off)" % back.distance_to(settled))
	# The same motion replays exactly (resumed exports depend on it).
	var runs := []
	for r in 2:
		a.reset_sim(Vector3(40, a.pos.y, 40), 0.0, "idle")
		for i in 20:
			a.pos.z += 0.08
			a.animate(1.0 / 30.0, false)
		runs.append(tip.call())
	ok((runs[0] as Vector3).distance_to(runs[1]) < 1e-4, "the hair moves the same way every time")


func _feelings(a: Actor) -> void:
	var expr: Dictionary = a.rig.get("expr", {})
	ok(expr.has("joy") and expr.has("angry") and expr.has("sorrow") and not str(expr).contains("Close"), "face shapes found for joy, anger and sorrow (not the eye-close shape)")
	if not expr.has("joy"):
		return
	var w := func(kind: String) -> float:
		var s: Array = expr[kind][0]
		return (s[0] as MeshInstance3D).get_blend_shape_value(int(s[1]))
	_run(a, "celebrate", 1.0)
	ok(w.call("joy") > 0.9 and w.call("sorrow") < 0.05, "celebrating looks happy (%.2f)" % w.call("joy"))
	_run(a, "cry", 1.0)
	ok(w.call("sorrow") > 0.9 and w.call("joy") < 0.05, "crying looks sad, and the smile fades (%.2f)" % w.call("sorrow"))
	_run(a, "fight", 1.0)
	ok(w.call("angry") > 0.9, "fighting looks angry")
	_run(a, "idle", 1.0)
	ok(w.call("angry") < 0.05 and w.call("joy") < 0.05, "idle is a neutral face again")


func _save(st: Studio, a: Actor, key: String) -> void:
	st.project_id = ProjectStore.new_id()
	st.project_name = "Anim test"
	var d := st.serialize()
	var cast_look: Dictionary = (d["cast"] as Array).filter(func(c): return c["name"] == a.name)[0]["look"]
	ok(str((cast_look.get("anims", {}) as Dictionary).get("wave", "")) == key, "the character's clips are saved with the scene")
	ProjectStore.save(st.project_id, d)
	var out := OS.get_cache_dir().path_join("gs-anim-export.json")
	ok(ProjectStore.export_to(st.project_id, out), "exported the scene file")
	var e: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(out))
	ok((e.get("assets", {}).get("anims", {}) as Dictionary).has(key.get_slice("#", 0)), "the exported file carries the animation clips")
	DirAccess.remove_absolute(out)


func _dances_and_chat(st: Studio) -> void:
	# Every style is a different pose, and a chosen style keeps looping.
	var sigs := {}
	for d in Actor.DANCES:
		if d[0] == "mix":
			continue
		var p := Actor.dance_pose(d[0], 1.3)
		sigs[str(p)] = d[0]
	ok(sigs.size() == Actor.DANCES.size() - 1, "%d different dance styles" % sigs.size())
	var robot_a := str(Actor.dance_pose("robot", 0.1).get("upperArmL"))
	var robot_b := str(Actor.dance_pose("robot", 8.1).get("upperArmL"))
	ok(robot_a == robot_b, "a chosen style loops (robot is still robot 8 s later)")
	var styles := {}
	for i in 9:
		styles[str(Actor.dance_pose("mix", i * 4.0 + 1.0).keys())] = true
	ok(styles.size() > 1, "mix moves through the styles")
	# Built-in characters dance the chosen style too.
	var b: Actor = st.actors[1]
	b.dance_style = "jacks"
	b.set_behavior("dance")
	b.t = 0.0
	for i in 10:
		b.animate(1.0 / 30.0, false)
	var arm: Node3D = b.rig["armL"]
	ok(absf(arm.rotation.z) > 0.5, "a built-in character does jumping jacks (arm out %.2f)" % arm.rotation.z)
	# Chat while doing a task: off by default, lines while dancing when on.
	ok(not b.chat_busy, "chatting while busy is off by default")
	# New scenes keep chatter off; this checks the per-character option.
	App.settings["chatter"] = true
	b.lines = ["La la la!"]
	var said := func(on: bool) -> int:
		b.chat_busy = on
		b.reset_sim(b.pos, b.yaw, "dance")
		var n := 0
		for i in 360:
			b.update_npc(1.0 / 30.0)
			b.animate(1.0 / 30.0, false)
			if b.speak_t > 2.3:
				n += 1
		return n
	ok(said.call(false) == 0, "busy characters stay quiet when it's off")
	ok(said.call(true) >= 1, "and say their lines while dancing when it's on")
	var d := b.to_dict(false)
	ok(d["dance"] == "jacks" and d["chat"] == true, "dance style and chatting are saved")
	var c := st.add_actor({"name": "Copy", "look": b.look, "dance": d["dance"], "chat": d["chat"], "x": 30.0, "z": 30.0})
	ok(c.dance_style == "jacks" and c.chat_busy, "and loaded back")
	st.remove_actor(c)
