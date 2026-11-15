class_name TerrainWater
extends MeshInstance3D
## Water you pour on the anime and low-poly ground (Ground → Water): a depth
## on every point of the terrain grid that runs downhill to its neighbours
## until it lies flat in a hollow, joining the world's lake if it reaches it.
## Drawn as one mesh at the water's surface (the ground hides what's below),
## with the lake's material. Characters swim in it where it's deep enough.
## Saved with the world ("pools": [[grid index, depth in cm], ...]).

## How deep (m) water must be to show, and to swim in.
const SHOW := 0.03
const SWIM := 0.6
## Brush: depth poured per second at the centre, and dried.
const POUR := 1.2
## Simulation: "virtual pipes" (O'Brien & Hodgins; see lisyarus.github.io,
## "Simulating water over terrain"). Each pair of neighbouring grid points is
## joined by a pipe whose flow speeds up with the difference in water
## surface and keeps going (slowed by friction), so water runs down a slope,
## carries on, sloshes and settles, instead of just levelling out.
## Steps per second (each DT long) while it's moving.
const STEPS := 40
const DT := 1.0 / STEPS
const G := 9.8
## Share of each pipe's flow lost per second (friction).
const FRICTION := 0.92
## Surface tension: over dry ground a pipe only starts flowing once the
## water stands this much higher (m), so on level ground it stops as a
## puddle instead of running out into a film.
const HOLD := 0.07

var world: TerrainWorld
var depth := PackedFloat32Array()
## Pipe flows (m³/s): fx between (i, j) and (i + 1, j) at j * (n - 1) + i,
## fz between (i, j) and (i, j + 1) at j * n + i. Positive = towards +x / +z.
var fx := PackedFloat32Array()
var fz := PackedFloat32Array()
var _n := 0
var _active := false
var _calm := 0
var _lo := Vector2i.ZERO
var _hi := Vector2i.ZERO
var _acc := 0.0
var _mesh_t := 0.0
var _dirty := false


func setup(w: TerrainWorld) -> void:
	world = w
	name = "Pools"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_n = TerrainWorld.TN + 1
	depth.resize(_n * _n)
	depth.fill(0.0)
	fx.resize((_n - 1) * _n)
	fz.resize(_n * (_n - 1))
	fx.fill(0.0)
	fz.fill(0.0)


func clear() -> void:
	depth.fill(0.0)
	fx.fill(0.0)
	fz.fill(0.0)
	_active = false
	mesh = null


func flowing() -> bool:
	return _active


func any() -> bool:
	for v in depth:
		if v > SHOW:
			return true
	return false


# ---------------------------------------------------------------- queries

## Water depth at a spot (interpolated over the grid).
func depth_at(x: float, z: float) -> float:
	var tn := TerrainWorld.TN
	x = clampf(x, 0.0, tn - 1e-4)
	z = clampf(z, 0.0, tn - 1e-4)
	var i := int(floor(x))
	var j := int(floor(z))
	var fx := x - i
	var fz := z - j
	var a := depth[j * _n + i]
	var b := depth[j * _n + i + 1]
	var c := depth[(j + 1) * _n + i]
	var d := depth[(j + 1) * _n + i + 1]
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


## The water surface over a spot, or -INF where it's dry.
func surface_at(x: float, z: float) -> float:
	var d := depth_at(x, z)
	return world.terrain_h(x, z) + d if d > SHOW else -INF


# ---------------------------------------------------------------- brush

## Pours (mode "water") or dries ("dry") round (x, z), like the ground brush.
func brush(x: float, z: float, mode: String, dt: float, r: float) -> void:
	var tn := TerrainWorld.TN
	for j in range(maxi(1, int(floor(z - r))), mini(tn - 1, int(ceil(z + r))) + 1):
		for i in range(maxi(1, int(floor(x - r))), mini(tn - 1, int(ceil(x + r))) + 1):
			var d := Vector2(i - x, j - z).length()
			if d > r:
				continue
			var w := pow(1.0 - d / r, 2.0)
			var k := j * _n + i
			if mode == "water":
				depth[k] += w * dt * POUR
			else:
				depth[k] = maxf(0.0, depth[k] - w * dt * POUR * 2.0)
	_wake(Vector2i(int(x - r) - 1, int(z - r) - 1), Vector2i(int(x + r) + 2, int(z + r) + 2))


func _wake(lo: Vector2i, hi: Vector2i) -> void:
	var tn := TerrainWorld.TN
	lo = lo.clamp(Vector2i.ZERO, Vector2i(tn, tn))
	hi = hi.clamp(Vector2i.ZERO, Vector2i(tn, tn))
	if _active:
		_lo = _lo.min(lo)
		_hi = _hi.max(hi)
	else:
		_lo = lo
		_hi = hi
	_active = true
	_calm = 0
	_dirty = true


# ---------------------------------------------------------------- flow

func _process(dt: float) -> void:
	if not _active:
		if _dirty:
			rebuild()
		return
	_acc += dt
	var n := 0
	while _acc >= DT and n < 6 and _active:
		_acc -= DT
		step()
		n += 1
	# The mesh follows at most 15 times a second (the flow itself runs at 40).
	_mesh_t += dt
	if _mesh_t >= 1.0 / 15.0 or not _active:
		_mesh_t = 0.0
		rebuild()


