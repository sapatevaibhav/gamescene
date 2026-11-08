class_name Skins
## Blocky style: 64x64 pixel-skin characters (painted presets, mobs and
## uploaded skins) plus the blocky animals and monsters.

const PX := 0.9 / 16.0

const PARTS := {
	"head": {"u": 0, "v": 0, "w": 8, "h": 8, "d": 8, "o": [32, 0]},
	"body": {"u": 16, "v": 16, "w": 8, "h": 12, "d": 4, "o": [16, 32]},
	"armR": {"u": 40, "v": 16, "w": 4, "h": 12, "d": 4, "o": [40, 32]},
	"armL": {"u": 32, "v": 48, "w": 4, "h": 12, "d": 4, "o": [48, 48]},
	"legR": {"u": 0, "v": 16, "w": 4, "h": 12, "d": 4, "o": [0, 32]},
	"legL": {"u": 16, "v": 48, "w": 4, "h": 12, "d": 4, "o": [0, 48]},
}

const SKIN_PRESETS := {
	"hero": {"label": "Rook", "skin": "#e0ac7e", "hair": "#3b2a1e", "eyes": "#2f5d8a", "shirt": "#2a9d8f", "shirt2": "#1f776c", "pants": "#2f3b52", "shoes": "#2b2b2b", "sleeves": "long", "belt": true, "seed": 1},
	"farmer": {"label": "Farmer", "skin": "#c98d62", "hair": "#6b4a2b", "eyes": "#3b2a1e", "hat": {"type": "straw", "color": "#e2c46b"}, "shirt": "#7aa95c", "pants": "#4a6fa5", "overalls": true, "shoes": "#5a3b22", "seed": 2, "lines": ["The carrots are coming in nicely.", "Mind the fence, friend.", "Rain would be nice."]},
	"merchant": {"label": "Merchant", "skin": "#8d5a3b", "hair": "#1e1612", "eyes": "#2b1b10", "shirt": "#7b4fa0", "shirt2": "#e0b13a", "robe": true, "beard": "#1e1612", "shoes": "#3a2a20", "seed": 3, "lines": ["Fresh goods, fair prices!", "I’ve got just the thing for you.", "Business is slow today."]},
	"guard": {"label": "Guard", "skin": "#f0c8a0", "hair": "#a0522d", "eyes": "#2e7d4f", "hat": {"type": "cap", "color": "#8a9099"}, "shirt": "#8a9099", "shirt2": "#b33a3a", "tabard": true, "pants": "#5c626b", "shoes": "#3a3d42", "sleeves": "long", "seed": 4, "lines": ["Halt! Oh, it’s you.", "All quiet on the wall.", "Keep your sword sheathed."]},
	"chef": {"label": "Chef", "skin": "#e8b892", "hair": "#2a1d14", "eyes": "#3b2a1e", "hat": {"type": "chef", "color": "#f4f4f4"}, "shirt": "#f4f4f4", "shirt2": "#d9d9d9", "pants": "#2e2e2e", "shoes": "#1e1e1e", "sleeves": "long", "seed": 5, "lines": ["Soup’s almost ready.", "Who keeps eating my bread?", "A pinch more salt…"]},
	"explorer": {"label": "Explorer", "skin": "#b97a50", "hair": "#2b1b10", "eyes": "#2b1b10", "hat": {"type": "cap", "color": "#8b6d3f"}, "shirt": "#c2a36b", "shirt2": "#6e5530", "pants": "#5b5340", "shoes": "#3b2a1a", "belt": true, "seed": 6, "lines": ["I found a cave up north!", "My map says this way.", "Have you seen the old ruins?"]},
	"sage": {"label": "Sage", "skin": "#e6bf9c", "hair": "#e8e8e8", "beard": "#e8e8e8", "eyes": "#2f5d8a", "hat": {"type": "hood", "color": "#2f4b8f"}, "shirt": "#2f4b8f", "shirt2": "#d9b44a", "robe": true, "shoes": "#1b2440", "sleeves": "long", "seed": 7, "lines": ["The stars are restless tonight.", "Patience, young one.", "Hmm, curious…"]},
	"dancer": {"label": "Dancer", "skin": "#a86b46", "hair": "#ffcc33", "hairStyle": "long", "eyes": "#2b1b10", "shirt": "#ff5d8f", "shirt2": "#ffd166", "pants": "#262a36", "shoes": "#ffffff", "seed": 8, "lines": ["Feel the beat!", "One more song!", "Come dance with me!"]},
	"bolt": {"label": "Bolt", "robot": true, "skin": "#a7b0ba", "eyes": "#38e1ff", "shirt": "#7d8893", "shirt2": "#38e1ff", "pants": "#5c6670", "shoes": "#3a424a", "seed": 9, "lines": ["Beep. Hello, human.", "Scanning area…", "Battery at 98 percent."]},
}

