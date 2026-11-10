class_name Actor
extends RefCounted
## A character in the scene: player or NPC. Holds simulation state, runs the
## behaviour state machine, moves with simple character physics and drives the
## procedural animation of its rig. Ported from the web `Actor`, `updateNPC`
## and `animateActor`, with extra behaviours (gather, patrol) and timeline cues.

const BUBBLE_SHADER := preload("res://src/shaders/bubble.gdshader")
const HW := 0.28
const HH := 1.75

static var _seq := 1

var studio: Node
var id: int
var name := "Someone"
var look := {}
var behavior := "idle"
## Behaviour from the scene setup; cues override `behavior` temporarily.
var base_behavior := "idle"
var notice := true
var lines: Array = []
var pos := Vector3.ZERO
var vel := Vector3.ZERO
var yaw := 0.0
var home := Vector3.ZERO
var on_ground := false
var blocked := false
var walk := 0.0
var head_yaw := 0.0
var head_pitch := 0.0
var t := 0.0
var target := {}
var wait := 0.0
var partner: Actor = null
var turn_t := 0.0
var speak_t := 0.0
var next_line := 3.0
var flip := false
var hy := 0.0
var hp := 0.0
var rig := {}
var bubble: Node3D = null
var bubble_t := 0.0
var tag: Node3D = null
var last_line := ""
## Directed walk target from a timeline cue ({} when none).
var goto := {}
var crouch := false
## Holding onto a ladder (Pixel 2D): no gravity while climbing.
var on_ladder := false
## In water deep enough to swim: floats head-up, moves slower.
var swimming := false
## Climbing out of the water onto a bank: a short hop that swimming doesn't
## hold down.
var _climb_t := 0.0
## Forward lean while swimming along (eased, so it never snaps).
var _swim_lean := 0.0
## Eye pieces to squash / eyelids to show / face shapes to drive when the
## eyes close (sleeping, blinking), and the floating "z Z z" over sleepers.
var _eyes: Array = []
var _lids: Array = []
var _eyes_closed := false
var _zzz: Node3D = null
## Talking mouths: [node, base scale] shown open, and the closed mouth nodes.
var _mouths: Array = []
var _mouth_shut: Array = []
var _mouth_open := 0.0
## Driven by timeline keyframes this tick (behaviours paused).
var keyed := false
## Seconds left in the current attack swing (0 = not attacking).
var attack_t := 0.0
## Seconds left of a hit flinch.
var hurt_t := 0.0
const ATTACK_TIME := 0.42
var knock_t := 0.0
var flee_t := 0.0


func _init(s: Node, o: Dictionary) -> void:
	studio = s
	id = _seq
	_seq += 1
	name = str(o.get("name", "Someone"))
	look = o.get("look", {})
	behavior = str(o.get("behavior", "idle"))
	base_behavior = behavior
	notice = o.get("notice", true) != false
	lines = (o.get("lines", []) as Array).duplicate()
	pos = Vector3(float(o.get("x", 40)), float(o.get("y", 0)), float(o.get("z", 40)))
	home = pos
	yaw = float(o.get("yaw", 0))
	t = App.sim_randf() * 100.0
	wait = App.sim_randf() * 2.0
	next_line = 3.0 + App.sim_randf() * 4.0


func k() -> float:
	return float(rig.get("scale", 1.0))


func head_y() -> float:
	return pos.y + (float(rig.get("headH", 1.5)) * k() if not rig.is_empty() else 1.5)


func height() -> float:
	return float(rig.get("height", 1.8)) * k()


func root() -> Node3D:
	return rig.get("root") as Node3D


func set_look(new_look: Dictionary) -> void:
	look = new_look
	var r: Dictionary
	if look.has("model"):
		r = ModelRig.build(look, studio.style_key)
	else:
		r = Rigs.build(look, studio.style_key)
	if not rig.is_empty():
		_free_rig()
	rig = r
	_find_eyes()
	var n := root()
	n.set_meta("actor_id", id)
	n.position = pos
	n.rotation.y = yaw
	studio.actor_layer.add_child(n)
	refresh_tag()


func _find_eyes() -> void:
	_eyes.clear()
	_lids.clear()
	_mouths.clear()
	_mouth_shut.clear()
	_mouth_open = 0.0
	_eyes_closed = false
	var stack: Array = [root()] if root() else []
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n.has_meta("eye") and n is Node3D:
			_eyes.append([n, (n as Node3D).scale])
		elif n.has_meta("lid"):
			_lids.append(n)
		elif n.has_meta("mouth_open") and n is Node3D:
			_mouths.append([n, (n as Node3D).scale])
		elif n.has_meta("mouth"):
			_mouth_shut.append(n)
		stack.append_array(n.get_children())


