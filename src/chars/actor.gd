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
## Woken from sleep by a hit: stays awake until the scene restarts or is
## told to sleep again.
var woken := false
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
## Imported faces: current weight of each feeling ("joy", "angry" ...).
var _expr := {}
## Library clip playing (see ModelRig.library_clip): its action and time.
var _clip_state := ""
var _clip_t := 0.0
## Dance style ("mix" cycles through all of them; see DANCES).
var dance_style := "mix"
## Say their lines every few seconds while doing their task (dancing,
## sitting, patrolling ...), not only when chatting.
var chat_busy := false

const DANCES := [["mix", "Mix"], ["hands_up", "Hands up"], ["sway", "Sway"], ["spin", "Spin"], ["robot", "Robot"],
	["disco", "Disco"], ["jacks", "Jumping jacks"], ["twist", "Twist"], ["clap", "Clap"]]
## Driven by timeline keyframes this tick (behaviours paused).
var keyed := false
## Seconds left in the current attack swing (0 = not attacking).
var attack_t := 0.0
## Seconds left of a hit flinch.
var hurt_t := 0.0
const ATTACK_TIME := 0.42
var knock_t := 0.0
## Seconds left of a reaction that changed what they do (running away,
## standing up for a friend); then they go back to `resume`.
var temp_t := 0.0
var resume := ""
## Feelings about others, by name: "friend", "rival" or "scared" (see
## FEELINGS). Friends greet each other, stand together and stand up for each
## other; rivals glare, won't hang out together and pick fights; the scared
## one runs away when the other comes close.
var rel := {}
## Held pose for the "pose" behaviour (see Poses); base_pose is the one from
## the scene setup (a timeline cue can show another for a while).
var pose := {}
var base_pose := {}
## A short reaction shown over what they're doing: an action ("laugh",
## "wave", "celebrate", "point") or "pose:<built-in key>", for react_t s.
var react_act := ""
var react_t := 0.0
## Can't react to another event until this runs out.
var react_cd := 0.0
## Looking at someone for a moment.
var look_who: Actor = null
var look_t := 0.0
## Who they fight or run from because of a reaction or a feeling.
var foe: Actor = null
var threat: Actor = null
## The group they're hanging out with (shared with its members; see
## Studio._update_groups), or {}.
var circle := {}
## When (actor clock) they last greeted or muttered at someone, by name.
var _met := {}
var _hot_t := 0.0
var _stuck_t := 0.0
## Saying a line from the story or a trigger (seconds left, with a short
## hold after): the 2D follow camera keeps them in view. Only the camera
## reads it.
var spotlight_t := 0.0
## "people", "mobs" or "animals" (from the look's preset).
var kind_group := "people"

const FEELINGS := [["", "No feeling"], ["friend", "Friend"], ["rival", "Rival"], ["scared", "Scared of"]]
## Behaviours calm enough to stop and react to what happens nearby.
const CALM := ["idle", "wander", "talk", "group", "gather", "sit", "dance", "patrol", "wave", "celebrate", "laugh", "point", "cry", "follow"]
const REACT_RANGE := 8.0
const GREET := ["Hey, %s!", "Hi, %s!", "Good to see you, %s!", "%s! Over here!"]
const RIVAL := ["Hmph.", "Not you again.", "What are you looking at?", "Keep walking."]
const DEFEND := ["Leave %s alone!", "Hey! Back off!", "I've got you, %s!"]
const GASP := ["Whoa!", "Hey, stop that!", "Did you see that?!", "Oh no!"]
const GLOAT := ["Ha! Serves you right.", "Hah!", "Ha ha!"]
const PANIC := ["Help!", "Run!", "Aaah!", "Monster!"]
const HOT := ["Ouch, hot!", "Too hot!", "Whoa, careful!"]


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
	dance_style = str(o.get("dance", "mix"))
	chat_busy = o.get("chat", false) == true
	rel = (o.get("rel", {}) as Dictionary).duplicate() if o.get("rel") is Dictionary else {}
	pose = (o.get("pose", {}) as Dictionary).duplicate(true) if o.get("pose") is Dictionary else {}
	base_pose = pose
	pos = Vector3(float(o.get("x", 40)), float(o.get("y", 0)), float(o.get("z", 40)))
	home = pos
	yaw = float(o.get("yaw", 0))
	t = App.sim_randf() * 100.0
	wait = App.sim_randf() * 2.0
	next_line = 3.0 + App.sim_randf() * 4.0


