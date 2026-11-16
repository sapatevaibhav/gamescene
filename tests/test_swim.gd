extends Node
## Swimming in every world: characters float with the head above deep water,
## move slower, show a swim pose, and climb back out. Also: pets start beside
## the player.

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
	await _terrain(studio, "anime")
	await _terrain(studio, "lowpoly")
	await _voxel(studio)
	await _side(studio)
	await _pets(studio)
	await _sculpt(studio)
	print("FAILS: ", fails)
	await SoundDirector.hush(get_tree())
	get_tree().quit(1 if fails > 0 else 0)


func _tick(studio: Studio, frames: int) -> void:
	for i in frames:
		studio._process(1.0 / 60.0)


## Digs the ground down below the water line with the ground tool (as a user
## would) until it's deep enough to swim; returns the spot.
func _deep(w: TerrainWorld) -> Vector3:
	var x := 14.5
	var z := 60.5
	for i in 600:
		if w.terrain_h(x, z) < w.water - 2.2:
			break
		w.brush(x, z, "lower", 0.05)
	if w.water_surface(Vector3(x, 0, z)) < -1e8:
		return Vector3.ZERO
	return Vector3(x, w.terrain_h(x, z), z)


func _terrain(studio: Studio, style: String) -> void:
	await studio.new_scene(style)
	studio.in_studio = true
	var w: TerrainWorld = studio.world
	var spot := _deep(w)
	ok(spot != Vector3.ZERO, "%s: dug a pond deep enough to swim (%.1f m)" % [style, w.water - w.terrain_h(spot.x, spot.z)])
	if spot == Vector3.ZERO:
		return
	var p := studio.player
	p.pos = spot
	p.vel = Vector3.ZERO
	_tick(studio, 90)
	ok(p.swimming, "%s: deep water means swimming" % style)
	var head := p.head_y()
	ok(head > w.water + 0.05 and p.pos.y > w.terrain_h(p.pos.x, p.pos.z) + 0.2, "%s: floats with the head above water (head %.2f, water %.2f)" % [style, head, w.water])
	ok(not w.body_blocked(p.pos) or w.prop_hit(p.pos.x, p.pos.z, p.pos.y), "%s: deep water itself doesn't block any more" % style)
	ok(not w.walkable(spot.x, spot.z), "%s: NPCs still keep out of the water" % style)
	# The follow camera stays behind the swimmer (not pulled into their head).
	var cam := studio.camera
	cam.set_mode("third")
	cam.dist = 6.0
	cam.pitch = 0.3
	var close := 0
	for k in 60:
		_tick(studio, 1)
		if cam.global_position.distance_to(Vector3(p.pos.x, p.head_y(), p.pos.z)) < 2.0:
			close += 1
	ok(close < 6, "%s: the follow camera stays back while swimming (%d of 60 frames too close)" % [style, close])


func _voxel(studio: Studio) -> void:
	await studio.new_scene("blocky")
	studio.in_studio = true
	var w: VoxelWorld = studio.world
	# Flat ground (water flows now: in a random world the pool could spill
	# out where the ground beside it is lower). Dig a 3-deep pool and fill it.
	w.generate("flat")
	w.rebuild()
	var water: int = Blocks.ID["water"]
	var gy := w.ground_y(20.5, 20.5)
	for y in range(gy - 3, gy):
		for z in range(18, 34):
			for x in range(18, 24):
				w.set_b(x, y, z, water)
	var p := studio.player
	p.pos = Vector3(20.5, gy - 3, 20.5)
	p.vel = Vector3.ZERO
	_tick(studio, 90)
	ok(p.swimming, "blocky: swims in a deep pool")
	ok(p.head_y() > gy, "blocky: head above the water (head %.2f, surface %d)" % [p.head_y(), gy])
	p.animate(0.05, true)
	ok(absf((p.rig["armL"] as Node3D).rotation.z) > 0.2, "blocky: treading water, arms sweep")
	# Swim along: stays upright (never lies flat), leaning in gently.
	studio.input_move = Vector2(0, 1)
	var leans := []
	for k in 25:
		_tick(studio, 1)
		leans.append((p.rig["upper"] as Node3D).rotation.x)
	var model_tilt := (p.rig["model"] as Node3D).rotation.x
	ok(p.swimming and absf(model_tilt) < 0.01, "blocky: swims upright (body tilt %.2f)" % model_tilt)
	ok(float(leans[-1]) > 0.25, "blocky: leans into the stroke (%.2f)" % float(leans[-1]))
	var jumps := 0.0
	for k in range(1, leans.size()):
		jumps = maxf(jumps, absf(float(leans[k]) - float(leans[k - 1])))
	ok(jumps < 0.08, "blocky: the lean eases in, no snap (biggest step %.3f)" % jumps)
	ok(p.head_y() > gy, "blocky: head stays above the water while swimming")
	studio.input_move = Vector2.ZERO