## Shut while sleeping, and a quick blink every few seconds otherwise.
func _update_eyes() -> void:
	var closed := behavior == "sleep" or fmod(t + id * 1.7, 4.3) < 0.13
	if closed == _eyes_closed:
		return
	_eyes_closed = closed
	for e in _eyes:
		var n: Node3D = e[0]
		var base: Vector3 = e[1]
		if is_instance_valid(n):
			n.scale = Vector3(base.x, base.y * (0.12 if closed else 1.0), base.z)
	for l in _lids:
		if is_instance_valid(l):
			(l as Node3D).visible = closed
	for b in rig.get("blink", []):
		if is_instance_valid(b[0]):
			(b[0] as MeshInstance3D).set_blend_shape_value(int(b[1]), 1.0 if closed else 0.0)


## Where the head is in the world right now (follows the rig, so it is
## right for a sleeper lying down too).
func head_point() -> Vector3:
	var sk: Skeleton3D = rig.get("skel")
	var bones: Dictionary = rig.get("bones", {})
	if sk and bones.has("head") and sk.is_inside_tree():
		return sk.global_transform * sk.get_bone_global_pose(int(bones["head"])).origin
	var h: Node3D = rig.get("head")
	if h and h.is_inside_tree() and rig.get("kind", "") != "sprite":
		return h.global_position
	return Vector3(pos.x, head_y(), pos.z)


## How open the mouth is while talking (0..1): syllables with short pauses
## between words. From the actor's clock, so takes repeat exactly.
func mouth_amount() -> float:
	if speak_t <= 0.0 or behavior == "sleep":
		return 0.0
	if fmod(t * 1.7 + id * 0.37, 1.6) > 1.3:
		return 0.0
	return clampf(absf(sin(t * 12.0 + id)) * (0.6 + 0.4 * sin(t * 4.3 + id * 2.0)), 0.0, 1.0)


func _update_mouth() -> void:
	var o := mouth_amount()
	if o == _mouth_open:
		return
	_mouth_open = o
	var open := o > 0.12
	for e in _mouths:
		var n: Node3D = e[0]
		if is_instance_valid(n):
			n.visible = open
			var base: Vector3 = e[1]
			n.scale = Vector3(base.x, base.y * maxf(0.3, o), base.z)
	for n in _mouth_shut:
		if is_instance_valid(n):
			(n as Node3D).visible = not open
	for b in rig.get("mouth", []):
		if is_instance_valid(b[0]):
			(b[0] as MeshInstance3D).set_blend_shape_value(int(b[1]), o * 0.8)


## Little z's drifting up from a sleeper, and the name tag / speech bubble
## brought down to the head while they lie there.
func _update_zzz() -> void:
	var asleep := behavior == "sleep" and not rig.is_empty()
	var flat: bool = studio.world != null and (studio.world.get("is_top") == true or studio.world.get("is_side") == true or rig.get("kind", "") == "sprite")
	var hp := head_point() if asleep and not flat else Vector3.ZERO
	if not rig.is_empty():
		var tag_y := float(rig["height"]) + 0.12
		var bub_y := float(rig["height"]) + (0.42 if App.device["names"] else 0.18)
		if is_instance_valid(tag):
			if asleep and not flat:
				tag.global_position = hp + Vector3(0, 0.4 * k(), 0)
			else:
				tag.position = Vector3(0, tag_y, 0)
		if is_instance_valid(bubble):
			if asleep and not flat:
				bubble.global_position = hp + Vector3(0, (0.7 if App.device["names"] else 0.45) * k(), 0)
			else:
				bubble.position = Vector3(0, bub_y, 0)
	if not asleep:
		if _zzz:
			_zzz.queue_free()
			_zzz = null
		return
	if _zzz == null:
		_zzz = Node3D.new()
		for i in 3:
			var l := Label3D.new()
			l.text = "z" if i != 1 else "Z"
			l.font_size = 40 + i * 10
			l.pixel_size = 0.0035
			l.outline_size = 12
			l.outline_modulate = Color(0.1, 0.12, 0.2, 0.9)
			l.modulate = Color(0.95, 0.97, 1.0)
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.render_priority = 5
			l.shaded = false
			_zzz.add_child(l)
		studio.actor_layer.add_child(_zzz)
	# From the head (north of the sprite on the top-view ground).
	var top_view: bool = studio.world != null and studio.world.get("is_top") == true
	var base: Vector3
	if top_view:
		base = pos + Vector3(0, 1.0, -0.8)
	elif flat:
		base = pos + Vector3(0.25, 0.75 * k(), 0)
	else:
		base = hp + Vector3(0.1, 0.2, 0) * k()
	for i in 3:
		var ph := fmod(t * 0.45 + i / 3.0, 1.0)
		var l: Label3D = _zzz.get_child(i)
		l.position = base + Vector3(ph * 0.45, ph * 0.9, 0) if not top_view else base + Vector3(ph * 0.45, 0, -ph * 0.9)
		l.modulate.a = sin(ph * PI)


func _free_rig() -> void:
	bubble = null
	tag = null
	var n := root()
	if is_instance_valid(n):
		n.queue_free()


