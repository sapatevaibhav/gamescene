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
	# A story, not a sandbox: only the script's lines are heard (no chatter,
	# no "Ow!" when hit, no ad-libbed gasps). Reactions still happen.
	App.settings["chatter"] = false
	App.settings["hit_lines"] = false
	st.shots = []
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
	if st.shots.is_empty():
		st.shots = st.default_shots()
	st.capture_start()
	st.mark_dirty()


# ---------------------------------------------------------------- scenes
# Each is a short film of about 30 seconds: a story with back-and-forth
# lines, people moving and reacting on cue, and a shot list that cuts to
# whoever matters (Export plays the story through those shots).

static func _scene_village(st: Studio, at: Vector3) -> void:
	var c := _cast(st, at, [
		{"name": "", "b": "group", "at": [-3, 2]},
		{"name": "", "b": "group", "at": [-4.5, 3.5]},
		{"name": "", "b": "group", "at": [-2, 4]},
		{"name": "", "b": "talk", "at": [4, -1]},
		{"name": "", "b": "talk", "at": [5.5, 0]},
		{"name": "", "b": "idle", "at": [7, 6]},
		{"name": "", "b": "patrol", "at": [-7, -4]},
		{"group": "animals", "name": "", "b": "follow", "at": [1.2, 0.8]},
	])
	var a: Actor = c[0]
	var b: Actor = c[1]
	var cc: Actor = c[2]
	var news: Actor = c[5]
	_friends(a, b)
	_friends(b, cc)
	_rivals(c[3], news)
	_cue(st, news, "wave", 0.5, 2.5)
	_line(st, news, 0.5, "Morning, everyone! Big news!", 3.0)
	_line(st, a, 3.8, "What is it this time, %s?" % news.name, 3.0)
	# Over to the friends: the side of their circle nearest him (a fixed spot
	# could land behind a house).
	var mid := (a.pos + b.pos + cc.pos) / 3.0
	var dir := news.pos - mid
	dir.y = 0.0
	_walk(st, news, 6.5, mid + (dir.normalized() * 2.2 if dir.length() > 0.1 else Vector3(2.2, 0, 0)), 3.5)
	_cue(st, news, "idle", 6.5, 23.5)
	_line(st, b, 7.0, "Let me guess. Your goat escaped again.", 3.0)
	_line(st, news, 10.2, "No! The festival is tonight, in the square!", 3.5)
	_cue(st, cc, "celebrate", 14.0, 3.0)
	_line(st, cc, 14.0, "A festival? I need a new dress!", 3.0)
	_line(st, c[3], 17.4, "Did you hear that? A festival!", 3.0)
	_line(st, c[4], 20.5, "Then I'll bake my famous pie.", 3.0)
	_line(st, c[6], 23.6, "I'd better keep watch tonight.", 2.8)
	_line(st, a, 26.6, "See you all at sunset!", 3.0)
	for x in [a, b, cc, news]:
		_cue(st, x, "wave", 26.8, 3.0)
	st.shots = [
		_shot("Morning", "crane", news, 5.0, 10.0, 5.0, {"title": "A Day in the Village", "fade_in": true}),
		_shot("The news", "push", news, 4.5, 4.0, 1.7),
		_shot("The friends", "orbit", a, 6.5, 5.0, 2.0),
		_shot("A festival!", "push", cc, 3.5, 3.5, 1.7),
		_shot("Gossip", "dolly", c[3], 6.0, 5.0, 1.8),
		_shot("See you", "orbit", a, 4.5, 7.0, 3.0, {"fade_out": true}),
	]


