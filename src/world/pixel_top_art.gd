class_name PixelTopArt
## Pixel 2D top view: ground tiles (16×16) and object sprites (trees,
## houses, rocks...) painted in code, seeded so every run draws the same
## art. Objects are drawn front-on (the usual top-down RPG look) and stand on
## a footprint of tiles that blocks walking.

const PX := 16
const COLS := 8

## Ground tiles; id 0 is unused. `block` stops walking (water).
const GROUND := [
	{},
	{"name": "Grass"},
	{"name": "Meadow"},
	{"name": "Path"},
	{"name": "Sand"},
	{"name": "Water", "water": true},
	{"name": "Plaza"},
	{"name": "Wood floor"},
	{"name": "Farmland"},
	{"name": "Dark grass"},
	{"name": "Snow"},
	{"name": "Cobble"},
	{"name": "Swamp"},
	{"name": "Ice"},
	{"name": "Carpet"},
	{"name": "Wall", "block": true},
	# Used by house interiors; not in the palette.
	{"name": "Void", "block": true, "system": true},
	{"name": "Doorway", "system": true},
]
const G := {"grass": 1, "meadow": 2, "path": 3, "sand": 4, "water": 5, "plaza": 6, "wood": 7, "farm": 8, "dark": 9, "snow": 10,
	"cobble": 11, "swamp": 12, "ice": 13, "carpet": 14, "wall": 15, "void": 16, "doorway": 17}

## Objects: sprite size in px, footprint in tiles (w × d, measured from the
## anchor tile northwards), and whether the footprint blocks walking.
const OBJECTS := {
	"tree": {"name": "Tree", "w": 32, "h": 48, "fw": 1, "fd": 1, "solid": true},
	"pine": {"name": "Pine", "w": 32, "h": 48, "fw": 1, "fd": 1, "solid": true},
	"rock": {"name": "Rock", "w": 16, "h": 16, "fw": 1, "fd": 1, "solid": true},
	"bush": {"name": "Bush", "w": 16, "h": 16, "fw": 1, "fd": 1, "solid": true},
	"flowers": {"name": "Flowers", "w": 16, "h": 16, "fw": 1, "fd": 1, "solid": false},
	"fence": {"name": "Fence", "w": 16, "h": 16, "fw": 1, "fd": 1, "solid": true},
	"house": {"name": "House", "w": 64, "h": 64, "fw": 4, "fd": 2, "solid": true},
	"well": {"name": "Well", "w": 32, "h": 32, "fw": 2, "fd": 1, "solid": true},
	"lamp": {"name": "Lamp post", "w": 16, "h": 32, "fw": 1, "fd": 1, "solid": true, "glow": true},
	"crate": {"name": "Crate", "w": 16, "h": 16, "fw": 1, "fd": 1, "solid": true},
	"crops": {"name": "Crops", "w": 16, "h": 16, "fw": 1, "fd": 1, "solid": false},
	"campfire": {"name": "Campfire", "w": 16, "h": 16, "fw": 1, "fd": 1, "solid": true, "glow": true},
	"sign": {"name": "Sign", "w": 16, "h": 16, "fw": 1, "fd": 1, "solid": true},
	"stall": {"name": "Market stall", "w": 48, "h": 48, "fw": 3, "fd": 1, "solid": true},
	"statue": {"name": "Statue", "w": 16, "h": 32, "fw": 1, "fd": 1, "solid": true},
	"fountain": {"name": "Fountain", "w": 32, "h": 32, "fw": 2, "fd": 2, "solid": true},
	"tent": {"name": "Tent", "w": 32, "h": 32, "fw": 2, "fd": 1, "solid": true},
	"barrel": {"name": "Barrel", "w": 16, "h": 16, "fw": 1, "fd": 1, "solid": true},
	"cart": {"name": "Cart", "w": 32, "h": 24, "fw": 2, "fd": 1, "solid": true},
	"stump": {"name": "Stump", "w": 16, "h": 16, "fw": 1, "fd": 1, "solid": true},
	"deadtree": {"name": "Dead tree", "w": 32, "h": 48, "fw": 1, "fd": 1, "solid": true},
	"palm": {"name": "Palm", "w": 32, "h": 48, "fw": 1, "fd": 1, "solid": true},
	"cactus": {"name": "Cactus", "w": 16, "h": 32, "fw": 1, "fd": 1, "solid": true},
	"bench": {"name": "Bench", "w": 32, "h": 16, "fw": 2, "fd": 1, "solid": true},
	"haystack": {"name": "Haystack", "w": 32, "h": 24, "fw": 2, "fd": 1, "solid": true},
	"torch": {"name": "Torch", "w": 16, "h": 32, "fw": 1, "fd": 1, "solid": true, "glow": true},
	"chest": {"name": "Chest", "w": 16, "h": 16, "fw": 1, "fd": 1, "solid": true},
	"bed": {"name": "Bed", "w": 16, "h": 32, "fw": 1, "fd": 2, "solid": true},
	"table": {"name": "Table", "w": 32, "h": 24, "fw": 2, "fd": 1, "solid": true},
	"chair": {"name": "Chair", "w": 16, "h": 16, "fw": 1, "fd": 1, "solid": true},
	"bookshelf": {"name": "Bookshelf", "w": 32, "h": 32, "fw": 2, "fd": 1, "solid": true},
	"plant": {"name": "Pot plant", "w": 16, "h": 24, "fw": 1, "fd": 1, "solid": true},
	"fireplace": {"name": "Fireplace", "w": 32, "h": 32, "fw": 2, "fd": 1, "solid": true, "glow": true},
}
const OBJ_ORDER := ["tree", "pine", "rock", "bush", "flowers", "fence", "house", "well", "lamp", "crate", "crops", "campfire", "sign", "stall",
	"statue", "fountain", "tent", "barrel", "cart", "stump", "deadtree", "palm", "cactus", "bench", "haystack", "torch",
	"chest", "bed", "table", "chair", "bookshelf", "plant", "fireplace"]
