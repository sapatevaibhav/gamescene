class_name Props
## Procedural scenery props for the terrain styles (anime, tactical, low-poly).
##
## Ported from the web build's prop builders. `build(style, key, seed)` returns
## a fresh Node3D standing on y = 0 and facing +Z. Same seed, same shape: the
## builders consume the mulberry32 stream in the same order as the JS code, so
## props saved by the web build rebuild identically. Colour picks that the web
## build made with Math.random use a second stream derived from the seed.
##
## Animated parts are exposed as metadata on the returned node:
##   "spin"    -> Node3D to rotate around its local Z (windmill hub)
##   "flicker" -> Array of flame MeshInstance3D to scale-flicker
##   "light"   -> OmniLight3D whose energy can flicker with the flames

const DEFS := {
	"anime": {
		"oak": {"name": "Oak tree", "cols": [[0.0, 0.0, 0.4]]},
		"windmill": {"name": "Windmill", "cols": [[0.0, 0.0, 1.6]]},
		"house": {"name": "Timber house"},
		"wall": {"name": "Stone wall"},
		"fence": {"name": "Fence"},
		"hay": {"name": "Haystack"},
		"cart": {"name": "Cart"},
		"lamp": {"name": "Lamp post"},
		"flowers": {"name": "Wildflowers", "cols": []},
		"rocks": {"name": "Rocks"},
		"blossom": {"name": "Blossom tree", "cols": [[0.0, 0.0, 0.35]]},
		"lantern": {"name": "Stone lantern"},
		"crystal": {"name": "Crystals"},
		"bench": {"name": "Bench"},
		"fire": {"name": "Campfire"},
		"well": {"name": "Well"},
	},
	"tactical": {
		"pine": {"name": "Pine", "cols": [[0.0, 0.0, 0.3]]},
		"rock": {"name": "Rock"},
		"crate": {"name": "Crate"},
		"barrel": {"name": "Barrel"},
		"container": {"name": "Container"},
		"tent": {"name": "Tent"},
		"sandbags": {"name": "Sandbags"},
		"tower": {"name": "Watchtower"},
		"warehouse": {"name": "Warehouse"},
		"jeep": {"name": "Jeep"},
		"fence": {"name": "Fence"},
	},
	"lowpoly": {
		"pine": {"name": "Pine", "cols": [[0.0, 0.0, 0.3]]},
		"tree": {"name": "Round tree", "cols": [[0.0, 0.0, 0.35]]},
		"rock": {"name": "Rock"},
		"house": {"name": "Cottage"},
		"well": {"name": "Well"},
		"fence": {"name": "Fence"},
		"bench": {"name": "Bench"},
		"barrel": {"name": "Barrel"},
		"fire": {"name": "Campfire"},
		"flowers": {"name": "Flowers", "cols": []},
		"lamp": {"name": "Lamp post"},
	},
}


static func defs(style: String) -> Dictionary:
	return DEFS.get(style, {})


static func has(style: String, key: String) -> bool:
	return DEFS.has(style) and DEFS[style].has(key)


## Builds prop `key` for `style`. Returns null for unknown keys.
static func build(style: String, key: String, seed: int) -> Node3D:
	if not has(style, key):
		return null
	var prev_shade := Kit.shade
	var prev_w := Kit.outline_width
	Kit.shade = Styles.get_style(style).get("shade", "lambert")
	Kit.outline_width = 0.016
	var r := U.rng(seed)
	var r2 := U.rng(seed ^ 0x5BD1E995)
	var g: Node3D = null
	match style:
		"anime":
			match key:
				"oak": g = _oak(r)
				"windmill": g = _windmill()
				"house": g = _timber_house(r2)
				"wall": g = _stone_wall()
				"fence": g = _fence("#8b6a45")
				"hay": g = _haystack()
				"cart": g = _cart()
				"lamp": g = _iron_lamp()
				"flowers": g = _wildflowers(r, r2)
				"rocks": g = _outcrop(r)
				"blossom": g = _tree_round("#f7a8c8", "#ffc9de", r)
				"lantern": g = _lantern()
				"crystal": g = _crystals(r, r2)
				"bench": g = _bench()
				"fire": g = _campfire()
				"well": g = _well()
		"tactical":
			match key:
				"pine": g = _tree_pine("#4f6b3a", r)
				"rock": g = _rock("#8a8a85", r)
				"crate": g = _crate()
				"barrel": g = _barrel()
				"container": g = _container(r2)
				"tent": g = _tent()
				"sandbags": g = _sandbags()
				"tower": g = _watchtower()
				"warehouse": g = _warehouse()
				"jeep": g = _jeep()
				"fence": g = _fence("#6b6f75")
		"lowpoly":
			match key:
				"pine": g = _tree_pine("#3f7f4a", r)
				"tree": g = _tree_round("#6fae4f", "#8cc45a", r)
				"rock": g = _rock("#9c958c", r)
				"house": g = _cottage("#e8d8b8", "#b5523a")
				"well": g = _well()
				"fence": g = _fence("#9b6b3f")
				"bench": g = _bench()
				"barrel": g = _barrel()
				"fire": g = _campfire()
				"flowers": g = _flowers(r, r2)
				"lamp": g = _lamp_post()
	Kit.shade = prev_shade
	Kit.outline_width = prev_w
	if g != null:
		g.name = "Prop_" + key
	return g


