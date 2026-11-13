class_name SceneFx
extends Node3D
## Effects placed in the scene: campfires, magic sparkles, smoke and dust, in
## every style. Each is a few MultiMesh billboard particles whose motion is
## worked out in the shader from the scene clock (fx_common.gdshaderinc), so
## takes, scrubbing and resumed exports always look the same; nothing is
## simulated here. Campfires also light the scene (3D styles), keep
## characters from walking into them and draw "gather" crowds round them.
##
## Saved in the project as "fx": [{k, x, y, z, s}].

const KINDS := {
	"fire": {"name": "Campfire", "icon": "fire"},
	"sparkles": {"name": "Magic sparkles", "icon": "sparkle"},
	"smoke": {"name": "Smoke", "icon": "cloud"},
	"dust": {"name": "Dust in the air", "icon": "wind"},
}
const ORDER := ["fire", "sparkles", "smoke", "dust"]
const ADD := preload("res://src/shaders/fx_add.gdshader")
const MIX := preload("res://src/shaders/fx_mix.gdshader")
## Art pixel in Pixel 2D worlds (PixelWorld.PPM pixels per metre).
const PX := 1.0 / 16.0

var studio: Node
## [{k, x, y, z, s}] in placement order; _nodes matches it.
var items: Array = []
var _nodes: Array[Node3D] = []
var _fire_cache: Array = []
var _fire_frame := -1


func clear() -> void:
	for n in _nodes:
		n.queue_free()
	_nodes.clear()
	items.clear()
	_fire_frame = -1


func serialize() -> Array:
	return items.map(func(it): return {"k": it["k"], "x": U.r2(it["x"]), "y": U.r2(it["y"]), "z": U.r2(it["z"]), "s": U.r2(it["s"])})


func load_data(arr: Variant) -> void:
	clear()
	if not arr is Array:
		return
	for it in arr:
		if it is Dictionary and KINDS.has(str(it.get("k", ""))):
			add(str(it["k"]), Vector3(float(it.get("x", 40)), float(it.get("y", 0)), float(it.get("z", 40))), float(it.get("s", 1.0)))


## Places an effect standing at `p` (`s` scales it). Returns its index.
func add(kind: String, p: Vector3, s := 1.0) -> int:
	if not KINDS.has(kind):
		return -1
	var view := _view()
	if view == 2:
		p.z = PixelWorld.LANE - 0.3
	elif view == 1:
		# Drawn at the depth of its own row, in front of what's north of it.
		p.y = PixelTopWorld.depth_y(p.z + 0.4)
	var n := build(kind, view, s, _style())
	n.position = p
	add_child(n)
	items.append({"k": kind, "x": p.x, "y": p.y, "z": p.z, "s": s})
	_nodes.append(n)
	_fire_frame = -1
	return items.size() - 1


func remove_at(i: int) -> void:
	if i < 0 or i >= items.size():
		return
	_nodes[i].queue_free()
	_nodes.remove_at(i)
	items.remove_at(i)
	_fire_frame = -1


## The effect nearest `p` within `r` metres (across the ground), or -1.
func index_near(p: Vector3, r := 1.5) -> int:
	var best := -1
	var bd := r
	for i in items.size():
		var it: Dictionary = items[i]
		var d := Vector2(float(it["x"]) - p.x, float(it["z"]) - p.z).length() if _view() != 2 else absf(float(it["x"]) - p.x) + absf(float(it["y"]) - p.y) * 0.5
		if d < bd:
			bd = d
			best = i
	return best


func node(i: int) -> Node3D:
	return _nodes[i] if i >= 0 and i < _nodes.size() else null


## Firelight flickers with the scene clock.
func animate(t: float) -> void:
	for i in _nodes.size():
		var n := _nodes[i]
		if n.has_meta("light"):
			var l: OmniLight3D = n.get_meta("light")
			l.light_energy = float(n.get_meta("energy")) * (1.0 + 0.12 * sin(t * 11.0 + i) + 0.07 * sin(t * 23.0 + i * 2.0) + 0.04 * sin(t * 37.0 + i * 5.0))


