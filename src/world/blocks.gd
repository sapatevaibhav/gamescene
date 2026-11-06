class_name Blocks
## Block library: every builtin block, its procedurally painted 16px tiles in a
## shared atlas, isometric icons and user-made custom blocks.
##
## Ported from the web build. Tile painters reproduce the canvas code pixel for
## pixel (same seeds, same random-call order) so worlds look identical and
## saved projects keep their block ids.

const TILE := 16
const ATLAS_N := 32
const CATS := [["nature", "Nature"], ["stone", "Stone"], ["wood", "Wood"], ["ores", "Ores & metal"], ["colors", "Colors"], ["glass", "Glass & light"], ["decor", "Decor"], ["mine", "Yours"]]
const MAX_BLOCKS := 255

static var BLOCKS: Array = [null]
static var ID: Dictionary = {}
static var BUILTIN_COUNT := 0
static var BUILTIN_TILES := 0

static var _inited := false
static var _img: Image
static var _tex: ImageTexture
static var _next_tile := 0
static var _seed := 300
static var _icons: Dictionary = {}

const _COBBLE_RECTS := [[0, 0, 6, 5], [6, 0, 5, 4], [11, 0, 5, 6], [0, 5, 4, 6], [4, 4, 7, 6], [11, 6, 5, 5], [0, 11, 7, 5], [7, 10, 5, 6], [12, 11, 4, 5]]


# ================================================================ public API

static func init() -> void:
	if _inited:
		return
	_inited = true
	_img = Image.create_empty(TILE * ATLAS_N, TILE * ATLAS_N, false, Image.FORMAT_RGBA8)
	_tex = ImageTexture.create_from_image(_img)
	BLOCKS = [null]
	ID = {}
	_next_tile = 0
	_builtins()
	_more_blocks()
	BUILTIN_COUNT = BLOCKS.size()
	BUILTIN_TILES = _next_tile
	_tex.update(_img)


## The shared tile atlas (512x512, 16px tiles). Sample it with nearest filtering.
static func atlas() -> ImageTexture:
	init()
	return _tex


static func atlas_image() -> Image:
	init()
	return _img


static func get_block(id: int) -> Dictionary:
	if id <= 0 or id >= BLOCKS.size() or BLOCKS[id] == null:
		return {}
	return BLOCKS[id]


static func exists(id: int) -> bool:
	var b := get_block(id)
	return not b.is_empty() and not b.get("deleted", false)


## Block ids in a category (see CATS), skipping deleted ones.
static func by_cat(cat: String) -> Array[int]:
	init()
	var out: Array[int] = []
	for i in range(1, BLOCKS.size()):
		var b = BLOCKS[i]
		if b != null and not b.get("deleted", false) and b.get("cat", "") == cat:
			out.append(i)
	return out


## Average colour of a block's top tile (used for lights and UI swatches).
static func avg_color(id: int, face := "top") -> Color:
	var b := get_block(id)
	if b.is_empty() or b.get("deleted", false):
		return Color.WHITE
	var t: int = b[face]
	var x0 := (t % ATLAS_N) * TILE
	var y0 := (t / ATLAS_N) * TILE
	var acc := Color(0, 0, 0, 0)
	for y in TILE:
		for x in TILE:
			acc += _img.get_pixel(x0 + x, y0 + y)
	return acc / float(TILE * TILE)


## 36x36 isometric icon of a block, cached.
static func icon(id: int) -> Texture2D:
	init()
	if _icons.has(id):
		return _icons[id]
	var b := get_block(id)
	if b.is_empty() or b.get("deleted", false):
		return null
	var top := _tile_image(b["top"])
	var side := _tile_image(b["side"])
	var img := Image.create_empty(36, 36, false, Image.FORMAT_RGBA8)
	_iso_face(img, top, 1, 0.5, -1, 0.5, 18, 2, 0.0)
	_iso_face(img, side, 1, 0.5, 0, 1, 2, 10, 0.18)
	_iso_face(img, side, 1, -0.5, 0, 1, 18, 18, 0.32)
	var tex := ImageTexture.create_from_image(img)
	_icons[id] = tex
	return tex


## Adds a user-made block from its saved source (web format):
## {name, kind, mode: "image", side: dataURL, top?: dataURL}
## or {name, kind, pattern, top: "#hex", side: "#hex"}.
## Returns the new id, or -1 if it can't be built or the limit is reached.
static func add_custom(src: Dictionary) -> int:
	init()
	if _next_tile + 2 > ATLAS_N * ATLAS_N or BLOCKS.size() >= MAX_BLOCKS:
		push_warning("Block limit reached for this project.")
		return -1
	var top: Image
	var side: Image
	if src.get("mode", "") == "image":
		side = _image_tile(str(src.get("side", "")))
		if side == null:
			return -1
		top = side
		if str(src.get("top", "")) != "":
			top = _image_tile(str(src["top"]))
			if top == null:
				return -1
	else:
		var pat: String = str(src.get("pattern", "speckled"))
		var tcol: String = str(src.get("top", "#888888"))
		var scol: String = str(src.get("side", tcol))
		top = pattern_tile(pat, tcol, 91)
		side = top if tcol == scol else pattern_tile(pat, scol, 92)
	var b := _def({"name": src.get("name", "Custom"), "topC": top, "sideC": side, "kind": src.get("kind", "solid")})
	b["src"] = src
	b["custom"] = true
	b["cat"] = "mine"
	_tex.update(_img)
	return b["id"]


## Appends a placeholder for a custom block that couldn't be restored, so the
## ids of later blocks stay stable.
static func push_deleted() -> int:
	var id := BLOCKS.size()
	BLOCKS.append({"id": id, "deleted": true, "name": "Deleted", "kind": "solid", "see": false, "cat": "mine", "top": 0, "side": 0, "bottom": 0, "tiles": {"top": 0, "side": 0, "bottom": 0}})
	return id


## Marks a custom block deleted (keeps its id slot).
static func delete_custom(id: int) -> void:
	var b := get_block(id)
	if b.is_empty() or not b.get("custom", false):
		return
	b["deleted"] = true
	_icons.erase(id)


## Drops every custom block (call before loading another project).
static func reset_custom() -> void:
	init()
	for i in range(BUILTIN_COUNT, BLOCKS.size()):
		_icons.erase(i)
	BLOCKS.resize(BUILTIN_COUNT)
	_next_tile = BUILTIN_TILES