func dispose() -> void:
	if _zzz:
		_zzz.queue_free()
		_zzz = null
	if partner:
		partner.partner = null
		partner = null
	if not rig.is_empty():
		_free_rig()
	rig = {}


func refresh_tag() -> void:
	if is_instance_valid(tag):
		tag.queue_free()
	tag = null
	if rig.is_empty() or not App.device["names"]:
		return
	tag = make_label(name, "tag")
	tag.position.y = float(rig["height"]) + 0.12
	tag.scale = Vector3.ONE / k()
	root().add_child(tag)


func say(text: String, dur := 2.8) -> void:
	if rig.is_empty() or text.is_empty():
		return
	if is_instance_valid(bubble):
		bubble.queue_free()
	bubble = make_label(text, "bubble")
	bubble.position.y = float(rig["height"]) + (0.42 if App.device["names"] else 0.18)
	bubble.scale = Vector3.ONE / k()
	root().add_child(bubble)
	bubble_t = dur
	speak_t = dur
	last_line = text
	studio.on_line_spoken(self, text, dur)


func line() -> String:
	if not lines.is_empty():
		return str(lines[int(App.sim_randf() * lines.size()) % lines.size()])
	return str(Rigs.CHATTER[int(App.sim_randf() * Rigs.CHATTER.size()) % Rigs.CHATTER.size()])


## Back to how the scene starts, at `p` facing `y`: every bit of state the
## simulation reads, so each take (and a resumed export) plays out exactly
## the same whatever happened before.
func reset_sim(p: Vector3, y: float, b: String) -> void:
	pos = p
	vel = Vector3.ZERO
	yaw = y
	goto = {}
	speak_t = 0.0
	set_behavior(b)
	home = pos
	t = 0.0
	wait = 0.5
	next_line = 3.0
	turn_t = 0.0
	flip = false
	keyed = false
	walk = 0.0
	target = {}
	partner = null
	hy = 0.0
	hp = 0.0
	head_yaw = 0.0
	head_pitch = 0.0
	on_ground = false
	blocked = false
	crouch = false
	on_ladder = false
	swimming = false
	_climb_t = 0.0
	_swim_lean = 0.0
	attack_t = 0.0
	hurt_t = 0.0
	last_line = ""
	if is_instance_valid(bubble):
		bubble.queue_free()
	bubble = null
	bubble_t = 0.0


func set_behavior(b: String, permanent := true) -> void:
	if partner:
		partner.partner = null
		partner = null
	behavior = b
	if permanent:
		base_behavior = b
		home = pos
	target = {}
	wait = 0.5


## Billboard text: a speech bubble or a name tag.
static func make_label(text: String, kind: String) -> Node3D:
	var n := Node3D.new()
	var font: Font = ThemeDB.fallback_font
	var fs := 56 if kind == "bubble" else 40
	var px := 0.0042 if kind == "bubble" else 0.0036
	var max_w := 760.0
	var sz := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, max_w, fs)
	var label := Label3D.new()
	label.text = text
	label.font_size = fs
	label.pixel_size = px
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.width = max_w
	label.modulate = Color("1c2433") if kind == "bubble" else Color.WHITE
	label.outline_size = 0
	label.render_priority = 3
	label.outline_render_priority = 2
	label.double_sided = true
	label.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var w := sz.x * px + (0.16 if kind == "bubble" else 0.1)
	var h := sz.y * px + (0.1 if kind == "bubble" else 0.05)
	var tail := 0.09 if kind == "bubble" else 0.0
	var q := QuadMesh.new()
	q.size = Vector2(w, h + tail)
	var m := ShaderMaterial.new()
	m.shader = BUBBLE_SHADER
	m.render_priority = 1
	m.set_shader_parameter("size", Vector2(w, h))
	m.set_shader_parameter("tail", tail)
	m.set_shader_parameter("radius", minf(h * 0.45, 0.09))
	if kind == "bubble":
		m.set_shader_parameter("color", Color(1, 1, 1, 0.96))
		m.set_shader_parameter("border", Color(0.11, 0.14, 0.2, 0.9))
	else:
		m.set_shader_parameter("color", Color(0.06, 0.08, 0.13, 0.55))
	var bg := MeshInstance3D.new()
	bg.mesh = q
	bg.material_override = m
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bg.position.y = -tail * 0.5
	n.add_child(bg)
	n.add_child(label)
	return n


# ---------------------------------------------------------------- movement

