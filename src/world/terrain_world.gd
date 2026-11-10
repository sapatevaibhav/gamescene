class_name TerrainWorld
extends Node3D
## Heightfield world for the anime and low-poly styles.
##
## A 48x48 cell heightmap ((TN+1)^2 vertices), a per-cell path mask, a water
## plane, procedural props, instanced grass and a horizon skirt. Ported from
## the web build and saved in the same JSON shape so web projects import.

signal changed

const TN := 80
const AR := 0.28
## Height a character can step onto without jumping.
const STEP := 0.45
const BRUSH_R := 2.6

var is_voxel := false
var style_key := "anime"
var h := PackedFloat32Array()
var path := PackedByteArray()
var water := 2.2
var props: Array = []
## Grass/flower count multiplier; lower it on weak devices, then rebuild_grass().
var grass_density := 1.0

var _terrain_mi: MeshInstance3D
var _water_mi: MeshInstance3D
var _skirt_mi: MeshInstance3D
var _props_root: Node3D
var _grass_mmi: MultiMeshInstance3D
var _flower_mmi: MultiMeshInstance3D
var _dirty := false
var _dirty_t := 0.0
var _t := 0.0
var _skirt_key := ""
var _backdrop: Node3D
var _skirt_hf: Callable
var _border_mmi: MultiMeshInstance3D
var _grass_root: Node3D
var _tall_card: Mesh
## Offset applied to old 48-wide saves when loading (actors shift with it).
var load_offset := 0.0
var _mat_key := ""

const SH_TOON := preload("res://src/shaders/terrain_toon.gdshader")
const SH_FLAT := preload("res://src/shaders/terrain_flat.gdshader")
const SH_WATER := preload("res://src/shaders/water.gdshader")
const SH_GRASS := preload("res://src/shaders/grass.gdshader")
const SH_GRASS_ANIME := preload("res://src/shaders/grass_anime.gdshader")
const SH_TERRAIN_ANIME := preload("res://src/shaders/terrain_anime.gdshader")


func _init() -> void:
	name = "TerrainWorld"
	h.resize((TN + 1) * (TN + 1))
	path.resize(TN * TN)
	_terrain_mi = MeshInstance3D.new()
	_terrain_mi.name = "Ground"
	add_child(_terrain_mi)
	_skirt_mi = MeshInstance3D.new()
	_skirt_mi.name = "Skirt"
	_skirt_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_skirt_mi)
	_water_mi = MeshInstance3D.new()
	_water_mi.name = "Water"
	_water_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := PlaneMesh.new()
	pm.size = Vector2(TN + 60, TN + 60)
	pm.subdivide_width = 54
	pm.subdivide_depth = 54
	_water_mi.mesh = pm
	var wm := ShaderMaterial.new()
	wm.shader = SH_WATER
	_water_mi.material_override = wm
	add_child(_water_mi)
	_props_root = Node3D.new()
	_props_root.name = "Props"
	add_child(_props_root)
	_grass_mmi = MultiMeshInstance3D.new()
	_grass_mmi.name = "Grass"
	_grass_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_grass_mmi)
	_flower_mmi = MultiMeshInstance3D.new()
	_flower_mmi.name = "Flowers"
	_flower_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flower_mmi)


func _process(dt: float) -> void:
	_dirty_t += dt
	if _dirty and _dirty_t > 0.05:
		_dirty_t = 0.0
		# Sculpting: only the chunks the brush touched are rebuilt.
		_rebuild_dirty()
		changed.emit()


# ---------------------------------------------------------------- style / palette

func set_style(key: String) -> void:
	style_key = key


func _sty() -> Dictionary:
	return Styles.get_style(style_key)


func _pal() -> Dictionary:
	return _sty().get("pal", Styles.STYLES["anime"]["pal"])


func _shade() -> String:
	return _sty().get("shade", "toon")


# ---------------------------------------------------------------- noise (exact JS ports)

static func hash2(x: float, z: float, s: float) -> float:
	var v := sin(x * 127.1 + z * 311.7 + s * 74.7) * 43758.5453
	return v - floor(v)


static func noise2(x: float, z: float, s: float) -> float:
	var ix := floorf(x)
	var iz := floorf(z)
	var fx := x - ix
	var fz := z - iz
	var sx := fx * fx * (3.0 - 2.0 * fx)
	var sz := fz * fz * (3.0 - 2.0 * fz)
	var a := hash2(ix, iz, s)
	var b := hash2(ix + 1, iz, s)
	var c := hash2(ix, iz + 1, s)
	var d := hash2(ix + 1, iz + 1, s)
	return lerpf(lerpf(a, b, sx), lerpf(c, d, sx), sz)


static func fbm(x: float, z: float, s: float) -> float:
	return noise2(x / 16, z / 16, s) * 0.6 + noise2(x / 8, z / 8, s + 9) * 0.3 + noise2(x / 4, z / 4, s + 17) * 0.1


# ---------------------------------------------------------------- heights

func _hi(i: int, j: int) -> int:
	return j * (TN + 1) + i


func hv(i: int, j: int) -> float:
	return h[_hi(clampi(i, 0, TN), clampi(j, 0, TN))]


func terrain_h(x: float, z: float) -> float:
	x = clampf(x, 0.0, TN - 1e-4)
	z = clampf(z, 0.0, TN - 1e-4)
	var i := int(floor(x))
	var j := int(floor(z))
	var fx := x - i
	var fz := z - j
	var a := hv(i, j)
	var b := hv(i + 1, j)
	var c := hv(i, j + 1)
	var d := hv(i + 1, j + 1)
	if fx + fz <= 1.0:
		return a + (b - a) * fx + (c - a) * fz
	return d + (c - d) * (1.0 - fx) + (b - d) * (1.0 - fz)


## Highest walkable surface: the terrain, or the top of a low prop (rock,
## log, crate...) you are standing on.
func ground_at(x: float, z: float) -> float:
	return maxf(terrain_h(x, z), prop_top(x, z))


