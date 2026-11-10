extends Node
## Pixel 2D style: the side-on tile world, lane movement (walk, jump,
## ladders), tile painting through the real camera, buildings, sprite frames,
## the side camera, save/load and deterministic replay.

var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		push_error("FAIL: " + what)
	else:
		print("ok   ", what)


func _ready() -> void:
	_tiles()
	var studio := Studio.new()
	add_child(studio)
	await get_tree().process_frame
	await studio.new_scene("pixel")
	studio.in_studio = true
	var w: PixelWorld = studio.world
	ok(w != null and w.is_side and not w.is_voxel, "pixel scene builds a side-on world")
	ok(studio.actors.size() >= 6, "default cast (%d)" % studio.actors.size())
	var on_lane := true
	var grounded := true
	for a in studio.actors:
		on_lane = on_lane and absf(a.pos.z - PixelWorld.LANE) < 1e-3
		grounded = grounded and not w.body_blocked(a.pos)
	ok(on_lane, "everyone stands on the lane")
	ok(grounded, "nobody starts inside a wall")
	await _walk_jump(studio, w)
	await _ladder(studio, w)
	await _paint(studio, w)
	_sprites(studio)
	await _sim(studio, w)
	_content(studio)
	_save(studio)
	print("FAILS: ", fails)
	get_tree().quit(1 if fails > 0 else 0)


func _tiles() -> void:
	ok(PixelTiles.is_solid(PixelTiles.ID["grass"]) and not PixelTiles.is_solid(PixelTiles.ID["water"]), "grass is solid, water isn't")
	ok(PixelTiles.is_bg(PixelTiles.ID["window"]) and PixelTiles.is_ladder(PixelTiles.ID["ladder"]), "windows sit behind, ladders climb")
	var tex := PixelTiles.atlas()
	ok(tex.get_width() == PixelTiles.COLS * PixelTiles.PX, "tile atlas painted (%dx%d)" % [tex.get_width(), tex.get_height()])
	var img := tex.get_image()
	var r := PixelTiles.uv_rect(PixelTiles.ID["grass"])
	var c := img.get_pixel(int(r.position.x * img.get_width()) + 4, int(r.position.y * img.get_height()) + 1)
	ok(c.g > c.r and c.a > 0.9, "grass tile has green on top")


func _player_tick(studio: Studio, frames: int) -> void:
	for i in frames:
		studio._process(1.0 / 60.0)


func _walk_jump(studio: Studio, w: PixelWorld) -> void:
	var p := studio.player
	var x0 := p.pos.x
	studio.input_move = Vector2(1, 0)
	_player_tick(studio, 30)
	studio.input_move = Vector2.ZERO
	ok(p.pos.x > x0 + 1.0, "right walks right (%.2f m)" % (p.pos.x - x0))
	ok(absf(p.pos.z - PixelWorld.LANE) < 1e-3, "walking stays on the lane")
	ok(sin(p.yaw) > 0.9, "faces right after walking right")
	_player_tick(studio, 20)
	var gy := p.pos.y
	studio.input_jump = true
	_player_tick(studio, 1)
	studio.input_jump = false
	var peak := gy
	for i in 40:
		_player_tick(studio, 1)
		peak = maxf(peak, p.pos.y)
	ok(peak > gy + 0.8, "jumps (%.2f m high)" % (peak - gy))
	_player_tick(studio, 60)
	ok(p.on_ground and absf(p.pos.y - gy) < 0.3, "lands again")
	studio.input_move = Vector2(-1, 0)
	_player_tick(studio, 10)
	studio.input_move = Vector2.ZERO
	ok(sin(p.yaw) < -0.9, "turns to face left")


func _ladder(studio: Studio, w: PixelWorld) -> void:
	# The watchtower has a ladder in its second column.
	var lx := -1
	for x in PixelWorld.W:
		for y in PixelWorld.H:
			if PixelTiles.is_ladder(w.tile(x, y, "bg")):
				lx = x
				break
		if lx >= 0:
			break
	ok(lx >= 0, "the village has a ladder")
	if lx < 0:
		return
	var p := studio.player
	p.pos = Vector3(lx + 0.5, w.ground_at(lx + 0.5), PixelWorld.LANE)
	p.vel = Vector3.ZERO
	_player_tick(studio, 10)
	var y0 := p.pos.y
	studio.input_move = Vector2(0, 1)
	_player_tick(studio, 60)
	studio.input_move = Vector2.ZERO
	ok(p.pos.y > y0 + 1.5, "climbs the ladder (%.2f m)" % (p.pos.y - y0))
	_player_tick(studio, 5)
	var hold := p.pos.y
	_player_tick(studio, 30)
	ok(absf(p.pos.y - hold) < 0.3, "holds on to the ladder")
	p.pos = Vector3(40.5, w.ground_at(40.5), PixelWorld.LANE)
	p.on_ladder = false
	_player_tick(studio, 30)


