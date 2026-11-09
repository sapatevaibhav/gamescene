class_name PixelTopWorld
extends Node3D
## Pixel 2D top view: an 80 × 80 tile ground seen straight from above by an
## orthographic camera, with front-facing pixel objects (trees, houses,
## rocks...) standing on it, like a top-down RPG. The ground is the y = 0
## plane, so the studio's 3D movement and behaviours work unchanged.
##
## Everything is a flat sprite lying on the ground. Draw order comes from
## depth: the further south something stands, the higher it is lifted, so it
## covers what's behind it (characters walk behind trees and in front of them).

const W := Styles.SIZE
const D := Styles.SIZE
## Lift per metre south, for draw order (see `depth_y`).
const DEPTH := 0.002
const BASE_Y := 0.05

var is_voxel := false
var is_side := false
var is_top := true
var load_offset := 0.0
var props: Array = []
## Ground tile id per cell (PixelTopArt.GROUND).
var ground := PackedByteArray()
## Placed objects: [key, x, z] with (x, z) the south-west tile of the footprint.
var objects: Array = []
var tint := Color.WHITE

var _solid := PackedByteArray()
var _ground_mesh := MeshInstance3D.new()
var _water_mesh := MeshInstance3D.new()
var _obj_mesh := MeshInstance3D.new()
var _glow_mesh := MeshInstance3D.new()
var _mat: ShaderMaterial
var _water_mat: ShaderMaterial
var _obj_mat: ShaderMaterial
var _glow_mat: ShaderMaterial
## Imported object sprites: key -> MeshInstance3D (one texture each).
var _sprite_meshes := {}


func _init() -> void:
	ground.resize(W * D)
	_solid.resize(W * D)
	var sh: Shader = load("res://src/shaders/pixel.gdshader")
	_mat = PixelWorld._pixel_mat(sh, PixelTopArt.ground_atlas())
	_obj_mat = PixelWorld._pixel_mat(sh, PixelTopArt.obj_atlas())
	_glow_mat = PixelWorld._pixel_mat(sh, PixelTopArt.obj_atlas())
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = load("res://src/shaders/pixel_water.gdshader")
	_water_mat.set_shader_parameter("tex", PixelTopArt.ground_atlas())
	for mi in [_ground_mesh, _water_mesh, _obj_mesh, _glow_mesh]:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_ground_mesh.material_override = _mat
	_water_mesh.material_override = _water_mat
	_obj_mesh.material_override = _obj_mat
	_glow_mesh.material_override = _glow_mat
	_water_mesh.position.y = 0.01


## Height to draw something whose feet are at `z` (south covers north).
static func depth_y(z: float) -> float:
	return BASE_Y + clampf(z, -10.0, D + 10.0) * DEPTH


# ---------------------------------------------------------------- cells

func idx(x: int, z: int) -> int:
	return z * W + x


func in_bounds(x: int, z: int) -> bool:
	return x >= 0 and z >= 0 and x < W and z < D


func ground_id(x: int, z: int) -> int:
	return ground[idx(x, z)] if in_bounds(x, z) else 0


func set_ground(x: int, z: int, id: int, rebuild_now := true) -> void:
	if not in_bounds(x, z):
		return
	ground[idx(x, z)] = id
	if rebuild_now:
		rebuild()


func solid_cell(x: int, z: int) -> bool:
	if not in_bounds(x, z):
		return true
	return _solid[idx(x, z)] != 0


## Objects defined in code or imported (keys starting with "spr:").
static func obj_def(key: String) -> Dictionary:
	if PixelTopArt.OBJECTS.has(key):
		return PixelTopArt.OBJECTS[key]
	if SpriteImport.is_key(key):
		return SpriteImport.object_def(key)
	return {}


func _cells_of(o: Array) -> Array:
	var d := obj_def(str(o[0]))
	var out := []
	if d.is_empty():
		return out
	for dz in int(d.get("fd", 1)):
		for dx in int(d.get("fw", 1)):
			out.append(Vector2i(int(o[1]) + dx, int(o[2]) - dz))
	return out


func object_at(x: int, z: int) -> int:
	for i in range(objects.size() - 1, -1, -1):
		if _cells_of(objects[i]).has(Vector2i(x, z)):
			return i
	return -1


## Places an object if its footprint is free; returns whether it did.
func place_object(key: String, x: int, z: int, rebuild_now := true) -> bool:
	var o := [key, x, z]
	for c in _cells_of(o):
		if not in_bounds(c.x, c.y) or object_at(c.x, c.y) >= 0:
			return false
	if obj_def(key).is_empty():
		return false
	objects.append(o)
	if rebuild_now:
		rebuild()
	return true


func remove_object_at(x: int, z: int) -> bool:
	var i := object_at(x, z)
	if i < 0:
		return false
	objects.remove_at(i)
	rebuild()
	return true


# ---------------------------------------------------------------- queries

func ground_at(_x: float, _z: float) -> float:
	return 0.0


