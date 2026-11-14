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

## The village map; NPCs stay on it.
const MAP := Styles.SIZE
## Total width: the map plus a strip well east of it holding house
## interiors (out of view of the map; each room is shown on its own).
const W := MAP + 48
const ROOM_X := MAP + 30
const D := Styles.SIZE
## House interiors: up to 8 rooms of 12 × 7 tiles in the strip.
const ROOM_W := 12
const ROOM_D := 7
const ROOM_SLOTS := 8
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
## Placed objects: [key, x, z] with (x, z) the south-west tile of the
## footprint. Houses add a fourth entry: their interior room slot (-1: none).
var objects: Array = []
## Door cells -> where they take you: Vector2i -> Vector3.
var _portals := {}
## Ground tiles from imported tile sets (TileSets): ids from 100.
var custom: Array = []
var _custom_meshes: Array[MeshInstance3D] = []
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
## One node per furnished room (shown only while you're inside it).
var _rooms := {}
var _black := MeshInstance3D.new()
var _shown_slot := -2


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
	# Plain black everywhere there's no ground (around the map and rooms).
	var pm := PlaneMesh.new()
	pm.size = Vector2(4000, 4000)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color("0b0e14")
	_black.mesh = pm
	_black.material_override = bm
	_black.position = Vector3(W / 2.0, -0.05, D / 2.0)
	_black.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_black)


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


## Footstep surface under `p` (see Sounds.surface_of).
func surface_at(p: Vector3) -> String:
	var id := ground_id(int(floor(p.x)), int(floor(p.z)))
	if id <= 0 or id >= PixelTopArt.GROUND.size():
		return "stone" if id >= TileSets.CUSTOM_BASE else "grass"
	return Sounds.surface_of(str((PixelTopArt.GROUND[id] as Dictionary).get("name", "")))


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


## The object whose picture is under a ground point (front-most first), so
## clicking a tree's canopy or a house's roof finds it, not just its base.
func object_at_point(p: Vector3) -> int:
	var best := -1
	var best_z := -1e9
	for i in objects.size():
		var o: Array = objects[i]
		var d := obj_def(str(o[0]))
		if d.is_empty():
			continue
		var w := float(d["w"]) / PixelWorld.PPM
		var h := float(d["h"]) / PixelWorld.PPM
		var south := float(o[2]) + 1.0
		var cx := float(o[1]) + float(d.get("fw", 1)) / 2.0
		if p.x >= cx - w / 2.0 and p.x <= cx + w / 2.0 and p.z >= south - h and p.z <= south and south > best_z:
			best = i
			best_z = south
	return best


func remove_object(i: int) -> void:
	if i < 0 or i >= objects.size():
		return
	var o: Array = objects[i]
	remove_object_at(int(o[1]), int(o[2]))


func object_at(x: int, z: int) -> int:
	for i in range(objects.size() - 1, -1, -1):
		if _cells_of(objects[i]).has(Vector2i(x, z)):
			return i
	return -1


## Places an object if its footprint is free; returns whether it did. A
## house gets an interior room when there's a free slot.
func place_object(key: String, x: int, z: int, rebuild_now := true) -> bool:
	var o := [key, x, z]
	for c in _cells_of(o):
		if not in_bounds(c.x, c.y) or object_at(c.x, c.y) >= 0:
			return false
	if obj_def(key).is_empty():
		return false
	if key == "house":
		if x + 4 > MAP:
			return false
		var slot := _free_slot()
		o.append(slot)
		objects.append(o)
		if slot >= 0:
			_build_room(slot)
	else:
		objects.append(o)
	if rebuild_now:
		rebuild()
	return true


func remove_object_at(x: int, z: int) -> bool:
	var i := object_at(x, z)
	if i < 0:
		return false
	var o: Array = objects[i]
	objects.remove_at(i)
	if str(o[0]) == "house" and o.size() > 3 and int(o[3]) >= 0:
		_clear_room(int(o[3]))
	rebuild()
	return true