static func _scene_campfire(st: Studio, at: Vector3) -> void:
	st.fx.add("fire", _ground(st, at))
	st.fx.add("sparkles", _ground(st, at + (Vector3(3.5, 0, 0) if st.is_side() else Vector3(0, 0, 3.0))), 0.8)
	st.fx.add("dust", _ground(st, at))
	var c := _cast(st, at, [
		{"name": "", "b": "gather", "at": [2.0, 0.5]},
		{"name": "", "b": "gather", "at": [-2.0, 0.5]},
		{"name": "", "b": "gather", "at": [0.5, 2.2]},
		{"name": "", "b": "gather", "at": [-0.5, -2.2]},
		{"name": "", "b": "sit", "at": [3.0, -2.0]},
	], Vector3(0, 0, -3.5))
	var teller: Actor = c[0]
	for i in range(1, 4):
		_friends(teller, c[i])
	_line(st, teller, 0.5, "Gather round, everyone. Closer to the fire.", 3.5)
	_line(st, c[1], 4.3, "Is this the one about the old mill?", 3.0)
	_line(st, teller, 7.5, "Long ago, a miller lived at the edge of these woods...", 4.0)
	_line(st, teller, 11.7, "Every night he heard footsteps... but no one was there.", 4.0)
	_cue(st, c[2], "pose", 15.6, 3.0, "", "scared")
	_line(st, c[2], 15.6, "Stop it, you're scaring me!", 3.0)
	_line(st, teller, 18.8, "One night, the footsteps stopped. Right. Behind. Him...", 4.0)
	_line(st, teller, 23.0, "BOO!", 1.5)
	_cue(st, c[1], "pose", 23.0, 2.0, "", "surprised")
	_cue(st, c[3], "laugh", 23.6, 3.0)
	_line(st, c[3], 23.8, "Ha! You jumped!", 2.6)
	_line(st, c[2], 26.6, "Not funny. Okay... a little funny.", 3.2)
	_night(st, 21.5)
	st.shots = [
		_shot("The fire", "crane", teller, 5.0, 8.0, 4.0, {"title": "Campfire Night", "fade_in": true}),
		_shot("The storyteller", "push", teller, 6.5, 3.5, 1.6),
		_shot("Listeners", "orbit", c[1], 4.0, 4.5, 1.8),
		_shot("The story", "push", teller, 7.5, 3.0, 1.6),
		_shot("BOO", "orbit", c[3], 4.0, 4.0, 1.8),
		_shot("Laughter", "crane", teller, 3.0, 7.0, 3.5, {"fade_out": true}),
	]


static func _scene_monsters(st: Studio, at: Vector3) -> void:
	var c := _cast(st, at, [
		{"name": "", "b": "group", "at": [-3, 2]},
		{"name": "", "b": "group", "at": [-4.5, 3]},
		{"name": "", "b": "idle", "at": [2.5, 3]},
		{"name": "", "b": "idle", "at": [1.5, -1.5]},
		{"group": "mobs", "name": "", "b": "idle", "at": [14, 7]},
		{"group": "mobs", "name": "", "b": "idle", "at": [15, -3]},
		{"group": "mobs", "name": "", "b": "wander", "at": [-14, 10]},
	])
	var hero: Actor = c[3]
	for i in 3:
		c[i].rel[c[4].name] = "scared"
		c[i].rel[c[5].name] = "scared"
	hero.rel[c[4].name] = "rival"
	hero.rel[c[5].name] = "rival"
	_friends(c[0], c[1])
	_line(st, c[0], 0.5, "Strange weather tonight...", 3.0)
	_line(st, c[1], 3.6, "I've never seen clouds this dark.", 3.0)
	_cue(st, c[2], "point", 6.7, 3.0)
	_line(st, c[2], 6.7, "Look! Over there, in the trees!", 3.0)
	for m in [c[4], c[5]]:
		_cue(st, m, "chase", 8.5, 17.5)
	_line(st, hero, 10.0, "Monsters! Everyone, get behind me!", 3.0)
	_cue(st, hero, "fight", 12.5, 13.5)
	_line(st, c[0], 13.3, "Run! To the houses!", 2.5)
	_line(st, hero, 18.5, "You picked the wrong village!", 3.0)
	for m in [c[4], c[5]]:
		_cue(st, m, "flee", 26.0, 4.0)
	_cue(st, hero, "celebrate", 26.2, 3.8)
	_line(st, hero, 26.2, "And stay out!", 2.0)
	_line(st, c[1], 28.2, "You saved us!", 1.8)
	st.atmo.apply_mood("storm")
	st.shots = [
		_shot("Dark clouds", "crane", c[0], 5.0, 9.0, 4.5, {"title": "Monster Attack", "fade_in": true}),
		_shot("Look!", "push", c[2], 4.0, 3.5, 1.7),
		_shot("They come", "dolly", c[4], 4.0, 6.0, 2.0),
		_shot("The hero", "push", hero, 4.0, 3.5, 1.7),
		_shot("The fight", "orbit", hero, 8.0, 5.0, 2.0),
		_shot("Victory", "push", hero, 5.0, 4.0, 1.8, {"fade_out": true}),
	]