static func custom_sources() -> Array:
	var out := []
	for i in range(BUILTIN_COUNT, BLOCKS.size()):
		var b = BLOCKS[i]
		out.append({"deleted": true} if b == null or b.get("deleted", false) else b.get("src", {}))
	return out


## Pattern tile used by custom blocks ("speckled", "bricks", "planks",
## "stripes", "tiles", anything else = smooth).
static func pattern_tile(pattern: String, col: String, seed := 77) -> Image:
	var c := _new()
	match pattern:
		"speckled":
			_speckle(c, col, 0.16, seed)
		"bricks":
			_rect(c, 0, 0, 16, 16, _shade_t(col, 1.35))
			for row in 4:
				var off := 4 if row % 2 else 0
				for bx in range(-1, 3):
					var x := bx * 8 + off
					var x0 := maxi(0, x)
					_speckle(c, col, 0.07, seed + row * 4 + bx, x0, row * 4, mini(16 - x0, x + 7 - x0), 3)
		"planks":
			_speckle(c, col, 0.06, seed)
			for y in [3, 7, 11, 15]:
				_rect(c, 0, y, 16, 1, _shade_t(col, 0.7))
		"stripes":
			for y in 16:
				_rect(c, 0, y, 16, 1, _parse(col) if (y >> 2) % 2 else _shade_t(col, 0.78))
		"tiles":
			_speckle(c, col, 0.04, seed)
			var s := _shade_t(col, 0.7)
			_stroke(c, 0, 0, 7, 7, s)
			_stroke(c, 8, 8, 7, 7, s)
			_stroke(c, 8, 0, 7, 7, s)
			_stroke(c, 0, 8, 7, 7, s)
		_:
			_speckle(c, col, 0.03, seed)
	return c


# ================================================================ registry

static func _def(o: Dictionary) -> Dictionary:
	var b := {"kind": "solid", "deleted": false}
	b.merge(o, true)
	b["see"] = b["kind"] == "glass" or b["kind"] == "water"
	var top: Image = o["topC"]
	var side: Image = o.get("sideC") if o.get("sideC") != null else top
	var bottom: Image = o.get("bottomC") if o.get("bottomC") != null else side
	b["top"] = _add_tile(top)
	b["side"] = b["top"] if side == top else _add_tile(side)
	if bottom == side:
		b["bottom"] = b["side"]
	elif bottom == top:
		b["bottom"] = b["top"]
	else:
		b["bottom"] = _add_tile(bottom)
	b["tiles"] = {"top": b["top"], "side": b["side"], "bottom": b["bottom"]}
	b.erase("topC")
	b.erase("sideC")
	b.erase("bottomC")
	b["id"] = BLOCKS.size()
	BLOCKS.append(b)
	if o.has("key"):
		ID[o["key"]] = b["id"]
	return b


static func _add_tile(cv: Image) -> int:
	if _next_tile >= ATLAS_N * ATLAS_N:
		return 0
	var i := _next_tile
	_next_tile += 1
	var x := (i % ATLAS_N) * TILE
	var y := (i / ATLAS_N) * TILE
	_img.fill_rect(Rect2i(x, y, TILE, TILE), Color(0, 0, 0, 0))
	_img.blit_rect(cv, Rect2i(0, 0, TILE, TILE), Vector2i(x, y))
	return i


static func _tile_image(t: int) -> Image:
	return _img.get_region(Rect2i((t % ATLAS_N) * TILE, (t / ATLAS_N) * TILE, TILE, TILE))


static func _image_tile(src: String) -> Image:
	if src == "":
		return null
	var img := U.image_from_data_url(src)
	if img == null:
		return null
	img.convert(Image.FORMAT_RGBA8)
	img.resize(TILE, TILE, Image.INTERPOLATE_NEAREST)
	return img


static func _iso_face(img: Image, src: Image, a: float, b: float, c: float, d: float, e: float, f: float, sh: float) -> void:
	var det := a * d - b * c
	for py in img.get_height():
		for px in img.get_width():
			var X := px + 0.5 - e
			var Y := py + 0.5 - f
			var sx := (d * X - c * Y) / det
			var sy := (-b * X + a * Y) / det
			if sx < 0.0 or sy < 0.0 or sx >= 16.0 or sy >= 16.0:
				continue
			var s := src.get_pixel(int(sx), int(sy))
			if s.a <= 0.0:
				continue
			if sh > 0.0:
				s = Color(s.r * (1.0 - sh), s.g * (1.0 - sh), s.b * (1.0 - sh), s.a)
			img.set_pixel(px, py, img.get_pixel(px, py).blend(s))


# ================================================================ painting

static func _new() -> Image:
	return Image.create_empty(TILE, TILE, false, Image.FORMAT_RGBA8)


static func _nx() -> int:
	_seed += 1
	return _seed - 1


static func _rgb(hex: String) -> PackedInt32Array:
	var h := hex.replace("#", "")
	if h.length() == 3:
		h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2]
	var n := h.hex_to_int() if h.is_valid_hex_number() else 0
	return PackedInt32Array([(n >> 16) & 255, (n >> 8) & 255, n & 255])


static func _parse(col: Variant) -> Color:
	if col is Color:
		return col
	var s := str(col)
	if s.begins_with("#"):
		var p := _rgb(s)
		return Color8(p[0], p[1], p[2])
	return U.col(s)


## JS `shade()`: channels truncated (rgbStr), returns a Color.
static func _shade_t(hex: String, f: float) -> Color:
	var p := _rgb(hex)
	return Color8(clampi(int(p[0] * f), 0, 255), clampi(int(p[1] * f), 0, 255), clampi(int(p[2] * f), 0, 255))


## JS `shadeHex()`: channels rounded, returns "#rrggbb".
static func _sh(hex: String, f: float) -> String:
	var p := _rgb(hex)
	return "#%02x%02x%02x" % [clampi(roundi(p[0] * f), 0, 255), clampi(roundi(p[1] * f), 0, 255), clampi(roundi(p[2] * f), 0, 255)]


static func _rect(c: Image, x: int, y: int, w: int, h: int, col: Variant) -> void:
	var cc := _parse(col)
	for yy in range(maxi(0, y), mini(16, y + h)):
		for xx in range(maxi(0, x), mini(16, x + w)):
			if cc.a >= 1.0:
				c.set_pixel(xx, yy, cc)
			else:
				c.set_pixel(xx, yy, c.get_pixel(xx, yy).blend(cc))