const MOB_SKINS := {
	"villager": {"label": "Villager", "group": "people", "skin": "#d8a27a", "hair": "#5a3b22", "eyes": "#3a2a20", "shirt": "#8a6a48", "shirt2": "#5b4a38", "pants": "#4f3f30", "shoes": "#3a2a20", "sleeves": "long", "belt": true, "seed": 21, "beh": "wander", "lines": ["Good harvest this year.", "Care to trade?", "Hmm, a visitor."]},
	"witch": {"label": "Witch", "group": "mobs", "skin": "#c9d8b0", "hair": "#2a2a2a", "hairStyle": "long", "eyes": "#7b3fb0", "shirt": "#3b2a4a", "shirt2": "#6a3a8a", "robe": true, "shoes": "#1c1820", "sleeves": "long", "witchHat": true, "seed": 22, "beh": "wander", "lines": ["A pinch of this, a drop of that…", "Fresh potions, dearie?", "Hehehe!"]},
	"zombie": {"label": "Zombie", "group": "mobs", "skin": "#7f9a6a", "hair": "#2f3a28", "hairStyle": "short", "eyes": "#1a1a1a", "shirt": "#7a6a55", "pants": "#4a4236", "shoes": "#2b2b24", "torn": true, "pose": "zombie", "seed": 23, "beh": "chase", "lines": ["Uuurgh…", "Braaains…", "Hungry…"]},
	"skeleton": {"label": "Skeleton", "group": "mobs", "skin": "#e6e2d6", "eyes": "#111111", "shirt": "#e6e2d6", "pants": "#e6e2d6", "shoes": "#cfc9b8", "hairStyle": "bald", "bones": true, "slim": true, "seed": 24, "beh": "wander", "lines": ["*rattle rattle*", "I’ve got a bone to pick.", "Chilly in here."]},
	"mummy": {"label": "Mummy", "group": "mobs", "skin": "#d9cfb0", "eyes": "#2a2a2a", "shirt": "#d9cfb0", "pants": "#d0c6a6", "shoes": "#c4b996", "hairStyle": "bald", "wrap": true, "pose": "zombie", "seed": 25, "beh": "chase", "lines": ["Mmmph!", "Mmm-mmh…"]},
	"golem": {"label": "Stone golem", "group": "mobs", "robot": true, "skin": "#9a958c", "eyes": "#f0a040", "shirt": "#8a857c", "shirt2": "#5f8a4a", "pants": "#7d786f", "shoes": "#5d5850", "scale": 1.4, "seed": 26, "beh": "idle", "lines": ["…", "I guard this place."]},
	"pirate": {"label": "Pirate", "group": "people", "skin": "#c98d62", "hair": "#2a1d14", "beard": "#2a1d14", "eyes": "#2b1b10", "hat": {"type": "cap", "color": "#b33a3a"}, "shirt": "#f0ece0", "shirt2": "#b33a3a", "pants": "#3a3a52", "shoes": "#2b2018", "belt": true, "patch": true, "seed": 27, "beh": "wander", "lines": ["Arr!", "Where’s me treasure?", "Avast!"]},
	"ghost": {"label": "Ghost", "group": "mobs", "skin": "#eef2f6", "eyes": "#1a1a22", "shirt": "#eef2f6", "pants": "#eef2f6", "shoes": "#dfe5ec", "hairStyle": "bald", "robe": true, "shirt2": "#dfe5ec", "seed": 28, "beh": "wander", "lines": ["Boooo…", "Have you seen my chains?"]},
	"bogwalker": {"label": "Bog walker", "group": "mobs", "skin": "#5f8f7a", "hair": "#2c4a3a", "hairStyle": "long", "eyes": "#d6f06a", "shirt": "#3e5f55", "pants": "#2f4a42", "shoes": "#22352f", "torn": true, "pose": "zombie", "seed": 29, "beh": "chase", "lines": ["Glrrb…", "*drip drip*"]},
	"frostgolem": {"label": "Frost golem", "group": "mobs", "robot": true, "skin": "#cfe8f5", "eyes": "#38b6ff", "shirt": "#a9d4ec", "shirt2": "#ffffff", "pants": "#8fc0dc", "shoes": "#6fa3c4", "scale": 1.35, "seed": 30, "beh": "idle", "lines": ["…brrr.", "Winter is patient."]},
	"necromancer": {"label": "Necromancer", "group": "mobs", "skin": "#bfc4b8", "hair": "#1a1a1a", "eyes": "#9cff6a", "hat": {"type": "hood", "color": "#22182e"}, "shirt": "#22182e", "shirt2": "#6af07a", "robe": true, "shoes": "#141018", "sleeves": "long", "seed": 31, "beh": "wander", "lines": ["Rise…", "The old bones remember.", "Hehehe…"]},
	"bandit": {"label": "Bandit", "group": "mobs", "skin": "#c98d62", "hair": "#1e1612", "beard": "#1e1612", "eyes": "#2b1b10", "hat": {"type": "hood", "color": "#4a3a2a"}, "shirt": "#5a4a3a", "shirt2": "#2e2a26", "pants": "#3a3430", "shoes": "#221c18", "belt": true, "patch": true, "sleeves": "long", "seed": 32, "beh": "chase", "lines": ["Your gold or your life!", "Nobody move!", "Easy pickings."]},
}

const ANIMALS := {
	"pig": {"label": "Pig", "group": "animals", "beh": "wander", "creature": true, "lines": ["Oink.", "Oink oink!"]},
	"cow": {"label": "Cow", "group": "animals", "beh": "wander", "creature": true, "lines": ["Moo.", "Mooo…"]},
	"sheep": {"label": "Sheep", "group": "animals", "beh": "wander", "creature": true, "lines": ["Baa.", "Baaa!"]},
	"chicken": {"label": "Chicken", "group": "animals", "beh": "wander", "creature": true, "lines": ["Bawk!", "Cluck cluck."]},
	"dog": {"label": "Dog", "group": "animals", "beh": "follow", "creature": true, "lines": ["Woof!", "Arf arf!"]},
	"cat": {"label": "Cat", "group": "animals", "beh": "wander", "creature": true, "lines": ["Meow.", "Purrr…"]},
	"horse": {"label": "Horse", "group": "animals", "beh": "wander", "creature": true, "lines": ["Neigh!", "Hrrr."]},
	"bear": {"label": "Bear", "group": "animals", "beh": "wander", "creature": true, "lines": ["Grrr.", "Rrrawr!"]},
	"spider": {"label": "Spider", "group": "mobs", "beh": "chase", "creature": true, "lines": ["*skitter*", "Hssss…"]},
	"slime": {"label": "Slime", "group": "mobs", "beh": "wander", "creature": true, "lines": ["*blorp*", "*squish*"]},
}

static var _cr_mats := {}


# ------------------------------------------------------------------ painting

static func ov(s: Dictionary) -> Dictionary:
	var o := s.duplicate()
	o["u"] = s["o"][0]
	o["v"] = s["o"][1]
	return o