# ---------------------------------------------------------------- helpers

static func M(c: String, opts := {}) -> Material:
	return Kit.mat(c, opts)


static func _glow_light(g: Node3D, y: float, color: String, energy := 1.4, rng := 5.0, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = Vector3(0, y, 0)
	l.light_color = U.col(color)
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.6
	l.shadow_enabled = shadow
	l.light_bake_mode = Light3D.BAKE_DISABLED
	l.distance_fade_enabled = true
	l.distance_fade_begin = 40.0
	l.distance_fade_length = 10.0
	g.add_child(l)
	g.set_meta("light", l)
	return l


# ---------------------------------------------------------------- builders

static func _tree_round(col_a: String, col_b: String, r: U.Rng) -> Node3D:
	var g := Kit.group()
	var t := M("#7a5432")
	g.add_child(Kit.cyl(0.12, 0.17, 1.5, 6, t, 0, 0.75, 0))
	var n := 1 + int(r.next() * 3)
	for k in n:
		var rad := 0.85 + r.next() * 0.35
		var mm := M(col_b if k % 2 == 1 else col_a)
		var x := (r.next() - 0.5) * 0.9
		var y := 1.9 + r.next() * 0.6
		var z := (r.next() - 0.5) * 0.9
		g.add_child(Kit.ball(rad, mm, x, y, z, 0 if Kit.shade == "flat" else 1))
	return g


static func _tree_pine(col: String, r: U.Rng) -> Node3D:
	var g := Kit.group()
	var m := M(col)
	g.add_child(Kit.cyl(0.1, 0.15, 0.9, 6, M("#6b4a2c"), 0, 0.45, 0))
	var s := 0.9 + r.next() * 0.4
	for row in [[1.15, 1.5, 1.3], [0.88, 1.3, 2.05], [0.58, 1.1, 2.7]]:
		g.add_child(Kit.cone(row[0] * s, row[1] * s, 7, m, 0, row[2] * s, 0))
	return g


static func _rock(col: String, r: U.Rng) -> Node3D:
	var g := Kit.group()
	var m := Kit.dodeca(0.6 + r.next() * 0.5, M(col))
	var sx := 1 + r.next() * 0.6
	var sy := 0.6 + r.next() * 0.5
	var sz := 1 + r.next() * 0.4
	m.scale = Vector3(sx, sy, sz)
	m.position.y = 0.25
	m.rotation.y = r.next() * 6
	g.add_child(m)
	return g


static func _cottage(wall: String, roof: String) -> Node3D:
	var g := Kit.group()
	var dark := M("#4a3626")
	g.add_child(Kit.box(3.2, 2.2, 2.6, M(wall), 0, 1.1, 0))
	g.add_child(Kit.prism(3.7, 1.5, 3.1, M(roof), 0, 2.2, 0))
	g.add_child(Kit.box(0.72, 1.25, 0.06, dark, 0, 0.63, 1.31))
	g.add_child(Kit.box(0.5, 0.5, 0.06, M("#ffd98a", {"glow": true}), -1, 1.35, 1.31))
	g.add_child(Kit.box(0.5, 0.5, 0.06, M("#ffd98a", {"glow": true}), 1, 1.35, 1.31))
	g.add_child(Kit.box(0.36, 0.9, 0.36, M("#8b8680"), 0.9, 3.1, -0.5))
	return g


static func _lantern() -> Node3D:
	var g := Kit.group()
	var st := M("#b9b4aa")
	g.add_child(Kit.cyl(0.26, 0.3, 0.18, 8, st, 0, 0.09, 0))
	g.add_child(Kit.cyl(0.1, 0.12, 0.8, 8, st, 0, 0.6, 0))
	g.add_child(Kit.box(0.34, 0.3, 0.34, M("#ffe2a0", {"glow": true}), 0, 1.15, 0))
	var c := Kit.cone(0.36, 0.26, 4, st, 0, 1.43, 0)
	c.rotation.y = PI / 4
	g.add_child(c)
	_glow_light(g, 1.15, "#ffd08a", 1.0, 4.0)
	return g


static func _crystals(r: U.Rng, r2: U.Rng) -> Node3D:
	var g := Kit.group()
	var col: String = r2.pick(["#8fe6ff", "#c9a8ff", "#ffb3e0"])
	for k in 4:
		var m := Kit.octa(0.28, M(col, {"glow": true}))
		m.scale = Vector3(1, 2.2 + r.next() * 1.2, 1)
		var px := (r.next() - 0.5) * 0.8
		var py := 0.5 + r.next() * 0.3
		var pz := (r.next() - 0.5) * 0.8
		m.position = Vector3(px, py, pz)
		var rx := (r.next() - 0.5) * 0.6
		var ry := r.next() * 3
		var rz := (r.next() - 0.5) * 0.6
		m.rotation = Vector3(rx, ry, rz)
		g.add_child(m)
	_glow_light(g, 0.8, col, 0.8, 3.5)
	return g


static func _flowers(r: U.Rng, r2: U.Rng) -> Node3D:
	var g := Kit.group()
	var cols := ["#ff7aa2", "#ffd166", "#ffffff", "#b9a2ff", "#ff9f43"]
	for k in 7:
		var x := (r.next() - 0.5) * 1.2
		var z := (r.next() - 0.5) * 1.2
		g.add_child(Kit.cyl(0.015, 0.015, 0.35, 4, M("#4f8f4a"), x, 0.17, z))
		g.add_child(Kit.ball(0.07, M(r2.pick(cols)), x, 0.36, z, 0))
	return g


static func _bench() -> Node3D:
	var g := Kit.group()
	var w := M("#9b6b3f")
	g.add_child(Kit.box(1.5, 0.08, 0.42, w, 0, 0.45, 0))
	g.add_child(Kit.box(1.5, 0.36, 0.06, w, 0, 0.74, -0.19))
	g.add_child(Kit.box(0.08, 0.45, 0.4, w, -0.65, 0.22, 0))
	g.add_child(Kit.box(0.08, 0.45, 0.4, w, 0.65, 0.22, 0))
	return g


static func _campfire() -> Node3D:
	var g := Kit.group()
	var w := M("#6b4a2c")
	for k in 3:
		var l := Kit.cyl(0.07, 0.07, 0.85, 6, w, 0, 0.08, 0)
		l.rotation = Vector3(PI / 2, k * 1.05, 0)
		g.add_child(l)
	for k in 7:
		var a := float(k) / 7 * TAU
		g.add_child(Kit.ball(0.11, M("#8a8680"), cos(a) * 0.5, 0.06, sin(a) * 0.5, 0))
	var f1 := Kit.cone(0.24, 0.7, 6, M("#ff8a2a", {"glow": true}), 0, 0.4, 0)
	var f2 := Kit.cone(0.14, 0.5, 6, M("#ffd24a", {"glow": true}), 0, 0.35, 0)
	g.add_child(f1)
	g.add_child(f2)
	g.set_meta("flicker", [f1, f2])
	_glow_light(g, 0.6, "#ff9a48", 2.2, 7.0, true)
	return g


static func _well() -> Node3D:
	var g := Kit.group()
	var st := M("#9a958c")
	var w := M("#7a5432")
	g.add_child(Kit.cyl(0.72, 0.78, 0.75, 10, st, 0, 0.37, 0))
	g.add_child(Kit.cyl(0.62, 0.62, 0.05, 10, M("#4fa3d1"), 0, 0.66, 0))
	g.add_child(Kit.box(0.1, 1.6, 0.1, w, -0.66, 1.1, 0))
	g.add_child(Kit.box(0.1, 1.6, 0.1, w, 0.66, 1.1, 0))
	g.add_child(Kit.prism(1.9, 0.65, 1.2, M("#b5523a"), 0, 1.85, 0))
	return g


static func _fence(col: String) -> Node3D:
	var g := Kit.group()
	var w := M(col)
	for x in [-1, 0, 1]:
		g.add_child(Kit.box(0.1, 0.95, 0.1, w, x, 0.47, 0))
	g.add_child(Kit.box(2.15, 0.08, 0.05, w, 0, 0.36, 0))
	g.add_child(Kit.box(2.15, 0.08, 0.05, w, 0, 0.72, 0))
	return g


static func _lamp_post() -> Node3D:
	var g := Kit.group()
	var m := M("#33363b")
	g.add_child(Kit.cyl(0.05, 0.07, 2.5, 6, m, 0, 1.25, 0))
	g.add_child(Kit.box(0.28, 0.32, 0.28, M("#ffe2a0", {"glow": true}), 0, 2.62, 0))
	var c := Kit.cone(0.24, 0.2, 4, m, 0, 2.88, 0)
	c.rotation.y = PI / 4
	g.add_child(c)
	_glow_light(g, 2.55, "#ffd08a", 1.6, 7.0)
	return g


static func _barrel() -> Node3D:
	var g := Kit.group()
	g.add_child(Kit.cyl(0.32, 0.32, 0.82, 10, M("#8b5a2b"), 0, 0.41, 0))
	g.add_child(Kit.cyl(0.335, 0.335, 0.05, 10, M("#3a3530"), 0, 0.2, 0))
	g.add_child(Kit.cyl(0.335, 0.335, 0.05, 10, M("#3a3530"), 0, 0.62, 0))
	return g


static func _crate() -> Node3D:
	var g := Kit.group()
	var w := M("#a07a46")
	var d := M("#7a5a32")
	g.add_child(Kit.box(1, 1, 1, w, 0, 0.5, 0))
	g.add_child(Kit.box(1.02, 0.1, 1.02, d, 0, 0.95, 0))
	g.add_child(Kit.box(1.02, 0.1, 1.02, d, 0, 0.05, 0))
	return g


static func _container(r2: U.Rng) -> Node3D:
	var g := Kit.group()
	var col: String = r2.pick(["#b5452f", "#2f6db5", "#3f8a4a", "#c9a227", "#6b6f75"])
	g.add_child(Kit.box(6, 2.6, 2.4, M(col, {"rough": 0.6, "metal": 0.35}), 0, 1.3, 0))
	var dk := M(U.shade_hex(col, 0.78), {"rough": 0.6, "metal": 0.35})
	var x := -2.7
	while x <= 2.7 + 1e-6:
		g.add_child(Kit.box(0.08, 2.4, 2.46, dk, x, 1.3, 0))
		x += 0.6
	return g


static func _tent() -> Node3D:
	var g := Kit.group()
	g.add_child(Kit.prism(2.6, 1.7, 3.2, M("#6b7350"), 0, 0, 0))
	g.add_child(Kit.prism(1.1, 0.95, 0.04, M("#2d2f25"), 0, 0, 1.61))
	return g


static func _sandbags() -> Node3D:
	var g := Kit.group()
	var m := M("#b8a37a")
	for y in 2:
		for k in 5:
			if y == 1 and k == 4:
				continue
			var s := Kit.sphere(0.32, 8, 6, m)
			s.scale = Vector3(1.25, 0.55, 0.8)
			s.position = Vector3(-1.3 + k * 0.65 + (0.32 if y == 1 else 0.0), 0.18 + y * 0.33, 0)
			g.add_child(s)
	return g


static func _watchtower() -> Node3D:
	var g := Kit.group()
	var w := M("#7d6448")
	for p in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		g.add_child(Kit.box(0.16, 4, 0.16, w, p[0], 2, p[1]))
	g.add_child(Kit.box(2.7, 0.16, 2.7, w, 0, 4, 0))
	for p in [[0, 1.3, 2.7, 0.1], [0, -1.3, 2.7, 0.1]]:
		g.add_child(Kit.box(p[2], 0.9, p[3], w, p[0], 4.5, p[1]))
	g.add_child(Kit.box(0.1, 0.9, 2.7, w, 1.3, 4.5, 0))
	g.add_child(Kit.box(0.1, 0.9, 2.7, w, -1.3, 4.5, 0))
	g.add_child(Kit.prism(3.1, 1.1, 3.1, M("#5b6340"), 0, 5.3, 0))
	var y := 0.4
	while y < 4.0:
		g.add_child(Kit.box(0.6, 0.06, 0.06, w, 0, y, 1.08))
		y += 0.45
	return g


static func _warehouse() -> Node3D:
	var g := Kit.group()
	g.add_child(Kit.box(8, 4, 6, M("#8a8f94", {"rough": 0.7, "metal": 0.25}), 0, 2, 0))
	g.add_child(Kit.prism(8.6, 1.6, 6.4, M("#6b7075", {"rough": 0.6, "metal": 0.3}), 0, 4, 0))
	g.add_child(Kit.box(2.6, 3, 0.06, M("#3b3f44"), 0, 1.5, 3.02))
	return g


static func _jeep() -> Node3D:
	var g := Kit.group()
	var o := M("#5b6340", {"rough": 0.65, "metal": 0.2})
	g.add_child(Kit.box(1.8, 0.7, 3.6, o, 0, 0.78, 0))
	g.add_child(Kit.box(1.7, 0.6, 1.3, M("#9fb4c2", {"rough": 0.15, "metal": 0.1}), 0, 1.42, -0.3))
	g.add_child(Kit.box(1.72, 0.08, 1.35, o, 0, 1.75, -0.3))
	for p in [[-0.95, 1.2], [0.95, 1.2], [-0.95, -1.2], [0.95, -1.2]]:
		var wh := Kit.cyl(0.38, 0.38, 0.3, 12, M("#1f2022"), p[0], 0.38, p[1])
		wh.rotation.z = PI / 2
		g.add_child(wh)
	return g


static func _oak(r: U.Rng) -> Node3D:
	var g := Kit.group()
	g.add_child(Kit.cyl(0.2, 0.32, 1.9, 8, M("#6b4a30"), 0, 0.95, 0))
	var cols := ["#4f9e3f", "#62b24a", "#79c457"]
	var n := 5 + int(r.next() * 3)
	for k in n:
		var a := float(k) / n * TAU
		var d := 0.0
		if k > 0:
			d = 0.7 + r.next() * 0.4
		var rad := 1 + r.next() * 0.45
		var y := 2.5 + r.next() * 0.7 + (0.0 if k > 0 else 0.5)
		g.add_child(Kit.ball(rad, M(cols[k % 3]), cos(a) * d, y, sin(a) * d))
	return g


static func _windmill() -> Node3D:
	var g := Kit.group()
	var cream := M("#efe6d2")
	var roof := M("#b5523a")
	var wood := M("#6b4a30")
	var sail := M("#f6f0e2", {"side": true})
	g.add_child(Kit.cyl(1.45, 1.6, 0.6, 12, M("#9aa0a8"), 0, 0.3, 0))
	g.add_child(Kit.cyl(0.95, 1.4, 5, 12, cream, 0, 3.1, 0))
	g.add_child(Kit.cone(1.25, 1.8, 12, roof, 0, 6.5, 0))
	g.add_child(Kit.box(0.7, 1.3, 0.08, wood, 0, 1.25, 1.42))
	g.add_child(Kit.box(0.4, 0.5, 0.06, M("#ffd98a", {"glow": true}), 0, 3.6, 1.18))
	var hub := Kit.group(0, 5, 1.35)
	var axle := Kit.cyl(0.22, 0.22, 0.5, 10, wood)
	axle.rotation.x = PI / 2
	hub.add_child(axle)
	for k in 4:
		var arm := Kit.group()
		arm.rotation.z = k * PI / 2
		arm.add_child(Kit.box(0.16, 3.4, 0.1, wood, 0, 1.75, 0))
		arm.add_child(Kit.box(0.95, 2.5, 0.03, sail, 0.55, 2.05, 0.06))
		hub.add_child(arm)
	g.add_child(hub)
	g.set_meta("spin", hub)
	return g


static func _timber_house(r2: U.Rng) -> Node3D:
	var g := Kit.group()
	var wall := M("#f2ede2")
	var beam := M("#5a3e2a")
	var roof_c: String = r2.pick(["#c0583e", "#b8643a", "#8a4a3a"])
	g.add_child(Kit.box(3.6, 2.7, 3, wall, 0, 1.35, 0))
	g.add_child(Kit.box(3.7, 0.5, 3.1, M("#a8adb2"), 0, 0.25, 0))
	g.add_child(Kit.prism(4.3, 2.3, 3.5, M(roof_c), 0, 2.7, 0))
	for z in [1.51, -1.51]:
		for x in [-1.75, 0.0, 1.75]:
			g.add_child(Kit.box(0.14, 2.2, 0.04, beam, x, 1.6, z))
		g.add_child(Kit.box(3.6, 0.14, 0.04, beam, 0, 1.55, z))
		g.add_child(Kit.box(3.6, 0.14, 0.04, beam, 0, 2.65, z))
	for x in [1.81, -1.81]:
		for z in [-1.4, 1.4]:
			g.add_child(Kit.box(0.04, 2.2, 0.14, beam, x, 1.6, z))
		g.add_child(Kit.box(0.04, 0.14, 3, beam, x, 1.55, 0))
	g.add_child(Kit.box(0.8, 1.35, 0.06, beam, 0, 0.9, 1.53))
	g.add_child(Kit.box(0.55, 0.55, 0.06, M("#ffd98a", {"glow": true}), -1, 2.1, 1.53))
	g.add_child(Kit.box(0.55, 0.55, 0.06, M("#ffd98a", {"glow": true}), 1, 2.1, 1.53))
	g.add_child(Kit.box(0.45, 1.3, 0.45, M("#9aa0a8"), 1.1, 4.1, -0.6))
	return g


static func _stone_wall() -> Node3D:
	var g := Kit.group()
	var s := M("#a8adb2")
	var d := M("#8e959c")
	for k in 5:
		g.add_child(Kit.box(0.62, 0.55 + (k % 2) * 0.08, 0.5, d if k % 2 == 1 else s, -1.24 + k * 0.62, 0.3, 0))
	g.add_child(Kit.box(3.2, 0.12, 0.56, M("#7fa860"), 0, 0.62, 0))
	return g


static func _haystack() -> Node3D:
	var g := Kit.group()
	g.add_child(Kit.cyl(0.75, 0.8, 1, 12, M("#e2c25a"), 0, 0.5, 0))
	g.add_child(Kit.cone(0.82, 0.9, 12, M("#d6b24a"), 0, 1.45, 0))
	return g


static func _wildflowers(r: U.Rng, r2: U.Rng) -> Node3D:
	var g := Kit.group()
	var cols := ["#ffffff", "#ffe066", "#8fb7ff", "#c9a2ff", "#ff9ec4"]
	for k in 11:
		var x := (r.next() - 0.5) * 1.8
		var z := (r.next() - 0.5) * 1.8
		var h := 0.35 + r.next() * 0.35
		g.add_child(Kit.cyl(0.012, 0.012, h, 4, M("#4f8f3a"), x, h / 2, z))
		var rad := 0.06 + r.next() * 0.03
		g.add_child(Kit.ball(rad, M(r2.pick(cols)), x, h, z, 1))
	return g


static func _outcrop(r: U.Rng) -> Node3D:
	var g := Kit.group()
	for k in 3:
		var m := Kit.dodeca(0.8 + r.next() * 0.7, M("#9aa3ad" if k % 2 == 1 else "#b3bbc4"))
		m.scale = Vector3(1, 0.8 + r.next() * 0.7, 1)
		var px := (r.next() - 0.5) * 1.6
		var pz := (r.next() - 0.5) * 1.4
		m.position = Vector3(px, 0.4 + k * 0.3, pz)
		var rx := r.next()
		var ry := r.next() * 3
		var rz := r.next()
		m.rotation = Vector3(rx, ry, rz)
		g.add_child(m)
	return g


static func _cart() -> Node3D:
	var g := Kit.group()
	var w := M("#8b5a2b")
	var dk := M("#5a3e2a")
	g.add_child(Kit.box(1.4, 0.45, 2, w, 0, 0.75, 0))
	g.add_child(Kit.box(1.5, 0.08, 2.1, dk, 0, 0.98, 0))
	g.add_child(Kit.box(0.08, 0.08, 1.4, dk, -0.35, 0.55, 1.6))
	g.add_child(Kit.box(0.08, 0.08, 1.4, dk, 0.35, 0.55, 1.6))
	for x in [-0.8, 0.8]:
		var wh := Kit.torus(0.42, 0.07, 6, 14, dk)
		wh.rotation.y = PI / 2
		wh.position = Vector3(x, 0.45, 0)
		g.add_child(wh)
	return g


static func _iron_lamp() -> Node3D:
	var g := Kit.group()
	var m := M("#2f3338")
	g.add_child(Kit.cyl(0.06, 0.08, 2.6, 8, m, 0, 1.3, 0))
	g.add_child(Kit.box(0.32, 0.38, 0.32, M("#ffe2a0", {"glow": true}), 0, 2.75, 0))
	var c := Kit.cone(0.3, 0.28, 4, m, 0, 3.08, 0)
	c.rotation.y = PI / 4
	g.add_child(c)
	_glow_light(g, 2.65, "#ffd08a", 1.6, 7.0)
	return g