func move_body(dt: float) -> void:
	var w = studio.world
	var surf: float = w.water_surface(pos) if w.has_method("water_surface") else -1.0e9
	if w.get("is_top") == true:
		# Top view: water is crossed by swimming, slowly, at ground level.
		swimming = surf > -1.0e8
	else:
		# Swim where the water, down to the bottom, is deeper than about chest
		# height, and we're in it (not standing on a bank above it).
		var bottom: float = w.water_bottom(pos) if w.has_method("water_bottom") else w.ground_at(pos.x, pos.z)
		swimming = surf - bottom > height() * 0.62 and pos.y < surf
	if _climb_t > 0.0:
		_climb_t -= dt
		_move_world(dt, w)
		return
	if swimming:
		var hx := vel.x
		var hz := vel.z
		vel.x *= 0.55
		vel.z *= 0.55
		if w.get("is_top") != true:
			# Upright, head and shoulders above the water.
			var target := surf - height() * 0.72
			# Cancel gravity (the movers add it) and bob towards the float line.
			vel.y = clampf((target - pos.y) * 5.0, -4.0, 4.0) + sin(t * 3.0) * 0.15 + 24.0 * dt
		_move_world(dt, w)
		vel.x = hx
		vel.z = hz
		# Swimming into a bank: haul out onto it (clears a step above the water).
		if blocked and w.get("is_top") != true and Vector2(hx, hz).length() > 0.5:
			vel.y = 10.0
			_climb_t = 0.4
		return
	_move_world(dt, w)


func _move_world(dt: float, w) -> void:
	if side():
		# Pixel 2D: everyone lives on one lane in front of the tiles.
		pos.z = PixelWorld.LANE
		vel.z = 0.0
		if on_ladder:
			vel.y += 24.0 * dt
		_move_voxel(dt, w)
		pos.z = PixelWorld.LANE
	elif w.is_voxel:
		_move_voxel(dt, w)
	else:
		_move_terrain(dt, w)


func _move_voxel(dt: float, w) -> void:
	vel.y = maxf(vel.y - 24.0 * dt, -40.0)
	var steps := maxi(1, int(ceil(maxf(absf(vel.x), maxf(absf(vel.y), absf(vel.z))) * dt / 0.25)))
	var s := dt / steps
	blocked = false
	on_ground = false
	for _i in steps:
		pos.x += vel.x * s
		if w.box_hits(pos):
			pos.x -= vel.x * s
			blocked = true
		pos.z += vel.z * s
		if w.box_hits(pos):
			pos.z -= vel.z * s
			blocked = true
		pos.y += vel.y * s
		if w.box_hits(pos):
			if vel.y < 0:
				var old := pos.y - vel.y * s
				pos.y = floorf(pos.y) + 1.0
				if w.box_hits(pos):
					pos.y = old
				on_ground = true
			else:
				pos.y -= vel.y * s
			vel.y = 0.0
	if w.box_hits(pos):
		pos.y += 1.0
		vel.y = 0.0


func _move_terrain(dt: float, w) -> void:
	vel.y = maxf(vel.y - 24.0 * dt, -40.0)
	blocked = false
	# Already overlapping something (spawned inside, a prop placed on top of
	# us, deep water)? Let moves through so we can walk back out.
	var stuck: bool = w.body_blocked(pos)
	var tv := Vector3(pos.x + vel.x * dt, pos.y, pos.z)
	if not stuck and w.body_blocked(tv):
		blocked = true
	else:
		pos.x = tv.x
	tv = Vector3(pos.x, pos.y, pos.z + vel.z * dt)
	if not stuck and w.body_blocked(tv):
		blocked = true
	else:
		pos.z = tv.z
	pos.y += vel.y * dt
	var g: float = w.ground_at(pos.x, pos.z)
	if pos.y <= g or (on_ground and vel.y <= 0 and pos.y - g < 0.35):
		pos.y = g
		vel.y = 0.0
		on_ground = true
	else:
		on_ground = false


## The world is the side-on Pixel 2D one.
func side() -> bool:
	return studio.world != null and studio.world.get("is_side") == true


## Worlds where characters hop up one-tile steps (voxel and Pixel 2D).
func steppy() -> bool:
	return studio.world != null and (studio.world.is_voxel or side())


func steer(tx: float, tz: float, speed: float, dt: float) -> float:
	if side():
		tz = pos.z
	var dx := tx - pos.x
	var dz := tz - pos.z
	var d := sqrt(dx * dx + dz * dz)
	if d < 0.05:
		vel.x = 0
		vel.z = 0
		return d
	var want := atan2(dx, dz)
	yaw += clampf(U.wrap_a(want - yaw), -8 * dt, 8 * dt)
	var sp := speed * clampf(d, 0.3, 1.0)
	vel.x = sin(yaw) * sp
	vel.z = cos(yaw) * sp
	if blocked and on_ground and steppy():
		vel.y = 7.6
	return d


func face_to(x: float, z: float, dt: float, rate := 5.0) -> void:
	var want := atan2(x - pos.x, z - pos.z)
	yaw += clampf(U.wrap_a(want - yaw), -rate * dt, rate * dt)


# ---------------------------------------------------------------- behaviour