## What the character shows: a reaction for a moment, else their behaviour.
func shown() -> String:
	if react_t > 0.0 and react_act != "":
		return "pose" if react_act.begins_with("pose:") else react_act
	return behavior


## The pose shown for "pose" (a reaction's, else their own).
func shown_pose() -> Dictionary:
	if react_t > 0.0 and react_act.begins_with("pose:"):
		return Poses.builtin(react_act.substr(5))
	return pose


## Their feeling about `b` ("" when none).
func feeling(b: Actor) -> String:
	return str(rel.get(b.name, "")) if b else ""


func is_monster() -> bool:
	return kind_group == "mobs"


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
	kind_group = "people"
	if look.has("preset"):
		kind_group = str(Rigs.presets_for(studio.style_key).get(str(look["preset"]), {}).get("group", "people"))
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
	var closed := shown() == "sleep" or fmod(t + id * 1.7, 4.3) < 0.13
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


## The dance pose at time `t` for a style, shared by built-in and imported
## characters: arm and leg angles per slot (x swings forward/up when
## negative, y moves the limb out to the side), plus "lift" (bounce, a
## fraction of height), "spin", "sway" (metres sideways), "lean", "hyaw"
## and "hpitch". "mix" changes style every 4 seconds.
static func dance_pose(style: String, t: float) -> Dictionary:
	if style == "mix" or not DANCES.any(func(d): return d[0] == style):
		style = DANCES[1 + int(floor(t / 4.0)) % (DANCES.size() - 1)][0]
	var s8 := sin(t * 8.0)
	var b := absf(s8)
	var p := {"lift": 0.0, "spin": 0.0, "sway": 0.0, "lean": 0.0, "hyaw": sin(t * 4.0) * 0.2, "hpitch": s8 * 0.08}
	match style:
		"hands_up":
			p["upperArmL"] = Vector2(-2.7 + s8 * 0.35, 0.2)
			p["upperArmR"] = Vector2(-2.7 - s8 * 0.35, 0.2)
			p["lowerArmL"] = Vector2(-0.4, 0)
			p["lowerArmR"] = Vector2(-0.4, 0)
			p["upperLegL"] = Vector2(maxf(0.0, s8) * -0.5, 0)
			p["upperLegR"] = Vector2(maxf(0.0, -s8) * -0.5, 0)
			p["lowerLegL"] = Vector2(maxf(0.0, s8) * 0.7, 0)
			p["lowerLegR"] = Vector2(maxf(0.0, -s8) * 0.7, 0)
			p["lift"] = b * 0.05
		"sway":
			var s6 := sin(t * 6.0)
			p["upperArmL"] = Vector2(-0.3, 1.1 + s6 * 0.45)
			p["upperArmR"] = Vector2(-0.3, 1.1 - s6 * 0.45)
			p["lowerArmL"] = Vector2(-0.8, 0)
			p["lowerArmR"] = Vector2(-0.8, 0)
			p["lean"] = s6 * 0.16
			p["sway"] = s6 * 0.05
		"spin":
			p["upperArmL"] = Vector2(0.0, 1.45)
			p["upperArmR"] = Vector2(0.0, 1.45)
			p["spin"] = t * 5.0
			p["lift"] = absf(sin(t * 10.0)) * 0.03
		"robot":
			# Stiff, on the beat: one arm up, one down, switching each beat.
			var beat := int(floor(t * 2.0)) % 2
			p["upperArmL"] = Vector2(-1.57 if beat == 0 else -0.2, 0.25)
			p["upperArmR"] = Vector2(-0.2 if beat == 0 else -1.57, 0.25)
			p["lowerArmL"] = Vector2(-1.57 if beat == 1 else 0.0, 0)
			p["lowerArmR"] = Vector2(-1.57 if beat == 0 else 0.0, 0)
			p["hyaw"] = 0.5 if beat == 0 else -0.5
			p["hpitch"] = 0.0
			p["spin"] = 0.25 if beat == 0 else -0.25
		"disco":
			# Point up across, then down across; the other hand on the hip.
			var up := int(floor(t * 2.0)) % 2 == 0
			p["upperArmR"] = Vector2(-2.7, 0.55) if up else Vector2(-0.5, -0.35)
			p["lowerArmR"] = Vector2(0.0, 0)
			p["upperArmL"] = Vector2(-0.2, 0.6)
			p["lowerArmL"] = Vector2(-1.6, 0)
			p["lift"] = b * 0.03
			p["lean"] = 0.08 if up else -0.08
		"jacks":
			var j := (sin(t * 7.0) + 1.0) * 0.5
			p["upperArmL"] = Vector2(0.0, 0.15 + j * 2.7)
			p["upperArmR"] = Vector2(0.0, 0.15 + j * 2.7)
			p["upperLegL"] = Vector2(0.0, j * 0.35)
			p["upperLegR"] = Vector2(0.0, j * 0.35)
			p["lift"] = absf(sin(t * 7.0)) * 0.06
		"twist":
			var tw := sin(t * 9.0)
			p["upperArmL"] = Vector2(-0.6 - tw * 0.3, 0.3)
			p["upperArmR"] = Vector2(-0.6 + tw * 0.3, 0.3)
			p["lowerArmL"] = Vector2(-1.4, 0)
			p["lowerArmR"] = Vector2(-1.4, 0)
			p["upperLegL"] = Vector2(-0.25, 0)
			p["upperLegR"] = Vector2(-0.25, 0)
			p["lowerLegL"] = Vector2(0.5, 0)
			p["lowerLegR"] = Vector2(0.5, 0)
			p["spin"] = tw * 0.5
			p["lift"] = -0.03
		"clap":
			# Hands together over the head on the beat.
			var c := absf(sin(t * 6.0))
			p["upperArmL"] = Vector2(-2.5, 0.08 + c * 0.35)
			p["upperArmR"] = Vector2(-2.5, 0.08 + c * 0.35)
			p["lowerArmL"] = Vector2(-0.3, 0)
			p["lowerArmR"] = Vector2(-0.3, 0)
			p["lift"] = absf(sin(t * 6.0)) * 0.04
	return p


