class_name Templates
## Starting points for a new scene: world layouts (forest, mountain pass,
## night town, great hall) and ready-made scenes to remix, each a layout
## plus a cast with behaviours and feelings, story moments, mood and
## effects. Listed under "Templates" when naming a new scene.
##
## Keys: "world:<layout>" or "scene:<key>". Every style gets the layouts its
## world type can make (see each world's LAYOUTS) and the scenes whose
## layout and cast it has.

const WORLDS := {
	"forest": {"name": "Forest", "blurb": "Deep woods round a clearing", "icon": "tree"},
	"mountain": {"name": "Mountain pass", "blurb": "A road between the peaks", "icon": "hill"},
	"city": {"name": "Night town", "blurb": "Lamp-lit streets and a square", "icon": "house"},
	"indoor": {"name": "Great hall", "blurb": "Inside: tables, shelves, a hearth", "icon": "home"},
}
const WORLD_ORDER := ["forest", "mountain", "city", "indoor"]

const SCENES := {
	"village": {"name": "A day in the village", "blurb": "Chores, chatter and friends meeting", "icon": "sun", "layout": ""},
	"campfire": {"name": "Campfire night", "blurb": "Stories round the fire in the woods", "icon": "fire", "layout": "forest"},
	"monsters": {"name": "Monster attack", "blurb": "Monsters storm in, a hero stands firm", "icon": "chase", "layout": "", "needs": "mobs"},
	"party": {"name": "Dance party", "blurb": "Dancing under the lamps in town", "icon": "dance", "layout": "city"},
	"journey": {"name": "Mountain journey", "blurb": "Travellers crossing the pass in the snow", "icon": "walk", "layout": "mountain"},
	"tavern": {"name": "Evening in the hall", "blurb": "Friends, rivals and a fight by the hearth", "icon": "chat", "layout": "indoor"},
}
const SCENE_ORDER := ["village", "campfire", "monsters", "party", "journey", "tavern"]
## The floor height inside the blocky great hall (the ground lookup finds the
## roof, the highest block), or -1 when not indoors.
const HALL_FLOOR := 5.0
static var _floor := -1.0


## Layouts the style's world can make.
static func layouts(style: String) -> Array:
	match str(Styles.get_style(style)["world"]):
		"voxel":
			return VoxelWorld.LAYOUTS
		"pixel":
			return PixelWorld.LAYOUTS
		"pixeltop":
			return PixelTopWorld.LAYOUTS
	return TerrainWorld.LAYOUTS


## [{key, name, blurb, icon, kind ("scene" | "world")}] for a style.
static func for_style(style: String) -> Array:
	var out := []
	var lay := layouts(style)
	var groups := {}
	for p in Rigs.presets_for(style).values():
		groups[p.get("group", "people")] = true
	for k in SCENE_ORDER:
		var sc: Dictionary = SCENES[k]
		if sc["layout"] != "" and not lay.has(sc["layout"]):
			continue
		if sc.has("needs") and not groups.has(sc["needs"]):
			continue
		out.append({"key": "scene:" + k, "name": sc["name"], "blurb": sc["blurb"], "icon": sc["icon"], "kind": "scene"})
	for k in WORLD_ORDER:
		if lay.has(k):
			out.append({"key": "world:" + k, "name": WORLDS[k]["name"], "blurb": WORLDS[k]["blurb"], "icon": WORLDS[k]["icon"], "kind": "world"})
	return out


## The world layout a template starts from ("" = the style's default).
static func layout_of(key: String) -> String:
	if key.begins_with("world:"):
		return key.substr(6)
	if key.begins_with("scene:"):
		return str(SCENES.get(key.substr(6), {}).get("layout", ""))
	return ""


## Sets the new scene up for template `key` (after Studio.new_scene with
## its layout).
static func apply(st: Studio, key: String) -> void:
	_floor = HALL_FLOOR if st.world.is_voxel and layout_of(key) == "indoor" else -1.0
	if key.begins_with("world:"):
		# Just the world: bring the starting cast to its open middle.
		var anchor := _anchor(st, key.substr(6))
		var i := 0
		for a in st.actors:
			_place(st, a, anchor + _ring(i, st.actors.size(), 3.0 if i else 0.0, st))
			i += 1
		if key == "world:city":
			_night(st, 21.5)
		st.capture_start()
		return
	if not key.begins_with("scene:"):
		return
	var k := key.substr(6)
	var anchor := _anchor(st, str(SCENES[k]["layout"]))
	match k:
		"village":
			_scene_village(st, anchor)
		"campfire":
			_scene_campfire(st, anchor)
		"monsters":
			_scene_monsters(st, anchor)
		"party":
			_scene_party(st, anchor)
		"journey":
			_scene_journey(st, anchor)
		"tavern":
			_scene_tavern(st, anchor)
	st.shots = st.default_shots()
	st.capture_start()
	st.mark_dirty()


