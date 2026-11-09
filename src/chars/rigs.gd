class_name Rigs
## Character factory: presets per style and `build(look, style)`, which
## returns a rig dictionary the actor animates (see the keys in `build`).

const NAMES := ["Om", "Vaish", "Jay", "Shri", "Anju", "Siddu", "Meera", "Arjun", "Kabir", "Riya", "Tara", "Dev", "Isha", "Rohan", "Neha", "Kiran", "Asha", "Vikram", "Pooja", "Aditya", "Sneha", "Rahul", "Divya", "Aarav", "Kavya", "Nikhil", "Priya", "Yash", "Lakshmi", "Ganesh"]
const CHATTER := ["Nice weather today.", "Did you hear that?", "I’m off to the market.", "Have you seen the new bridge?", "Hmm…", "Welcome, traveler!", "What a day.", "I lost my bucket again.", "Ha! Good one.", "Really? No way!", "Let’s meet by the well later.", "I think it’ll rain soon."]
const GROUPS := [["people", "People"], ["mobs", "Monsters"], ["animals", "Animals"]]

## The player is always Vaibh; everyone else gets an Indian name.
const DEFAULT_CAST := {
	"blocky": [["hero", "Vaibh"], ["farmer", "Om", "wander"], ["merchant", "Vaish", "talk"], ["chef", "Jay", "talk"], ["dancer", "Shri", "dance"], ["guard", "Siddu", "follow"]],
	"anime": [["wanderer", "Vaibh"], ["ranger", "Anju", "wander"], ["mage", "Shri", "talk"], ["keeper", "Vaish", "talk"], ["bard", "Meera", "dance"], ["ronin", "Siddu", "follow"], ["slimeGreen", "Golu", "wander"], ["slimeBlue", "Chintu", "wander"]],
	"pixel": [["hero", "Vaibh"], ["farmer", "Om", "wander"], ["merchant", "Vaish", "talk"], ["chef", "Anju", "talk"], ["knight", "Siddu", "patrol"], ["wizard", "Shri", "dance"], ["slime", "Golu", "wander"], ["dog", "Moti", "follow"]],
	"pixeltop": [["hero", "Vaibh"], ["farmer", "Jay", "wander"], ["merchant", "Vaish", "talk"], ["chef", "Anju", "talk"], ["knight", "Siddu", "patrol"], ["wizard", "Om", "dance"], ["princess", "Shri", "wander"], ["slime", "Golu", "wander"], ["dog", "Moti", "follow"]],
	"lowpoly": [["villager", "Vaibh"], ["explorer", "Om", "wander"], ["baker", "Anju", "talk"], ["farmer", "Jay", "talk"], ["kid", "Siddu", "dance"], ["knight", "Vaish", "follow"]],
}