## Feelings on imported faces that have the shapes: joy while celebrating,
## laughing, dancing or waving; sorrow while crying; anger while fighting;
## surprise while fleeing. Eased in and out.
func _update_expr(dt: float) -> void:
	var shapes: Dictionary = rig.get("expr", {})
	if shapes.is_empty():
		return
	var want := ""
	var b := shown()
	match b:
		"celebrate", "laugh", "dance", "wave":
			want = "joy"
		"cry":
			want = "sorrow"
		"fight", "chase":
			want = "angry"
		"flee":
			want = "surprised"
		"pose":
			if react_act in ["pose:surprised", "pose:scared"] and react_t > 0.0:
				want = "surprised"
	if look_t > 0.0 and look_who and feeling(look_who) == "rival":
		want = "angry"
	var rate := 1.0 - exp(-dt * 6.0)
	for kind in shapes:
		var target := (0.6 if b == "wave" else 1.0) if kind == want else 0.0
		var cur := float(_expr.get(kind, 0.0))
		var nv := lerpf(cur, target, rate)
		if absf(nv - target) < 0.002:
			nv = target
		if nv == cur and _expr.has(kind):
			continue
		_expr[kind] = nv
		for s in shapes[kind]:
			if is_instance_valid(s[0]):
				(s[0] as MeshInstance3D).set_blend_shape_value(int(s[1]), nv)


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
	unlink()
	if not rig.is_empty():
		_free_rig()
	rig = {}


## Drops references to other characters (actors are reference counted, so
## two pointing at each other would never be freed).
func unlink() -> void:
	circle = {}
	foe = null
	threat = null
	look_who = null


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


## A line said on the character's own (chatting, noticing the player): shown
## only when the scene's "chatter" setting is on. The line is still picked
## either way, so turning it off doesn't change the rest of the take.
func chat(text: String, dur := 2.8) -> void:
	if App.settings.get("chatter", true):
		say(text, dur)


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
	_clip_state = ""
	_clip_t = 0.0
	_expr = {}
	temp_t = 0.0
	resume = ""
	react_act = ""
	react_t = 0.0
	react_cd = 0.0
	look_who = null
	look_t = 0.0
	foe = null
	threat = null
	circle = {}
	_met = {}
	_hot_t = 0.0
	_stuck_t = 0.0
	spotlight_t = 0.0
	knock_t = 0.0
	pose = base_pose
	var springs: SpringRig = rig.get("springs")
	if springs:
		springs.reset()
	if is_instance_valid(bubble):
		bubble.queue_free()
	bubble = null
	bubble_t = 0.0