## Runs the flow until it settles (tests, loading).
func settle() -> void:
	var guard := 0
	while _active and guard < 3000:
		step()
		guard += 1
	rebuild()


## One step of the pipes: speed each pipe up by the difference in water
## surface (friction slows it), scale a point's outflows down if they'd take
## more water than it has, then move the water. Water that reaches the lake,
## or the edge of the world, goes into it. Only the area round the water is
## worked on.
func step() -> void:
	var tn := TerrainWorld.TN
	var n := _n
	var h := world.h
	var lake := world.water
	var x0 := maxi(0, _lo.x)
	var z0 := maxi(0, _lo.y)
	var x1 := mini(tn, _hi.x)
	var z1 := mini(tn, _hi.y)
	var keep := pow(1.0 - FRICTION, DT)
	var acc := G * DT
	var fmax := 0.0
	# 1. Pipes speed up towards the lower surface.
	for j in range(z0, z1 + 1):
		for i in range(x0, x1 + 1):
			var k := j * n + i
			var s := h[k] + depth[k]
			if i < x1:
				var k2 := k + 1
				var d := s - (h[k2] + depth[k2])
				var e := j * (n - 1) + i
				fx[e] = _pipe(fx[e] * keep * _drag(depth[k], depth[k2]), d, acc, depth[k], depth[k2])
				fmax = maxf(fmax, absf(fx[e]))
			if j < z1:
				var k2 := k + n
				var d := s - (h[k2] + depth[k2])
				var e := j * n + i
				fz[e] = _pipe(fz[e] * keep * _drag(depth[k], depth[k2]), d, acc, depth[k], depth[k2])
				fmax = maxf(fmax, absf(fz[e]))
	# 2. Nobody gives away more water than they have.
	for j in range(z0, z1 + 1):
		for i in range(x0, x1 + 1):
			var k := j * n + i
			var out := 0.0
			var ex_r := j * (n - 1) + i
			var ex_l := ex_r - 1
			var ez_u := j * n + i
			var ez_d := ez_u - n
			if i < tn and fx[ex_r] > 0.0:
				out += fx[ex_r]
			if i > 0 and fx[ex_l] < 0.0:
				out -= fx[ex_l]
			if j < tn and fz[ez_u] > 0.0:
				out += fz[ez_u]
			if j > 0 and fz[ez_d] < 0.0:
				out -= fz[ez_d]
			if out <= 0.0:
				continue
			var limit := depth[k] / DT
			if out > limit:
				var sc := limit / out
				if i < tn and fx[ex_r] > 0.0:
					fx[ex_r] *= sc
				if i > 0 and fx[ex_l] < 0.0:
					fx[ex_l] *= sc
				if j < tn and fz[ez_u] > 0.0:
					fz[ez_u] *= sc
				if j > 0 and fz[ez_d] < 0.0:
					fz[ez_d] *= sc
	# 3. Move the water; find where it is now.
	var moved := 0.0
	var lo := Vector2i(tn, tn)
	var hi := Vector2i(0, 0)
	for j in range(z0, z1 + 1):
		for i in range(x0, x1 + 1):
			var k := j * n + i
			var net := 0.0
			if i < tn:
				net -= fx[j * (n - 1) + i]
			if i > 0:
				net += fx[j * (n - 1) + i - 1]
			if j < tn:
				net -= fz[j * n + i]
			if j > 0:
				net += fz[(j - 1) * n + i]
			var dd := net * DT
			if dd != 0.0:
				depth[k] = maxf(0.0, depth[k] + dd)
				moved = maxf(moved, absf(dd))
			if depth[k] > 0.0005:
				# Reached the lake (or the world's edge): it joins it.
				if h[k] + depth[k] <= lake + 0.02 or i == 0 or j == 0 or i == tn or j == tn:
					depth[k] = 0.0
					continue
				lo = lo.min(Vector2i(i, j))
				hi = hi.max(Vector2i(i, j))
	if hi.x < lo.x:
		_settle_down()
		return
	_lo = lo - Vector2i.ONE * 2
	_hi = hi + Vector2i.ONE * 2
	_dirty = true
	# Still once no pipe moves more than a fraction of a millimetre a step.
	_calm = _calm + 1 if moved < 0.0005 else 0
	if _calm > 20:
		_settle_down()


## Shallow water drags on the ground: thin films hardly keep their speed.
static func _drag(wa: float, wb: float) -> float:
	return clampf((wa + wb) / 0.4, 0.35, 1.0)


## A pipe's new flow: faster towards the lower side, but water doesn't start
## creeping over dry ground for less than HOLD.
static func _pipe(f: float, d: float, acc: float, wa: float, wb: float) -> float:
	if d > 0.0 and wb < SHOW:
		d = maxf(0.0, d - HOLD)
	elif d < 0.0 and wa < SHOW:
		d = minf(0.0, d + HOLD)
	# Nothing flows out of a point with (next to) no water in it.
	if (d >= 0.0 and wa <= 0.001) or (d <= 0.0 and wb <= 0.001):
		return 0.0
	# Level to within a few millimetres: it's still (the flow dies away
	# instead of sloshing on forever as a thin film spreading out).
	if absf(d) < 0.005:
		return f * 0.6
	return f + d * acc