const CHAR_PRESETS := {
	"anime": {
		"wanderer": {"legs": "pants", "boots": "tall", "label": "Wanderer", "skin": "#f6dcc8", "hair": "#2bb3a3", "hairStyle": "spiky", "eyes": "#e8a92e", "shirt": "#f4f2ec", "shirt2": "#2a7f87", "coatC": "#2a7f87", "pants": "#2d3346", "shoes": "#6b4a2b", "coat": "short", "cape": true, "weapon": "sword", "lines": ["The wind feels different today.", "Where does this road lead?", "Stay close."]},
		"mage": {"legs": "stockings", "sock": "#2a2440", "boots": "short", "ornC": "#c9a8ff", "label": "Mage", "skin": "#f8e2d2", "hair": "#8a6fd6", "hairStyle": "long", "eyes": "#6f4ad1", "shirt": "#efe7ff", "shirt2": "#e3b84a", "coatC": "#3a2f6b", "pants": "#3a2f6b", "shoes": "#2a2240", "coat": "long", "hat": "witch", "weapon": "staff", "sleeve": 1, "lines": ["The stars are restless.", "Careful, that spell is fresh.", "I sense something nearby…"]},
		"ronin": {"boots": "tall", "ornament": false, "label": "Swordsman", "skin": "#efcfb4", "hair": "#1c1c26", "hairStyle": "spiky", "eyes": "#b8323a", "shirt": "#2a2a35", "shirt2": "#c8393b", "coatC": "#2a2a35", "pants": "#1f1f28", "shoes": "#141418", "coat": "short", "scarf": true, "weapon": "sword", "sleeve": 1, "lines": ["Hmph.", "My blade is ready.", "Not bad."]},
		"ranger": {"boots": "tall", "ornC": "#ffd166", "label": "Ranger", "skin": "#e9c3a3", "hair": "#7a4a2a", "hairStyle": "pony", "eyes": "#3f8a4a", "shirt": "#4f8f4a", "shirt2": "#8b5a2b", "coatC": "#6e4b2c", "pants": "#3d3528", "shoes": "#5a3b22", "coat": "short", "weapon": "bow", "lines": ["Tracks lead east.", "Quiet, I hear something.", "Nice shot, huh?"]},
		"keeper": {"legs": "stockings", "sock": "#f6f2ee", "boots": "short", "ornC": "#ff7aa2", "label": "Shrine keeper", "skin": "#f8e6da", "hair": "#f2f2f7", "hairStyle": "twin", "eyes": "#d24a6a", "shirt": "#fbfbfb", "shirt2": "#c8393b", "coatC": "#c8393b", "pants": "#c8393b", "shoes": "#3a2a2a", "coat": "skirt", "lines": ["Welcome, traveler.", "The festival starts tonight!", "Please, make a wish."]},
		"bard": {"legs": "bare", "boots": "tall", "ornC": "#ffd166", "label": "Bard", "skin": "#f3d2bd", "hair": "#f28dbb", "hairStyle": "short", "eyes": "#3c78d8", "shirt": "#ffd166", "shirt2": "#ff7aa2", "coatC": "#ff7aa2", "pants": "#3a3a52", "shoes": "#ffffff", "coat": "skirt", "hat": "circlet", "lines": ["Let’s sing!", "I wrote a new song!", "Everyone, gather round!"]},
		"slimeGreen": {"label": "Green slime", "group": "mobs", "creature": "slime", "col": "#86d96a", "beh": "wander", "lines": ["*boing*", "*squish*"]},
		"slimeBlue": {"label": "Blue slime", "group": "mobs", "creature": "slime", "col": "#6fb8ff", "beh": "wander", "lines": ["*bloop*", "*wobble*"]},
		"slimeEmber": {"label": "Ember slime", "group": "mobs", "creature": "slime", "col": "#ff9a4a", "beh": "chase", "lines": ["*sizzle*", "*pop*"]},
		"goblin": {"label": "Goblin", "group": "mobs", "skin": "#8fb35a", "hair": "#2a3a1e", "hairStyle": "short", "eyes": "#e8c33a", "shirt": "#7a5a3a", "shirt2": "#4a3a2a", "coatC": "#6b4f33", "pants": "#5a4430", "shoes": "#3a2a1e", "coat": "skirt", "sleeve": 0, "ears": "pointy", "weapon": "club", "scale": 0.72, "ornament": false, "beh": "chase", "lines": ["Grrah!", "Mine!", "Hehehe!"]},
		"wolf": {"label": "Wolf", "group": "mobs", "creature": "wolf", "col": "#8f99a8", "col2": "#e8e6e0", "eye": "#f2c14e", "beh": "wander", "lines": ["Grrr…", "Awoooo!"]},
		"wisp": {"label": "Wisp", "group": "mobs", "creature": "wisp", "col": "#9fe8ff", "beh": "wander", "lines": ["*hums*", "*twinkle*"]},
		"scholar": {"boots": "short", "ornament": false, "label": "Scholar", "skin": "#e2b896", "hair": "#c9ced9", "hairStyle": "short", "eyes": "#2e6fa8", "shirt": "#ffffff", "shirt2": "#2c3e6b", "coatC": "#2c3e6b", "pants": "#2c3e6b", "shoes": "#1f2433", "coat": "long", "sleeve": 1, "lines": ["Fascinating.", "According to my notes…", "Have you read this?"]},
	},
	"lowpoly": {
		"villager": {"label": "Villager", "skin": "#e9b98f", "hair": "#6b4a2b", "shirt": "#d9822b", "pants": "#5b4a3a", "shoes": "#3a2a20", "lines": ["Lovely day!", "Have you met the baker?", "I need more firewood."]},
		"knight": {"label": "Knight", "skin": "#f0c8a0", "hat": "helmet", "hatC": "#b8bec7", "shirt": "#9aa3ad", "apron": "#b33a3a", "cape": "#b33a3a", "pants": "#6f7781", "shoes": "#4a5058", "sleeve": 1, "lines": ["For the village!", "All quiet at the gate.", "Stand aside, please."]},
		"farmer": {"label": "Farmer", "skin": "#c98d62", "hair": "#5a3b22", "hat": "straw", "hatC": "#e2c46b", "shirt": "#6aa84f", "pants": "#4a6fa5", "shoes": "#5a3b22", "lines": ["The harvest looks good.", "Mind the carrots!", "Rain would help."]},
		"baker": {"label": "Baker", "skin": "#f1c9a5", "hair": "#8a5a3b", "hat": "chef", "shirt": "#e9c8a0", "apron": "#f6f4ef", "pants": "#6b5a4a", "shoes": "#3a2a20", "lines": ["Fresh bread!", "Who took my rolling pin?", "Pie’s almost ready."]},
		"explorer": {"label": "Explorer", "skin": "#b97a50", "hair": "#2b1b10", "hat": "ranger", "hatC": "#7a5a3a", "shirt": "#c2a36b", "pants": "#5b5340", "shoes": "#3b2a1a", "lines": ["I found a map!", "Over those hills…", "Adventure awaits."]},
		"kid": {"label": "Kid", "skin": "#f3d2bd", "hair": "#f2c94c", "shirt": "#2aa198", "pants": "#34495e", "shoes": "#e74c3c", "scale": 0.72, "lines": ["Wanna play?", "Tag, you’re it!", "I’m not tired!"]},
		"elder": {"label": "Elder", "skin": "#e6bf9c", "hair": "#ecebe7", "beard": "#ecebe7", "shirt": "#6c4f8f", "pants": "#4a3a5a", "shoes": "#2a2230", "sleeve": 1, "lines": ["In my day…", "Patience, young one.", "The old tales are true."]},
	},
}