func set_behavior(b: String, permanent := true) -> void:
	if partner:
		partner.partner = null
		partner = null
	behavior = b
	# A new action ends any reaction still showing (a laugh, a wave), or it
	# would play over what they were just told to do.
	react_t = 0.0
	react_act = ""
	if b != "fight":
		foe = null
	if b != "flee":
		threat = null
	if permanent:
		base_behavior = b
		woken = false
		home = pos
		temp_t = 0.0
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
	if react_t > 0.0:
		react_t -= dt
	if react_cd > 0.0:
		react_cd -= dt
	if _hot_t > 0.0:
		_hot_t -= dt
	if look_t > 0.0:
		look_t -= dt
		if look_t <= 0.0:
			look_who = null
	if knock_t > 0.0:
		knock_t -= dt
		move_body(dt)
		vel.x *= 0.85
		vel.z *= 0.85
		return
	if temp_t > 0.0:
		temp_t -= dt
		if temp_t <= 0.0:
			set_behavior(resume if resume != "" else _settled(), false)
			resume = ""
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
	_feelings()
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
						if studio.world.walkable(x, z) and not studio.fx.blocks(x, z):
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
			# Round the nearest campfire, else round the player.
			var fire: Variant = studio.fx.nearest("fire", pos, 15.0)
			var gp: Vector3 = fire if fire is Vector3 else studio.gather_point()
			var d := Vector2(gp.x - pos.x, gp.z - pos.z).length()
			var ring: float = (1.5 if fire is Vector3 else 1.2) + 0.25 * studio.count_behavior("gather")
			if d > ring:
				steer(gp.x, gp.z, 2.2, dt)
			else:
				face_to(gp.x, gp.z, dt)
				if player and pd < 6:
					look_at = player
		"follow":
			if player and player != self:
				# The player, or the house door they went through (top view).
				var goal: Vector3 = studio.follow_goal(self)
				if goal != player.pos:
					steer(goal.x, goal.z, 4.2, dt)
				elif pd > 2.6:
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
						chat(line(), 1.8)
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
			# Square up to whoever they're fighting (someone who hurt a
			# friend), else a rival nearby, else the nearest character, and
			# swing every so often.
			var opp: Actor = foe if foe and studio.actors.has(foe) else null
			var fd := 6.0
			if opp:
				fd = Vector2(opp.pos.x - pos.x, opp.pos.z - pos.z).length()
				if fd > 15.0:
					opp = null
					foe = null
					fd = 6.0
			if opp == null:
				var rd := 10.0
				for b in studio.actors:
					if b != self and feeling(b) == "rival":
						var dd := Vector2(b.pos.x - pos.x, b.pos.z - pos.z).length()
						if dd < rd:
							rd = dd
							opp = b
				if opp:
					fd = rd
			if opp == null:
				for b in studio.actors:
					if b == self:
						continue
					var dd := Vector2(b.pos.x - pos.x, b.pos.z - pos.z).length()
					if dd < fd:
						fd = dd
						opp = b
			if opp:
				if fd > 1.3:
					steer(opp.pos.x, opp.pos.z, 2.6, dt)
				else:
					face_to(opp.pos.x, opp.pos.z, dt, 8)
					wait -= dt
					if wait <= 0:
						wait = 0.9 + App.sim_randf() * 0.8
						attack()
				look_at = opp
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
					if feeling(b) == "rival" or b.feeling(self) == "rival":
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
							s.chat(s.line(), 2.4)
			elif player and player != self and pd < 6:
				face_to(player.pos.x, player.pos.z, dt)
				look_at = player
				next_line -= dt
				if next_line <= 0:
					next_line = 5.0 + App.sim_randf() * 4.0
					chat(line())
		"group":
			# Hanging out in a small circle: walk to their place in it, face
			# the middle and watch whoever is talking (Studio._update_groups
			# forms the circles and hands out turns to speak).
			if circle.is_empty():
				if player and player != self and pd < 6:
					face_to(player.pos.x, player.pos.z, dt)
					look_at = player
			else:
				var c: Vector3 = circle["c"]
				var slot: Vector2 = (circle["slots"] as Dictionary).get(id, Vector2(pos.x, pos.z))
				var d := Vector2(slot.x - pos.x, slot.y - pos.z).length()
				if d > 0.3:
					steer(slot.x, slot.y, 1.7, dt)
					# Something in the way (a well, a wall): stay where they
					# got to, if that's still near the circle.
					_stuck_t = _stuck_t + dt if blocked and not steppy() else 0.0
					if _stuck_t > 1.0 and Vector2(c.x - pos.x, c.z - pos.z).length() < 3.0:
						(circle["slots"] as Dictionary)[id] = Vector2(pos.x, pos.z)
						_stuck_t = 0.0
				else:
					face_to(c.x, c.z, dt, 4.0)
				var sp: Actor = circle.get("speaker")
				if sp and sp != self and studio.actors.has(sp):
					look_at = sp
				else:
					# Not talking: glance round the circle.
					var mem: Array = circle["m"]
					var o: Actor = mem[(int(t / 2.7) + id) % mem.size()]
					if o != self:
						look_at = o
		"pose":
			# Holding a pose: stand still where they are.
			pass
	if chat_busy and not behavior in ["talk", "group", "chase", "flee", "sleep"]:
		# "Chat while doing a task": a line every few seconds, whatever they do.
		next_line -= dt
		if next_line <= 0:
			next_line = 6.0 + App.sim_randf() * 4.0
			chat(line(), 2.4)
	if look_t > 0.0 and look_who and studio.actors.has(look_who) and not behavior in ["fight", "chase", "talk", "flee", "sleep", "pose"]:
		look_at = look_who
	if look_at == null and notice and player and player != self and pd < 7 and not behavior in ["dance", "flee", "sleep", "cry", "pose"]:
		look_at = player
	# Too close to a campfire: step back out of it.
	var heat: Vector2 = studio.fx.heat_push(pos)
	if heat != Vector2.ZERO and behavior != "sleep":
		vel.x = heat.x * 2.6
		vel.z = heat.y * 2.6
		if _hot_t <= 0.0 and App.settings.get("reactions", true):
			_hot_t = 6.0
			react("pose:surprised", 0.9)
			chat(HOT[int(App.sim_randf() * HOT.size()) % HOT.size()], 1.6)
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
	_update_expr(dt)
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
		# Talking ends (it never did for imported characters: after their
		# first line they kept the talking pose instead of their action).
		speak_t = maxf(speak_t - dt, 0.0)
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
	var act := shown()
	if quad and still and not ["idle", "wander", "follow", "chase", "flee", "patrol", "gather", "fight", "group", "pose"].has(act):
		match act:
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
		match act:
			"dance":
				var dp := dance_pose(dance_style, t)
				var al: Vector2 = dp.get("upperArmL", Vector2.ZERO)
				var ar: Vector2 = dp.get("upperArmR", Vector2.ZERO)
				arm_l.rotation = Vector3(al.x, 0, al.y)
				arm_r.rotation = Vector3(ar.x, 0, -ar.y)
				var ll: Vector2 = dp.get("upperLegL", Vector2.ZERO)
				var lr: Vector2 = dp.get("upperLegR", Vector2.ZERO)
				leg_l.rotation = Vector3(ll.x, 0, ll.y)
				leg_r.rotation = Vector3(lr.x, 0, -lr.y)
				model.position.y = float(dp["lift"]) * hgt
				model.position.x = float(dp["sway"])
				model.rotation.y = float(dp["spin"])
				upper.rotation.z = float(dp["lean"])
				hyaw = float(dp["hyaw"])
				hpitch = float(dp["hpitch"])
			"wave":
				arm_r.rotation = Vector3(0, 0, -2.5 + sin(t * 9) * 0.4)
			"sit":
				leg_l.rotation = Vector3(-1.5, -0.1, 0)
				leg_r.rotation = Vector3(-1.5, 0.1, 0)
				model.position.y = -float(m.get("sitDrop", 0.4))
				arm_l.rotation = Vector3(-0.5, 0, 0)
				arm_r.rotation = Vector3(-0.5, 0, 0)
			"idle", "gather", "talk", "group":
				# Subtle breathing so nobody stands frozen.
				upper.rotation.x = sin(t * 1.7) * 0.015
			"pose":
				# Held pose: upper arms and legs, body lean and drop, head
				# (built-in characters have no elbows or knees).
				var ps := shown_pose()
				var al := Poses.joint(ps, "upperArmL")
				var ar := Poses.joint(ps, "upperArmR")
				arm_l.rotation = Vector3(al.x, 0, al.y)
				arm_r.rotation = Vector3(ar.x, 0, -ar.y)
				var ll := Poses.joint(ps, "upperLegL")
				var lr := Poses.joint(ps, "upperLegR")
				leg_l.rotation = Vector3(ll.x, 0, ll.y)
				leg_r.rotation = Vector3(lr.x, 0, -lr.y)
				var spn := Poses.joint(ps, "spine")
				upper.rotation = Vector3(spn.x, 0, -spn.y)
				model.position.y = float(ps.get("lift", 0.0)) * hgt
				var hd := Poses.joint(ps, "head")
				hyaw = hd.x
				hpitch = hd.y + sin(t * 1.7) * 0.01
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
	if spotlight_t > 0.0:
		spotlight_t = maxf(0.0, spotlight_t - dt)
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


