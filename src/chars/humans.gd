class_name Humans
## Styled humanoids: anime (cel-shaded) and low-poly, plus the
## anime creatures (slime, wisp, wolf). Ported from the web build.

static var _decals := {}


static func M(color: String, opts: Dictionary = {}) -> Material:
	return Kit.mat(color, opts)


static func _cap(r: float, ln: float, m: Material, x := 0.0, y := 0.0, z := 0.0, seg := 12) -> MeshInstance3D:
	return Kit.mi(CharMesh.capsule(r, ln, seg), m, x, y, z)


static func _sph(r: float, ws: int, hs: int, m: Material, x := 0.0, y := 0.0, z := 0.0) -> MeshInstance3D:
	return Kit.mi(Kit.sphere_mesh(r, ws, hs), m, x, y, z)


static func _torus(r: float, tube: float, rs: int, ts: int, m: Material, arc := TAU) -> MeshInstance3D:
	return Kit.mi(CharMesh.torus(r, tube, rs, ts, arc), m)


## Hemisphere-like cap, Three's capGeo(r, seg, frac).
static func _capgeo(r: float, seg: int, frac: float, m: Material) -> MeshInstance3D:
	return Kit.mi(CharMesh.sphere_part(r, seg, maxi(4, int(seg * 0.6)), PI * frac), m)


static func _q_from(v: Vector3, from := Vector3(0, 0, 1)) -> Quaternion:
	return Quaternion(from, v.normalized())


# ---------------------------------------------------------------- decals

