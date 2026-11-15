class_name VoxelWorld
extends Node3D
## Blocky world: a 48 x 24 x 48 grid of block ids, meshed in 16 x 16 column
## chunks with baked ambient occlusion. Separate surfaces for opaque, glass,
## water and glowing blocks; glowing blocks also get a few real lights.
##
## Data layout and save format match the web build so old projects open.

const WX := 80
const WY := 24
const WZ := 80
const CH := 16
const CX := 5  # WX / CH
const CZ := 5  # WZ / CH
const HW := 0.28
const HH := 1.75
const MAX_LIGHTS := 12
const AO := [0.5, 0.68, 0.84, 1.0]

const PREFABS := {
	"cottage": {"name": "Cottage", "icon": "planks"},
	"tower": {"name": "Tower", "icon": "cobble"},
	"tree": {"name": "Tree", "icon": "leaves"},
	"well": {"name": "Well", "icon": "water"},
	"stall": {"name": "Market stall", "icon": "red"},
	"fountain": {"name": "Fountain", "icon": "brick"},
	"lamp": {"name": "Lamp post", "icon": "lamp"},
}

# Face table (same order and corners as the web build).
const FACES := [
	{"n": Vector3i(1, 0, 0), "c": [Vector3i(1, 1, 1), Vector3i(1, 1, 0), Vector3i(1, 0, 1), Vector3i(1, 0, 0)], "t": "side", "ax": [1, 2]},
	{"n": Vector3i(-1, 0, 0), "c": [Vector3i(0, 1, 0), Vector3i(0, 1, 1), Vector3i(0, 0, 0), Vector3i(0, 0, 1)], "t": "side", "ax": [1, 2]},
	{"n": Vector3i(0, 1, 0), "c": [Vector3i(0, 1, 0), Vector3i(1, 1, 0), Vector3i(0, 1, 1), Vector3i(1, 1, 1)], "t": "top", "ax": [0, 2]},
	{"n": Vector3i(0, -1, 0), "c": [Vector3i(0, 0, 1), Vector3i(1, 0, 1), Vector3i(0, 0, 0), Vector3i(1, 0, 0)], "t": "bottom", "ax": [0, 2]},
	{"n": Vector3i(0, 0, 1), "c": [Vector3i(0, 1, 1), Vector3i(1, 1, 1), Vector3i(0, 0, 1), Vector3i(1, 0, 1)], "t": "side", "ax": [0, 1]},
	{"n": Vector3i(0, 0, -1), "c": [Vector3i(1, 1, 0), Vector3i(0, 1, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 0)], "t": "side", "ax": [0, 1]},
]

enum { G_OPAQUE, G_TRANS, G_WATER, G_GLOW }

var is_voxel := true
var size := WX
var data := PackedByteArray()

var _dirty := {}
var _chunks := {}  # Vector2i -> Array[MeshInstance3D] (one per group)
var _mats: Array[Material] = []
var _lights_node: Node3D
var _lights: Array[OmniLight3D] = []
var _light_base: Array[float] = []
var _floor: MeshInstance3D


func _init() -> void:
	Blocks.init()
	data.resize(WX * WY * WZ)
	name = "VoxelWorld"


func _ready() -> void:
	_build_materials()
	_lights_node = Node3D.new()
	_lights_node.name = "Lights"
	add_child(_lights_node)
	_build_floor()


func _process(dt: float) -> void:
	if not _flow.is_empty():
		_flow_t += dt
		var n := 0
		while _flow_t >= FLOW_STEP and n < 3:
			_flow_t -= FLOW_STEP
			flow_step()
			n += 1
	if not _dirty.is_empty():
		_flush()


# ================================================================ flowing water
# Water you place (or that a removed block lets out) falls straight down into
# empty space, then spreads sideways up to FLOW_SPREAD blocks from where it
# lands, a step at a time so you see it run. A step runs every FLOW_STEP
# seconds; FLOW_MAX blocks at most per pour, so one block can't flood the
# world. Only edits start it: generating or loading a world doesn't.

const FLOW_STEP := 0.07
const FLOW_SPREAD := 5
const FLOW_MAX := 3000
## The flow's edge: block -> how far it may still spread sideways.
var _flow := {}
var _flow_t := 0.0
var _flow_n := 0
var _flowing := false


func flowing() -> bool:
	return not _flow.is_empty()


## Runs the flow to the end at once (tests, and before saving a snapshot).
func settle_water() -> void:
	var guard := 0
	while not _flow.is_empty() and guard < 400:
		flow_step()
		guard += 1


func flow_step() -> void:
	var wid := _id("water")
	var edge := _flow
	_flow = {}
	_flowing = true
	for c: Vector3i in edge:
		if get_b(c.x, c.y, c.z) != wid:
			continue
		var left: int = edge[c]
		# Falls first: down into empty space, and spreads again where it lands.
		if c.y > 0 and get_b(c.x, c.y - 1, c.z) == 0:
			set_b(c.x, c.y - 1, c.z, wid)
			_flow[Vector3i(c.x, c.y - 1, c.z)] = FLOW_SPREAD
			_flow_n += 1
			continue
		if left <= 0 or (c.y > 0 and get_b(c.x, c.y - 1, c.z) == wid):
			# Out of reach, or resting on water (it joins the pool below).
			continue
		for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var nb: Vector3i = c + d
			if inside(nb.x, nb.y, nb.z) and get_b(nb.x, nb.y, nb.z) == 0:
				set_b(nb.x, nb.y, nb.z, wid)
				_flow[nb] = left - 1
				_flow_n += 1
		if _flow_n > FLOW_MAX:
			_flow.clear()
			break
	_flowing = false


