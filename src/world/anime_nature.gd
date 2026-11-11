class_name AnimeNature
## Lush stylised nature for the anime fantasy style, built procedurally:
## big broadleaf trees with cloud-like leaf-card canopies, tall forest trees,
## blossom trees, bushes, ferns, mossy boulders, fallen logs, stumps,
## mushrooms and overgrown stone ruins. Also builds the instanced backdrop
## forest that fills the horizon.

const SH_FOLIAGE := preload("res://src/shaders/foliage.gdshader")
const SH_SURFACE := preload("res://src/shaders/anime_surface.gdshader")

const PALETTES := {
	"leaf": {"top": Color(0.62, 0.84, 0.34), "bottom": Color(0.13, 0.36, 0.22), "tint": Color(0.3, 0.5, 0.55)},
	"deep": {"top": Color(0.45, 0.72, 0.3), "bottom": Color(0.08, 0.27, 0.2), "tint": Color(0.26, 0.44, 0.52)},
	"blossom": {"top": Color(1.0, 0.8, 0.88), "bottom": Color(0.86, 0.48, 0.64), "tint": Color(0.72, 0.56, 0.78)},
	"bush": {"top": Color(0.56, 0.8, 0.32), "bottom": Color(0.16, 0.4, 0.2), "tint": Color(0.3, 0.5, 0.55)},
	"fern": {"top": Color(0.5, 0.78, 0.3), "bottom": Color(0.2, 0.45, 0.2), "tint": Color(0.3, 0.52, 0.5)},
}

static var _tex := {}
static var _mats := {}
static var _meshes := {}


# ---------------------------------------------------------------- textures

static func _leaf(img: Image, cx: float, cy: float, ang: float, ln: float, wd: float, shade: float) -> void:
	var ca := cos(ang)
	var sa := sin(ang)
	var ext := int(ln + 2)
	for y in range(int(cy) - ext, int(cy) + ext + 1):
		for x in range(int(cx) - ext, int(cx) + ext + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			var u := dx * ca + dy * sa  # along the leaf, 0..ln
			var v := -dx * sa + dy * ca
			if u < 0.0 or u > ln:
				continue
			var t := u / ln
			var half := wd * pow(sin(PI * clampf(t * 0.92 + 0.04, 0, 1)), 0.75)
			var e := absf(v) / maxf(half, 0.001)
			if e > 1.0:
				continue
			var vein := 1.0 - 0.25 * (1.0 - smoothstep(0.0, 0.12, absf(v) / maxf(wd, 0.001)))
			var edge := 1.0 - 0.18 * smoothstep(0.6, 1.0, e)
			var g := clampf(shade * vein * edge, 0, 1)
			var old := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(g, g, g, 1.0) if old.a < 0.5 or randf() < 0.5 else old)


## Alpha leaf-cluster texture: white leaves, colour comes from the shader.
static func leaf_texture(kind: String) -> Texture2D:
	if _tex.has(kind):
		return _tex[kind]
	var n := 256
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	seed(hash(kind))
	match kind:
		"fern":
			# One frond: a stem with paired leaflets shrinking to the tip.
			for k in 22:
				var t := k / 22.0
				var y := n - 8.0 - t * (n - 16.0)
				var ln := (1.0 - t) * 56.0 + 8.0
				_leaf(img, n / 2.0, y, PI + 0.45, ln, ln * 0.22, 0.95)
				_leaf(img, n / 2.0, y, -0.45, ln, ln * 0.22, 0.95)
			for y in range(8, n - 8):
				img.set_pixel(n / 2, y, Color(0.7, 0.7, 0.7, 1))
		"blossom":
			for k in 34:
				var cx := 30.0 + randf() * (n - 60.0)
				var cy := 30.0 + randf() * (n - 60.0)
				for p in 5:
					_leaf(img, cx, cy, p / 5.0 * TAU + randf() * 0.3, 15.0 + randf() * 5.0, 7.5, 0.9 + randf() * 0.1)
		"single":
			_leaf(img, 12.0, n / 2.0, 0.0, n - 24.0, n * 0.3, 1.0)
		_:
			for k in 46:
				var a := randf() * TAU
				var d := sqrt(randf()) * n * 0.36
				var cx := n / 2.0 + cos(a) * d
				var cy := n / 2.0 + sin(a) * d
				_leaf(img, cx, cy, a + randf() * 1.2 - 0.6, 26.0 + randf() * 16.0, 9.0 + randf() * 3.0, 0.78 + randf() * 0.22)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[kind] = t
	return t