## What a character goes back to after fleeing: its own behaviour, except
## that someone woken from sleep stays up.
func _settled() -> String:
	return "idle" if woken and base_behavior == "sleep" else base_behavior


func on_hit(from: Actor) -> void:
	hurt_t = 0.35
	if behavior == "sleep":
		# A knock wakes a sleeper for good (this take).
		woken = true
		set_behavior("idle", false)
		if studio.player != self:
			var wl: String = ["Huh?! Who's there?", "I'm up, I'm up!", "Hey, I was sleeping!"][int(App.sim_randf() * 3.0) % 3]
			if App.settings.get("hit_lines", true):
				say(wl, 1.8)
		var p0 := pos - from.pos
		p0.y = 0
		if p0.length() > 0.01:
			yaw = atan2(-p0.x, -p0.z)
		return
	var push := pos - from.pos
	push.y = 0
	if push.length() > 0.01:
		push = push.normalized() * 5.0
	vel = Vector3(push.x, 3.5, push.z)
	knock_t = 0.25
	if studio.player != self:
		# The scene's random stream keeps fights the same on every take.
		var hl: String = ["Ow!", "Hey!", "Ouch!", "What was that for?!"][int(App.sim_randf() * 4.0) % 4]
		if App.settings.get("hit_lines", true):
			say(hl, 1.6)
		if base_behavior in ["idle", "wander", "talk", "sit", "dance", "wave", "gather", "group"] and App.sim_randf() < 0.5:
			start_temp("flee", 4.0)
			threat = from
		studio.emit_event("hit", pos, from, self)


