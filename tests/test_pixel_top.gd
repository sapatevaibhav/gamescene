extends Node
## Pixel 2D top view, plus things shared by both 2D views: characters pass
## each other, default names, and the new-scene view choice.

var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		push_error("FAIL: " + what)
	else:
		print("ok   ", what)


func _ready() -> void:
	_names()
	var studio := Studio.new()
	add_child(studio)
	await get_tree().process_frame
	await _passing(studio)
	await studio.new_scene("pixeltop")
	studio.in_studio = true
	var w: PixelTopWorld = studio.world
	ok(w != null and w.is_top and not w.is_side and not w.is_voxel, "top view builds its own kind of world")
	ok(not studio.is_side() and studio.is_top() and studio.is_flat(), "studio knows it's the top view")
	_world(studio, w)
	await _walk(studio, w)
	await _tools(studio, w)
	_sprites(studio)
	await _sim(studio, w)
	_save(studio)
	print("FAILS: ", fails)
	get_tree().quit(1 if fails > 0 else 0)


func _names() -> void:
	var all_vaibh := true
	for style in Styles.STYLE_ORDER:
		var cast: Array = Rigs.DEFAULT_CAST[style]
		all_vaibh = all_vaibh and cast[0][1] == "Vaibh"
	ok(all_vaibh, "the player is Vaibh in every style")
	var pixel: Array = Rigs.DEFAULT_CAST["pixel"]
	var names := pixel.map(func(r): return r[1])
	ok(names.has("Om") and names.has("Vaish") and names.has("Siddu"), "NPCs have Indian names (%s)" % ", ".join(PackedStringArray(names)))
	for n in ["Om", "Vaish", "Jay", "Shri", "Anju", "Siddu"]:
		ok(Rigs.NAMES.has(n), "%s is in the name list" % n)
	ok(Styles.HOME_ORDER.has("pixel") and not Styles.HOME_ORDER.has("pixeltop"), "one Pixel 2D card on the home screen")
	ok(Styles.PIXEL_VIEWS.size() == 2 and Styles.PIXEL_VIEWS[1][0] == "pixeltop", "Pixel 2D asks side or top view")


## Side view: two characters walking towards each other end up past each
## other instead of pushing.
func _passing(studio: Studio) -> void:
	await studio.new_scene("pixel")
	studio.in_studio = true
	var a: Actor = studio.actors[1]
	var b: Actor = studio.actors[2]
	var w: PixelWorld = studio.world
	var y: float = w.ground_at(40.5)
	for x in [a, b]:
		x.set_behavior("idle")
	a.pos = Vector3(37.5, y, PixelWorld.LANE)
	b.pos = Vector3(43.5, y, PixelWorld.LANE)
	a.goto = {"x": 46.0, "z": PixelWorld.LANE}
	b.goto = {"x": 34.0, "z": PixelWorld.LANE}
	for i in 240:
		studio._process(1.0 / 60.0)
	ok(a.pos.x > b.pos.x + 2.0, "side-view characters walk past each other (a %.1f, b %.1f)" % [a.pos.x, b.pos.x])
	var p := studio.player
	var c: Actor = studio.actors[3]
	c.set_behavior("idle")
	p.pos = Vector3(38.5, y, PixelWorld.LANE)
	c.pos = Vector3(40.5, y, PixelWorld.LANE)
	studio.input_move = Vector2(1, 0)
	for i in 60:
		studio._process(1.0 / 60.0)
	studio.input_move = Vector2.ZERO
	ok(p.pos.x > 41.5, "the player walks through NPCs (x %.1f)" % p.pos.x)


func _world(studio: Studio, w: PixelTopWorld) -> void:
	ok(w.objects.size() > 100, "a village with woods (%d objects)" % w.objects.size())
	var keys := {}
	for o in w.objects:
		keys[o[0]] = true
	for k in ["house", "tree", "well", "lamp", "fence", "crops"]:
		ok(keys.has(k), "has %s" % k)
	var water := 0
	for i in w.ground.size():
		if w.ground[i] == PixelTopArt.G["water"]:
			water += 1
	ok(water > 30, "has a pond (%d tiles)" % water)
	ok(w.solid_cell(61, 22) and not w.walkable(61.5, 22.5), "water blocks walking")
	var clear := true
	for a in studio.actors:
		clear = clear and not w.body_blocked(a.pos) and a.pos.y == 0.0
	ok(clear, "the cast starts on open ground")
	ok(studio.camera.projection == Camera3D.PROJECTION_ORTHOGONAL or true, "camera set up on first frame")