## Canvas strokeRect(x + .5, y + .5, w, h) with a 1px line.
static func _stroke(c: Image, x: int, y: int, w: int, h: int, col: Variant) -> void:
	var cc := _parse(col)
	var pts := {}
	for xx in range(x, x + w + 1):
		pts[Vector2i(xx, y)] = true
		pts[Vector2i(xx, y + h)] = true
	for yy in range(y + 1, y + h):
		pts[Vector2i(x, yy)] = true
		pts[Vector2i(x + w, yy)] = true
	for p: Vector2i in pts:
		if p.x >= 0 and p.y >= 0 and p.x < 16 and p.y < 16:
			c.set_pixel(p.x, p.y, c.get_pixel(p.x, p.y).blend(cc))


static func _disc(c: Image, cx: float, cy: float, r: float, col: Variant) -> void:
	var cc := _parse(col)
	for y in 16:
		for x in 16:
			if pow(x + 0.5 - cx, 2) + pow(y + 0.5 - cy, 2) <= r * r:
				c.set_pixel(x, y, c.get_pixel(x, y).blend(cc))


static func _draw(c: Image, src: Image) -> void:
	c.blend_rect(src, Rect2i(0, 0, 16, 16), Vector2i.ZERO)


static func _speckle(c: Image, hex: String, vari: float, seed: int, x0 := 0, y0 := 0, w := 16, h := 16) -> void:
	var r := U.rng(seed)
	var p := _rgb(hex)
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			var n := 1.0 + (r.next() - 0.5) * 2.0 * vari
			if x < 0 or y < 0 or x >= 16 or y >= 16:
				continue
			c.set_pixel(x, y, Color8(clampi(int(p[0] * n), 0, 255), clampi(int(p[1] * n), 0, 255), clampi(int(p[2] * n), 0, 255)))


static func _ri(r: U.Rng, m: int) -> int:
	return int(r.next() * m)


# ---------------------------------------------------------------- fixed painters (P)

static func _p(name: String, arg := "") -> Image:
	var c := _new()
	match name:
		"grassTop":
			_speckle(c, "#67a843", 0.13, 1)
		"grassSide":
			_speckle(c, "#8a5a3b", 0.12, 2)
			var r := U.rng(3)
			for x in 16:
				var d := 3 + (1 if r.next() < 0.5 else 0)
				d += 1 if r.next() < 0.25 else 0
				_speckle(c, "#67a843", 0.12, 10 + x, x, 0, 1, d)
		"dirt":
			_speckle(c, "#8a5a3b", 0.14, 4)
		"path":
			_speckle(c, "#a8834f", 0.1, 40)
			var r := U.rng(41)
			for i in 8:
				var x := _ri(r, 15)
				var y := _ri(r, 15)
				_rect(c, x, y, 1, 1, "#8c6a3c")
		"stone":
			_speckle(c, "#8d9096", 0.08, 5)
			var r := U.rng(6)
			for i in 10:
				var x := _ri(r, 14)
				var y := _ri(r, 15)
				var w := 2 + _ri(r, 3)
				_rect(c, x, y, w, 1, "rgba(60,62,68,.35)")
		"cobble":
			_rect(c, 0, 0, 16, 16, "#55585e")
			var cols := ["#9a9da3", "#878a90", "#a7aab0"]
			for i in _COBBLE_RECTS.size():
				var q: Array = _COBBLE_RECTS[i]
				_speckle(c, cols[i % 3], 0.08, 20 + i, q[0], q[1], q[2] - 1, q[3] - 1)
		"sand":
			_speckle(c, "#e2cf92", 0.07, 7)
		"sandstone":
			_speckle(c, "#d9c287", 0.05, 8)
			for y in [3, 9, 13]:
				_speckle(c, "#c4ab70", 0.05, 9 + y, 0, y, 16, 1)
		"planks":
			_speckle(c, "#b07f47", 0.06, 11)
			for y in [3, 7, 11, 15]:
				_rect(c, 0, y, 16, 1, "#7d5530")
			for q in [[6, 0], [12, 4], [3, 8], [10, 12]]:
				_rect(c, q[0], q[1], 1, 3, "#7d5530")
		"logSide":
			_speckle(c, "#6e4b2c", 0.1, 12)
			var r := U.rng(13)
			for i in 5:
				var x := _ri(r, 16)
				var y := _ri(r, 8)
				var h := 5 + _ri(r, 8)
				_rect(c, x, y, 1, h, "#55381f")
		"logTop":
			_speckle(c, "#b58a55", 0.05, 14)
			_stroke(c, 2, 2, 11, 11, "#8a6338")
			_stroke(c, 5, 5, 5, 5, "#8a6338")
			_stroke(c, 0, 0, 15, 15, "#6e4b2c")
		"leaves":
			_speckle(c, "#3e8a37", 0.25, 15)
			var r := U.rng(16)
			for i in 18:
				var x := _ri(r, 16)
				var y := _ri(r, 16)
				_rect(c, x, y, 1, 1, "#25601f")
		"brick":
			_rect(c, 0, 0, 16, 16, "#c9bcae")
			for row in 4:
				var off := 4 if row % 2 else 0
				for bx in range(-1, 3):
					var x := bx * 8 + off
					var x0 := maxi(0, x)
					_speckle(c, "#a64b37", 0.08, 30 + row * 4 + bx, x0, row * 4, mini(mini(7, 16 - x0), x + 7 - x0), 3)
		"glass":
			_rect(c, 0, 0, 16, 16, "rgba(210,235,255,0.14)")
			_stroke(c, 0, 0, 15, 15, "rgba(235,248,255,.95)")
			for q in [[3, 3], [4, 4], [5, 5], [10, 3], [11, 4]]:
				_rect(c, q[0], q[1], 1, 1, "rgba(255,255,255,.8)")
		"water":
			_rect(c, 0, 0, 16, 16, "rgba(46,108,196,.78)")
			var r := U.rng(17)
			for i in 10:
				var x := _ri(r, 13)
				var y := _ri(r, 16)
				_rect(c, x, y, 3, 1, "rgba(130,180,240,.7)")
		"snow":
			_speckle(c, "#f2f6fa", 0.03, 18)
		"snowSide":
			_speckle(c, "#8a5a3b", 0.12, 19)
			var r := U.rng(20)
			for x in 16:
				_speckle(c, "#f2f6fa", 0.03, 50 + x, x, 0, 1, 3 + (1 if r.next() < 0.5 else 0))
		"ice":
			_rect(c, 0, 0, 16, 16, "rgba(170,215,255,.55)")
			for q in [[2, 12, 6], [7, 4, 7], [4, 8, 3]]:
				_rect(c, q[0], q[1], q[2], 1, "rgba(240,250,255,.8)")
		"lamp":
			_rect(c, 0, 0, 16, 16, "#7a5a2e")
			_speckle(c, "#ffd57a", 0.06, 21, 1, 1, 14, 14)
			for v in [5, 10]:
				_rect(c, v, 1, 1, 14, "#e0a84a")
				_rect(c, 1, v, 14, 1, "#e0a84a")
		"cactusSide":
			_speckle(c, "#4f8f3a", 0.08, 22)
			for x in [3, 8, 12]:
				_rect(c, x, 0, 1, 16, "#3c7029")
			var r := U.rng(23)
			for i in 6:
				var x := _ri(r, 16)
				var y := _ri(r, 16)
				_rect(c, x, y, 1, 1, "#d8e8b0")
		"cactusTop":
			_speckle(c, "#5fa046", 0.06, 24)
			_stroke(c, 3, 3, 9, 9, "#3c7029")
		"gold":
			_speckle(c, "#e3b43c", 0.06, 25)
			_rect(c, 1, 1, 14, 1, "#fbe08a")
			_rect(c, 1, 1, 1, 14, "#fbe08a")
			_rect(c, 1, 14, 14, 1, "#b8871f")
			_rect(c, 14, 1, 1, 14, "#b8871f")
		"basalt":
			_speckle(c, "#2e2f38", 0.12, 26)
			var r := U.rng(27)
			for i in 6:
				var x := _ri(r, 16)
				var y := _ri(r, 16)
				_rect(c, x, y, 2, 1, "#4b4466")
		"cloth":
			_speckle(c, arg, 0.06, 28)
			for y in range(0, 16, 4):
				_rect(c, 0, y, 16, 1, _shade_t(arg, 0.92))
	return c