## Top of the climbable prop under (x, z), or -INF. Climbable = box-shaped
## props (no trunk colliders) up to 3.2 m tall.
func prop_top(x: float, z: float) -> float:
	var best := -INF
	for p in props:
		if p.cols != null:
			continue
		var s: float = p.s
		var top: float = (p.node as Node3D).position.y + float(p.h) * s
		if float(p.h) * s > 3.2:
			continue
		var dx: float = x - p.x
		var dz: float = z - p.z
		if dx * dx + dz * dz > 36.0 * s * s:
			continue
		var c := cos(p.rot)
		var sn := sin(p.rot)
		var lx := (dx * c - dz * sn) / s
		var lz := (dx * sn + dz * c) / s
		if ROUND.has(str(p.get("key", ""))):
			# Rocks: stand on the curved surface.
			var dh := _dome(p, lx, lz)
			if dh > 0.0:
				best = maxf(best, (p.node as Node3D).position.y + dh * s * 0.96)
			continue
		# Slightly inset so you don't hover past rounded edges.
		if absf(lx) < p.hw * 0.85 and absf(lz) < p.hd * 0.85:
			best = maxf(best, top - float(p.h) * s * 0.06)
	return best


func walkable(x: float, z: float) -> bool:
	return terrain_h(x, z) > water


func gen_terrain(seed: int) -> void:
	var c := TN / 2.0
	for j in TN + 1:
		for i in TN + 1:
			var hh := 3.0 + (fbm(i * 1.3, j * 1.3, seed) - 0.45) * 7.0
			var d := Vector2(i - c, j - c).length()
			hh = lerpf(3.0, hh, clampf((d - 9.0) / 7.0, 0.0, 1.0))
			hh += clampf((d - 17.0) / 6.0, 0.0, 1.0) * 2.5
			var e := mini(mini(i, j), mini(TN - i, TN - j))
			hh = lerpf(6.0, hh, clampf(e / 4.0, 0.0, 1.0))
			h[_hi(i, j)] = clampf(hh, 0.4, 12.0)
	path.fill(0)
	for j in TN:
		for i in TN:
			var d := Vector2(i + 0.5 - c, j + 0.5 - c).length()
			if (d > 5.2 and d < 6.6) or (absf(i + 0.5 - c) < 1.1 and j < c - 5):
				path[j * TN + i] = 1
	water = 2.2


func flatten_at(x: float, z: float, rad: float, target: float) -> void:
	for j in range(int(floor(z - rad)), int(ceil(z + rad)) + 1):
		for i in range(int(floor(x - rad)), int(ceil(x + rad)) + 1):
			if i < 0 or j < 0 or i > TN or j > TN:
				continue
			var d := Vector2(i - x, j - z).length()
			if d > rad:
				continue
			var k := _hi(i, j)
			h[k] = lerpf(h[k], target, clampf(1.4 - d / rad, 0.0, 1.0))


## Sculpt brush: mode is "raise", "lower" or "smooth".
func brush(x: float, z: float, mode: String, dt: float) -> void:
	var R := BRUSH_R
	for j in range(int(floor(z - R)), int(ceil(z + R)) + 1):
		for i in range(int(floor(x - R)), int(ceil(x + R)) + 1):
			if i < 1 or j < 1 or i >= TN or j >= TN:
				continue
			var d := Vector2(i - x, j - z).length()
			if d > R:
				continue
			var w := pow(1.0 - d / R, 2.0)
			var k := _hi(i, j)
			if mode == "raise":
				h[k] = minf(12.0, h[k] + w * dt * 3.2)
			elif mode == "lower":
				h[k] = maxf(0.3, h[k] - w * dt * 3.2)
			else:
				var avg := (hv(i - 1, j) + hv(i + 1, j) + hv(i, j - 1) + hv(i, j + 1)) / 4.0
				h[k] = lerpf(h[k], avg, clampf(w * dt * 8.0, 0.0, 1.0))
	_dirty = true
	# Vertices moved here; their normals and colours also change the cells
	# around them, so mark one extra cell on each side.
	for cj in range(maxi(0, int(floor(z - R)) - 2) / CH, mini(TN - 1, int(ceil(z + R)) + 1) / CH + 1):
		for ci in range(maxi(0, int(floor(x - R)) - 2) / CH, mini(TN - 1, int(ceil(x + R)) + 1) / CH + 1):
			_dirty_chunks[cj * _nc() + ci] = true
	for p in props:
		if absf(p.x - x) < R + 3 and absf(p.z - z) < R + 3:
			(p.node as Node3D).position.y = terrain_h(p.x, p.z)


# ---------------------------------------------------------------- meshing

func _terrain_color(x: float, z: float, hh: float, ny: float) -> Color:
	var P := _pal()
	var i := clampi(int(floor(x)), 0, TN - 1)
	var j := clampi(int(floor(z)), 0, TN - 1)
	var c: String
	if path[j * TN + i] == 1:
		c = P.path
	elif hh < water + 0.35:
		c = P.sand
	elif ny < 0.78:
		c = P.rock
	else:
		c = P.grass if hash2(i, j, 3) < 0.5 else P.grass2
	var n := 0.94 + hash2(i * 3 + 1, j * 7 + 2, 9) * 0.1
	var col := U.col(c)
	return Color(col.r * n, col.g * n, col.b * n)


func _vn(i: int, j: int) -> Vector3:
	var dx := hv(i + 1, j) - hv(i - 1, j)
	var dz := hv(i, j + 1) - hv(i, j - 1)
	return Vector3(-dx, 2.0, -dz).normalized()


## The ground is split into CH × CH cell chunks so sculpting only rebuilds
## the few chunks under the brush (a full rebuild is ~13k triangles).
const CH := 10
var _chunks: Array[MeshInstance3D] = []
var _dirty_chunks := {}
var _ground_mat: ShaderMaterial


static func _nc() -> int:
	return ceili(float(TN) / CH)


func rebuild() -> void:
	_dirty = false
	_dirty_chunks.clear()
	if _mat_key != style_key or _ground_mat == null:
		_ground_mat = _terrain_material()
		_mat_key = style_key
	var n := _nc() * _nc()
	while _chunks.size() < n:
		var mi := MeshInstance3D.new()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_terrain_mi.add_child(mi)
		_chunks.append(mi)
	for c in n:
		_build_chunk(c)
	_update_water()
	if _skirt_key != style_key:
		_build_skirt()
		_skirt_key = style_key


func _rebuild_dirty() -> void:
	_dirty = false
	if _chunks.is_empty():
		rebuild()
		return
	for c in _dirty_chunks:
		_build_chunk(int(c))
	_dirty_chunks.clear()


