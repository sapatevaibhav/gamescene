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
				# A short film: a story of about 30 s with real dialogue, shots
				# that add up to it, and only the script's lines heard.
				var lines := studio.cues.filter(func(c): return c["action"] == "say")
				ok(lines.size() >= 8, "%s: %d lines of dialogue" % [what, lines.size()])
				ok(studio.script_length() >= 28.0 and studio.script_length() <= 32.0, "%s: a story of about 30 s (%.1f s)" % [what, studio.script_length()])
				var shot_len: float = studio.shots.reduce(func(acc, sh): return acc + float(sh["dur"]), 0.0)
				ok(studio.shots.size() >= 5 and absf(shot_len - 30.0) < 2.0 and str(studio.shots[0].get("title", "")) != "", "%s: %d shots, %.1f s, opening on a title" % [what, studio.shots.size(), shot_len])
				ok(studio.shots.all(func(sh): return studio.actor_by_name(str(sh["target"])) != null), "%s: every shot films someone in the cast" % what)
				ok(not App.settings["chatter"] and not App.settings["hit_lines"], "%s: no ad-lib chatter or hit lines" % what)
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
			# Plays out (cues, reactions, groups) without errors. In the 2D
			# views, the follow camera keeps whoever is saying a story line
			# on screen (Play story uses it; shots are for Export).
			studio.play_scene(true)
			var cam := studio.camera
			cam.mode = "third"
			var missed := []
			var heard := 0
			# When each character's current line started (frame), and how
			# long they had left on it a frame ago.
			var began := {}
			var last := {}
			for i in int((30.0 if t["kind"] == "scene" else 6.0) / DT):
				studio._sim_step(DT)
				if studio.is_flat():
					for a in studio.actors:
						a.animate(DT, a == studio.player)
				else:
					# Speaking timers tick in animate; the 3D check only needs
					# those, not the whole body posed.
					for a in studio.actors:
						a._tick_bubble(DT)
						if a.speak_t > 0.0:
							a.speak_t = maxf(0.0, a.speak_t - DT)
				if t["kind"] == "scene":
					cam.update_camera(DT)
				if t["kind"] == "scene":
					for a in studio.actors:
						if a.speak_t > float(last.get(a.id, 0.0)):
							began[a.id] = i
						last[a.id] = a.speak_t
					# The newest line (when two overlap, the camera goes to the
					# one who started last), judged after a second of easing.
					var newest: Actor = null
					for a in studio.actors:
						if a != studio.player and a.spotlight_t > 0.0 and a.speak_t > 0.0 and (newest == null or int(began.get(a.id, 0)) > int(began.get(newest.id, 0))):
							newest = a
					for a in studio.actors:
						if a == newest and (i - int(began.get(a.id, i))) * DT > 1.0:
							heard += 1
							var off_screen := false
							if studio.is_flat():
								var half := Vector2(cam.size * cam.get_viewport().get_visible_rect().size.aspect(), cam.size) * 0.5
								var c := Vector2(cam.global_position.x, cam.global_position.y if studio.is_side() else cam.global_position.z)
								var p := Vector2(a.pos.x, a.pos.y + 1.0 if studio.is_side() else a.pos.z)
								off_screen = absf(p.x - c.x) > half.x or absf(p.y - c.y) > half.y
							else:
								off_screen = not cam.is_position_in_frustum(Vector3(a.pos.x, a.head_y() - 0.2, a.pos.z))
							if off_screen:
								if not missed.has(a.name):
									missed.append(a.name)
			if t["kind"] == "scene":
				ok(heard > 0 and missed.is_empty(), "%s: the follow camera keeps every speaker in view (off: %s)" % [what, missed])
			# Everyone told to walk somewhere gets there (nobody stuck on a
			# bank or a tree on the way).
			var short := []
			for cu in studio.cues:
				if cu["action"] in ["walkto", "runto"]:
					var w := studio.actor_by_name(str(cu["actor"]))
					var dd := absf(w.pos.x - float(cu["x"])) if studio.is_side() else Vector2(w.pos.x - float(cu["x"]), w.pos.z - float(cu["z"])).length()
					if dd > 2.0:
						short.append("%s %.1f m off" % [w.name, dd])
			ok(short.is_empty(), "%s: every walk in the story arrives (%s)" % [what, short])
			studio.play_scene(false)
			var d := studio.serialize()
			var err := studio.load_data(JSON.parse_string(JSON.stringify(d)))
			ok(err == "" and studio.actors.size() == (d["cast"] as Array).size() and studio.fx.items.size() == (d["fx"] as Array).size(), "%s: saves and loads" % what)
	print("FAILS: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