static func _builtins() -> void:
	var dirt := _p("dirt")
	_def({"key": "grass", "name": "Grass", "topC": _p("grassTop"), "sideC": _p("grassSide"), "bottomC": dirt})
	_def({"key": "dirt", "name": "Dirt", "topC": dirt})
	_def({"key": "path", "name": "Path", "topC": _p("path"), "sideC": dirt})
	_def({"key": "stone", "name": "Stone", "topC": _p("stone")})
	_def({"key": "cobble", "name": "Cobble", "topC": _p("cobble")})
	_def({"key": "sand", "name": "Sand", "topC": _p("sand")})
	_def({"key": "sandstone", "name": "Sandstone", "topC": _p("sandstone")})
	_def({"key": "planks", "name": "Oak planks", "topC": _p("planks")})
	_def({"key": "log", "name": "Oak log", "topC": _p("logTop"), "sideC": _p("logSide")})
	_def({"key": "leaves", "name": "Oak leaves", "topC": _p("leaves")})
	_def({"key": "brick", "name": "Brick", "topC": _p("brick")})
	_def({"key": "glass", "name": "Glass", "topC": _p("glass"), "kind": "glass"})
	_def({"key": "water", "name": "Water", "topC": _p("water"), "kind": "water"})
	_def({"key": "snow", "name": "Snow", "topC": _p("snow"), "sideC": _p("snowSide"), "bottomC": dirt})
	_def({"key": "ice", "name": "Ice", "topC": _p("ice"), "kind": "glass"})
	_def({"key": "lamp", "name": "Lamp", "topC": _p("lamp"), "kind": "glow"})
	_def({"key": "cactus", "name": "Cactus", "topC": _p("cactusTop"), "sideC": _p("cactusSide")})
	_def({"key": "gold", "name": "Gold", "topC": _p("gold")})
	_def({"key": "basalt", "name": "Basalt", "topC": _p("basalt")})
	for q in [["red", "Red cloth", "#c8413b"], ["blue", "Blue cloth", "#3b5bc8"], ["yellow", "Yellow cloth", "#e6c13b"], ["green", "Green cloth", "#3f9e4d"], ["pink", "Pink cloth", "#e07aa8"], ["white", "White cloth", "#e9ecef"], ["black", "Black cloth", "#2a2d33"]]:
		_def({"key": q[0], "name": q[1], "topC": _p("cloth", q[2])})


# ---------------------------------------------------------------- texture helpers (moreBlocks)

static func _S(col: String, v := 0.08) -> Image:
	var c := _new()
	_speckle(c, col, v, _nx())
	return c


static func _stoneT(base: String, dark: String, n := 12) -> Image:
	var c := _new()
	_speckle(c, base, 0.07, _nx())
	var r := U.rng(_nx())
	for i in n:
		var x := _ri(r, 15)
		var y := _ri(r, 15)
		var w := 1 + _ri(r, 2)
		_rect(c, x, y, w, 1, dark)
	return c


static func _bricksT(col: String, mortar: String, h := 4) -> Image:
	var c := _new()
	_rect(c, 0, 0, 16, 16, mortar)
	var s0 := _nx()
	for row in 16 / h:
		var off := 4 if row % 2 else 0
		for bx in range(-1, 3):
			var x := bx * 8 + off
			var x0 := maxi(0, x)
			var w := mini(16 - x0, x + 7 - x0)
			if w > 0:
				_speckle(c, col, 0.07, s0 + row * 4 + bx, x0, row * h, w, h - 1)
	return c


static func _tilesT(col: String, k := 8) -> Image:
	var c := _new()
	_speckle(c, col, 0.05, _nx())
	var s := _sh(col, 0.7)
	for i in range(0, 16, k):
		_rect(c, i, 0, 1, 16, s)
		_rect(c, 0, i, 16, 1, s)
	return c


static func _planksT(col: String) -> Image:
	var c := _new()
	_speckle(c, col, 0.06, _nx())
	var dk := _sh(col, 0.68)
	for y in [3, 7, 11, 15]:
		_rect(c, 0, y, 16, 1, dk)
	for q in [[6, 0], [12, 4], [3, 8], [10, 12]]:
		_rect(c, q[0], q[1], 1, 3, dk)
	return c


static func _barkT(col: String, mark: String) -> Image:
	var c := _new()
	_speckle(c, col, 0.1, _nx())
	var r := U.rng(_nx())
	for i in 7:
		var x := _ri(r, 16)
		var y := _ri(r, 12)
		var w := 1 + (1 if r.next() < 0.3 else 0)
		var h := 3 + _ri(r, 8)
		_rect(c, x, y, w, h, mark)
	return c