## Painted clump of grass blades (white, alpha cut-out; shader colours it).
static func grass_texture(tall := false) -> Texture2D:
	var key := "grass_tall" if tall else "grass"
	if _tex.has(key):
		return _tex[key]
	var w := 128
	var h := 128 if tall else 96
	var img := Image.create(w, h, true, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	seed(31337 + (7 if tall else 0))
	for k in (9 if tall else 15):
		var bx := 10.0 + randf() * (w - 20.0)
		var bh := h * ((0.6 + randf() * 0.4) if tall else (0.4 + randf() * 0.55))
		var bw := (2.4 + randf() * 1.6) if tall else (3.5 + randf() * 2.5)
		var lean := (randf() - 0.5) * (40.0 if tall else 26.0)
		for y in range(int(h - bh), h):
			var t := float(h - y) / bh  # 0 at ground, 1 at tip
			var cx := bx + lean * t * t
			var half := bw * (1.0 - t)
			for x in range(int(cx - half - 1), int(cx + half + 2)):
				if x < 0 or x >= w:
					continue
				var a := clampf(half - absf(x + 0.5 - cx) + 0.5, 0, 1)
				if a <= 0.0:
					continue
				var g := 0.8 + 0.2 * t
				img.set_pixel(x, y, Color(g, g, g, a))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex


## A few stems with five-petal flower heads (coloured per instance).
static func flower_texture() -> Texture2D:
	if _tex.has("flower"):
		return _tex["flower"]
	var w := 64
	var h := 64
	var img := Image.create(w, h, true, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	seed(4242)
	for k in 3:
		var fx := 12.0 + randf() * 40.0
		var fy := 10.0 + randf() * 22.0
		for y in range(int(fy), h):
			for dx in [-1, 0]:
				img.set_pixel(clampi(int(fx) + dx, 0, w - 1), y, Color(0.35, 0.62, 0.3, 1))
		for p in 5:
			var a := p / 5.0 * TAU
			var px := fx + cos(a) * 4.5
			var py := fy + sin(a) * 4.5
			for y in range(int(py - 4), int(py + 5)):
				for x in range(int(px - 4), int(px + 5)):
					if x >= 0 and y >= 0 and x < w and y < h and Vector2(x - px, y - py).length() < 3.6:
						img.set_pixel(x, y, Color(1, 1, 1, 1))
		for y in range(int(fy - 2), int(fy + 3)):
			for x in range(int(fx - 2), int(fx + 3)):
				if x >= 0 and y >= 0 and x < w and y < h:
					img.set_pixel(x, y, Color(1.0, 0.85, 0.3, 1))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_tex["flower"] = tex
	return tex


static func foliage_mat(pal: String, tex := "leaf") -> ShaderMaterial:
	var key := pal + "|" + tex
	if _mats.has(key):
		return _mats[key]
	var p: Dictionary = PALETTES[pal]
	var m := ShaderMaterial.new()
	m.shader = SH_FOLIAGE
	m.set_shader_parameter("leaf_tex", leaf_texture(tex))
	m.set_shader_parameter("top_color", p["top"])
	m.set_shader_parameter("bottom_color", p["bottom"])
	m.set_shader_parameter("shadow_tint", p["tint"])
	m.set_shader_parameter("wind", 0.03 if tex == "fern" else 0.06)
	_mats[key] = m
	return m


static func surface_mat(kind: String) -> ShaderMaterial:
	if _mats.has(kind):
		return _mats[kind]
	var m := ShaderMaterial.new()
	m.shader = SH_SURFACE
	match kind:
		"bark":
			m.set_shader_parameter("albedo", Color(0.45, 0.33, 0.24))
			m.set_shader_parameter("albedo2", Color(0.3, 0.22, 0.17))
			m.set_shader_parameter("shadow_tint", Color(0.5, 0.45, 0.62))
			m.set_shader_parameter("grooves", 1.0)
			m.set_shader_parameter("moss", 0.35)
			m.set_shader_parameter("detail_scale", 2.2)
		"birch":
			m.set_shader_parameter("albedo", Color(0.9, 0.88, 0.82))
			m.set_shader_parameter("albedo2", Color(0.55, 0.52, 0.5))
			m.set_shader_parameter("grooves", 0.6)
			m.set_shader_parameter("detail_scale", 3.0)
		"rock":
			m.set_shader_parameter("albedo", Color(0.7, 0.69, 0.66))
			m.set_shader_parameter("albedo2", Color(0.55, 0.55, 0.56))
			m.set_shader_parameter("shadow_tint", Color(0.66, 0.68, 0.8))
			m.set_shader_parameter("moss", 0.9)
			m.set_shader_parameter("detail_scale", 0.9)
		"ruin":
			m.set_shader_parameter("albedo", Color(0.82, 0.8, 0.72))
			m.set_shader_parameter("albedo2", Color(0.62, 0.62, 0.58))
			m.set_shader_parameter("moss", 0.7)
			m.set_shader_parameter("detail_scale", 1.4)
		"wood":
			m.set_shader_parameter("albedo", Color(0.62, 0.45, 0.3))
			m.set_shader_parameter("albedo2", Color(0.45, 0.32, 0.22))
			m.set_shader_parameter("moss", 0.5)
			m.set_shader_parameter("detail_scale", 2.5)
	_mats[kind] = m
	return m


# ---------------------------------------------------------------- meshes

## A leaf-card canopy: `cards` quads inside an ellipsoid, normals pointing
## out from the centre so the clump shades like one soft volume.
static func canopy_mesh(radii: Vector3, cards: int, card: float, seed: int) -> ArrayMesh:
	var key := "can%s|%d|%.2f|%d" % [radii, cards, card, seed]
	if _meshes.has(key):
		return _meshes[key]
	var r := U.rng(seed)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in cards:
		# Bias towards the surface so the silhouette is full and puffy.
		var dir := Vector3(r.next() * 2 - 1, r.next() * 2 - 1, r.next() * 2 - 1)
		if dir.length() < 0.05:
			dir = Vector3.UP
		dir = dir.normalized()
		var rad := pow(r.next(), 0.35)
		var p := dir * radii * rad
		var nrm := (p / (radii * radii)).normalized()
		if nrm.length() < 0.1:
			nrm = dir
		# Card faces mostly outward with some random twist.
		var fwd := (nrm + Vector3(r.next() - 0.5, r.next() - 0.5, r.next() - 0.5) * 1.1).normalized()
		var up := Vector3.UP if absf(fwd.y) < 0.95 else Vector3.RIGHT
		var u := fwd.cross(up).normalized()
		var v := u.cross(fwd).normalized()
		var rot := r.next() * TAU
		var u2 := u * cos(rot) + v * sin(rot)
		var v2 := -u * sin(rot) + v * cos(rot)
		var s := card * (0.75 + r.next() * 0.5)
		var hgt := clampf(0.5 + 0.5 * p.y / radii.y, 0, 1) * 0.7 + rad * 0.3
		var col := Color(r.next(), hgt, 0, 1)
		var c := [p - u2 * s - v2 * s, p + u2 * s - v2 * s, p - u2 * s + v2 * s, p + u2 * s + v2 * s]
		var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(0, 0), Vector2(1, 0)]
		for idx in [0, 1, 2, 2, 1, 3]:
			st.set_color(col)
			st.set_normal(nrm)
			st.set_uv(uv[idx])
			st.add_vertex(c[idx])
	var m := st.commit()
	_meshes[key] = m
	return m


## Tube along `pts` with per-point radius (trunks, branches, roots).
static func tube(pts: Array, radii: Array, seg := 10) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tube_into(st, pts, radii, seg)
	return st.commit()


static func _tube_into(st: SurfaceTool, pts: Array, radii: Array, seg: int) -> void:
	var rings := []
	var n := pts.size()
	for i in n:
		var a: Vector3 = pts[i]
		var t: Vector3 = ((pts[mini(i + 1, n - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
		var x := t.cross(Vector3.FORWARD if absf(t.z) < 0.9 else Vector3.RIGHT).normalized()
		var z := x.cross(t).normalized()
		var ring := []
		for k in seg + 1:
			var ang := float(k) / seg * TAU
			var nrm := (x * cos(ang) + z * sin(ang)).normalized()
			ring.append([a + nrm * float(radii[i]), nrm, Vector2(float(k) / seg, float(i) / (n - 1))])
		rings.append(ring)
	for i in n - 1:
		for k in seg:
			var A: Array = rings[i][k]
			var B: Array = rings[i][k + 1]
			var C: Array = rings[i + 1][k]
			var D: Array = rings[i + 1][k + 1]
			for q in [A, B, D, A, D, C]:
				st.set_normal(q[1])
				st.set_uv(q[2])
				st.add_vertex(q[0])
	# Make sure faces point outward whatever the frame handedness.
	return


static func _bent(from: Vector3, to: Vector3, bend: Vector3, steps: int) -> Array:
	var out := []
	for i in steps + 1:
		var t := float(i) / steps
		out.append(from.lerp(to, t) + bend * sin(t * PI) )
	return out


## Smooth, lumpy boulder.
static func rock_mesh(seed: int, size: Vector3) -> ArrayMesh:
	var key := "rock%d%s" % [seed, size]
	if _meshes.has(key):
		return _meshes[key]
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 28
	sm.rings = 16
	var arr := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var fn := FastNoiseLite.new()
	fn.seed = seed
	fn.frequency = 0.9
	for i in verts.size():
		var v := verts[i]
		var d := 1.0 + fn.get_noise_3dv(v * 1.3) * 0.32 + fn.get_noise_3dv(v * 3.1) * 0.08
		v = v * d
		# Flatter bottom and slightly faceted top like hand-sculpted stones.
		if v.y < -0.3:
			v.y = lerpf(v.y, -0.3, 0.6)
		verts[i] = v * size
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in verts.size():
		st.add_vertex(verts[i])
	for i in idx:
		st.add_index(i)
	st.generate_normals()
	var m := st.commit()
	_meshes[key] = m
	return m


# ---------------------------------------------------------------- builders

static func _mi(mesh: Mesh, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	return m


static func _canopy(g: Node3D, pal: String, pos: Vector3, radii: Vector3, density: float, r: U.Rng, tex := "leaf") -> void:
	# Phones: fewer, slightly bigger leaf cards (the cut-out leaves are drawn
	# over each other many times, which slow phone GPUs pay for per pixel).
	var lite := App.lite_shading()
	var cards := int(clampf(radii.x * radii.y * radii.z * 17.0 * density * (0.35 if lite else 1.0), 14 if lite else 30, 240))
	var variant := int(r.next() * 4)
	var m := _mi(canopy_mesh(radii, cards, (0.85 if tex == "leaf" else 0.7) * (1.25 if lite else 1.0), variant * 97 + int(radii.x * 10)), foliage_mat(pal, tex), pos)
	# Only tree crowns cast shadows; low undergrowth isn't worth the cost.
	if radii.y < 1.0:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.rotation.y = r.next() * TAU
	g.add_child(m)


## Big broadleaf tree with root flares, a few limbs and cloud canopies.
static func broadleaf(r: U.Rng, pal := "leaf", tall := false) -> Node3D:
	var g := Kit.group()
	var h := (6.5 + r.next() * 2.0) * (1.35 if tall else 1.0)
	var base := 0.34 + r.next() * 0.1
	var lean := Vector3(r.next() - 0.5, 0, r.next() - 0.5) * 0.6
	var top := Vector3(lean.x, h * 0.72, lean.z)
	var bark := surface_mat("bark")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := _bent(Vector3.ZERO + Vector3(0, -0.3, 0), top, Vector3(r.next() - 0.5, 0, r.next() - 0.5) * 0.5, 7)
	var rads := []
	for i in trunk.size():
		var t := float(i) / (trunk.size() - 1)
		rads.append(lerpf(base * 1.35, base * 0.45, pow(t, 0.8)))
	_tube_into(st, trunk, rads, 12)
	# Root flares.
	var nroots := 4 + int(r.next() * 3)
	for k in nroots:
		var a := k / float(nroots) * TAU + r.next() * 0.5
		var out := Vector3(cos(a), 0, sin(a))
		_tube_into(st, [Vector3(0, 0.9, 0) + out * base * 0.3, out * (base + 0.45) + Vector3(0, 0.1, 0), out * (base + 0.95) + Vector3(0, -0.25, 0)], [base * 0.5, base * 0.32, 0.04], 8)
	# Limbs carrying side canopies.
	var limbs := []
	var nl := 3 + int(r.next() * 2)
	for k in nl:
		var a := k / float(nl) * TAU + r.next() * 0.8
		var y0 := h * (0.42 + r.next() * 0.22)
		var start := Vector3(lean.x * y0 / h, y0, lean.z * y0 / h)
		var end := start + Vector3(cos(a) * (1.6 + r.next()), 1.1 + r.next() * 1.2, sin(a) * (1.6 + r.next()))
		_tube_into(st, _bent(start, end, Vector3(0, 0.35, 0), 4), [base * 0.42, base * 0.32, base * 0.24, base * 0.18, base * 0.12], 8)
		limbs.append(end)
	g.add_child(_mi(st.commit(), bark))
	# Canopy: a big crown plus clumps at the limb ends.
	var crown := Vector3(2.6, 1.9, 2.6) * (0.9 + r.next() * 0.25) * (0.8 if tall else 1.0)
	_canopy(g, pal, top + Vector3(0, crown.y * 0.55, 0), crown, 1.0, r)
	for e in limbs:
		var cr := Vector3(1.6, 1.25, 1.6) * (0.8 + r.next() * 0.4)
		_canopy(g, pal, e + Vector3(0, 0.35, 0), cr, 1.0, r)
	if r.next() < 0.6:
		_canopy(g, pal, top + Vector3(r.next() - 0.5, crown.y * 1.2, r.next() - 0.5), crown * 0.6, 1.0, r)
	return g


static func blossom(r: U.Rng) -> Node3D:
	var g := broadleaf(r, "blossom")
	g.scale = Vector3.ONE * 0.75
	return g


static func bush(r: U.Rng, pal := "bush") -> Node3D:
	var g := Kit.group()
	var n := 2 + int(r.next() * 3)
	for k in n:
		var a := r.next() * TAU
		var d := r.next() * 0.6
		var rad := Vector3(0.9, 0.7, 0.9) * (0.7 + r.next() * 0.5)
		_canopy(g, pal, Vector3(cos(a) * d, rad.y * 0.75, sin(a) * d), rad, 1.0, r)
	if r.next() < 0.35:
		# A few flowers poking out.
		var fc: String = ["#ffffff", "#ffe066", "#ff9ec4", "#c9a2ff"][int(r.next() * 4)]
		Kit.shade = "toon"
		for k in 6:
			var a := r.next() * TAU
			g.add_child(Kit.ball(0.07, Kit.mat(fc), cos(a) * 0.8, 0.9 + r.next() * 0.4, sin(a) * 0.8))
	return g


static func fern(r: U.Rng) -> Node3D:
	var g := Kit.group()
	var mat := foliage_mat("fern", "fern")
	var n := 6 + int(r.next() * 5)
	for k in n:
		var a := k / float(n) * TAU + r.next() * 0.4
		var ln := 0.9 + r.next() * 0.5
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Arched frond strip.
		var segs := 5
		var prev := []
		for i in segs + 1:
			var t := float(i) / segs
			var w := 0.22 * ln
			var p := Vector3(0, sin(t * PI * 0.7) * 0.55 * ln, t * ln)
			var row := [p + Vector3(-w, 0, 0), p + Vector3(w, 0, 0)]
			if i > 0:
				var quad := [prev[0], prev[1], row[0], row[1]]
				var uvs := [Vector2(0, 1.0 - (t - 1.0 / segs)), Vector2(1, 1.0 - (t - 1.0 / segs)), Vector2(0, 1.0 - t), Vector2(1, 1.0 - t)]
				for idx in [0, 1, 2, 2, 1, 3]:
					st.set_color(Color(r.next() * 0.3 + 0.35, t, 0, 1))
					st.set_normal(Vector3.UP)
					st.set_uv(uvs[idx])
					st.add_vertex(quad[idx])
			prev = row
		var m := _mi(st.commit(), mat)
		m.rotation.y = a
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(m)
	return g


static func boulder(r: U.Rng, big := false) -> Node3D:
	var g := Kit.group()
	var n := 1 + int(r.next() * (3 if big else 2))
	for k in n:
		var s := (1.0 + r.next() * 0.8) * (1.15 if big else 0.6)
		var size := Vector3(s * (0.9 + r.next() * 0.4), s * (0.55 + r.next() * 0.35), s * (0.8 + r.next() * 0.4))
		var m := _mi(rock_mesh(int(r.next() * 9), size), surface_mat("rock"), Vector3((r.next() - 0.5) * s, size.y * 0.35, (r.next() - 0.5) * s))
		m.rotation = Vector3(r.next() * 0.3, r.next() * TAU, r.next() * 0.3)
		g.add_child(m)
	return g


static func log_prop(r: U.Rng) -> Node3D:
	var g := Kit.group()
	var ln := 3.0 + r.next() * 2.0
	var rad := 0.32 + r.next() * 0.12
	var pts := _bent(Vector3(-ln / 2, rad, 0), Vector3(ln / 2, rad * 0.9, 0), Vector3(0, 0.1, 0.25), 6)
	var rads := []
	for i in pts.size():
		rads.append(rad * (1.0 - 0.15 * float(i) / pts.size()))
	g.add_child(_mi(tube(pts, rads, 12), surface_mat("bark")))
	Kit.shade = "toon"
	var end_m := Kit.mat("#c9a273")
	for s in [-1.0, 1.0]:
		var cap := Kit.cyl(rad * 0.95, rad * 0.95, 0.03, 16, end_m, s * ln / 2, rad, 0)
		cap.rotation.z = PI / 2
		g.add_child(cap)
	# Mushrooms growing on it.
	if r.next() < 0.7:
		for k in 3:
			var cap2 := Kit.cap(0.09, 12, 0.5, Kit.mat("#f2e6cf"), (r.next() - 0.5) * ln * 0.7, rad * 1.8, rad * 0.7)
			cap2.scale = Vector3(1, 0.5, 1)
			g.add_child(cap2)
	return g


static func stump(r: U.Rng) -> Node3D:
	var g := Kit.group()
	var rad := 0.45 + r.next() * 0.2
	g.add_child(_mi(tube([Vector3(0, -0.2, 0), Vector3(0, 0.35, 0), Vector3(0, 0.62, 0)], [rad * 1.3, rad, rad * 0.95], 14), surface_mat("bark")))
	Kit.shade = "toon"
	g.add_child(Kit.cyl(rad * 0.93, rad * 0.93, 0.03, 18, Kit.mat("#c9a273"), 0, 0.62, 0))
	return g


static func mushrooms(r: U.Rng) -> Node3D:
	var g := Kit.group()
	Kit.shade = "toon"
	var red := r.next() < 0.5
	var cap_m := Kit.mat("#d8473f" if red else "#e8b45a")
	var stem_m := Kit.mat("#f4ead8")
	var dot_m := Kit.mat("#fff8ee")
	for k in 3 + int(r.next() * 4):
		var a := r.next() * TAU
		var d := r.next() * 0.45
		var s := 0.6 + r.next() * 0.8
		var x := cos(a) * d
		var z := sin(a) * d
		g.add_child(Kit.cyl(0.035 * s, 0.05 * s, 0.22 * s, 10, stem_m, x, 0.11 * s, z))
		var cap := Kit.cap(0.13 * s, 16, 0.5, cap_m, x, 0.2 * s, z)
		cap.scale = Vector3(1, 0.7, 1)
		g.add_child(cap)
		if red:
			for q in 4:
				var b := r.next() * TAU
				g.add_child(Kit.ball(0.018 * s, dot_m, x + cos(b) * 0.08 * s, 0.26 * s, z + sin(b) * 0.08 * s))
	return g


## Overgrown stone pillar, optionally broken.
static func ruin_pillar(r: U.Rng) -> Node3D:
	var g := Kit.group()
	var stone := surface_mat("ruin")
	var hgt := 2.6 + r.next() * 2.4
	if r.next() < 0.4:
		hgt *= 0.5
	g.add_child(_mi(Kit.box_mesh(1.1, 0.35, 1.1), stone, Vector3(0, 0.17, 0)))
	var drums := int(hgt / 0.7)
	for k in drums:
		var d := _mi(Kit.cyl_mesh(0.36, 0.38, 0.68, 16), stone, Vector3((r.next() - 0.5) * 0.04, 0.35 + 0.34 + k * 0.7, (r.next() - 0.5) * 0.04))
		d.rotation.y = r.next()
		g.add_child(d)
	if hgt > 3.5:
		g.add_child(_mi(Kit.box_mesh(0.95, 0.28, 0.95), stone, Vector3(0, 0.35 + drums * 0.7 + 0.14, 0)))
	else:
		# Fallen drum lying beside it.
		var f := _mi(Kit.cyl_mesh(0.36, 0.38, 0.68, 16), stone, Vector3(1.1, 0.36, 0.3))
		f.rotation = Vector3(0, r.next(), PI / 2)
		g.add_child(f)
	# Ivy: small leaf clumps climbing the pillar.
	for k in 3:
		_canopy(g, "deep", Vector3((r.next() - 0.5) * 0.6, 0.5 + r.next() * hgt * 0.8, 0.35), Vector3(0.35, 0.5, 0.25), 1.4, r)
	return g


## Ancient arch with a glowing keystone rune.
static func ruin_arch(r: U.Rng) -> Node3D:
	var g := Kit.group()
	var stone := surface_mat("ruin")
	for s in [-1.0, 1.0]:
		g.add_child(_mi(Kit.box_mesh(0.9, 3.6, 0.9), stone, Vector3(s * 1.7, 1.8, 0)))
		g.add_child(_mi(Kit.box_mesh(1.1, 0.3, 1.1), stone, Vector3(s * 1.7, 0.15, 0)))
	var pts := []
	var rads := []
	for i in 9:
		var a := PI - i / 8.0 * PI
		pts.append(Vector3(cos(a) * 1.7, 3.6 + sin(a) * 1.3, 0))
		rads.append(0.38)
	g.add_child(_mi(tube(pts, rads, 8), stone))
	Kit.shade = "toon"
	var rune := Kit.octa(0.22, Kit.mat("#7fe3ff", {"glow": true}), 0, 4.9, 0.3)
	rune.scale = Vector3(1, 1.4, 0.4)
	g.add_child(rune)
	var l := OmniLight3D.new()
	l.light_color = Color("7fe3ff")
	l.light_energy = 1.2
	l.omni_range = 5.0
	l.position = Vector3(0, 4.7, 0.6)
	g.add_child(l)
	g.set_meta("light", l)
	_canopy(g, "deep", Vector3(-1.6, 3.9, 0), Vector3(0.7, 0.6, 0.6), 1.3, r)
	_canopy(g, "deep", Vector3(1.9, 1.0, 0.3), Vector3(0.5, 0.8, 0.5), 1.3, r)
	return g


## Instanced low-cost tree for the horizon forest (trunk + crown surfaces).
static func backdrop_tree_mesh(variant: int) -> ArrayMesh:
	var key := "bd%d" % variant
	if _meshes.has(key):
		return _meshes[key]
	var r := U.rng(900 + variant)
	var mesh := ArrayMesh.new()
	var h := 7.0 + variant * 1.5
	var trunk := tube([Vector3(0, -0.5, 0), Vector3(0, h * 0.5, 0), Vector3(0, h * 0.8, 0)], [0.45, 0.32, 0.22], 6)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, trunk.surface_get_arrays(0))
	mesh.surface_set_material(0, surface_mat("bark"))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var c := canopy_mesh(Vector3(3.0, 2.4, 3.0) * (1.0 - k * 0.18), 26, 1.7, 500 + variant * 7 + k)
		var xf := Transform3D(Basis.IDENTITY, Vector3((r.next() - 0.5) * 1.5, h * 0.82 + k * 1.6, (r.next() - 0.5) * 1.5))
		st.append_from(c, 0, xf)
	var crown := st.commit()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, crown.surface_get_arrays(0))
	mesh.surface_set_material(1, foliage_mat("deep" if variant % 2 == 0 else "leaf"))
	_meshes[key] = mesh
	return mesh
