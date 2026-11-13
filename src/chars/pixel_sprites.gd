class_name PixelSprites
## Pixel 2D characters: side-view sprite sheets painted in code from a small
## look config (colours, hair, hat, robe...), shown on a flat quad that faces
## the side camera. One sheet holds every pose; `animate` picks the frame
## from what the character is doing and mirrors it to face left or right.

const FRAME := 32
const COLS := 8
## Rows per direction block (5 × 8 = 40 frame slots; FRAMES fills the first).
const ROWS := 5
## Metres per sprite pixel: 16 px per metre, like the tiles.
const PPM := 16.0

## Frame order in the sheet.
const FRAMES := ["idle0", "idle1", "walk0", "walk1", "walk2", "walk3", "jump", "crouch",
	"sit", "sleep", "wave0", "wave1", "talk0", "talk1", "dance0", "dance1",
	"dance2", "dance3", "cel0", "cel1", "laugh0", "laugh1", "cry0", "cry1",
	"point", "guard", "atk0", "atk1", "hurt", "climb0", "climb1", "idle2",
	"swim0", "swim1", "tread0", "tread1"]
const BLOCK := COLS * ROWS

## Human poses. Arm and leg angles in degrees: 0 hangs straight down, 90
## points forward, 180 straight up; negative swings back. `ae`/`abe` bend the
## elbows, `lfk`/`lbk` the knees. `dy` drops the body, `lean` tips it forward.
const POSES := {
	"idle0": {"af": 8, "ab": -8},
	"idle1": {"af": 5, "ab": -5, "dy": 1},
	"idle2": {"af": 8, "ab": -8, "eyes": "closed"},
	# Contact, passing, contact, passing: the swinging leg's knee bends with
	# the foot tucked just behind it, never kicked far back.
	"walk0": {"af": -22, "ab": 22, "lf": 24, "lb": -22},
	"walk1": {"af": -6, "ab": 6, "lf": -4, "lb": 14, "lbk": 30, "dy": -1},
	"walk2": {"af": 22, "ab": -22, "lf": -22, "lb": 24},
	"walk3": {"af": 6, "ab": -6, "lf": 14, "lfk": 30, "lb": -4, "dy": -1},
	"jump": {"af": 150, "ab": 120, "lf": 35, "lfk": 50, "lb": -20, "lbk": 40, "dy": -2},
	"crouch": {"af": 30, "ae": 30, "ab": 15, "lf": 50, "lfk": 95, "lb": 10, "lbk": 95, "dy": 4},
	"sit": {"af": 25, "ae": 25, "ab": 20, "lf": 90, "lb": 85, "dy": 9, "sit": true},
	"sleep": {"af": 5, "ab": -5, "eyes": "closed", "sleep": true},
	"wave0": {"af": 165, "ae": 15, "ab": -8, "mouth": "smile"},
	"wave1": {"af": 150, "ae": -25, "ab": -8, "mouth": "smile"},
	"talk0": {"af": 60, "ae": 45, "ab": -5, "mouth": "open"},
	"talk1": {"af": 40, "ae": 25, "ab": -5},
	"dance0": {"af": 165, "ab": 160, "lf": 20, "lb": -10, "dy": -1, "mouth": "smile"},
	"dance1": {"af": 110, "ae": 40, "ab": 170, "lf": -10, "lb": 25, "lbk": 30, "mouth": "smile"},
	"dance2": {"af": 90, "ae": 90, "ab": 90, "abe": 90, "lf": 30, "lfk": 45, "dy": 1, "mouth": "smile"},
	"dance3": {"af": 170, "ab": 115, "lf": -5, "lb": 5, "dy": -2, "mouth": "smile"},
	"cel0": {"af": 170, "ab": 165, "lf": 18, "lb": -18, "dy": -2, "mouth": "open", "eyes": "happy"},
	"cel1": {"af": 150, "ab": 150, "mouth": "open", "eyes": "happy"},
	"laugh0": {"af": 45, "ae": 75, "ab": 35, "abe": 70, "lean": -1, "mouth": "open", "eyes": "happy"},
	"laugh1": {"af": 45, "ae": 75, "ab": 35, "abe": 70, "dy": 1, "mouth": "open", "eyes": "happy"},
	"cry0": {"af": 115, "ae": 105, "ab": 110, "abe": 100, "lean": 1, "hd": 1, "eyes": "cry"},
	"cry1": {"af": 115, "ae": 105, "ab": 110, "abe": 100, "lean": 1, "hd": 1, "dy": 1, "eyes": "cry"},
	"point": {"af": 90, "ab": -5},
	"guard": {"af": 70, "ae": 95, "ab": 60, "abe": 95, "lf": 22, "lb": -22, "dy": 1},
	"atk0": {"af": 170, "ae": 10, "ab": -25, "lean": -1, "lf": 10, "lb": -10},
	"atk1": {"af": 65, "ae": -10, "ab": -30, "lean": 1, "lf": 30, "lb": -22, "mouth": "open"},
	"hurt": {"af": -45, "ab": -55, "lean": -2, "eyes": "closed", "mouth": "open"},
	"climb0": {"af": 155, "ab": 125, "lf": 35, "lfk": 45, "lb": 0},
	"climb1": {"af": 125, "ab": 155, "lf": 0, "lb": 35, "lbk": 45},
	# Swimming along: upright, arms pulling, body hidden below the waterline.
	"swim0": {"af": 130, "ae": 20, "ab": 30, "lf": -30, "lb": -50, "swim": true, "mouth": "open", "lean": 1},
	"swim1": {"af": 40, "ae": 20, "ab": 130, "lf": -50, "lb": -30, "swim": true, "lean": 1},
	# Treading water: upright, head and shoulders above the waterline.
	"tread0": {"af": 130, "ae": 20, "ab": 30, "lf": -30, "lb": -50, "swim": true, "mouth": "open"},
	"tread1": {"af": 40, "ae": 20, "ab": 130, "lf": -50, "lb": -30, "swim": true},
}

