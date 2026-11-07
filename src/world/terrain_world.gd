class_name TerrainWorld
extends Node3D
## Heightfield world for the anime, tactical and low-poly styles.
##
## A 48x48 cell heightmap ((TN+1)^2 vertices), a per-cell path mask, a water
## plane, procedural props, instanced grass and a horizon skirt. Ported from
## the web build and saved in the same JSON shape so web projects import.

signal changed

const TN := 48
const AR := 0.28
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
var _mat_key := ""

const SH_REAL := preload("res://src/shaders/terrain.gdshader")
const SH_TOON := preload("res://src/shaders/terrain_toon.gdshader")
const SH_FLAT := preload("res://src/shaders/terrain_flat.gdshader")
const SH_WATER := preload("res://src/shaders/water.gdshader")
const SH_GRASS := preload("res://src/shaders/grass.gdshader")


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
		rebuild()
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


func ground_at(x: float, z: float) -> float:
	return terrain_h(x, z)


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


func rebuild() -> void:
	_dirty = false
	var flat := _shade() == "flat"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in TN:
		for i in TN:
			# Three's CCW triangles [(i,j),(i,j+1),(i+1,j)], [(i,j+1),(i+1,j+1),(i+1,j)];
			# emitted in reverse for Godot's clockwise front faces.
			_tri(st, [[i, j], [i + 1, j], [i, j + 1]], flat)
			_tri(st, [[i, j + 1], [i + 1, j], [i + 1, j + 1]], flat)
	_terrain_mi.mesh = st.commit()
	if _mat_key != style_key or _terrain_mi.material_override == null:
		_terrain_mi.material_override = _terrain_material()
		_mat_key = style_key
	_terrain_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_update_water()
	if _skirt_key != style_key:
		_build_skirt()
		_skirt_key = style_key


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
			st.set_normal(n)
			st.add_vertex(p[k])


func _terrain_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var sh := _shade()
	m.shader = SH_TOON if sh == "toon" else (SH_FLAT if sh == "flat" else SH_REAL)
	m.set_shader_parameter("rock_color", U.col(_pal().rock))
	m.set_shader_parameter("detail_amount", 0.07 if sh == "toon" else (0.05 if sh == "flat" else 0.16))
	m.set_shader_parameter("rock_mix", 0.0 if sh == "flat" else 0.6)
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
		return base + k * k * (4.0 + fbm(x * 0.4 + 300.0, z * 0.4 + 300.0, 41.0) * 22.0)
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


# ---------------------------------------------------------------- grass

func rebuild_grass() -> void:
	_grass_mmi.multimesh = null
	_flower_mmi.multimesh = null
	if grass_density <= 0.0:
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
		"tactical":
			base = U.col("#5f6438")
			tip = U.col("#c9c08a")
			hue = 0.16
			sat = 0.35
			count = 5000
			flowers = 0
			blade_h = 0.85
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
	gm.set_shader_parameter("wind_strength", 1.0 if style_key != "tactical" else 0.7)

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
	var bb := Kit.bounds(node)
	var def := _prop_def(key)
	var cols: Variant = def.get("cols", null)
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


func prop_hit(x: float, z: float, y: float) -> bool:
	for p in props:
		var dx: float = x - p.x
		var dz: float = z - p.z
		var s: float = p.s
		if dx * dx + dz * dz > 64.0 * s * s:
			continue
		if y > (p.node as Node3D).position.y + p.h * s - 0.2:
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
	return p.x < 0.5 or p.z < 0.5 or p.x > TN - 0.5 or p.z > TN - 0.5 or prop_hit(p.x, p.z, p.y) or terrain_h(p.x, p.z) < water - 0.45