static func _scene_party(st: Studio, at: Vector3) -> void:
	var dances := ["disco", "robot", "twist", "hands_up", "jacks", "sway"]
	var specs := []
	for i in 6:
		var an := TAU * i / 6.0
		specs.append({"name": "", "b": "dance", "dance": dances[i], "at": [cos(an) * 3.2, sin(an) * 3.2]})
	specs.append({"name": "", "b": "idle", "at": [6, 4]})
	specs.append({"name": "", "b": "idle", "at": [7, 5.5]})
	var c := _cast(st, at, specs, Vector3(0, 0, -5.5))
	var host: Actor = c[6]
	var shy: Actor = c[7]
	_friends(host, shy)
	for k in [Vector3(0, 0, 0), Vector3(-5, 0, 3), Vector3(5, 0, -3)]:
		st.fx.add("sparkles", _ground(st, at + (Vector3(k.x, 0, 0) if st.is_side() else k)), 1.2)
	_line(st, host, 0.5, "Welcome to the night market dance!", 3.0)
	_line(st, shy, 3.6, "Is the whole town here?", 2.6)
	_line(st, host, 6.3, "Everybody, show us your best moves!", 3.0)
	_line(st, c[0], 9.4, "Watch this spin!", 2.5)
	_cue(st, c[1], "celebrate", 12.0, 3.0)
	_line(st, c[1], 12.0, "Woo! Again!", 2.5)
	_cue(st, shy, "laugh", 15.0, 3.0)
	_line(st, shy, 15.0, "You call that dancing?", 2.8)
	_line(st, c[2], 18.0, "Then come and show us!", 2.6)
	_walk(st, shy, 20.4, at + Vector3(1.0, 0, -1.0), 2.5)
	_line(st, shy, 20.4, "Fine. Just one song!", 2.6)
	_cue(st, shy, "dance", 23.0, 7.0)
	_line(st, host, 24.0, "One more! Make it a big one!", 3.0)
	for i in 6:
		_cue(st, c[i], "celebrate", 27.2, 2.8)
	_night(st, 21.0)
	st.shots = [
		_shot("Night market", "crane", host, 5.0, 10.0, 5.0, {"title": "Dance Party", "fade_in": true}),
		_shot("The host", "push", host, 4.5, 3.5, 1.7),
		_shot("Dancers", "orbit", c[0], 6.0, 5.5, 2.0),
		_shot("Too cool", "push", shy, 5.0, 3.5, 1.7),
		_shot("One song", "orbit", shy, 5.5, 4.5, 1.9),
		_shot("Big finish", "crane", c[0], 4.0, 9.0, 4.5, {"fade_out": true}),
	]


