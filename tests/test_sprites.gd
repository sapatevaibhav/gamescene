extends Node
## Pixel sprite imports: PNG strips and RPG grids, and Aseprite files
## (compressed, raw and linked cels, two layers, tags) written here byte by
## byte, then used as characters and objects in both 2D views.

var fails := 0
const TMP := "user://test_projects/src/"


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		push_error("FAIL: " + what)
	else:
		print("ok   ", what)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(TMP)
	_png()
	_ase()
	await _use()
	await _tilesets()
	print("FAILS: ", fails)
	get_tree().quit(1 if fails > 0 else 0)


func _png() -> void:
	# A 4-frame strip of 16×24... no: strips are square frames.
	var strip := Image.create(64, 16, false, Image.FORMAT_RGBA8)
	strip.fill(Color(0, 0, 0, 0))
	for k in 4:
		strip.fill_rect(Rect2i(k * 16 + 4, 2, 8, 14), Color(0.2 * k, 0.5, 0.8))
	strip.save_png(TMP + "runner.png")
	var id := SpriteImport.import_file(ProjectSettings.globalize_path(TMP + "runner.png"), "char")
	ok(id != "", "imports a PNG strip")
	var m := SpriteImport.meta(id)
	ok(int(m["frames"]) == 4 and int(m["fw"]) == 16 and int(m["fh"]) == 16, "strip split into 4 frames of 16×16")
	ok((m["anims"]["walk"] as Array).size() == 4, "strip frames are the walk cycle")
	# RPG grid: 3 columns × 4 rows (down, left, right, up).
	var grid := Image.create(48, 64, false, Image.FORMAT_RGBA8)
	grid.fill(Color(0, 0, 0, 0))
	for r in 4:
		for c in 3:
			grid.fill_rect(Rect2i(c * 16 + 3, r * 16 + 1, 10, 15), Color(0.25 * r, 0.3, 0.3 * c + 0.1))
	grid.save_png(TMP + "villager_rpg.png")
	var gid := SpriteImport.import_file(ProjectSettings.globalize_path(TMP + "villager_rpg.png"), "char")
	var gm := SpriteImport.meta(gid)
	ok(gid != "" and int(gm["frames"]) == 12, "imports an RPG grid (12 frames)")
	ok(gm["anims"].has("walk:front") and gm["anims"].has("walk:back") and gm["anims"].has("walk:side"), "grid rows become directions")
	ok(SpriteImport.import_file(ProjectSettings.globalize_path(TMP + "nope.gif"), "char") == "" and SpriteImport.last_error != "", "unsupported files are refused with a reason")


# ---------------------------------------------------------------- aseprite writer

func _u16(b: PackedByteArray, v: int) -> void:
	b.append(v & 0xFF)
	b.append((v >> 8) & 0xFF)


func _u32(b: PackedByteArray, v: int) -> void:
	_u16(b, v & 0xFFFF)
	_u16(b, (v >> 16) & 0xFFFF)


func _zeros(b: PackedByteArray, n: int) -> void:
	for i in n:
		b.append(0)


func _str(b: PackedByteArray, s: String) -> void:
	var u := s.to_utf8_buffer()
	_u16(b, u.size())
	b.append_array(u)


func _chunk(type: int, data: PackedByteArray) -> PackedByteArray:
	var c := PackedByteArray()
	_u32(c, data.size() + 6)
	_u16(c, type)
	c.append_array(data)
	return c


func _layer(name: String, visible: bool) -> PackedByteArray:
	var d := PackedByteArray()
	_u16(d, 1 if visible else 0)
	_u16(d, 0)
	_u16(d, 0)
	_u16(d, 0)
	_u16(d, 0)
	_u16(d, 0)
	d.append(255)
	_zeros(d, 3)
	_str(d, name)
	return _chunk(0x2004, d)


## Cel: type 0 raw, 2 compressed, 1 linked (to `link` frame).
func _cel(layer: int, x: int, y: int, img: Image, type: int, link := 0) -> PackedByteArray:
	var d := PackedByteArray()
	_u16(d, layer)
	_u16(d, x)
	_u16(d, y)
	d.append(255)
	_u16(d, type)
	_u16(d, 0)
	_zeros(d, 5)
	if type == 1:
		_u16(d, link)
	else:
		_u16(d, img.get_width())
		_u16(d, img.get_height())
		var px := img.get_data()
		d.append_array(px if type == 0 else px.compress(FileAccess.COMPRESSION_DEFLATE))
	return _chunk(0x2005, d)


func _tags(tags: Array) -> PackedByteArray:
	var d := PackedByteArray()
	_u16(d, tags.size())
	_zeros(d, 8)
	for t in tags:
		_u16(d, t[1])
		_u16(d, t[2])
		d.append(0)
		_u16(d, 0)
		_zeros(d, 6)
		_zeros(d, 3)
		d.append(0)
		_str(d, t[0])
	return _chunk(0x2018, d)