func free_spot(x: float, z: float, r := 1.2) -> bool:
	if x < 2 or z < 2 or x > TN - 2 or z > TN - 2:
		return false
	if terrain_h(x, z) < water + 0.3:
		return false
	for p in props:
		if Vector2(p.x - x, p.z - z).length() < r + maxf(p.hw, p.hd) * p.s * 0.8:
			return false
	return true


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
	while t < n * 12 and placed < n:
		t += 1
		var a := r.next() * TAU
		var d := r_min + r.next() * (r_max - r_min)
		var x := c + cos(a) * d
		var z := c + sin(a) * d
		if avoid_path and on_path(x, z):
			continue
		if not free_spot(x, z, 1):
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
		_ring_place("house", 5, 10.5, r, 0.4)
		add_prop("well", c, c)
		add_prop("fire", c + 3.5, c + 3)
		add_prop("windmill", c + 13, c + 9, -0.6)
		add_prop("windmill", c - 14, c + 7, 0.5)
		var z := 4.0
		while z < c - 6:
			add_prop("lamp", c - 2, z)
			z += 5
		for w in [[c - 5, c - 8, 0.2], [c + 5, c - 8, -0.2], [c - 8, c - 5, 0.9], [c + 8, c - 5, -0.9]]:
			add_prop("wall", w[0], w[1], w[2])
		add_prop("hay", c + 7, c + 1)
		add_prop("hay", c + 8.2, c + 2.4)
		add_prop("cart", c - 6.5, c + 1.5, 1.2)
		add_prop("bench", c - 3, c - 3, PI * 0.15)
		_scatter_props("oak", 20, 13, 22, r)
		_scatter_props("rocks", 7, 14, 22, r)
		_scatter_props("flowers", 22, 6, 21, r)
		_scatter_props("fence", 6, 12, 16, r)
	elif key == "tactical":
		add_prop("warehouse", c + 8, c + 7, -0.4)
		add_prop("tower", c - 8, c + 8, 0.3)
		add_prop("container", c - 8, c - 4, PI / 2 + 0.1)
		add_prop("container", c + 9, c - 3, 1.4)
		add_prop("tent", c + 3, c + 9, PI)
		add_prop("tent", c - 2, c + 9.5, PI + 0.2)
		for k in 6:
			var a := -PI / 2 + (k - 2.5) * 0.45
			add_prop("sandbags", c + cos(a) * 9.5, c + sin(a) * 9.5, atan2(-cos(a), -sin(a)))
		add_prop("jeep", c + 4.5, c - 4, 0.6)
		for q in [[c - 4, c + 4], [c - 3, c + 4.6], [c + 6, c + 3], [c - 6, c - 7], [c + 2, c - 8]]:
			add_prop("crate", q[0], q[1], r.next() * 2)
		for q in [[c - 5, c + 2], [c + 6.5, c + 1], [c + 7, c + 2], [c - 6, c - 1]]:
			add_prop("barrel", q[0], q[1])
		_scatter_props("pine", 26, 15, 22, r)
		_scatter_props("rock", 12, 10, 22, r)
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
		flatten_at(p.x, p.z, maxf(p.hw, p.hd) * p.s + 0.6, terrain_h(p.x, p.z))
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
		if p.y < terrain_h(p.x, p.z) + 0.3:
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
	return {"h": hs, "path": U.rle_encode(path), "water": water, "props": ps}


## Loads a saved world. Pass `style` to switch style first (props are
## style-specific); otherwise the current `style_key` is used.
func load_data(d: Dictionary, style := "") -> void:
	if style != "":
		style_key = style
	clear_props()
	var src: Array = d.get("h", [])
	for i in mini(src.size(), h.size()):
		h[i] = float(src[i])
	path = U.rle_decode(str(d.get("path", "")), TN * TN)
	water = float(d.get("water", 2.2))
	for e in d.get("props", []):
		if e is Array and e.size() >= 3:
			add_prop(str(e[0]), float(e[1]), float(e[2]), float(e[3]) if e.size() > 3 else 0.0, float(e[4]) if e.size() > 4 else 1.0, int(e[5]) if e.size() > 5 and e[5] != null else -1)
	rebuild()
	rebuild_grass()