static func _scene_journey(st: Studio, at: Vector3) -> void:
	# The travellers walk up the road to a camp where you (the player) keep
	# the fire. Everything is placed on the road itself: it winds through the
	# pass, and a spot measured from the middle of the map can be up the bank.
	var c := _cast(st, at, [
		{"name": "", "b": "idle", "at": [-12, 0]},
		{"name": "", "b": "idle", "at": [-13.5, 0]},
		{"name": "", "b": "idle", "at": [-15, 0]},
		{"group": "animals", "name": "", "b": "idle", "at": [-16.5, 0]},
	], Vector3(9, 0, 0))
	var starts := [[-12.0, 0.5], [-13.5, -0.6], [-15.0, 0.6], [-16.5, -0.4]]
	for i in 4:
		_place(st, c[i], _road(st, starts[i][0], starts[i][1]))
	_place(st, st.player, _road(st, 9.0, -0.6))
	var camp := _road(st, 9.0, 1.2)
	for i in 3:
		_friends(c[i], c[(i + 1) % 3])
	st.fx.add("fire", _ground(st, camp))
	st.fx.add("dust", _road(st, 0.0, 0.0), 1.4)
	_walk(st, c[0], 0.3, _road(st, 6.6, -0.4), 13.0)
	_walk(st, c[1], 0.8, _road(st, 7.4, 1.0), 13.0)
	_walk(st, c[2], 1.3, _road(st, 5.8, 0.6), 13.0)
	# Their pack animal (or a fourth traveller) plods along behind.
	_walk(st, c[3], 1.8, _road(st, 4.8, -0.2), 13.0)
	_line(st, c[0], 1.0, "Keep moving! The pass closes at dark.", 3.2)
	_line(st, c[1], 5.0, "My feet are frozen solid...", 3.0)
	_cue(st, c[2], "point", 9.0, 2.6)
	_line(st, c[2], 9.0, "Look, smoke! Someone's camping up ahead!", 3.2)
	_line(st, st.player, 13.2, "Travellers! Come and warm up by the fire.", 3.4)
	_line(st, c[0], 17.0, "Thank you, friend. We've walked all day.", 3.4)
	_cue(st, c[1], "sit", 20.8, 9.2)
	_line(st, c[1], 20.8, "Ahh... warm at last.", 3.0)
	_line(st, st.player, 24.2, "Where are you headed?", 2.6)
	_line(st, c[2], 27.0, "Over the mountain, to the sea.", 3.0)
	st.atmo.apply_mood("snow")
	st.shots = [
		_shot("The pass", "crane", c[0], 5.0, 10.0, 5.0, {"title": "Mountain Journey", "fade_in": true}),
		_shot("On the road", "dolly", c[0], 6.0, 5.0, 2.0),
		_shot("Smoke", "push", c[2], 4.0, 3.5, 1.7),
		_shot("The camp", "push", st.player, 4.0, 4.0, 1.8),
		_shot("By the fire", "orbit", c[0], 7.0, 5.0, 2.0),
		_shot("To the sea", "crane", c[2], 4.0, 8.0, 4.0, {"fade_out": true}),
	]