func _build_chunk(c: int) -> void:
	var flat := _shade() == "flat"
	var ci := c % _nc()
	var cj := c / _nc()
	if not flat:
		_build_chunk_smooth(c, ci, cj)
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(cj * CH, mini(TN, (cj + 1) * CH)):
		for i in range(ci * CH, mini(TN, (ci + 1) * CH)):
			# Three's CCW triangles [(i,j),(i,j+1),(i+1,j)], [(i,j+1),(i+1,j+1),(i+1,j)];
			# emitted in reverse for Godot's clockwise front faces.
			_tri(st, [[i, j], [i + 1, j], [i, j + 1]], flat)
			_tri(st, [[i, j + 1], [i + 1, j], [i + 1, j + 1]], flat)
	_chunks[c].mesh = st.commit()
	_chunks[c].material_override = _ground_mat


## Smooth-shaded chunk: each vertex's position, normal, colour and blend
## weights are worked out once and shared by its triangles (indexed mesh).
func _build_chunk_smooth(c: int, ci: int, cj: int) -> void:
	var i0 := ci * CH
	var j0 := cj * CH
	var i1 := mini(TN, i0 + CH)
	var j1 := mini(TN, j0 + CH)
	var nx := i1 - i0 + 1
	var verts := PackedVector3Array()
	var nrms := PackedVector3Array()
	var cols := PackedColorArray()
	var uv2 := PackedVector2Array()
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var y := hv(i, j)
			var n := _vn(i, j)
			verts.append(Vector3(i, y, j))
			nrms.append(n)
			cols.append(_terrain_color(i - 0.01, j - 0.01, y, n.y).srgb_to_linear())
			uv2.append(_ground_w(i, j, y))
	var ids := PackedInt32Array()
	for j in range(j1 - j0):
		for i in range(i1 - i0):
			var a := j * nx + i
			# Same winding as `_tri`: (i,j),(i+1,j),(i,j+1) and (i,j+1),(i+1,j),(i+1,j+1).
			ids.append_array([a, a + 1, a + nx, a + nx, a + 1, a + nx + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrms
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = ids
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_chunks[c].mesh = am
	_chunks[c].material_override = _ground_mat


func _tri(st: SurfaceTool, pts: Array, flat: bool) -> void:
	var p := []
	for q in pts:
		p.append(Vector3(q[0], hv(q[0], q[1]), q[1]))
	if flat:
		var nrm: Vector3 = (p[2] - p[0]).cross(p[1] - p[0]).normalized()
		var cx: float = (p[0].x + p[1].x + p[2].x) / 3.0
		var cz: float = (p[0].z + p[1].z + p[2].z) / 3.0
		var ch: float = (p[0].y + p[1].y + p[2].y) / 3.0
		var col := _terrain_color(cx, cz, ch, nrm.y).srgb_to_linear()
		for k in 3:
			st.set_color(col)
			st.set_normal(nrm)
			st.add_vertex(p[k])
	else:
		for k in 3:
			var n := _vn(pts[k][0], pts[k][1])
			st.set_color(_terrain_color(pts[k][0] - 0.01, pts[k][1] - 0.01, p[k].y, n.y).srgb_to_linear())
			st.set_uv2(_ground_w(pts[k][0], pts[k][1], p[k].y))
			st.set_normal(n)
			st.add_vertex(p[k])


## Texture blend weights for a heightmap vertex: x = path, y = sand.
func _ground_w(i: int, j: int, hh: float) -> Vector2:
	var pw := 0.0
	for q in [[i - 1, j - 1], [i, j - 1], [i - 1, j], [i, j]]:
		var a: int = clampi(q[0], 0, TN - 1)
		var b: int = clampi(q[1], 0, TN - 1)
		pw += path[b * TN + a]
	return Vector2(pw / 4.0, 1.0 if hh < water + 0.35 else 0.0)


func _terrain_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var sh := _shade()
	m.shader = SH_TOON if sh == "toon" else SH_FLAT
	if style_key == "anime":
		m.shader = SH_TERRAIN_ANIME
	m.set_shader_parameter("rock_color", U.col(_pal().rock))
	m.set_shader_parameter("detail_amount", 0.07 if sh == "toon" else 0.05)
	m.set_shader_parameter("rock_mix", 0.0 if sh == "flat" else 0.6)
	if sh != "flat":
		for t in ["grass", "dirt", "floor", "rock"]:
			m.set_shader_parameter(t + "_tex", load("res://assets/textures/%s_color.jpg" % t))
			m.set_shader_parameter(t + "_nrm", load("res://assets/textures/%s_normal.jpg" % t))
		# Anime keeps its painted palette and borrows only surface detail.
		m.set_shader_parameter("tex_mode", 1)
	return m


func _update_water() -> void:
	var P := _pal()
	var wm := _water_mi.material_override as ShaderMaterial
	var wc := U.col(P.water)
	wm.set_shader_parameter("water_color", wc)
	wm.set_shader_parameter("deep_color", U.shade(wc, 0.35))
	wm.set_shader_parameter("opacity", float(P.get("wop", 0.8)))
	var sh := _shade()
	wm.set_shader_parameter("roughness_val", 0.35 if sh == "flat" else 0.05)
	wm.set_shader_parameter("wave_strength", 0.015 if sh == "flat" else 0.035)
	_water_mi.position = Vector3(TN / 2.0, water, TN / 2.0)


## Horizon skirt: a coarse grid ring around the play area at the rim height
## (5.98) that rolls up into low hills in the distance.
func _build_skirt() -> void:
	const S := 150.0
	const CELL := 6.0
	var base := 5.98
	var col := U.shade(U.col(_pal().grass2), 0.92)
	var n := int((TN + 2 * S) / CELL)
	var flat := _shade() == "flat"
	var hf := func(x: float, z: float) -> float:
		var dx := maxf(maxf(-x, x - TN), 0.0)
		var dz := maxf(maxf(-z, z - TN), 0.0)
		var d := Vector2(dx, dz).length()
		var k := clampf((d - 6.0) / 70.0, 0.0, 1.0)
		return base + k * k * (4.0 + fbm(x * 0.4 + 300.0, z * 0.4 + 300.0, 41.0) * (34.0 if style_key == "anime" else 22.0))
	var cf := func(x: float, z: float, y: float) -> Color:
		var t := clampf((y - base) / 18.0, 0.0, 1.0)
		var c2: Color = col.lerp(U.col(_pal().rock), t * 0.55)
		var v := 0.94 + hash2(floor(x / CELL), floor(z / CELL), 5) * 0.1
		return Color(c2.r * v, c2.g * v, c2.b * v).srgb_to_linear()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n:
		for i in n:
			var x0 := -S + i * CELL
			var z0 := -S + j * CELL
			if x0 >= 0.0 and x0 + CELL <= TN and z0 >= 0.0 and z0 + CELL <= TN:
				continue
			var q := [Vector2(x0, z0), Vector2(x0 + CELL, z0), Vector2(x0, z0 + CELL), Vector2(x0 + CELL, z0 + CELL)]
			var v := []
			for e in q:
				v.append(Vector3(e.x, hf.call(e.x, e.y), e.y))
			for tri in [[0, 1, 2], [2, 1, 3]]:
				var a: Vector3 = v[tri[0]]
				var b: Vector3 = v[tri[1]]
				var c: Vector3 = v[tri[2]]
				var nrm := (c - a).cross(b - a).normalized()
				for p in [a, b, c]:
					var pn: Vector3 = nrm
					if not flat:
						var e2 := 0.5
						pn = Vector3(hf.call(p.x - e2, p.z) - hf.call(p.x + e2, p.z), 2.0 * e2, hf.call(p.x, p.z - e2) - hf.call(p.x, p.z + e2)).normalized()
					st.set_color(cf.call(p.x, p.z, p.y))
					st.set_normal(pn)
					st.add_vertex(p)
	_skirt_mi.mesh = st.commit()
	var m := _terrain_material()
	m.set_shader_parameter("rock_mix", 0.0)
	_skirt_mi.material_override = m
	if _backdrop:
		_backdrop.queue_free()
		_backdrop = null
	_skirt_hf = hf
	if style_key == "anime":
		_build_backdrop(hf)


## Instanced forest filling the horizon around the play area, plus floating
## light motes and drifting leaves over the glade.
func _build_backdrop(hf: Callable) -> void:
	_backdrop = Node3D.new()
	_backdrop.name = "Backdrop"
	add_child(_backdrop)
	var rr := RandomNumberGenerator.new()
	rr.seed = 4242
	for variant in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = AnimeNature.backdrop_tree_mesh(variant)
		var xfs := []
		for k in 260:
			var x := rr.randf_range(-110.0, TN + 110.0)
			var z := rr.randf_range(-110.0, TN + 110.0)
			var dx := maxf(maxf(-x, x - TN), 0.0)
			var dz := maxf(maxf(-z, z - TN), 0.0)
			var d := Vector2(dx, dz).length()
			if d < 3.5 or d > 105.0:
				continue
			# Thin out with distance and leave a few meadow clearings.
			if rr.randf() < d / 160.0 or fbm(x * 0.05, z * 0.05, 7.0) < 0.36:
				continue
			var y: float = hf.call(x, z)
			var sc := rr.randf_range(0.8, 1.4) * (1.0 + d / 120.0)
			xfs.append(Transform3D(Basis(Vector3.UP, rr.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(x, y - 0.4, z)))
		mm.instance_count = xfs.size()
		for i in xfs.size():
			mm.set_instance_transform(i, xfs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_backdrop.add_child(mmi)
	_backdrop.add_child(_motes())
	_backdrop.add_child(_falling_leaves())


func _motes() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 120
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = Vector3(TN / 2.0, 5.0, TN / 2.0)
	p.visibility_aabb = AABB(Vector3(-50, -10, -50), Vector3(100, 25, 100))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(TN / 2.0, 3, TN / 2.0)
	pm.gravity = Vector3(0, 0.05, 0)
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	pm.turbulence_noise_scale = 6.0
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0))
	fade.add_point(0.2, Color(1, 1, 1, 1))
	fade.add_point(0.8, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = fade
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.0, 0.95, 0.6) * 2.2
	var dot := GradientTexture2D.new()
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1, 0.5)
	var dg := Gradient.new()
	dg.set_color(0, Color(1, 1, 1, 1))
	dg.set_color(1, Color(1, 1, 1, 0))
	dot.gradient = dg
	m.albedo_texture = dot
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _falling_leaves() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 60
	p.lifetime = 12.0
	p.preprocess = 12.0
	p.position = Vector3(TN / 2.0, 12.0, TN / 2.0)
	p.visibility_aabb = AABB(Vector3(-50, -20, -50), Vector3(100, 30, 100))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(TN / 2.0, 2, TN / 2.0)
	pm.gravity = Vector3(0.35, -0.55, 0.15)
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.4
	pm.direction = Vector3(0.4, -1, 0.2)
	pm.spread = 35.0
	pm.angular_velocity_min = -90.0
	pm.angular_velocity_max = 90.0
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.14, 0.09)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.62, 0.82, 0.32)
	m.albedo_texture = AnimeNature.leaf_texture("single")
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