## Overlay spec for a limb, or null for legacy 64x32 skins that have no overlay layer.
static func _ov_opt(s: Dictionary, legacy: bool) -> Variant:
	if legacy:
		return null
	return ov(s)


static func faces(s: Dictionary) -> Dictionary:
	var u: int = s["u"]
	var v: int = s["v"]
	var w: int = s["w"]
	var h: int = s["h"]
	var d: int = s["d"]
	return {"top": [u + d, v, w, d], "bottom": [u + d + w, v, w, d], "right": [u, v + d, d, h], "front": [u + d, v + d, w, h], "left": [u + d + w, v + d, d, h], "back": [u + 2 * d + w, v + d, w, h]}


static func _r(img: Image, x: int, y: int, w: int, h: int, c: Variant) -> void:
	Painter.rect(img, x, y, w, h, c if c is Color else U.col(str(c)))


static func _sh(hex: String, f: float) -> Color:
	return U.shade(U.col(hex), f)


static func paint_box(img: Image, s: Dictionary, c: Variant) -> void:
	var F := faces(s)
	for k in F:
		var r: Array = F[k]
		_r(img, r[0], r[1], r[2], r[3], c)


static func paint_rows(img: Image, s: Dictionary, y0: int, y1: int, c: Variant) -> void:
	var F := faces(s)
	for k in ["right", "front", "left", "back"]:
		var r: Array = F[k]
		_r(img, r[0], r[1] + y0, r[2], y1 - y0, c)
	if y0 == 0:
		var t: Array = F["top"]
		_r(img, t[0], t[1], t[2], t[3], c)
	if y1 == int(s["h"]):
		var b: Array = F["bottom"]
		_r(img, b[0], b[1], b[2], b[3], c)


## Paints an original 64x64 skin from a preset/random config (JS paintSkin).
static func paint_skin(cfg: Dictionary) -> Image:
	var img := Painter.new_img(64, 64)
	var S := PARTS
	var sk: String = cfg.get("skin", "#e0ac7e")
	var H := faces(S["head"])
	var fx: int = H["front"][0]
	var fy: int = H["front"][1]
	var eyes: String = cfg.get("eyes", "#2f3b52") if cfg.get("eyes") else "#2f3b52"
	paint_box(img, S["head"], sk)
	if cfg.get("robot", false):
		_r(img, fx + 1, fy + 3, 6, 2, "#1d2730")
		_r(img, fx + 2, fy + 3, 1, 1, eyes)
		_r(img, fx + 5, fy + 3, 1, 1, eyes)
		for i in 4:
			_r(img, fx + 2 + i, fy + 6, 1, 1, "#2b333c" if i % 2 else "#59636e")
		_r(img, H["top"][0] + 3, H["top"][1] + 3, 2, 2, eyes)
	else:
		var hair: String = str(cfg.get("hair", "")) if cfg.get("hair") else ""
		var long_hair: bool = cfg.get("hairStyle", "") == "long"
		if hair != "" and cfg.get("hairStyle", "") != "bald":
			var T: Array = H["top"]
			_r(img, T[0], T[1], T[2], T[3], hair)
			_r(img, H["back"][0], H["back"][1], 8, 8 if long_hair else 5, hair)
			var rx: int = H["right"][0]
			var ry: int = H["right"][1]
			var lx: int = H["left"][0]
			var ly: int = H["left"][1]
			_r(img, rx, ry, 8, 3, hair)
			_r(img, lx, ly, 8, 3, hair)
			_r(img, rx, ry + 3, 3, 5 if long_hair else 2, hair)
			_r(img, lx + 5, ly + 3, 3, 5 if long_hair else 2, hair)
			_r(img, fx, fy, 8, 2, hair)
			_r(img, fx, fy + 2, 1, 4 if long_hair else 1, hair)
			_r(img, fx + 7, fy + 2, 1, 4 if long_hair else 1, hair)
			_r(img, fx + 1, fy + 3, 2, 1, _sh(hair, 0.8))
			_r(img, fx + 5, fy + 3, 2, 1, _sh(hair, 0.8))
		_r(img, fx + 1, fy + 4, 2, 1, "#f4f4f4")
		_r(img, fx + 2, fy + 4, 1, 1, eyes)
		_r(img, fx + 5, fy + 4, 2, 1, "#f4f4f4")
		_r(img, fx + 5, fy + 4, 1, 1, eyes)
		_r(img, fx + 3, fy + 5, 2, 1, _sh(sk, 0.9))
		_r(img, fx + 3, fy + 6, 2, 1, _sh(sk, 0.62))
		if cfg.get("beard"):
			var beard: String = cfg["beard"]
			_r(img, fx, fy + 5, 8, 3, beard)
			_r(img, fx + 3, fy + 6, 2, 1, _sh(beard, 0.65))
			_r(img, fx + 3, fy + 5, 2, 1, _sh(sk, 0.9))
			_r(img, H["right"][0] + 4, H["right"][1] + 5, 4, 3, beard)
			_r(img, H["left"][0], H["left"][1] + 5, 4, 3, beard)
	var shirt: String = cfg.get("shirt", "#3b5bc8")
	var shirt2: String = str(cfg.get("shirt2", shirt)) if cfg.get("shirt2") else shirt
	var pants_c: String = str(cfg.get("pants", "#2f3b52")) if cfg.get("pants") else "#2f3b52"
	var shoes: String = str(cfg.get("shoes", "#2b2b2b")) if cfg.get("shoes") else "#2b2b2b"
	paint_box(img, S["body"], shirt)
	var B := faces(S["body"])
	if cfg.get("overalls", false):
		paint_rows(img, S["body"], 7, 12, pants_c)
		for f in [B["front"], B["back"]]:
			_r(img, f[0] + 1, f[1], 1, 7, pants_c)
			_r(img, f[0] + 6, f[1], 1, 7, pants_c)
	if cfg.get("belt", false):
		paint_rows(img, S["body"], 9, 10, shirt2)
	if cfg.get("tabard", false):
		for f in [B["front"], B["back"]]:
			_r(img, f[0] + 2, f[1] + 1, 4, 11, shirt2)
	if cfg.get("robe", false):
		_r(img, B["front"][0] + 3, B["front"][1], 2, 12, shirt2)
		paint_rows(img, S["body"], 7, 8, shirt2)
	if cfg.get("robot", false):
		_r(img, B["front"][0] + 2, B["front"][1] + 3, 4, 3, "#1d2730")
		_r(img, B["front"][0] + 3, B["front"][1] + 4, 2, 1, shirt2)
	var sl := 12 if cfg.get("robot", false) else (10 if cfg.get("sleeves", "") == "long" else 4)
	for s in [S["armR"], S["armL"]]:
		paint_box(img, s, shirt)
		if sl < 12:
			paint_rows(img, s, sl, 12, sk)
		if cfg.get("robot", false):
			paint_rows(img, s, 5, 6, "#4a525b")
	var pants := shirt if cfg.get("robe", false) else pants_c
	for s in [S["legR"], S["legL"]]:
		paint_box(img, s, pants)
		paint_rows(img, s, 10, 12, shoes)
		if cfg.get("robe", false):
			paint_rows(img, s, 8, 9, shirt2)
	var hat = cfg.get("hat")
	if hat is Dictionary:
		var hs := ov(S["head"])
		var F := faces(hs)
		var hc := U.col(str(hat.get("color", "#8a9099")))
		var t: Array = F["top"]
		_r(img, t[0], t[1], t[2], t[3], hc)
		var typ: String = hat.get("type", "cap")
		if typ == "straw":
			for k in ["right", "front", "left", "back"]:
				_r(img, F[k][0], F[k][1], F[k][2], 3, hc)
				_r(img, F[k][0], F[k][1] + 2, F[k][2], 1, U.shade(hc, 0.72))
		elif typ == "cap":
			for k in ["right", "front", "left", "back"]:
				_r(img, F[k][0], F[k][1], F[k][2], 2, hc)
			_r(img, F["front"][0], F["front"][1] + 2, 8, 1, U.shade(hc, 0.75))
		elif typ == "chef":
			for k in ["right", "front", "left", "back"]:
				_r(img, F[k][0], F[k][1], F[k][2], 4, hc)
		elif typ == "hood":
			for k in ["right", "left", "back"]:
				_r(img, F[k][0], F[k][1], F[k][2], 8, hc)
			_r(img, F["front"][0], F["front"][1], 8, 2, hc)
			_r(img, F["front"][0], F["front"][1] + 2, 1, 6, hc)
			_r(img, F["front"][0] + 7, F["front"][1] + 2, 1, 6, hc)
	paint_mob_extras(img, cfg)
	var r := U.rng(int(cfg.get("seed", 7)) if cfg.get("seed") else 7)
	for y in 64:
		for x in 64:
			var c := img.get_pixel(x, y)
			if c.a8 == 0:
				continue
			var n := 1.0 + (r.next() - 0.5) * 0.12
			img.set_pixel(x, y, Color8(clampi(roundi(c.r8 * n), 0, 255), clampi(roundi(c.g8 * n), 0, 255), clampi(roundi(c.b8 * n), 0, 255), c.a8))
	return img