const RAND_POOLS := {
	"skins": ["#f6dcc8", "#f1c9a5", "#e0ac7e", "#c98d62", "#a86b46", "#8d5a3b", "#5e3a26"],
	"hairs": ["#1e1612", "#3b2a1e", "#6b4a2b", "#a0522d", "#d9b26a", "#e8e8e8", "#2bb3a3", "#8a6fd6", "#f28dbb", "#3c78d8"],
	"cloth": ["#c8393b", "#3b5bc8", "#3f9e4d", "#e6c13b", "#7b4fa0", "#e07aa8", "#2a9d8f", "#d9822b", "#5c6670", "#f4f4f4", "#2c3e6b", "#4f8f4a"],
}

static var _presets := {}


## key -> preset dict (label, group, lines, beh, creature, look fields...).
static func presets_for(style: String) -> Dictionary:
	if _presets.has(style):
		return _presets[style]
	var src := {}
	if style == "blocky":
		src.merge(Skins.SKIN_PRESETS)
		src.merge(Skins.MOB_SKINS)
		src.merge(Skins.ANIMALS)
	elif style == "pixel" or style == "pixeltop":
		src = PixelSprites.PRESETS
	else:
		src = CHAR_PRESETS.get(style, {})
	var out := {}
	for k in src:
		var p: Dictionary = (src[k] as Dictionary).duplicate(true)
		if not p.has("group"):
			p["group"] = "people"
		if not p.has("lines"):
			p["lines"] = []
		out[k] = p
	_presets[style] = out
	return out


static func cfg_for(look: Dictionary, style: String) -> Dictionary:
	if look.get("cfg") is Dictionary:
		return look["cfg"]
	var P := presets_for(style)
	var key: String = str(look.get("preset", ""))
	if P.has(key):
		return P[key]
	return P[P.keys()[0]] if not P.is_empty() else {}