## Atlas cell for objects (the largest sprite fits).
const CELL := 64

static var _ground_tex: ImageTexture
static var _obj_tex: ImageTexture
static var _icons := {}


static func ground_uv(id: int) -> Rect2:
	var rows := ceili(float(GROUND.size()) / COLS)
	var r := Rect2(float(id % COLS) / COLS, float(id / COLS) / rows, 1.0 / COLS, 1.0 / rows)
	# Half a texel in from each edge so neighbouring tiles never bleed in.
	return r.grow_individual(-0.5 / (COLS * PX), -0.5 / (rows * PX), -0.5 / (COLS * PX), -0.5 / (rows * PX))


static func ground_atlas() -> ImageTexture:
	if _ground_tex:
		return _ground_tex
	var rows := ceili(float(GROUND.size()) / COLS)
	var img := Image.create(COLS * PX, rows * PX, false, Image.FORMAT_RGBA8)
	for id in range(1, GROUND.size()):
		img.blit_rect(_paint_ground(id), Rect2i(0, 0, PX, PX), Vector2i((id % COLS) * PX, (id / COLS) * PX))
	_ground_tex = ImageTexture.create_from_image(img)
	return _ground_tex


## UV rect of an object's sprite in the object atlas.
static func obj_uv(key: String) -> Rect2:
	var i := OBJ_ORDER.find(key)
	var o: Dictionary = OBJECTS[key]
	var rows := ceili(float(OBJ_ORDER.size()) / COLS)
	var aw := float(COLS * CELL)
	var ah := float(rows * CELL)
	var x := (i % COLS) * CELL + (CELL - int(o["w"])) / 2
	var y := (i / COLS) * CELL + (CELL - int(o["h"]))
	return Rect2(x / aw, y / ah, float(o["w"]) / aw, float(o["h"]) / ah)