func body_blocked(p: Vector3) -> bool:
	var r := 0.28
	for z in range(int(floor(p.z - r)), int(floor(p.z + r)) + 1):
		for x in range(int(floor(p.x - r)), int(floor(p.x + r)) + 1):
			if solid_cell(x, z):
				return true
	return false


func walkable(x: float, z: float) -> bool:
	return x >= 1.0 and z >= 1.0 and x < W - 1 and z < D - 1 and not solid_cell(int(floor(x)), int(floor(z)))


## Where a screen ray meets the ground: {point, x, z, ground, object}.
func ray(o: Vector3, d: Vector3, _max_d: float) -> Dictionary:
	if absf(d.y) < 1e-5:
		return {}
	var t := -o.y / d.y
	if t < 0.0:
		return {}
	var p := o + d * t
	var tx := int(floor(p.x))
	var tz := int(floor(p.z))
	if not in_bounds(tx, tz):
		return {}
	return {"point": Vector3(p.x, 0.0, p.z), "x": tx, "z": tz, "ground": ground_id(tx, tz), "object": object_at(tx, tz), "dist": t}


func pick(origin: Vector3, dir: Vector3, max_d: float = 60.0) -> Dictionary:
	return ray(origin, dir, max_d)


func clip_cam(_from: Vector3, _dir: Vector3, dist: float) -> float:
	return dist


# ---------------------------------------------------------------- generation

func new_world(_style := "pixeltop") -> void:
	var r := U.rng(5151)
	var G := PixelTopArt.G
	ground.fill(G["grass"])
	objects.clear()
	var c := W / 2
	for z in D:
		for x in W:
			var v := r.next()
			if v < 0.08:
				ground[idx(x, z)] = G["meadow"]
			elif v < 0.14:
				ground[idx(x, z)] = G["dark"]
	# Crossroads and a plaza around the well.
	for k in W:
		for w in [-1, 0]:
			ground[idx(k, c + w)] = G["path"]
			ground[idx(c + w, k)] = G["path"]
	for z in range(c - 4, c + 4):
		for x in range(c - 5, c + 5):
			ground[idx(x, z)] = G["plaza"]
	# Pond with a sandy shore in the north-east.
	for z in range(14, 30):
		for x in range(52, 70):
			var dx := (x - 61.0) / 8.0
			var dz := (z - 22.0) / 7.0
			var d := dx * dx + dz * dz
			if d < 1.0:
				ground[idx(x, z)] = G["water"]
			elif d < 1.45:
				ground[idx(x, z)] = G["sand"]
	# Farm in the south-west.
	for z in range(48, 56):
		for x in range(18, 30):
			ground[idx(x, z)] = G["farm"]
	_recompute_solid()
	# Village.
	place_object("well", c - 1, c - 2, false)
	for h in [[c - 12, c - 4], [c + 5, c - 4], [c - 12, c + 10], [c + 6, c + 10]]:
		place_object("house", h[0], h[1], false)
	place_object("stall", c + 2, c + 3, false)
	place_object("stall", c - 6, c + 3, false)
	for lx in [c - 7, c + 6]:
		for lz in [c - 7, c + 6]:
			place_object("lamp", lx, lz, false)
	place_object("sign", c + 2, c - 3, false)
	place_object("campfire", 12, 66, false)
	for k in 2:
		place_object("crate", c + 3 + k, c + 6, false)
	# Farm crops and fence.
	for z in range(49, 55, 2):
		for x in range(19, 29):
			place_object("crops", x, z, false)
	for x in range(17, 31):
		place_object("fence", x, 47, false)
		place_object("fence", x, 56, false)
	# Woods around the edges, leaving the paths and the village clear.
	for n in 260:
		var x := int(r.next() * W)
		var z := int(r.next() * D)
		var center := absf(x - c) < 18 and absf(z - c) < 16
		var on_path := absi(x - c) < 3 or absi(z - c) < 3
		if center or on_path or ground_id(x, z) in [G["water"], G["farm"], G["sand"]]:
			continue
		var edge := minf(minf(x, W - x), minf(z, D - z))
		var v := r.next()
		if edge < 12 and v < 0.75:
			place_object("pine" if r.next() < 0.5 else "tree", x, z, false)
		elif v < 0.3:
			place_object("tree", x, z, false)
		elif v < 0.5:
			place_object("bush", x, z, false)
		elif v < 0.62:
			place_object("rock", x, z, false)
		elif v < 0.85:
			place_object("flowers", x, z, false)
	rebuild()


# ---------------------------------------------------------------- meshes

func _recompute_solid() -> void:
	_solid.fill(0)
	for z in D:
		for x in W:
			if PixelTopArt.GROUND[ground[idx(x, z)]].get("block", false):
				_solid[idx(x, z)] = 1
	for o in objects:
		if not obj_def(str(o[0])).get("solid", false):
			continue
		for cell in _cells_of(o):
			if in_bounds(cell.x, cell.y):
				_solid[idx(cell.x, cell.y)] = 1