func _frame(chunks: Array) -> PackedByteArray:
	var body := PackedByteArray()
	for c in chunks:
		body.append_array(c)
	var f := PackedByteArray()
	_u32(f, body.size() + 16)
	_u16(f, 0xF1FA)
	_u16(f, chunks.size())
	_u16(f, 100)
	_zeros(f, 2)
	_u32(f, chunks.size())
	f.append_array(body)
	return f


func _write_ase(path: String, w: int, h: int, frames: Array) -> void:
	var body := PackedByteArray()
	for fr in frames:
		body.append_array(_frame(fr))
	var head := PackedByteArray()
	_u32(head, 128 + body.size())
	_u16(head, 0xA5E0)
	_u16(head, frames.size())
	_u16(head, w)
	_u16(head, h)
	_u16(head, 32)
	_u32(head, 1)
	_u16(head, 100)
	_zeros(head, 8)
	head.append(0)
	_zeros(head, 3)
	_u16(head, 0)
	head.append(1)
	head.append(1)
	_zeros(head, 4)
	_u16(head, 16)
	_u16(head, 16)
	_zeros(head, 84)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(head + body)
	f.close()


## Same colour within one 8-bit step (files store 0-255 per channel).
func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.006 and absf(a.g - b.g) < 0.006 and absf(a.b - b.b) < 0.006 and absf(a.a - b.a) < 0.006


func _solid(w: int, h: int, c: Color) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return img


func _ase() -> void:
	var body := _solid(8, 12, Color(0.2, 0.4, 0.9))
	var hat := _solid(8, 3, Color(0.9, 0.1, 0.1))
	var frames := []
	# 6 frames: 0-1 idle, 2-5 walk; frame 1 links frame 0's body.
	for i in 6:
		var ch := []
		if i == 0:
			ch.append(_layer("Body", true))
			ch.append(_layer("Hat", true))
			ch.append(_layer("Sketch", false))
			ch.append(_tags([["Idle", 0, 1], ["walk_down", 2, 3], ["Walk_Up", 4, 5], ["dance", 2, 5]]))
		if i == 1:
			ch.append(_cel(0, 4, 4, body, 1, 0))
		else:
			ch.append(_cel(0, 4 + (i % 2), 4, body, 2 if i % 2 == 0 else 0))
		ch.append(_cel(1, 4, 1, hat, 2))
		ch.append(_cel(2, 0, 0, _solid(16, 16, Color.GREEN), 0))
		frames.append(ch)
	_write_ase(ProjectSettings.globalize_path(TMP + "hero.aseprite"), 16, 16, frames)
	var sheet := SpriteImport.read_aseprite(ProjectSettings.globalize_path(TMP + "hero.aseprite"))
	ok(not sheet.is_empty(), "reads an Aseprite file (%s)" % SpriteImport.last_error)
	if sheet.is_empty():
		return
	var fr: Array = sheet["frames"]
	ok(fr.size() == 6, "all 6 frames")
	var f0: Image = fr[0]
	ok(_near(f0.get_pixel(6, 10), Color(0.2, 0.4, 0.9)), "compressed cel pixels land in place")
	ok(_near(f0.get_pixel(6, 2), Color(0.9, 0.1, 0.1)), "upper layer draws on top")
	ok(f0.get_pixel(0, 0).a == 0.0, "hidden layer is left out")
	ok(_near((fr[1] as Image).get_pixel(6, 10), Color(0.2, 0.4, 0.9)), "linked cel reuses the frame it points to")
	ok(_near((fr[3] as Image).get_pixel(5, 10), Color(0.2, 0.4, 0.9)) and (fr[3] as Image).get_pixel(4, 10).a == 0.0, "raw cel at its own offset")
	var an: Dictionary = sheet["anims"]
	ok(an.get("idle") == [0, 1], "Idle tag -> idle")
	ok(an.get("walk:front") == [2, 3] and an.get("walk:back") == [4, 5], "walk_down / Walk_Up -> top-view directions")
	ok(an.get("dance") == [2, 3, 4, 5], "dance tag")
	var id := SpriteImport.import_file(ProjectSettings.globalize_path(TMP + "hero.aseprite"), "char")
	ok(id != "" and FileAccess.file_exists(SpriteImport.dir() + id + ".png"), "imported as a sprite sheet")
	var bad := FileAccess.open(TMP + "bad.ase", FileAccess.WRITE)
	bad.store_buffer(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8]))
	bad.close()
	ok(SpriteImport.import_file(ProjectSettings.globalize_path(TMP + "bad.ase"), "char") == "", "a broken file is refused")