static func _decal_mat(key: String, img: Image, blend := false) -> StandardMaterial3D:
	if _decals.has(key):
		return _decals[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = Painter.tex(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if blend:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.render_priority = 2
	else:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.2
		m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
		m.render_priority = 1
	_decals[key] = m
	return m


static func _decal_node(w: float, h: float, mat: Material) -> MeshInstance3D:
	var p := Kit.plane(w, h, mat)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Old-style eye (JS eyeMat) for the low-poly people.
static func eye_mat(kind: String, color: String) -> Material:
	var key := "eye" + kind + color
	if _decals.has(key):
		return _decals[key]
	var img := Painter.new_img(64, 80)
	Painter.ellipse(img, 32, 44, 14, 22, U.col("#1c1a22"))
	Painter.circle(img, 27, 36, 5, Color.WHITE)
	return _decal_mat(key, img)


static func mouth_mat(kind: String) -> Material:
	var key := "mouth" + kind
	if _decals.has(key):
		return _decals[key]
	var img := Painter.new_img(64, 32)
	Painter.stroke(img, Painter.arc_pts(32, 2, 16, 16, PI * 0.25, PI * 0.75), 5, U.col("#8a3a44" if kind == "anime" else "#5a2e28"))
	return _decal_mat(key, img)


## Anime face textures (JS animeTex): eye, brow, blush, mouth.
static func anime_tex(kind: String, a: String) -> Material:
	var key := "a" + kind + a
	if _decals.has(key):
		return _decals[key]
	var img: Image
	if kind == "eye":
		img = Painter.new_img(64, 96)
		Painter.ellipse(img, 32, 52, 22, 32, U.col("#fbf8f6"))
		var stops := [[0.0, U.col(U.shade_hex(a, 0.32))], [0.55, U.col(a)], [1.0, U.col(U.shade_hex(a, 1.35))]]
		Painter.ellipse(img, 32, 56, 17, 27, Color.WHITE, 0.0, [22, 86, stops])
		Painter.ellipse(img, 32, 58, 7, 12, U.col(U.shade_hex(a, 0.22)))
		Painter.ellipse(img, 24, 42, 6, 8, Color(1, 1, 1, 0.95), -0.3)
		Painter.circle(img, 40, 72, 3.2, Color(1, 1, 1, 0.95))
		Painter.stroke(img, Painter.arc_pts(32, 52, 24, 33, PI * 1.1, PI * 1.95), 8, U.col("#1e1424"))
		Painter.stroke(img, PackedVector2Array([Vector2(54, 34), Vector2(62, 28)]), 5, U.col("#1e1424"))
		Painter.stroke(img, Painter.arc_pts(32, 54, 21, 30, PI * 0.25, PI * 0.75), 2.5, Color(60 / 255.0, 30 / 255.0, 40 / 255.0, 0.55))
	elif kind == "brow":
		img = Painter.new_img(64, 16)
		Painter.stroke(img, Painter.quad_pts(Vector2(6, 12), Vector2(30, 2), Vector2(58, 9)), 5, U.col(a))
	elif kind == "blush":
		img = Painter.new_img(64, 32)
		Painter.radial(img, 32, 16, 2, 28, [[0.0, Color(1, 120 / 255.0, 140 / 255.0, 0.55)], [1.0, Color(1, 120 / 255.0, 140 / 255.0, 0.0)]])
	else:
		img = Painter.new_img(64, 32)
		Painter.stroke(img, Painter.quad_pts(Vector2(22, 12), Vector2(32, 20), Vector2(42, 12)), 4, U.col("#9a4250"))
	return _decal_mat(key, img, kind == "blush")


## Decal on an ellipsoidal head (JS decal).
static func decal(hc: Node3D, mat: Material, r: float, sc: Array, dir: Array, w: float, h: float) -> MeshInstance3D:
	var d := Vector3(dir[0], dir[1], dir[2]).normalized()
	var p := _decal_node(w, h, mat)
	p.position = Vector3(d.x * r * sc[0] * 1.012, d.y * r * sc[1] * 1.012, d.z * r * sc[2] * 1.012)
	p.quaternion = _q_from(d)
	hc.add_child(p)
	return p


## Decal hugging the anime head (JS faceDecal).
static func face_decal(hc: Node3D, mat: Material, x: float, y: float, r: float, w: float, h: float, tilt := 0.0) -> MeshInstance3D:
	var zz := sqrt(maxf(0.0001, r * r - x * x - y * y)) * 1.03 + 0.003
	var p := _decal_node(w, h, mat)
	p.position = Vector3(x * 0.96, y * (1.1 if y < 0.0 else 1.0), zz)
	var d := Vector3(p.position.x * 0.7, p.position.y * 0.4, p.position.z)
	p.quaternion = _q_from(d) * Quaternion(Vector3(0, 0, 1), tilt)
	hc.add_child(p)
	return p


# ---------------------------------------------------------------- humanoid

## Generic segmented humanoid used by low-poly (JS humanoid).
static func humanoid(p: Dictionary) -> Dictionary:
	var root := Kit.group()
	var model := Kit.group()
	root.add_child(model)
	var seg: int = p["seg"]
	var legs := []
	var arms := []
	var leg_len: float = p["legLen"]
	var boot_h: float = p["bootH"]
	var leg_w: float = p["legW"]
	for side in [-1.0, 1.0]:
		var pv := Kit.group(side * float(p["legX"]), p["hip"], 0)
		model.add_child(pv)
		var pl := leg_len - boot_h
		pv.add_child(Kit.cyl(leg_w, leg_w * 0.86, pl, seg, p["mPants"], 0, -pl / 2.0, 0))
		pv.add_child(Kit.cyl(leg_w * 1.06, leg_w * 1.12, boot_h, seg, p["mShoes"], 0, -pl - boot_h / 2.0, leg_w * 0.18))
		legs.append(pv)
	var upper := Kit.group(0, p["hip"], 0)
	model.add_child(upper)
	var tw: float = p["torsoW"]
	var th: float = p["torsoH"]
	var td: float = p["torsoD"]
	var chest: float = p["chest"]
	var waist: float = p["waist"]
	var torso: MeshInstance3D
	if p.get("torsoBox", false):
		torso = Kit.box(tw, th, td, p["mShirt"])
	else:
		torso = Kit.cyl(tw / 2.0 * chest, tw / 2.0 * waist, th, seg + 2, p["mShirt"])
		torso.scale.z = td / tw
	torso.position.y = th / 2.0
	upper.add_child(torso)
	var belt := Kit.cyl(tw / 2.0 * waist * 1.02, tw / 2.0 * waist * 0.98, 0.1, seg + 2, p["mPants"], 0, -0.02, 0)
	belt.scale.z = td / tw
	upper.add_child(belt)
	var neck: float = p["neck"]
	var head_r: float = p["headR"]
	var lift: float = p["headLift"]
	var head := Kit.group(0, th + neck, 0)
	upper.add_child(head)
	head.add_child(Kit.cyl(head_r * 0.36, head_r * 0.42, neck + 0.06, seg, p["mSkin"], 0, -neck / 2.0, 0))
	var head_geo: Callable = p["headGeo"]
	var hm: Node3D = head_geo.call(p)
	hm.position.y = head_r * lift
	head.add_child(hm)
	var hc := Kit.group(0, head_r * lift, 0)
	head.add_child(hc)
	var half := tw / 2.0 if p.get("torsoBox", false) else tw / 2.0 * chest
	var arm_w: float = p["armW"]
	var arm_len: float = p["armLen"]
	for side in [-1.0, 1.0]:
		var pv := Kit.group(side * (half + arm_w * 0.85), th - arm_w * 0.7, 0)
		upper.add_child(pv)
		pv.add_child(Kit.ball(arm_w * 1.15, p["mShirt"]))
		var sl: float = arm_len * float(p["sleeve"])
		var fl := arm_len - sl
		if sl > 0.01:
			pv.add_child(Kit.cyl(arm_w * 1.08, arm_w, sl, seg, p["mShirt"], 0, -sl / 2.0, 0))
		if fl > 0.01:
			pv.add_child(Kit.cyl(arm_w * 0.95, arm_w * 0.82, fl, seg, p.get("mArm", p["mSkin"]), 0, -sl - fl / 2.0, 0))
		pv.add_child(Kit.ball(arm_w * 1.05, p.get("mHand", p["mSkin"]), 0, -arm_len - arm_w * 0.3, 0))
		arms.append(pv)
	var head_h: float = float(p["hip"]) + th + neck + head_r * lift
	return {"root": root, "model": model, "upper": upper, "head": head, "hc": hc, "torso": torso, "armR": arms[0], "armL": arms[1], "legR": legs[0], "legL": legs[1],
		"headH": head_h, "height": head_h + head_r * 1.15, "sitDrop": float(p["hip"]) - leg_w * 1.1, "kind": "human"}


# ---------------------------------------------------------------- anime

static func _strand(hc: Node3D, m: Material, x: float, y: float, z: float, ln: float, w: float, dir: Array) -> MeshInstance3D:
	var c := Kit.cone(w, ln, 12, m)
	var d := Vector3(dir[0], dir[1], dir[2]).normalized()
	c.quaternion = _q_from(d, Vector3(0, -1, 0))
	c.position = Vector3(x + d.x * ln / 2.0, y + d.y * ln / 2.0, z + d.z * ln / 2.0)
	hc.add_child(c)
	return c


static func hair_anime(hc: Node3D, r: float, m: Material, style: String) -> void:
	var cap := Kit.mi(CharMesh.sphere_part(r * 1.1, 26, 16, PI * 0.56), m)
	cap.rotation.x = -0.36
	cap.position = Vector3(0, r * 0.05, -r * 0.03)
	hc.add_child(cap)
	var back := _sph(r * 1.07, 22, 16, m)
	back.scale = Vector3(1, 0.92, 0.86)
	back.position = Vector3(0, -r * 0.08, -r * 0.3)
	hc.add_child(back)
	for k in 13:
		var t := (k / 12.0 - 0.5) * 2.0
		var a := t * 1.1
		# Bangs stop above the eyes in the middle and frame the face at the sides.
		var ln := r * (0.36 + absf(t) * 0.42 + (k % 2) * 0.06)
		_strand(hc, m, sin(a) * r * 1.0, r * 0.62, cos(a) * r * 0.95, ln, r * 0.16, [t * 0.3, -1, 0.5])
	for k in 10:
		var t := (k / 9.0) * TAU
		_strand(hc, m, sin(t) * r * 0.95, r * 0.35, cos(t) * r * 0.85 - r * 0.15, r * (0.7 + 0.15 * (k % 3)), r * 0.24, [sin(t) * 0.35, -1, cos(t) * 0.25 - 0.1])
	for s in [-1.0, 1.0]:
		_strand(hc, m, s * r * 0.9, r * 0.2, r * 0.32, r * (0.9 if style == "short" else 1.45), r * 0.17, [s * 0.12, -1, 0.12])
	if style == "spiky":
		for d in [[0, 1, -0.4], [0.55, 0.8, -0.4], [-0.55, 0.8, -0.4], [0.85, 0.35, -0.55], [-0.85, 0.35, -0.55], [0, 0.35, -1], [0.45, 0.05, -0.95], [-0.45, 0.05, -0.95]]:
			var v := Vector3(d[0], d[1], d[2]).normalized()
			var c := Kit.cone(r * 0.3, r * 1.05, 8, m)
			c.quaternion = _q_from(v, Vector3.UP)
			c.position = Vector3(v.x * r * 0.9, v.y * r * 0.9 + r * 0.05, v.z * r * 0.9)
			hc.add_child(c)
	if style == "long" or style == "twin" or style == "pony":
		for k in 7:
			var t := (k / 6.0 - 0.5) * 2.0
			_strand(hc, m, t * r * 0.7, -r * 0.1, -r * 0.85, r * (3.1 if style == "long" else 1.3) * (1.0 - absf(t) * 0.12), r * 0.28, [t * 0.15, -1, -0.18])
	if style == "twin":
		for s in [-1.0, 1.0]:
			hc.add_child(Kit.ball(r * 0.18, m, s * r * 1.02, r * 0.35, -r * 0.3))
			var tl := _strand(hc, m, s * r * 1.05, r * 0.3, -r * 0.35, r * 3.0, r * 0.34, [s * 0.3, -1, -0.15])
			tl.scale.x = 1.1
	if style == "pony":
		hc.add_child(Kit.ball(r * 0.2, m, 0, r * 0.28, -r * 1.05))
		_strand(hc, m, 0, r * 0.25, -r * 1.12, r * 2.8, r * 0.36, [0, -1, -0.35])
	if style == "short":
		for k in 5:
			var t := (k / 4.0 - 0.5) * 2.0
			_strand(hc, m, t * r * 0.6, -r * 0.2, -r * 0.9, r * 0.55, r * 0.22, [t * 0.2, -1, -0.4])


static func build_anime(cfg: Dictionary) -> Dictionary:
	var g := func(k: String, d: String) -> String: return str(cfg[k]) if cfg.get(k) else d
	var skin: String = g.call("skin", "#f6dcc8")
	var mS := M(skin, {"skin": true})
	var mH := M(g.call("hair", "#3b2a1e"), {"hair": true})
	var mSh := M(g.call("shirt", "#f4f2ec"))
	var shirt2: String = g.call("shirt2", "#2a7f87")
	var mA := M(shirt2)
	var mP := M(g.call("pants", "#2d3346"))
	var mB := M(g.call("shoes", "#6b4a2b"))
	var coat_c: String = g.call("coatC", shirt2)
	var gold := M("#e6c35a")
	var root := Kit.group()
	var model := Kit.group()
	root.add_child(model)
	var hip := 1.0
	var legs := []
	var arms := []
	var legs_kind: String = cfg.get("legs", "") if cfg.get("legs") else ""
	var thigh_m: Material = mP
	if legs_kind == "bare":
		thigh_m = mS
	elif legs_kind == "stockings":
		thigh_m = M(g.call("sock", "#2a2430"))
	var tall: bool = cfg.get("boots", "") == "tall"
	for s in [-1.0, 1.0]:
		var pv := Kit.group(s * 0.082, hip, 0)
		model.add_child(pv)
		pv.add_child(_cap(0.064, 0.4, thigh_m, 0, -0.22, 0, 16))
		pv.add_child(_cap(0.05, 0.4, mB if tall else (thigh_m if legs_kind == "stockings" else mP), 0, -0.66, 0, 16))
		if tall:
			pv.add_child(Kit.cyl(0.06, 0.054, 0.07, 18, mA, 0, -0.46, 0))
		var foot := _cap(0.048, 0.13, mB, 0, -0.94, 0.05, 14)
		foot.rotation.x = PI / 2
		pv.add_child(foot)
		legs.append(pv)
	var upper := Kit.group(0, hip, 0)
	model.add_child(upper)
	var hips_m := Kit.mi(CharMesh.lathe([[0.001, -0.12], [0.13, -0.11], [0.15, -0.04], [0.13, 0.06], [0.001, 0.06]], 36), mP)
	hips_m.scale.z = 0.74
	upper.add_child(hips_m)
	var torso := Kit.mi(CharMesh.lathe([[0.001, 0], [0.12, 0], [0.112, 0.12], [0.122, 0.25], [0.15, 0.36], [0.158, 0.43], [0.1, 0.5], [0.04, 0.53], [0.001, 0.53]], 36), mSh)
	torso.scale.z = 0.7
	upper.add_child(torso)
	var sash := Kit.cyl(0.118, 0.118, 0.035, 20, mA, 0, 0.03, 0)
	sash.scale.z = 0.72
	upper.add_child(sash)
	upper.add_child(Kit.box(0.06, 0.045, 0.02, gold, 0, 0.03, 0.088))
	var collar := _torus(0.06, 0.016, 8, 20, mA)
	collar.rotation.x = PI / 2
	collar.position.y = 0.52
	upper.add_child(collar)
	# Layered outfit: corset over the shirt, gold trims, a front tabard.
	var mC := M(coat_c)
	var corset := Kit.mi(CharMesh.lathe([[0.001, 0.0], [0.13, 0.0], [0.124, 0.12], [0.13, 0.25], [0.152, 0.33], [0.001, 0.33]], 36), mA)
	corset.scale.z = 0.73
	upper.add_child(corset)
	for ty in [0.005, 0.33]:
		var trim := _torus(0.135 if ty < 0.1 else 0.152, 0.008, 6, 36, gold)
		trim.rotation.x = PI / 2
		trim.position.y = ty
		trim.scale = Vector3(1, 0.73, 1)
		upper.add_child(trim)
	var tabard := Kit.box(0.13, 0.36, 0.012, mC, 0, -0.18, 0.1)
	tabard.rotation.x = -0.12
	upper.add_child(tabard)
	upper.add_child(Kit.box(0.135, 0.014, 0.016, gold, 0, -0.355, 0.122))
	upper.add_child(Kit.octa(0.022, M("#7fe3ff", {"glow": true}), 0, 0.04, 0.1))
	var coat = cfg.get("coat")
	if coat:
		var cl := 0.78 if coat == "long" else (0.3 if coat == "skirt" else 0.46)
		var flare := 0.25 if coat == "skirt" else 0.22
		var sk := Kit.mi(CharMesh.lathe([[0.13, 0.04], [0.145, -0.02], [flare * 0.9, -cl * 0.6], [flare, -cl]], 40), CharMesh.side_mat(coat_c))
		sk.scale.z = 0.8
		upper.add_child(sk)
		if coat != "skirt":
			var tr := _torus(flare, 0.012, 6, 28, gold)
			tr.rotation.x = PI / 2
			tr.position.y = -cl
			tr.scale.y = 0.8
			upper.add_child(tr)
	var head := Kit.group(0, 0.56, 0)
	upper.add_child(head)
	head.add_child(_cap(0.036, 0.06, mS, 0, 0.02, 0, 10))
	var r := 0.128
	var hc := Kit.group(0, 0.13, 0)
	head.add_child(hc)
	hc.add_child(Kit.mi(CharMesh.anime_head(r), mS))
	for s in [-1.0, 1.0]:
		hc.add_child(_sph(0.028, 10, 8, mS, s * r * 0.93, -r * 0.1, -r * 0.05))
	var eye := anime_tex("eye", g.call("eyes", "#3c78d8"))
	face_decal(hc, eye, -r * 0.38, -r * 0.14, r, r * 0.5, r * 0.74, 0.06)
	var eye_r := face_decal(hc, eye, r * 0.38, -r * 0.14, r, r * 0.5, r * 0.74, -0.06)
	eye_r.scale.x = -1
	var brow := anime_tex("brow", U.shade_hex(g.call("hair", "#3b2a1e"), 0.7))
	face_decal(hc, brow, -r * 0.38, r * 0.3, r, r * 0.4, r * 0.1, 0.12)
	var brow_r := face_decal(hc, brow, r * 0.38, r * 0.3, r, r * 0.4, r * 0.1, -0.12)
	brow_r.scale.x = -1
	var bl := anime_tex("blush", "")
	face_decal(hc, bl, -r * 0.48, -r * 0.45, r, r * 0.36, r * 0.18)
	face_decal(hc, bl, r * 0.48, -r * 0.45, r, r * 0.36, r * 0.18)
	face_decal(hc, anime_tex("mouth", ""), 0, -r * 0.7, r, r * 0.26, r * 0.13)
	hair_anime(hc, r, mH, g.call("hairStyle", "short"))
	if cfg.get("ears", "") == "pointy":
		for s in [-1.0, 1.0]:
			var e := Kit.cone(0.04, 0.2, 8, mS, s * r * 1.02, r * 0.02, -r * 0.05)
			e.rotation.z = -s * 1.15
			hc.add_child(e)
	for s in [-1.0, 1.0]:
		hc.add_child(Kit.ball(0.012, gold, s * r * 0.95, -r * 0.4, -r * 0.02, 1))
	if cfg.get("ornament", true) != false:
		var o := Kit.group()
		var orn: String = g.call("ornC", "#ffffff")
		for k in 5:
			var a := k / 5.0 * TAU
			o.add_child(Kit.ball(0.018, M(orn), cos(a) * 0.026, sin(a) * 0.026, 0, 1))
		o.add_child(Kit.ball(0.014, gold, 0, 0, 0.006, 1))
		o.position = Vector3(r * 0.62, r * 0.68, r * 0.62)
		o.quaternion = _q_from(o.position)
		hc.add_child(o)
	if cfg.get("hat", "") == "witch":
		var m_hat := M(g.call("coatC", "#3a2f6b"))
		hc.add_child(Kit.cyl(r * 2.05, r * 2.05, 0.014, 32, m_hat, 0, r * 0.68, -r * 0.05))
		var c := Kit.cone(r * 1.02, r * 2.4, 24, m_hat, 0, r * 1.85, -r * 0.3)
		c.rotation.x = -0.32
		hc.add_child(c)
		var band := _torus(r * 0.98, 0.014, 6, 24, gold)
		band.rotation.x = PI / 2 - 0.05
		band.position.y = r * 0.74
		hc.add_child(band)
	if cfg.get("hat", "") == "circlet":
		var t := _torus(r * 1.06, 0.01, 6, 32, gold)
		t.rotation.x = PI / 2 - 0.32
		t.position.y = r * 0.46
		hc.add_child(t)
		hc.add_child(Kit.octa(0.02, M("#7fe3ff", {"glow": true}), 0, r * 0.62, r * 1.02))
	var sl: float = float(cfg["sleeve"]) if cfg.get("sleeve") != null else 0.8
	for s in [-1.0, 1.0]:
		var pv := Kit.group(s * 0.175, 0.45, 0)
		upper.add_child(pv)
		pv.add_child(Kit.ball(0.055, mSh))
		var pad := Kit.cap(0.07, 18, 0.5, mC, 0, 0.01, 0)
		pad.scale = Vector3(1.05, 0.8, 1.0)
		pad.rotation.z = -s * 0.25
		pv.add_child(pad)
		var pad_trim := _torus(0.068, 0.006, 5, 24, gold)
		pad_trim.rotation.x = PI / 2
		pad_trim.position.y = 0.012
		pv.add_child(pad_trim)
		pv.add_child(_cap(0.047, 0.23, mSh, 0, -0.16, 0, 14))
		pv.add_child(_cap(0.04, 0.21, mSh if sl > 0.9 else mS, 0, -0.42, 0, 14))
		if sl > 0.9:
			var cf := _torus(0.037, 0.01, 6, 16, gold)
			cf.rotation.x = PI / 2
			cf.position.y = -0.52
			pv.add_child(cf)
		pv.add_child(_sph(0.042, 16, 12, M(g.call("gloves", skin), {"skin": not cfg.get("gloves")}), 0, -0.58, 0.005))
		arms.append(pv)
	var cape_g: Node3D = null
	if cfg.get("cape", false):
		cape_g = Kit.group(0, 0.5, -0.1)
		cape_g.add_child(Kit.mi(CharMesh.cape(), CharMesh.side_mat(coat_c)))
		cape_g.rotation.x = 0.1
		upper.add_child(cape_g)
	if cfg.get("scarf", false):
		var ts := _torus(0.075, 0.03, 8, 18, mA)
		ts.rotation.x = PI / 2
		ts.position.y = 0.52
		upper.add_child(ts)
		var tail := _cap(0.03, 0.3, mA, 0.06, 0.32, -0.1)
		tail.rotation.z = 0.2
		upper.add_child(tail)
	var steel := M("#e2e7ef", {"rough": 0.35, "metal": 0.6})
	var dark := M("#3a2f3f")
	var weapon = cfg.get("weapon")
	if weapon == "sword":
		var wg := Kit.group(0, 0.3, -0.13)
		wg.add_child(Kit.box(0.04, 0.82, 0.01, steel, 0, 0.22, 0))
		wg.add_child(Kit.box(0.15, 0.025, 0.045, gold, 0, -0.2, 0))
		wg.add_child(Kit.cyl(0.016, 0.016, 0.17, 8, dark, 0, -0.3, 0))
		wg.add_child(Kit.ball(0.022, gold, 0, -0.4, 0, 1))
		wg.rotation.z = 0.75
		upper.add_child(wg)
	elif weapon == "bow":
		var tb := _torus(0.38, 0.012, 5, 24, M("#8b5a2b"), PI)
		tb.position = Vector3(0, 0.28, -0.13)
		tb.rotation.z = -PI / 2 + 0.5
		upper.add_child(tb)
	elif weapon == "club":
		var cg := Kit.group(0, -0.53, 0.03)
		cg.add_child(Kit.cyl(0.05, 0.022, 0.62, 8, M("#7a5432"), 0, 0.27, 0))
		for k in 3:
			cg.add_child(Kit.cone(0.025, 0.06, 5, M("#d8d0c0"), cos(k * 2.1) * 0.05, 0.45 + k * 0.05, sin(k * 2.1) * 0.05))
		cg.rotation.x = 0.5
		(arms[0] as Node3D).add_child(cg)
	elif weapon == "staff":
		var sg := Kit.group(0, -0.53, 0.02)
		sg.add_child(Kit.cyl(0.014, 0.018, 1.55, 8, M("#6e4b2c"), 0, 0.25, 0))
		sg.add_child(Kit.ball(0.055, M("#9fe8ff", {"glow": true}), 0, 1.05, 0, 2))
		var ring := _torus(0.075, 0.008, 6, 20, gold)
		ring.position.y = 1.05
		sg.add_child(ring)
		(arms[0] as Node3D).add_child(sg)
	var head_h := hip + 0.56 + 0.13
	return {"root": root, "model": model, "upper": upper, "head": head, "hc": hc, "torso": torso, "armR": arms[0], "armL": arms[1], "legR": legs[0], "legL": legs[1],
		"headH": head_h, "height": head_h + r * 1.4, "sitDrop": hip - 0.08, "cape": cape_g, "kind": "human"}


static func build_anime_creature(cfg: Dictionary) -> Dictionary:
	var root := Kit.group()
	var model := Kit.group()
	root.add_child(model)
	var upper := Kit.group()
	model.add_child(upper)
	var head := Kit.group()
	var eye_dark := M("#1e1424")
	var white := M("#ffffff", {"glow": true})
	var col: String = cfg.get("col", "#86d96a")
	var nub := func() -> Node3D:
		var gg := Kit.group()
		model.add_child(gg)
		return gg
	var rig := {}
	if cfg.get("creature") == "slime":
		var body := _sph(0.42, 30, 22, M(col, {"op": 0.82}))
		body.scale = Vector3(1, 0.82, 1)
		body.position.y = 0.34
		upper.add_child(body)
		upper.add_child(_sph(0.2, 16, 12, M(U.shade_hex(col, 0.75)), 0, 0.3, 0))
		upper.add_child(_sph(0.07, 10, 8, white, -0.15, 0.58, 0.18))
		head.position = Vector3(0, 0.38, 0)
		upper.add_child(head)
		for s in [-1.0, 1.0]:
			var e := _cap(0.035, 0.06, eye_dark, s * 0.13, 0.02, 0.375)
			e.scale.z = 0.5
			head.add_child(e)
			head.add_child(_sph(0.014, 8, 6, white, s * 0.13 - 0.01, 0.05, 0.4))
		rig = {"hop": true, "headH": 0.5, "height": 0.85}
	elif cfg.get("creature") == "wisp":
		upper.position.y = 0.9
		upper.add_child(_sph(0.16, 18, 14, M(col, {"glow": true})))
		var aura := _sph(0.28, 18, 14, M(col, {"op": 0.25, "glow": true}))
		upper.add_child(aura)
		for k in 3:
			var a := k / 3.0 * TAU
			upper.add_child(_sph(0.04, 8, 6, M("#ffffff", {"glow": true}), cos(a) * 0.38, sin(a * 2) * 0.1, sin(a) * 0.38))
		upper.add_child(head)
		for s in [-1.0, 1.0]:
			head.add_child(_sph(0.025, 8, 6, eye_dark, s * 0.055, 0.02, 0.15))
		rig = {"float": true, "spinUpper": true, "headH": 0.95, "height": 1.25}
	else:
		var fur := M(col)
		var belly := M(str(cfg["col2"]) if cfg.get("col2") else "#e8e4dc")
		var leg_h := 0.42
		upper.position.y = leg_h
		var body := _cap(0.22, 0.55, fur, 0, 0.2, 0, 14)
		body.rotation.x = PI / 2
		upper.add_child(body)
		head.position = Vector3(0, 0.38, 0.45)
		upper.add_child(head)
		head.add_child(_sph(0.17, 18, 14, fur, 0, 0, 0.02))
		var sn := Kit.cone(0.09, 0.22, 12, belly, 0, -0.05, 0.2)
		sn.rotation.x = PI / 2
		head.add_child(sn)
		head.add_child(_sph(0.03, 8, 6, eye_dark, 0, -0.03, 0.31))
		for s in [-1.0, 1.0]:
			var ear := Kit.cone(0.055, 0.16, 6, fur, s * 0.09, 0.17, -0.02)
			ear.rotation.z = -s * 0.25
			head.add_child(ear)
			head.add_child(_sph(0.025, 8, 6, M(str(cfg["eye"]) if cfg.get("eye") else "#f2c14e", {"glow": true}), s * 0.075, 0.04, 0.15))
		var tail := Kit.cone(0.07, 0.45, 8, fur, 0, 0.32, -0.5)
		tail.rotation.x = -2.2
		upper.add_child(tail)
		var leg := func(x: float, z: float) -> Node3D:
			var pv := Kit.group(x, leg_h, z)
			pv.add_child(_cap(0.055, leg_h - 0.1, fur, 0, -leg_h / 2.0, 0, 10))
			model.add_child(pv)
			return pv
		return {"root": root, "model": model, "upper": upper, "head": head, "hc": null, "kind": "quad", "headH": 0.85, "height": 1.05, "sitDrop": 0.1,
			"armR": leg.call(-0.13, 0.3), "armL": leg.call(0.13, 0.3), "legR": leg.call(-0.13, -0.3), "legL": leg.call(0.13, -0.3)}
	var out := {"root": root, "model": model, "upper": upper, "head": head, "hc": null, "kind": "quad", "armR": nub.call(), "armL": nub.call(), "legR": nub.call(), "legL": nub.call(), "sitDrop": 0.05}
	out.merge(rig, true)
	return out


# ---------------------------------------------------------------- low-poly

static func build_lowpoly(cfg: Dictionary) -> Dictionary:
	var g := func(k: String, d: String) -> String: return str(cfg[k]) if cfg.get(k) else d
	var skin: String = g.call("skin", "#e9b98f")
	var mS := M(skin)
	var mH := M(g.call("hair", "#5a3b22"))
	var p := {"seg": 6, "hip": 0.58, "legLen": 0.56, "legW": 0.11, "legX": 0.12, "bootH": 0.16, "torsoH": 0.6, "torsoW": 0.5, "torsoD": 0.38, "chest": 0.88, "waist": 1.04, "neck": 0.04, "headR": 0.23, "headLift": 0.95, "armLen": 0.5, "armW": 0.08,
		"sleeve": float(cfg["sleeve"]) if cfg.get("sleeve") != null else 0.7,
		"mPants": M(g.call("pants", "#5b4a3a")), "mShoes": M(g.call("shoes", "#3a2a20")), "mShirt": M(g.call("shirt", "#d9822b")), "mSkin": mS}
	p["headGeo"] = func(q: Dictionary) -> Node3D:
		return Kit.icosa(q["headR"], 1, mS)
	var rig := humanoid(p)
	var r: float = p["headR"]
	var hc: Node3D = rig["hc"]
	var eye := M("#1c1a22")
	var shine := M("#ffffff", {"glow": true})
	for s in [-1.0, 1.0]:
		hc.add_child(Kit.box(0.035, 0.06, 0.02, eye, s * 0.08, 0.02, r * 0.92))
		hc.add_child(Kit.box(0.012, 0.014, 0.01, shine, s * 0.08 - 0.008, 0.035, r * 0.92 + 0.012))
	hc.add_child(Kit.box(0.05, 0.05, 0.05, M(U.shade_hex(skin, 0.9)), 0, -0.04, r * 0.95))
	if cfg.get("beard"):
		var bd := Kit.cone(r * 0.65, r * 0.9, 6, M(cfg["beard"]), 0, -r * 0.7, r * 0.45)
		bd.rotation.x = PI
		hc.add_child(bd)
	var hat: String = g.call("hat", "")
	if hat != "helmet" and hat != "hood":
		var hr := Kit.mi(CharMesh.sphere_part(r * 1.07, 7, 5, PI * 0.5), mH)
		hr.rotation.x = -0.38
		hc.add_child(hr)
	if cfg.get("hairStyle", "") == "long":
		var b := Kit.icosa(r, 0, mH)
		b.scale = Vector3(1.05, 1.3, 0.6)
		b.position = Vector3(0, -r * 0.5, -r * 0.5)
		hc.add_child(b)
	var m_hat := M(g.call("hatC", "#c9a24e"))
	if hat == "straw" or hat == "ranger":
		hc.add_child(Kit.cyl(r * 1.85, r * 1.85, 0.03, 8, m_hat, 0, r * 0.45, 0))
		hc.add_child(Kit.cyl(r * 0.85, r * 1.0, r * 0.55, 8, m_hat, 0, r * 0.72, 0))
	if hat == "helmet":
		hc.add_child(Kit.cyl(r * 1.1, r * 1.12, r * 1.6, 8, m_hat, 0, r * 0.15, 0))
		hc.add_child(Kit.box(r * 1.3, 0.04, 0.04, M("#1c1a22"), 0, r * 0.05, r * 1.1))
	if hat == "chef":
		var w := M("#f6f4ef")
		hc.add_child(Kit.cyl(r * 0.9, r * 0.9, r * 0.7, 8, w, 0, r * 0.9, 0))
		hc.add_child(Kit.ball(r * 0.85, w, 0, r * 1.4, 0, 0))
	if hat == "hood":
		var h := Kit.icosa(r * 1.28, 1, m_hat)
		h.position = Vector3(0, r * 0.1, -r * 0.3)
		hc.add_child(h)
	var tw: float = p["torsoW"]
	var th: float = p["torsoH"]
	var td: float = p["torsoD"]
	var upper: Node3D = rig["upper"]
	if cfg.get("apron"):
		upper.add_child(Kit.box(tw * 0.8, th * 0.72 + 0.14, 0.02, M(cfg["apron"]), 0, th * 0.36 - 0.07, td / 2.0 + 0.01))
	if cfg.get("cape"):
		var pv := Kit.group(0, th - 0.04, -td / 2.0 - 0.02)
		pv.rotation.x = 0.12
		pv.add_child(Kit.box(0.48, 0.72, 0.03, M(cfg["cape"]), 0, -0.36, 0))
		upper.add_child(pv)
		rig["cape"] = pv
	rig["height"] = float(rig["headH"]) + r * 1.25
	return rig