func _paint(studio: Studio, w: PixelWorld) -> void:
	var cam := studio.camera
	cam.set_mode("free")
	cam.free_pos = Vector3(20.0, 22.0, 0)
	cam.update_camera(0.016)
	ok(cam.projection == Camera3D.PROJECTION_ORTHOGONAL, "side camera is orthographic")
	var tx := 20
	var ty := 22
	var screen := cam.unproject_position(Vector3(tx + 0.5, ty + 0.5, PixelWorld.LANE))
	studio.tools.set_tool("blocks")
	ok(studio.tools.kind == "tiles", "the build tool becomes tile painting")
	studio.tools.set_tool("tiles", {"tile": PixelTiles.ID["brick"], "mode": "place"})
	studio.tools.tap(screen)
	ok(w.tile(tx, ty) == PixelTiles.ID["brick"], "tap paints a brick where you point")
	studio.tools.set_tool("tiles", {"tile": PixelTiles.ID["window"], "mode": "place"})
	studio.tools.tap(cam.unproject_position(Vector3(tx + 1.5, ty + 0.5, PixelWorld.LANE)))
	ok(w.tile(tx + 1, ty, "bg") == PixelTiles.ID["window"] and w.tile(tx + 1, ty) == 0, "windows go on the back layer")
	studio.tools.set_tool("tiles", {"mode": "break"})
	studio.tools.tap(screen)
	ok(w.tile(tx, ty) == 0, "erase removes it")
	# Drag-painting a row.
	studio.tools.set_tool("tiles", {"tile": PixelTiles.ID["planks"], "mode": "place"})
	studio.tools.begin_paint(cam.unproject_position(Vector3(15.5, 25.5, PixelWorld.LANE)))
	for k in range(16, 20):
		studio.tools.paint(cam.unproject_position(Vector3(k + 0.5, 25.5, PixelWorld.LANE)))
	studio.tools.end_paint()
	var row := true
	for k in range(15, 20):
		row = row and w.tile(k, 25) == PixelTiles.ID["planks"]
	ok(row, "dragging paints a row of tiles")
	studio.undo()
	ok(w.tile(17, 25) == 0, "undo takes the row back")
	# Buildings.
	var gx := 70
	var gy := w.ground_y(gx)
	studio.tools.set_tool("prefab", {"pprefab": "well"})
	ok(studio.tools.kind == "pprefab", "buildings tool in pixel worlds")
	cam.free_pos = Vector3(gx, gy + 2.0, 0)
	cam.update_camera(0.016)
	studio.tools.tap(cam.unproject_position(Vector3(gx + 0.5, gy + 0.5, PixelWorld.LANE)))
	ok(w.tile(gx, gy) == PixelTiles.ID["stone"], "a well is built on the ground")
	# Erase a whole building (and keep the ground) by clicking any part of it.
	var hx := 47
	var hy := w.ground_y(hx + 2)
	var roof_tile := Vector2i(-1, -1)
	for y in range(hy, hy + 8):
		for x in range(hx, hx + 6):
			if w.tile(x, y) == PixelTiles.ID["roof"]:
				roof_tile = Vector2i(x, y)
	ok(roof_tile.x >= 0, "a cottage stands in the village")
	if roof_tile.x >= 0:
		var ground_before := w.tile(hx + 2, hy - 1)
		cam.free_pos = Vector3(roof_tile.x, roof_tile.y, 0)
		cam.update_camera(0.016)
		studio.tools.set_tool("prefab", {"pprefab": "cottage", "obj_mode": "erase"})
		studio.tools.tap(cam.unproject_position(Vector3(roof_tile.x + 0.5, roof_tile.y + 0.5, PixelWorld.LANE)))
		var left := 0
		for y in range(hy, hy + 8):
			for x in range(hx, hx + 6):
				if w.tile(x, y) == PixelTiles.ID["roof"] or w.tile(x, y, "bg") == PixelTiles.ID["wall"]:
					left += 1
		ok(left == 0, "erase clears the whole cottage (%d tiles left)" % left)
		ok(w.tile(hx + 2, hy - 1) == ground_before and ground_before != 0, "the ground under it stays")
		studio.undo()
		ok(w.tile(roof_tile.x, roof_tile.y) == PixelTiles.ID["roof"], "undo puts it back")
		# Right click removes even in place mode.
		studio.tools.set_tool("prefab", {"pprefab": "cottage"})
		studio.tools.tap(cam.unproject_position(Vector3(roof_tile.x + 0.5, roof_tile.y + 0.5, PixelWorld.LANE)), MOUSE_BUTTON_RIGHT)
		ok(w.tile(roof_tile.x, roof_tile.y) == 0, "right click removes a building")
	studio.tools.set_tool("")
	cam.set_mode("third")