func _wake_water(x: int, y: int, z: int, v: int) -> void:
	var wid := _id("water")
	if wid == 0:
		return
	if v == wid:
		_flow[Vector3i(x, y, z)] = FLOW_SPREAD
		_flow_n = 0
	elif v == 0:
		# A gap opened next to water: the water around it runs in.
		for d in [Vector3i(0, 1, 0), Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var nb: Vector3i = Vector3i(x, y, z) + d
			if get_b(nb.x, nb.y, nb.z) == wid:
				_flow[nb] = maxi(int(_flow.get(nb, 0)), FLOW_SPREAD - 1)
				_flow_n = 0


# ================================================================ data access

static func idx(x: int, y: int, z: int) -> int:
	return (y * WZ + z) * WX + x


static func inside(x: int, y: int, z: int) -> bool:
	return x >= 0 and y >= 0 and z >= 0 and x < WX and y < WY and z < WZ


func get_b(x: int, y: int, z: int) -> int:
	return data[idx(x, y, z)] if inside(x, y, z) else 0


func set_b(x: int, y: int, z: int, v: int) -> void:
	if not inside(x, y, z):
		return
	var i := idx(x, y, z)
	if data[i] == v:
		return
	data[i] = v
	_mark(x, z)
	if not _flowing:
		_wake_water(x, y, z, v)


## Natural ground: what the world generator lays down. Everything else
## (bricks, planks, logs, leaves, glass...) belongs to a building or tree.
const GROUND_KEYS := ["grass", "dirt", "stone", "sand", "sandstone", "snow", "ice", "water", "path", "gravel", "bedrock", "clay"]


## Removes the building or tree that block (x, y, z) is part of: every
## connected block that isn't natural ground. Returns how many went.
func clear_structure(x: int, y: int, z: int) -> int:
	var ground := {}
	for k in GROUND_KEYS:
		var gid := _id(k)
		if gid != 0:
			ground[gid] = true
	var part := func(cx: int, cy: int, cz: int) -> bool:
		var v := get_b(cx, cy, cz)
		return v != 0 and not ground.has(v)
	if not part.call(x, y, z):
		return 0
	var todo: Array[Vector3i] = [Vector3i(x, y, z)]
	var seen := {Vector3i(x, y, z): true}
	var n := 0
	while not todo.is_empty() and n < 6000:
		var c: Vector3i = todo.pop_back()
		set_b(c.x, c.y, c.z, 0)
		n += 1
		for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
			var nb: Vector3i = c + d
			if not seen.has(nb) and part.call(nb.x, nb.y, nb.z):
				seen[nb] = true
				todo.append(nb)
	return n


func _set_raw(x: int, y: int, z: int, v: int) -> void:
	if inside(x, y, z):
		data[idx(x, y, z)] = v


func _mark(x: int, z: int) -> void:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var cx := clampi((x + dx) / CH, 0, CX - 1)
			var cz := clampi((z + dz) / CH, 0, CZ - 1)
			if x + dx >= 0 and z + dz >= 0:
				_dirty[Vector2i(cx, cz)] = true


func solid_at(x: int, y: int, z: int) -> bool:
	if y < 0:
		return true
	if x < 0 or z < 0 or x >= WX or z >= WZ:
		return true
	if y >= WY:
		return false
	var v := data[idx(x, y, z)]
	if v == 0:
		return false
	var b := Blocks.get_block(v)
	return not b.is_empty() and not b.get("deleted", false) and b.get("kind", "") != "water"


func is_opaque(x: int, y: int, z: int) -> bool:
	if y < 0:
		return true
	var v := get_b(x, y, z)
	if v == 0:
		return false
	var b := Blocks.get_block(v)
	return not b.is_empty() and not b.get("see", false) and not b.get("deleted", false)


func fill_box(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, v: int) -> void:
	for y in range(y0, y1 + 1):
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				_set_raw(x, y, z, v)
	_mark_all()


func ground_y(x: float, z: float) -> int:
	var ix := clampi(int(floor(x)), 0, WX - 1)
	var iz := clampi(int(floor(z)), 0, WZ - 1)
	for y in range(WY - 1, -1, -1):
		if solid_at(ix, y, iz):
			return y + 1
	return 0


func ground_at(x: float, z: float) -> float:
	return float(ground_y(x, z))


func box_hits(p: Vector3) -> bool:
	var x0 := int(floor(p.x - HW))
	var x1 := int(floor(p.x + HW))
	var y0 := int(floor(p.y))
	var y1 := int(floor(p.y + HH))
	var z0 := int(floor(p.z - HW))
	var z1 := int(floor(p.z + HW))
	for y in range(y0, y1 + 1):
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				if solid_at(x, y, z):
					return true
	return false


func body_blocked(p: Vector3) -> bool:
	return box_hits(p)


## Top of the water a body at `p` is in, else -1e9.
func water_surface(p: Vector3) -> float:
	var x := int(floor(p.x))
	var z := int(floor(p.z))
	var y := int(floor(p.y + 0.1))
	if not _is_water(x, y, z):
		return -1.0e9
	while y < WY - 1 and _is_water(x, y + 1, z):
		y += 1
	return float(y + 1)


## Top of the first solid block below `p` (the bed under the water).
func water_bottom(p: Vector3) -> float:
	var x := int(floor(p.x))
	var z := int(floor(p.z))
	var y := int(floor(p.y + 0.1))
	while y > 0 and not solid_at(x, y - 1, z):
		y -= 1
	return float(y)


func _is_water(x: int, y: int, z: int) -> bool:
	var v := get_b(x, y, z)
	return v != 0 and Blocks.get_block(v).get("kind", "") == "water"


## Footstep surface under `p` (see Sounds.surface_of).
func surface_at(p: Vector3) -> String:
	var x := int(floor(p.x))
	var z := int(floor(p.z))
	for dy in [0.05, 1.05]:
		var b := get_b(x, int(floor(p.y - dy)), z)
		if b > 0:
			return Sounds.surface_of(str(Blocks.get_block(b).get("key", "")))
	return "grass"


func walkable(x: float, z: float) -> bool:
	return x >= 1.0 and z >= 1.0 and x < WX - 1 and z < WZ - 1 and ground_y(x, z) < WY - 2


# ================================================================ generation

## World layouts besides the default meadow village (see Templates).
const LAYOUTS := ["forest", "mountain", "city", "indoor"]


func new_world(_style_key := "blocky", layout := "") -> void:
	Blocks.reset_custom()
	generate(layout if layout in LAYOUTS else "meadow")
	rebuild()


static func _hash2(x: float, z: float, s: float) -> float:
	var v := sin(x * 127.1 + z * 311.7 + s * 74.7) * 43758.5453
	return v - floor(v)


static func _noise2(x: float, z: float, s: float) -> float:
	var ix := floorf(x)
	var iz := floorf(z)
	var fx := x - ix
	var fz := z - iz
	var sx := fx * fx * (3.0 - 2.0 * fx)
	var sz := fz * fz * (3.0 - 2.0 * fz)
	var a := _hash2(ix, iz, s)
	var b := _hash2(ix + 1, iz, s)
	var c := _hash2(ix, iz + 1, s)
	var d := _hash2(ix + 1, iz + 1, s)
	return lerpf(lerpf(a, b, sx), lerpf(c, d, sx), sz)


static func _fbm(x: float, z: float, s: float) -> float:
	return _noise2(x / 16.0, z / 16.0, s) * 0.6 + _noise2(x / 8.0, z / 8.0, s + 9) * 0.3 + _noise2(x / 4.0, z / 4.0, s + 17) * 0.1


func _id(key: String) -> int:
	return Blocks.ID.get(key, 0)


func _tree(x: int, y: int, z: int, r: U.Rng, snowy: bool) -> void:
	var h := 4 + int(r.next() * 2)
	var log_id := _id("log")
	var leaves := _id("leaves")
	for i in h:
		_set_raw(x, y + i, z, log_id)
	var ty := y + h - 1
	for dy in range(-1, 3):
		var rad := 1 if dy >= 1 else 2
		for dx in range(-rad, rad + 1):
			for dz in range(-rad, rad + 1):
				if absi(dx) == rad and absi(dz) == rad and r.next() < 0.6:
					continue
				if get_b(x + dx, ty + dy, z + dz) == 0:
					_set_raw(x + dx, ty + dy, z + dz, leaves)
	if snowy:
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var top := ground_y(x + dx, z + dz)
				if get_b(x + dx, top - 1, z + dz) == leaves and top < WY:
					_set_raw(x + dx, top, z + dz, _id("snow"))


func _house(x0: int, z0: int, fy: int, w: int, d: int, wall: int, roof: int) -> Vector2i:
	_fill_raw(x0 - 1, fy + 1, z0 - 1, x0 + w, fy + 8, z0 + d, 0)
	_fill_raw(x0, fy, z0, x0 + w - 1, fy, z0 + d - 1, _id("planks"))
	for y in range(fy + 1, fy + 4):
		for x in range(x0, x0 + w):
			for z in range(z0, z0 + d):
				var ex := x == x0 or x == x0 + w - 1
				var ez := z == z0 or z == z0 + d - 1
				if not ex and not ez:
					continue
				_set_raw(x, y, z, _id("log") if ex and ez else wall)
	var mx := x0 + (w >> 1)
	var mz := z0 + (d >> 1)
	var glass := _id("glass")
	_set_raw(x0, fy + 2, mz, glass)
	_set_raw(x0 + w - 1, fy + 2, mz, glass)
	_set_raw(x0 + 1, fy + 2, z0 + d - 1, glass)
	_set_raw(x0 + w - 2, fy + 2, z0 + d - 1, glass)
	_set_raw(mx, fy + 1, z0, 0)
	_set_raw(mx, fy + 2, z0, 0)
	for k in 3:
		_fill_raw(x0 - 1 + k, fy + 4 + k, z0 - 1 + k, x0 + w - k, fy + 4 + k, z0 + d - k, roof)
	_set_raw(x0 + 1, fy + 1, z0 + d - 2, _id("lamp"))
	_set_raw(mx - 2, fy + 1, z0 - 2, _id("log"))
	_set_raw(mx - 2, fy + 2, z0 - 2, _id("lamp"))
	return Vector2i(mx, z0)


func _fill_raw(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, v: int) -> void:
	for y in range(y0, y1 + 1):
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				_set_raw(x, y, z, v)


## Fills the grid with a starter landscape: "meadow", "desert", "snow",
## "plaza" or "flat". Call rebuild() afterwards (new_world does both).
func generate(kind: String, p_seed := -1) -> void:
	_flow.clear()
	data.fill(0)
	_mark_all()
	var seed_v := p_seed if p_seed >= 0 else randi() % 1000
	var r := U.rng(seed_v + 1)
	var cx := WX >> 1
	var cz := WZ >> 1
	var stone := _id("stone")
	if kind == "flat":
		_fill_raw(0, 0, 0, WX - 1, 2, WZ - 1, stone)
		_fill_raw(0, 3, 0, WX - 1, 3, WZ - 1, _id("dirt"))
		_fill_raw(0, 4, 0, WX - 1, 4, WZ - 1, _id("grass"))
		return
	if kind == "mountain":
		_gen_mountain(r, seed_v)
		return
	if kind == "city":
		_gen_city(r)
		return
	if kind == "indoor":
		_gen_indoor()
		return
	if kind == "plaza":
		_fill_raw(0, 0, 0, WX - 1, 3, WZ - 1, stone)
		_fill_raw(0, 4, 0, WX - 1, 4, WZ - 1, _id("cobble"))
		_fill_raw(cx - 3, 4, cz - 3, cx + 2, 4, cz + 2, _id("planks"))
		_fill_raw(cx - 2, 5, cz - 2, cx + 1, 5, cz + 1, _id("brick"))
		_fill_raw(cx - 1, 5, cz - 1, cx, 5, cz, _id("water"))
		var far := WX - 16
		var spots := [[6, 6], [far, 6], [6, far], [far, far]]
		var mats := [_id("brick"), _id("sandstone"), _id("planks"), _id("brick")]
		for i in spots.size():
			var x: int = spots[i][0]
			var z: int = spots[i][1]
			var w := 9 + int(r.next() * 3)
			var d := 8 + int(r.next() * 3)
			var h := 6 + int(r.next() * 6)
			var m: int = mats[i]
			for y in range(5, 5 + h):
				for xx in range(x, x + w):
					for zz in range(z, z + d):
						var edge := xx == x or xx == x + w - 1 or zz == z or zz == z + d - 1
						if not edge:
							continue
						_set_raw(xx, y, zz, _id("glass") if (y % 3 == 0 and (xx + zz) % 3 == 1) else m)
			_fill_raw(x, 5 + h, z, x + w - 1, 5 + h, z + d - 1, stone)
		for q in [[cx - 8, cz - 8], [cx + 7, cz - 8], [cx - 8, cz + 7], [cx + 7, cz + 7], [cx, cz - 12], [cx, cz + 11]]:
			_fill_raw(q[0], 5, q[1], q[0], 7, q[1], _id("basalt"))
			_set_raw(q[0], 8, q[1], _id("lamp"))
		for i in 4:
			_tree(cx - 10 + i * 6, 5, cz + 15, r, false)
		return
	var water := 5
	for x in WX:
		for z in WZ:
			var h := 4 + roundi(_fbm(x, z, seed_v) * 7.0)
			var dist := Vector2(x - cx, z - cz).length()
			var f := clampf((dist - 7.0) / 6.0, 0.0, 1.0)
			h = roundi(lerpf(6.0, float(h), f))
			for y in range(0, h + 1):
				var id := stone
				if kind == "desert":
					id = _id("sand") if y == h or y > h - 3 else _id("sandstone")
				elif kind == "snow":
					id = _id("snow") if y == h else (_id("dirt") if y > h - 3 else stone)
				else:
					id = (_id("sand") if h <= water else _id("grass")) if y == h else (_id("dirt") if y > h - 3 else stone)
				_set_raw(x, y, z, id)
			if h < water:
				for y in range(h + 1, water + 1):
					_set_raw(x, y, z, _id("ice") if kind == "snow" and y == water else _id("water"))
	var forest := kind == "forest"
	var door := Vector2i(cx, 0)
	if not forest:
		door = _house(cx - 3, cz - 2, 6, 7, 6, _id("sandstone") if kind == "desert" else _id("planks"), _id("sandstone") if kind == "desert" else _id("brick"))
	if kind != "desert" and not forest:
		for z in range(0, door.y - 1):
			var y := ground_y(door.x, z) - 1
			var t := get_b(door.x, y, z)
			if t == _id("grass") or t == _id("snow"):
				_set_raw(door.x, y, z, _id("path"))
	# A forest: three times the trees, with a clearing in the middle.
	for i in int((180.0 if forest else 60.0) * WX * WZ / 2304.0):
		var x := 2 + int(r.next() * (WX - 4))
		var z := 2 + int(r.next() * (WZ - 4))
		if Vector2(x - cx, z - cz).length() < (8 if forest else 10) or (absi(x - door.x) < 2 and not forest):
			continue
		var y := ground_y(x, z)
		var top := get_b(x, y - 1, z)
		if kind == "desert":
			if top == _id("sand") and r.next() < 0.5:
				var h := 2 + int(r.next() * 2)
				for k in h:
					_set_raw(x, y + k, z, _id("cactus"))
		elif (top == _id("grass") or top == _id("snow")) and r.next() < (0.8 if forest else 0.45):
			_tree(x, y, z, r, kind == "snow")


## Two ridges with a road along the valley between them, snow on the tops.
func _gen_mountain(r: U.Rng, seed_v: int) -> void:
	var cz := WZ >> 1
	var stone := _id("stone")
	for x in WX:
		var mid := cz + int(round(sin(x * 0.08) * 3.0))
		for z in WZ:
			var off := absi(z - mid)
			var h := 5 + clampi(int((off - 4) * 0.8), 0, 13) + (roundi(_fbm(x, z, seed_v) * 3.0) if off > 6 else 0)
			h = mini(h, WY - 3)
			for y in range(0, h + 1):
				var id := stone
				if y == h:
					id = _id("snow") if h >= 14 else (_id("path") if off <= 1 else (_id("grass") if h < 11 else stone))
				elif y > h - 2 and h < 11:
					id = _id("dirt")
				_set_raw(x, y, z, id)
	# Pines on the lower slopes.
	for i in 120:
		var x := 2 + int(r.next() * (WX - 4))
		var z := 2 + int(r.next() * (WZ - 4))
		var mid := cz + int(round(sin(x * 0.08) * 3.0))
		if absi(z - mid) < 4:
			continue
		var y := ground_y(x, z)
		if get_b(x, y - 1, z) == _id("grass") and y < WY - 7 and r.next() < 0.6:
			_tree(x, y, z, r, y > 11)


## A night city: cobbled streets in a grid, tall buildings with lit windows,
## street lamps, and an open square in the middle.
func _gen_city(r: U.Rng) -> void:
	var cx := WX >> 1
	var cz := WZ >> 1
	_fill_raw(0, 0, 0, WX - 1, 3, WZ - 1, _id("stone"))
	_fill_raw(0, 4, 0, WX - 1, 4, WZ - 1, _id("cobble"))
	_fill_raw(cx - 7, 4, cz - 7, cx + 6, 4, cz + 6, _id("planks"))
	_fill_raw(cx - 1, 5, cz - 1, cx, 5, cz, _id("water"))
	for q in [[cx - 2, cz - 2], [cx + 1, cz - 2], [cx - 2, cz + 1], [cx + 1, cz + 1]]:
		_set_raw(q[0], 5, q[1], _id("brick"))
	var mats := [_id("brick"), _id("sandstone"), _id("stone"), _id("planks"), _id("basalt")]
	# Blocks of buildings 9 wide with 5-wide streets between them.
	for bx in range(2, WX - 9, 14):
		for bz in range(2, WZ - 9, 14):
			if absi(bx + 4 - cx) < 11 and absi(bz + 4 - cz) < 11:
				continue
			var w := 8 + int(r.next() * 2)
			var d := 8 + int(r.next() * 2)
			var h := 6 + int(r.next() * 12)
			h = mini(h, WY - 7)
			var m: int = mats[int(r.next() * mats.size())]
			for y in range(5, 5 + h):
				for xx in range(bx, bx + w):
					for zz in range(bz, bz + d):
						var edge := xx == bx or xx == bx + w - 1 or zz == bz or zz == bz + d - 1
						if not edge:
							continue
						var win := y % 3 == 1 and (xx + zz) % 3 == 1 and y > 5
						_set_raw(xx, y, zz, (_id("lamp") if r.next() < 0.35 else _id("glass")) if win else m)
			_fill_raw(bx, 5 + h, bz, bx + w - 1, 5 + h, bz + d - 1, _id("stone"))
			# A door on the street side.
			_set_raw(bx + w / 2, 5, bz, 0)
			_set_raw(bx + w / 2, 6, bz, 0)
	for x in range(4, WX - 3, 7):
		for z in range(4, WZ - 3, 7):
			if (x - 2) % 14 >= 10 or (z - 2) % 14 >= 10:
				if get_b(x, 5, z) == 0 and Vector2(x - cx, z - cz).length() > 3:
					_fill_raw(x, 5, z, x, 7, z, _id("basalt"))
					_set_raw(x, 8, z, _id("lamp"))


## A big hall inside: plank floor, brick walls with windows, a roof, lamps
## hanging from the ceiling, bookshelves, tables (counters) and a hearth.
func _gen_indoor() -> void:
	var cx := WX >> 1
	var cz := WZ >> 1
	_fill_raw(0, 0, 0, WX - 1, 3, WZ - 1, _id("stone"))
	_fill_raw(0, 4, 0, WX - 1, 4, WZ - 1, _id("grass"))
	var x0 := cx - 15
	var x1 := cx + 14
	var z0 := cz - 11
	var z1 := cz + 10
	var top := 12
	_fill_raw(x0, 4, z0, x1, 4, z1, _id("planks"))
	for y in range(5, top):
		for x in range(x0, x1 + 1):
			for z in range(z0, z1 + 1):
				if x == x0 or x == x1 or z == z0 or z == z1:
					var win := y in [7, 8] and ((x - x0) % 5 == 2 or (z - z0) % 5 == 2) and not (x in [x0, x1] and z in [z0, z1])
					_set_raw(x, y, z, _id("glass") if win else _id("brick"))
	_fill_raw(x0, top, z0, x1, top, z1, _id("planks"))
	# Lamps hanging in rows under the roof.
	for x in range(x0 + 4, x1 - 2, 6):
		for z in range(z0 + 4, z1 - 2, 6):
			_set_raw(x, top - 1, z, _id("lamp"))
	# Bookshelves along the back wall, a hearth in the middle of it.
	for x in range(x0 + 1, x1):
		if absi(x - cx) > 2:
			_fill_raw(x, 5, z1 - 1, x, 7, z1 - 1, _id("bookshelf"))
	_fill_raw(cx - 2, 5, z1 - 1, cx + 2, 8, z1 - 1, _id("brick"))
	_set_raw(cx, 5, z1 - 1, 0)
	_set_raw(cx, 6, z1 - 1, 0)
	# Long tables down the hall.
	for z in range(z0 + 4, z1 - 4, 5):
		for x in [cx - 8, cx + 7]:
			_fill_raw(x - 3, 5, z, x + 3, 5, z, _id("planks"))
	# The door, facing south, and a path up to it.
	_fill_raw(cx - 1, 5, z0, cx, 7, z0, 0)
	for z in range(0, z0):
		_set_raw(cx, 4, z, _id("path"))
		_set_raw(cx - 1, 4, z, _id("path"))


## Builds a prefab with its origin at (bx, by, bz), rotated rot * 90 degrees.
func stamp_prefab(key: String, bx: int, by: int, bz: int, rot: int) -> void:
	var P := func(dx: int, dy: int, dz: int, id: int) -> void:
		var x := dx
		var z := dz
		for k in rot:
			var t := x
			x = -z
			z = t
		set_b(bx + x, by + dy, bz + z, id)
	var F := func(x0: int, y0: int, z0: int, x1: int, y1: int, z1: int, id: int) -> void:
		for y in range(y0, y1 + 1):
			for z in range(z0, z1 + 1):
				for x in range(x0, x1 + 1):
					P.call(x, y, z, id)
	var planks := _id("planks")
	var log_id := _id("log")
	var glass := _id("glass")
	var lamp := _id("lamp")
	var cobble := _id("cobble")
	var water := _id("water")
	var brick := _id("brick")
	match key:
		"cottage":
			F.call(-4, 0, -3, 4, 7, 4, 0)
			F.call(-3, -1, -2, 3, -1, 3, planks)
			for y in range(0, 3):
				for x in range(-3, 4):
					for z in range(-2, 4):
						var ex := absi(x) == 3
						var ez := z == -2 or z == 3
						if not ex and not ez:
							continue
						P.call(x, y, z, log_id if ex and ez else planks)
			P.call(0, 0, -2, 0)
			P.call(0, 1, -2, 0)
			for q in [[-3, 1, 0], [3, 1, 0], [-1, 1, 3], [1, 1, 3], [-2, 1, -2], [2, 1, -2]]:
				P.call(q[0], q[1], q[2], glass)
			for k in 3:
				F.call(-4 + k, 3 + k, -3 + k, 4 - k, 3 + k, 4 - k, brick)
			P.call(-2, 0, 2, lamp)
		"tower":
			F.call(-2, 0, -2, 2, 9, 2, cobble)
			F.call(-1, 0, -1, 1, 8, 1, 0)
			P.call(0, 0, -2, 0)
			P.call(0, 1, -2, 0)
			for y in [4, 7]:
				P.call(0, y, -2, glass)
				P.call(0, y, 2, glass)
				P.call(-2, y, 0, glass)
				P.call(2, y, 0, glass)
			F.call(-1, 9, -1, 1, 9, 1, planks)
			for q in [[-2, -2], [2, -2], [-2, 2], [2, 2], [0, -2], [0, 2], [-2, 0], [2, 0]]:
				P.call(q[0], 10, q[1], cobble)
			P.call(0, 10, 0, lamp)
		"tree":
			for y in 5:
				P.call(0, y, 0, log_id)
			for dy in range(3, 7):
				var rad := 1 if dy >= 5 else 2
				for x in range(-rad, rad + 1):
					for z in range(-rad, rad + 1):
						if absi(x) == rad and absi(z) == rad and dy != 4:
							continue
						if not (x == 0 and z == 0 and dy < 5):
							P.call(x, dy, z, _id("leaves"))
		"well":
			F.call(-1, 0, -1, 1, 0, 1, cobble)
			P.call(0, 0, 0, water)
			P.call(0, -1, 0, water)
			P.call(-1, 1, 0, log_id)
			P.call(-1, 2, 0, log_id)
			P.call(1, 1, 0, log_id)
			P.call(1, 2, 0, log_id)
			F.call(-1, 3, -1, 1, 3, 1, planks)
		"stall":
			for q in [[-2, -1], [2, -1], [-2, 1], [2, 1]]:
				for y in 3:
					P.call(q[0], y, q[1], log_id)
			F.call(-1, 0, -1, 1, 0, -1, planks)
			for x in range(-2, 3):
				for z in range(-1, 2):
					P.call(x, 3, z, _id("white") if (x + 2) % 2 else _id("red"))
		"fountain":
			F.call(-2, 0, -2, 2, 0, 2, brick)
			F.call(-1, 0, -1, 1, 0, 1, water)
			P.call(0, 0, 0, brick)
			P.call(0, 1, 0, brick)
			P.call(0, 2, 0, water)
		"lamp":
			for y in 3:
				P.call(0, y, 0, _id("basalt"))
			P.call(0, 3, 0, lamp)


# ================================================================ queries

## Voxel ray march (Amanatides-Woo), like the web `voxelRay`.
## Returns {} on a miss, else {x, y, z, nx, ny, nz, dist, floor, v, point}.
func ray(o: Vector3, d: Vector3, max_d: float) -> Dictionary:
	var x := int(floor(o.x))
	var y := int(floor(o.y))
	var z := int(floor(o.z))
	var sx := int(signf(d.x))
	var sy := int(signf(d.y))
	var sz := int(signf(d.z))
	var tdx := absf(1.0 / d.x) if sx != 0 else INF
	var tdy := absf(1.0 / d.y) if sy != 0 else INF
	var tdz := absf(1.0 / d.z) if sz != 0 else INF
	var tmx := (x + 1 - o.x) * tdx if sx > 0 else ((o.x - x) * tdx if sx < 0 else INF)
	var tmy := (y + 1 - o.y) * tdy if sy > 0 else ((o.y - y) * tdy if sy < 0 else INF)
	var tmz := (z + 1 - o.z) * tdz if sz > 0 else ((o.z - z) * tdz if sz < 0 else INF)
	var t := 0.0
	var nx := 0
	var ny := 0
	var nz := 0
	for i in 400:
		if tmx < tmy and tmx < tmz:
			x += sx
			t = tmx
			tmx += tdx
			nx = -sx
			ny = 0
			nz = 0
		elif tmy < tmz:
			y += sy
			t = tmy
			tmy += tdy
			nx = 0
			ny = -sy
			nz = 0
		else:
			z += sz
			t = tmz
			tmz += tdz
			nx = 0
			ny = 0
			nz = -sz
		if t > max_d:
			return {}
		if y < 0:
			return {"x": x, "y": y, "z": z, "nx": nx, "ny": ny, "nz": nz, "dist": t, "floor": true, "v": 0, "point": o + d * t}
		var v := get_b(x, y, z)
		if v != 0:
			var b := Blocks.get_block(v)
			if not b.is_empty() and not b.get("deleted", false) and b.get("kind", "") != "water":
				return {"x": x, "y": y, "z": z, "nx": nx, "ny": ny, "nz": nz, "dist": t, "floor": false, "v": v, "point": o + d * t}
	return {}


func pick(origin: Vector3, dir: Vector3, max_d: float = 60.0) -> Dictionary:
	return ray(origin, dir, max_d)


func clip_cam(from: Vector3, dir: Vector3, dist: float) -> float:
	var hit := ray(from, dir, dist)
	return maxf(0.5, hit["dist"] - 0.25) if not hit.is_empty() else dist


# ================================================================ save / load

## Offset applied to old 48-wide saves when loading (actors shift with it).
var load_offset := 0.0


func serialize() -> Dictionary:
	return {"v3": true, "size": WX, "rle": U.rle_encode(data), "custom": Blocks.custom_sources()}


func load_data(d: Dictionary) -> void:
	_flow.clear()
	Blocks.reset_custom()
	for src in d.get("custom", []):
		if src is Dictionary and not src.get("deleted", false):
			if Blocks.add_custom(src) < 0:
				Blocks.push_deleted()
		else:
			Blocks.push_deleted()
	var n := int(d.get("size", Styles.LEGACY_SIZE))
	var arr := U.rle_decode(str(d.get("rle", "")), n * WY * n)
	if not d.get("v3", false):
		for i in arr.size():
			if arr[i] >= 27:
				arr[i] = mini(255, arr[i] - 27 + Blocks.BUILTIN_COUNT)
	load_offset = 0.0
	if n == WX:
		data = arr
	else:
		# Older, smaller world: centre it and extend its edge columns outward.
		var off := (WX - n) / 2
		load_offset = off
		data = PackedByteArray()
		data.resize(WX * WY * WZ)
		for z in WZ:
			var sz := clampi(z - off, 0, n - 1)
			for x in WX:
				var sx := clampi(x - off, 0, n - 1)
				var edge := sx != x - off or sz != z - off
				for y in WY:
					var v := arr[(y * n + sz) * n + sx]
					if edge and v != 0 and Blocks.get_block(v).get("kind", "solid") != "solid":
						v = 0
					data[(y * WZ + z) * WX + x] = v
	rebuild()


# ================================================================ meshing

func rebuild() -> void:
	_mark_all()
	_flush()


func _mark_all() -> void:
	for cz in CZ:
		for cx in CX:
			_dirty[Vector2i(cx, cz)] = true


func _flush() -> void:
	if _mats.is_empty():
		_build_materials()
	var keys := _dirty.keys()
	_dirty.clear()
	for k: Vector2i in keys:
		_mesh_chunk(k)
	_update_lights()


func _build_materials() -> void:
	var tex := Blocks.atlas()
	var opaque := StandardMaterial3D.new()
	opaque.albedo_texture = tex
	opaque.vertex_color_use_as_albedo = true
	opaque.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	opaque.roughness = 0.92
	opaque.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	var trans := StandardMaterial3D.new()
	trans.albedo_texture = tex
	trans.vertex_color_use_as_albedo = true
	trans.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	trans.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trans.cull_mode = BaseMaterial3D.CULL_DISABLED
	trans.roughness = 0.08
	trans.metallic_specular = 0.7
	var water := ShaderMaterial.new()
	water.shader = preload("res://src/shaders/voxel_water.gdshader")
	var glow := StandardMaterial3D.new()
	glow.albedo_texture = tex
	glow.vertex_color_use_as_albedo = true
	glow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	glow.emission_enabled = true
	glow.emission_texture = tex
	glow.emission = Color.WHITE
	glow.emission_energy_multiplier = 1.6
	glow.roughness = 0.8
	_mats = [opaque, trans, water, glow]


func _build_floor() -> void:
	# Bedrock-like slab under the world (the grid treats y < 0 as solid).
	_floor = MeshInstance3D.new()
	_floor.name = "Floor"
	var m := BoxMesh.new()
	m.size = Vector3(WX + 64, 1, WZ + 64)
	_floor.mesh = m
	_floor.position = Vector3(WX / 2.0, -0.5, WZ / 2.0)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#55595f")
	fm.roughness = 1.0
	_floor.material_override = fm
	add_child(_floor)


func _mesh_chunk(k: Vector2i) -> void:
	var groups := []
	for g in 4:
		groups.append({"p": [], "n": [], "u": [], "c": [], "i": []})
	var s := 1.0 / Blocks.ATLAS_N
	var e := 0.0006
	var water_id: int = Blocks.ID.get("water", -1)
	var x0 := k.x * CH
	var z0 := k.y * CH
	var blocks := Blocks.BLOCKS
	var nb_count := blocks.size()
	for y in WY:
		for z in range(z0, z0 + CH):
			for x in range(x0, x0 + CH):
				var v := data[(y * WZ + z) * WX + x]
				if v == 0 or v >= nb_count:
					continue
				var b = blocks[v]
				if b == null or b["deleted"]:
					continue
				var kind: String = b["kind"]
				var see: bool = b["see"]
				var gi := G_GLOW if kind == "glow" else (G_WATER if kind == "water" else (G_TRANS if see else G_OPAQUE))
				var g: Dictionary = groups[gi]
				for f in FACES:
					var n: Vector3i = f["n"]
					var nx := x + n.x
					var ny := y + n.y
					var nz := z + n.z
					if ny < 0:
						continue
					var nv := get_b(nx, ny, nz)
					var nbe = null
					if nv != 0 and nv < nb_count and blocks[nv] != null and not blocks[nv]["deleted"]:
						nbe = blocks[nv]
					var vis: bool
					if see:
						vis = nv != v and (nbe == null or nbe["see"])
					else:
						vis = nbe == null or nbe["see"]
					if not vis:
						continue
					var t: int = b[f["t"]]
					var tx := (t % Blocks.ATLAS_N) * s
					var ty := (t / Blocks.ATLAS_N) * s
					var uvs := [Vector2(tx + e, ty + e), Vector2(tx + s - e, ty + e), Vector2(tx + e, ty + s - e), Vector2(tx + s - e, ty + s - e)]
					var base: int = (g["p"] as Array).size()
					var ao := [3, 3, 3, 3]
					var corners: Array = f["c"]
					var nf := Vector3(n)
					var surf_top := gi == G_WATER and get_b(x, y + 1, z) != water_id
					for kk in 4:
						var c: Vector3i = corners[kk]
						g["p"].append(Vector3(x + c.x, y + c.y, z + c.z))
						g["n"].append(nf)
						g["u"].append(uvs[kk])
						if gi == G_OPAQUE:
							var A: int = f["ax"][0]
							var B: int = f["ax"][1]
							var q := Vector3i(nx, ny, nz)
							var q1 := q
							var q2 := q
							q1[A] += 1 if c[A] else -1
							q2[B] += 1 if c[B] else -1
							var q3 := q1
							q3[B] = q2[B]
							var s1 := 1 if is_opaque(q1.x, q1.y, q1.z) else 0
							var s2 := 1 if is_opaque(q2.x, q2.y, q2.z) else 0
							var s3 := 1 if is_opaque(q3.x, q3.y, q3.z) else 0
							ao[kk] = 0 if (s1 and s2) else 3 - (s1 + s2 + s3)
						var sh: float = AO[ao[kk]]
						var alpha := 1.0 if (surf_top and c.y == 1) else 0.0
						if gi != G_WATER:
							alpha = 1.0
						g["c"].append(Color(sh, sh, sh, alpha))
					var idx_arr: Array = g["i"]
					if ao[0] + ao[3] > ao[1] + ao[2]:
						idx_arr.append_array([base, base + 3, base + 2, base, base + 1, base + 3])
					else:
						idx_arr.append_array([base, base + 1, base + 2, base + 2, base + 1, base + 3])
	var insts: Array = _chunks.get(k, [])
	if insts.is_empty():
		for gi in 4:
			var mi := MeshInstance3D.new()
			mi.name = "Chunk_%d_%d_%d" % [k.x, k.y, gi]
			mi.material_override = _mats[gi]
			if gi == G_TRANS or gi == G_WATER:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			insts.append(mi)
		_chunks[k] = insts
	for gi in 4:
		var g: Dictionary = groups[gi]
		var mi: MeshInstance3D = insts[gi]
		if (g["p"] as Array).is_empty():
			mi.mesh = null
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(g["p"])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array(g["n"])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array(g["u"])
		arrays[Mesh.ARRAY_COLOR] = PackedColorArray(g["c"])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(g["i"])
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mi.mesh = am


# ================================================================ lights & animation

func _update_lights() -> void:
	if _lights_node == null:
		return
	var center := Vector3(WX / 2.0, 6.0, WZ / 2.0)
	var cands := []
	for y in WY:
		for z in WZ:
			for x in WX:
				var v := data[(y * WZ + z) * WX + x]
				if v == 0:
					continue
				var b := Blocks.get_block(v)
				if b.is_empty() or b["deleted"] or b["kind"] != "glow":
					continue
				# Skip glow blocks buried on every side.
				if is_opaque(x + 1, y, z) and is_opaque(x - 1, y, z) and is_opaque(x, y + 1, z) and is_opaque(x, y, z + 1) and is_opaque(x, y, z - 1):
					continue
				var p := Vector3(x + 0.5, y + 0.5, z + 0.5)
				cands.append([p.distance_squared_to(center), p, v])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	var chosen := []
	for c in cands:
		if chosen.size() >= MAX_LIGHTS:
			break
		var ok := true
		for o in chosen:
			if (o[1] as Vector3).distance_to(c[1]) < 3.0:
				ok = false
				break
		if ok:
			chosen.append(c)
	while _lights.size() < chosen.size():
		var l := OmniLight3D.new()
		l.omni_range = 7.0
		l.omni_attenuation = 1.4
		l.shadow_enabled = false
		l.light_specular = 0.3
		_lights_node.add_child(l)
		_lights.append(l)
		_light_base.append(1.0)
	for i in _lights.size():
		var l := _lights[i]
		if i < chosen.size():
			var col := Blocks.avg_color(chosen[i][2])
			col = col.lerp(Color(1.0, 0.85, 0.6), 0.35)
			col.a = 1.0
			l.light_color = col.lightened(0.15)
			l.position = chosen[i][1]
			l.visible = true
			_light_base[i] = 1.6
			l.light_energy = 1.6
		else:
			l.visible = false


## Per-frame ambience: light flicker (water waves run in the shader).
func animate(_dt: float, t: float) -> void:
	for i in _lights.size():
		var l := _lights[i]
		if l.visible:
			l.light_energy = _light_base[i] * (1.0 + 0.06 * sin(t * 7.0 + i * 1.7) + 0.03 * sin(t * 13.0 + i))