static func paint_mob_extras(img: Image, cfg: Dictionary) -> void:
	var S := PARTS
	if cfg.get("torn", false):
		var r := U.rng(int(cfg.get("seed", 3)))
		var shirt: String = cfg.get("shirt", "#7a6a55")
		for key in ["body", "armR", "armL", "legR", "legL"]:
			var F := faces(S[key])
			for i in 6:
				var k: String = ["front", "back", "left", "right"][i % 4]
				var f: Array = F[k]
				var xx: int = f[0] + int(r.next() * f[2])
				var yy: int = f[1] + int(r.next() * f[3])
				var ww := 1 + (1 if r.next() < 0.5 else 0)
				var hh := 1 + (1 if r.next() < 0.5 else 0)
				_r(img, xx, yy, ww, hh, cfg.get("skin", "#7f9a6a") if i % 3 else U.shade_hex(shirt, 0.7))
	if cfg.get("bones", false):
		var H := faces(S["head"])
		var fx: int = H["front"][0]
		var fy: int = H["front"][1]
		var dark := "#3a3630"
		_r(img, fx + 1, fy + 3, 2, 2, "#111111")
		_r(img, fx + 5, fy + 3, 2, 2, "#111111")
		_r(img, fx + 3, fy + 5, 2, 1, dark)
		_r(img, fx + 1, fy + 6, 6, 1, dark)
		for x in range(1, 7, 2):
			_r(img, fx + x, fy + 7, 1, 1, dark)
		var B := faces(S["body"])
		for f in [B["front"], B["back"]]:
			_r(img, f[0] + 3, f[1], 2, 12, "#cfc9b8")
			for k in range(1, 8, 2):
				_r(img, f[0], f[1] + k, 8, 1, dark)
			_r(img, f[0], f[1] + 9, 8, 3, dark)
			_r(img, f[0] + 3, f[1] + 9, 2, 3, "#cfc9b8")
		for key in ["armR", "armL", "legR", "legL"]:
			paint_rows(img, S[key], 5, 6, "#b8b2a0")
	if cfg.get("wrap", false):
		for key in S:
			var F := faces(S[key])
			for k in ["front", "back", "left", "right"]:
				var f: Array = F[k]
				for yy in range(1, int(f[3]), 3):
					_r(img, f[0], f[1] + yy, f[2], 1, "#b8ac88")
		var hf: Array = faces(S["head"])["front"]
		_r(img, hf[0] + 1, hf[1] + 3, 6, 2, "#2a2420")
		_r(img, hf[0] + 2, hf[1] + 3, 1, 1, "#e8d84a")
		_r(img, hf[0] + 5, hf[1] + 3, 1, 1, "#e8d84a")
	if cfg.get("patch", false):
		var pf: Array = faces(S["head"])["front"]
		_r(img, pf[0] + 1, pf[1] + 3, 3, 3, "#141414")
		_r(img, pf[0], pf[1] + 2, 8, 1, "#141414")