## Does `b` for `dur` seconds (running away, standing up for a friend), then
## goes back to what they were doing.
func start_temp(b: String, dur: float) -> void:
	if temp_t <= 0.0:
		resume = behavior if not behavior in ["flee", "fight"] else _settled()
	set_behavior(b, false)
	temp_t = dur


## Shows an action over what they're doing for a moment ("laugh", "wave",
## "celebrate", "point" or "pose:<built-in key>").
func react(act: String, dur: float) -> void:
	react_act = act
	react_t = dur


func glance(b: Actor, dur: float) -> void:
	look_who = b
	look_t = dur


## Can react to things now (not the player, not busy with a script).
func can_react() -> bool:
	return App.settings.get("reactions", true) and studio.player != self and not keyed and goto.is_empty() and behavior in CALM and knock_t <= 0.0


## Feelings and monsters, checked every tick: run from who they fear and from
## monsters on the hunt, greet friends, glare and mutter at rivals.
func _feelings() -> void:
	if not can_react():
		return
	for b in studio.actors:
		if b == self or b.rig.is_empty():
			continue
		var d := Vector2(b.pos.x - pos.x, b.pos.z - pos.z).length()
		if d > 6.0:
			continue
		var f := feeling(b)
		var hunting: bool = b.is_monster() and not is_monster() and kind_group == "people" and b.behavior in ["chase", "fight"] and f != "friend" and b != studio.player
		if (f == "scared" and d < 4.5 and b.behavior != "sleep") or (hunting and d < 4.0):
			start_temp("flee", 4.0)
			threat = b
			if react_cd <= 0.0:
				chat(PANIC[int(App.sim_randf() * PANIC.size()) % PANIC.size()], 1.4)
			react_cd = 2.0
			studio.emit_event("panic", pos, b, self)
			return
		if f == "friend" and d < 4.0 and b.behavior != "sleep" and t - float(_met.get(b.name, -99.0)) > 30.0:
			_met[b.name] = t
			if speak_t <= 0.0:
				react("wave", 1.6)
				glance(b, 2.5)
				chat(GREET[int(App.sim_randf() * GREET.size()) % GREET.size()] % b.name, 2.0)
			return
		if f == "rival" and d < 5.0:
			if look_t <= 0.2:
				glance(b, 1.0)
			if t - float(_met.get(b.name, -99.0)) > 20.0:
				_met[b.name] = t
				if speak_t <= 0.0:
					chat(RIVAL[int(App.sim_randf() * RIVAL.size()) % RIVAL.size()], 1.8)


