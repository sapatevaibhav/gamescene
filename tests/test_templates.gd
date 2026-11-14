extends Node
## Templates: every world layout and ready-made scene in every style builds,
## puts its cast on open ground, sets up what it promises (effects,
## feelings, story moments, night), plays without errors and saves.

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
		var list := Templates.for_style(style)
		var keys := list.map(func(t): return t["key"])
		ok(keys.has("scene:village") and keys.has("scene:campfire") and keys.has("world:forest") and keys.has("world:city"), "%s: offers scenes and worlds (%s)" % [style, ", ".join(PackedStringArray(keys))])
		await studio.new_scene(style)
		var plain := JSON.stringify(studio.world.serialize())
		for t in list:
			var t0 := Time.get_ticks_msec()
			await studio.new_scene(style, Templates.layout_of(t["key"]))
			Templates.apply(studio, t["key"])
			studio.in_studio = false
			var ms := Time.get_ticks_msec() - t0
			var what := "%s %s" % [style, t["key"]]
			ok(JSON.stringify(studio.world.serialize()) != plain or Templates.layout_of(t["key"]) == "", "%s: builds its own world (%d ms)" % [what, ms])
			# Open ground: nothing in the way where they stand, and (indoors)
			# on the floor, not up on the roof.
			var indoor: bool = studio.world.is_voxel and Templates.layout_of(t["key"]) == "indoor"
			var stuck := studio.actors.filter(func(a): return studio.world.body_blocked(a.pos) or (indoor and a.pos.y > Templates.HALL_FLOOR + 0.5))
			ok(stuck.is_empty(), "%s: everyone stands on open ground (%s)" % [what, stuck.map(func(a): return a.name)])
			var names := {}
			for a in studio.actors:
				names[a.name] = true
			ok(names.size() == studio.actors.size(), "%s: everyone has their own name" % what)
			if t["kind"] == "scene":
				ok(studio.actors.size() >= 5, "%s: a cast of %d" % [what, studio.actors.size()])
				ok(not studio.cues.is_empty() and studio.cues.all(func(c): return studio.actor_by_name(str(c["actor"])) != null), "%s: story moments for the cast" % what)
				ok(studio.actors.any(func(a): return not a.rel.is_empty()), "%s: some feelings between them" % what)
			match t["key"]:
				"scene:campfire":
					ok(studio.fx.items.any(func(it): return it["k"] == "fire") and App.settings["time"] > 19.0, "%s: a campfire at night" % what)
					ok(studio.actors.filter(func(a): return a.base_behavior == "gather").size() >= 4, "%s: gathered round it" % what)
				"scene:party":
					ok(studio.actors.filter(func(a): return a.base_behavior == "dance").size() == 6, "%s: six dancers" % what)
				"scene:monsters":
					ok(studio.actors.filter(func(a): return a.is_monster()).size() >= 2, "%s: monsters" % what)
				"scene:journey":
					ok(App.settings["weather"] == "snow", "%s: snowing" % what)
			# Plays out (cues, reactions, groups) without errors.
			studio.play_scene(true)
			for i in int(6.0 / DT):
				studio._sim_step(DT)
			studio.play_scene(false)
			var d := studio.serialize()
			var err := studio.load_data(JSON.parse_string(JSON.stringify(d)))
			ok(err == "" and studio.actors.size() == (d["cast"] as Array).size() and studio.fx.items.size() == (d["fx"] as Array).size(), "%s: saves and loads" % what)
	print("FAILS: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
