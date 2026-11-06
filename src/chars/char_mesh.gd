class_name CharMesh
## Character-specific geometry (capsules, lathes, partial spheres, tori, the
## anime head, capes and pixel-skin boxes). Triangles are auto-oriented so
## front faces are clockwise (Godot) with normals pointing outward.

const TOON_DOUBLE := preload("res://src/chars/toon_double.gdshader")

const HINT_ORIGIN := 0
const HINT_TORUS := 1
const HINT_CONST := 2

static var _cache := {}
static var _side_mats := {}


static func capsule(r: float, ln: float, seg := 12) -> Mesh:
	var key := "cap%.4f,%.4f,%d" % [r, ln, seg]
	if not _cache.has(key):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = ln + 2.0 * r
		m.radial_segments = maxi(6, seg + 4)
		m.rings = 8
		_cache[key] = m
	return _cache[key]


## Three's SphereGeometry(r, wseg, hseg, 0, 2PI, 0, theta_len).
static func sphere_part(r: float, wseg: int, hseg: int, theta_len: float) -> Mesh:
	var key := "sp%.4f,%d,%d,%.4f" % [r, wseg, hseg, theta_len]
	if _cache.has(key):
		return _cache[key]
	var rows := []
	for j in hseg + 1:
		var th := theta_len * float(j) / hseg
		var row := PackedVector3Array()
		for i in wseg:
			var ph := TAU * float(i) / wseg
			row.append(Vector3(-r * cos(ph) * sin(th), r * cos(th), r * sin(ph) * sin(th)))
		rows.append(row)
	var m := grid(rows, true, HINT_ORIGIN, Vector3.ZERO, true)
	_cache[key] = m
	return m


## The anime head: a sphere with a tapered chin and slightly flattened sides.
static func anime_head(r: float) -> Mesh:
	var key := "ahead%.4f" % r
	if _cache.has(key):
		return _cache[key]
	var rows := []
	var ws := 34
	var hs := 26
	for j in hs + 1:
		var th := PI * float(j) / hs
		var row := PackedVector3Array()
		for i in ws:
			var ph := TAU * float(i) / ws
			var x := -r * cos(ph) * sin(th)
			var y := r * cos(th)
			var z := r * sin(ph) * sin(th)
			if y < 0.0:
				var t := pow(-y / r, 1.7)
				x *= 1.0 - 0.3 * t
				z *= 1.0 - 0.16 * t
				y *= 1.12
			if z > 0.0:
				z *= 1.03
			x *= 0.96
			row.append(Vector3(x, y, z))
		rows.append(row)
	var m := grid(rows, true, HINT_ORIGIN, Vector3.ZERO, false)
	_cache[key] = m
	return m


## Three's LatheGeometry: pts = [[radius, y], ...] revolved around Y.
static func lathe(pts: Array, seg := 24) -> Mesh:
	var key := "la%s,%d" % [str(pts), seg]
	if _cache.has(key):
		return _cache[key]
	var cy := 0.0
	for p in pts:
		cy += float(p[1])
	cy /= pts.size()
	var rows := []
	for p in pts:
		var row := PackedVector3Array()
		for i in seg:
			var ph := TAU * float(i) / seg
			row.append(Vector3(float(p[0]) * sin(ph), float(p[1]), float(p[0]) * cos(ph)))
		rows.append(row)
	var m := grid(rows, true, HINT_ORIGIN, Vector3(0, cy, 0), false)
	_cache[key] = m
	return m


## Three's TorusGeometry (ring in the XY plane), with optional partial arc.
static func torus(r: float, tube: float, radial: int, tubular: int, arc := TAU) -> Mesh:
	var key := "to%.4f,%.4f,%d,%d,%.4f" % [r, tube, radial, tubular, arc]
	if _cache.has(key):
		return _cache[key]
	var full := absf(arc - TAU) < 0.001
	var rows := []
	var nu := tubular if full else tubular + 1
	for i in nu:
		var u := float(i) / tubular * arc
		var row := PackedVector3Array()
		for j in radial:
			var v := float(j) / radial * TAU
			row.append(Vector3((r + tube * cos(v)) * cos(u), (r + tube * cos(v)) * sin(u), tube * sin(v)))
		rows.append(row)
	if full:
		rows.append(rows[0])
	var m := grid(rows, true, HINT_TORUS, Vector3(r, 0, 0), false)
	_cache[key] = m
	return m


## The anime cape: a plane that widens and curls back towards the hem.
static func cape() -> Mesh:
	if _cache.has("cape"):
		return _cache["cape"]
	var rows := []
	for j in 9:
		var y0 := 0.45 - 0.9 * float(j) / 8.0
		var y := y0 - 0.45
		var row := PackedVector3Array()
		for i in 3:
			var x := -0.18 + 0.36 * float(i) / 2.0
			row.append(Vector3(x * (1.0 + (-y) * 0.35), y, -pow(-y, 2) * 0.12))
		rows.append(row)
	var m := grid(rows, false, HINT_CONST, Vector3(0, 0, -1), false)
	_cache["cape"] = m
	return m