# ---------------------------------------------------------------- house interiors

## South-west corner of a room slot (inside the walls).
static func room_origin(slot: int) -> Vector2i:
	return Vector2i(ROOM_X, 3 + slot * (ROOM_D + 2))


static func room_rect(slot: int) -> Rect2i:
	var o := room_origin(slot)
	return Rect2i(o.x - 1, o.y - 1, ROOM_W + 2, ROOM_D + 2)


## The room slot a position is in, or -1 outside.
static func slot_at(p: Vector3) -> int:
	for s in ROOM_SLOTS:
		if room_rect(s).has_point(Vector2i(int(floor(p.x)), int(floor(p.z)))):
			return s
	return -1


func _free_slot() -> int:
	var used := {}
	for o in objects:
		if str(o[0]) == "house" and o.size() > 3:
			used[int(o[3])] = true
	for s in ROOM_SLOTS:
		if not used.has(s):
			return s
	return -1


## Walls, wooden floor, a rug, furniture and a door in the south wall.
func _build_room(slot: int) -> void:
	_clear_room(slot)
	var o := room_origin(slot)
	var G := PixelTopArt.G
	for z in range(o.y - 1, o.y + ROOM_D + 1):
		for x in range(o.x - 1, o.x + ROOM_W + 1):
			var edge := x == o.x - 1 or z == o.y - 1 or x == o.x + ROOM_W or z == o.y + ROOM_D
			ground[idx(x, z)] = G["wall"] if edge else G["wood"]
	for z in range(o.y + 2, o.y + 5):
		for x in range(o.x + 4, o.x + 8):
			ground[idx(x, z)] = G["carpet"]
	for x in _door_xs(o):
		ground[idx(x, o.y + ROOM_D)] = G["doorway"]
	var r := U.rng(700 + slot * 97)
	var furn := [["bed", o.x, o.y + 1], ["bookshelf", o.x + 3, o.y], ["fireplace", o.x + 9, o.y], ["table", o.x + 5, o.y + 3], ["chair", o.x + 4, o.y + 3],
		["chest", o.x + 11, o.y + 4], ["plant", o.x, o.y + 6], ["plant", o.x + 11, o.y + 6]]
	for f in furn:
		if r.next() < 0.9 or f[0] in ["bed", "table"]:
			place_object(f[0], f[1], f[2], false)


static func _door_xs(o: Vector2i) -> Array:
	return [o.x + ROOM_W / 2 - 1, o.x + ROOM_W / 2]


func _clear_room(slot: int) -> void:
	var o := room_origin(slot)
	var rect := Rect2i(o.x - 1, o.y - 1, ROOM_W + 2, ROOM_D + 2)
	for i in range(objects.size() - 1, -1, -1):
		if rect.has_point(Vector2i(int(objects[i][1]), int(objects[i][2]))):
			objects.remove_at(i)
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if in_bounds(x, z):
				ground[idx(x, z)] = PixelTopArt.G["void"]


## A house's door cells: the middle two of its front row.
static func _house_doors(o: Array) -> Array:
	return [Vector2i(int(o[1]) + 1, int(o[2])), Vector2i(int(o[1]) + 2, int(o[2]))]


func _update_portals() -> void:
	_portals.clear()
	for o in objects:
		if str(o[0]) != "house" or o.size() < 4 or int(o[3]) < 0:
			continue
		var ro := room_origin(int(o[3]))
		# In through the front door: arrive just inside the room's door.
		var inside := Vector3(ro.x + ROOM_W / 2.0, 0, ro.y + ROOM_D - 1.0)
		for c in _house_doors(o):
			_portals[c] = inside
		# Out through the room's door: arrive on the path outside the house.
		var outside := Vector3(float(o[1]) + 2.0, 0, float(o[2]) + 1.6)
		for x in _door_xs(ro):
			_portals[Vector2i(x, ro.y + ROOM_D)] = outside