static func _ringT(inner: String, bark: String) -> Image:
	var c := _new()
	_speckle(c, inner, 0.05, _nx())
	var s := _sh(inner, 0.75)
	_stroke(c, 2, 2, 11, 11, s)
	_stroke(c, 5, 5, 5, 5, s)
	_stroke(c, 0, 0, 15, 15, bark)
	return c


static func _leavesT(col: String, dots := "") -> Image:
	var c := _new()
	_speckle(c, col, 0.25, _nx())
	var r := U.rng(_nx())
	var dk := _sh(col, 0.6)
	for i in 18:
		var x := _ri(r, 16)
		var y := _ri(r, 16)
		_rect(c, x, y, 1, 1, dk)
	if dots != "":
		for i in 9:
			var x := _ri(r, 15)
			var y := _ri(r, 15)
			_rect(c, x, y, 2, 2, dots)
	return c


static func _oreT(stone: String, ore: String) -> Image:
	var c := _new()
	_speckle(c, stone, 0.07, _nx())
	var r := U.rng(_nx())
	for k in 5:
		var x := 1 + _ri(r, 12)
		var y := 1 + _ri(r, 12)
		_rect(c, x, y, 2, 2, ore)
		_rect(c, x, y, 1, 1, _sh(ore, 1.35))
		if r.next() < 0.5:
			_rect(c, x + 2, y + 1, 1, 1, _sh(ore, 0.8))
	return c


static func _metalT(col: String) -> Image:
	var c := _new()
	_speckle(c, col, 0.04, _nx())
	_rect(c, 0, 0, 16, 1, _sh(col, 1.25))
	_rect(c, 0, 0, 1, 16, _sh(col, 1.25))
	_rect(c, 0, 15, 16, 1, _sh(col, 0.7))
	_rect(c, 15, 0, 1, 16, _sh(col, 0.7))
	_stroke(c, 3, 3, 9, 9, _sh(col, 0.88))
	return c


static func _gemT(col: String) -> Image:
	var c := _new()
	_speckle(c, col, 0.07, _nx())
	for k in 4:
		_rect(c, 2 + k * 3, 2 + k * 3, 3, 1, _sh(col, 1.45))
	_rect(c, 0, 15, 16, 1, _sh(col, 0.65))
	_rect(c, 15, 0, 1, 16, _sh(col, 0.65))
	_rect(c, 0, 0, 16, 1, _sh(col, 1.2))
	return c


static func _glassT(col: String, op := 0.42) -> Image:
	var c := _new()
	var p := _rgb(col)
	_rect(c, 0, 0, 16, 16, Color8(p[0], p[1], p[2], int(roundf(op * 255.0))))
	_stroke(c, 0, 0, 15, 15, Color8(p[0], p[1], p[2], int(roundf(0.95 * 255.0))))
	for q in [[3, 3], [4, 4], [5, 5]]:
		_rect(c, q[0], q[1], 1, 1, "rgba(255,255,255,.75)")
	return c


static func _glowT(col: String, line: String) -> Image:
	var c := _new()
	_speckle(c, col, 0.1, _nx())
	var r := U.rng(_nx())
	for i in 7:
		var x := _ri(r, 13)
		var y := _ri(r, 13)
		_rect(c, x, y, 3, 1, line)
		_rect(c, x + 1, y - 1, 1, 3, line)
	return c


static func _crackT(dark: String, hot: String) -> Image:
	var c := _new()
	_speckle(c, dark, 0.1, _nx())
	var r := U.rng(_nx())
	for i in 5:
		var x := _ri(r, 16)
		var y := _ri(r, 16)
		for k in 6:
			_rect(c, x, y, 1, 1, hot)
			x = (x + (1 if r.next() < 0.5 else -1) + 16) % 16
			y = (y + 1) % 16
	return c


static func _D(key: String, name: String, cat: String, top: Image, side: Image = null, bottom: Image = null, kind := "solid") -> void:
	var s := side if side != null else top
	var b := bottom if bottom != null else s
	_def({"key": key, "name": name, "cat": cat, "topC": top, "sideC": s, "bottomC": b, "kind": kind})


## Small random scatter helper: n rects of size (w, h) at r()*m positions.
static func _dots(c: Image, r: U.Rng, n: int, m: int, w: int, h: int, col: String) -> void:
	for i in n:
		var x := _ri(r, m)
		var y := _ri(r, m)
		_rect(c, x, y, w, h, col)


static func _moss_dots(c: Image, r: U.Rng, n: int) -> void:
	for i in n:
		var x := _ri(r, 16)
		var y := _ri(r, 16)
		var w := 1 + (1 if r.next() < 0.4 else 0)
		_rect(c, x, y, w, 1, "#5e8a3e" if r.next() < 0.5 else "#4a7a32")