static func random_skin_cfg() -> Dictionary:
	var shirts := ["#c8413b", "#3b5bc8", "#3f9e4d", "#e6c13b", "#7b4fa0", "#e07aa8", "#2a9d8f", "#d9822b", "#5c6670", "#f4f4f4"]
	return {
		"skin": U.pick(["#f1c9a5", "#e0ac7e", "#c98d62", "#a86b46", "#8d5a3b", "#5e3a26"]),
		"hair": U.pick(["#1e1612", "#3b2a1e", "#6b4a2b", "#a0522d", "#d9b26a", "#e8e8e8", "#7a3b2a"]),
		"hairStyle": U.pick(["short", "short", "long", "bald"]),
		"eyes": U.pick(["#2f5d8a", "#3b2a1e", "#2e7d4f", "#555555"]),
		"shirt": U.pick(shirts), "shirt2": U.pick(shirts),
		"pants": U.pick(["#2f3b52", "#4a6fa5", "#5b5340", "#2e2e2e", "#6e4b2c"]),
		"shoes": U.pick(["#2b2b2b", "#5a3b22", "#3a3d42"]),
		"sleeves": U.pick(["short", "long"]),
		"belt": randf() < 0.4, "overalls": randf() < 0.2,
		"hat": U.maybe({"type": U.pick(["straw", "cap", "hood"]), "color": U.pick(shirts)}, 0.3),
		"beard": U.maybe("#3b2a1e", 0.15),
		"seed": randi() % 1000000,
	}


## Empty string if `img` is a usable skin, otherwise a user-facing reason.
static func validate_skin(img: Image) -> String:
	if img == null:
		return "That image couldn’t be read."
	var w := img.get_width()
	var h := img.get_height()
	if not (w >= 64 and (h == w or h * 2 == w)):
		return "Skins need to be 64×64 (or 64×32). This one is %d×%d." % [w, h]
	return ""


# ------------------------------------------------------------------ model

static func _skin_box(s: Dictionary, tex_h: float, mirror: bool, infl: float) -> Mesh:
	var u: float = s["u"]
	var v: float = s["v"]
	var w: float = s["w"]
	var h: float = s["h"]
	var d: float = s["d"]
	var R := [[u + d + w, v + d, d, h], [u, v + d, d, h], [u + d, v, w, d], [u + d + w, v, w, d], [u + d, v + d, w, h], [u + 2 * d + w, v + d, w, h]]
	if mirror:
		var t: Array = R[0]
		R[0] = R[1]
		R[1] = t
	var uv := []
	for r in R:
		uv.append([r[0] / 64.0, r[1] / tex_h, (r[0] + r[2]) / 64.0, (r[1] + r[3]) / tex_h])
	return CharMesh.skin_box_mesh((w + infl) * PX, (h + infl) * PX, (d + infl) * PX, uv, mirror)


static func _skin_mats(img: Image) -> Array:
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 1.0
	var omat := mat.duplicate() as StandardMaterial3D
	omat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	omat.alpha_scissor_threshold = 0.5
	omat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return [mat, omat]


## Pixel-skin humanoid (JS buildModel). `legacy` = 64x32 skins, `slim` = 3px arms.
static func build_model(img: Image, legacy: bool, slim: bool) -> Dictionary:
	var tex_h := 32.0 if legacy else 64.0
	var mats := _skin_mats(img)
	var mat: Material = mats[0]
	var omat: Material = mats[1]
	var root := Kit.group()
	var model := Kit.group()
	root.add_child(model)
	var aw := 3 if slim else 4
	var S := PARTS
	var limb := func(spec: Dictionary, o_spec: Variant, x: float, y: float, my: float, mirror: bool, parent: Node3D) -> Node3D:
		var pv := Kit.group(x * PX, y * PX, 0)
		pv.add_child(Kit.mi(_skin_box(spec, tex_h, mirror, 0.0), mat, 0, my * PX, 0))
		if o_spec is Dictionary:
			var o := Kit.mi(_skin_box(o_spec, tex_h, mirror, 0.5), omat, 0, my * PX, 0)
			pv.add_child(o)
		parent.add_child(pv)
		return pv
	var leg_r: Node3D = limb.call(S["legR"], _ov_opt(S["legR"], legacy), -2.0, 12.0, -6.0, false, model)
	var leg_l: Node3D = limb.call(S["legR"], null, 2.0, 12.0, -6.0, true, model) if legacy else limb.call(S["legL"], ov(S["legL"]), 2.0, 12.0, -6.0, false, model)
	var upper := Kit.group(0, 12 * PX, 0)
	model.add_child(upper)
	upper.add_child(Kit.mi(_skin_box(S["body"], tex_h, false, 0.0), mat, 0, 6 * PX, 0))
	if not legacy:
		upper.add_child(Kit.mi(_skin_box(ov(S["body"]), tex_h, false, 0.5), omat, 0, 6 * PX, 0))
	var head := Kit.group(0, 12 * PX, 0)
	upper.add_child(head)
	head.add_child(Kit.mi(_skin_box(S["head"], tex_h, false, 0.0), mat, 0, 4 * PX, 0))
	head.add_child(Kit.mi(_skin_box(ov(S["head"]), tex_h, false, 1.0), omat, 0, 4 * PX, 0))
	var a_r: Dictionary = (S["armR"] as Dictionary).duplicate()
	a_r["w"] = aw
	var a_l: Dictionary = (S["armL"] as Dictionary).duplicate()
	a_l["w"] = aw
	var ax := 4.0 + aw / 2.0
	var arm_r: Node3D = limb.call(a_r, _ov_opt(a_r, legacy), -ax, 10.0, -4.0, false, upper)
	var arm_l: Node3D = limb.call(a_r, null, ax, 10.0, -4.0, true, upper) if legacy else limb.call(a_l, ov(a_l), ax, 10.0, -4.0, false, upper)
	return {"root": root, "model": model, "upper": upper, "head": head, "hc": null, "armL": arm_l, "armR": arm_r, "legL": leg_l, "legR": leg_r,
		"height": 1.8, "headH": 1.58, "sitDrop": 0.58, "kind": "human", "skin": img}