const PRESETS := {
	"hero": {"label": "Hero", "skin": "#f0c8a0", "hair": "#6b3a1e", "eyes": "#2f5d8a", "shirt": "#2a9d8f", "shirt2": "#e9c46a", "pants": "#2f3b52", "shoes": "#4a2e1e", "cape": "#c0392b"},
	"farmer": {"label": "Farmer", "skin": "#d9a27a", "hair": "#8a5a2b", "eyes": "#3b2a1e", "hat": "straw", "hatC": "#e2c46b", "shirt": "#7aa95c", "pants": "#4a6fa5", "overalls": true, "shoes": "#5a3b22", "beh": "wander", "lines": ["The carrots are coming in nicely.", "Rain would be nice."]},
	"merchant": {"label": "Merchant", "skin": "#8d5a3b", "hair": "#1e1612", "beard": "#1e1612", "eyes": "#2b1b10", "shirt": "#7b4fa0", "shirt2": "#e0b13a", "robe": true, "shoes": "#3a2a20", "beh": "talk", "lines": ["Fresh goods, fair prices!", "Business is slow today."]},
	"knight": {"label": "Knight", "skin": "#f0c8a0", "hair": "#a0522d", "eyes": "#2e7d4f", "hat": "helmet", "hatC": "#a7b0ba", "shirt": "#a7b0ba", "shirt2": "#3d6fb5", "pants": "#7d868f", "shoes": "#4a5058", "sword": true, "beh": "patrol", "lines": ["Halt! Oh, it's you.", "All quiet on the wall."]},
	"wizard": {"label": "Wizard", "skin": "#e6bf9c", "hair": "#e8e8e8", "beard": "#e8e8e8", "eyes": "#2f5d8a", "hat": "wizard", "hatC": "#3a3f9a", "shirt": "#3a3f9a", "shirt2": "#e9c46a", "robe": true, "shoes": "#1b2440", "staff": true, "beh": "idle", "lines": ["The stars are restless tonight.", "Patience, young one."]},
	"chef": {"label": "Chef", "skin": "#e8b892", "hair": "#2a1d14", "eyes": "#3b2a1e", "hat": "chef", "hatC": "#f4f4f4", "shirt": "#f4f4f4", "shirt2": "#d9d9d9", "pants": "#2e2e2e", "shoes": "#1e1e1e", "beh": "talk", "lines": ["Soup's almost ready.", "A pinch more salt…"]},
	"ranger": {"label": "Ranger", "skin": "#b97a50", "hair": "#2b1b10", "eyes": "#2b1b10", "hat": "hood", "hatC": "#3f6b3a", "shirt": "#5a7a3a", "shirt2": "#8a6236", "pants": "#4a3c2a", "shoes": "#3b2a1a", "bow": true, "beh": "wander", "lines": ["Tracks lead north.", "Quiet. Listen."]},
	"miner": {"label": "Miner", "skin": "#e0ac7e", "hair": "#3b2a1e", "beard": "#3b2a1e", "eyes": "#3b2a1e", "hat": "cap", "hatC": "#f2c14e", "shirt": "#8a5a3a", "pants": "#3a3f52", "shoes": "#2b2018", "pick": true, "beh": "wander", "lines": ["Gold in them hills!", "Mind your head."]},
	"princess": {"label": "Princess", "skin": "#f2cfb0", "hair": "#f2c14e", "hairStyle": "long", "eyes": "#3c78d8", "hat": "crown", "hatC": "#f2c14e", "shirt": "#ff7aa2", "shirt2": "#ffffff", "robe": true, "shoes": "#ff7aa2", "beh": "wander", "lines": ["What a lovely day!", "Have you seen my cat?"]},
	"villager": {"label": "Villager", "skin": "#d8a27a", "hair": "#5a3b22", "eyes": "#3a2a20", "shirt": "#c98a4a", "shirt2": "#5b4a38", "pants": "#4f3f30", "shoes": "#3a2a20", "beh": "wander", "lines": ["Good harvest this year.", "Hmm, a visitor."]},
	"kid": {"label": "Kid", "skin": "#c98d62", "hair": "#1e1612", "eyes": "#2b1b10", "shirt": "#ffd166", "pants": "#3d6fb5", "shoes": "#ffffff", "scale": 0.8, "beh": "dance", "lines": ["Catch me!", "Again! Again!"]},
	# Mobs.
	"skeleton": {"label": "Skeleton", "group": "mobs", "skin": "#e6e2d6", "eyes": "#111111", "shirt": "#e6e2d6", "pants": "#e6e2d6", "shoes": "#cfc9b8", "hairStyle": "bald", "bones": true, "beh": "wander", "lines": ["*rattle rattle*", "Chilly in here."]},
	"zombie": {"label": "Zombie", "group": "mobs", "skin": "#7f9a6a", "hair": "#2f3a28", "eyes": "#1a1a1a", "shirt": "#7a6a55", "pants": "#4a4236", "shoes": "#2b2b24", "pose": "zombie", "beh": "chase", "lines": ["Uuurgh…", "Braaains…"]},
	"goblin": {"label": "Goblin", "group": "mobs", "skin": "#8fb35a", "hair": "#2a3a1e", "eyes": "#e8c33a", "shirt": "#7a5a3a", "pants": "#5a4430", "shoes": "#3a2a1e", "ears": true, "club": true, "scale": 0.8, "beh": "chase", "lines": ["Grrah!", "Mine!"]},
	"witch": {"label": "Witch", "group": "mobs", "skin": "#c9d8b0", "hair": "#2a2a2a", "hairStyle": "long", "eyes": "#7b3fb0", "hat": "wizard", "hatC": "#2a1f36", "shirt": "#3b2a4a", "shirt2": "#6a3a8a", "robe": true, "shoes": "#1c1820", "staff": true, "beh": "wander", "lines": ["Hehehe!", "Fresh potions, dearie?"]},
	"ghost": {"label": "Ghost", "group": "mobs", "creature": "ghost", "col": "#eef2f6", "height": 1.6, "beh": "wander", "lines": ["Boooo…", "Have you seen my chains?"]},
	"slime": {"label": "Slime", "group": "mobs", "creature": "slime", "col": "#7ed957", "height": 0.7, "beh": "wander", "lines": ["*boing*", "*squish*"]},
	"slimeBlue": {"label": "Blue slime", "group": "mobs", "creature": "slime", "col": "#5fa8ff", "height": 0.7, "beh": "wander", "lines": ["*bloop*"]},
	"bat": {"label": "Bat", "group": "mobs", "creature": "bat", "col": "#4a3a5a", "height": 1.0, "beh": "wander", "lines": ["*squeak*"]},
	# Animals.
	"chicken": {"label": "Chicken", "group": "animals", "creature": "chicken", "col": "#f4f4f0", "height": 0.7, "beh": "wander", "lines": ["Bawk!", "Cluck cluck."]},
	"pig": {"label": "Pig", "group": "animals", "creature": "pig", "col": "#f2a6b4", "height": 0.8, "beh": "wander", "lines": ["Oink."]},
	"dog": {"label": "Dog", "group": "animals", "creature": "dog", "col": "#b5793f", "height": 0.8, "beh": "follow", "lines": ["Woof!", "Arf arf!"]},
	"cat": {"label": "Cat", "group": "animals", "creature": "cat", "col": "#8a8f98", "height": 0.6, "beh": "wander", "lines": ["Meow.", "Purrr…"]},
	"sheep": {"label": "Sheep", "group": "animals", "creature": "sheep", "col": "#f4f4f0", "height": 0.9, "beh": "wander", "lines": ["Baa."]},
	"frog": {"label": "Frog", "group": "animals", "creature": "frog", "col": "#5fb04a", "height": 0.5, "beh": "wander", "lines": ["Ribbit."]},
}

const OUTLINE := Color("1b1626")

static var _sheets := {}
static var _shader: Shader


# ---------------------------------------------------------------- looks

static func cfg_for(look: Dictionary) -> Dictionary:
	if look.get("cfg") is Dictionary:
		return look["cfg"]
	return PRESETS.get(str(look.get("preset", "")), PRESETS["hero"])