static func _more_blocks() -> void:
	const OLD := {"grass": "nature", "dirt": "nature", "path": "nature", "stone": "stone", "cobble": "stone", "sand": "nature", "sandstone": "stone", "planks": "wood", "log": "wood", "leaves": "wood", "brick": "stone", "glass": "glass", "water": "nature", "snow": "nature", "ice": "nature", "lamp": "glass", "cactus": "nature", "gold": "ores", "basalt": "stone", "red": "colors", "blue": "colors", "yellow": "colors", "green": "colors", "pink": "colors", "white": "colors", "black": "colors"}
	for b in BLOCKS:
		if b != null and b.has("key"):
			b["cat"] = OLD.get(b["key"], "decor")
	_seed = 300
	var dirt := _p("dirt")
	var c: Image
	var c2: Image
	var r: U.Rng
	# ---- nature
	c = _new()
	_speckle(c, "#7a5236", 0.16, _nx())
	r = U.rng(_nx())
	_dots(c, r, 14, 16, 1, 1, "#5a5048")
	_D("coarse", "Coarse dirt", "nature", c)
	c = _new()
	_speckle(c, "#7d5424", 0.2, _nx())
	r = U.rng(_nx())
	for i in 16:
		var x := _ri(r, 15)
		var y := _ri(r, 16)
		_rect(c, x, y, 2, 1, "#a06a2a")
	c2 = _new()
	_speckle(c2, "#8a5a3b", 0.12, _nx())
	_speckle(c2, "#7d5424", 0.18, _nx(), 0, 0, 16, 3)
	_D("forestfloor", "Forest floor", "nature", c, c2, dirt)
	_D("mud", "Mud", "nature", _S("#3e3530", 0.1))
	_D("moss", "Moss", "nature", _S("#5a8a3a", 0.2))
	c = _new()
	_speckle(c, "#8c8580", 0.1, _nx())
	r = U.rng(_nx())
	var gcols := ["#6b6560", "#a8a29c", "#7d7570"]
	for i in 26:
		var x := _ri(r, 15)
		var y := _ri(r, 15)
		var h := 1 + (1 if r.next() < 0.5 else 0)
		_rect(c, x, y, 2, h, gcols[i % 3])
	_D("gravel", "Gravel", "nature", c)
	_D("clay", "Clay", "nature", _S("#a3aab8", 0.04))
	_D("redsand", "Red sand", "nature", _S("#c4692e", 0.07))
	c = _new()
	_speckle(c, "#8fb8e8", 0.05, _nx())
	for q in [[2, 3, 7], [8, 9, 6], [4, 13, 5]]:
		_rect(c, q[0], q[1], q[2], 1, "#c6dcf6")
	_D("packedice", "Packed ice", "nature", c)
	_D("lava", "Lava", "nature", _glowT("#f0801e", "#ffd040"), null, null, "glow")
	_D("magma", "Magma", "nature", _crackT("#4a2418", "#ff8a2a"), null, null, "glow")
	c = _p("snow")
	c2 = _new()
	_speckle(c2, "#8a5a3b", 0.12, _nx())
	_speckle(c2, "#f2f6fa", 0.03, _nx(), 0, 0, 16, 3)
	_D("snowgrass", "Snowy grass", "nature", c, c2, dirt)
	for q in [["coralred", "Red coral", "#d8443f"], ["coralpink", "Pink coral", "#e77fb3"], ["coralyellow", "Yellow coral", "#e8c33a"], ["coralblue", "Blue coral", "#3a6fd8"], ["coralpurple", "Purple coral", "#9a4ad0"]]:
		c = _new()
		_speckle(c, q[2], 0.12, _nx())
		r = U.rng(_nx())
		_dots(c, r, 14, 15, 1, 1, _sh(q[2], 1.35))
		_dots(c, r, 8, 15, 1, 1, _sh(q[2], 0.6))
		_D(q[0], q[1], "nature", c)
	# ---- stone
	c = _new()
	_speckle(c, "#a0a3a8", 0.03, _nx())
	_rect(c, 0, 0, 16, 1, "#b8bbc0")
	_rect(c, 0, 15, 16, 1, "#7d8085")
	_D("smoothstone", "Smooth stone", "stone", c)
	_D("stonebricks", "Stone bricks", "stone", _bricksT("#8f9297", "#6a6d72", 8))
	c = _new()
	_draw(c, _bricksT("#8f9297", "#6a6d72", 8))
	r = U.rng(_nx())
	_moss_dots(c, r, 30)
	_D("mossybricks", "Mossy stone bricks", "stone", c)
	c = _new()
	_draw(c, _bricksT("#8f9297", "#6a6d72", 8))
	r = U.rng(_nx())
	var cx := 3
	var cy := 0
	for k in 16:
		_rect(c, cx, cy, 1, 1, "#55585c")
		cx = clampi(cx + (1 if r.next() < 0.5 else 0), 0, 15)
		cy += 1
	_D("crackedbricks", "Cracked stone bricks", "stone", c)
	c = _new()
	_draw(c, _p("cobble"))
	r = U.rng(_nx())
	_moss_dots(c, r, 26)
	_D("mossycobble", "Mossy cobble", "stone", c)
	_D("granite", "Granite", "stone", _stoneT("#a86f5a", "#7d4a3a", 18))
	_D("polgranite", "Polished granite", "stone", _metalT("#a86f5a"))
	_D("diorite", "Diorite", "stone", _stoneT("#c9c7c3", "#8e8c88", 20))
	_D("andesite", "Andesite", "stone", _stoneT("#88898a", "#6a6b6c", 16))
	_D("tuff", "Tuff", "stone", _stoneT("#6c6d62", "#535448", 14))
	_D("calcite", "Calcite", "stone", _stoneT("#e3e3df", "#c4c4bf", 10))
	c = _new()
	_speckle(c, "#4c4c52", 0.07, _nx())
	for y in [4, 9, 13]:
		_rect(c, 0, y, 16, 1, "#3c3c42")
	_D("slate", "Slate", "stone", c)
	c = _new()
	_rect(c, 0, 0, 16, 16, "#2e2e33")
	var scols := ["#55555b", "#4a4a50", "#606066"]
	for i in _COBBLE_RECTS.size():
		var q: Array = _COBBLE_RECTS[i]
		_speckle(c, scols[i % 3], 0.07, _nx(), q[0], q[1], q[2] - 1, q[3] - 1)
	_D("cobbledslate", "Cobbled slate", "stone", c)
	_D("slatebricks", "Slate bricks", "stone", _bricksT("#505056", "#333338", 4))
	_D("slatetiles", "Slate tiles", "stone", _tilesT("#46464c", 4))
	c = _new()
	_speckle(c, "#b8602c", 0.05, _nx())
	for y in [3, 9, 13]:
		_rect(c, 0, y, 16, 1, "#9a4c22")
	_D("redsandstone", "Red sandstone", "stone", c)
	c = _new()
	_speckle(c, "#1d1626", 0.14, _nx())
	r = U.rng(_nx())
	_dots(c, r, 8, 15, 2, 1, "#4a3366")
	_D("obsidian", "Obsidian", "stone", c)
	_D("blackstone", "Black stone", "stone", _stoneT("#2c2a30", "#45424a", 16))
	c = _new()
	_speckle(c, "#ece8e2", 0.03, _nx())
	_rect(c, 0, 15, 16, 1, "#cfcac3")
	_rect(c, 15, 0, 1, 16, "#cfcac3")
	_D("quartz", "Quartz", "stone", c)
	_D("quartzbricks", "Quartz bricks", "stone", _bricksT("#ece8e2", "#c9c4bc", 8))
	_D("mudbricks", "Mud bricks", "stone", _bricksT("#8c6a50", "#6a4e3a", 4))
	_D("packedmud", "Packed mud", "stone", _S("#8e6a50", 0.1))
	_D("terracotta", "Terracotta", "stone", _S("#a0614a", 0.05))
	c = _new()
	_speckle(c, "#5aa596", 0.14, _nx())
	r = U.rng(_nx())
	for i in 16:
		var x := _ri(r, 15)
		var y := _ri(r, 15)
		_rect(c, x, y, 2, 1, "#3f7f74" if i % 2 else "#86c8b6")
	_D("seastone", "Sea stone", "stone", c)
	_D("seabricks", "Sea bricks", "stone", _bricksT("#5aa596", "#3f7f74", 8))
	# ---- wood
	for q in [["spruce", "Spruce", "#7a5a36", "#3f2c1c", "#2e1f14"], ["birch", "Birch", "#d8c58a", "#e6e2d6", "#2a2a2a"], ["jungle", "Jungle", "#b07a50", "#5b4a28", "#3f3418"], ["acacia", "Acacia", "#c06a3a", "#6a6158", "#4a443e"], ["darkoak", "Dark oak", "#4f3520", "#3a2a1a", "#22180e"], ["mangrove", "Mangrove", "#7a3a32", "#4a3a2e", "#2e241c"], ["cherry", "Cherry", "#e3b6ad", "#3a2228", "#24141a"], ["bamboo", "Bamboo", "#d8c060", "#7aa03a", "#55782a"]]:
		var k: String = q[0]
		_D(k + "planks", q[1] + " planks", "wood", _planksT(q[2]))
		if k == "bamboo":
			var top := _ringT("#c9d080", "#55782a")
			c = _new()
			_speckle(c, q[3], 0.06, _nx())
			for x in [0, 5, 10]:
				_rect(c, x, 0, 1, 16, q[4])
			for y in [4, 11]:
				_rect(c, 0, y, 16, 1, "#a8c860")
			_D(k + "log", "Bamboo stalks", "wood", top, c)
		else:
			var top := _ringT(q[2], q[3])
			_D(k + "log", q[1] + " log", "wood", top, _barkT(q[3], q[4]))
	_D("spruceleaves", "Spruce leaves", "wood", _leavesT("#2f5a32"))
	_D("birchleaves", "Birch leaves", "wood", _leavesT("#6fa04a"))
	_D("jungleleaves", "Jungle leaves", "wood", _leavesT("#3a8a2a"))
	_D("cherryleaves", "Cherry leaves", "wood", _leavesT("#e9a2c2", "#fbd0e2"))
	_D("flowerleaves", "Flowering leaves", "wood", _leavesT("#4f8a3a", "#e77fb3"))
	# ---- ores & metal
	var st := "#8d9096"
	var sl := "#4c4c52"
	for q in [["coal", "Coal", "#2a2a2a"], ["iron", "Iron", "#d8b89a"], ["copper", "Copper", "#d8744a"], ["gold", "Gold", "#f2cf3a"], ["diamond", "Diamond", "#5ee8e0"], ["emerald", "Emerald", "#2ecc71"], ["lapis", "Lapis", "#2a4fc8"], ["ruby", "Ruby", "#d0283a"]]:
		_D(q[0] + "ore", q[1] + " ore", "ores", _oreT(st, q[2]))
		_D(q[0] + "slateore", q[1] + " ore, deep", "ores", _oreT(sl, q[2]))
	c = _new()
	_speckle(c, "#1f1f22", 0.12, _nx())
	r = U.rng(_nx())
	_dots(c, r, 10, 15, 1, 1, "#4a4a52")
	_D("coalblock", "Coal block", "ores", c)
	_D("ironblock", "Iron block", "ores", _metalT("#d6d8da"))
	_D("copperblock", "Copper block", "ores", _metalT("#c96a42"))
	c = _new()
	_draw(c, _metalT("#a8794a"))
	r = U.rng(_nx())
	_dots(c, r, 22, 15, 2, 1, "#5a9a80")
	_D("weathered", "Weathered copper", "ores", c)
	_D("oxidized", "Oxidized copper", "ores", _metalT("#4fa088"))
	_D("diamondblock", "Diamond block", "ores", _gemT("#6fe6e0"))
	_D("emeraldblock", "Emerald block", "ores", _gemT("#2ecc71"))
	_D("lapisblock", "Lapis block", "ores", _gemT("#2a4fc8"))
	_D("rubyblock", "Ruby block", "ores", _gemT("#d0283a"))
	_D("amethyst", "Amethyst", "ores", _gemT("#9a63d6"))
	_D("netheritelike", "Dark alloy", "ores", _metalT("#3d3a3c"))
	# ---- colors
	var dyes := [["white", "White", "#e9ecef"], ["lightgray", "Light gray", "#a8acb0"], ["gray", "Gray", "#5a5e63"], ["black", "Black", "#24262b"], ["brown", "Brown", "#7a5230"], ["red", "Red", "#c8413b"], ["orange", "Orange", "#e8862a"], ["yellow", "Yellow", "#e6c13b"], ["lime", "Lime", "#86c83a"], ["green", "Green", "#3f7a2e"], ["cyan", "Cyan", "#2a9aa0"], ["lightblue", "Light blue", "#5ab4e6"], ["blue", "Blue", "#3b5bc8"], ["purple", "Purple", "#7b3fb0"], ["magenta", "Magenta", "#c24ab8"], ["pink", "Pink", "#e07aa8"]]
	for q in dyes:
		if not ID.has(q[0]):
			_D(q[0], q[1] + " cloth", "colors", _p("cloth", q[2]))
	for q in dyes:
		_D("concrete-" + q[0], q[1] + " concrete", "colors", _S(q[2], 0.025))
	for q in dyes:
		_D("terra-" + q[0], q[1] + " terracotta", "colors", _S(_sh(q[2], 0.78), 0.06))
	# ---- glass & light
	for q in dyes:
		_D("glass-" + q[0], q[1] + " glass", "glass", _glassT(q[2]), null, null, "glass")
	_D("glowcrystal", "Glow crystal", "glass", _glowT("#f2c65a", "#fff2a0"), null, null, "glow")
	c = _new()
	_speckle(c, "#bfe8e0", 0.06, _nx())
	_stroke(c, 0, 0, 15, 15, "#7fc8b8")
	_stroke(c, 4, 4, 7, 7, "#7fc8b8")
	_D("sealamp", "Sea lamp", "glass", c, null, null, "glow")
	c = _new()
	_speckle(c, "#d9822b", 0.06, _nx())
	_rect(c, 7, 0, 2, 3, "#5a7a2a")
	c2 = _new()
	_speckle(c2, "#d9822b", 0.06, _nx())
	for x in [0, 5, 10, 15]:
		_rect(c2, x, 0, 1, 16, "#b8681e")
	for q in [[3, 4, 3, 3], [10, 4, 3, 3], [3, 10, 10, 2], [5, 12, 2, 1], [9, 12, 2, 1]]:
		_rect(c2, q[0], q[1], q[2], q[3], "#ffd24a")
	_D("jack", "Jack-o’-lantern", "glass", c, c2, null, "glow")
	_D("slimeblock", "Slime block", "glass", _glassT("#6fd06a", 0.6), null, null, "glass")
	# ---- decor
	var bk_top := _planksT("#b07f47")
	c = _new()
	_speckle(c, "#b07f47", 0.06, _nx())
	_rect(c, 0, 0, 16, 1, "#7d5530")
	_rect(c, 0, 7, 16, 2, "#7d5530")
	_rect(c, 0, 15, 16, 1, "#7d5530")
	r = U.rng(_nx())
	var bcols := ["#b33a3a", "#3b5bc8", "#3f7a2e", "#e6c13b", "#7b3fb0", "#d9822b"]
	for row in [1, 9]:
		for x in range(1, 15, 2):
			var h := 6 - _ri(r, 2)
			_rect(c, x, row, 2, h, bcols[_ri(r, bcols.size())])
	_D("bookshelf", "Bookshelf", "decor", bk_top, c)
	c = _new()
	_draw(c, _planksT("#b58a55"))
	_stroke(c, 1, 1, 13, 13, "#6b4a2b")
	_rect(c, 7, 2, 1, 12, "#6b4a2b")
	_rect(c, 2, 7, 12, 1, "#6b4a2b")
	c2 = _new()
	_draw(c2, _planksT("#a07040"))
	_rect(c2, 3, 4, 2, 7, "#8c8f94")
	_rect(c2, 2, 4, 4, 2, "#8c8f94")
	_rect(c2, 10, 3, 2, 9, "#6b4a2b")
	_rect(c2, 9, 3, 4, 2, "#8c8f94")
	_D("workbench", "Workbench", "decor", c, c2, _planksT("#b07f47"))
	c = _S("#8d9096", 0.07)
	c2 = _new()
	_speckle(c2, "#7d8085", 0.07, _nx())
	_rect(c2, 3, 7, 10, 6, "#2a2a2e")
	_rect(c2, 4, 10, 8, 2, "#e8862a")
	_rect(c2, 3, 3, 10, 2, "#5a5d62")
	_D("furnace", "Furnace", "decor", c, c2)
	c = _new()
	_speckle(c, "#8b5a2b", 0.06, _nx())
	_stroke(c, 0, 0, 15, 15, "#3a3530")
	_stroke(c, 4, 4, 7, 7, "#3a3530")
	c2 = _new()
	_speckle(c2, "#8b5a2b", 0.06, _nx())
	for y in [2, 13]:
		_rect(c2, 0, y, 16, 1, "#3a3530")
	for x in [3, 8, 12]:
		_rect(c2, x, 0, 1, 16, "#6e4520")
	_D("barrelblock", "Barrel", "decor", c, c2)
	c = _new()
	_speckle(c, "#d8b440", 0.08, _nx())
	_stroke(c, 2, 2, 11, 11, "#a8862a")
	c2 = _new()
	_speckle(c2, "#d8b440", 0.1, _nx())
	for x in [1, 4, 7, 10, 13]:
		_rect(c2, x, 0, 1, 16, "#b8962e")
	for y in [4, 11]:
		_rect(c2, 0, y, 16, 1, "#8a3a2a")
	_D("hay", "Hay bale", "decor", c, c2)
	c = _new()
	_speckle(c, "#d9822b", 0.06, _nx())
	_rect(c, 7, 6, 2, 3, "#5a7a2a")
	c2 = _new()
	_speckle(c2, "#d9822b", 0.06, _nx())
	for x in [0, 5, 10, 15]:
		_rect(c2, x, 0, 1, 16, "#b8681e")
	_D("pumpkin", "Pumpkin", "decor", c, c2)
	c = _new()
	_speckle(c, "#6ab83a", 0.08, _nx())
	for x in [1, 5, 9, 13]:
		_rect(c, x, 0, 2, 16, "#3f7a2e")
	_D("melon", "Melon", "decor", c)
	c = _new()
	_speckle(c, "#d8cc4a", 0.06, _nx())
	r = U.rng(_nx())
	_dots(c, r, 14, 15, 2, 2, "#a89a2a")
	_D("sponge", "Sponge", "decor", c)
	c = _new()
	_rect(c, 0, 0, 16, 16, "#b8761e")
	for y in range(0, 16, 4):
		var x := 2 if (y / 4) % 2 else 0
		while x < 16:
			_rect(c, x, y, 3, 3, "#e8a83a")
			x += 4
	_D("honeycomb", "Honeycomb", "decor", c)
	c = _new()
	_speckle(c, "#c8302c", 0.06, _nx())
	for q in [[2, 2], [9, 3], [5, 9], [11, 11], [2, 12]]:
		_rect(c, q[0], q[1], 3, 2, "#f2ece0")
	_D("mushred", "Red mushroom block", "decor", c)
	_D("mushbrown", "Brown mushroom block", "decor", _S("#946a4a", 0.06))
	c = _new()
	_speckle(c, "#e6dccb", 0.04, _nx())
	for x in [3, 8, 12]:
		_rect(c, x, 0, 1, 16, "#cfc4b0")
	_D("mushstem", "Mushroom stem", "decor", c)
	c = _new()
	_draw(c, _planksT("#a07a46"))
	_stroke(c, 2, 2, 11, 11, "#b33a3a")
	c2 = _new()
	_draw(c2, _planksT("#a07a46"))
	for x in range(2, 14, 3):
		_rect(c2, x, 3, 2, 10, "#c8413b")
	_rect(c2, 0, 7, 16, 2, "#2a2a2a")
	_D("dynamite", "Dynamite crate", "decor", c, c2)
	c = _new()
	_rect(c, 0, 0, 16, 16, "#efe6d8")
	_disc(c, 8, 8, 7, "#c8413b")
	_disc(c, 8, 8, 5, "#efe6d8")
	_disc(c, 8, 8, 2.5, "#c8413b")
	_D("target", "Target", "decor", c)