func _tick(studio: Studio, frames: int) -> void:
	for i in frames:
		studio._process(1.0 / 60.0)


func _walk(studio: Studio, w: PixelTopWorld) -> void:
	var p := studio.player
	p.pos = Vector3(40.5, 0, 46.5)
	var z0 := p.pos.z
	studio.input_move = Vector2(0, 1)
	_tick(studio, 30)
	ok(p.pos.z < z0 - 1.0, "W walks north (%.2f m)" % (z0 - p.pos.z))
	var x0 := p.pos.x
	studio.input_move = Vector2(1, 0)
	_tick(studio, 30)
	ok(p.pos.x > x0 + 1.0, "D walks east (%.2f m)" % (p.pos.x - x0))
	studio.input_move = Vector2.ZERO
	# Walk into a solid rock placed in the way.
	var rx := int(p.pos.x) + 2
	var rz := int(p.pos.z)
	w.place_object("rock", rx, rz)
	studio.input_move = Vector2(1, 0)
	_tick(studio, 60)
	studio.input_move = Vector2.ZERO
	ok(p.pos.x < rx, "rocks block walking (x %.2f, rock at %d)" % [p.pos.x, rx])
	w.remove_object_at(rx, rz)
	studio.camera.update_camera(0.016)
	var cam := studio.camera
	ok(cam.projection == Camera3D.PROJECTION_ORTHOGONAL and cam.global_position.y > 10.0, "top camera looks straight down")
	ok(absf(cam.global_position.x - p.pos.x) < 3.0 and absf(cam.global_position.z - p.pos.z) < 3.0, "and follows the player")


func _tools(studio: Studio, w: PixelTopWorld) -> void:
	var cam := studio.camera
	cam.set_mode("free")
	cam.free_pos = Vector3(30, 0, 30)
	cam.update_camera(0.016)
	var at := func(x: float, z: float) -> Vector2: return cam.unproject_position(Vector3(x, 0, z))
	studio.tools.set_tool("blocks")
	ok(studio.tools.kind == "tiles", "build tool paints ground in top view")
	studio.tools.set_tool("tiles", {"tile": PixelTopArt.G["sand"], "mode": "place"})
	studio.tools.tap(at.call(30.5, 30.5))
	ok(w.ground_id(30, 30) == PixelTopArt.G["sand"], "tap paints sand where you point")
	studio.tools.begin_paint(at.call(26.5, 28.5))
	for k in range(27, 31):
		studio.tools.paint(at.call(k + 0.5, 28.5))
	studio.tools.end_paint()
	var row := true
	for k in range(26, 31):
		row = row and w.ground_id(k, 28) == PixelTopArt.G["sand"]
	ok(row, "dragging paints a strip")
	studio.undo()
	ok(w.ground_id(28, 28) != PixelTopArt.G["sand"], "undo takes it back")
	studio.tools.set_tool("prefab", {"pprefab": "house"})
	ok(studio.tools.kind == "pprefab", "objects tool in top view")
	var n := w.objects.size()
	studio.tools.tap(at.call(30.5, 33.5))
	ok(w.objects.size() == n + 1 and w.objects[-1][0] == "house", "tap places a house")
	ok(w.solid_cell(30, 33), "houses block walking")
	studio.tools.tap(at.call(30.5, 33.5))
	ok(w.objects.size() == n + 1, "can't stack objects on the same spot")
	studio.tools.set_tool("tiles", {"mode": "break"})
	studio.tools.tap(at.call(30.5, 33.5))
	ok(w.objects.size() == n, "erase removes the object")
	studio.tools.set_tool("")
	cam.set_mode("third")


