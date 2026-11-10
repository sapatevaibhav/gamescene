class_name PixelWorld
extends Node3D
## Pixel 2D style: a side-on tile world drawn as flat pixel art on one plane,
## seen by an orthographic side camera. Characters live on a single lane in
## front of it (z = LANE), so the 3D studio (behaviours, timeline, director
## mode, recording) works unchanged; only x and y matter here.
##
## Two tile layers: `fg` (in the way: ground, walls, roofs) and `bg` (behind
## the characters: house walls, trees, flowers, ladders). Water is its own
## see-through mesh in front of the characters, so wading looks submerged.

const W := Styles.SIZE
const H := 40
const LANE := Styles.SIZE / 2.0
## Pixels per metre: one 16 px tile is one metre.
const PPM := 16.0
## Same body box as the voxel world, so the shared movement code fits.
const HW := 0.3
const HH := 1.75

var is_voxel := false
var is_side := true
var load_offset := 0.0
## Terrain-world compatibility (pixel worlds have no props).
var props: Array = []
var fg := PackedByteArray()
var bg := PackedByteArray()
## Day/night multiplier for every pixel material (characters read it too).
var tint := Color.WHITE
## Imported object sprites standing behind the characters: [key, x, y].
var decor: Array = []
## Tiles from imported tile sets this scene uses (TileSets): ids from 100.
var custom: Array = []
var _custom_meshes: Array[MeshInstance3D] = []
var _decor_meshes: Array[MeshInstance3D] = []

var _fg_mesh := MeshInstance3D.new()
var _bg_mesh := MeshInstance3D.new()
var _glow_mesh := MeshInstance3D.new()
var _water_mesh := MeshInstance3D.new()
var _mat: ShaderMaterial
var _bg_mat: ShaderMaterial
var _glow_mat: ShaderMaterial
var _water_mat: ShaderMaterial
var _sky := MeshInstance3D.new()
var _sky_mat: ShaderMaterial
var _layers: Array[MeshInstance3D] = []
var _layer_mats: Array[ShaderMaterial] = []
const PARALLAX := [0.85, 0.65, 0.4]
## Painted backdrop behind the world (BACKDROPS key), saved with the scene.
var backdrop := "hills"

## Three parallax layers each, far to near.
const BACKDROPS := {
	"hills": {"name": "Hills", "layers": [
		{"col": "9bb4d6", "base": 15.0, "amp": 9.0, "freq": 0.045, "cap": "e8f0fa"},
		{"col": "6f9a6a", "base": 12.0, "amp": 4.0, "freq": 0.09},
		{"col": "3f7a4a", "base": 11.0, "amp": 2.5, "freq": 0.21, "trees": true}]},
	"mountains": {"name": "Mountains", "layers": [
		{"col": "8a9bb8", "base": 20.0, "amp": 13.0, "freq": 0.03, "cap": "ffffff"},
		{"col": "6f86a6", "base": 15.0, "amp": 8.0, "freq": 0.06, "cap": "e8f0fa"},
		{"col": "4f7a5a", "base": 11.0, "amp": 2.5, "freq": 0.25, "trees": true}]},
	"forest": {"name": "Forest", "layers": [
		{"col": "6f9a7a", "base": 16.0, "amp": 2.0, "freq": 0.12, "trees": true},
		{"col": "467a52", "base": 14.0, "amp": 2.5, "freq": 0.22, "trees": true},
		{"col": "2f5a3a", "base": 12.0, "amp": 2.0, "freq": 0.4, "trees": true}]},
	"desert": {"name": "Desert", "layers": [
		{"col": "e8c9a0", "base": 14.0, "amp": 6.0, "freq": 0.035},
		{"col": "dcb27a", "base": 12.5, "amp": 3.5, "freq": 0.07},
		{"col": "c99a5e", "base": 11.0, "amp": 2.0, "freq": 0.13}]},
	"city": {"name": "Night city", "layers": [
		{"col": "6a7090", "base": 18.0, "buildings": true},
		{"col": "4a5070", "base": 15.0, "buildings": true},
		{"col": "30364e", "base": 12.0, "buildings": true}]},
}