static func _scene_tavern(st: Studio, at: Vector3) -> void:
	var c := _cast(st, at, [
		{"name": "", "b": "group", "at": [-3, -1]},
		{"name": "", "b": "group", "at": [-4.5, 0.5]},
		{"name": "", "b": "group", "at": [-2.5, 1.2]},
		{"name": "", "b": "idle", "at": [4, -1]},
		{"name": "", "b": "idle", "at": [5.5, 0]},
		{"name": "", "b": "dance", "at": [0, 4]},
	], Vector3(0, 0, -4))
	var a: Actor = c[0]
	var r1: Actor = c[3]
	var r2: Actor = c[4]
	_friends(a, c[1])
	_friends(c[1], c[2])
	_rivals(r1, r2)
	# The hearth: in the middle of the back wall.
	if st.world.is_voxel:
		st.fx.add("fire", Vector3(VoxelWorld.WX >> 1, 5.0, (VoxelWorld.WZ >> 1) + 9 + 0.6), 0.7)
	else:
		st.fx.add("fire", _ground(st, at + Vector3(6, 0, 0)), 0.8)
	_cue(st, c[1], "celebrate", 0.5, 2.5)
	_line(st, a, 0.5, "To friendship!", 2.5)
	_line(st, r1, 3.3, "Hey. That's my seat.", 2.6)
	_line(st, r2, 6.1, "I don't see your name on it.", 3.0)
	_cue(st, r1, "point", 9.3, 2.4)
	_line(st, r1, 9.3, "Move. Now.", 2.2)
	_cue(st, r2, "laugh", 11.7, 2.4)
	_line(st, r2, 11.7, "Make me.", 2.2)
	_cue(st, r1, "fight", 14.2, 6.0)
	_cue(st, r2, "fight", 14.2, 6.0)
	_line(st, c[2], 15.0, "Oh no. Not again...", 2.6)
	# Over to break it up, and stays there (not back to his friends).
	_walk(st, a, 15.6, (r1.pos + r2.pos) * 0.5 + _flat(st, Vector3(0, 0, -1.3)), 4.5)
	_cue(st, a, "idle", 15.6, 14.4)
	_line(st, a, 20.5, "ENOUGH! Sit down, both of you!", 3.2)
	_line(st, r2, 24.0, "...Fine.", 2.0)
	_cue(st, r2, "sit", 24.0, 6.0)
	_line(st, r1, 26.2, "This isn't over.", 2.4)
	_line(st, c[5], 28.4, "Who wants a song?", 1.6)
	_night(st, 20.5)
	st.shots = [
		_shot("The hall", "crane", a, 5.0, 9.0, 4.5, {"title": "Evening in the Hall", "fade_in": true}),
		_shot("That's my seat", "push", r1, 4.0, 3.5, 1.7),
		_shot("Make me", "push", r2, 5.0, 3.5, 1.7),
		_shot("The brawl", "orbit", r1, 6.5, 4.5, 1.9),
		_shot("Enough", "push", a, 5.0, 3.5, 1.7),
		_shot("A song", "orbit", c[5], 4.5, 6.0, 2.5, {"fade_out": true}),
	]


# ---------------------------------------------------------------- helpers

## The open middle of the layout, where a scene is set.
static func _anchor(st: Studio, layout: String) -> Vector3:
	var c := float(Styles.SIZE) / 2.0
	var p := Vector3(c, 0, c)
	if st.world.is_voxel and layout == "":
		p.z = c - 10.0  # well south of the house, so nobody's cut off by it
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


## A spot on the mountain pass road, `along` metres from the middle of the
## map and `off` metres to one side (the curves match each world's own road:
## east-west in 3D, north-south seen from above, the lane in side view).
static func _road(st: Studio, along: float, off: float) -> Vector3:
	var c := float(Styles.SIZE) / 2.0
	if st.is_side():
		return _ground(st, Vector3(c + along, 0, PixelWorld.LANE))
	if st.is_top():
		var z := c + along
		return _ground(st, Vector3(c + round(sin(z * 0.1) * 5.0) + off, 0, z))
	var x := c + along
	return _ground(st, Vector3(x, 0, c + sin(x * 0.08) * 3.0 + off))


## A spoken line in the story.
static func _line(st: Studio, a: Actor, start: float, text: String, dur: float) -> void:
	if a == null:
		return
	st.cues.append({"actor": a.name, "action": "say", "start": start, "dur": dur, "text": text})


## Walking (or running) to `to` from `start`.
static func _walk(st: Studio, a: Actor, start: float, to: Vector3, dur: float, run := false) -> void:
	if a == null or a == st.player:
		return
	var g := _ground(st, to)
	st.cues.append({"actor": a.name, "action": "runto" if run else "walkto", "start": start, "dur": dur, "x": U.r2(g.x), "z": U.r2(g.z)})


## One shot of the film: a cinematic camera on `who`.
static func _shot(name: String, kind: String, who: Actor, dur: float, dist: float, height: float, extra := {}) -> Dictionary:
	var s := {"name": name, "mode": "cine", "shot": kind, "target": who.name if who else "", "dur": dur, "dist": dist, "height": height, "title": ""}
	s.merge(extra, true)
	return s


static func _night(st: Studio, hour: float) -> void:
	st.atmo.apply_mood("day")
	App.settings["time"] = hour
	st.atmo.apply()