# ---------------------------------------------------------------- grass

func rebuild_grass() -> void:
	_grass_mmi.multimesh = null
	_flower_mmi.multimesh = null
	if _grass_root:
		_grass_root.queue_free()
		_grass_root = null
	if grass_density <= 0.0:
		return
	if style_key == "anime":
		_anime_grass()
		return
	var sh := _shade()
	var base: Color
	var tip: Color
	var hue := 0.27
	var sat := 0.5
	var count := 6000
	var flowers := 1200
	var blade_h := 1.0
	match style_key:
		"lowpoly":
			base = U.col("#4f8a3a")
			tip = U.col("#a6d36a")
			hue = 0.26
			sat = 0.45
			count = 2600
			flowers = 500
			blade_h = 0.8
		_:
			base = U.col("#4f9e46")
			tip = U.col("#b6e98a")
	count = int(count * grass_density)
	flowers = int(flowers * grass_density)
	var gm := ShaderMaterial.new()
	gm.shader = SH_GRASS
	gm.set_shader_parameter("toon", 1.0 if sh == "toon" else 0.0)
	gm.set_shader_parameter("wind_strength", 1.0)

	# Blade tuft mesh: 5 crossed triangles.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rr := RandomNumberGenerator.new()
	rr.seed = 1234
	for k in 5:
		var a := k / 5.0 * PI + rr.randf() * 0.4
		var w := 0.05
		var hh := (0.42 + rr.randf() * 0.3) * blade_h
		var ox := (rr.randf() - 0.5) * 0.16
		var oz := (rr.randf() - 0.5) * 0.16
		var ca := cos(a)
		var sa := sin(a)
		var lean := (rr.randf() - 0.5) * 0.12
		var verts := [Vector3(ox - ca * w, 0, oz - sa * w), Vector3(ox + lean, hh, oz + lean * 0.5), Vector3(ox + ca * w, 0, oz + sa * w)]
		var cols := [base, tip, base]
		for v in 3:
			st.set_color(cols[v].srgb_to_linear())
			st.set_normal(Vector3.UP)
			st.add_vertex(verts[v])
	var blade := st.commit()
	blade.surface_set_material(0, gm)
	_grass_mmi.multimesh = _scatter(blade, count, hue, sat, true, [])

	if flowers > 0:
		var fs := SurfaceTool.new()
		fs.begin(Mesh.PRIMITIVE_TRIANGLES)
		var stem := U.col("#4f8f3a").srgb_to_linear()
		for v in [Vector3(-0.012, 0, 0), Vector3(0, 0.55, 0), Vector3(0.012, 0, 0)]:
			fs.set_color(stem)
			fs.set_normal(Vector3.UP)
			fs.add_vertex(v)
		for k in 5:
			var a := k / 5.0 * TAU
			var b := (k + 1) / 5.0 * TAU
			var pv := [Vector3(0, 0.58, 0), Vector3(cos(b) * 0.07, 0.58, sin(b) * 0.07), Vector3(cos(a) * 0.07, 0.58, sin(a) * 0.07)]
			var pc := [Color(1, 0.92, 0.5), Color.WHITE, Color.WHITE]
			for v in 3:
				fs.set_color(pc[v].srgb_to_linear())
				fs.set_normal(Vector3.UP)
				fs.add_vertex(pv[v])
		var fmesh := fs.commit()
		fmesh.surface_set_material(0, gm)
		_flower_mmi.multimesh = _scatter(fmesh, flowers, 0.0, 0.0, false, ["#ffffff", "#ffe066", "#8fb7ff", "#c9a2ff", "#ff9ec4"])