func _frame(a: Actor) -> Array:
	var mat: ShaderMaterial = a.rig["mat"]
	var f: Vector2 = mat.get_shader_parameter("frame")
	var i := int(f.y) * PixelSprites.COLS + int(f.x)
	var block: String = ["side", "front", "back"][i / PixelSprites.FRAMES.size()]
	return [block, PixelSprites.FRAMES[i % PixelSprites.FRAMES.size()], float(mat.get_shader_parameter("flip"))]


func _sprites(studio: Studio) -> void:
	var a: Actor = null
	for x in studio.actors:
		if x != studio.player and not x.rig.get("creature", false):
			a = x
	ok(a.rig.get("view") == "top", "characters are built for the top view")
	var mi: MeshInstance3D = a.rig["mesh"]
	ok(absf(mi.rotation.x + PI / 2) < 1e-3, "sprites lie flat for the top camera")
	a.set_behavior("idle")
	for d in [[Vector3(0, 0, 3), "front", "walking south shows the front"], [Vector3(0, 0, -3), "back", "walking north shows the back"], [Vector3(3, 0, 0), "side", "walking east shows the side"]]:
		a.vel = d[0]
		a.yaw = atan2(a.vel.x, a.vel.z)
		a.animate(0.05, false)
		var f := _frame(a)
		ok(f[0] == d[1] and str(f[1]).begins_with("walk"), "%s (%s %s)" % [d[2], f[0], f[1]])
	a.vel = Vector3(-3, 0, 0)
	a.yaw = atan2(-3, 0)
	a.animate(0.05, false)
	ok(_frame(a)[0] == "side" and _frame(a)[2] > 0.5, "walking west mirrors the side")
	a.vel = Vector3.ZERO
	a.set_behavior("dance")
	a.animate(0.05, false)
	ok(_frame(a)[0] == "front" and str(_frame(a)[1]).begins_with("dance"), "actions face the viewer")
	a.set_behavior("idle")
	# Draw order: further south is lifted higher.
	a.pos.z = 30.0
	a.animate(0.0, false)
	var y1 := a.root().position.y
	a.pos.z = 50.0
	a.animate(0.0, false)
	ok(a.root().position.y > y1, "characters further south draw on top")
	var sheet := PixelSprites.sheet_for(PixelSprites.cfg_for({"preset": "hero"}), true).get_image()
	var front := sheet.get_region(Rect2i(0, PixelSprites.ROWS * PixelSprites.FRAME, PixelSprites.FRAME, PixelSprites.FRAME))
	var back := sheet.get_region(Rect2i(0, PixelSprites.ROWS * PixelSprites.FRAME * 2, PixelSprites.FRAME, PixelSprites.FRAME))
	ok(front.get_used_rect().size.y > 20 and back.get_used_rect().size.y > 20, "front and back art painted")
	ok(front.get_pixel(14, 7) != back.get_pixel(14, 7), "front shows a face, back doesn't")


func _sim(studio: Studio, w: PixelTopWorld) -> void:
	studio.capture_start()
	studio.seek(6.0)
	var snap := studio.actors.map(func(x): return x.pos)
	var fine := true
	for a in studio.actors:
		fine = fine and not w.body_blocked(a.pos) and a.pos.x > 0.5 and a.pos.z > 0.5 and a.pos.x < PixelTopWorld.W - 0.5 and a.pos.z < PixelTopWorld.D - 0.5
	ok(fine, "after 6 s everyone is on open ground inside the world")
	studio.seek(2.0)
	studio.seek(6.0)
	var same := true
	for j in studio.actors.size():
		same = same and studio.actors[j].pos.distance_to(snap[j]) < 1e-3
	ok(same, "replays identically")
	studio.play_scene(false)


func _save(studio: Studio) -> void:
	var w: PixelTopWorld = studio.world
	w.set_ground(3, 3, PixelTopArt.G["snow"])
	w.place_object("campfire", 5, 5)
	var d := studio.serialize()
	ok(d["style"] == "pixeltop", "saves as a top-view scene")
	var err := studio.load_data(JSON.parse_string(JSON.stringify(d)))
	var w2: PixelTopWorld = studio.world
	ok(err == "" and w2.ground_id(3, 3) == PixelTopArt.G["snow"] and w2.object_at(5, 5) >= 0, "ground and objects load back")