## Still: stop, clear the pipes, and let films too thin to show dry off.
func _settle_down() -> void:
	_active = false
	_dirty = true
	fx.fill(0.0)
	fz.fill(0.0)
	for k in depth.size():
		if depth[k] < SHOW * 0.5:
			depth[k] = 0.0


# ---------------------------------------------------------------- mesh

## The water's surface as one mesh over the wet cells. Wet points sit at
## their surface; dry points next to them take the highest wet neighbour's
## level, so the surface runs on into the bank and the ground cuts a natural
## shoreline. Vertex colour: alpha fades with depth (the shader fades the
## edge by it, so no grid-shaped steps), red/green carry the flow direction
## (the shader slides the ripples along it). Built from packed arrays over
## the wet area only (a SurfaceTool pass over the whole grid took ~40 ms).
func rebuild() -> void:
	_dirty = false
	var tn := TerrainWorld.TN
	var n := _n
	var h := world.h
	var lo := Vector2i(n, n)
	var hi := Vector2i(-1, -1)
	for k in depth.size():
		if depth[k] > SHOW:
			var i := k % n
			var j := k / n
			lo = lo.min(Vector2i(i, j))
			hi = hi.max(Vector2i(i, j))
	if hi.x < 0:
		mesh = null
		return
	lo = (lo - Vector2i.ONE).max(Vector2i.ZERO)
	hi = (hi + Vector2i.ONE).min(Vector2i(tn, tn))
	var w := hi.x - lo.x + 1
	var ht := hi.y - lo.y + 1
	# Surface per point in the area (wet: its own; dry beside wet: the
	# highest wet neighbour's; else its ground), alpha and flow.
	var ys := PackedFloat32Array()
	ys.resize(w * ht)
	var cols := PackedColorArray()
	cols.resize(w * ht)
	for j in range(lo.y, hi.y + 1):
		for i in range(lo.x, hi.x + 1):
			var k := j * n + i
			var a := (j - lo.y) * w + (i - lo.x)
			var d := depth[k]
			if d > SHOW:
				ys[a] = h[k] + d
				var vx := 0.0
				var vz := 0.0
				if i < tn:
					vx += fx[j * (n - 1) + i]
				if i > 0:
					vx += fx[j * (n - 1) + i - 1]
				if j < tn:
					vz += fz[j * n + i]
				if j > 0:
					vz += fz[(j - 1) * n + i]
				var sp := 0.5 / maxf(d, 0.15)
				cols[a] = Color(clampf(0.5 + vx * sp * 0.25, 0.0, 1.0), clampf(0.5 + vz * sp * 0.25, 0.0, 1.0), 0.0, clampf(d / 0.15, 0.0, 1.0))
			else:
				var best := -INF
				for nj in range(maxi(0, j - 1), mini(tn, j + 1) + 1):
					for ni in range(maxi(0, i - 1), mini(tn, i + 1) + 1):
						var nk := nj * n + ni
						if depth[nk] > SHOW:
							best = maxf(best, h[nk] + depth[nk])
				ys[a] = best if best > -INF else h[k]
				cols[a] = Color(0.5, 0.5, 0.0, 0.0)
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var idx := PackedInt32Array()
	var map := PackedInt32Array()
	map.resize(w * ht)
	map.fill(-1)
	for j in range(lo.y, hi.y):
		for i in range(lo.x, hi.x):
			var k := j * n + i
			if depth[k] <= SHOW and depth[k + 1] <= SHOW and depth[k + n] <= SHOW and depth[k + n + 1] <= SHOW:
				continue
			var corners := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i, j + 1), Vector2i(i + 1, j + 1)]
			var vi := PackedInt32Array([0, 0, 0, 0])
			for c in 4:
				var p: Vector2i = corners[c]
				var a := (p.y - lo.y) * w + (p.x - lo.x)
				if map[a] < 0:
					map[a] = verts.size()
					verts.append(Vector3(p.x, ys[a], p.y))
					colors.append(cols[a])
				vi[c] = map[a]
			idx.append_array(PackedInt32Array([vi[0], vi[1], vi[3], vi[0], vi[3], vi[2]]))
	if idx.is_empty():
		mesh = null
		return
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = am


# ---------------------------------------------------------------- saving

func serialize() -> Array:
	var out := []
	for k in depth.size():
		if depth[k] > SHOW * 0.5:
			out.append([k, int(round(depth[k] * 100.0))])
	return out


func load_data(arr: Variant) -> void:
	clear()
	if arr is Array:
		for e in arr:
			if e is Array and e.size() >= 2 and int(e[0]) >= 0 and int(e[0]) < depth.size():
				depth[int(e[0])] = float(e[1]) / 100.0
	rebuild()