# ---------------------------------------------------------------- scenes

static func _scene_village(st: Studio, at: Vector3) -> void:
	var c := _cast(st, at, [
		{"name": "", "b": "group", "at": [-3, 2], "lines": ["Did you see the new bridge?", "The bread smells amazing today.", "Let's go to the market later."]},
		{"name": "", "b": "group", "at": [-4.5, 3.5]},
		{"name": "", "b": "group", "at": [-2, 4]},
		{"name": "", "b": "talk", "at": [4, -1]},
		{"name": "", "b": "talk", "at": [5.5, 0]},
		{"name": "", "b": "wander", "at": [2, 5]},
		{"name": "", "b": "patrol", "at": [-6, -4]},
		{"group": "animals", "name": "", "b": "follow", "at": [1.2, 0.8]},
	])
	_friends(c[0], c[1])
	_friends(c[1], c[2])
	_rivals(c[3], c[5])
	_cue(st, c[5], "say", 2.0, 3.0, "Good morning, everyone!")
	_cue(st, c[5], "wave", 2.0, 3.0)
	_cue(st, c[0], "say", 7.0, 3.0, "Oh, it's you again.")
	_cue(st, c[2], "celebrate", 11.0, 3.0)
	_cue(st, c[2], "say", 11.0, 3.0, "I won the baking contest!")


static func _scene_campfire(st: Studio, at: Vector3) -> void:
	st.fx.add("fire", _ground(st, at))
	st.fx.add("sparkles", _ground(st, at + Vector3(0, 0, 3.0 if not st.is_side() else 0.0) + (Vector3(3.5, 0, 0) if st.is_side() else Vector3.ZERO)), 0.8)
	st.fx.add("dust", _ground(st, at))
	var c := _cast(st, at, [
		{"name": "", "b": "gather", "at": [2.0, 0.5], "lines": ["...and then the lights went out.", "Nobody ever saw him again.", "Listen. Did you hear that?"]},
		{"name": "", "b": "gather", "at": [-2.0, 0.5]},
		{"name": "", "b": "gather", "at": [0.5, 2.2]},
		{"name": "", "b": "gather", "at": [-0.5, -2.2]},
		{"name": "", "b": "sit", "at": [3.0, -2.0]},
	], Vector3(0, 0, -3.5))
	for i in range(1, 4):
		_friends(c[0], c[i])
	_cue(st, c[0], "say", 1.5, 3.5, "Gather round. I'll tell you a story.")
	_cue(st, c[0], "say", 6.0, 3.5, "Long ago, in these very woods...")
	_cue(st, c[0], "say", 11.0, 3.0, "BOO!")
	_cue(st, c[1], "pose", 11.2, 2.0, "", "scared")
	_cue(st, c[2], "laugh", 12.0, 3.0)
	_cue(st, c[3], "say", 13.0, 2.5, "Not funny!")
	_night(st, 21.5)


static func _scene_monsters(st: Studio, at: Vector3) -> void:
	var c := _cast(st, at, [
		{"name": "", "b": "group", "at": [-3, 2]},
		{"name": "", "b": "group", "at": [-4.5, 3]},
		{"name": "", "b": "wander", "at": [3, 3]},
		{"name": "", "b": "fight", "at": [1.5, -1.5], "lines": ["Stay behind me!", "Not one step further!"]},
		{"group": "mobs", "name": "", "b": "chase", "at": [12, 6]},
		{"group": "mobs", "name": "", "b": "chase", "at": [13, -4]},
		{"group": "mobs", "name": "", "b": "wander", "at": [-12, 9]},
	])
	for i in 3:
		c[i].rel[c[4].name] = "scared"
		c[i].rel[c[5].name] = "scared"
	c[3].rel[c[4].name] = "rival"
	c[3].rel[c[5].name] = "rival"
	_friends(c[0], c[1])
	_cue(st, c[2], "say", 3.0, 2.5, "What's that noise?")
	_cue(st, c[3], "say", 6.0, 2.5, "Monsters! Everyone, get back!")
	st.atmo.apply_mood("storm")


