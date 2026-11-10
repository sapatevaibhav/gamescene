class_name TileSets
## Imported tile sets for Pixel 2D: a .png/.webp grid of square tiles (16,
## 32 or 8 px), stored next to the sprites (SpriteImport's folder) with a JSON
## description listing the non-empty tiles. Worlds refer to a tile as
## {set: id, i: index}; each world keeps its own list of the custom tiles it
## uses (ids from CUSTOM_BASE up) so saves stay small.

const CUSTOM_BASE := 100
const MAX_CUSTOM := 150

static var last_error := ""


static func import_file(path: String) -> String:
	last_error = ""
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		last_error = "That picture couldn’t be read."
		return ""
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var size := 0
	for s in [16, 32, 8]:
		if w % s == 0 and h % s == 0 and w >= s and h >= s:
			size = s
			break
	if size == 0:
		last_error = "Tile sets must be a grid of 16, 32 or 8 px tiles (this is %d × %d)." % [w, h]
		return ""
	var cols := w / size
	var rows := h / size
	if cols * rows > 1024:
		last_error = "That tile set is too big (up to 1024 tiles)."
		return ""
	var tiles := []
	for i in cols * rows:
		var region := img.get_region(Rect2i((i % cols) * size, (i / cols) * size, size, size))
		if region.get_used_rect().size.x > 0:
			tiles.append(i)
	if tiles.is_empty():
		last_error = "That tile set is empty."
		return ""
	var bytes := FileAccess.get_file_as_bytes(path)
	var id := U.slug(path.get_file().get_basename()) + "~%06x" % (hash(bytes.slice(0, mini(bytes.size(), 200000))) & 0xFFFFFF)
	var dir := SpriteImport.dir()
	DirAccess.make_dir_recursive_absolute(dir)
	if img.save_png(dir + id + ".png") != OK:
		last_error = "Couldn’t save the tile set."
		return ""
	var f := FileAccess.open(dir + id + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"kind": "tileset", "tile": size, "cols": cols, "rows": rows, "tiles": tiles, "source": path.get_file()}))
	f.close()
	SpriteImport._meta.erase(id)
	SpriteImport._tex.erase(id)
	return id


static func tiles_of(set_id: String) -> Array:
	return SpriteImport.meta(set_id).get("tiles", [])


## UV rect of tile `i` in its set's texture.
static func uv(set_id: String, i: int) -> Rect2:
	var m := SpriteImport.meta(set_id)
	if m.is_empty():
		return Rect2(0, 0, 1, 1)
	var cols: int = m["cols"]
	var rows: int = m["rows"]
	return Rect2(float(i % cols) / cols, float(i / cols) / rows, 1.0 / cols, 1.0 / rows)


static func icon(set_id: String, i: int) -> Texture2D:
	var tex := SpriteImport.texture(set_id)
	var m := SpriteImport.meta(set_id)
	if tex == null or m.is_empty():
		return PixelTiles.icon(PixelTiles.ID["stone"])
	var s: int = m["tile"]
	var img := tex.get_image().get_region(Rect2i((i % int(m["cols"])) * s, (i / int(m["cols"])) * s, s, s))
	img.resize(64, 64, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## Adds (or finds) a custom tile in a world's list; returns its tile id, or
## 0 when the list is full.
static func register(custom: Array, set_id: String, i: int, bg := false) -> int:
	for k in custom.size():
		var c: Dictionary = custom[k]
		if c["set"] == set_id and int(c["i"]) == i and bool(c.get("bg", false)) == bg:
			return CUSTOM_BASE + k
	if custom.size() >= MAX_CUSTOM:
		return 0
	custom.append({"set": set_id, "i": i, "bg": bg})
	return CUSTOM_BASE + custom.size() - 1


## One mesh per tile set for the cells of `layer` holding custom tiles.
## `place` maps a cell index to [position, size] for the quad.
static func meshes(custom: Array, layer: PackedByteArray, place: Callable, parent: Node, z_or_y: float, flat: bool) -> Array[MeshInstance3D]:
	var by_set := {}
	for cell in layer.size():
		var id := layer[cell]
		if id < CUSTOM_BASE or id - CUSTOM_BASE >= custom.size():
			continue
		var c: Dictionary = custom[id - CUSTOM_BASE]
		(by_set.get_or_add(str(c["set"]), []) as Array).append([cell, int(c["i"])])
	var out: Array[MeshInstance3D] = []
	var sh: Shader = load("res://src/shaders/pixel.gdshader")
	for set_id in by_set:
		var tex := SpriteImport.texture(set_id)
		if tex == null:
			continue
		var verts := PackedVector3Array()
		var uvs := PackedVector2Array()
		var ids := PackedInt32Array()
		for e in by_set[set_id]:
			var pq: Vector2 = place.call(int(e[0]))
			var r := uv(set_id, int(e[1]))
			var v0 := verts.size()
			if flat:
				verts.append_array([Vector3(pq.x, 0, pq.y), Vector3(pq.x + 1, 0, pq.y), Vector3(pq.x + 1, 0, pq.y + 1), Vector3(pq.x, 0, pq.y + 1)])
				uvs.append_array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
			else:
				verts.append_array([Vector3(pq.x, pq.y, 0), Vector3(pq.x + 1, pq.y, 0), Vector3(pq.x + 1, pq.y + 1, 0), Vector3(pq.x, pq.y + 1, 0)])
				uvs.append_array([Vector2(r.position.x, r.end.y), r.end, Vector2(r.end.x, r.position.y), r.position])
			ids.append_array([v0, v0 + 1, v0 + 2, v0, v0 + 2, v0 + 3])
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_INDEX] = ids
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.material_override = PixelWorld._pixel_mat(sh, tex)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if flat:
			mi.position.y = z_or_y
		else:
			mi.position.z = z_or_y
		parent.add_child(mi)
		out.append(mi)
	return out