## Something happened nearby (see Studio.emit_event): someone was hit
## ("hit": src hit dst), someone ran off in a panic ("panic": dst ran from
## src) or someone is celebrating ("cheer": src). Bystanders look round,
## gasp, laugh, run away, stand up for a friend or join in.
func react_to(e: Dictionary) -> void:
	var src: Actor = e.get("src")
	var dst: Actor = e.get("dst")
	if self == src or self == dst or not can_react() or react_cd > 0.0:
		return
	var at: Vector3 = e["pos"]
	var d := Vector2(at.x - pos.x, at.z - pos.z).length()
	if d > REACT_RANGE:
		return
	var calm_kind := kind_group == "people"
	match str(e["k"]):
		"hit":
			react_cd = 3.0
			var fv := feeling(dst)
			var fa := feeling(src)
			if fv == "friend" and fa != "scared" and fa != "friend":
				start_temp("fight", 6.0)
				foe = src
				chat(DEFEND[int(App.sim_randf() * DEFEND.size()) % DEFEND.size()].replace("%s", dst.name), 1.8)
			elif fa == "scared" or (calm_kind and src.is_monster() and fa != "friend"):
				start_temp("flee", 4.0)
				threat = src
				chat(PANIC[int(App.sim_randf() * PANIC.size()) % PANIC.size()], 1.4)
			elif fv == "rival":
				react("laugh", 2.0)
				glance(dst, 2.5)
				chat(GLOAT[int(App.sim_randf() * GLOAT.size()) % GLOAT.size()], 1.6)
			else:
				glance(src, 3.0)
				var r := App.sim_randf()
				if r < 0.45:
					react("pose:surprised", 1.2)
					chat(GASP[int(App.sim_randf() * GASP.size()) % GASP.size()], 1.6)
				elif r < 0.7:
					react("point", 1.5)
		"panic":
			react_cd = 3.0
			glance(src, 3.0)
			if calm_kind and d < 6.0 and App.sim_randf() < 0.35 and feeling(src) != "friend":
				start_temp("flee", 3.5)
				threat = src
			else:
				react("pose:surprised", 1.0)
		"cheer":
			if feeling(src) == "friend" and d < REACT_RANGE:
				react_cd = 3.0
				react("celebrate", 2.5)
				glance(src, 2.5)
			elif feeling(src) != "rival" and d < 5.0 and App.sim_randf() < 0.3:
				react_cd = 3.0
				glance(src, 2.0)


func to_dict(is_player: bool) -> Dictionary:
	var d := {"name": name, "look": look, "behavior": base_behavior, "notice": notice, "lines": lines, "dance": dance_style, "chat": chat_busy,
		"pos": [U.r2(pos.x), U.r2(pos.y), U.r2(pos.z)], "yaw": U.r2(yaw), "player": is_player}
	if not rel.is_empty():
		d["rel"] = rel
	if not base_pose.is_empty():
		d["pose"] = base_pose
	return d