## Builds a smooth mesh from rows of points. `wrap` joins the last column to
## the first. The hint gives a rough outward direction per point, used to
## orient normals and triangles: HINT_ORIGIN = p - param, HINT_TORUS = away
## from the ring of radius param.x in the XY plane, HINT_CONST = param.
## `hint_normals` uses the hint directly as the normal.
static func grid(rows: Array, wrap: bool, mode: int, param: Vector3, hint_normals: bool) -> ArrayMesh:
	var nr := rows.size()
	var first: PackedVector3Array = rows[0]
	var nc := first.size()
	var cols := nc if wrap else nc - 1
	var pos := PackedVector3Array()
	for row in rows:
		pos.append_array(row)
	var nrm := PackedVector3Array()
	nrm.resize(pos.size())
	var tris := []
	for j in nr - 1:
		for i in cols:
			var a := j * nc + i
			var b := (j + 1) * nc + i
			var c := (j + 1) * nc + (i + 1) % nc
			var d := j * nc + (i + 1) % nc
			tris.append([a, b, d])
			tris.append([b, c, d])
	var good := []
	for t in tris:
		var fn := (pos[t[1]] - pos[t[0]]).cross(pos[t[2]] - pos[t[0]])
		if fn.length_squared() < 1e-14:
			continue
		good.append(t)
		for k in 3:
			nrm[t[k]] += fn
	for i in pos.size():
		var h := _hint(pos[i], mode, param)
		var n := nrm[i]
		if hint_normals or n.length_squared() < 1e-14:
			n = h
		elif n.dot(h) < 0.0:
			n = -n
		nrm[i] = n.normalized() if n.length_squared() > 0.0 else Vector3.UP
	var idx := PackedInt32Array()
	for t in good:
		var fn := (pos[t[1]] - pos[t[0]]).cross(pos[t[2]] - pos[t[0]])
		var avg: Vector3 = nrm[t[0]] + nrm[t[1]] + nrm[t[2]]
		var i0: int = t[0]
		var i1: int = t[1]
		var i2: int = t[2]
		if fn.dot(avg) > 0.0:
			idx.append(i0)
			idx.append(i2)
			idx.append(i1)
		else:
			idx.append(i0)
			idx.append(i1)
			idx.append(i2)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m


static func _hint(p: Vector3, mode: int, param: Vector3) -> Vector3:
	if mode == HINT_TORUS:
		return p - Vector3(p.x, p.y, 0.0).normalized() * param.x
	if mode == HINT_CONST:
		return param
	return p - param


## Box whose six faces each map the full 0..1 texture (Three's BoxGeometry
## UVs), used by textured creature parts.
static func uv_box(w: float, h: float, d: float) -> Mesh:
	var key := "uvb%.4f,%.4f,%.4f" % [w, h, d]
	if _cache.has(key):
		return _cache[key]
	var full := [0.0, 0.0, 1.0, 1.0]
	var m := skin_box_mesh(w, h, d, [full, full, full, full, full, full], false)
	_cache[key] = m
	return m


## Box with per-face UV rects [u0, v0, u1, v1] in face order +X, -X, +Y, -Y,
## +Z, -Z, corners laid out exactly like Three's BoxGeometry so pixel skins
## land the same way. `mirror` flips U on every face.
static func skin_box_mesh(w: float, h: float, d: float, uv: Array, mirror: bool) -> ArrayMesh:
	var hx := w / 2.0
	var hy := h / 2.0
	var hz := d / 2.0
	var corners := [
		[Vector3(hx, hy, hz), Vector3(hx, hy, -hz), Vector3(hx, -hy, hz), Vector3(hx, -hy, -hz)],
		[Vector3(-hx, hy, -hz), Vector3(-hx, hy, hz), Vector3(-hx, -hy, -hz), Vector3(-hx, -hy, hz)],
		[Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz), Vector3(-hx, hy, hz), Vector3(hx, hy, hz)],
		[Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz)],
		[Vector3(-hx, hy, hz), Vector3(hx, hy, hz), Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz)],
		[Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz), Vector3(hx, -hy, -hz), Vector3(-hx, -hy, -hz)],
	]
	var normals := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in 6:
		var r: Array = uv[f]
		var u0: float = r[0]
		var u1: float = r[2]
		if mirror:
			var t := u0
			u0 = u1
			u1 = t
		var v0: float = r[1]
		var v1: float = r[3]
		var c: Array = corners[f]
		var uvs := [Vector2(u0, v0), Vector2(u1, v0), Vector2(u0, v1), Vector2(u1, v1)]
		# TL, TR, BL then BL, TR, BR: clockwise seen from outside.
		for k in [0, 1, 2, 2, 1, 3]:
			st.set_normal(normals[f])
			st.set_uv(uvs[k])
			st.add_vertex(c[k])
	return st.commit()


## Double-sided material: a cull-disabled toon shader in the anime style,
## otherwise Kit's material with side = true.
static func side_mat(color: String) -> Material:
	if Kit.shade != "toon":
		return Kit.mat(color, {"side": true})
	if not _side_mats.has(color):
		var m := ShaderMaterial.new()
		m.shader = TOON_DOUBLE
		m.set_shader_parameter("albedo", U.col(color))
		_side_mats[color] = m
	return _side_mats[color]
