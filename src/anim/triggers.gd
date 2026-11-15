class_name Triggers
extends Node3D
## "When something happens" in a scene: someone walks into an area, or
## touches a character or an object, and a character reacts (says a line,
## does an action for a while, walks over). Checked every simulation tick,
## live and during the story, in cast order, so takes and exports replay
## the same. The areas show as rings on the ground while editing (never in
## a recording).
##
## A trigger: {when: "enter" | "touch", who: "" (anyone) | "@player" | name,
## x, z, r (the area, or the touched object's spot), target: a character's
## name when touching a character (the spot follows them), label: what was
## touched, actor: "@who" (whoever set it off) | "@target" | name, action:
## "say" | "walkto" | "runto" | a behaviour, text, dur, once}. Saved in the
## project as "triggers".

const WHEN := [["enter", "Someone walks into an area"], ["touch_actor", "Someone touches a character"], ["touch_spot", "Someone touches an object"]]
## What the one reacting can do (a subset of the story's actions).
const ACTIONS := [["say", "Say a line"], ["wave", "Wave"], ["flee", "Run away"], ["walkto", "Walk over"], ["runto", "Run over"], ["point", "Point"],
	["celebrate", "Celebrate"], ["laugh", "Laugh"], ["cry", "Cry"], ["dance", "Dance"], ["fight", "Fight"], ["sit", "Sit"]]
## How close counts as touching (metres, from the object's spot or the
## character's feet).
const TOUCH := 1.3
## A repeating trigger waits this long before it can go off again.
const COOLDOWN := 3.0

var studio: Node
var list: Array = []
## Per trigger: {inside: {actor id: true}, cd, done}.
var _state := {}
var _rings: Array[MeshInstance3D] = []
var _mat: StandardMaterial3D
var _mat_touch: StandardMaterial3D


func _ready() -> void:
	name = "Triggers"
	_mat = _ring_mat(Color(0.35, 0.85, 0.95, 0.7))
	_mat_touch = _ring_mat(Color(0.98, 0.76, 0.3, 0.75))


static func _ring_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.no_depth_test = true
	m.render_priority = 9
	return m


func load_data(arr: Variant) -> void:
	list = (arr as Array).filter(func(t): return t is Dictionary) if arr is Array else []
	reset()
	refresh()


func serialize() -> Array:
	return list


## Back to the start of a take: nothing has gone off yet.
func reset() -> void:
	_state.clear()


func clear() -> void:
	list = []
	reset()
	refresh()


func rename(old: String, new_name: String) -> void:
	for t in list:
		for k in ["who", "actor", "target"]:
			if str(t.get(k, "")) == old:
				t[k] = new_name


## Where a trigger is right now (a touched character's feet move).
func centre(t: Dictionary) -> Variant:
	if str(t.get("target", "")) != "":
		var a: Actor = studio.actor_by_name(str(t["target"]))
		return a.pos if a else null
	return Vector3(float(t.get("x", 40)), 0, float(t.get("z", 40)))


func radius(t: Dictionary) -> float:
	return float(t.get("r", 3.0)) if t.get("when", "enter") == "enter" else TOUCH


func _matches(t: Dictionary, a: Actor) -> bool:
	var who := str(t.get("who", ""))
	if who == "":
		return true
	if who == "@player":
		return a == studio.player
	return a.name == who


## One simulation tick: who has just come into each area, and what follows.
func tick(dt: float) -> void:
	for i in list.size():
		var t: Dictionary = list[i]
		if not _state.has(i):
			_state[i] = {"inside": {}, "cd": 0.0, "done": false}
		var st: Dictionary = _state[i]
		if st["done"]:
			continue
		st["cd"] = maxf(0.0, float(st["cd"]) - dt)
		var c: Variant = centre(t)
		if c == null:
			continue
		var r := radius(t)
		var inside: Dictionary = st["inside"]
		for a in studio.actors:
			if not _matches(t, a) or a.name == str(t.get("target", "")):
				continue
			var d := absf(a.pos.x - c.x) if studio.is_side() else Vector2(a.pos.x - c.x, a.pos.z - c.z).length()
			var now := d <= r
			if now and not inside.has(a.id):
				inside[a.id] = true
				if float(st["cd"]) <= 0.0:
					fire(t, a)
					st["cd"] = COOLDOWN
					if t.get("once", false):
						st["done"] = true
						break
			elif not now and inside.has(a.id) and d > r + 0.3:
				inside.erase(a.id)