static func add_witch_hat(m: Dictionary) -> void:
	var g := Kit.group()
	var hat := "#241c2c"
	var band := "#6a3a8a"
	var P := PX
	for b in [[14, 1, 14, hat, 0, 0, 0], [9, 1.2, 9, band, 0, 1, 0], [9, 3, 9, hat, 0, 3, 0], [6, 3, 6, hat, 0.5, 6, -0.5], [4, 3, 4, hat, 1, 9, -1], [2, 2.5, 2, hat, 1.6, 11.5, -1.8]]:
		g.add_child(cb(b[0] * P, b[1] * P, b[2] * P, b[3], b[4] * P, b[5] * P, b[6] * P))
	g.position.y = 8.6 * P
	g.rotation.z = -0.08
	(m["head"] as Node3D).add_child(g)
	m["height"] = float(m["height"]) + 0.45


# ------------------------------------------------------------------ creatures

## Speckled 8x8 pixel material (JS crMat). opt: v, patch, stripe, glow, op.
static func cr_mat(col: String, opt: Dictionary = {}) -> Material:
	var key := "%s|%s|%s|%s|%s|%s" % [col, opt.get("glow", false), opt.get("op", ""), opt.get("patch", ""), opt.get("stripe", ""), opt.get("v", "")]
	if _cr_mats.has(key):
		return _cr_mats[key]
	var sd := 0
	for ch in key:
		sd = (sd * 31 + ch.unicode_at(0)) & 0xFFFFFFFF
	var img := Painter.new_img(8, 8)
	Painter.speckle(img, col, opt.get("v", 0.08), sd, 0, 0, 8, 8)
	if opt.has("patch"):
		var r := U.rng(sd + 1)
		for i in 3:
			_r(img, int(r.next() * 6), int(r.next() * 6), 2 + int(r.next() * 3), 2 + int(r.next() * 2), opt["patch"])
	if opt.has("stripe"):
		for y in range(1, 8, 3):
			_r(img, 0, y, 8, 1, opt["stripe"])
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 1.0
	if opt.get("glow", false):
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.emission_enabled = true
		m.emission_texture = m.albedo_texture
		m.emission_energy_multiplier = 1.6
	else:
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if opt.has("op"):
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 1, 1, float(opt["op"]))
	_cr_mats[key] = m
	return m


## Creature box (JS `cb`).
static func cb(w: float, h: float, d: float, col: String, x := 0.0, y := 0.0, z := 0.0, opt: Dictionary = {}) -> MeshInstance3D:
	var m := Kit.mi(CharMesh.uv_box(w, h, d), cr_mat(col, opt), x, y, z)
	if opt.get("glow", false) or opt.has("op"):
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if opt.get("glow", false) else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return m


static func eyes_on(g: Node3D, z: float, y: float, sep: float, s := 0.07, col := "#16141a", white := true) -> void:
	for sx in [-1.0, 1.0]:
		if white:
			g.add_child(cb(s * 1.6, s * 1.2, 0.02, "#f4f2ee", sx * sep, y, z, {"v": 0.0}))
		var glow := col != "#16141a"
		g.add_child(cb(s * 0.8, s * 1.2, 0.025, col, sx * sep + (sx * s * 0.35 if white else 0.0), y, z + 0.005, {"v": 0.0, "glow": glow}))
		# small catch-light so eyes read as glossy
		g.add_child(cb(s * 0.3, s * 0.3, 0.012, "#ffffff", sx * sep + (sx * s * 0.35 if white else 0.0) - s * 0.15, y + s * 0.3, z + 0.016, {"v": 0.0, "glow": true}))


static func quad_rig(o: Dictionary) -> Dictionary:
	var root := Kit.group()
	var model := Kit.group()
	root.add_child(model)
	var leg_h: float = o["legH"]
	var bw: float = o["bw"]
	var bh: float = o["bh"]
	var bd: float = o["bd"]
	var upper := Kit.group(0, leg_h, 0)
	model.add_child(upper)
	upper.add_child(cb(bw, bh, bd, o["body"], 0, bh / 2.0, 0, o.get("bodyOpt", {})))
	var head := Kit.group(0, bh * 0.7 + o.get("neckY", 0.0), bd / 2.0 + o.get("neckZ", 0.0))
	upper.add_child(head)
	var hd: float = o["hd"]
	var hh: float = o["hh"]
	var hz := hd * 0.38
	head.add_child(cb(o["hw"], hh, hd, o.get("headC", o["body"]), 0, hh * 0.15, hz, o.get("headOpt", o.get("bodyOpt", {}))))
	var front := hz + hd / 2.0 + 0.011
	var hy := hh * 0.15
	var lw: float = o["lw"]
	var leg := func(x: float, z: float) -> Node3D:
		var pv := Kit.group(x, leg_h, z)
		pv.add_child(cb(lw, leg_h, lw, o.get("legC", o["body"]), 0, -leg_h / 2.0, 0))
		model.add_child(pv)
		return pv
	var lx := bw / 2.0 - lw / 2.0
	var fz := bd / 2.0 - lw / 2.0 - 0.02
	var arm_r: Node3D = leg.call(-lx, fz)
	var arm_l: Node3D = leg.call(lx, fz)
	var leg_r: Node3D = leg.call(-lx, -fz)
	var leg_l: Node3D = leg.call(lx, -fz)
	var head_h: float = leg_h + bh * 0.7 + o.get("neckY", 0.0) + hy
	return {"root": root, "model": model, "upper": upper, "head": head, "hc": null, "armL": arm_l, "armR": arm_r, "legL": leg_l, "legR": leg_r, "kind": "quad",
		"headH": head_h, "height": head_h + hh * 0.7, "sitDrop": 0.08, "front": front, "hy": hy}


