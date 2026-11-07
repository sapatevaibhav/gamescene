class_name Kit
## Procedural mesh and material kit shared by props, characters and creatures.
##
## Mirrors the web build's helpers (box, cyl, cone, ball, prism, cap, torus...)
## so ported builders read the same. Geometry conventions match Three.js:
## primitives are centred on their origin, cones/cylinders run along +Y,
## planes face +Z, tori lie in the XY plane. Every node created here uses XYZ
## Euler order, so `node.rotation = Vector3(x, y, z)` behaves like Three's
## `rotation.set(x, y, z)`.

const TOON := preload("res://src/shaders/toon.gdshader")
const OUTLINE := preload("res://src/shaders/outline.gdshader")
const FLAT := preload("res://src/shaders/flat.gdshader")

## Shading model for new materials: "lambert" (blocky), "toon" (anime),
## "standard" (tactical) or "flat" (low-poly).
static var shade := "lambert"
## Outline thickness used by toon materials created from now on.
static var outline_width := 0.01

static var _mats := {}
static var _meshes := {}


# ---------------------------------------------------------------- materials

## Cached material for a colour. opts: glow (bool, emissive and unlit-looking),
## op (float opacity), side (bool, double sided), rough (float), metal (float).
static func mat(color: Variant, opts: Dictionary = {}) -> Material:
	var c: Color = color if color is Color else U.col(str(color))
	var op: float = opts.get("op", 1.0)
	var key := "%s|%s|%s|%.2f|%s|%.3f|%s|%s" % [shade, c.to_html(), opts.get("glow", false), op, opts.get("side", false), outline_width, opts.get("rough", -1.0), opts.get("metal", -1.0)] + ("s" if opts.get("skin", false) else "") + ("h" if opts.get("hair", false) else "")
	if _mats.has(key):
		return _mats[key]
	var m: Material
	if opts.get("glow", false):
		var g := StandardMaterial3D.new()
		g.albedo_color = c
		g.emission_enabled = true
		g.emission = c
		g.emission_energy_multiplier = 2.2
		g.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m = g
	elif shade == "toon" and op >= 1.0:
		var t := ShaderMaterial.new()
		t.shader = TOON
		t.set_shader_parameter("albedo", c)
		# Shadows are tinted, never grey: skin goes warm rose, the rest cool lilac.
		var tint := Color(0.74, 0.71, 0.88)
		if opts.get("skin", false):
			tint = Color(0.97, 0.74, 0.74)
		elif c.v > 0.85 and c.s < 0.15:
			tint = Color(0.78, 0.8, 0.94)
		t.set_shader_parameter("shadow_tint", tint)
		if opts.get("hair", false):
			t.set_shader_parameter("hair_spec", 0.32)
		if opts.get("metal", -1.0) > 0.3:
			t.set_shader_parameter("spec_amount", 0.8)
			t.set_shader_parameter("rim_amount", 0.5)
		if outline_width > 0.0:
			var ol := ShaderMaterial.new()
			ol.shader = OUTLINE
			ol.set_shader_parameter("color", U.shade(c, 0.34))
			ol.set_shader_parameter("width", outline_width)
			t.next_pass = ol
		m = t
	elif shade == "flat" and op >= 1.0 and not opts.get("side", false):
		var f := ShaderMaterial.new()
		f.shader = FLAT
		f.set_shader_parameter("albedo", c)
		m = f
	else:
		var s := StandardMaterial3D.new()
		s.albedo_color = c
		s.roughness = opts.get("rough", 0.9 if shade == "standard" else 1.0)
		s.metallic = opts.get("metal", 0.02 if shade == "standard" else 0.0)
		if shade == "lambert":
			s.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
			s.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		m = s
	if op < 1.0 and m is StandardMaterial3D:
		var sm := m as StandardMaterial3D
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.albedo_color.a = op
	if opts.get("side", false):
		if m is StandardMaterial3D:
			(m as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


## Unlit textured material (decals, faces, skins).
static func tex_mat(tex: Texture2D, opts: Dictionary = {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST if opts.get("pixel", false) else BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if opts.get("alpha", false):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR if opts.get("scissor", false) else BaseMaterial3D.TRANSPARENCY_ALPHA
		m.alpha_scissor_threshold = 0.5
	if opts.get("unshaded", false):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.roughness = 1.0
	if opts.get("side", false):
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func clear_cache() -> void:
	_mats.clear()


# ---------------------------------------------------------------- nodes

static func group(x := 0.0, y := 0.0, z := 0.0) -> Node3D:
	var n := Node3D.new()
	n.rotation_order = EULER_ORDER_XYZ
	n.position = Vector3(x, y, z)
	return n


static func mi(mesh: Mesh, m: Material, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	var o := MeshInstance3D.new()
	o.rotation_order = EULER_ORDER_XYZ
	o.mesh = mesh
	o.material_override = m
	o.position = Vector3(x, y, z)
	if m is StandardMaterial3D and (m as StandardMaterial3D).shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return o


## Adds `child` to `parent` and returns the child, like the JS `put`.
static func put(parent: Node3D, child: Node3D) -> Node3D:
	parent.add_child(child)
	return child


static func box(w: float, h: float, d: float, m: Material, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	return mi(box_mesh(w, h, d), m, x, y, z)


static func cyl(rt: float, rb: float, h: float, seg: int, m: Material, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	return mi(cyl_mesh(rt, rb, h, seg), m, x, y, z)


static func cone(r: float, h: float, seg: int, m: Material, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	return mi(cyl_mesh(0.0, r, h, seg), m, x, y, z)


## Sphere. Toon style gets a smooth UV sphere; other styles a faceted
## icosphere with `detail` subdivisions (default 1), like the web build.
static func ball(r: float, m: Material, x := 0.0, y := 0.0, z := 0.0, detail := -1) -> MeshInstance3D:
	if shade == "toon":
		return mi(sphere_mesh(r, 16, 12), m, x, y, z)
	return mi(icosa_mesh(r, 1 if detail < 0 else detail), m, x, y, z)


static func sphere(r: float, seg: int, rings: int, m: Material, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	return mi(sphere_mesh(r, seg, rings), m, x, y, z)


## Roof prism: base on y = 0, ridge at y = h running along Z.
static func prism(w: float, h: float, d: float, m: Material, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	return mi(prism_mesh(w, h, d), m, x, y, z)


## Top part of a sphere (Three's SphereGeometry with thetaLength = PI * frac).
static func cap(r: float, seg: int, frac: float, m: Material, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	return mi(cap_mesh(r, seg, frac), m, x, y, z)


static func torus(r: float, tube: float, radial: int, tubular: int, m: Material, arc := TAU, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	return mi(torus_mesh(r, tube, radial, tubular, arc), m, x, y, z)


static func plane(w: float, h: float, m: Material, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	return mi(plane_mesh(w, h), m, x, y, z)


static func dodeca(r: float, m: Material, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	return mi(poly_mesh("dodeca", r), m, x, y, z)


static func octa(r: float, m: Material, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	return mi(poly_mesh("octa", r), m, x, y, z)


static func icosa(r: float, detail: int, m: Material, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	return mi(icosa_mesh(r, detail), m, x, y, z)


## Sets every MeshInstance3D under `n` to cast (or not cast) shadows.
static func shadows(n: Node, on: bool) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		shadows(c, on)


## World-space AABB of all meshes under `n`.
static func bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for m in _meshes_under(n):
		var mi3 := m as MeshInstance3D
		if mi3.mesh == null:
			continue
		var bb: AABB = (n.global_transform.affine_inverse() * mi3.global_transform) * mi3.mesh.get_aabb() if n.is_inside_tree() else _local_xf(n, mi3) * mi3.mesh.get_aabb()
		if first:
			out = bb
			first = false
		else:
			out = out.merge(bb)
	return out


static func _local_xf(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


static func _meshes_under(n: Node) -> Array:
	var out := []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes_under(c))
	return out


# ---------------------------------------------------------------- meshes (cached)

static func box_mesh(w: float, h: float, d: float) -> Mesh:
	var key := "b%.4f,%.4f,%.4f" % [w, h, d]
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = Vector3(w, h, d)
		_meshes[key] = m
	return _meshes[key]


static func cyl_mesh(rt: float, rb: float, h: float, seg: int) -> Mesh:
	var key := "c%.4f,%.4f,%.4f,%d" % [rt, rb, h, seg]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = rt
		m.bottom_radius = rb
		m.height = h
		m.radial_segments = maxi(3, seg)
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


static func sphere_mesh(r: float, seg: int, rings: int) -> Mesh:
	var key := "s%.4f,%d,%d" % [r, seg, rings]
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = seg
		m.rings = rings
		_meshes[key] = m
	return _meshes[key]


static func plane_mesh(w: float, h: float) -> Mesh:
	var key := "p%.4f,%.4f" % [w, h]
	if not _meshes.has(key):
		var m := QuadMesh.new()
		m.size = Vector2(w, h)
		_meshes[key] = m
	return _meshes[key]


static func prism_mesh(w: float, h: float, d: float) -> Mesh:
	var key := "pr%.4f,%.4f,%.4f" % [w, h, d]
	if _meshes.has(key):
		return _meshes[key]
	var a := Vector3(-w / 2, 0, d / 2)
	var b := Vector3(w / 2, 0, d / 2)
	var c := Vector3(0, h, d / 2)
	var a2 := Vector3(-w / 2, 0, -d / 2)
	var b2 := Vector3(w / 2, 0, -d / 2)
	var c2 := Vector3(0, h, -d / 2)
	var tris := [[a, b, c], [b2, a2, c2], [a2, a, c], [a2, c, c2], [b, b2, c2], [b, c2, c], [a, a2, b2], [a, b2, b]]
	var m := _flat_tris(tris)
	_meshes[key] = m
	return m


static func cap_mesh(r: float, seg: int, frac: float) -> Mesh:
	var key := "cap%.4f,%d,%.3f" % [r, seg, frac]
	if _meshes.has(key):
		return _meshes[key]
	var rings := maxi(4, int(seg * 0.6))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var theta_len := PI * frac
	for j in rings + 1:
		var th := theta_len * float(j) / rings
		for i in seg + 1:
			var ph := TAU * float(i) / seg
			var n := Vector3(-cos(ph) * sin(th), cos(th), sin(ph) * sin(th))
			st.set_normal(n)
			st.set_uv(Vector2(float(i) / seg, float(j) / rings))
			st.add_vertex(n * r)
	for j in rings:
		for i in seg:
			var a0 := j * (seg + 1) + i
			var b0 := a0 + seg + 1
			st.add_index(a0)
			st.add_index(a0 + 1)
			st.add_index(b0)
			st.add_index(b0)
			st.add_index(a0 + 1)
			st.add_index(b0 + 1)
	var m := st.commit()
	_set_double_sided_hint(m)
	_meshes[key] = m
	return m


static func torus_mesh(r: float, tube: float, radial: int, tubular: int, arc: float) -> Mesh:
	var key := "t%.4f,%.4f,%d,%d,%.3f" % [r, tube, radial, tubular, arc]
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in radial + 1:
		for i in tubular + 1:
			var u := float(i) / tubular * arc
			var v := float(j) / radial * TAU
			var center := Vector3(r * cos(u), r * sin(u), 0)
			var p := Vector3((r + tube * cos(v)) * cos(u), (r + tube * cos(v)) * sin(u), tube * sin(v))
			st.set_normal((p - center).normalized())
			st.set_uv(Vector2(float(i) / tubular, float(j) / radial))
			st.add_vertex(p)
	for j in range(1, radial + 1):
		for i in range(1, tubular + 1):
			var a0 := (tubular + 1) * j + i - 1
			var b0 := (tubular + 1) * (j - 1) + i - 1
			var c0 := (tubular + 1) * (j - 1) + i
			var d0 := (tubular + 1) * j + i
			st.add_index(a0)
			st.add_index(d0)
			st.add_index(b0)
			st.add_index(b0)
			st.add_index(d0)
			st.add_index(c0)
	var m := st.commit()
	_meshes[key] = m
	return m


static func icosa_mesh(r: float, detail: int) -> Mesh:
	var key := "ico%.4f,%d" % [r, detail]
	if _meshes.has(key):
		return _meshes[key]
	var t := (1.0 + sqrt(5.0)) / 2.0
	var v := [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var f := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var tris := []
	for face in f:
		tris.append([v[face[0]].normalized(), v[face[1]].normalized(), v[face[2]].normalized()])
	for _d in detail:
		var nt := []
		for tri in tris:
			var a: Vector3 = tri[0]
			var b: Vector3 = tri[1]
			var c: Vector3 = tri[2]
			var ab := ((a + b) * 0.5).normalized()
			var bc := ((b + c) * 0.5).normalized()
			var ca := ((c + a) * 0.5).normalized()
			nt.append_array([[a, ab, ca], [b, bc, ab], [c, ca, bc], [ab, bc, ca]])
		tris = nt
	for tri in tris:
		tri[0] *= r
		tri[1] *= r
		tri[2] *= r
	var m := _flat_tris(tris, true)
	_meshes[key] = m
	return m


static func poly_mesh(kind: String, r: float) -> Mesh:
	var key := "%s%.4f" % [kind, r]
	if _meshes.has(key):
		return _meshes[key]
	var tris := []
	if kind == "octa":
		var p := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
		var f := [[0, 2, 4], [0, 4, 3], [0, 3, 5], [0, 5, 2], [1, 2, 5], [1, 5, 3], [1, 3, 4], [1, 4, 2]]
		for face in f:
			tris.append([p[face[0]] * r, p[face[1]] * r, p[face[2]] * r])
	else:
		# Dodecahedron as in Three.js (vertices + 36 triangles).
		var t := (1.0 + sqrt(5.0)) / 2.0
		var q := 1.0 / t
		var p := [Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(-1, 1, -1), Vector3(-1, 1, 1), Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(0, -q, -t), Vector3(0, -q, t), Vector3(0, q, -t), Vector3(0, q, t), Vector3(-q, -t, 0), Vector3(-q, t, 0), Vector3(q, -t, 0), Vector3(q, t, 0), Vector3(-t, 0, -q), Vector3(t, 0, -q), Vector3(-t, 0, q), Vector3(t, 0, q)]
		var idx := [3, 11, 7, 3, 7, 15, 3, 15, 13, 7, 19, 17, 7, 17, 6, 7, 6, 15, 17, 4, 8, 17, 8, 10, 17, 10, 6, 8, 0, 16, 8, 16, 2, 8, 2, 10, 0, 12, 1, 0, 1, 18, 0, 18, 16, 6, 10, 2, 6, 2, 13, 6, 13, 15, 2, 16, 18, 2, 18, 3, 2, 3, 13, 18, 1, 9, 18, 9, 11, 18, 11, 3, 4, 14, 12, 4, 12, 0, 4, 0, 8, 11, 9, 5, 11, 5, 19, 11, 19, 7, 19, 5, 14, 19, 14, 4, 19, 4, 17, 1, 12, 14, 1, 14, 5, 1, 5, 9]
		for i in range(0, idx.size(), 3):
			tris.append([p[idx[i]].normalized() * r, p[idx[i + 1]].normalized() * r, p[idx[i + 2]].normalized() * r])
	var m := _flat_tris(tris, true)
	_meshes[key] = m
	return m


## Builds a flat-shaded mesh from [[a,b,c],...] (counter-clockwise when seen
## from outside, Three.js winding). `outward` re-orients triangles away from
## the origin, which keeps convex solids correct whatever the source winding.
static func _flat_tris(tris: Array, outward := false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in tris:
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		var n := (b - a).cross(c - a).normalized()
		if outward and n.dot((a + b + c) / 3.0) < 0.0:
			var tmp := b
			b = c
			c = tmp
			n = -n
		# Godot front faces are clockwise, Three's counter-clockwise: emit a, c, b.
		for v in [a, c, b]:
			st.set_normal(n)
			st.add_vertex(v)
	return st.commit()


static func _set_double_sided_hint(_m: Mesh) -> void:
	pass


# ---------------------------------------------------------------- batching

## Merges every static MeshInstance3D under `root` into one mesh per material
## (and vertex format), cutting draw calls by 10-50x for procedural props.
## Animated parts listed in the "spin"/"flicker" metas, and anything marked
## with meta "keep", stay separate.
static func merge_static(root: Node3D) -> void:
	var keep := {}
	for key in ["spin", "flicker"]:
		if root.has_meta(key):
			var v: Variant = root.get_meta(key)
			for n in (v if v is Array else [v]):
				if n is Node:
					_mark(n, keep)
	var groups := {}
	_collect(root, root, Transform3D.IDENTITY, keep, groups)
	_emit(root, groups)


## Merges only the direct mesh children of `n` (for rig pivots that move).
static func merge_children(n: Node3D) -> void:
	if n == null:
		return
	var groups := {}
	for c in n.get_children():
		if c is MeshInstance3D and c.get_child_count() == 0 and not c.has_meta("keep"):
			_add(groups, c as MeshInstance3D, (c as MeshInstance3D).transform)
	_emit(n, groups)


static func _mark(n: Node, keep: Dictionary) -> void:
	keep[n] = true
	for c in n.get_children():
		_mark(c, keep)


static func _collect(root: Node3D, n: Node, xf: Transform3D, keep: Dictionary, groups: Dictionary) -> void:
	for c in n.get_children():
		if keep.has(c) or not (c is Node3D):
			continue
		var cx: Transform3D = xf * (c as Node3D).transform
		if c is MeshInstance3D and not c.has_meta("keep") and (c as MeshInstance3D).visible:
			_add(groups, c as MeshInstance3D, cx)
		_collect(root, c, cx, keep, groups)


static func _add(groups: Dictionary, mi3: MeshInstance3D, xf: Transform3D) -> void:
	var mesh := mi3.mesh
	if mesh == null or mi3.material_override == null or mesh.get_surface_count() != 1:
		return
	var fmt := 0
	if mesh is ArrayMesh:
		fmt = (mesh as ArrayMesh).surface_get_format(0) & (Mesh.ARRAY_FORMAT_COLOR | Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_NORMAL)
	else:
		fmt = Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_NORMAL
	var key := "%d|%d|%d" % [mi3.material_override.get_instance_id(), fmt, mi3.cast_shadow]
	if not groups.has(key):
		groups[key] = {"mat": mi3.material_override, "shadow": mi3.cast_shadow, "items": []}
	groups[key]["items"].append([mi3, xf])


static func _emit(root: Node3D, groups: Dictionary) -> void:
	for key in groups:
		var g: Dictionary = groups[key]
		var items: Array = g["items"]
		if items.size() < 2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for it in items:
			st.append_from((it[0] as MeshInstance3D).mesh, 0, it[1])
		var merged := MeshInstance3D.new()
		merged.mesh = st.commit()
		merged.material_override = g["mat"]
		merged.cast_shadow = g["shadow"]
		for it in items:
			var old: MeshInstance3D = it[0]
			old.get_parent().remove_child(old)
			old.queue_free()
		root.add_child(merged)