## Anime meadow, built for speed: painted grass-clump cards (2 crossed quads
## each, ~8 vertices instead of ~130 for modelled blades), grouped in 12 m
## chunks so off-screen and distant chunks are culled, and faded out by
## distance in the shader. The ground shader already paints grass colour, so
## sparse clumps read as a full meadow.
const GRASS_CHUNK := 12.0
const GRASS_FAR := 42.0

func _anime_grass() -> void:
	if _grass_root:
		_grass_root.queue_free()
	_grass_root = Node3D.new()
	_grass_root.name = "GrassChunks"
	add_child(_grass_root)
	if _border_mmi:
		_border_mmi.queue_free()
		_border_mmi = null
	var gm := ShaderMaterial.new()
	gm.shader = SH_GRASS_ANIME
	gm.set_shader_parameter("grass_tex", AnimeNature.grass_texture())
	gm.set_shader_parameter("fade_end", GRASS_FAR)
	var card := _grass_card_mesh(1.05, 0.62)
	card.surface_set_material(0, gm)
	var fm := ShaderMaterial.new()
	fm.shader = SH_GRASS_ANIME
	fm.set_shader_parameter("grass_tex", AnimeNature.flower_texture())
	fm.set_shader_parameter("fade_end", GRASS_FAR * 0.7)
	fm.set_shader_parameter("tint_strength", 0.0)
	var fcard := _grass_card_mesh(0.28, 0.3)
	fcard.surface_set_material(0, fm)
	var tm := gm.duplicate() as ShaderMaterial
	tm.set_shader_parameter("grass_tex", AnimeNature.grass_texture(true))
	tm.set_shader_parameter("tip_color", Color(0.78, 0.9, 0.42))
	var tall := _grass_card_mesh(0.8, 1.0)
	tall.surface_set_material(0, tm)
	_tall_card = tall
	var density := 2.4 * grass_density
	var lo := -12.0 if _skirt_hf.is_valid() else 0.0
	var hi := TN + (12.0 if _skirt_hf.is_valid() else 0.0)
	var cz := lo
	while cz < hi:
		var cx := lo
		while cx < hi:
			_grass_chunk(card, fcard, cx, cz, density)
			cx += GRASS_CHUNK
		cz += GRASS_CHUNK


func _grass_chunk(card: Mesh, fcard: Mesh, cx: float, cz: float, density: float) -> void:
	var grass := []
	var flowers := []
	var talls := []
	var n := int(GRASS_CHUNK * GRASS_CHUNK * density)
	for k in n:
		var x := cx + randf() * GRASS_CHUNK
		var z := cz + randf() * GRASS_CHUNK
		var inside := x > 0.5 and z > 0.5 and x < TN - 0.5 and z < TN - 0.5
		var y: float
		if inside:
			var i := int(x)
			var j := int(z)
			if path[j * TN + i] == 1:
				continue
			y = terrain_h(x, z)
			if y < water + 0.4 or prop_hit(x, z, y):
				continue
		else:
			if not _skirt_hf.is_valid():
				continue
			y = _skirt_hf.call(x, z)
		var sc := 0.75 + randf() * 0.6
		var xf := Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3(sc, sc * (0.8 + randf() * 0.45), sc)), Vector3(x, y - 0.03, z))
		var roll := randf()
		if roll < 0.04:
			flowers.append(xf)
		elif roll < 0.2:
			talls.append(xf)
		else:
			grass.append(xf)
	for pair in [[card, grass], [fcard, flowers], [_tall_card, talls]]:
		var list: Array = pair[1]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = pair[0]
		mm.instance_count = list.size()
		var flower: bool = pair[0] == fcard
		var petals := [Color.WHITE, Color.WHITE, Color("ffe27a"), Color("9cc8ff"), Color("d6b3ff"), Color("ffb3cf")]
		for i in list.size():
			mm.set_instance_transform(i, list[i])
			mm.set_instance_color(i, petals[randi() % petals.size()] if flower else Color.from_hsv(0.23 + randf() * 0.07, 0.25, 0.85 + randf() * 0.15))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = GRASS_FAR + GRASS_CHUNK
		mmi.visibility_range_end_margin = 6.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		_grass_root.add_child(mmi)