## Where a door at `p` leads, or null.
func portal_at(p: Vector3) -> Variant:
	return _portals.get(Vector2i(int(floor(p.x)), int(floor(p.z))))


## Whether `p` is inside a house interior.
func indoors(p: Vector3) -> bool:
	return p.x >= MAP


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
	var cx := int(floor(x))
	var cz := int(floor(z))
	return x >= 1.0 and z >= 1.0 and x < MAP - 1 and z < D - 1 and not solid_cell(cx, cz) and not _water_cell(cx, cz)


func _water_cell(x: int, z: int) -> bool:
	return PixelTopArt.GROUND[ground_id(x, z)].get("water", false) if ground_id(x, z) < PixelTopArt.GROUND.size() else false


## Top view: water is swum across at ground level (0), else -1e9.
func water_surface(p: Vector3) -> float:
	return 0.0 if _water_cell(int(floor(p.x)), int(floor(p.z))) else -1.0e9


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

## World layouts besides the default village (see Templates).
const LAYOUTS := ["forest", "mountain", "city"]


func new_world(_style := "pixeltop", layout := "") -> void:
	var r := U.rng(5151)
	var G := PixelTopArt.G
	ground.fill(G["void"])
	objects.clear()
	var c := MAP / 2
	if layout in LAYOUTS:
		for z in D:
			for x in MAP:
				ground[idx(x, z)] = G["grass"]
		call("_layout_" + layout, r)
		rebuild()
		return
	for z in D:
		for x in MAP:
			ground[idx(x, z)] = G["grass"]
			var v := r.next()
			if v < 0.08:
				ground[idx(x, z)] = G["meadow"]
			elif v < 0.14:
				ground[idx(x, z)] = G["dark"]
	# Crossroads and a plaza around the well.
	for k in MAP:
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
		var x := int(r.next() * MAP)
		var z := int(r.next() * D)
		var center := absf(x - c) < 18 and absf(z - c) < 16
		var on_path := absi(x - c) < 3 or absi(z - c) < 3
		if center or on_path or ground_id(x, z) in [G["water"], G["farm"], G["sand"]]:
			continue
		var edge := minf(minf(x, MAP - x), minf(z, D - z))
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


## Trees and the rest scattered where `ok(x, z)` allows.
func _scatter(r: U.Rng, n: int, keys: Array, ok: Callable) -> void:
	for k in n:
		var x := int(r.next() * MAP)
		var z := int(r.next() * D)
		if ok.call(x, z):
			place_object(keys[int(r.next() * keys.size())], x, z, false)


## Deep woods with a clearing in the middle and a winding trail.
func _layout_forest(r: U.Rng) -> void:
	var G := PixelTopArt.G
	var c := MAP / 2
	for z in D:
		for x in MAP:
			if r.next() < 0.18:
				ground[idx(x, z)] = G["dark"]
	for z in D:
		var tx := c + int(round(sin(z * 0.15) * 4.0))
		for w in [-1, 0]:
			ground[idx(tx + w, z)] = G["path"]
	for z in range(c - 5, c + 5):
		for x in range(c - 6, c + 6):
			ground[idx(x, z)] = G["meadow"]
	_recompute_solid()
	place_object("stump", c - 4, c + 2, false)
	place_object("stump", c + 3, c - 3, false)
	_scatter(r, 900, ["tree", "pine", "pine", "bush", "tree", "rock", "flowers", "stump"], func(x: int, z: int) -> bool:
		var trail := absi(x - (c + int(round(sin(z * 0.15) * 4.0)))) < 3
		return not trail and not (absi(x - c) < 8 and absi(z - c) < 7))