static func random_cfg() -> Dictionary:
	var skins := ["#f2cfb0", "#f0c8a0", "#d9a27a", "#c98d62", "#8d5a3b", "#5e3b26"]
	var hairs := ["#1e1612", "#3b2a1e", "#6b3a1e", "#a0522d", "#f2c14e", "#e8e8e8", "#c0392b", "#3a3f9a"]
	var cloth := ["#2a9d8f", "#e76f51", "#e9c46a", "#7b4fa0", "#3d6fb5", "#c0392b", "#5a7a3a", "#ff7aa2", "#f4f4f4", "#3a3a3a"]
	return {"skin": U.pick(skins), "hair": U.pick(hairs), "hairStyle": U.pick(["short", "short", "long", "bald"]), "eyes": U.pick(["#2f5d8a", "#2b1b10", "#2e7d4f"]),
		"shirt": U.pick(cloth), "shirt2": U.pick(cloth), "pants": U.pick(["#2f3b52", "#4a6fa5", "#4f3f30", "#2e2e2e"]), "shoes": U.pick(["#3a2a20", "#1e1e1e", "#ffffff"]),
		"hat": U.pick([null, null, "cap", "straw", "hood", "helmet"]), "hatC": U.pick(cloth), "beard": U.maybe(U.pick(hairs), 0.15), "robe": randf() < 0.15}


static func height_of(cfg: Dictionary) -> float:
	if cfg.has("creature"):
		return float(cfg.get("height", 0.8))
	return 1.75 * float(cfg.get("scale", 1.0))


# ---------------------------------------------------------------- rig

## Builds the sprite character: {kind: "sprite", view, root, mesh, mat,
## height, headH, scale, creature}. `view` "side" stands the sprite up on the
## lane; "top" lays it on the ground for the top-down camera, with front,
## back and side art. Imported sprites ({sprite: id}) use their own sheet.
static func build(look: Dictionary, view := "side") -> Dictionary:
	if look.has("sprite"):
		return SpriteImport.build_char(str(look["sprite"]), view)
	var cfg := cfg_for(look)
	var top := view == "top"
	var sheet := sheet_for(cfg, top)
	var s := float(cfg.get("scale", 1.0))
	var h := height_of(cfg)
	var rig := quad_rig(sheet, Vector2i(COLS, ROWS * (3 if top else 1)), Vector2(FRAME, FRAME) / PPM * s, view)
	rig.merge({"height": h / s, "headH": h * 0.85 / s, "scale": s, "creature": cfg.has("creature"), "float": cfg.get("creature", "") in ["ghost", "bat"]})
	rig["root"].set_meta("frame_h", h)
	rig["root"].set_meta("head_h", h * 0.85)
	return rig


## A sprite on one quad: standing (side view) or lying on the ground facing
## up (top view), bottom edge at the character's feet.
static func quad_rig(sheet: Texture2D, grid: Vector2i, size: Vector2, view: String) -> Dictionary:
	if _shader == null:
		_shader = load("res://src/shaders/pixel.gdshader")
	var root := Node3D.new()
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("tex", sheet)
	mat.set_shader_parameter("frames", Vector2(grid))
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	q.center_offset = Vector3(0, size.y / 2.0, 0)
	mi.mesh = q
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if view == "top":
		mi.rotation.x = -PI / 2
	root.add_child(mi)
	return {"kind": "sprite", "view": view, "root": root, "mesh": mi, "mat": mat, "grid": grid, "sitDrop": 0.0}