## Two crossed vertical quads, UV v = 1 at the ground.
func _grass_card_mesh(w := 0.9, h := 0.6) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 2:
		var a := k * PI / 2.0 + PI / 4.0
		var d := Vector3(cos(a), 0, sin(a)) * w * 0.5
		var q := [-d, d, -d + Vector3(0, h, 0), d + Vector3(0, h, 0)]
		var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(0, 0), Vector2(1, 0)]
		for idx in [0, 1, 2, 2, 1, 3]:
			st.set_uv(uv[idx])
			st.set_normal(Vector3.UP)
			st.add_vertex(q[idx])
	return st.commit()


func _scatter(mesh: Mesh, n: int, hue: float, sat: float, is_grass: bool, petals: Array) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = n
	var placed := 0
	var tries := 0
	while tries < n * 3 and placed < n:
		tries += 1
		var x := 1.0 + randf() * (TN - 2)
		var z := 1.0 + randf() * (TN - 2)
		var i := int(floor(x))
		var j := int(floor(z))
		if path[j * TN + i] == 1:
			continue
		var y := terrain_h(x, z)
		if y < water + 0.4:
			continue
		if is_grass:
			var sl := absf(hv(i + 1, j) - hv(i, j)) + absf(hv(i, j + 1) - hv(i, j))
			if sl > 1.1:
				continue
		if prop_hit(x, z, y):
			continue
		var s := (0.7 + randf() * 0.7) if is_grass else (0.8 + randf() * 0.5)
		var sy := s * (0.8 + randf() * 0.5) if is_grass else s
		var b := Basis(Vector3.UP, randf() * 6.3).scaled(Vector3(s, sy, s))
		mm.set_instance_transform(placed, Transform3D(b, Vector3(x, y - 0.02, z)))
		var c: Color
		if is_grass:
			c = Color.from_hsv(hue + randf() * 0.06, sat * 0.8, 0.55 + randf() * 0.2).lerp(Color.WHITE, 0.3)
		else:
			c = U.col(petals[randi() % petals.size()])
		mm.set_instance_color(placed, c)
		placed += 1
	mm.visible_instance_count = placed
	return mm


# ---------------------------------------------------------------- props

func _prop_def(key: String) -> Dictionary:
	return Props.defs(style_key).get(key, {})


func add_prop(key: String, x: float, z: float, rot := 0.0, s := 1.0, seed := -1) -> Dictionary:
	if not Props.has(style_key, key):
		return {}
	if seed < 0:
		seed = randi() % 1000000
	var node := Props.build(style_key, key, seed)
	if node == null:
		return {}
	if not AssetLib.is_key(key):
		Kit.merge_static(node)
	var bb := Kit.bounds(node)
	var def := _prop_def(key)
	var cols: Variant = def.get("cols", null)
	if AssetLib.is_key(key):
		# Imported: small things don't block, tall narrow-based things are
		# trees (collide at the trunk), the rest use their bounding box.
		if bb.size.y < 0.8:
			cols = []
		elif bb.size.y > 3.0 and maxf(bb.size.x, bb.size.z) > bb.size.y * 0.45:
			cols = [[0.0, 0.0, clampf(maxf(bb.size.x, bb.size.z) * 0.08, 0.25, 0.8)]]
	var p := {"key": key, "x": x, "z": z, "rot": rot, "s": s, "seed": seed, "node": node,
		"hw": bb.size.x / 2.0, "hd": bb.size.z / 2.0, "h": bb.size.y, "cols": cols, "bb": bb}
	node.set_meta("prop", p)
	_props_root.add_child(node)
	update_prop(p)
	props.append(p)
	return p


func update_prop(p: Dictionary) -> void:
	var n: Node3D = p.node
	n.position = Vector3(p.x, terrain_h(p.x, p.z), p.z)
	n.rotation = Vector3(0, p.rot, 0)
	n.scale = Vector3.ONE * float(p.s)


func remove_prop(p: Dictionary) -> void:
	var i := props.find(p)
	if i >= 0:
		props.remove_at(i)
	var n: Node3D = p.get("node")
	if is_instance_valid(n):
		n.queue_free()


func clear_props() -> void:
	for p in props:
		var n: Node3D = p.get("node")
		if is_instance_valid(n):
			n.free()
	props.clear()


## Rounded props: collide and are walked on as a dome, not as their box.
const ROUND := ["rocks", "stone", "rock"]


## Height of a rounded prop's dome above its base at local (lx, lz) in the
## prop's unscaled units, or -1 outside it.
static func _dome(p: Dictionary, lx: float, lz: float) -> float:
	var ex: float = lx / (float(p.hw) * 0.9)
	var ez: float = lz / (float(p.hd) * 0.9)
	var r2 := ex * ex + ez * ez
	if r2 >= 1.0:
		return -1.0
	return float(p.h) * sqrt(1.0 - r2)


func prop_hit(x: float, z: float, y: float) -> bool:
	for p in props:
		var dx: float = x - p.x
		var dz: float = z - p.z
		var s: float = p.s
		if dx * dx + dz * dz > 64.0 * s * s:
			continue
		if ROUND.has(str(p.get("key", ""))):
			# Blocks only where the dome rises more than a step above the feet
			# (checked at the nearest point of the body's circle).
			var c0 := cos(p.rot)
			var s0 := sin(p.rot)
			var l := Vector2((dx * c0 - dz * s0) / s, (dx * s0 + dz * c0) / s)
			var near := l - l.normalized() * minf(l.length(), AR / s)
			var dh := _dome(p, near.x, near.y)
			if dh > 0.0 and y < (p.node as Node3D).position.y + dh * s - STEP:
				return true
			continue
		# Anything lower than a step (or that you've jumped above) doesn't block.
		if y > (p.node as Node3D).position.y + p.h * s - STEP:
			continue
		var c := cos(p.rot)
		var sn := sin(p.rot)
		var lx := (dx * c - dz * sn) / s
		var lz := (dx * sn + dz * c) / s
		if p.cols != null:
			for cc in p.cols:
				if pow(lx - cc[0], 2) + pow(lz - cc[1], 2) < pow(cc[2] + AR / s, 2):
					return true
			continue
		if absf(lx) < p.hw + AR / s and absf(lz) < p.hd + AR / s:
			return true
	return false


## True when a character standing with feet at `p` would collide.
func body_blocked(p: Vector3) -> bool:
	# Water never blocks: shallow water is waded, deep water is swum.
	return p.x < 0.5 or p.z < 0.5 or p.x > TN - 0.5 or p.z > TN - 0.5 or prop_hit(p.x, p.z, p.y)