## A snowy mountain pass: rock and ice on both sides, a road through the snow.
func _layout_mountain(r: U.Rng) -> void:
	var G := PixelTopArt.G
	var c := MAP / 2
	for z in D:
		for x in MAP:
			var road := absi(x - (c + int(round(sin(z * 0.1) * 5.0))))
			ground[idx(x, z)] = G["path"] if road < 2 else G["snow"]
			if road > 9 and r.next() < 0.06:
				ground[idx(x, z)] = G["ice"]
	_recompute_solid()
	place_object("tent", c + 4, c - 2, false)
	place_object("campfire", c + 4, c + 2, false)
	_scatter(r, 700, ["pine", "pine", "rock", "rock", "deadtree"], func(x: int, z: int) -> bool:
		return absi(x - (c + int(round(sin(z * 0.1) * 5.0)))) > 4 and not (absi(x - c - 4) < 4 and absi(z - c) < 5))


## A town at night: a cobbled square, streets in a grid lined with houses,
## stalls and lamps.
func _layout_city(r: U.Rng) -> void:
	var G := PixelTopArt.G
	var c := MAP / 2
	for z in D:
		for x in MAP:
			var street := (x - 2) % 14 >= 10 or (z - 2) % 14 >= 10
			ground[idx(x, z)] = G["cobble"] if street else G["grass"]
	for z in range(c - 6, c + 6):
		for x in range(c - 7, c + 7):
			ground[idx(x, z)] = G["plaza"]
	_recompute_solid()
	place_object("fountain", c - 1, c - 1, false)
	for sx in [c - 6, c + 4]:
		place_object("stall", sx, c + 3, false)
	for bx in range(2, MAP - 9, 14):
		for bz in range(2, D - 9, 14):
			if absi(bx + 4 - c) < 11 and absi(bz + 4 - c) < 11:
				continue
			place_object("house", bx + 1, bz + 4, false)
			place_object("house", bx + 5, bz + 4, false)
			place_object("tree", bx + 2, bz + 8, false)
			place_object("barrel", bx + 8, bz + 8, false)
	for x in range(6, MAP - 3, 7):
		for z in range(6, D - 3, 7):
			if ((x - 2) % 14 >= 10 or (z - 2) % 14 >= 10) and object_at(x, z) < 0:
				place_object("lamp", x, z, false)


# ---------------------------------------------------------------- meshes

func _recompute_solid() -> void:
	_solid.fill(0)
	for z in D:
		for x in W:
			var gid := ground[idx(x, z)]
			if gid < PixelTopArt.GROUND.size() and PixelTopArt.GROUND[gid].get("block", false) and not PixelTopArt.GROUND[gid].get("water", false):
				_solid[idx(x, z)] = 1
	for o in objects:
		if not obj_def(str(o[0])).get("solid", false):
			continue
		var doors: Array = _house_doors(o) if str(o[0]) == "house" and o.size() > 3 and int(o[3]) >= 0 else []
		for cell in _cells_of(o):
			if in_bounds(cell.x, cell.y) and not doors.has(cell):
				_solid[idx(cell.x, cell.y)] = 1
	_update_portals()


func rebuild() -> void:
	_recompute_solid()
	var map := Rect2i(0, 0, MAP, D)
	_ground_mesh.mesh = _ground_layer(func(id): return not PixelTopArt.GROUND[id].get("water", false), map)
	_water_mesh.mesh = _ground_layer(func(id): return PixelTopArt.GROUND[id].get("water", false), map)
	_obj_mesh.mesh = _object_layer(func(k): return PixelTopArt.OBJECTS.has(k) and not PixelTopArt.OBJECTS[k].get("glow", false), map)
	_glow_mesh.mesh = _object_layer(func(k): return PixelTopArt.OBJECTS.has(k) and PixelTopArt.OBJECTS[k].get("glow", false), map)
	_rebuild_rooms()
	_rebuild_sprites()
	for mi in _custom_meshes:
		mi.queue_free()
	_custom_meshes.clear()
	_custom_meshes.append_array(TileSets.meshes(custom, ground, func(cell: int) -> Vector2: return Vector2(cell % W, cell / W), self, 0.0, true))
	_shown_slot = -2