static func _nub(model: Node3D) -> Node3D:
	var g := Kit.group()
	model.add_child(g)
	return g


static func build_creature(key: String) -> Dictionary:
	var r: Dictionary
	match key:
		"pig":
			r = quad_rig({"bw": 0.62, "bh": 0.52, "bd": 0.92, "legH": 0.3, "lw": 0.2, "hw": 0.5, "hh": 0.48, "hd": 0.44, "body": "#ef9fae"})
			r["head"].add_child(cb(0.26, 0.17, 0.06, "#de7d90", 0, r["hy"] - 0.08, r["front"] + 0.02))
			eyes_on(r["head"], r["front"], r["hy"] + 0.08, 0.13)
		"cow":
			r = quad_rig({"bw": 0.72, "bh": 0.7, "bd": 1.15, "legH": 0.56, "lw": 0.24, "hw": 0.52, "hh": 0.48, "hd": 0.4, "body": "#f2efe8", "bodyOpt": {"patch": "#2a2522"}, "headOpt": {"patch": "#2a2522"}, "legC": "#3a3430"})
			r["head"].add_child(cb(0.36, 0.2, 0.06, "#e8b0a8", 0, r["hy"] - 0.1, r["front"] + 0.02))
			for s in [-1.0, 1.0]:
				r["head"].add_child(cb(0.08, 0.14, 0.08, "#e8dcc0", s * 0.22, r["hy"] + 0.3, r["front"] - 0.2))
			eyes_on(r["head"], r["front"], r["hy"] + 0.08, 0.15)
		"sheep":
			r = quad_rig({"bw": 0.78, "bh": 0.72, "bd": 1.0, "legH": 0.44, "lw": 0.17, "hw": 0.36, "hh": 0.38, "hd": 0.36, "body": "#f3f1ea", "bodyOpt": {"v": 0.14}, "headC": "#cfc2ad", "legC": "#cfc2ad"})
			r["head"].add_child(cb(0.4, 0.16, 0.3, "#f3f1ea", 0, r["hy"] + 0.2, r["front"] - 0.2, {"v": 0.14}))
			eyes_on(r["head"], r["front"], r["hy"] + 0.04, 0.1, 0.06)
		"dog":
			r = quad_rig({"bw": 0.38, "bh": 0.38, "bd": 0.74, "legH": 0.38, "lw": 0.13, "hw": 0.36, "hh": 0.34, "hd": 0.36, "body": "#c9a46b", "legC": "#b8925a"})
			r["head"].add_child(cb(0.18, 0.14, 0.16, "#d8b87e", 0, r["hy"] - 0.06, r["front"] + 0.08))
			r["head"].add_child(cb(0.08, 0.06, 0.03, "#2a2020", 0, r["hy"] - 0.01, r["front"] + 0.17))
			for s in [-1.0, 1.0]:
				r["head"].add_child(cb(0.08, 0.14, 0.06, "#8a6a40", s * 0.15, r["hy"] + 0.2, r["front"] - 0.2))
			eyes_on(r["head"], r["front"], r["hy"] + 0.07, 0.09, 0.05)
			var t := cb(0.08, 0.08, 0.34, "#b8925a", 0, 0.3, -0.48)
			t.rotation.x = 0.7
			r["upper"].add_child(t)
		"cat":
			r = quad_rig({"bw": 0.28, "bh": 0.28, "bd": 0.6, "legH": 0.26, "lw": 0.09, "hw": 0.3, "hh": 0.26, "hd": 0.28, "body": "#e89a48", "bodyOpt": {"stripe": "#b86a28"}, "headOpt": {"stripe": "#b86a28"}})
			for s in [-1.0, 1.0]:
				r["head"].add_child(cb(0.07, 0.1, 0.05, "#e89a48", s * 0.1, r["hy"] + 0.17, r["front"] - 0.12))
			r["head"].add_child(cb(0.05, 0.04, 0.02, "#e07f90", 0, r["hy"] - 0.04, r["front"] + 0.01))
			eyes_on(r["head"], r["front"], r["hy"] + 0.04, 0.07, 0.045, "#3a9a3a")
			var t := cb(0.06, 0.06, 0.5, "#e89a48", 0, 0.32, -0.5, {"stripe": "#b86a28"})
			t.rotation.x = 1.0
			r["upper"].add_child(t)
		"horse":
			r = quad_rig({"bw": 0.62, "bh": 0.68, "bd": 1.35, "legH": 0.85, "lw": 0.2, "hw": 0.3, "hh": 0.36, "hd": 0.62, "body": "#8a5a34", "neckY": 0.38, "neckZ": -0.04, "legC": "#7a4c2c"})
			r["upper"].add_child(cb(0.3, 0.55, 0.3, "#8a5a34", 0, 0.82, 0.6))
			r["upper"].add_child(cb(0.08, 0.6, 0.34, "#3a2418", 0, 1.0, 0.5))
			eyes_on(r["head"], r["front"] - 0.25, r["hy"] + 0.08, 0.16, 0.05, "#16141a", false)
			r["head"].add_child(cb(0.06, 0.12, 0.06, "#3a2418", -0.1, r["hy"] + 0.24, r["front"] - 0.52))
			r["head"].add_child(cb(0.06, 0.12, 0.06, "#3a2418", 0.1, r["hy"] + 0.24, r["front"] - 0.52))
			var t := cb(0.12, 0.55, 0.12, "#3a2418", 0, 0.3, -0.72)
			t.rotation.x = 0.35
			r["upper"].add_child(t)
			r["height"] = float(r["height"]) + 0.2
		"bear":
			r = quad_rig({"bw": 0.86, "bh": 0.8, "bd": 1.3, "legH": 0.46, "lw": 0.3, "hw": 0.56, "hh": 0.5, "hd": 0.48, "body": "#6a4628", "bodyOpt": {"v": 0.12}})
			r["head"].add_child(cb(0.28, 0.2, 0.14, "#a88a68", 0, r["hy"] - 0.08, r["front"] + 0.06))
			r["head"].add_child(cb(0.1, 0.07, 0.03, "#1c1614", 0, r["hy"] - 0.02, r["front"] + 0.135))
			for s in [-1.0, 1.0]:
				r["head"].add_child(cb(0.12, 0.12, 0.08, "#5a3a20", s * 0.22, r["hy"] + 0.3, r["front"] - 0.3))
			eyes_on(r["head"], r["front"], r["hy"] + 0.1, 0.14, 0.05, "#16141a", false)
		"chicken":
			var root := Kit.group()
			var model := Kit.group()
			root.add_child(model)
			var upper := Kit.group(0, 0.3, 0)
			model.add_child(upper)
			upper.add_child(cb(0.36, 0.36, 0.46, "#f6f4ee", 0, 0.18, 0))
			var head := Kit.group(0, 0.3, 0.16)
			upper.add_child(head)
			head.add_child(cb(0.24, 0.3, 0.2, "#f6f4ee", 0, 0.15, 0.02))
			head.add_child(cb(0.12, 0.07, 0.1, "#e8a33a", 0, 0.14, 0.16))
			head.add_child(cb(0.07, 0.1, 0.04, "#d8302c", 0, 0.06, 0.13))
			head.add_child(cb(0.1, 0.06, 0.1, "#d8302c", 0, 0.33, 0.02))
			eyes_on(head, 0.121, 0.2, 0.07, 0.04, "#16141a", false)
			var wing := func(s: float) -> Node3D:
				var pv := Kit.group(s * 0.2, 0.32, 0)
				pv.add_child(cb(0.05, 0.24, 0.34, "#ecebe4", 0, -0.12, 0))
				upper.add_child(pv)
				return pv
			var leg := func(s: float) -> Node3D:
				var pv := Kit.group(s * 0.08, 0.3, 0)
				pv.add_child(cb(0.05, 0.3, 0.05, "#e8a33a", 0, -0.15, 0))
				pv.add_child(cb(0.12, 0.02, 0.14, "#e8a33a", 0, -0.29, 0.03))
				model.add_child(pv)
				return pv
			r = {"root": root, "model": model, "upper": upper, "head": head, "hc": null, "armR": wing.call(-1.0), "armL": wing.call(1.0), "legR": leg.call(-1.0), "legL": leg.call(1.0), "kind": "quad", "headH": 0.75, "height": 0.9, "sitDrop": 0.1}
		"spider":
			var root := Kit.group()
			var model := Kit.group()
			root.add_child(model)
			var upper := Kit.group(0, 0.32, 0)
			model.add_child(upper)
			upper.add_child(cb(0.72, 0.52, 0.72, "#2a2426", 0, 0.2, -0.42, {"v": 0.14}))
			upper.add_child(cb(0.46, 0.38, 0.44, "#3a3234", 0, 0.12, 0.1))
			var head := Kit.group(0, 0.14, 0.32)
			upper.add_child(head)
			head.add_child(cb(0.38, 0.32, 0.26, "#3a3234", 0, 0, 0.1))
			for p in [[-0.1, 0.06], [0.1, 0.06], [-0.05, -0.05], [0.05, -0.05]]:
				head.add_child(cb(0.06, 0.05, 0.02, "#ff3a3a", p[0], p[1], 0.235, {"v": 0.0, "glow": true}))
			var pair := func(s: float, z: float) -> Node3D:
				var pv := Kit.group(s * 0.2, 0.32, z)
				for k in 2:
					var g := Kit.group()
					g.rotation = Vector3(0, (0.35 if k else -0.35) * s, s * -0.55)
					g.add_child(cb(0.65, 0.06, 0.06, "#2a2426", s * 0.33, 0, 0))
					g.position.z = 0.12 if k else -0.12
					pv.add_child(g)
				model.add_child(pv)
				return pv
			r = {"root": root, "model": model, "upper": upper, "head": head, "hc": null, "armR": pair.call(-1.0, 0.18), "armL": pair.call(1.0, 0.18), "legR": pair.call(-1.0, -0.18), "legL": pair.call(1.0, -0.18), "kind": "quad", "headH": 0.5, "height": 0.85, "sitDrop": 0.1}
		_:
			# slime
			var root := Kit.group()
			var model := Kit.group()
			root.add_child(model)
			var upper := Kit.group()
			model.add_child(upper)
			upper.add_child(cb(0.44, 0.44, 0.44, "#3f9a3a", 0, 0.32, 0, {"v": 0.1}))
			var shell := cb(0.82, 0.82, 0.82, "#7ad86f", 0, 0.41, 0, {"op": 0.68, "v": 0.1})
			upper.add_child(shell)
			var head := Kit.group(0, 0.41, 0)
			upper.add_child(head)
			head.add_child(cb(0.12, 0.12, 0.02, "#16141a", -0.16, 0.1, 0.415, {"v": 0.0}))
			head.add_child(cb(0.12, 0.12, 0.02, "#16141a", 0.16, 0.1, 0.415, {"v": 0.0}))
			head.add_child(cb(0.12, 0.05, 0.02, "#16141a", 0, -0.12, 0.415, {"v": 0.0}))
			r = {"root": root, "model": model, "upper": upper, "head": head, "hc": null, "armR": _nub(model), "armL": _nub(model), "legR": _nub(model), "legL": _nub(model), "kind": "quad", "hop": true, "headH": 0.5, "height": 0.9, "sitDrop": 0.05}
	r["creature"] = key
	return r