func rebuild() -> void:
	_recompute_solid()
	_ground_mesh.mesh = _ground_layer(func(id): return not PixelTopArt.GROUND[id].get("water", false))
	_water_mesh.mesh = _ground_layer(func(id): return PixelTopArt.GROUND[id].get("water", false))
	_obj_mesh.mesh = _object_layer(func(k): return PixelTopArt.OBJECTS.has(k) and not PixelTopArt.OBJECTS[k].get("glow", false))
	_glow_mesh.mesh = _object_layer(func(k): return PixelTopArt.OBJECTS.has(k) and PixelTopArt.OBJECTS[k].get("glow", false))
	_rebuild_sprites()


func _ground_layer(keep: Callable) -> ArrayMesh:
	var q := _Quads.new()
	for z in D:
		for x in W:
			var id := ground[idx(x, z)]
			if id == 0 or not keep.call(id):
				continue
			var r := PixelTopArt.ground_uv(id)
			q.flat(Vector3(x, 0, z), Vector2(1, 1), r)
	return q.mesh()


## Object sprites lying on the ground, bottom edge at the footprint's south
## side, reaching north; lifted by depth so southern things draw on top.
func _object_layer(keep: Callable) -> ArrayMesh:
	var q := _Quads.new()
	for o in objects:
		var key := str(o[0])
		if not keep.call(key):
			continue
		var d: Dictionary = PixelTopArt.OBJECTS[key]
		_add_obj_quad(q, o, d, PixelTopArt.obj_uv(key))
	return q.mesh()


func _add_obj_quad(q: _Quads, o: Array, d: Dictionary, uv: Rect2) -> void:
	var w := float(d["w"]) / PixelWorld.PPM
	var h := float(d["h"]) / PixelWorld.PPM
	var south := float(o[2]) + 1.0
	var cx := float(o[1]) + float(d.get("fw", 1)) / 2.0
	q.flat(Vector3(cx - w / 2.0, depth_y(south), south - h), Vector2(w, h), uv)


## Imported object sprites: one mesh per sprite file.
func _rebuild_sprites() -> void:
	for k in _sprite_meshes:
		(_sprite_meshes[k] as Node).queue_free()
	_sprite_meshes.clear()
	var by_key := {}
	for o in objects:
		if SpriteImport.is_key(str(o[0])):
			(by_key.get_or_add(str(o[0]), []) as Array).append(o)
	for key in by_key:
		var tex := SpriteImport.object_texture(key)
		var d := obj_def(key)
		var q := _Quads.new()
		for o in by_key[key]:
			_add_obj_quad(q, o, d, Rect2(0, 0, 1, 1))
		var mi := MeshInstance3D.new()
		mi.mesh = q.mesh()
		mi.material_override = PixelWorld._pixel_mat(load("res://src/shaders/pixel.gdshader"), tex if tex else PixelTopArt.obj_atlas())
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_sprite_meshes[key] = mi


## Builds flat quads (in the xz plane, image top towards north).
class _Quads:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var ids := PackedInt32Array()

	func flat(p: Vector3, size: Vector2, r: Rect2) -> void:
		var v0 := verts.size()
		verts.append_array([p, p + Vector3(size.x, 0, 0), p + Vector3(size.x, 0, size.y), p + Vector3(0, 0, size.y)])
		uvs.append_array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		ids.append_array([v0, v0 + 1, v0 + 2, v0, v0 + 2, v0 + 3])

	func mesh() -> ArrayMesh:
		var am := ArrayMesh.new()
		if verts.is_empty():
			return am
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_TEX_UV] = uvs
		arr[Mesh.ARRAY_INDEX] = ids
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return am


# ---------------------------------------------------------------- per frame

func animate(_dt: float, _t: float) -> void:
	var atmo: Atmosphere = get_parent().get("atmo") if get_parent() else null
	var night := atmo.night if atmo else 0.0
	var light := atmo.light_color() if atmo else Color.WHITE
	tint = Color.WHITE.lerp(light, 0.25).lerp(Color(0.34, 0.4, 0.66), night * 0.8)
	if App.settings.get("weather", "clear") != "clear":
		tint = tint * Color(0.82, 0.84, 0.9)
	tint.a = 1.0
	for m in [_mat, _water_mat, _obj_mat]:
		m.set_shader_parameter("tint", tint)
	_glow_mat.set_shader_parameter("tint", tint.lerp(Color(1.15, 1.05, 0.85), night))
	for k in _sprite_meshes:
		((_sprite_meshes[k] as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("tint", tint)


# ---------------------------------------------------------------- compatibility

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
	return {"top": 1, "w": W, "d": D, "ground": U.rle_encode(ground), "objects": objects.duplicate(true)}


func load_data(d: Dictionary, _style := "") -> void:
	if int(d.get("w", 0)) != W or int(d.get("d", 0)) != D or not d.has("ground"):
		new_world()
		return
	ground = U.rle_decode(str(d["ground"]), W * D)
	objects = []
	for o in d.get("objects", []):
		if o is Array and o.size() >= 3:
			objects.append([str(o[0]), int(o[1]), int(o[2])])
	rebuild()