static func _scene_party(st: Studio, at: Vector3) -> void:
	var dances := ["disco", "robot", "twist", "hands_up", "jacks", "sway"]
	var specs := []
	for i in 6:
		var a := TAU * i / 6.0
		specs.append({"name": "", "b": "dance", "dance": dances[i], "at": [cos(a) * 3.2, sin(a) * 3.2]})
	specs.append({"name": "", "b": "group", "at": [6, 4]})
	specs.append({"name": "", "b": "group", "at": [7, 5.5]})
	var c := _cast(st, at, specs, Vector3(0, 0, -5.5))
	_friends(c[6], c[7])
	for k in [Vector3(0, 0, 0), Vector3(-5, 0, 3), Vector3(5, 0, -3)]:
		st.fx.add("sparkles", _ground(st, at + (Vector3(k.x, 0, 0) if st.is_side() else k)), 1.2)
	_cue(st, c[0], "say", 2.0, 2.5, "Everybody dance!")
	_cue(st, c[1], "celebrate", 8.0, 3.0)
	_night(st, 21.0)


static func _scene_journey(st: Studio, at: Vector3) -> void:
	var c := _cast(st, at, [
		{"name": "", "b": "follow", "at": [-2, 0.8], "lines": ["Are we nearly there?", "My feet are freezing.", "The pass is just ahead!"]},
		{"name": "", "b": "follow", "at": [-3.5, -0.6]},
		{"name": "", "b": "follow", "at": [-5, 0.5]},
		{"name": "", "b": "sit", "at": [9, 2.5]},
	], Vector3(0, 0, 0))
	for i in 3:
		c[i].chat_busy = true
		_friends(c[i], c[(i + 1) % 3])
	if not st.is_flat():
		st.fx.add("fire", _ground(st, at + Vector3(9, 0, 4)))
	else:
		st.fx.add("fire", _ground(st, at + Vector3(10, 0, 0)))
	st.fx.add("dust", _ground(st, at), 1.4)
	_cue(st, c[3], "say", 4.0, 3.0, "Travellers! Come and warm up by the fire.")
	_cue(st, c[3], "wave", 4.0, 3.0)
	st.atmo.apply_mood("snow")


static func _scene_tavern(st: Studio, at: Vector3) -> void:
	var c := _cast(st, at, [
		{"name": "", "b": "group", "at": [-3, -1], "lines": ["Another round!", "Did you hear the bard last night?", "To friendship!"]},
		{"name": "", "b": "group", "at": [-4.5, 0.5]},
		{"name": "", "b": "group", "at": [-2.5, 1.2]},
		{"name": "", "b": "idle", "at": [4, -1], "lines": ["You'll regret that.", "Say that again!"]},
		{"name": "", "b": "idle", "at": [5.5, 0]},
		{"name": "", "b": "dance", "at": [0, 4]},
	], Vector3(0, 0, -4))
	_friends(c[0], c[1])
	_friends(c[1], c[2])
	_rivals(c[3], c[4])
	c[2].rel[c[3].name] = "friend"
	# The hearth: in the middle of the back wall.
	if st.world.is_voxel:
		st.fx.add("fire", Vector3(VoxelWorld.WX >> 1, 5.0, (VoxelWorld.WZ >> 1) + 9 + 0.6), 0.7)
	else:
		st.fx.add("fire", _ground(st, at + Vector3(6, 0, 0)), 0.8)
	_cue(st, c[3], "say", 3.0, 2.5, "That's my seat.")
	_cue(st, c[4], "say", 5.5, 2.5, "I don't see your name on it.")
	_cue(st, c[3], "fight", 8.0, 5.0)
	_cue(st, c[0], "say", 13.5, 3.0, "Enough! Sit down, both of you.")
	_night(st, 20.5)


# ---------------------------------------------------------------- helpers

## The open middle of the layout, where a scene is set.
static func _anchor(st: Studio, layout: String) -> Vector3:
	var c := float(Styles.SIZE) / 2.0
	var p := Vector3(c, 0, c)
	if st.world.is_voxel and layout == "":
		p.z = c - 6.0  # south of the house
	elif st.world.is_voxel and layout == "indoor":
		p.z = c - 2.0
	elif layout == "mountain" and not st.is_flat():
		# On the road along the valley floor.
		p.z = c + sin(c * 0.08) * 3.0
	if st.is_side():
		p.z = PixelWorld.LANE
	return _ground(st, p)