func update_npc(dt: float) -> void:
	if knock_t > 0.0:
		knock_t -= dt
		move_body(dt)
		vel.x *= 0.85
		vel.z *= 0.85
		return
	if flee_t > 0.0:
		flee_t -= dt
		if flee_t <= 0.0:
			set_behavior(base_behavior, false)
	vel.x = 0
	vel.z = 0
	var look_at: Actor = null
	var player: Actor = studio.player
	var size := float(Styles.SIZE)
	var pd := 99.0
	if player:
		pd = Vector2(player.pos.x - pos.x, player.pos.z - pos.z).length()
	if not goto.is_empty():
		var d := steer(goto["x"], goto["z"], 3.4 if goto.get("run", false) else 1.8, dt)
		if d < 0.4:
			goto = {}
		move_body(dt)
		_head_idle()
		return
	match behavior:
		"wander":
			if target.is_empty():
				wait -= dt
				if wait <= 0:
					for _k in 6:
						var ang := App.sim_randf() * TAU
						var dd := 2.0 + App.sim_randf() * 6.0
						var x := clampf(pos.x + cos(ang) * dd, 1.5, size - 1.5)
						var z := clampf(pos.z + sin(ang) * dd, 1.5, size - 1.5)
						if studio.world.walkable(x, z):
							target = {"x": x, "z": z, "t": 8.0}
							break
					wait = 1.0
			else:
				target["t"] -= dt
				var d := steer(target["x"], target["z"], 1.7, dt)
				if d < 0.5 or target["t"] < 0 or (blocked and not steppy()):
					target = {}
					wait = 1.0 + App.sim_randf() * 3.5
		"patrol":
			# Walk a loop of four points around the spot the actor was placed.
			if target.is_empty():
				var idx := int(wait) % 4 if wait >= 0 else 0
				var off: Vector2 = [Vector2(3, 0), Vector2(0, 3), Vector2(-3, 0), Vector2(0, -3)][idx]
				target = {"x": clampf(home.x + off.x, 1.5, size - 1.5), "z": clampf(home.z + off.y, 1.5, size - 1.5), "t": 10.0, "i": idx}
			else:
				target["t"] -= dt
				var d := steer(target["x"], target["z"], 1.5, dt)
				if d < 0.5 or target["t"] < 0:
					wait = float(int(target["i"]) + 1)
					target = {}
		"gather":
			var gp: Vector3 = studio.gather_point()
			var d := Vector2(gp.x - pos.x, gp.z - pos.z).length()
			var ring: float = 1.2 + 0.25 * studio.count_behavior("gather")
			if d > ring:
				steer(gp.x, gp.z, 2.2, dt)
			else:
				face_to(gp.x, gp.z, dt)
				if player and pd < 6:
					look_at = player
		"follow":
			if player and player != self:
				if pd > 2.6:
					steer(player.pos.x, player.pos.z, 4.2 if pd > 6 else 2.4, dt)
				else:
					face_to(player.pos.x, player.pos.z, dt)
				look_at = player
		"chase":
			if player and player != self:
				if pd > 1.25:
					steer(player.pos.x, player.pos.z, 3.4 if pd > 8 else 2.6, dt)
				else:
					face_to(player.pos.x, player.pos.z, dt, 8)
				look_at = player
				if pd < 1.6:
					next_line -= dt
					if next_line <= 0:
						next_line = 4.0 + App.sim_randf() * 3.0
						say(line(), 1.8)
		"flee":
			var threat: Actor = studio.nearest_threat(self)
			if threat:
				var tdx := pos.x - threat.pos.x
				var tdz := pos.z - threat.pos.z
				var l := maxf(sqrt(tdx * tdx + tdz * tdz), 0.001)
				steer(clampf(pos.x + tdx / l * 4, 1.5, size - 1.5), clampf(pos.z + tdz / l * 4, 1.5, size - 1.5), 4.4, dt)
			else:
				hy = 0
		"fight":
			# Square up to the nearest character and swing every so often.
			var foe: Actor = null
			var fd := 6.0
			for b in studio.actors:
				if b == self:
					continue
				var dd := Vector2(b.pos.x - pos.x, b.pos.z - pos.z).length()
				if dd < fd:
					fd = dd
					foe = b
			if foe:
				if fd > 1.3:
					steer(foe.pos.x, foe.pos.z, 2.6, dt)
				else:
					face_to(foe.pos.x, foe.pos.z, dt, 8)
					wait -= dt
					if wait <= 0:
						wait = 0.9 + App.sim_randf() * 0.8
						attack()
				look_at = foe
		"talk":
			if partner == null or partner.behavior != "talk" or not studio.actors.has(partner):
				partner = null
				var best: Actor = null
				var bd := 16.0
				for b in studio.actors:
					if b == self or b == player or b.behavior != "talk":
						continue
					if b.partner and b.partner != self:
						continue
					var dd := pos.distance_to(b.pos)
					if dd < bd:
						bd = dd
						best = b
				if best:
					partner = best
					best.partner = self
			var p := partner
			if p:
				var d := Vector2(p.pos.x - pos.x, p.pos.z - pos.z).length()
				if d > 2.1:
					steer(p.pos.x, p.pos.z, 1.8, dt)
				else:
					face_to(p.pos.x, p.pos.z, dt)
					look_at = p
					if id < p.id:
						turn_t -= dt
						if turn_t <= 0:
							turn_t = 2.6 + App.sim_randf() * 1.4
							flip = not flip
							var s := self if flip else p
							s.say(s.line(), 2.4)
			elif player and player != self and pd < 6:
				face_to(player.pos.x, player.pos.z, dt)
				look_at = player
				next_line -= dt
				if next_line <= 0:
					next_line = 5.0 + App.sim_randf() * 4.0
					say(line())
	if look_at == null and notice and player and player != self and pd < 7 and not behavior in ["dance", "flee", "sleep", "cry"]:
		look_at = player
	move_body(dt)
	if look_at:
		var tx := look_at.pos.x - pos.x
		var tz := look_at.pos.z - pos.z
		var ty := look_at.head_y() - head_y()
		var rel := U.wrap_a(atan2(tx, tz) - yaw)
		if absf(rel) > 1.1 and Vector2(vel.x, vel.z).length() < 0.1 and behavior != "sit":
			yaw += clampf(rel, -3 * dt, 3 * dt)
			rel = U.wrap_a(atan2(tx, tz) - yaw)
		hy = clampf(rel, -1.1, 1.1)
		hp = clampf(-atan2(ty, Vector2(tx, tz).length()), -0.6, 0.6)
	else:
		_head_idle()