func _side(studio: Studio) -> void:
	await studio.new_scene("pixel")
	studio.in_studio = true
	var w: PixelWorld = studio.world
	# A deep tank of water dug into the flat village street.
	var gy := w.ground_y(32)
	for y in range(gy - 4, gy):
		for x in range(30, 36):
			w.fg[w.idx(x, y)] = PixelTiles.ID["water"]
	w.rebuild()
	var p := studio.player
	p.pos = Vector3(32.5, gy - 4, PixelWorld.LANE)
	p.vel = Vector3.ZERO
	_tick(studio, 90)
	ok(p.swimming and p.head_y() > gy, "side view: floats up and swims (head %.2f, surface %d)" % [p.head_y(), gy])
	p.animate(0.05, true)
	var f: Vector2 = (p.rig["mat"] as ShaderMaterial).get_shader_parameter("frame")
	ok(PixelSprites.FRAMES[int(f.y) * PixelSprites.COLS + int(f.x)].begins_with("tread"), "side view: treading water when still")
	p.vel = Vector3(3, 0, 0)
	p.animate(0.05, true)
	f = (p.rig["mat"] as ShaderMaterial).get_shader_parameter("frame")
	ok(PixelSprites.FRAMES[int(f.y) * PixelSprites.COLS + int(f.x)].begins_with("swim"), "side view: swimming along shows the stroke frame")
	var sheet := PixelSprites.sheet_for(PixelSprites.cfg_for({"preset": "hero"})).get_image()
	var si := PixelSprites.FRAMES.find("swim0")
	var used := sheet.get_region(Rect2i((si % PixelSprites.COLS) * 32, (si / PixelSprites.COLS) * 32, 32, 32)).get_used_rect()
	ok(used.end.y <= 23 and used.size.y > 12, "the swim frame is upright, cut at the waterline (plus its outline) (%d × %d px)" % [used.size.x, used.size.y])
	p.vel = Vector3.ZERO
	# Swim right to the edge and climb out.
	studio.input_move = Vector2(1, 0)
	_tick(studio, 180)
	studio.input_move = Vector2.ZERO
	ok(not p.swimming and p.pos.x > 36.0 and p.pos.y >= gy - 0.01, "side view: climbs out onto the bank (x %.1f, y %.1f)" % [p.pos.x, p.pos.y])


func _pets(studio: Studio) -> void:
	for style in Styles.STYLE_ORDER:
		await studio.new_scene(style)
		var pl := studio.player
		for a in studio.actors:
			if a != pl and a.base_behavior == "follow" and Rigs.presets_for(style).get(str(a.look.get("preset", "")), {}).get("group", "") == "animals":
				var d := Vector2(a.pos.x - pl.pos.x, a.pos.z - pl.pos.z).length()
				ok(d > 0.6 and d < 3.0, "%s: %s starts a step beside the player (%.1f m)" % [style, a.name, d])
		var shared := false
		for i in studio.actors.size():
			for j in range(i + 1, studio.actors.size()):
				if studio.actors[i].pos.distance_to(studio.actors[j].pos) < 0.3:
					shared = true
		ok(not shared, "%s: nobody starts on the same spot" % style)


## Sculpting the ground rebuilds only the chunks under the brush, and the
## chunked ground matches the heightmap.
func _sculpt(studio: Studio) -> void:
	await studio.new_scene("anime")
	var w: TerrainWorld = studio.world
	ok(w._chunks.size() == TerrainWorld._nc() * TerrainWorld._nc(), "ground is split into chunks (%d)" % w._chunks.size())
	w.brush(30.0, 30.0, "raise", 0.05)
	ok(w._dirty_chunks.size() > 0 and w._dirty_chunks.size() <= 9, "a brush stroke touches only a few chunks (%d)" % w._dirty_chunks.size())
	var t0 := Time.get_ticks_usec()
	w._rebuild_dirty()
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("     stroke rebuild %.1f ms" % ms)
	ok(w._dirty_chunks.is_empty(), "and rebuilds just those")
	var c := (30 / TerrainWorld.CH) * TerrainWorld._nc() + 30 / TerrainWorld.CH
	var arr := (w._chunks[c].mesh as ArrayMesh).surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var match_ok := true
	for v in verts:
		match_ok = match_ok and absf(v.y - w.hv(int(v.x), int(v.z))) < 1e-4
	ok(match_ok, "the rebuilt chunk follows the new heights")