# ---------------------------------------------------------------- fires

## Every campfire's spot and size: placed ones plus campfire objects of the
## world itself (anime and low-poly props, top-view campfires).
func fires() -> Array:
	var f := Engine.get_process_frames()
	if f == _fire_frame:
		return _fire_cache
	_fire_frame = f
	_fire_cache = []
	for it in items:
		if it["k"] == "fire":
			_fire_cache.append([Vector3(it["x"], it["y"], it["z"]), float(it["s"])])
	var w: Variant = studio.world if studio else null
	if w != null:
		if w.get("is_top") == true:
			for o in w.objects:
				if str(o[0]) == "campfire":
					_fire_cache.append([Vector3(float(o[1]) + 0.5, 0.0, float(o[2]) + 0.5), 1.0])
		elif not w.is_voxel and w.get("is_side") != true:
			for p in w.props:
				if p.key == "fire":
					_fire_cache.append([Vector3(p.x, 0.0, p.z), float(p.s)])
	return _fire_cache


## The nearest effect of `kind` within `max_d` of `p` ("fire" counts the
## world's own campfires too), or null.
func nearest(kind: String, p: Vector3, max_d: float) -> Variant:
	var best: Variant = null
	var bd := max_d
	var src: Array = fires() if kind == "fire" else items.filter(func(it): return it["k"] == kind).map(func(it): return [Vector3(it["x"], it["y"], it["z"]), 1.0])
	for f in src:
		var q: Vector3 = f[0]
		var d := Vector2(q.x - p.x, q.z - p.z).length() if _view() != 2 else absf(q.x - p.x)
		if d < bd:
			bd = d
			best = q
	return best


## Standing too close to a fire: the way out (unit vector on the ground),
## else zero.
func heat_push(p: Vector3) -> Vector2:
	for f in fires():
		var q: Vector3 = f[0]
		var r := 0.8 * float(f[1])
		var d := Vector2(p.x - q.x, p.z - q.z) if _view() != 2 else Vector2(p.x - q.x, 0.0)
		if d.length() < r and absf(p.y - q.y) < 1.5:
			return d.normalized() if d.length() > 0.01 else Vector2(1, 0)
	return Vector2.ZERO


## Somewhere wanderers shouldn't head for (in or right by a fire).
func blocks(x: float, z: float) -> bool:
	for f in fires():
		var q: Vector3 = f[0]
		if Vector2(x - q.x, z - q.z).length() < 1.3 * float(f[1]):
			return true
	return false


# ---------------------------------------------------------------- building

func _view() -> int:
	if studio == null or studio.world == null:
		return 0
	if studio.world.get("is_top") == true:
		return 1
	if studio.world.get("is_side") == true:
		return 2
	return 0


func _style() -> String:
	return str(studio.style_key) if studio else "anime"


## An effect node for `view` (0 = 3D, 1 = 2D top, 2 = 2D side).
static func build(kind: String, view: int, s := 1.0, style := "anime") -> Node3D:
	var g := Node3D.new()
	g.name = "Fx_" + kind
	g.set_meta("fx", kind)
	var flat := view != 0
	var lite: bool = App.phone_gpu or App.device.get("quality", "high") == "low"
	match kind:
		"fire":
			g.add_child(_logs(view, style))
			g.add_child(emitter("flame", view, s, 12 if flat else (16 if lite else 24)))
			g.add_child(emitter("ember", view, s, 6 if flat else 10))
			g.add_child(emitter("fire_smoke", view, s, 4 if flat else (5 if lite else 8)))
			if not flat:
				var l := OmniLight3D.new()
				l.position = Vector3(0, 0.6 * s, 0)
				l.light_color = Color("ff9a48")
				l.omni_range = 7.0 * s
				l.omni_attenuation = 1.6
				# No shadows: an omni shadow renders the scene six more times.
				l.shadow_enabled = false
				l.light_bake_mode = Light3D.BAKE_DISABLED
				l.distance_fade_enabled = true
				l.distance_fade_begin = 40.0
				l.distance_fade_length = 10.0
				l.light_energy = 2.2
				g.add_child(l)
				g.set_meta("light", l)
				g.set_meta("energy", 2.2)
		"sparkles":
			g.add_child(emitter("sparkle", view, s, 16 if flat else 28))
		"smoke":
			g.add_child(emitter("smoke", view, s, 8 if flat else (10 if lite else 16)))
		"dust":
			g.add_child(emitter("dust", view, s, 18 if flat else (24 if lite else 40)))
	return g


