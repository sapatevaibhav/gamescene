extends Node
## Timeline mode: key storage and interpolation, seeking (deterministic, also
## backwards), keyframed characters and camera, rename and save/load.

var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		push_error("FAIL: " + what)
	else:
		print("ok   ", what)


func _ready() -> void:
	_unit()
	var studio := Studio.new()
	add_child(studio)
	await get_tree().process_frame
	await studio.new_scene("lowpoly")
	studio.in_studio = true
	await _studio(studio)
	print("FAILS: ", fails)
	get_tree().quit(1 if fails > 0 else 0)


func _unit() -> void:
	var tl := Timeline.new()
	tl.set_key("A", {"t": 4.0, "p": [10, 0, 0], "yaw": 0.0, "e": "l"})
	tl.set_key("A", {"t": 2.0, "p": [0, 0, 0], "yaw": 0.0, "e": "l"})
	ok(float(tl.track("A")[0]["t"]) == 2.0, "keys stay sorted")
	tl.set_key("A", {"t": 2.02, "p": [1, 0, 0], "yaw": 0.0, "e": "l"})
	ok(tl.track("A").size() == 2 and float(tl.track("A")[0]["p"][0]) == 1.0, "key at the same moment is replaced")
	tl.set_key("A", {"t": 2.0, "p": [0, 0, 0], "yaw": 0.0, "e": "l"})
	var mid := tl.actor_pose("A", 3.0, {})
	ok(mid["pos"].is_equal_approx(Vector3(5, 0, 0)), "linear midpoint (%s)" % mid["pos"])
	var early := tl.actor_pose("A", 1.0, {"pos": [0, 0, 8], "yaw": 0.0})
	ok(early["pos"].is_equal_approx(Vector3(0, 0, 4)), "moves from the scene start to the first key (%s)" % early["pos"])
	ok(tl.actor_pose("A", 5.0, {}).is_empty(), "track lets go after its last key")
	ok(is_equal_approx(tl.length(), 4.0), "length is the last key")
	var i := tl.move_key("A", 1, 1.0)
	ok(i == 0 and float(tl.track("A")[0]["t"]) == 1.0, "retimed key re-sorts")
	tl.rename_track("A", "B")
	ok(tl.has_track("B") and not tl.has_track("A"), "rename moves the track")
	tl.set_key(Timeline.CAM, {"t": 0.0, "p": [0, 0, 0], "q": [0, 0, 0, 1], "fov": 60.0, "e": "s"})
	tl.set_key(Timeline.CAM, {"t": 2.0, "p": [0, 4, 0], "q": [0, 0, 0, 1], "fov": 80.0, "e": "s"})
	var cp := tl.camera_pose(1.0)
	ok(is_equal_approx(cp["pos"].y, 2.0) and is_equal_approx(cp["fov"], 70.0), "smooth camera midpoint")
	ok(tl.camera_pose(0.5)["pos"].y < 1.0, "smooth easing starts slow")
	tl.remove_key("B", 0)
	tl.remove_key("B", 0)
	ok(not tl.has_track("B"), "empty track is dropped")


func _studio(studio: Studio) -> void:
	var a: Actor = null
	for x in studio.actors:
		if x != studio.player:
			a = x
			break
	studio.capture_start()
	var p0 := a.pos
	var target := Vector3(p0.x + 6.0, 0, p0.z)
	target.y = studio.world.ground_at(target.x, target.z)
	studio.timeline.set_key(a.name, {"t": 2.0, "p": [p0.x, p0.y, p0.z], "yaw": 0.0, "e": "l"})
	studio.timeline.set_key(a.name, {"t": 4.0, "p": [target.x, target.y, target.z], "yaw": 1.0, "e": "l"})
	ok(is_equal_approx(studio.script_length(), 4.0), "scene length includes keys")
	studio.seek(3.0)
	ok(studio.paused and absf(studio.play_t - 3.0) < 1e-3, "seek pauses on the playhead")
	ok(a.keyed and absf(a.pos.x - (p0.x + 3.0)) < 0.05, "keyed character at the midpoint (%.2f)" % (a.pos.x - p0.x))
	ok(a.vel.length() > 1.0, "keyed character walks (speed %.2f)" % a.vel.length())
	var snap := studio.actors.map(func(x): return x.pos)
	studio.seek(5.0)
	ok(not a.keyed and absf(a.pos.x - target.x) < 0.3, "after the last key they stay at it")
	studio.seek(3.0)
	var same := true
	for j in studio.actors.size():
		if studio.actors[j].pos.distance_to(snap[j]) > 1e-3:
			same = false
	ok(same, "seeking back replays the scene identically")
	# Playing advances the clock and keeps driving the character.
	studio.paused = false
	for k in 10:
		await get_tree().process_frame
	ok(studio.play_t > 3.0 and a.keyed, "play resumes from the playhead")
	studio.paused = true
	# Camera track.
	studio.camera.mode = "free"
	studio.camera.free_pos = Vector3(30, 12, 30)
	studio.camera.update_camera(0.016)
	studio.timeline.set_key(Timeline.CAM, Timeline.camera_key(0.0, studio.camera))
	studio.camera.free_pos = Vector3(50, 12, 30)
	studio.camera.update_camera(0.016)
	studio.timeline.set_key(Timeline.CAM, Timeline.camera_key(2.0, studio.camera))
	studio.camera.set_mode("keys")
	studio.seek(1.0)
	studio.camera.update_camera(0.016)
	ok(absf(studio.camera.global_position.x - 40.0) < 0.5, "camera follows its keys (x %.2f)" % studio.camera.global_position.x)
	ok(studio.camera.to_dict()["mode"] == "third", "keys camera mode isn't saved")
	# Rename, save and load.
	var old := a.name
	studio.cues.append({"actor": old, "action": "wave", "start": 0.0, "dur": 1.0})
	studio.rename_actor(a, "Renamed")
	ok(studio.timeline.has_track("Renamed") and studio.cues[-1]["actor"] == "Renamed", "rename updates keys and cues")
	studio.play_scene(false)
	var d := studio.serialize()
	ok(d.has("keys") and (d["keys"] as Dictionary).has("Renamed") and int(d["v"]) == 4, "keys are saved (schema v4)")
	var err := studio.load_data(JSON.parse_string(JSON.stringify(d)))
	ok(err == "" and studio.timeline.track("Renamed").size() == 2 and studio.timeline.track(Timeline.CAM).size() == 2, "keys load back")