func _head_idle() -> void:
	hy = 0.0 if behavior == "sleep" else sin(t * 0.45 + id) * 0.45
	hp = 0.0


# ---------------------------------------------------------------- animation

func animate(dt: float, is_player: bool) -> void:
	if rig.is_empty():
		return
	var m := rig
	t += dt
	_update_eyes()
	_update_mouth()
	_update_zzz()
	var sp := Vector2(vel.x, vel.z).length()
	walk += sp * dt * 2.4 / maxf(0.6, k())
	var amt := minf(1.0, sp / 3.2)
	var sw := sin(walk) * 0.9 * amt
	if m.get("kind", "") == "sprite":
		attack_t = maxf(attack_t - dt, 0.0)
		hurt_t = maxf(hurt_t - dt, 0.0)
		if speak_t > 0.0:
			speak_t = maxf(speak_t - dt, 0.0)
		PixelSprites.animate(self, dt, sp)
		_tick_bubble(dt)
		return
	var model: Node3D = m["model"]
	var upper: Node3D = m["upper"]
	var arm_l: Node3D = m["armL"]
	var arm_r: Node3D = m["armR"]
	var leg_l: Node3D = m["legL"]
	var leg_r: Node3D = m["legR"]
	var head: Node3D = m["head"]
	var r := root()
	if m.get("kind", "human") == "model":
		r.position = pos
		r.rotation = Vector3(0, yaw, 0)
		attack_t = maxf(attack_t - dt, 0.0)
		hurt_t = maxf(hurt_t - dt, 0.0)
		ModelRig.animate(self, dt, sp, is_player)
		_tick_bubble(dt)
		return
	leg_l.rotation = Vector3(sw, 0, 0)
	leg_r.rotation = Vector3(-sw, 0, 0)
	arm_l.rotation = Vector3(-sw * 0.85, 0, 0.05 + sin(t * 1.6) * 0.03)
	arm_r.rotation = Vector3(sw * 0.85, 0, -0.05 - sin(t * 1.6) * 0.03)
	model.position = Vector3.ZERO
	model.rotation = Vector3.ZERO
	upper.rotation = Vector3.ZERO
	var hyaw := hy
	var hpitch := hp
	var quad: bool = m.get("kind", "human") == "quad"
	if quad:
		arm_l.rotation.z = 0
		arm_r.rotation.z = 0
	elif not on_ground:
		arm_l.rotation.z = 0.5
		arm_r.rotation.z = -0.5
	if m.get("pose", "") == "zombie":
		arm_l.rotation = Vector3(-1.45 + sin(t * 2) * 0.05 - sw * 0.1, 0, 0.06)
		arm_r.rotation = Vector3(-1.45 - sin(t * 2) * 0.05 + sw * 0.1, 0, -0.06)
	if m.get("float", false):
		model.position.y = sin(t * 2.2) * 0.09
		if m.get("spinUpper", false):
			upper.rotation.y = t * 1.4
	if m.get("hop", false):
		var h2 := absf(sin(walk * 1.3)) * amt
		model.position.y = h2 * 0.35
		upper.scale = Vector3(1 + (1 - h2) * amt * 0.12, 1 - (1 - h2) * amt * 0.15, 1 + (1 - h2) * amt * 0.12)
	var still := sp < 0.2 and not is_player
	if quad and still and not ["idle", "wander", "follow", "chase", "flee", "patrol", "gather", "fight"].has(behavior):
		match behavior:
			"dance":
				model.position.y = absf(sin(t * 8)) * 0.18
				model.rotation.y = sin(t * 3) * 0.7
				hyaw = sin(t * 6) * 0.3
			"sit":
				leg_l.rotation.x = -1.1
				leg_r.rotation.x = -1.1
				model.rotation.x = -0.3
				model.position.y = -float(m.get("sitDrop", 0.1))
			"wave":
				arm_r.rotation.x = -1.2 + sin(t * 9) * 0.35
			"talk":
				if speak_t > 0:
					hpitch += sin(t * 9) * 0.12
			"sleep":
				leg_l.rotation.x = -1.3
				leg_r.rotation.x = -1.3
				arm_l.rotation.x = 1.3
				arm_r.rotation.x = 1.3
				model.position.y = -float(m.get("sitDrop", 0.1)) * 1.6
				hyaw = 0.4
				hpitch = 0.5
			"celebrate":
				model.position.y = absf(sin(t * 7)) * 0.2
				model.rotation.y = sin(t * 3.5) * 0.35
			"laugh", "cry":
				hpitch += sin(t * 15) * 0.08 + (0.35 if behavior == "cry" else -0.2)
			"point":
				hpitch -= 0.15
		if speak_t > 0:
			speak_t -= dt
		_finish_head(dt, hyaw, hpitch, head, r)
		_tick_bubble(dt)
		return
	if quad and speak_t > 0:
		speak_t = maxf(speak_t - dt, 0)
		hpitch += sin(t * 9) * 0.12
	if still:
		var hgt: float = m.get("height", 1.8)
		match behavior:
			"dance":
				var style := int(floor(t / 4.0)) % 3
				if style == 0:
					arm_l.rotation = Vector3(-2.7 + sin(t * 8) * 0.35, 0, 0)
					arm_r.rotation = Vector3(-2.7 - sin(t * 8) * 0.35, 0, 0)
					model.position.y = absf(sin(t * 8)) * hgt * 0.05
					leg_l.rotation.x = maxf(0, sin(t * 8)) * -0.5
					leg_r.rotation.x = maxf(0, -sin(t * 8)) * -0.5
				elif style == 1:
					upper.rotation.z = sin(t * 6) * 0.16
					arm_l.rotation = Vector3(0, 0, 0.9 + sin(t * 6) * 0.5)
					arm_r.rotation = Vector3(0, 0, -0.9 + sin(t * 6) * 0.5)
					model.position.x = sin(t * 6) * 0.05
				else:
					model.rotation.y = t * 5
					arm_l.rotation = Vector3(0, 0, 1.45)
					arm_r.rotation = Vector3(0, 0, -1.45)
					model.position.y = absf(sin(t * 10)) * hgt * 0.03
				hyaw = sin(t * 4) * 0.25
				hpitch = sin(t * 8) * 0.1
			"wave":
				arm_r.rotation = Vector3(0, 0, -2.5 + sin(t * 9) * 0.4)
			"sit":
				leg_l.rotation = Vector3(-1.5, -0.1, 0)
				leg_r.rotation = Vector3(-1.5, 0.1, 0)
				model.position.y = -float(m.get("sitDrop", 0.4))
				arm_l.rotation = Vector3(-0.5, 0, 0)
				arm_r.rotation = Vector3(-0.5, 0, 0)
			"idle", "gather", "talk":
				# Subtle breathing so nobody stands frozen.
				upper.rotation.x = sin(t * 1.7) * 0.015
			"sleep":
				# Lie on their back, centred on where they stood.
				model.rotation.x = -PI / 2
				model.position = Vector3(0, hgt * 0.08 + sin(t * 1.2) * 0.004, hgt * 0.45)
				leg_l.rotation = Vector3.ZERO
				leg_r.rotation = Vector3.ZERO
				arm_l.rotation = Vector3(0, 0, 0.12)
				arm_r.rotation = Vector3(0, 0, -0.12)
				hyaw = 0.0
				hpitch = 0.0
			"celebrate":
				var j := absf(sin(t * 7))
				model.position.y = j * hgt * 0.07
				arm_l.rotation = Vector3(-2.9 + sin(t * 14) * 0.25, 0, 0.25)
				arm_r.rotation = Vector3(-2.9 - sin(t * 14) * 0.25, 0, -0.25)
				leg_l.rotation.x = -j * 0.3
				leg_r.rotation.x = -j * 0.3
				hpitch = -0.25
			"laugh":
				# Lean back, hands on the belly, shaking.
				upper.rotation.x = -0.12 + sin(t * 16) * 0.05
				arm_l.rotation = Vector3(-0.55, 0, -0.18)
				arm_r.rotation = Vector3(-0.55, 0, 0.18)
				hpitch = -0.35 + sin(t * 16) * 0.08
				model.position.y = absf(sin(t * 16)) * hgt * 0.01
			"cry":
				# Head down, hands to the face, shoulders shaking.
				upper.rotation.x = 0.18 + sin(t * 18) * 0.025
				arm_l.rotation = Vector3(-2.3, 0, -0.55)
				arm_r.rotation = Vector3(-2.3, 0, 0.55)
				hyaw = 0.0
				hpitch = 0.45
			"point":
				arm_r.rotation = Vector3(-1.55, 0, 0)
				hpitch = 0.0
			"fight":
				# Guard up between swings.
				arm_l.rotation = Vector3(-1.3, 0, 0.35)
				arm_r.rotation = Vector3(-1.1, 0, -0.35)
				upper.rotation.x = 0.08
	if speak_t > 0 and not quad:
		speak_t -= dt
		if m.get("pose", "") != "zombie":
			arm_r.rotation.x = -0.6 + sin(t * 5) * 0.35
		hpitch += sin(t * 7) * 0.06
	if swimming and not quad:
		# Upright: arms pull through the water, legs kick. Swimming along adds
		# a forward lean that eases in and out.
		var moving := sp > 0.3
		_swim_lean = lerpf(_swim_lean, 0.4 if moving else 0.08, 1.0 - exp(-dt * 4.0))
		var st := t * (5.0 if moving else 3.0)
		arm_l.rotation = Vector3(-1.2 + sin(st) * 0.9, 0, 0.9 + sin(st) * 0.5)
		arm_r.rotation = Vector3(-1.2 - sin(st) * 0.9, 0, -0.9 - sin(st) * 0.5)
		leg_l.rotation = Vector3(sin(st * 1.6) * 0.5, 0, 0)
		leg_r.rotation = Vector3(-sin(st * 1.6) * 0.5, 0, 0)
		upper.rotation.x = _swim_lean
		model.position.y = 0.0
		hpitch = -0.2 - _swim_lean * 0.5
	elif _swim_lean > 0.0:
		_swim_lean = 0.0
	if crouch and not quad:
		var drop: float = float(m.get("sitDrop", 0.4)) * 0.45
		model.position.y -= drop
		leg_l.rotation.x = minf(leg_l.rotation.x, 0.0) - 0.55
		leg_r.rotation.x = minf(leg_r.rotation.x, 0.0) - 0.55
		upper.rotation.x += 0.32
		hpitch -= 0.25
	if attack_t > 0.0:
		attack_t = maxf(attack_t - dt, 0.0)
		var k := 1.0 - attack_t / ATTACK_TIME
		# Wind up over the shoulder, then slash down and across.
		var swing := -2.6 + smoothstep(0.15, 0.6, k) * 3.4
		arm_r.rotation = Vector3(swing, 0, -0.35 + smoothstep(0.2, 0.6, k) * 0.6)
		upper.rotation.y = sin(k * PI) * 0.45
		upper.rotation.x += sin(k * PI) * 0.12
	if hurt_t > 0.0:
		hurt_t = maxf(hurt_t - dt, 0.0)
		upper.rotation.x -= sin(hurt_t / 0.35 * PI) * 0.35
		hpitch -= 0.3 * hurt_t
	var cape: Node3D = m.get("cape")
	if cape:
		cape.rotation.x = 0.14 + amt * 0.5 + sin(t * 3) * 0.03
	_finish_head(dt, hyaw, hpitch, head, r)
	_tick_bubble(dt)