static func _ground(st: Studio, p: Vector3) -> Vector3:
	if st.is_side():
		p.z = PixelWorld.LANE
	if _floor >= 0.0:
		# Indoors: on the floor (not the roof), off the tables.
		for r in [0.0, 0.8, 1.6, 2.4]:
			for k in (1 if r == 0.0 else 8):
				var q := Vector3(p.x + cos(k * TAU / 8.0) * r, _floor, p.z + sin(k * TAU / 8.0) * r)
				if not st.world.body_blocked(q):
					return q
		return Vector3(p.x, _floor, p.z)
	var s := st.find_spot(p.x, p.z)
	return Vector3(s.x, st.world.ground_at(s.x, s.y), s.y if not st.is_side() else PixelWorld.LANE)


static func _ring(i: int, n: int, r: float, st: Studio) -> Vector3:
	if st.is_side():
		return Vector3((i - n / 2.0) * 1.4, 0, 0)
	var a := TAU * i / maxf(1.0, float(n))
	return Vector3(cos(a) * r, 0, sin(a) * r)


static func _place(st: Studio, a: Actor, p: Vector3) -> void:
	var g := _ground(st, p)
	a.pos = g
	a.home = g
	a.vel = Vector3.ZERO


## Replaces everyone but the player with `specs` ({group, b, at: [x, z],
## lines, dance}) placed round `at`; the player stands at `at` + `me`.
## Returns the new characters in order (a missing kind is skipped as null,
## so the indexes stay put; callers only use people slots then).
static func _cast(st: Studio, at: Vector3, specs: Array, me := Vector3(0, 0, -2.5)) -> Array:
	for a in st.actors.duplicate():
		if a != st.player:
			st.remove_actor(a)
	_place(st, st.player, at + _flat(st, me))
	var presets := Rigs.presets_for(st.style_key)
	var pools := {}
	for k in presets:
		var g: String = presets[k].get("group", "people")
		if g == "people" and presets[k].get("creature"):
			continue
		if not pools.has(g):
			pools[g] = []
		pools[g].append(k)
	var used := {st.player.name: true}
	var out := []
	var count := {}
	for sp in specs:
		var g: String = sp.get("group", "people")
		var pool: Array = pools.get(g, pools.get("people", []))
		if pool.is_empty():
			out.append(null)
			continue
		var n := int(count.get(g, 0))
		count[g] = n + 1
		# Skip the player's own look for people where there's a choice.
		var key: String = pool[(n + (1 if g == "people" and pool.size() > 2 else 0)) % pool.size()]
		var name := _name(used)
		var off: Array = sp["at"]
		var p := _ground(st, at + _flat(st, Vector3(float(off[0]), 0, float(off[1]))))
		var lines: Array = sp.get("lines", presets[key].get("lines", []))
		var a := st.add_actor({"name": name, "look": {"preset": key}, "behavior": sp.get("b", "idle"), "lines": lines.duplicate(),
			"dance": sp.get("dance", "mix"), "x": p.x, "y": p.y, "z": p.z, "yaw": atan2(at.x - p.x, at.z - p.z)})
		out.append(a)
	# Missing kinds (no monsters in a style): fill the slot with a person so
	# the scene still reads.
	for i in out.size():
		if out[i] == null:
			out[i] = st.player
	return out


static func _flat(st: Studio, v: Vector3) -> Vector3:
	return Vector3(v.x + v.z * 0.35, 0, 0) if st.is_side() else v


static func _name(used: Dictionary) -> String:
	for n in Rigs.NAMES:
		if not used.has(n):
			used[n] = true
			return n
	var k := used.size()
	used["Extra %d" % k] = true
	return "Extra %d" % k


static func _friends(a: Actor, b: Actor) -> void:
	if a and b and a != b:
		a.rel[b.name] = "friend"
		b.rel[a.name] = "friend"


static func _rivals(a: Actor, b: Actor) -> void:
	if a and b and a != b:
		a.rel[b.name] = "rival"
		b.rel[a.name] = "rival"


static func _cue(st: Studio, a: Actor, action: String, start: float, dur: float, text := "", pose := "") -> void:
	if a == null or a == st.player:
		return
	var c := {"actor": a.name, "action": action, "start": start, "dur": dur}
	if action == "say":
		c["text"] = text
	if action == "pose":
		c["pose"] = Poses.builtin(pose)
	st.cues.append(c)


static func _night(st: Studio, hour: float) -> void:
	st.atmo.apply_mood("day")
	App.settings["time"] = hour
	st.atmo.apply()