## Particle settings per emitter: shader, kind, count is passed in.
const EMIT := {
	"flame": {"mix": false, "kind": 0, "rate": 1.4, "height": 1.05, "spread": 0.3, "size": 0.55, "a": "ffcf4a", "b": "ff4a0a", "strength": 1.7},
	"ember": {"mix": false, "kind": 1, "rate": 0.55, "height": 2.6, "spread": 0.25, "size": 0.05, "a": "ffd060", "b": "ff6a10", "strength": 1.0},
	"fire_smoke": {"mix": true, "kind": 2, "rate": 0.18, "height": 3.0, "spread": 0.2, "size": 0.7, "base": 0.9, "a": "6b6460", "b": "9a9590", "strength": 0.32},
	"sparkle": {"mix": false, "kind": 3, "rate": 0.35, "height": 2.2, "spread": 0.6, "size": 0.16, "a": "9ff3ff", "b": "f3a8ff", "strength": 1.0},
	"smoke": {"mix": true, "kind": 2, "rate": 0.12, "height": 5.0, "spread": 0.35, "size": 1.0, "base": 0.2, "a": "5a5550", "b": "a8a4a0", "strength": 0.45},
	"dust": {"mix": false, "kind": 4, "rate": 0.03, "height": 3.0, "spread": 2.2, "size": 0.035, "a": "fff3d6", "b": "ffe2b0", "strength": 0.5},
}


## Particle buffers and materials are shared by every effect of the same
## kind (their settings don't depend on where or how big the effect is), so
## placing another campfire creates no new GPU resources.
static var _mms := {}
static var _mats := {}


static func emitter(which: String, view: int, s: float, count: int) -> MultiMeshInstance3D:
	var e: Dictionary = EMIT[which]
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = _multimesh(which, count)
	mi.material_override = _material(which, view)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3.ONE * s
	var hgt: float = float(e["height"]) + float(e.get("base", 0.0)) + 1.0
	var w: float = float(e["spread"]) + 1.5
	mi.custom_aabb = AABB(Vector3(-w, -0.5, -w - hgt), Vector3(w * 2.0, hgt + 1.0, w * 2.0 + hgt))
	mi.name = which
	return mi


static func _multimesh(which: String, count: int) -> MultiMesh:
	var key := "%s|%d" % [which, count]
	if _mms.has(key):
		return _mms[key]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = count
	var r := U.rng(hash(which) & 0x7fffffff)
	for i in count:
		mm.set_instance_transform(i, Transform3D.IDENTITY)
		# Seeds spread evenly (with a jitter) so the stream never bunches up.
		mm.set_instance_custom_data(i, Color((i + r.next() * 0.8) / count, 0.8 + r.next() * 0.4, 0, 0))
	_mms[key] = mm
	return mm


static func _material(which: String, view: int) -> ShaderMaterial:
	var key := "%s|%d" % [which, view]
	if _mats.has(key):
		return _mats[key]
	var e: Dictionary = EMIT[which]
	var m := ShaderMaterial.new()
	m.shader = MIX if e["mix"] else ADD
	m.set_shader_parameter("kind", e["kind"])
	m.set_shader_parameter("rate", e["rate"])
	m.set_shader_parameter("height", e["height"])
	m.set_shader_parameter("spread", e["spread"])
	var sz: float = e["size"]
	if view != 0 and which in ["ember", "sparkle", "dust", "flame"]:
		sz *= 1.6
	m.set_shader_parameter("size", sz)
	m.set_shader_parameter("base_y", e.get("base", 0.0))
	m.set_shader_parameter("col_a", Color(str(e["a"])))
	m.set_shader_parameter("col_b", Color(str(e["b"])))
	m.set_shader_parameter("strength", e["strength"])
	m.set_shader_parameter("view", view)
	m.set_shader_parameter("px", PX if view != 0 else 0.0)
	m.render_priority = 2 if e["mix"] else 3
	_mats[key] = m
	return m