func _finish_head(dt: float, hyaw: float, hpitch: float, head: Node3D, r: Node3D) -> void:
	head_yaw = lerpf(head_yaw, hyaw, 1.0 - exp(-dt * 8))
	head_pitch = lerpf(head_pitch, hpitch, 1.0 - exp(-dt * 8))
	head.rotation = Vector3(head_pitch, head_yaw, 0)
	r.position = pos
	r.rotation.y = yaw


func _tick_bubble(dt: float) -> void:
	if bubble:
		bubble_t -= dt
		if bubble_t <= 0:
			if is_instance_valid(bubble):
				bubble.queue_free()
			bubble = null


## Swing at whoever is in front; they flinch, get knocked back and react.
func attack() -> void:
	if attack_t > 0.0 or rig.is_empty():
		return
	attack_t = ATTACK_TIME
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	for b in studio.actors:
		if b == self:
			continue
		var d: Vector3 = b.pos - pos
		d.y = 0
		var dist := d.length()
		if dist < 1.8 and (dist < 0.4 or d.normalized().dot(fwd) > 0.35):
			b.on_hit(self)


func on_hit(from: Actor) -> void:
	hurt_t = 0.35
	var push := pos - from.pos
	push.y = 0
	if push.length() > 0.01:
		push = push.normalized() * 5.0
	vel = Vector3(push.x, 3.5, push.z)
	knock_t = 0.25
	if studio.player != self:
		# The scene's random stream keeps fights the same on every take.
		say(["Ow!", "Hey!", "Ouch!", "What was that for?!"][int(App.sim_randf() * 4.0) % 4], 1.6)
		if base_behavior in ["idle", "wander", "talk", "sit", "dance", "wave", "gather"] and App.sim_randf() < 0.5:
			set_behavior("flee", false)
			flee_t = 4.0


func to_dict(is_player: bool) -> Dictionary:
	return {"name": name, "look": look, "behavior": base_behavior, "notice": notice, "lines": lines,
		"pos": [U.r2(pos.x), U.r2(pos.y), U.r2(pos.z)], "yaw": U.r2(yaw), "player": is_player}