## Makes the reaction happen; `who` set it off.
func fire(t: Dictionary, who: Actor) -> void:
	var name_ := str(t.get("actor", "@who"))
	var a: Actor = who
	if name_ == "@target":
		a = studio.actor_by_name(str(t.get("target", "")))
	elif name_ != "@who":
		a = studio.actor_by_name(name_)
	if a == null:
		return
	var action := str(t.get("action", "say"))
	var dur := float(t.get("dur", 3.0))
	var text := str(t.get("text", "")).strip_edges()
	var c: Variant = centre(t)
	if text != "":
		a.say(text, minf(dur, 4.0) if action != "say" else dur)
		a.spotlight_t = (minf(dur, 4.0) if action != "say" else dur) + 0.8
	if a == studio.player:
		# You're in control: only what you say comes from the trigger.
		return
	match action:
		"say":
			pass
		"walkto", "runto":
			if c is Vector3 and a != who:
				a.goto = {"x": c.x, "z": c.z, "run": action == "runto"}
		"flee":
			a.start_temp("flee", dur)
			a.threat = who if who != a else null
		_:
			a.goto = {}
			a.start_temp(action, dur)
			if action == "fight" and who != a:
				a.foe = who


## What the one reacting does, said of someone else ("Om waves") and of
## "they" or "you" ("they wave").
const DOES := {"say": ["says", "say"], "wave": ["waves", "wave"], "flee": ["runs away", "run away"], "walkto": ["walks over", "walk over"],
	"runto": ["runs over", "run over"], "point": ["points", "point"], "celebrate": ["celebrates", "celebrate"], "laugh": ["laughs", "laugh"],
	"cry": ["cries", "cry"], "dance": ["dances", "dance"], "fight": ["fights", "fight"], "sit": ["sits down", "sit down"]}


## One line saying what a trigger does, for the Story page.
static func describe(t: Dictionary) -> String:
	var who := str(t.get("who", ""))
	var who_s := "anyone" if who == "" else ("you" if who == "@player" else who)
	var plural := who == "@player"
	var when_s := ""
	match str(t.get("when", "enter")):
		"enter":
			when_s = "%s %s into the area" % [who_s, "walk" if plural else "walks"]
		_:
			var what := str(t.get("target", "")) if str(t.get("target", "")) != "" else str(t.get("label", "the object"))
			when_s = "%s %s %s" % [who_s, "touch" if plural else "touches", what]
	var actor := str(t.get("actor", "@who"))
	var actor_s := actor
	var they := false
	if actor == "@who":
		# Whoever set it off: "you" or "they" (anyone), else their name.
		actor_s = "you" if who == "@player" else ("they" if who == "" else who)
		they = who == "" or who == "@player"
	elif actor == "@target":
		actor_s = str(t.get("target", "they"))
	var action := str(t.get("action", "say"))
	var forms: Array = DOES.get(action, [action, action])
	var verb: String = forms[1] if they else forms[0]
	var text := str(t.get("text", "")).strip_edges()
	var out := "When %s, %s " % [when_s, actor_s]
	if action == "say":
		out += "%s “%s”" % [verb, text]
	else:
		out += verb + ((" and %s “%s”" % ["say" if they else "says", text]) if text != "" else "")
	return out + (" (first time only)" if t.get("once", false) else "")


# ---------------------------------------------------------------- rings

## Redraws the rings (after an edit).
func refresh() -> void:
	for n in _rings:
		n.queue_free()
	_rings.clear()
	if not is_inside_tree():
		return
	for t in list:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.93
		tm.outer_radius = 1.0
		tm.rings = 48
		tm.ring_segments = 4
		ring.mesh = tm
		ring.material_override = _mat if t.get("when", "enter") == "enter" else _mat_touch
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_rings.append(ring)
	_place()


func _process(_dt: float) -> void:
	# Never in a recording; touched characters' rings follow them.
	visible = studio != null and studio.in_studio and not studio.recorder.active and not list.is_empty()
	if visible:
		_place()


func _place() -> void:
	for i in mini(_rings.size(), list.size()):
		var t: Dictionary = list[i]
		var c: Variant = centre(t)
		var ring := _rings[i]
		ring.visible = c != null
		if c == null:
			continue
		var r := radius(t)
		var y: float = studio.world.ground_at(c.x, c.z) if studio.world and str(t.get("target", "")) == "" else c.y
		ring.position = Vector3(c.x, y + 0.06, c.z)
		ring.scale = Vector3(r, 0.04, r)