## Compiles the effect shaders before they're first needed: one of each is
## drawn for a few frames (invisibly) in front of `cam`, so the first
## campfire doesn't stall the scene. Call once at startup.
static func warm_up(cam: Node3D) -> void:
	var g := Node3D.new()
	g.name = "FxWarmUp"
	for which in ["flame", "fire_smoke"]:
		var mi := emitter(which, 0, 0.01, 1)
		mi.position = Vector3(0, 0, -2)
		g.add_child(mi)
	cam.add_child(g)
	for i in 4:
		await cam.get_tree().process_frame
	g.queue_free()


## The logs and stones under a campfire.
static func _logs(view: int, style: String) -> Node3D:
	if view != 0:
		return _pixel_logs(view)
	var g := Node3D.new()
	g.name = "logs"
	var prev := Kit.shade
	Kit.shade = Styles.get_style(style).get("shade", "lambert")
	var wood := Kit.mat("#6b4a2c")
	var char_ := Kit.mat("#2a1d14")
	var stone := Kit.mat("#8a8680")
	var glow := Kit.mat("#ff7a2a", {"glow": true})
	if style == "blocky":
		for k in 2:
			var l := Kit.box(0.9, 0.16, 0.16, wood, 0, 0.08 + k * 0.14, 0)
			l.rotation.y = k * PI / 2 + PI / 4
			g.add_child(l)
		g.add_child(Kit.box(0.3, 0.06, 0.3, glow, 0, 0.04, 0))
		for k in 8:
			var a := float(k) / 8 * TAU
			g.add_child(Kit.box(0.22, 0.18, 0.22, stone, cos(a) * 0.55, 0.09, sin(a) * 0.55))
	else:
		for k in 3:
			var l := Kit.cyl(0.07, 0.07, 0.85, 6, wood if k != 1 else char_, 0, 0.08, 0)
			l.rotation = Vector3(PI / 2, k * 1.05, 0)
			g.add_child(l)
		g.add_child(Kit.cyl(0.22, 0.26, 0.05, 8, glow, 0, 0.03, 0))
		for k in 8:
			var a := float(k) / 8 * TAU
			g.add_child(Kit.ball(0.11, stone, cos(a) * 0.52, 0.06, sin(a) * 0.52, 0))
	Kit.shade = prev
	return g


static var _logs_tex: ImageTexture


static func _pixel_logs(view: int) -> Node3D:
	if _logs_tex == null:
		var img := Image.create(16, 8, false, Image.FORMAT_RGBA8)
		var dark := Color("2a1d14")
		var wood := Color("7a5232")
		var hi := Color("a8743f")
		var ember := Color("ff6a1a")
		var stone := Color("8a8680")
		# Two crossed logs over a bed of embers, stones at the ends.
		for x in range(2, 14):
			var y := 3 + int(absf(x - 7.5) / 3.0)
			img.set_pixel(x, y, wood)
			img.set_pixel(x, y + 1, dark)
			img.set_pixel(x, y - 1, hi if x % 3 else wood)
		for x in range(4, 12):
			img.set_pixel(x, 6, ember if x % 2 else Color("ffb040"))
		for x in [0, 1, 14, 15]:
			img.set_pixel(x, 6, stone)
			img.set_pixel(x, 7, stone.darkened(0.3))
		_logs_tex = ImageTexture.create_from_image(img)
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = _logs_tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "logs"
	if view == 1:
		mi.rotation.x = -PI / 2
		mi.position = Vector3(0, 0.0, 0.1)
	else:
		mi.position = Vector3(0, 0.25, 0)
	return mi