func water_bottom(p: Vector3) -> float:
	return terrain_h(p.x, p.z)


## Height of the water surface where it's deep enough to swim, else -1e9.
func water_surface(p: Vector3) -> float:
	return water if terrain_h(p.x, p.z) < water - 0.6 else -1.0e9


func free_spot(x: float, z: float, r := 1.2) -> bool:
	if x < 2 or z < 2 or x > TN - 2 or z > TN - 2:
		return false
	if terrain_h(x, z) < water + 0.3:
		return false
	for p in props:
		if Vector2(p.x - x, p.z - z).length() < r + _footprint(p) * p.s:
			return false
	return true


## Ground radius a prop occupies: trunk colliders for trees, almost nothing
## for undergrowth, the bounding box otherwise.
func _footprint(p: Dictionary) -> float:
	var cols: Variant = p.get("cols")
	if cols is Array:
		if (cols as Array).is_empty():
			return 0.25
		var m := 0.0
		for c in cols:
			m = maxf(m, Vector2(c[0], c[1]).length() + float(c[2]))
		return m
	return maxf(p.hw, p.hd) * 0.8


func on_path(x: float, z: float) -> bool:
	var i := clampi(int(floor(x)), 0, TN - 1)
	var j := clampi(int(floor(z)), 0, TN - 1)
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var ii := i + di
			var jj := j + dj
			if ii >= 0 and jj >= 0 and ii < TN and jj < TN and path[jj * TN + ii] == 1:
				return true
	return false


func _scatter_props(key: String, n: int, r_min: float, r_max: float, r: U.Rng, avoid_path := true) -> void:
	var c := TN / 2.0
	var placed := 0
	var t := 0
	# Layouts were authored for a 48 m world; "fill to the edge" scatters
	# (r_max >= 20) cover the whole, bigger square.
	var fill := r_max >= 20.0
	if fill:
		n = int(n * TN / 48.0)
	while t < n * 12 and placed < n:
		t += 1
		var a := r.next() * TAU
		var d := r_min + r.next() * (r_max - r_min)
		var x := c + cos(a) * d
		var z := c + sin(a) * d
		if fill:
			x = 2.0 + r.next() * (TN - 4.0)
			z = 2.0 + r.next() * (TN - 4.0)
			if Vector2(x - c, z - c).length() < r_min:
				continue
		if avoid_path and on_path(x, z):
			continue
		var spacing := 5.0 if key in ["oak", "tall", "blossom"] else 0.6
		if not free_spot(x, z, spacing):
			continue
		var rot := r.next() * TAU
		var sc := 0.85 + r.next() * 0.35
		add_prop(key, x, z, rot, sc)
		placed += 1


func _ring_place(key: String, n: int, d: float, r: U.Rng, offset := 0.0, face := true) -> void:
	var c := TN / 2.0
	for k in n:
		var a := offset + float(k) / n * TAU
		var x := c + cos(a) * d
		var z := c + sin(a) * d
		if absf(x - c) < 2.5 and z < c:
			continue
		add_prop(key, x, z, atan2(c - x, c - z) if face else r.next() * 6, 1)


## Generates a fresh world for `key` (terrain + the style's village/outpost).
func new_world(key: String) -> void:
	style_key = key
	var seed := randi() % 1000
	var r := U.rng(seed + 7)
	var c := TN / 2.0
	gen_terrain(seed)
	clear_props()
	if key == "anime":
		# A forest glade: ruins and a campfire in a clearing, a winding path,
		# dense broadleaf forest all around, undergrowth everywhere.
		add_prop("arch", c, c + 7.5, PI)
		for q in [[c - 6.5, c + 3.5], [c + 6.8, c + 4.2], [c - 5.0, c - 5.5], [c + 7.5, c - 3.0]]:
			add_prop("pillar", q[0], q[1], r.next() * TAU)
		add_prop("fire", c + 1.5, c - 1.0)
		add_prop("log", c + 3.6, c - 1.4, 1.3)
		add_prop("log", c - 0.8, c - 3.4, 0.2)
		add_prop("stump", c - 1.5, c + 0.8)
		add_prop("house", c - 12.5, c - 9.5, 0.7)
		add_prop("windmill", c + 16, c + 14, -0.6)
		add_prop("lantern", c - 1.6, c - 7.5)
		add_prop("lantern", c + 1.6, c - 7.5)
		add_prop("rocks", c + 9.5, c + 9.5, r.next() * TAU)
		add_prop("rocks", c - 10.5, c + 7.5, r.next() * TAU)
		_scatter_props("tall", 7, 15, 23, r)
		_scatter_props("oak", 12, 11, 23, r)
		_scatter_props("blossom", 3, 10, 18, r)
		_scatter_props("rocks", 6, 12, 23, r)
		_scatter_props("stone", 10, 7, 22, r)
		_scatter_props("bush", 16, 8, 23, r)
		_scatter_props("fern", 22, 7, 23, r)
		_scatter_props("log", 3, 12, 21, r)
		_scatter_props("stump", 3, 10, 21, r)
		_scatter_props("mushrooms", 10, 8, 23, r)
		_scatter_props("flowers", 20, 4, 23, r)
	else:
		_ring_place("house", 4, 10, r, 0.4)
		add_prop("well", c, c)
		add_prop("bench", c - 3.2, c + 2.4, PI * 0.85)
		add_prop("bench", c + 3.2, c + 2.4, -PI * 0.85)
		add_prop("fire", c + 3.6, c - 3, 0)
		var z2 := 4.0
		while z2 < c - 6:
			add_prop("lamp", c - 1.9, z2)
			z2 += 5
		for f in [[c - 7, c - 9, 0.3], [c - 5, c - 10, 0.1], [c + 7, c - 9, -0.3]]:
			add_prop("fence", f[0], f[1], f[2])
		add_prop("barrel", c + 7, c + 3)
		add_prop("barrel", c + 7.5, c + 3.6)
		_scatter_props("pine", 16, 13, 22, r)
		_scatter_props("tree", 12, 12, 22, r)
		_scatter_props("rock", 8, 10, 22, r)
		_scatter_props("flowers", 10, 7, 18, r)
	for p in props:
		flatten_at(p.x, p.z, _footprint(p) * p.s + 0.6, terrain_h(p.x, p.z))
	for p in props:
		update_prop(p)
	rebuild()
	rebuild_grass()


# ---------------------------------------------------------------- queries

