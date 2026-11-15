extends Node
## Triggers: walking into an area, touching a character or an object, who
## sets them off, who reacts and how, first time only or every time, saved,
## renamed with the character, reset each take and replayed the same. Every
## style.

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
		studio.in_studio = false
		_style(studio, style)
	print("FAILS: ", fails)
	get_tree().quit(1 if fails > 0 else 0)


func _put(studio: Studio, a: Actor, x: float, z: float) -> void:
	var s := studio.find_spot(x, z)
	var zz := PixelWorld.LANE if studio.is_side() else s.y
	a.pos = Vector3(s.x, studio.world.ground_at(s.x, zz), zz)
	a.home = a.pos
	a.vel = Vector3.ZERO


func _run(studio: Studio, secs: float) -> void:
	for i in int(secs / DT):
		studio._sim_step(DT)


func _style(studio: Studio, style: String) -> void:
	# A quiet cast: the player, a guard and a villager, nobody wandering off.
	for a in studio.actors.duplicate():
		if a != studio.player:
			studio.remove_actor(a)
	var presets := Rigs.presets_for(studio.style_key)
	var key := ""
	for k in presets:
		if presets[k].get("group", "people") == "people" and not presets[k].get("creature"):
			key = k
			break
	var guard := studio.add_actor({"name": "Guard", "look": {"preset": key}, "behavior": "idle", "x": 40.0, "z": 40.0})
	var vil := studio.add_actor({"name": "Villa", "look": {"preset": key}, "behavior": "idle", "x": 30.0, "z": 30.0})
	guard.notice = false
	vil.notice = false
	var pl := studio.player
	_put(studio, guard, 40, 40)
	_put(studio, vil, 25, 30)
	_put(studio, pl, 55, 55)
	studio.capture_start()
	var gx := guard.pos.x
	var gz := guard.pos.z
	# 1. You walk into the area: the guard calls out, once.
	studio.triggers.load_data([{"when": "enter", "who": "@player", "x": gx + 3.0, "z": gz, "r": 2.0, "actor": "Guard", "action": "say", "text": "Halt!", "dur": 2.0, "once": true}])
	studio.reset_to_start()
	_run(studio, 0.2)
	ok(guard.last_line == "", "%s: nothing before anyone's in the area" % style)
	_put(studio, vil, gx + 3.0, gz)
	_run(studio, 0.2)
	ok(guard.last_line == "", "%s: someone else doesn't set off a you-only trigger" % style)
	_put(studio, vil, 25, 30)
	_put(studio, pl, gx + 3.0, gz)
	_run(studio, 0.2)
	ok(guard.last_line == "Halt!", "%s: walking into the area makes the guard say his line" % style)
	guard.last_line = ""
	_put(studio, pl, 55, 55)
	_run(studio, 4.0)
	_put(studio, pl, gx + 3.0, gz)
	_run(studio, 0.2)
	ok(guard.last_line == "", "%s: first time only means once" % style)
	studio.reset_to_start()
	_put(studio, pl, gx + 3.0, gz)
	_run(studio, 0.2)
	ok(guard.last_line == "Halt!", "%s: and again in the next take" % style)
	# 2. Every time, with the reaction lasting its time and then ending.
	studio.triggers.list[0]["once"] = false
	studio.triggers.list[0]["action"] = "wave"
	studio.triggers.list[0]["text"] = ""
	studio.reset_to_start()
	_put(studio, pl, 55, 55)
	_run(studio, 0.2)
	_put(studio, pl, gx + 3.0, gz)
	_run(studio, 0.2)
	ok(guard.behavior == "wave", "%s: the guard waves (%s)" % [style, guard.behavior])
	_run(studio, 2.5)
	ok(guard.behavior == "idle", "%s: for its time, then back to what he was doing" % style)
	_put(studio, pl, 55, 55)
	_run(studio, 4.0)
	_put(studio, pl, gx + 3.0, gz)
	_run(studio, 0.2)
	ok(guard.behavior == "wave", "%s: every time you come back" % style)
	# 3. Touching a character: the one touched reacts.
	studio.triggers.load_data([{"when": "touch", "who": "", "target": "Guard", "actor": "@target", "action": "laugh", "text": "Ha, that tickles!", "dur": 2.0}])
	studio.reset_to_start()
	_put(studio, pl, 55, 55)
	_run(studio, 0.2)
	# Right beside him (not moved to a free spot: that could be > 1.3 m off).
	vil.pos = guard.pos + Vector3(0.9, 0, 0)
	vil.vel = Vector3.ZERO
	_run(studio, 0.2)
	ok(guard.behavior == "laugh" and guard.last_line == "Ha, that tickles!", "%s: touching the guard makes him laugh and speak" % style)
	# 4. Touching an object: whoever touched it runs off.
	studio.triggers.load_data([{"when": "touch", "who": "Villa", "x": 30.0, "z": 45.0, "label": "the well", "actor": "@who", "action": "flee", "dur": 2.0}])
	studio.reset_to_start()
	_put(studio, pl, 30.0, 45.0)
	_run(studio, 0.2)
	ok(vil.behavior != "flee", "%s: only the one named sets it off" % style)
	_put(studio, pl, 55, 55)
	_put(studio, vil, 30.0, 45.0)
	_run(studio, 0.2)
	ok(vil.behavior == "flee", "%s: touching the object makes them run" % style)
	# 5. Walk over: someone else heads to the area.
	studio.triggers.load_data([{"when": "enter", "who": "@player", "x": gx - 6.0, "z": gz, "r": 2.0, "actor": "Guard", "action": "walkto", "text": ""}])
	studio.reset_to_start()
	_put(studio, pl, gx - 6.0, gz)
	var d0 := absf(guard.pos.x - (gx - 6.0))
	_run(studio, 2.0)
	ok(absf(guard.pos.x - (gx - 6.0)) < d0 - 1.0, "%s: the guard walks over to the area" % style)
	# 6. Saved with the scene, renamed with the character, rings drawn.
	studio.triggers.load_data([{"when": "touch", "who": "Villa", "target": "Guard", "actor": "Guard", "action": "say", "text": "Hey!"}])
	studio.rename_actor(guard, "Captain")
	var t: Dictionary = studio.triggers.list[0]
	ok(t["target"] == "Captain" and t["actor"] == "Captain", "%s: renaming a character keeps their triggers" % style)
	ok(studio.triggers.get_children().filter(func(n): return not n.is_queued_for_deletion()).size() == 1, "%s: a ring shows where it is" % style)
	var d := studio.serialize()
	ok((d["triggers"] as Array).size() == 1 and int(d["v"]) == App.SCHEMA_VERSION, "%s: triggers are saved" % style)
	studio.load_data(JSON.parse_string(JSON.stringify(d)))
	studio.in_studio = false
	ok(studio.triggers.list.size() == 1 and str(studio.triggers.list[0]["text"]) == "Hey!", "%s: and load back" % style)
	ok(Triggers.describe(studio.triggers.list[0]).contains("Captain"), "%s: and read as a sentence (%s)" % [style, Triggers.describe(studio.triggers.list[0])])