func _use() -> void:
	var studio := Studio.new()
	add_child(studio)
	await get_tree().process_frame
	await studio.new_scene("pixeltop")
	var ids := SpriteImport.list("char")
	var hero := ""
	for i in ids:
		if str(i).begins_with("hero"):
			hero = i
	ok(hero != "", "listed as a character")
	AssetTags.tag("sprites", hero, "pixeltop")
	ok(AssetTags.only("sprites", ids, "pixeltop").has(hero) and not AssetTags.only("sprites", ids, "pixel").has(hero), "belongs to the top view only")
	var a := studio.add_actor({"name": "Imp", "look": {"sprite": hero}, "x": 40.5, "z": 44.5})
	ok(a != null and a.rig.get("kind") == "sprite" and a.rig.has("anims"), "an imported sprite becomes a character")
	a.vel = Vector3(0, 0, 3)
	a.yaw = 0.0
	a.animate(0.05, false)
	var mat: ShaderMaterial = a.rig["mat"]
	var f: Vector2 = mat.get_shader_parameter("frame")
	var idx := int(f.y) * int(a.rig["grid"].x) + int(f.x)
	ok(idx in [2, 3], "walking south plays the walk_down frames (%d)" % idx)
	a.vel = Vector3.ZERO
	a.set_behavior("dance")
	a.animate(0.05, false)
	f = mat.get_shader_parameter("frame")
	idx = int(f.y) * int(a.rig["grid"].x) + int(f.x)
	ok(idx in [2, 3, 4, 5], "dance tag plays")
	a.set_behavior("sleep")
	a.animate(0.05, false)
	f = mat.get_shader_parameter("frame")
	idx = int(f.y) * int(a.rig["grid"].x) + int(f.x)
	ok(idx in [0, 1], "actions without a tag fall back to idle")
	# Objects in both views.
	var oid := SpriteImport.import_file(ProjectSettings.globalize_path(TMP + "hero.aseprite"), "object")
	ok(oid == hero or oid != "", "imports as an object too")
	var w: PixelTopWorld = studio.world
	var key := SpriteImport.PREFIX + oid
	ok(w.place_object(key, 30, 30) and w.solid_cell(30, 30), "imported objects stand in the top view and block walking")
	var d := studio.serialize()
	studio.load_data(JSON.parse_string(JSON.stringify(d)))
	ok((studio.world as PixelTopWorld).object_at(30, 30) >= 0, "and are saved")
	await studio.new_scene("pixel")
	var pw: PixelWorld = studio.world
	pw.add_decor(key, 20, pw.ground_y(20))
	ok(pw.decor.size() == 1 and pw.remove_decor_at(20, pw.ground_y(20)), "side view: imported objects as decorations")


## Tile sets: import a grid, paint its tiles in both 2D views, save and load.
func _tilesets() -> void:
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cols := [Color.RED, Color.GREEN, Color.BLUE, Color.YELLOW, Color.PURPLE, Color.ORANGE, Color.CYAN]
	for i in 7:  # the 8th cell stays empty
		img.fill_rect(Rect2i((i % 4) * 16, (i / 4) * 16, 16, 16), cols[i])
	img.save_png(TMP + "dungeon.png")
	var id := TileSets.import_file(ProjectSettings.globalize_path(TMP + "dungeon.png"))
	ok(id != "" and TileSets.tiles_of(id).size() == 7, "tile set imported, empty cell skipped (%d tiles)" % TileSets.tiles_of(id).size())
	var odd := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	odd.save_png(TMP + "odd.png")
	ok(TileSets.import_file(ProjectSettings.globalize_path(TMP + "odd.png")) == "" and TileSets.last_error.contains("16"), "odd sizes are refused with a reason")
	ok(SpriteImport.list("tileset").has(id), "listed as a tile set")
	var studio: Studio = null
	for c in get_children():
		if c is Studio:
			studio = c
	await studio.new_scene("pixel")
	var w: PixelWorld = studio.world
	var solid_id := w.custom_id(id, 2)
	var behind_id := w.custom_id(id, 3, true)
	ok(solid_id >= TileSets.CUSTOM_BASE and behind_id == solid_id + 1 and w.custom_id(id, 2) == solid_id, "custom tile ids are registered once")
	w.set_tile(10, 30, solid_id)
	w.set_tile(11, 30, behind_id)
	ok(w.tile(10, 30) == solid_id and w.solid_at(10, 30), "imported tile in the way")
	ok(w.tile(11, 30, "bg") == behind_id and not w.solid_at(11, 30), "imported tile behind the characters")
	ok(w._custom_meshes.size() >= 2, "drawn with the tile set's picture")
	var d := studio.serialize()
	studio.load_data(JSON.parse_string(JSON.stringify(d)))
	var w2: PixelWorld = studio.world
	ok(w2.tile(10, 30) == solid_id and w2.custom.size() == 2, "saved and loaded")
	await studio.new_scene("pixeltop")
	var tw: PixelTopWorld = studio.world
	var gid := tw.custom_id(id, 1)
	tw.set_ground(20, 20, gid)
	ok(tw.ground_id(20, 20) == gid and not tw.solid_cell(20, 20) and tw._custom_meshes.size() == 1, "top view: imported ground tile, walkable")
	var cam := studio.camera
	cam.set_mode("free")
	cam.free_pos = Vector3(25, 0, 25)
	cam.update_camera(0.016)
	studio.tools.set_tool("tiles", {"tile": gid, "mode": "place"})
	ok(studio.tools.tile == gid, "the tile tool keeps an imported tile")
	studio.tools.tap(cam.unproject_position(Vector3(24.5, 0, 24.5)))
	ok(tw.ground_id(24, 24) == gid, "and paints it through the camera")