static func obj_atlas() -> ImageTexture:
	if _obj_tex:
		return _obj_tex
	var rows := ceili(float(OBJ_ORDER.size()) / COLS)
	var img := Image.create(COLS * CELL, rows * CELL, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in OBJ_ORDER.size():
		var key: String = OBJ_ORDER[i]
		var o: Dictionary = OBJECTS[key]
		var s := _paint_obj(key)
		PixelSprites.outline(s)
		img.blit_rect(s, Rect2i(0, 0, o["w"], o["h"]), Vector2i((i % COLS) * CELL + (CELL - int(o["w"])) / 2, (i / COLS) * CELL + (CELL - int(o["h"]))))
	_obj_tex = ImageTexture.create_from_image(img)
	return _obj_tex


static func ground_icon(id: int) -> Texture2D:
	var k := "g%d" % id
	if not _icons.has(k):
		var img := _paint_ground(id)
		img.resize(PX * 4, PX * 4, Image.INTERPOLATE_NEAREST)
		_icons[k] = ImageTexture.create_from_image(img)
	return _icons[k]


static func obj_icon(key: String) -> Texture2D:
	if not _icons.has(key):
		var img := _paint_obj(key)
		PixelSprites.outline(img)
		var o: Dictionary = OBJECTS[key]
		var s := maxi(int(o["w"]), int(o["h"]))
		var sq := Image.create(s, s, false, Image.FORMAT_RGBA8)
		sq.fill(Color(0, 0, 0, 0))
		sq.blit_rect(img, Rect2i(0, 0, o["w"], o["h"]), Vector2i((s - int(o["w"])) / 2, s - int(o["h"])))
		sq.resize(64, 64, Image.INTERPOLATE_NEAREST)
		_icons[key] = ImageTexture.create_from_image(sq)
	return _icons[key]


# ---------------------------------------------------------------- ground

static func _paint_ground(id: int) -> Image:
	var img := Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	var r := U.rng(2000 + id * 31)
	var name := str(GROUND[id].get("name", "")).to_lower()
	var base: Array = {"grass": ["6cc04a", "62b343", "7ccf55"], "meadow": ["6cc04a", "62b343", "7ccf55"], "path": ["c9a46a", "bd975d", "d6b277"],
		"sand": ["e8d39a", "dcc68a", "f0dfaa"], "water": ["3d8fd1", "3484c4", "4a9de0"], "plaza": ["a8a39a", "9a958c", "b5b0a6"],
		"cobble": ["8a8f98", "7a7f88", "9aa0a8"], "swamp": ["4a6a3a", "3f5f34", "5a7a44"], "ice": ["bfe6f7", "aedcf2", "d6f0fb"],
		"carpet": ["b33a3a", "a83535", "c04444"], "wall": ["8a6236", "7a5530", "96703f"], "void": ["10151f", "10151f", "121826"], "doorway": ["6e4a2a", "5e3e22", "7a5230"],
		"wood floor": ["b8874e", "a67943", "c4945a"], "farmland": ["7a5434", "6a4628", "8a6440"], "dark grass": ["4f9a3a", "468c34", "5aa844"],
		"snow": ["f4f8fc", "e6eef6", "ffffff"]}.get(name, ["ff00ff", "ff00ff", "ff00ff"])
	for y in PX:
		for x in PX:
			var v := r.next()
			img.set_pixel(x, y, Color(base[0] if v < 0.55 else (base[1] if v < 0.85 else base[2])))
	match name:
		"grass", "dark grass":
			for k in 5:
				var x := int(r.next() * PX)
				var y := int(r.next() * (PX - 1))
				img.set_pixel(x, y, Color("8be06a") if name == "grass" else Color("6cbf52"))
				img.set_pixel(x, y + 1, Color(base[1]).darkened(0.15))
		"meadow":
			for k in 4:
				var c: Color = [Color("ff6b8a"), Color("ffd166"), Color("ffffff"), Color("9b7bff")][k]
				var x := 2 + int(r.next() * 12)
				var y := 2 + int(r.next() * 12)
				img.set_pixel(x, y, c)
				img.set_pixel(x + 1, y, c.darkened(0.2))
		"plaza":
			for y in PX:
				for x in PX:
					if y % 8 == 7 or (x + (8 if (y / 8) % 2 else 0)) % 8 == 7:
						img.set_pixel(x, y, Color("8a857c"))
		"wood floor":
			for y in PX:
				for x in PX:
					if x % 4 == 3:
						img.set_pixel(x, y, Color("8a6236"))
		"farmland":
			for y in PX:
				if y % 4 == 1:
					for x in PX:
						img.set_pixel(x, y, Color("5a3a20"))
		"cobble":
			for y in PX:
				for x in PX:
					if (x + (y / 4) * 3) % 5 == 0 or y % 4 == 3:
						img.set_pixel(x, y, Color("5f646c"))
		"swamp":
			for k in 4:
				var sx := int(r.next() * 12)
				var sy := int(r.next() * 14)
				for j in 4:
					img.set_pixel(sx + j, sy, Color("3a5a6a"))
		"ice":
			for k in 4:
				img.set_pixel(3 + k, 10 - k, Color.WHITE)
				img.set_pixel(9 + k, 5 - k / 2, Color("eaf8ff"))
		"carpet":
			for x in PX:
				img.set_pixel(x, 1, Color("f2c14e"))
				img.set_pixel(x, PX - 2, Color("f2c14e"))
		"wall":
			for y in PX:
				for x in PX:
					if x % 4 == 0:
						img.set_pixel(x, y, Color("5e3e22"))
				if y < 3:
					for x in PX:
						img.set_pixel(x, y, Color("4a3018"))
		"doorway":
			for y in PX:
				img.set_pixel(1, y, Color("4a3018"))
				img.set_pixel(PX - 2, y, Color("4a3018"))
		"water":
			for k in 3:
				var x := int(r.next() * 12)
				var y := int(r.next() * PX)
				for j in 3:
					img.set_pixel(x + j, y, Color("8fd3ff"))
	return img


# ---------------------------------------------------------------- objects

static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			_px(img, xx, yy, c)


static func _disc(img: Image, cx: float, cy: float, rx: float, ry: float, light: Color, dark: Color, r: U.Rng) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			var d := dx * dx + dy * dy
			if d <= 1.0:
				var lit := dx * -0.5 + dy * -0.6 + r.next() * 0.35
				_px(img, x, y, light if lit > 0.05 else dark)


static func _paint_obj(key: String) -> Image:
	var o: Dictionary = OBJECTS[key]
	var w: int = o["w"]
	var h: int = o["h"]
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := U.rng(3000 + OBJ_ORDER.find(key) * 13)
	match key:
		"tree":
			_rect(img, 13, 30, 6, 16, Color("7a5230"))
			_rect(img, 13, 30, 2, 16, Color("5e3e22"))
			_disc(img, 16, 18, 15, 15, Color("5fbf4a"), Color("3f9a3a"), r)
			for k in 8:
				_px(img, 6 + int(r.next() * 20), 6 + int(r.next() * 20), Color("8be06a"))
		"pine":
			_rect(img, 14, 38, 4, 9, Color("6e4a2a"))
			for k in 4:
				var top := 2 + k * 9
				for y in 12:
					var half := int((y + 2) * (1.1 + k * 0.12))
					_rect(img, 16 - half, top + y, half * 2, 1, Color("2f7a3e") if (y + k) % 3 else Color("3f8f4a"))
		"rock":
			_disc(img, 8, 9.5, 7.5, 6.5, Color("a8adb5"), Color("7d828a"), r)
		"bush":
			_disc(img, 8, 9, 7.5, 7, Color("56b048"), Color("3a8a34"), r)
			_px(img, 5, 6, Color("e63946"))
			_px(img, 10, 9, Color("e63946"))
		"flowers":
			for k in 5:
				var x := 2 + k * 3
				var y := 6 + (k * 7) % 6
				var c: Color = [Color("ff6b8a"), Color("ffd166"), Color("9b7bff"), Color("ffffff"), Color("ff9a4a")][k]
				_rect(img, x, y + 2, 1, 4, Color("3f9a3a"))
				_rect(img, x - 1, y, 3, 2, c)
		"fence":
			for x in [2, 13]:
				_rect(img, x, 3, 2, 12, Color("8a6236"))
			_rect(img, 0, 6, 16, 2, Color("b8874e"))
			_rect(img, 0, 11, 16, 2, Color("b8874e"))
		"house":
			# Roof.
			for y in 30:
				var inset := maxi(0, 10 - y)
				_rect(img, inset, y + 2, w - inset * 2, 1, Color("b33a3a") if y % 4 != 3 else Color("8e2c2c"))
			_rect(img, 0, 31, w, 2, Color("7e2626"))
			# Front wall with door and windows.
			_rect(img, 4, 33, w - 8, 31, Color("e0cfae"))
			for y in range(33, 64, 6):
				_rect(img, 4, y, w - 8, 1, Color("cbb894"))
			_rect(img, 26, 44, 12, 20, Color("6e4a2a"))
			_rect(img, 31, 44, 1, 20, Color("4a3018"))
			_px(img, 35, 55, Color("f2c14e"))
			for wx in [9, 45]:
				_rect(img, wx, 40, 10, 10, Color("6e4a2a"))
				_rect(img, wx + 1, 41, 8, 8, Color("ffe08a"))
				_rect(img, wx + 4, 41, 1, 8, Color("6e4a2a"))
				_rect(img, wx + 1, 44, 8, 1, Color("6e4a2a"))
		"well":
			_rect(img, 4, 2, 24, 3, Color("8e2c2c"))
			_rect(img, 6, 5, 2, 12, Color("6e4a2a"))
			_rect(img, 24, 5, 2, 12, Color("6e4a2a"))
			_rect(img, 4, 17, 24, 13, Color("9aa0a8"))
			for y in range(17, 30, 4):
				for x in range(4, 28, 6):
					_rect(img, x + (3 if (y / 4) % 2 else 0), y, 1, 4, Color("7d828a"))
			_rect(img, 6, 17, 20, 3, Color("2a4a6a"))
		"lamp":
			_rect(img, 7, 10, 2, 22, Color("3a3a3a"))
			_rect(img, 4, 2, 8, 9, Color("3a3a3a"))
			_rect(img, 5, 3, 6, 7, Color("ffd166"))
		"crate":
			_rect(img, 1, 2, 14, 13, Color("b8874e"))
			_rect(img, 1, 2, 14, 1, Color("8a6236"))
			_rect(img, 1, 8, 14, 1, Color("8a6236"))
			_rect(img, 7, 2, 1, 13, Color("8a6236"))
		"crops":
			for x in range(1, 16, 3):
				for y in range(4, 15):
					_px(img, x, y, Color("6fae3a") if y > 7 else Color("e9c46a"))
		"campfire":
			for x in range(2, 14):
				_px(img, x, 13, Color("6e4a2a"))
				_px(img, x, 14, Color("5e3e22"))
			_disc(img, 8, 9, 4, 5, Color("ffd166"), Color("ff7a2e"), r)
		"sign":
			_rect(img, 7, 9, 2, 7, Color("6e4a2a"))
			_rect(img, 1, 2, 14, 8, Color("b8874e"))
			_rect(img, 3, 4, 10, 1, Color("5e3e22"))
			_rect(img, 3, 7, 7, 1, Color("5e3e22"))
		"statue":
			_rect(img, 3, 26, 10, 6, Color("7d828a"))
			_rect(img, 5, 12, 6, 14, Color("b5bac2"))
			_disc(img, 8, 8, 4, 4, Color("c9ced6"), Color("a8adb5"), r)
			_rect(img, 2, 14, 3, 2, Color("b5bac2"))
			_rect(img, 11, 12, 3, 2, Color("b5bac2"))
		"fountain":
			_disc(img, 16, 20, 15, 10, Color("9aa0a8"), Color("7d828a"), r)
			_disc(img, 16, 19, 11, 7, Color("4a9de0"), Color("3d8fd1"), r)
			_rect(img, 14, 6, 4, 14, Color("9aa0a8"))
			_disc(img, 16, 6, 4, 3, Color("8fd3ff"), Color("4a9de0"), r)
		"tent":
			for y in 26:
				var half := 2 + y * 14 / 26
				_rect(img, 16 - half, 4 + y, half * 2, 1, Color("d9b46a") if y % 5 else Color("c49a52"))
			_rect(img, 13, 18, 6, 12, Color("5e3e22"))
		"barrel":
			_rect(img, 3, 2, 10, 13, Color("8a5a30"))
			_rect(img, 3, 4, 10, 1, Color("3a3a3a"))
			_rect(img, 3, 11, 10, 1, Color("3a3a3a"))
			_rect(img, 4, 2, 8, 2, Color("6e4a2a"))
		"cart":
			_rect(img, 2, 4, 28, 10, Color("b8874e"))
			_rect(img, 2, 4, 28, 2, Color("8a6236"))
			_disc(img, 8, 17, 5, 5, Color("6e4a2a"), Color("4a3018"), r)
			_disc(img, 24, 17, 5, 5, Color("6e4a2a"), Color("4a3018"), r)
		"stump":
			_rect(img, 3, 6, 10, 9, Color("7a5230"))
			_disc(img, 8, 6, 5, 2.5, Color("c49a6c"), Color("a87e52"), r)
		"deadtree":
			_rect(img, 14, 20, 4, 27, Color("6e5a48"))
			for b in [[14, 22, -1], [17, 16, 1], [14, 10, -1], [17, 6, 1]]:
				for k in 8:
					_px(img, b[0] + b[2] * k, b[1] - k / 2, Color("6e5a48"))
					_px(img, b[0] + b[2] * k, b[1] - k / 2 + 1, Color("5a4838"))
		"palm":
			for y in 30:
				_rect(img, 15 + int(sin(y * 0.15) * 2.0), 17 + y, 3, 1, Color("8a6236") if y % 3 else Color("6e4a2a"))
			for leaf in [[-1, 0], [1, 0], [-1, 1], [1, 1], [0, -1]]:
				for k in 13:
					_rect(img, 16 + leaf[0] * k, 14 + leaf[1] * k / 2 + absi(k - 6) / 3 - 3, 2, 2, Color("3f9a3a") if k % 3 else Color("56b048"))
		"cactus":
			_rect(img, 6, 6, 5, 26, Color("3f9a3a"))
			_rect(img, 2, 12, 3, 8, Color("3f9a3a"))
			_rect(img, 2, 18, 5, 2, Color("3f9a3a"))
			_rect(img, 12, 9, 3, 7, Color("3f9a3a"))
			_rect(img, 10, 14, 5, 2, Color("3f9a3a"))
			_rect(img, 7, 6, 1, 26, Color("56b048"))
		"bench":
			_rect(img, 1, 3, 30, 4, Color("b8874e"))
			_rect(img, 1, 8, 30, 3, Color("a67943"))
			_rect(img, 3, 11, 2, 5, Color("4a3018"))
			_rect(img, 27, 11, 2, 5, Color("4a3018"))
		"haystack":
			_disc(img, 16, 14, 15, 10, Color("e9c46a"), Color("d4a83f"), r)
			for k in 6:
				_px(img, 6 + k * 4, 8 + (k % 3) * 4, Color("f4dc8a"))
		"torch":
			_rect(img, 7, 12, 2, 20, Color("6e4a2a"))
			_disc(img, 8, 7, 4, 6, Color("ffd166"), Color("ff7a2e"), r)
		"chest":
			_rect(img, 2, 5, 12, 10, Color("8a5a30"))
			_rect(img, 2, 5, 12, 3, Color("a8703c"))
			_rect(img, 2, 8, 12, 1, Color("f2c14e"))
			_rect(img, 7, 8, 2, 3, Color("f2c14e"))
		"bed":
			_rect(img, 1, 1, 14, 30, Color("8a5a30"))
			_rect(img, 2, 2, 12, 6, Color("f4f4f0"))
			_rect(img, 2, 9, 12, 21, Color("3d6fb5"))
			_rect(img, 2, 9, 12, 2, Color("6f9be0"))
		"table":
			_rect(img, 1, 3, 30, 12, Color("b8874e"))
			_rect(img, 1, 3, 30, 2, Color("c4945a"))
			_rect(img, 3, 15, 3, 8, Color("6e4a2a"))
			_rect(img, 26, 15, 3, 8, Color("6e4a2a"))
			_rect(img, 12, 6, 4, 4, Color("f4f4f0"))
		"chair":
			_rect(img, 3, 1, 10, 7, Color("8a6236"))
			_rect(img, 3, 8, 10, 3, Color("b8874e"))
			_rect(img, 3, 11, 2, 5, Color("6e4a2a"))
			_rect(img, 11, 11, 2, 5, Color("6e4a2a"))
		"bookshelf":
			_rect(img, 1, 1, 30, 30, Color("6e4a2a"))
			for row in 3:
				for k in 9:
					_rect(img, 3 + k * 3, 3 + row * 9, 2, 7, [Color("b33a3a"), Color("3d6fb5"), Color("3f9a3a"), Color("e9c46a")][(k + row) % 4])
				_rect(img, 1, 10 + row * 9, 30, 1, Color("4a3018"))
		"plant":
			_rect(img, 4, 16, 8, 8, Color("b0523d"))
			_disc(img, 8, 9, 6, 8, Color("56b048"), Color("3f9a3a"), r)
		"fireplace":
			_rect(img, 1, 2, 30, 30, Color("8a8f98"))
			_rect(img, 1, 2, 30, 4, Color("6a6e76"))
			_rect(img, 7, 14, 18, 18, Color("2a2a2a"))
			_disc(img, 16, 25, 6, 6, Color("ffd166"), Color("ff7a2e"), r)
		"stall":
			for y in 12:
				_rect(img, 0, 6 + y, w, 1, Color("e63946") if (y / 3) % 2 == 0 else Color("f4f4f0"))
			_rect(img, 3, 18, 2, 30, Color("6e4a2a"))
			_rect(img, w - 5, 18, 2, 30, Color("6e4a2a"))
			_rect(img, 3, 34, w - 6, 10, Color("b8874e"))
			for k in 6:
				_rect(img, 8 + k * 6, 30, 4, 4, [Color("e63946"), Color("ffd166"), Color("6fae3a")][k % 3])
	return img