## Ray pick against props (rotated AABBs) and the heightfield.
## Returns {point: Vector3, prop: Dictionary or null}, or {} on a miss.
func pick(origin: Vector3, dir: Vector3, max_d: float) -> Dictionary:
	dir = dir.normalized()
	var best_t := INF
	var best_prop: Variant = null
	for p in props:
		var n: Node3D = p.node
		var inv := n.global_transform.affine_inverse() if n.is_inside_tree() else n.transform.affine_inverse()
		var lo := inv * origin
		var ld := inv.basis * dir
		var t := _ray_aabb(lo, ld, p.bb)
		if t >= 0.0:
			# Convert local parameter back to world distance.
			var wp: Vector3 = (n.global_transform if n.is_inside_tree() else n.transform) * (lo + ld * t)
			var wt := (wp - origin).length()
			if wt < best_t and wt <= max_d:
				best_t = wt
				best_prop = p
	var tt := _ray_terrain(origin, dir, minf(max_d, best_t))
	if tt >= 0.0 and tt < best_t:
		return {"point": origin + dir * tt, "prop": null}
	if best_prop != null:
		return {"point": origin + dir * best_t, "prop": best_prop}
	return {}


func _ray_aabb(o: Vector3, d: Vector3, bb: AABB) -> float:
	var tmin := -INF
	var tmax := INF
	for a in 3:
		var lo := bb.position[a]
		var hi := bb.end[a]
		if absf(d[a]) < 1e-9:
			if o[a] < lo or o[a] > hi:
				return -1.0
			continue
		var t1 := (lo - o[a]) / d[a]
		var t2 := (hi - o[a]) / d[a]
		tmin = maxf(tmin, minf(t1, t2))
		tmax = minf(tmax, maxf(t1, t2))
	if tmax < maxf(tmin, 0.0):
		return -1.0
	return maxf(tmin, 0.0)


func _ray_terrain(o: Vector3, d: Vector3, max_d: float) -> float:
	var step := 0.1
	var t := 0.0
	var prev := 0.0
	if max_d == INF:
		max_d = 200.0
	while t <= max_d:
		var p := o + d * t
		var inside := p.x >= 0 and p.z >= 0 and p.x <= TN and p.z <= TN
		if inside and p.y <= terrain_h(p.x, p.z):
			var a := prev
			var b := t
			for _k in 12:
				var m := (a + b) * 0.5
				var q := o + d * m
				if q.y <= terrain_h(q.x, q.z):
					b = m
				else:
					a = m
			return b
		prev = t
		t += step
	return -1.0


## Shortens a camera boom so it stays above the ground.
func clip_cam(from: Vector3, dir: Vector3, dist: float) -> float:
	var out := dist
	for k in range(1, 11):
		var d := dist * k / 10.0
		var p := from + dir * d
		# Stay above the ground and the water surface.
		if p.y < maxf(terrain_h(p.x, p.z), water + 0.1) + 0.3:
			out = maxf(0.5, dist * (k - 1) / 10.0)
			break
	# Keep the camera out of buildings (solid props without trunk colliders).
	dir = dir.normalized()
	for pr in props:
		if pr.get("cols") != null or float(pr.h) * float(pr.s) < 1.6:
			continue
		var n: Node3D = pr.node
		if Vector2(n.global_position.x - from.x, n.global_position.z - from.z).length() > out + 12.0:
			continue
		var xf := n.global_transform
		var inv := xf.affine_inverse()
		var lo := inv * from
		var ld := inv.basis * dir
		var bb: AABB = pr.bb
		if bb.has_point(lo):
			continue
		var t := _ray_aabb(lo, ld, bb)
		if t >= 0.0:
			var wt := (xf * (lo + ld * t) - from).length()
			if wt < out:
				out = maxf(0.5, wt - 0.35)
	return out


# ---------------------------------------------------------------- animation

func animate(dt: float, t: float) -> void:
	_t = t
	for p in props:
		var n: Node3D = p.node
		if n.has_meta("spin"):
			(n.get_meta("spin") as Node3D).rotation.z -= dt * 0.7
		if n.has_meta("flicker"):
			var arr: Array = n.get_meta("flicker")
			for i in arr.size():
				var m: Node3D = arr[i]
				var sxz := 1.0 + sin(t * 7 + i) * 0.08
				m.scale = Vector3(sxz, 1.0 + sin(t * 11 + i * 2) * 0.18, sxz)
			if n.has_meta("light"):
				var l: OmniLight3D = n.get_meta("light")
				l.light_energy = 2.2 + sin(t * 11) * 0.25 + sin(t * 23.0) * 0.15


# ---------------------------------------------------------------- persistence

func serialize() -> Dictionary:
	var hs := []
	hs.resize(h.size())
	for i in h.size():
		hs[i] = U.r2(h[i])
	var ps := []
	for p in props:
		ps.append([p.key, U.r2(p.x), U.r2(p.z), U.r2(p.rot), U.r2(p.s), p.seed])
	return {"size": TN, "h": hs, "path": U.rle_encode(path), "water": water, "props": ps}


## Loads a saved world. Pass `style` to switch style first (props are
## style-specific); otherwise the current `style_key` is used.
func load_data(d: Dictionary, style := "") -> void:
	if style != "":
		style_key = style
	clear_props()
	var src: Array = d.get("h", [])
	var n := int(d.get("size", Styles.LEGACY_SIZE))
	var off := (TN - n) / 2
	load_offset = float(off)
	var old_path := U.rle_decode(str(d.get("path", "")), n * n)
	path.fill(0)
	for j in TN + 1:
		for i in TN + 1:
			# Older, smaller worlds sit in the centre; their rim extends outward.
			var si := clampi(i - off, 0, n)
			var sj := clampi(j - off, 0, n)
			var k := sj * (n + 1) + si
			h[_hi(i, j)] = float(src[k]) if k < src.size() else 6.0
	for j in n:
		for i in n:
			path[(j + off) * TN + i + off] = old_path[j * n + i]
	water = float(d.get("water", 2.2))
	for e in d.get("props", []):
		if e is Array and e.size() >= 3:
			add_prop(str(e[0]), float(e[1]) + off, float(e[2]) + off, float(e[3]) if e.size() > 3 else 0.0, float(e[4]) if e.size() > 4 else 1.0, int(e[5]) if e.size() > 5 and e[5] != null else -1)
	rebuild()
	rebuild_grass()