const SKY_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 top : source_color;
uniform vec4 bottom : source_color;
void fragment() {
	float k = floor((1.0 - UV.y) * 24.0) / 24.0;
	ALBEDO = mix(bottom.rgb, top.rgb, k);
}
"""


func _init() -> void:
	fg.resize(W * H)
	bg.resize(W * H)
	var sh: Shader = load("res://src/shaders/pixel.gdshader")
	_mat = _pixel_mat(sh, PixelTiles.atlas())
	_bg_mat = _pixel_mat(sh, PixelTiles.atlas())
	_glow_mat = _pixel_mat(sh, PixelTiles.atlas())
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://src/shaders/pixel_water.gdshader")
	_water_mat.set_shader_parameter("tex", PixelTiles.atlas())
	for mi in [_fg_mesh, _bg_mesh, _glow_mesh, _water_mesh]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_fg_mesh.material_override = _mat
	_bg_mesh.material_override = _bg_mat
	_glow_mesh.material_override = _glow_mat
	_water_mesh.material_override = _water_mat
	# Layers front to back: water, (characters on the lane), fg, glow, bg.
	_water_mesh.position.z = LANE + 0.35
	_fg_mesh.position.z = LANE - 0.6
	_glow_mesh.position.z = LANE - 1.15
	_bg_mesh.position.z = LANE - 1.2
	_build_backdrop()


static func _pixel_mat(sh: Shader, tex: Texture2D) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tex", tex)
	return m


# ---------------------------------------------------------------- tiles

func idx(x: int, y: int) -> int:
	return y * W + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H


func tile(x: int, y: int, layer := "fg") -> int:
	if not in_bounds(x, y):
		return 0
	return (fg if layer == "fg" else bg)[idx(x, y)]


## Puts a tile on the layer it belongs to (0 clears both layers there).
func set_tile(x: int, y: int, id: int, rebuild_now := true) -> void:
	if not in_bounds(x, y):
		return
	var i := idx(x, y)
	if id == 0:
		if fg[i] != 0:
			fg[i] = 0
		else:
			bg[i] = 0
	elif id >= TileSets.CUSTOM_BASE:
		if _custom_bg(id):
			bg[i] = id
		else:
			fg[i] = id
	elif PixelTiles.is_bg(id):
		bg[i] = id
	else:
		fg[i] = id
	if rebuild_now:
		rebuild()


func solid_at(x: int, y: int) -> bool:
	if x < 0 or x >= W or y < 0:
		return true
	if y >= H:
		return false
	return tile_solid(fg[idx(x, y)])


## Whether a tile stands in the way (imported tiles: unless placed behind).
func tile_solid(id: int) -> bool:
	if id >= TileSets.CUSTOM_BASE:
		return not _custom_bg(id)
	return PixelTiles.is_solid(id)


func _custom_bg(id: int) -> bool:
	var k := id - TileSets.CUSTOM_BASE
	return k >= 0 and k < custom.size() and bool(custom[k].get("bg", false))


## Tile id for tile `i` of imported set `set_id` (0 if the list is full).
func custom_id(set_id: String, i: int, behind := false) -> int:
	return TileSets.register(custom, set_id, i, behind)


func custom_icon(id: int) -> Texture2D:
	var c: Dictionary = custom[id - TileSets.CUSTOM_BASE]
	return TileSets.icon(str(c["set"]), int(c["i"]))


func ladder_at(p: Vector3) -> bool:
	var x := int(floor(p.x))
	for y in [int(floor(p.y + 0.2)), int(floor(p.y + 1.0))]:
		if PixelTiles.is_ladder(tile(x, y, "bg")):
			return true
	return false


func water_at(p: Vector3) -> bool:
	return PixelTiles.is_water(tile(int(floor(p.x)), int(floor(p.y + 0.4))))


## Top of the first solid tile below `p` (the bed under the water).
func water_bottom(p: Vector3) -> float:
	var x := int(floor(p.x))
	var y := int(floor(p.y + 0.1))
	while y > 0 and not solid_at(x, y - 1):
		y -= 1
	return float(y)


## Top of the water a body at `p` is in, else -1e9.
func water_surface(p: Vector3) -> float:
	var x := int(floor(p.x))
	var y := int(floor(p.y + 0.1))
	if not PixelTiles.is_water(tile(x, y)):
		return -1.0e9
	while y < H - 1 and PixelTiles.is_water(tile(x, y + 1)):
		y += 1
	return float(y + 1)


# ---------------------------------------------------------------- queries

## The ground surface of a column: the first gap (two free tiles) going up
## from the bottom, so roofs and treetops don't count as ground.
func ground_y(x: float) -> int:
	var ix := clampi(int(floor(x)), 0, W - 1)
	for y in range(0, H - 1):
		if not solid_at(ix, y) and not solid_at(ix, y + 1):
			return y
	return H - 1


func ground_at(x: float, _z := 0.0) -> float:
	return float(ground_y(x))


func box_hits(p: Vector3) -> bool:
	var x0 := int(floor(p.x - HW))
	var x1 := int(floor(p.x + HW))
	var y0 := int(floor(p.y))
	var y1 := int(floor(p.y + HH))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if solid_at(x, y):
				return true
	return false


func body_blocked(p: Vector3) -> bool:
	return box_hits(p)


## Footstep surface under `p` (see Sounds.surface_of).
func surface_at(p: Vector3) -> String:
	var x := int(floor(p.x))
	var y := int(floor(p.y - 0.05))
	for k in 2:
		var id := tile(x, y - k)
		if id > 0 and id < TileSets.CUSTOM_BASE:
			return Sounds.surface_of(str(PixelTiles.ID.find_key(id)))
		if id >= TileSets.CUSTOM_BASE:
			return "stone"
	return "grass"


func walkable(x: float, _z := 0.0) -> bool:
	if x < 1.0 or x >= W - 1:
		return false
	var g := ground_y(x)
	return g < H - 3 and not PixelTiles.is_water(tile(int(floor(x)), g))


## Where a screen ray meets the tile plane: {point, x, y, fg, bg, dist}.
func ray(o: Vector3, d: Vector3, max_d: float) -> Dictionary:
	if absf(d.z) < 1e-5:
		return {}
	var t := (LANE - o.z) / d.z
	if t < 0.0 or t > max_d * 4.0:
		return {}
	var p := o + d * t
	var tx := int(floor(p.x))
	var ty := int(floor(p.y))
	if not in_bounds(tx, ty):
		return {}
	return {"point": p, "x": tx, "y": ty, "fg": tile(tx, ty), "bg": tile(tx, ty, "bg"), "dist": t}


func pick(origin: Vector3, dir: Vector3, max_d: float = 60.0) -> Dictionary:
	var hit := ray(origin, dir, max_d)
	if hit.is_empty():
		return {}
	var p: Vector3 = hit["point"]
	hit["point"] = Vector3(p.x, ground_at(p.x), LANE)
	return hit


func clip_cam(_from: Vector3, _dir: Vector3, dist: float) -> float:
	return dist


## Stamps a building with its bottom-left corner at (x, y).
func stamp_prefab(key: String, x: int, y: int, flip := false) -> void:
	var p: Dictionary = PixelTiles.PREFABS.get(key, {})
	if p.is_empty():
		return
	var rows: Array = p["rows"]
	var n := rows.size()
	for r in n:
		var row: String = rows[r]
		var ty := y + (n - 1 - r)
		for c in row.length():
			var ch := row[c]
			if ch == ".":
				continue
			var tx := x + (row.length() - 1 - c if flip else c)
			if not in_bounds(tx, ty):
				continue
			if ch == " ":
				fg[idx(tx, ty)] = 0
				bg[idx(tx, ty)] = 0
				continue
			var key2: String = PixelTiles.KEYS.get(ch, "")
			if key2 != "":
				set_tile(tx, ty, PixelTiles.ID[key2], false)
	rebuild()


# ---------------------------------------------------------------- generation

func new_world(_style := "pixel") -> void:
	fg.fill(0)
	bg.fill(0)
	var r := U.rng(4242)
	# Rolling ground with a flat village in the middle and a pond.
	var heights: Array[int] = []
	var a := r.next() * TAU
	var b := r.next() * TAU
	for x in W:
		var h := 14.0 + sin(x * 0.11 + a) * 2.2 + sin(x * 0.27 + b) * 1.0
		var flat := clampf(1.0 - absf(x - 40.0) / 16.0, 0.0, 1.0)
		h = lerpf(h, 14.0, clampf(flat * 1.6, 0.0, 1.0))
		heights.append(int(round(h)))
	for x in range(60, 69):
		heights[x] = 12
	for x in W:
		var g := heights[x]
		for y in g:
			var id := PixelTiles.ID["stone"]
			if y >= g - 1:
				id = PixelTiles.ID["grass"]
			elif y >= g - 4:
				id = PixelTiles.ID["dirt"]
			fg[idx(x, y)] = id
	# Pond: sand bed and water up to the banks.
	for x in range(60, 69):
		fg[idx(x, 11)] = PixelTiles.ID["sand"]
		for y in range(12, 14):
			fg[idx(x, y)] = PixelTiles.ID["water"]
	for x in [59, 69]:
		fg[idx(x, heights[x] - 1)] = PixelTiles.ID["sand"]
	# Village.
	stamp_prefab("cottage", 27, 14)
	stamp_prefab("cottage", 47, 14, true)
	stamp_prefab("shop", 37, 14)
	stamp_prefab("tower", 10, heights[10])
	stamp_prefab("well", 55, heights[55])
	for tx in [3, 19, 22, 72, 76]:
		stamp_prefab("tree", tx - 2, heights[tx])
	stamp_prefab("bridge", 60, 13)
	# Flowers and tall grass along the top.
	for x in W:
		var y := ground_y(x)
		if bg[idx(x, y)] != 0 or fg[idx(x, y)] != 0:
			continue
		var v := r.next()
		if v < 0.12:
			bg[idx(x, y)] = PixelTiles.ID["flowers"]
		elif v < 0.3:
			bg[idx(x, y)] = PixelTiles.ID["tallgrass"]
	for x in [25, 34, 44, 53]:
		bg[idx(x, ground_y(x) + 1)] = PixelTiles.ID["lantern"]
	rebuild()


# ---------------------------------------------------------------- meshes

## Tiles that make up the land itself (kept when clearing a structure).
const LAND := ["grass", "dirt", "stone", "sand", "water", "snow", "ice", "cobble", "mossy"]


## Removes the whole tree or building at a tile: every connected non-land
## tile on both layers (and any decoration there). Returns tiles removed.
func clear_structure(x: int, y: int) -> int:
	if remove_decor_at(x, y):
		return 1
	var land := LAND.map(func(k): return PixelTiles.ID[k])
	var is_part := func(cx: int, cy: int) -> bool:
		if not in_bounds(cx, cy):
			return false
		var f := fg[idx(cx, cy)]
		var b := bg[idx(cx, cy)]
		return (f != 0 and not land.has(f)) or b != 0
	if not is_part.call(x, y):
		return 0
	var todo := [Vector2i(x, y)]
	var seen := {Vector2i(x, y): true}
	var n := 0
	while not todo.is_empty() and n < 400:
		var c: Vector2i = todo.pop_back()
		var i := idx(c.x, c.y)
		if not land.has(fg[i]):
			fg[i] = 0
		bg[i] = 0
		n += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = c + d
			if not seen.has(nb) and is_part.call(nb.x, nb.y):
				seen[nb] = true
				todo.append(nb)
	rebuild()
	return n


func add_decor(key: String, x: int, y: int) -> void:
	decor.append([key, x, y])
	rebuild()


func remove_decor_at(x: int, y: int) -> bool:
	for i in range(decor.size() - 1, -1, -1):
		var d := SpriteImport.object_def(str(decor[i][0]))
		var dx: int = decor[i][1]
		var dy: int = decor[i][2]
		if x >= dx and x < dx + ceili(float(d["w"]) / PPM) and y >= dy and y < dy + ceili(float(d["h"]) / PPM):
			decor.remove_at(i)
			rebuild()
			return true
	return false


func _rebuild_decor() -> void:
	for mi in _decor_meshes:
		mi.queue_free()
	_decor_meshes.clear()
	var sh: Shader = load("res://src/shaders/pixel.gdshader")
	for d in decor:
		var key := str(d[0])
		var tex := SpriteImport.object_texture(key)
		if tex == null:
			continue
		var od := SpriteImport.object_def(key)
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(float(od["w"]), float(od["h"])) / PPM
		mi.mesh = q
		mi.material_override = _pixel_mat(sh, tex)
		mi.position = Vector3(float(d[1]) + q.size.x / 2.0, float(d[2]) + q.size.y / 2.0, LANE - 0.9)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_decor_meshes.append(mi)


func rebuild() -> void:
	_rebuild_decor()
	for mi in _custom_meshes:
		mi.queue_free()
	_custom_meshes.clear()
	var place := func(cell: int) -> Vector2: return Vector2(cell % W, cell / W)
	_custom_meshes.append_array(TileSets.meshes(custom, fg, place, self, LANE - 0.6, false))
	_custom_meshes.append_array(TileSets.meshes(custom, bg, place, self, LANE - 1.2, false))
	_fg_mesh.mesh = _layer_mesh(fg, func(id): return not PixelTiles.is_water(id) and not PixelTiles.get_tile(id).get("glow", false))
	_bg_mesh.mesh = _layer_mesh(bg, func(id): return not _glows(id), Color(0.7, 0.72, 0.8))
	_glow_mesh.mesh = _layer_mesh(bg, func(id): return _glows(id))
	_water_mesh.mesh = _layer_mesh(fg, func(id): return PixelTiles.is_water(id))


## Lanterns and windows light up at night.
static func _glows(id: int) -> bool:
	return id in [PixelTiles.ID["lantern"], PixelTiles.ID["window"], PixelTiles.ID["torch"]]


func _layer_mesh(layer: PackedByteArray, keep: Callable, shade := Color.WHITE) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var ids := PackedInt32Array()
	for y in H:
		for x in W:
			var id := layer[idx(x, y)]
			if id == 0 or id >= TileSets.CUSTOM_BASE or not keep.call(id):
				continue
			var r := PixelTiles.uv_rect(id)
			var v0 := verts.size()
			verts.append_array([Vector3(x, y, 0), Vector3(x + 1, y, 0), Vector3(x + 1, y + 1, 0), Vector3(x, y + 1, 0)])
			uvs.append_array([Vector2(r.position.x, r.end.y), r.end, Vector2(r.end.x, r.position.y), r.position])
			cols.append_array([shade, shade, shade, shade])
			ids.append_array([v0, v0 + 2, v0 + 1, v0, v0 + 3, v0 + 2])
	var am := ArrayMesh.new()
	if verts.is_empty():
		return am
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_INDEX] = ids
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


# ---------------------------------------------------------------- backdrop

## Sky gradient plus three parallax layers (far mountains, hills, forest),
## painted in code at half the tile resolution.
func _build_backdrop() -> void:
	_sky_mat = ShaderMaterial.new()
	var sk := Shader.new()
	sk.code = SKY_SHADER
	_sky_mat.shader = sk
	var qm := QuadMesh.new()
	qm.size = Vector2(W * 4, H * 3)
	_sky.mesh = qm
	_sky.material_override = _sky_mat
	_sky.position = Vector3(W / 2.0, H / 2.0, LANE - 40.0)
	_sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sky)
	var sh: Shader = load("res://src/shaders/pixel.gdshader")
	for i in 3:
		var m := _pixel_mat(sh, null)
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(W * 2.0, H)
		mi.mesh = q
		mi.material_override = m
		mi.position = Vector3(W / 2.0, H / 2.0, LANE - 30.0 + i * 10.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_layers.append(mi)
		_layer_mats.append(m)
	set_backdrop(backdrop)


## Repaints the parallax layers for a BACKDROPS key.
func set_backdrop(key: String) -> void:
	if not BACKDROPS.has(key):
		key = "hills"
	backdrop = key
	var specs: Array = BACKDROPS[key]["layers"]
	for i in 3:
		_layer_mats[i].set_shader_parameter("tex", _paint_layer(specs[i], 900 + i + key.hash() % 1000))


static func _paint_layer(spec: Dictionary, seed: int) -> ImageTexture:
	var ppm := 8
	var w := W * 2 * ppm
	var h := H * ppm
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := U.rng(seed)
	var ph := r.next() * TAU
	var ph2 := r.next() * TAU
	var col := Color(str(spec["col"]))
	if spec.get("buildings", false):
		# Blocks of buildings with lit windows.
		var x0 := 0
		while x0 < w:
			var bw := 24 + int(r.next() * 40)
			var bh := int((float(spec["base"]) + r.next() * 9.0) * ppm)
			for x in range(x0, mini(w, x0 + bw - 3)):
				for y in range(0, mini(bh, h)):
					var lit := (x - x0) % 6 in [2, 3] and y % 8 in [3, 4, 5] and y < bh - 4 and r.next() < 0.5
					img.set_pixel(x, h - 1 - y, Color("ffd97a") if lit else col)
			x0 += bw
		return ImageTexture.create_from_image(img)
	for x in w:
		var mx := float(x) / ppm
		var top := float(spec["base"]) + sin(mx * float(spec["freq"]) * TAU / 2.0 + ph) * float(spec["amp"]) + sin(mx * 0.5 + ph2) * 0.6
		if spec.get("trees", false):
			top += absf(sin(mx * 2.4 + ph2)) * 1.6
		var ty := int(top * ppm)
		for y in range(0, mini(ty, h)):
			var py := h - 1 - y
			var c := col
			if spec.has("cap") and y > ty - 6:
				c = Color(str(spec["cap"]))
			elif y % 9 == 0 and x % 7 == 0:
				c = U.shade(col, 0.9)
			img.set_pixel(x, py, c)
	return ImageTexture.create_from_image(img)


## Per frame: parallax and the time-of-day tint.
func animate(_dt: float, _t: float) -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var cx := W / 2.0
	if cam:
		cx = cam.global_position.x
		_sky.position.x = cx
		_sky.position.y = cam.global_position.y
	for i in _layers.size():
		# Far layers follow the camera more, so they seem to move slower.
		_layers[i].position.x = W / 2.0 + (cx - W / 2.0) * float(PARALLAX[i])
	var atmo: Atmosphere = get_parent().get("atmo") if get_parent() else null
	var night := atmo.night if atmo else 0.0
	var sky := atmo.sky_color() if atmo else Color("8fd3ff")
	var light := atmo.light_color() if atmo else Color.WHITE
	tint = Color.WHITE.lerp(light, 0.25).lerp(Color(0.34, 0.4, 0.66), night * 0.8)
	if App.settings.get("weather", "clear") != "clear":
		tint = tint * Color(0.82, 0.84, 0.9)
	tint.a = 1.0
	for m in [_mat, _bg_mat, _water_mat]:
		m.set_shader_parameter("tint", tint)
	for mi in _custom_meshes:
		(mi.material_override as ShaderMaterial).set_shader_parameter("tint", tint)
	for mi in _decor_meshes:
		(mi.material_override as ShaderMaterial).set_shader_parameter("tint", tint)
	_glow_mat.set_shader_parameter("tint", tint.lerp(Color(1.15, 1.05, 0.85), night))
	for m in _layer_mats:
		m.set_shader_parameter("tint", tint.lerp(sky, 0.25))
	_sky_mat.set_shader_parameter("top", U.shade(sky, 0.78))
	_sky_mat.set_shader_parameter("bottom", sky.lerp(Color.WHITE, 0.3 * (1.0 - night)))


# ---------------------------------------------------------------- terrain-world compatibility

func rebuild_grass() -> void:
	pass


func brush(_x: float, _z: float, _mode: String, _dt: float) -> void:
	pass


func update_prop(_p: Dictionary) -> void:
	pass


func remove_prop(_p: Dictionary) -> void:
	pass


# ---------------------------------------------------------------- save / load

func serialize() -> Dictionary:
	return {"pixel": 1, "w": W, "h": H, "fg": U.rle_encode(fg), "bg": U.rle_encode(bg), "decor": decor.duplicate(true), "backdrop": backdrop, "custom": custom.duplicate(true)}


func load_data(d: Dictionary, _style := "") -> void:
	if int(d.get("w", 0)) != W or int(d.get("h", 0)) != H or not d.has("fg"):
		new_world()
		return
	fg = U.rle_decode(str(d["fg"]), W * H)
	bg = U.rle_decode(str(d.get("bg", "")), W * H)
	set_backdrop(str(d.get("backdrop", "hills")))
	custom = (d.get("custom", []) as Array).duplicate(true)
	decor = []
	for o in d.get("decor", []):
		if o is Array and o.size() >= 3:
			decor.append([str(o[0]), int(o[1]), int(o[2])])
	rebuild()