static func random_cfg(style: String) -> Dictionary:
	var R := RAND_POOLS
	var pk := func(a: Array) -> Variant: return U.pick(a)
	if style == "blocky":
		return Skins.random_skin_cfg()
	if style == "pixel" or style == "pixeltop":
		return PixelSprites.random_cfg()
	if style == "anime":
		return {"skin": pk.call(R["skins"].slice(0, 4)), "hair": pk.call(R["hairs"]), "hairStyle": pk.call(["short", "spiky", "long", "twin", "pony"]),
			"eyes": pk.call(["#e8a92e", "#3c78d8", "#3f8a4a", "#d24a6a", "#6f4ad1"]), "shirt": pk.call(R["cloth"]), "shirt2": pk.call(R["cloth"]), "coatC": pk.call(R["cloth"]),
			"pants": pk.call(["#2d3346", "#3a2f6b", "#1f1f28", "#3d3528"]), "shoes": pk.call(["#6b4a2b", "#141418", "#ffffff"]), "coat": pk.call(["short", "long", "skirt", null]),
			"cape": randf() < 0.3, "scarf": randf() < 0.25, "weapon": pk.call([null, null, "sword", "bow", "staff"]),
			"boots": pk.call(["tall", "short"]), "legs": pk.call(["pants", "pants", "stockings", "bare"]), "ornC": pk.call(["#ffffff", "#ffd166", "#ff7aa2", "#c9a8ff"])}
	return {"skin": pk.call(R["skins"]), "hair": pk.call(R["hairs"].slice(0, 7)), "hairStyle": pk.call(["short", "long"]), "hat": pk.call([null, null, "straw", "chef", "ranger", "hood"]),
		"hatC": pk.call(R["cloth"]), "shirt": pk.call(R["cloth"]), "pants": pk.call(["#5b4a3a", "#4a6fa5", "#34495e", "#6b5a4a"]), "shoes": "#3a2a20",
		"apron": U.maybe("#f6f4ef", 0.25), "beard": U.maybe("#ecebe7", 0.15)}


static func validate_skin(img: Image) -> String:
	return Skins.validate_skin(img)


## Builds a character for `look` in `style`. look: {preset} | {cfg} |
## {png: data-url, slim?} (blocky). Returned keys: root, model, upper, head,
## hc (or null), armL, armR, legL, legR, headH, height, sitDrop, kind
## ("human" | "quad"), scale, plus optional cape, float, spinUpper, hop,
## pose, creature, torso, skin (Image, blocky humans).
static func build(look: Dictionary, style: String) -> Dictionary:
	if style == "pixel" or style == "pixeltop":
		return PixelSprites.build(look, "top" if style == "pixeltop" else "side")
	var sty := Styles.get_style(style)
	Kit.shade = sty["shade"]
	Kit.outline_width = 0.008
	var rig: Dictionary
	var cfg := {}
	if style == "blocky":
		var key: String = str(look.get("preset", ""))
		if look.get("png") == null and look.get("cfg") == null and Skins.ANIMALS.has(key):
			rig = Skins.build_creature(key)
		else:
			var img: Image = null
			var legacy := false
			if look.get("png"):
				img = U.image_from_data_url(str(look["png"]))
				if Skins.validate_skin(img) != "":
					img = null
				else:
					img.convert(Image.FORMAT_RGBA8)
					legacy = img.get_height() * 2 == img.get_width()
			if img == null:
				cfg = cfg_for(look, style) if not look.get("png") else Skins.SKIN_PRESETS["hero"]
				img = Skins.paint_skin(cfg)
			rig = Skins.build_model(img, legacy, bool(look.get("slim", false)) or bool(cfg.get("slim", false)))
			if cfg.get("witchHat", false):
				Skins.add_witch_hat(rig)
			if cfg.get("pose"):
				rig["pose"] = cfg["pose"]
	else:
		cfg = cfg_for(look, style)
		if style == "anime":
			rig = Humans.build_anime_creature(cfg) if cfg.get("creature") else Humans.build_anime(cfg)
		else:
			rig = Humans.build_lowpoly(cfg)
		if cfg.get("pose"):
			rig["pose"] = cfg["pose"]
	var sc: float = float(cfg["scale"]) if cfg.get("scale") else 1.0
	var root: Node3D = rig["root"]
	root.scale = Vector3.ONE * sc
	rig["scale"] = sc
	for k in ["hc", "cape"]:
		if not rig.has(k):
			rig[k] = null
	if not rig.has("kind"):
		rig["kind"] = "human"
	for k in ["float", "spinUpper", "hop"]:
		rig[k] = bool(rig.get(k, false))
	if cfg.get("creature") and not rig.has("creature"):
		rig["creature"] = str(cfg["creature"])
	# Batch each rigid part into one mesh per material (far fewer draw calls).
	for k in ["root", "model", "upper", "head", "hc", "armL", "armR", "legL", "legR", "cape"]:
		var n: Variant = rig.get(k)
		if n is Node3D:
			Kit.merge_children(n)
	root.set_meta("frame_h", float(rig["height"]) * sc)
	root.set_meta("head_h", float(rig["headH"]) * sc)
	return rig