## The idle frame drawn big, for pickers and the home screen.
static func icon(look: Dictionary) -> Texture2D:
	if look.has("sprite"):
		return SpriteImport.icon(str(look["sprite"]))
	var cfg := cfg_for(look)
	var img := sheet_for(cfg).get_image().get_region(Rect2i(0, 0, FRAME, FRAME))
	img.resize(FRAME * 4, FRAME * 4, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## Side frames in rows 0-3; with `top`, front frames in rows 4-7 and back
## frames in rows 8-11.
static func sheet_for(cfg: Dictionary, top := false) -> ImageTexture:
	var key := JSON.stringify(cfg).md5_text() + ("t" if top else "")
	if _sheets.has(key):
		return _sheets[key]
	var blocks := 3 if top else 1
	var img := Image.create(FRAME * COLS, FRAME * ROWS * blocks, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for b in blocks:
		for i in FRAMES.size():
			var f: Image
			if cfg.has("creature"):
				f = _creature_frame(cfg, FRAMES[i])
			elif b == 0:
				f = _human_frame(cfg, FRAMES[i])
			else:
				f = _front_frame(cfg, FRAMES[i], b == 2)
			outline(f)
			img.blit_rect(f, Rect2i(0, 0, FRAME, FRAME), Vector2i((i % COLS) * FRAME, (b * ROWS + i / COLS) * FRAME))
	var tex := ImageTexture.create_from_image(img)
	_sheets[key] = tex
	return tex


# ---------------------------------------------------------------- animation

## Actions shown facing the viewer in top view. Fighting isn't one: a
## fighter faces who they're fighting.
const FACE_VIEWER := ["dance", "wave", "sit", "sleep", "celebrate", "laugh", "cry", "point", "pose"]


## What the character is doing, as a frame name ("walk2", "dance0"...), plus
## how far to lift them (hops, floating).
static func state_frame(a: Actor, sp: float) -> Array:
	var m := a.rig
	var t := a.t
	var lift := 0.0
	var name := "idle0" if fmod(t, 1.6) < 1.2 else "idle1"
	if fmod(t + a.id * 1.3, 5.0) < 0.15:
		name = "idle2"
	var w: Variant = a.studio.world
	var climbing: bool = w != null and w.get("is_side") == true and w.ladder_at(a.pos) and not a.on_ground
	if a.swimming:
		var k := "swim" if sp > 0.2 else "tread"
		name = k + ("0" if fmod(t, 0.7) < 0.35 else "1")
	elif a.hurt_t > 0.0:
		name = "hurt"
	elif a.attack_t > 0.0:
		name = "atk0" if a.attack_t > Actor.ATTACK_TIME * 0.5 else "atk1"
	elif climbing:
		name = "climb0" if fmod(a.pos.y, 0.5) < 0.25 else "climb1"
	elif not a.on_ground and absf(a.vel.y) > 1.0 and not m.get("float", false):
		name = "jump"
	elif sp > 0.2:
		name = "walk%d" % (int(a.walk * 1.3) % 4)
	elif a.crouch:
		name = "crouch"
	elif a.speak_t > 0.0:
		name = "talk0" if fmod(t, 0.36) < 0.18 else "talk1"
	else:
		match a.shown():
			"dance":
				var dd := dance_frame(a.dance_style, t)
				name = dd[0]
				lift += float(dd[1])
			"wave":
				name = "wave0" if fmod(t, 0.5) < 0.25 else "wave1"
			"sit":
				name = "sit"
			"sleep":
				name = "sleep"
			"celebrate":
				name = "cel0" if fmod(t, 0.5) < 0.25 else "cel1"
				lift = absf(sin(t * 6.3)) * 0.25
			"laugh":
				name = "laugh0" if fmod(t, 0.24) < 0.12 else "laugh1"
			"cry":
				name = "cry0" if fmod(t, 0.6) < 0.3 else "cry1"
			"point":
				name = "point"
			"fight":
				name = "guard"
			"pose":
				name = Poses.sprite_frame(a.shown_pose())
	if m.get("float", false):
		lift += 0.35 + sin(t * 2.6) * 0.08
	return [name, lift]


## A sprite dance for each style (sprites have four dance frames): frame
## speed and order, hops, and turning round (see dance_flip). Mix changes
## style every 4 s, like the 3D characters.
static func dance_frame(style: String, t: float) -> Array:
	if style == "mix" or not Actor.DANCES.any(func(d): return d[0] == style):
		style = Actor.DANCES[1 + int(floor(t / 4.0)) % (Actor.DANCES.size() - 1)][0]
	match style:
		"hands_up":
			return ["dance%d" % (int(t * 4.0) % 4), absf(sin(t * 8.0)) * 0.08]
		"sway":
			return ["dance%d" % [0, 1, 0, 3][int(t * 2.5) % 4], 0.0]
		"spin":
			return ["dance%d" % (int(t * 6.0) % 4), 0.0]
		"robot":
			return ["dance%d" % [0, 2][int(t * 2.0) % 2], 0.0]
		"disco":
			return ["dance%d" % [1, 3][int(t * 3.0) % 2], 0.0]
		"jacks":
			return ["dance%d" % [0, 2][int(t * 3.0) % 2], absf(sin(t * TAU * 1.5)) * 0.3]
		"twist":
			return ["dance%d" % (int(t * 5.0) % 4), 0.0]
		"clap":
			return ["cel%d" % (int(t * 4.0) % 2), absf(sin(t * TAU)) * 0.05]
	return ["dance%d" % (int(t * 4.0) % 4), 0.0]


## Spinning dances turn the sprite round: -1 = leave it, 0 / 1 = flipped.
static func dance_flip(style: String, t: float) -> int:
	if style == "mix" or not Actor.DANCES.any(func(d): return d[0] == style):
		style = Actor.DANCES[1 + int(floor(t / 4.0)) % (Actor.DANCES.size() - 1)][0]
	match style:
		"spin":
			return int(t * 4.0) % 2
		"twist":
			return int(t * 2.5) % 2
		"disco":
			return int(t * 0.75) % 2
	return -1


## Which way the sprite faces: "side" (flipped when going left), "front"
## (towards the viewer, i.e. south) or "back". Side view is always "side".
static func facing(a: Actor, sp: float) -> Array:
	if a.rig.get("view", "side") != "top":
		return ["side", sin(a.yaw) < 0.0]
	var d := Vector2(sin(a.yaw), cos(a.yaw))
	if sp > 0.2:
		d = Vector2(a.vel.x, a.vel.z).normalized()
	elif a.shown() in FACE_VIEWER and a.speak_t <= 0.0 and a.attack_t <= 0.0 and a.hurt_t <= 0.0:
		return ["front", false]
	if absf(d.x) > absf(d.y) * 1.1:
		return ["side", d.x < 0.0]
	return ["front" if d.y >= 0.0 else "back", false]


static func animate(a: Actor, _dt: float, sp: float) -> void:
	var m := a.rig
	var r := a.root()
	var sf := state_frame(a, sp)
	var name: String = sf[0]
	var lift: float = sf[1]
	var fc := facing(a, sp)
	var idx: int
	if m.has("anims"):
		idx = SpriteImport.frame_index(m, name, fc[0], a.t)
	else:
		var block := 0
		if m.get("view", "side") == "top" and not m.get("creature", false):
			block = {"side": 0, "front": 1, "back": 2}[fc[0]]
		idx = block * BLOCK + FRAMES.find(name)
	var grid: Vector2i = m.get("grid", Vector2i(COLS, ROWS))
	var mat: ShaderMaterial = m["mat"]
	mat.set_shader_parameter("frame", Vector2(idx % grid.x, idx / grid.x))
	if fc[0] == "side" and (sp > 0.2 or absf(sin(a.yaw)) > 0.3 or m.get("view", "side") == "top"):
		mat.set_shader_parameter("flip", 1.0 if fc[1] != m.get("faces_left", false) else 0.0)
	elif fc[0] != "side":
		mat.set_shader_parameter("flip", 0.0)
	if a.behavior == "dance" and (name.begins_with("dance") or name.begins_with("cel")):
		var df := dance_flip(a.dance_style, a.t)
		if df >= 0:
			mat.set_shader_parameter("flip", float(df))
	var w: Variant = a.studio.world
	var tint := Color.WHITE
	if w != null and w.get("tint") is Color:
		tint = w.tint
	mat.set_shader_parameter("tint", tint)
	var px := 1.0 / PPM
	r.rotation = Vector3.ZERO
	if m.get("view", "side") == "top":
		# Lying on the ground; lifted by how far south they stand so they
		# draw over things behind them. Hops and floating move them north.
		# Swimmers' cut-off sprites shift south so the waterline sits where they are.
		var wade := 0.8 if a.swimming else 0.0
		r.position = Vector3(snappedf(a.pos.x, px), PixelTopWorld.depth_y(a.pos.z) + float(a.id % 16) * 0.0001, snappedf(a.pos.z - lift + wade, px))
		# Name tag and speech bubble above the head (north on screen), lifted
		# so they draw over the world.
		var head_n := float(m.get("height", 1.75)) * float(m.get("scale", 1.0))
		for lbl in [a.tag, a.bubble]:
			if is_instance_valid(lbl):
				(lbl as Node3D).position = Vector3(0, 1.0, -head_n - (0.3 if lbl == a.tag else 0.75))
	else:
		# Snap to the pixel grid; a tiny depth step per character stops
		# overlaps from flickering.
		r.position = Vector3(snappedf(a.pos.x, px), snappedf(a.pos.y + lift, px), a.pos.z + float(a.id % 16) * 0.004)


# ---------------------------------------------------------------- painting: people

static func _c(cfg: Dictionary, key: String, fallback: String) -> Color:
	var v: Variant = cfg.get(key)
	return U.col(str(v)) if v is String and v != "" else U.col(fallback)


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < FRAME and y < FRAME:
		img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


## A limb segment from `p` at `deg` (0 = down, 90 = forward), `len` px long
## and `wid` px thick. Returns the far end.
static func _limb(img: Image, p: Vector2, deg: float, len: int, wid: int, c: Color, tip := Color(0, 0, 0, 0), tip_len := 0) -> Vector2:
	var a := deg_to_rad(deg)
	var d := Vector2(sin(a), cos(a))
	for k in range(len + 1):
		var q := p + d * k
		var col := tip if tip.a > 0.0 and k > len - tip_len else c
		_rect(img, int(round(q.x - (wid - 1) * 0.5)), int(round(q.y - (wid - 1) * 0.5)), wid, wid, col)
	return p + d * len


static func _human_frame(cfg: Dictionary, name: String) -> Image:
	var img := Image.create(FRAME, FRAME, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var p: Dictionary = POSES.get(name, POSES["idle0"])
	if p.get("sleep", false):
		# Lie on the back: paint standing with eyes shut, then turn it over.
		var up := _human_frame(cfg, "idle2")
		up.rotate_90(COUNTERCLOCKWISE)
		# The figure now lies along the bottom-left; move it to the floor.
		var bounds := up.get_used_rect()
		img.blit_rect(up, bounds, Vector2i((FRAME - bounds.size.x) / 2, FRAME - bounds.size.y))
		return img
	_paint_human(img, cfg, p, name)
	return img


static func _paint_human(img: Image, cfg: Dictionary, p: Dictionary, name: String) -> void:
	var skin := _c(cfg, "skin", "#f0c8a0")
	var hair := _c(cfg, "hair", "#3b2a1e")
	var shirt := _c(cfg, "shirt", "#2a9d8f")
	var shirt2 := _c(cfg, "shirt2", U.shade_hex(str(cfg.get("shirt", "#2a9d8f")), 0.75))
	var pants := _c(cfg, "pants", "#2f3b52")
	var shoes := _c(cfg, "shoes", "#3a2a20")
	var eye := _c(cfg, "eyes", "#2b1b10")
	var robe: bool = cfg.get("robe", false)
	var bones: bool = cfg.get("bones", false)
	var dy := int(p.get("dy", 0))
	var lean := int(p.get("lean", 0))
	var sit: bool = p.get("sit", false)
	var af := float(p.get("af", 8))
	var ab := float(p.get("ab", -8))
	if cfg.get("pose", "") == "zombie" and name.begins_with("walk") or (cfg.get("pose", "") == "zombie" and name.begins_with("idle")):
		af = 88
		ab = 82
	var back := func(c: Color) -> Color: return U.shade(c, 0.72)
	var hip_y := 21 + dy
	var sh_y := 12 + dy
	var hx := 15 + lean
	# Back leg, back arm (darker, behind the body).
	if not robe or sit:
		var k1 := _limb(img, Vector2(15, hip_y), float(p.get("lb", 0)), 5, 2, back.call(pants))
		_limb(img, k1, float(p.get("lb", 0)) - float(p.get("lbk", 0)), 5, 2, back.call(pants), back.call(shoes), 2)
	var e1 := _limb(img, Vector2(hx, sh_y + 1), ab, 4, 2, back.call(shirt))
	_limb(img, e1, ab + float(p.get("abe", 0)), 4, 2, back.call(skin) if not bones else back.call(skin), back.call(skin), 2)
	# Torso.
	_rect(img, hx - 2, sh_y, 6, hip_y - sh_y + 1, shirt)
	_rect(img, hx - 2, hip_y - 2, 6, 1, shirt2)
	if cfg.get("overalls", false):
		_rect(img, hx - 2, sh_y + 4, 6, hip_y - sh_y - 3, pants)
		_px(img, hx - 1, sh_y + 1, pants)
		_px(img, hx + 2, sh_y + 1, pants)
	if bones:
		for yy in range(sh_y + 1, hip_y - 1, 2):
			_rect(img, hx - 1, yy, 4, 1, Color("8a8576"))
	if robe and not sit:
		_rect(img, hx - 3, hip_y - 2, 8, 31 - hip_y, shirt)
		_rect(img, hx - 3, 28, 8, 1, shirt2)
		_rect(img, hx - 1, 30, 4, 2, shoes)
	if cfg.get("cape") is String:
		_rect(img, hx - 4, sh_y + 1, 2, hip_y - sh_y + 4, _c(cfg, "cape", "#c0392b"))
	# Front leg.
	if not robe or sit:
		var lf := float(p.get("lf", 0))
		var k2 := _limb(img, Vector2(16, hip_y), lf, 5, 2, pants)
		var foot := _limb(img, k2, lf - float(p.get("lfk", 0)), 5, 2, pants, shoes, 2)
		if not sit:
			_px(img, int(foot.x) + 1, int(foot.y), shoes)
	elif sit:
		pass
	# Head.
	var hy := 4 + dy + int(p.get("hd", 0))
	var fx := hx - 3
	_rect(img, fx, hy + 1, 8, 7, skin)
	_px(img, fx + 8, hy + 4, skin)
	if cfg.get("ears", false):
		_px(img, fx + 1, hy + 2, skin)
		_px(img, fx, hy + 1, skin)
	var style := str(cfg.get("hairStyle", "short"))
	if style != "bald":
		_rect(img, fx, hy, 8, 2, hair)
		_rect(img, fx, hy + 2, 3, 3 if style == "short" else 9, hair)
	if cfg.get("beard") is String:
		_rect(img, fx + 3, hy + 6, 5, 2, _c(cfg, "beard", "#3b2a1e"))
	var eyes := str(p.get("eyes", "open"))
	var ex := fx + 5
	var ey := hy + 3
	match eyes:
		"closed":
			_rect(img, ex, ey + 1, 2, 1, U.shade(skin, 0.55))
		"happy":
			_px(img, ex, ey + 1, eye)
			_px(img, ex + 1, ey, eye)
		"cry":
			_px(img, ex, ey, eye)
			_px(img, ex, ey + 2, Color("6fc3ff"))
			_px(img, ex, ey + 3, Color("6fc3ff"))
		_:
			_rect(img, ex, ey, 1, 2, eye)
	if bones:
		_rect(img, ex - 1, ey, 2, 2, Color("111111"))
	match str(p.get("mouth", "")):
		"open":
			_rect(img, fx + 6, hy + 6, 2, 1, Color("6b2a2a"))
		"smile":
			_px(img, fx + 6, hy + 6, Color("6b2a2a"))
	_hat(img, cfg, fx, hy)
	# Front arm with what they carry.
	var e2 := _limb(img, Vector2(hx + 1, sh_y + 1), af, 4, 2, shirt)
	var hand := _limb(img, e2, af + float(p.get("ae", 0)), 4, 2, skin if not bones else skin, skin, 2)
	_tool(img, cfg, hand, af + float(p.get("ae", 0)))
	if p.get("swim", false):
		var wx := 15 + int(p.get("lean", 0))
		_waterline(img, 21, wx - 4, wx + 5)


static func _hat(img: Image, cfg: Dictionary, fx: int, hy: int) -> void:
	var kind := str(cfg.get("hat", "")) if cfg.get("hat") != null else ""
	var c := _c(cfg, "hatC", "#8a6236")
	match kind:
		"cap":
			_rect(img, fx, hy - 1, 8, 2, c)
			_rect(img, fx + 6, hy + 1, 4, 1, c)
		"straw":
			_rect(img, fx - 2, hy + 1, 12, 1, c)
			_rect(img, fx + 1, hy - 2, 6, 3, c)
			_rect(img, fx + 1, hy, 6, 1, U.shade(c, 0.7))
		"hood":
			_rect(img, fx - 1, hy - 1, 9, 2, c)
			_rect(img, fx - 1, hy + 1, 3, 8, c)
		"chef":
			_rect(img, fx + 1, hy - 4, 6, 5, c)
			_rect(img, fx, hy, 8, 1, U.shade(c, 0.85))
		"helmet":
			_rect(img, fx - 1, hy - 1, 9, 4, c)
			_rect(img, fx + 4, hy + 3, 4, 1, U.shade(c, 0.6))
			_px(img, fx + 3, hy - 2, Color("c0392b"))
		"wizard":
			_rect(img, fx - 2, hy + 1, 12, 1, c)
			for k in 5:
				_rect(img, fx + 1 + k / 2, hy - k, 6 - k, 1, c)
			_px(img, fx + 4, hy - 3, Color("f2c14e"))
		"crown":
			_rect(img, fx + 1, hy - 1, 6, 2, c)
			for k in [0, 2, 4]:
				_px(img, fx + 2 + k, hy - 2, c)
			_px(img, fx + 4, hy - 1, Color("e63946"))


static func _tool(img: Image, cfg: Dictionary, hand: Vector2, deg: float) -> void:
	if cfg.get("sword", false):
		_limb(img, hand, deg + 90, 7, 1, Color("d9e1e8"))
	elif cfg.get("staff", false):
		var top := _limb(img, hand + Vector2(0, 5), 180, 12, 1, Color("8a6236"))
		_rect(img, int(top.x) - 1, int(top.y) - 1, 3, 3, Color("9fe8ff"))
	elif cfg.get("pick", false):
		var top2 := _limb(img, hand, deg + 90, 5, 1, Color("8a6236"))
		_rect(img, int(top2.x) - 2, int(top2.y), 5, 1, Color("a7b0ba"))
	elif cfg.get("club", false):
		_limb(img, hand, deg + 80, 5, 2, Color("6e4a2a"))
	elif cfg.get("bow", false):
		for k in range(-4, 5):
			_px(img, int(hand.x) + 1 + (2 - absi(k) / 2), int(hand.y) + k, Color("8a6236"))


# ---------------------------------------------------------------- painting: front and back (top view)

## Front-on poses. Arm angles in degrees for each arm, measured outward:
## 0 hangs down, 90 sticks out sideways, 180 points up; over 180 swings in
## across the body. `are`/`ale` are the forearm angles (default: straight).
## `lr`/`ll` lift a foot, `dy` drops the body.
const FPOSES := {
	"idle0": {"ar": 6, "al": 6},
	"idle1": {"ar": 4, "al": 4, "dy": 1},
	"idle2": {"ar": 6, "al": 6, "eyes": "closed"},
	"walk0": {"ar": 12, "al": 2, "ll": 2},
	"walk1": {"ar": 6, "al": 6, "dy": -1},
	"walk2": {"ar": 2, "al": 12, "lr": 2},
	"walk3": {"ar": 6, "al": 6, "dy": -1},
	"jump": {"ar": 150, "al": 150, "ll": 2, "lr": 2, "dy": -2},
	"crouch": {"ar": 30, "al": 30, "ll": 3, "lr": 3, "dy": 4},
	"sit": {"ar": 20, "al": 20, "dy": 7, "sit": true},
	"sleep": {"sleep": true},
	"wave0": {"ar": 160, "are": 150, "al": 6, "mouth": "smile"},
	"wave1": {"ar": 150, "are": 190, "al": 6, "mouth": "smile"},
	"talk0": {"ar": 45, "are": 100, "al": 6, "mouth": "open"},
	"talk1": {"ar": 35, "are": 70, "al": 6},
	"dance0": {"ar": 160, "al": 160, "ll": 2, "mouth": "smile"},
	"dance1": {"ar": 100, "are": 150, "al": 30, "mouth": "smile"},
	"dance2": {"ar": 30, "al": 100, "ale": 150, "lr": 2, "mouth": "smile"},
	"dance3": {"ar": 170, "al": 170, "dy": -2, "mouth": "smile"},
	"cel0": {"ar": 165, "al": 165, "dy": -2, "mouth": "open", "eyes": "happy"},
	"cel1": {"ar": 150, "al": 150, "mouth": "open", "eyes": "happy"},
	"laugh0": {"ar": 20, "are": 280, "al": 20, "ale": 280, "mouth": "open", "eyes": "happy"},
	"laugh1": {"ar": 20, "are": 280, "al": 20, "ale": 280, "dy": 1, "mouth": "open", "eyes": "happy"},
	"cry0": {"ar": 25, "are": 200, "al": 25, "ale": 200, "hd": 1, "eyes": "cry"},
	"cry1": {"ar": 25, "are": 200, "al": 25, "ale": 200, "hd": 1, "dy": 1, "eyes": "cry"},
	"point": {"ar": 90, "al": 6},
	"guard": {"ar": 35, "are": 165, "al": 35, "ale": 165},
	"atk0": {"ar": 170, "al": 10},
	"atk1": {"ar": 60, "al": 10, "mouth": "open"},
	"hurt": {"ar": 30, "al": 30, "dy": 1, "eyes": "closed", "mouth": "open"},
	"climb0": {"ar": 160, "al": 140, "ll": 2},
	"climb1": {"ar": 140, "al": 160, "lr": 2},
	"swim0": {"ar": 110, "are": 150, "al": 40, "swim": true},
	"swim1": {"ar": 40, "al": 110, "ale": 150, "swim": true},
	"tread0": {"ar": 110, "are": 150, "al": 40, "swim": true},
	"tread1": {"ar": 40, "al": 110, "ale": 150, "swim": true},
}


## One arm, front-on. `side` is +1 for the arm on the right of the picture.
static func _farm(img: Image, sh: Vector2, side: int, upper: float, fore: float, sleeve: Color, skin: Color) -> Vector2:
	var a := deg_to_rad(upper)
	var d := Vector2(sin(a) * side, cos(a))
	var e := sh
	for k in range(5):
		e = sh + d * k
		_rect(img, int(round(e.x)) - (1 if side < 0 else 0), int(round(e.y)), 2, 2, sleeve)
	var b := deg_to_rad(fore)
	var d2 := Vector2(sin(b) * side, cos(b))
	var hnd := e
	for k in range(1, 5):
		hnd = e + d2 * k
		_rect(img, int(round(hnd.x)) - (1 if side < 0 else 0), int(round(hnd.y)), 2, 2, sleeve if k < 3 else skin)
	return hnd


static func _front_frame(cfg: Dictionary, name: String, back: bool) -> Image:
	var img := Image.create(FRAME, FRAME, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var p: Dictionary = FPOSES.get(name, FPOSES["idle0"])
	if p.get("sleep", false):
		var up := _front_frame(cfg, "idle2", back)
		up.rotate_90(COUNTERCLOCKWISE)
		var bounds := up.get_used_rect()
		img.blit_rect(up, bounds, Vector2i((FRAME - bounds.size.x) / 2, FRAME - bounds.size.y))
		return img
	var skin := _c(cfg, "skin", "#f0c8a0")
	var hair := _c(cfg, "hair", "#3b2a1e")
	var shirt := _c(cfg, "shirt", "#2a9d8f")
	var shirt2 := _c(cfg, "shirt2", U.shade_hex(str(cfg.get("shirt", "#2a9d8f")), 0.75))
	var pants := _c(cfg, "pants", "#2f3b52")
	var shoes := _c(cfg, "shoes", "#3a2a20")
	var eye := _c(cfg, "eyes", "#2b1b10")
	var robe: bool = cfg.get("robe", false)
	var bones: bool = cfg.get("bones", false)
	var dy := int(p.get("dy", 0))
	var sit: bool = p.get("sit", false)
	var ar := float(p.get("ar", 6))
	var al := float(p.get("al", 6))
	if cfg.get("pose", "") == "zombie" and (name.begins_with("walk") or name.begins_with("idle")):
		ar = 100
		al = 100
	var sh_y := 12 + dy
	var hip_y := 21 + dy
	# Legs.
	if not robe or sit:
		for lg in [[13, int(p.get("ll", 0))], [17, int(p.get("lr", 0))]]:
			var lx: int = lg[0]
			var lift: int = lg[1]
			if sit:
				_rect(img, lx, hip_y, 2, 3, pants)
				_rect(img, lx, hip_y + 3, 2, 1, shoes)
			else:
				var foot := 31 - lift
				_rect(img, lx, hip_y, 2, foot - hip_y - 1, pants)
				_rect(img, lx, foot - 1, 2, 2, shoes)
	# Torso.
	_rect(img, 12, sh_y, 8, hip_y - sh_y + 1, shirt)
	_rect(img, 12, hip_y - 1, 8, 1, shirt2)
	if cfg.get("overalls", false):
		_rect(img, 13, sh_y + 3, 6, hip_y - sh_y - 2, pants)
		_px(img, 13, sh_y, pants)
		_px(img, 18, sh_y, pants)
	if bones:
		for yy in range(sh_y + 1, hip_y - 1, 2):
			_rect(img, 13, yy, 6, 1, Color("8a8576"))
	if robe and not sit:
		_rect(img, 11, hip_y - 1, 10, 30 - hip_y, shirt)
		_rect(img, 11, 28, 10, 1, shirt2)
		_rect(img, 13, 30, 2, 2, shoes)
		_rect(img, 17, 30, 2, 2, shoes)
	if cfg.get("cape") is String:
		var cape_c := _c(cfg, "cape", "#c0392b")
		if back:
			# Seen from behind the cape covers the back, down to the knees.
			_rect(img, 11, sh_y, 10, mini(hip_y - sh_y + 6, 30 - sh_y), cape_c)
			_rect(img, 11, sh_y, 10, 1, U.shade(cape_c, 0.8))
		else:
			# From the front only the clasps at the shoulders show.
			_px(img, 12, sh_y, cape_c)
			_px(img, 19, sh_y, cape_c)
	# Head.
	var hy := 4 + dy + int(p.get("hd", 0))
	_rect(img, 12, hy + 1, 8, 7, skin)
	var style := str(cfg.get("hairStyle", "short"))
	if back:
		if style != "bald":
			_rect(img, 12, hy, 8, 8 if style == "short" else 12, hair)
	else:
		if style != "bald":
			_rect(img, 12, hy, 8, 2, hair)
			_rect(img, 12, hy + 2, 1, 3 if style == "short" else 9, hair)
			_rect(img, 19, hy + 2, 1, 3 if style == "short" else 9, hair)
		if cfg.get("ears", false):
			_px(img, 11, hy + 3, skin)
			_px(img, 20, hy + 3, skin)
		if cfg.get("beard") is String:
			_rect(img, 13, hy + 6, 6, 2, _c(cfg, "beard", "#3b2a1e"))
		var eyes := str(p.get("eyes", "open"))
		for ex in [14, 17]:
			match eyes:
				"closed":
					_px(img, ex, hy + 4, U.shade(skin, 0.55))
				"happy":
					_px(img, ex, hy + 3, eye)
				"cry":
					_px(img, ex, hy + 3, eye)
					_px(img, ex, hy + 5, Color("6fc3ff"))
				_:
					_rect(img, ex, hy + 3, 1, 2, eye)
			if bones:
				_rect(img, ex, hy + 3, 1, 2, Color("111111"))
		match str(p.get("mouth", "")):
			"open":
				_rect(img, 15, hy + 6, 2, 1, Color("6b2a2a"))
			"smile":
				_rect(img, 15, hy + 6, 2, 1, Color("8a3a3a"))
	_fhat(img, cfg, hy, back)
	# Arms over the body (so hands on the belly or face show).
	var hand_r := _farm(img, Vector2(20, sh_y + 1), 1, ar, float(p.get("are", ar)), shirt, skin)
	_farm(img, Vector2(11, sh_y + 1), -1, al, float(p.get("ale", al)), shirt, skin)
	if not back:
		_tool(img, cfg, hand_r, 180.0 if ar > 120.0 else 90.0)
	if p.get("swim", false):
		_waterline(img, 19, 11, 21)
	return img


static func _fhat(img: Image, cfg: Dictionary, hy: int, back: bool) -> void:
	var kind := str(cfg.get("hat", "")) if cfg.get("hat") != null else ""
	var c := _c(cfg, "hatC", "#8a6236")
	match kind:
		"cap":
			_rect(img, 12, hy - 1, 8, 2, c)
			if not back:
				_rect(img, 12, hy + 1, 8, 1, U.shade(c, 0.8))
		"straw":
			_rect(img, 9, hy + 1, 14, 1, c)
			_rect(img, 13, hy - 2, 6, 3, c)
		"hood":
			_rect(img, 11, hy - 1, 10, 2, c)
			_rect(img, 11, hy + 1, 1, 8, c)
			_rect(img, 20, hy + 1, 1, 8, c)
			if back:
				_rect(img, 12, hy, 8, 9, c)
		"chef":
			_rect(img, 13, hy - 4, 6, 5, c)
			_rect(img, 12, hy, 8, 1, U.shade(c, 0.85))
		"helmet":
			_rect(img, 11, hy - 1, 10, 4, c)
			if not back:
				_rect(img, 13, hy + 3, 6, 1, U.shade(c, 0.6))
		"wizard":
			_rect(img, 9, hy + 1, 14, 1, c)
			for k in 5:
				_rect(img, 13 + k / 2, hy - k, 6 - k, 1, c)
		"crown":
			_rect(img, 13, hy - 1, 6, 2, c)
			for k in [0, 2, 4]:
				_px(img, 13 + k, hy - 2, c)


# ---------------------------------------------------------------- painting: critters

static func _creature_frame(cfg: Dictionary, name: String) -> Image:
	var img := Image.create(FRAME, FRAME, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var kind := str(cfg.get("creature", "slime"))
	var col := _c(cfg, "col", "#7ed957")
	var dark := U.shade(col, 0.7)
	var step := 0
	if name.begins_with("walk"):
		step = int(name.substr(4)) % 4
	var hop := 0
	if name in ["jump", "dance0", "dance3", "cel0"]:
		hop = 3
	var shut := name in ["sleep", "idle2"]
	var down := name in ["sleep", "sit", "crouch"]
	match kind:
		"slime":
			var sq: int = [0, 1, 0, -1][step] if name.begins_with("walk") else (1 if name == "idle1" else 0)
			var w := 14 + sq * 2
			var h := 9 - sq - (2 if down else 0)
			var x0 := 16 - w / 2
			var y0 := 31 - h - hop
			for yy in h:
				var inset := 2 if yy == 0 else (1 if yy == 1 else 0)
				_rect(img, x0 + inset, y0 + yy, w - inset * 2, 1, col if yy < h - 2 else dark)
			_px(img, x0 + 3, y0 + 2, Color.WHITE)
			_rect(img, x0 + w - 6, y0 + 3, 2, 1 if shut else 2, Color("1b1626"))
			_rect(img, x0 + w - 3, y0 + 3, 1, 1 if shut else 2, Color("1b1626"))
		"ghost":
			var y0 := 6 - hop
			_rect(img, 10, y0 + 2, 12, 16, col)
			_rect(img, 11, y0, 10, 2, col)
			for k in 4:
				_rect(img, 10 + k * 3, y0 + 18, 2, 2 + ((k + step) % 2), col)
			_rect(img, 17, y0 + 6, 2, 1 if shut else 3, Color("1b1626"))
			_rect(img, 20, y0 + 6, 1, 1 if shut else 3, Color("1b1626"))
			_rect(img, 18, y0 + 11, 2, 2, Color("1b1626"))
		"bat":
			var flap := (step % 2 == 0) if name.begins_with("walk") else (name != "idle1")
			var y0 := 12 - hop
			_rect(img, 13, y0, 6, 5, col)
			_px(img, 13, y0 - 1, col)
			_px(img, 18, y0 - 1, col)
			_px(img, 17, y0 + 1, Color("ff5d5d"))
			for k in 6:
				var dyw := -k / 2 if flap else k / 2
				_px(img, 12 - k, y0 + 2 + dyw, dark)
				_px(img, 19 + k, y0 + 2 + dyw, dark)
		_:
			_quad(img, cfg, kind, col, dark, step, hop, down, shut)
	return img


## Four-legged and bird critters seen from the side, facing right.
static func _quad(img: Image, cfg: Dictionary, kind: String, col: Color, dark: Color, step: int, hop: int, down: bool, shut: bool) -> void:
	var spec: Dictionary = {
		"chicken": {"bw": 8, "bh": 6, "hw": 4, "hh": 4, "leg": 3, "legs": 1},
		"pig": {"bw": 13, "bh": 7, "hw": 5, "hh": 5, "leg": 3, "legs": 2},
		"dog": {"bw": 11, "bh": 5, "hw": 5, "hh": 5, "leg": 4, "legs": 2},
		"cat": {"bw": 10, "bh": 4, "hw": 4, "hh": 4, "leg": 3, "legs": 2},
		"sheep": {"bw": 12, "bh": 8, "hw": 4, "hh": 4, "leg": 4, "legs": 2},
		"frog": {"bw": 9, "bh": 5, "hw": 4, "hh": 4, "leg": 2, "legs": 1},
	}.get(kind, {"bw": 10, "bh": 6, "hw": 4, "hh": 4, "leg": 3, "legs": 2})
	var leg: int = 0 if down else spec["leg"]
	var bw: int = spec["bw"]
	var bh: int = spec["bh"]
	var ground := 31 - hop
	var by := ground - leg - bh + 1
	var bx := 16 - bw / 2 - 1
	var leg_c := dark if kind != "chicken" else Color("f2a03a")
	if kind == "sheep":
		leg_c = Color("2a2a2a")
	# Legs (alternate while walking).
	if leg > 0:
		var xs: Array = [bx + 2, bx + bw - 3] if int(spec["legs"]) == 2 else [bx + bw / 2]
		for i in xs.size():
			var lx: int = xs[i]
			var off := 0
			if step == 1 or step == 3:
				off = 1 if i == 0 else -1
			_rect(img, lx + off, by + bh, 1, leg, leg_c)
			_rect(img, lx - off + 1, by + bh, 1, leg, U.shade(leg_c, 0.8))
	# Body.
	_rect(img, bx, by, bw, bh, col)
	_rect(img, bx, by + bh - 1, bw, 1, dark)
	if kind == "sheep":
		for k in 10:
			_px(img, bx + (k * 5) % bw, by + (k * 3) % bh, Color("dcdcd6"))
	# Tail.
	match kind:
		"dog":
			_rect(img, bx - 2, by - 2, 2, 2, col)
		"cat":
			for k in 5:
				_px(img, bx - 1, by - k, col)
		"pig":
			_px(img, bx - 1, by + 1, U.shade(col, 0.8))
		"chicken":
			_rect(img, bx - 2, by - 1, 2, 3, col)
	# Head.
	var hw: int = spec["hw"]
	var hh: int = spec["hh"]
	var hx := bx + bw - 1
	var hy := by - hh + 2 if kind not in ["pig", "frog", "sheep"] else by
	if down:
		hy += 2
	var head_c := Color("2a2a2a") if kind == "sheep" else col
	_rect(img, hx, hy, hw, hh, head_c)
	var eye_c := Color.WHITE if kind == "sheep" else Color("1b1626")
	_rect(img, hx + hw - 2, hy + 1, 1, 1, U.shade(head_c, 0.5) if shut else eye_c)
	match kind:
		"chicken":
			_rect(img, hx + hw, hy + 2, 2, 1, Color("f2a03a"))
			_rect(img, hx + 1, hy - 1, 2, 1, Color("e63946"))
		"pig":
			_rect(img, hx + hw, hy + 2, 2, 2, U.shade(col, 0.85))
			_px(img, hx + 1, hy - 1, col)
		"dog":
			_rect(img, hx + hw, hy + 2, 2, 2, col)
			_px(img, hx + hw + 1, hy + 2, Color("1b1626"))
			_rect(img, hx, hy - 1, 2, 3, U.shade(col, 0.7))
		"cat":
			_px(img, hx, hy - 1, col)
			_px(img, hx + hw - 1, hy - 1, col)
		"frog":
			_rect(img, hx + 1, hy - 2, 3, 2, col)
			_px(img, hx + 2, hy - 2, Color("1b1626"))


## Swimming: everything below the waterline is hidden, with a small ripple
## across the body only (x0..x1).
static func _waterline(img: Image, y: int, x0: int, x1: int) -> void:
	for yy in range(y, FRAME):
		for x in FRAME:
			img.set_pixel(x, yy, Color(0, 0, 0, 0))
	for x in range(x0, x1):
		if x % 2 == 0:
			_px(img, x, y, Color("cfeeff"))


## Dark 1 px outline around the silhouette (classic pixel-art look).
static func outline(img: Image) -> void:
	var src := img.duplicate() as Image
	var iw := img.get_width()
	var ih := img.get_height()
	for y in ih:
		for x in iw:
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < iw and n.y < ih and src.get_pixel(n.x, n.y).a > 0.5:
					img.set_pixel(x, y, OUTLINE)
					break
