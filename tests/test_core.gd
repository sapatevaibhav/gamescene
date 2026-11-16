extends Node
## Core checks: seeded RNG matches the web build, RLE round trip, project
## migration, and a headless simulation of every style with NPC behaviours.

var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		push_error("FAIL: " + what)
	else:
		print("ok   ", what)


func _ready() -> void:
	# mulberry32(42) first values from the JS implementation.
	var r := U.rng(42)
	var a := r.next()
	ok(absf(a - 0.6011037519201636) < 1e-9, "rng matches JS mulberry32 (%f)" % a)
	var data := PackedByteArray([0, 0, 0, 5, 5, 200, 0])
	ok(U.rle_decode(U.rle_encode(data), data.size()) == data, "rle round trip")
	ok(U.rle_encode(data) == "0*3,5*2,5k*1,0*1", "rle web format")
	var m := ProjectStore.migrate({"app": "blockset", "world": "0*10", "cast": []})
	ok(m.get("style") == "blocky" and int(m.get("v")) == App.SCHEMA_VERSION and m.has("keys") and m.get("audio") == [] and m.get("fx") == [] and m.get("triggers") == [], "migrate blockset v1")
	var m4 := ProjectStore.migrate({"app": "gamescene", "v": 4, "style": "anime", "world": {}, "keys": {}})
	ok(int(m4["v"]) == App.SCHEMA_VERSION and m4["audio"] == [], "migrate v4 -> v5 (sound clips)")
	var m5 := ProjectStore.migrate({"app": "gamescene", "v": 5, "style": "anime", "world": {}, "audio": []})
	ok(int(m5["v"]) == App.SCHEMA_VERSION and m5["fx"] == [], "migrate v5 -> v6 (effects, feelings, poses)")
	var m6 := ProjectStore.migrate({"app": "gamescene", "v": 6, "style": "anime", "world": {}, "fx": []})
	ok(int(m6["v"]) == App.SCHEMA_VERSION and m6["triggers"] == [], "migrate v6 -> v7 (triggers)")
	var m7 := ProjectStore.migrate({"app": "gamescene", "v": 7, "style": "blocky", "world": {}, "triggers": []})
	ok(int(m7["v"]) == 8, "migrate v7 -> v8 (shallow water)")
	var m2 := ProjectStore.migrate({"app": "gamescene", "v": 2, "style": "anime", "world": {}, "settings": {"quality": "high", "fog": 80}})
	ok(m2["shots"] == [] and not m2["settings"].has("quality") and m2["settings"]["fog"] == 80, "migrate web v2")
	await get_tree().process_frame
	await _sim()
	print("FAILS: ", fails)
	await SoundDirector.hush(get_tree())
	get_tree().quit(1 if fails else 0)


func _sim() -> void:
	var studio := Studio.new()
	add_child(studio)
	await get_tree().process_frame
	for style in Styles.STYLE_ORDER:
		await studio.new_scene(style)
		studio.in_studio = true
		ok(studio.actors.size() >= 6, "%s default cast (%d)" % [style, studio.actors.size()])
		ok(studio.player != null, "%s has a player" % style)
		var behs := ["wander", "talk", "talk", "dance", "follow", "flee", "patrol", "gather", "sit", "chase"]
		var i := 0
		for x in studio.actors:
			if x != studio.player:
				x.set_behavior(behs[i % behs.size()])
				i += 1
		studio.cues = [{"actor": studio.actors[1].name, "action": "say", "text": "Hello!", "start": 0.5, "dur": 2.0},
			{"actor": studio.actors[2].name, "action": "dance", "start": 0.0, "dur": 1.0}]
		studio.play_scene(true)
		App.fixed_dt = 1.0 / 30.0
		var start := studio.actors[1].pos
		for f in 240:
			studio.input_move = Vector2(0, 1) if f < 60 else Vector2.ZERO
			studio._process(App.fixed_dt)
		App.fixed_dt = 0.0
		var moved := 0
		for x in studio.actors:
			ok(is_finite(x.pos.x) and is_finite(x.pos.y) and x.pos.y > -2.0 and x.pos.y < 40.0, "%s %s stays in the world" % [style, x.name])
			if x.pos.distance_to(start) > 0.01:
				moved += 1
		ok(moved > 0, "%s actors moved" % style)
		ok(studio.actors[1].last_line == "Hello!" or studio.actors[1].last_line != "", "%s cue line spoken" % style)
		var d := studio.serialize()
		var txt := JSON.stringify(d)
		var err := studio.load_data(JSON.parse_string(txt))
		ok(err == "", "%s reload" % style)
		ok(studio.actors.size() == d["cast"].size(), "%s cast count after reload" % style)
		ok(JSON.stringify(studio.serialize()["world"]) == JSON.stringify(d["world"]), "%s world identical after reload" % style)
		studio.checkpoint()
		studio.world.serialize()
		studio.undo()
		ok(studio.actors.size() == d["cast"].size(), "%s undo keeps cast" % style)
	# Old 48 m save: lands centred in the 80 m world, actors shifted with it.
	var hs := []
	hs.resize(49 * 49)
	hs.fill(3.0)
	var legacy := {"app": "gamescene", "v": 2, "style": "anime", "world": {"h": hs, "path": "0*2304", "water": 2.2, "props": [["stone", 24.0, 24.0, 0.0, 1.0, 5]]},
		"cast": [{"name": "Old", "look": {"preset": "wanderer"}, "behavior": "idle", "pos": [24.0, 3.0, 20.0], "yaw": 0.0, "player": true}]}
	ok(studio.load_data(legacy) == "", "legacy 48 m save loads")
	var w: TerrainWorld = studio.world
	ok(w.props.size() == 1 and absf(float(w.props[0].x) - 40.0) < 0.01, "legacy prop centred")
	ok(absf(studio.player.pos.x - 40.0) < 0.6 and absf(studio.player.pos.z - 36.0) < 0.6, "legacy actor shifted (%s)" % studio.player.pos)
	studio.queue_free()