func custom_id(set_id: String, i: int, _behind := false) -> int:
	return TileSets.register(custom, set_id, i, false)


func custom_icon(id: int) -> Texture2D:
	var c: Dictionary = custom[id - TileSets.CUSTOM_BASE]
	return TileSets.icon(str(c["set"]), int(c["i"]))


## Imported ground tiles never block walking.
func tile_solid(_id: int) -> bool:
	return false


## Rooms: each slot's floor, walls and furniture as its own node.
func _rebuild_rooms() -> void:
	for k in _rooms:
		(_rooms[k] as Node).queue_free()
	_rooms.clear()
	_shown_slot = -2
	for o in objects:
		if str(o[0]) != "house" or o.size() < 4 or int(o[3]) < 0:
			continue
		var slot: int = o[3]
		var rect := room_rect(slot)
		var node := Node3D.new()
		var g := MeshInstance3D.new()
		g.mesh = _ground_layer(func(_id): return true, rect)
		g.material_override = _mat
		var f := MeshInstance3D.new()
		f.mesh = _object_layer(func(k): return PixelTopArt.OBJECTS.has(k), rect)
		f.material_override = _obj_mat
		for mi in [g, f]:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			node.add_child(mi)
		node.visible = false
		add_child(node)
		_rooms[slot] = node


func _ground_layer(keep: Callable, rect: Rect2i) -> ArrayMesh:
	var q := _Quads.new()
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var id := ground[idx(x, z)]
			if id == 0 or id == PixelTopArt.G["void"] or id >= PixelTopArt.GROUND.size() or not keep.call(id):
				continue
			var r := PixelTopArt.ground_uv(id)
			q.flat(Vector3(x, 0, z), Vector2(1, 1), r)
	return q.mesh()


## Object sprites lying on the ground, bottom edge at the footprint's south
## side, reaching north; lifted by depth so southern things draw on top.
func _object_layer(keep: Callable, rect: Rect2i) -> ArrayMesh:
	var q := _Quads.new()
	for o in objects:
		var key := str(o[0])
		if not keep.call(key) or not rect.has_point(Vector2i(int(o[1]), int(o[2]))):
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

## Inside a house only that room shows; outside, only the map does.
func _update_visibility() -> void:
	var studio: Node = get_parent()
	var pl: Variant = studio.get("player") if studio else null
	var slot := slot_at((pl as Actor).pos) if pl is Actor else -1
	if slot == _shown_slot:
		return
	_shown_slot = slot
	var outdoors := slot < 0
	for n in [_ground_mesh, _water_mesh, _obj_mesh, _glow_mesh]:
		(n as Node3D).visible = outdoors
	for mi in _custom_meshes:
		mi.visible = outdoors
	for k in _sprite_meshes:
		(_sprite_meshes[k] as Node3D).visible = outdoors
	for k in _rooms:
		(_rooms[k] as Node3D).visible = k == slot


func animate(_dt: float, _t: float) -> void:
	_update_visibility()
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
	for mi in _custom_meshes:
		(mi.material_override as ShaderMaterial).set_shader_parameter("tint", tint)


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
	return {"top": 1, "w": W, "d": D, "ground": U.rle_encode(ground), "objects": objects.duplicate(true), "custom": custom.duplicate(true)}


func load_data(d: Dictionary, _style := "") -> void:
	if int(d.get("w", 0)) != W or int(d.get("d", 0)) != D or not d.has("ground"):
		new_world()
		return
	ground = U.rle_decode(str(d["ground"]), W * D)
	custom = (d.get("custom", []) as Array).duplicate(true)
	objects = []
	for o in d.get("objects", []):
		if o is Array and o.size() >= 3:
			var e := [str(o[0]), int(o[1]), int(o[2])]
			if o.size() > 3:
				e.append(int(o[3]))
			objects.append(e)
	rebuild()