func _frame_of(a: Actor) -> String:
	var f: Vector2 = (a.rig["mat"] as ShaderMaterial).get_shader_parameter("frame")
	return PixelSprites.FRAMES[int(f.y) * PixelSprites.COLS + int(f.x)]


func _sprites(studio: Studio) -> void:
	var a: Actor = null
	for x in studio.actors:
		if x != studio.player and not x.rig.get("creature", false):
			a = x
			break
	a.vel = Vector3.ZERO
	for beh in [["dance", "dance"], ["sit", "sit"], ["sleep", "sleep"], ["celebrate", "cel"], ["laugh", "laugh"], ["cry", "cry"], ["point", "point"], ["wave", "wave"], ["fight", "guard"]]:
		a.set_behavior(beh[0])
		a.speak_t = 0.0
		a.animate(0.05, false)
		ok(_frame_of(a).begins_with(beh[1]), "%s shows the %s frame (%s)" % [beh[0], beh[1], _frame_of(a)])
	a.set_behavior("idle")
	a.say("Hi!", 2.0)
	a.animate(0.05, false)
	ok(_frame_of(a).begins_with("talk"), "talking moves the mouth")
	a.speak_t = 0.0
	a.vel = Vector3(-3, 0, 0)
	a.yaw = -PI / 2
	a.animate(0.05, false)
	var flip: float = (a.rig["mat"] as ShaderMaterial).get_shader_parameter("flip")
	ok(_frame_of(a).begins_with("walk") and flip > 0.5, "walking left uses a mirrored walk frame")
	a.vel = Vector3.ZERO
	var sheet := PixelSprites.sheet_for(PixelSprites.cfg_for({"preset": "hero"})).get_image()
	var lit := 0
	for y in PixelSprites.FRAME:
		for x in PixelSprites.FRAME:
			if sheet.get_pixel(x, y).a > 0.5:
				lit += 1
	ok(lit > 120, "the hero's idle frame is painted (%d px)" % lit)
	var slime := PixelSprites.sheet_for(PixelSprites.PRESETS["slime"]).get_image()
	ok(slime.get_used_rect().size.x > 10, "critters are painted too")


func _sim(studio: Studio, w: PixelWorld) -> void:
	studio.capture_start()
	studio.seek(6.0)
	var snap := studio.actors.map(func(x): return x.pos)
	var fine := true
	for a in studio.actors:
		fine = fine and absf(a.pos.z - PixelWorld.LANE) < 1e-3 and a.pos.x > 0.5 and a.pos.x < PixelWorld.W - 0.5 and not w.body_blocked(a.pos) and a.pos.y > 1.0
	ok(fine, "after 6 s everyone is still on the lane, in the world and out of walls")
	studio.seek(2.0)
	studio.seek(6.0)
	var same := true
	for j in studio.actors.size():
		same = same and studio.actors[j].pos.distance_to(snap[j]) < 1e-3
	ok(same, "replays identically")
	studio.play_scene(false)


func _content(studio: Studio) -> void:
	ok(PixelTiles.count() - 1 >= 35, "35 tiles (%d)" % (PixelTiles.count() - 1))
	ok(PixelTiles.PREFABS.size() >= 9, "9 buildings (%d)" % PixelTiles.PREFABS.size())
	var w: PixelWorld = studio.world
	for k in PixelWorld.BACKDROPS:
		w.set_backdrop(k)
		var tex: Texture2D = w._layer_mats[0].get_shader_parameter("tex")
		ok(w.backdrop == k and tex != null and tex.get_image().get_used_rect().size.x > 0, "%s backdrop paints" % k)
	w.set_backdrop("city")
	ok(PixelWorld._glows(PixelTiles.ID["torch"]), "torches glow at night")
	var gx := 66
	w.stamp_prefab("castle", gx, w.ground_y(gx))
	ok(w.tile(gx, w.ground_y(gx) + 8) == PixelTiles.ID["mossy"], "castle tower builds")


func _save(studio: Studio) -> void:
	var w: PixelWorld = studio.world
	w.set_tile(5, 30, PixelTiles.ID["gold"])
	var d := studio.serialize()
	ok(d["style"] == "pixel" and (d["world"] as Dictionary).has("fg"), "saves the tile layers")
	var err := studio.load_data(JSON.parse_string(JSON.stringify(d)))
	ok(err == "" and (studio.world as PixelWorld).tile(5, 30) == PixelTiles.ID["gold"], "loads them back")
	ok((studio.world as PixelWorld).backdrop == "city", "the backdrop is saved")
	ok(studio.actors.size() == (d["cast"] as Array).size(), "cast comes back")
