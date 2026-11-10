class_name PixelTiles
## Tiles for the Pixel 2D style: 16×16 pixel art painted in code (seeded, so
## every run draws the same tiles), packed into one atlas, plus small
## buildings stamped from tile patterns.

const PX := 16
const COLS := 8

## id -> {name, solid, layer ("fg" stands in the way, "bg" sits behind
## characters), water}. Id 0 is empty.
const TILES := [
	{},
	{"name": "Grass", "solid": true},
	{"name": "Dirt", "solid": true},
	{"name": "Stone", "solid": true},
	{"name": "Sand", "solid": true},
	{"name": "Brick", "solid": true},
	{"name": "Planks", "solid": true},
	{"name": "Log", "solid": true},
	{"name": "Leaves", "solid": false, "layer": "bg"},
	{"name": "Glass", "solid": true},
	{"name": "Water", "solid": false, "water": true},
	{"name": "Ladder", "solid": false, "layer": "bg", "ladder": true},
	{"name": "Cobblestone", "solid": true},
	{"name": "Snow", "solid": true},
	{"name": "Roof", "solid": true},
	{"name": "Door", "solid": false, "layer": "bg"},
	{"name": "Window", "solid": false, "layer": "bg"},
	{"name": "Flowers", "solid": false, "layer": "bg"},
	{"name": "Tall grass", "solid": false, "layer": "bg"},
	{"name": "Lantern", "solid": false, "layer": "bg"},
	{"name": "Gold", "solid": true},
	{"name": "Ice", "solid": true},
	{"name": "Wall", "solid": false, "layer": "bg"},
	{"name": "Fence", "solid": false, "layer": "bg"},
	{"name": "Trunk", "solid": false, "layer": "bg"},
	{"name": "Stone wall", "solid": false, "layer": "bg"},
	{"name": "Mossy stone", "solid": true},
	{"name": "Marble", "solid": true},
	{"name": "Crate", "solid": true},
	{"name": "Hay", "solid": true},
	{"name": "Cloud", "solid": true},
	{"name": "Bookshelf", "solid": false, "layer": "bg"},
	{"name": "Vines", "solid": false, "layer": "bg"},
	{"name": "Mushroom", "solid": false, "layer": "bg"},
	{"name": "Torch", "solid": false, "layer": "bg"},
	{"name": "Banner", "solid": false, "layer": "bg"},
]

const ID := {
	"grass": 1, "dirt": 2, "stone": 3, "sand": 4, "brick": 5, "planks": 6, "log": 7, "leaves": 8, "glass": 9,
	"water": 10, "ladder": 11, "cobble": 12, "snow": 13, "roof": 14, "door": 15, "window": 16, "flowers": 17,
	"tallgrass": 18, "lantern": 19, "gold": 20, "ice": 21, "wall": 22, "fence": 23, "trunk": 24, "stonewall": 25,
	"mossy": 26, "marble": 27, "crate": 28, "hay": 29, "cloud": 30, "bookshelf": 31, "vines": 32, "mushroom": 33, "torch": 34, "banner": 35,
}

## Buildings: rows top to bottom, one character per tile. "." = leave as is,
## " " = clear, other letters map to tiles (see KEYS). Walls and trunks sit
## behind the characters so you can walk in; floors and roofs are solid.
const KEYS := {"G": "grass", "D": "dirt", "S": "stone", "B": "brick", "P": "planks", "L": "log", "l": "leaves",
	"g": "glass", "h": "ladder", "C": "cobble", "R": "roof", "d": "door", "w": "window", "W": "wall",
	"f": "flowers", "t": "tallgrass", "n": "lantern", "F": "fence", "T": "trunk", "c": "stonewall",
	"M": "mossy", "A": "marble", "X": "crate", "Y": "hay", "O": "cloud", "k": "bookshelf", "v": "vines", "m": "mushroom", "o": "torch", "r": "banner"}

const PREFABS := {
	"cottage": {"name": "Cottage", "icon": "roof", "rows": [
		"..RR..",
		".RRRR.",
		"RRRRRR",
		".WwWW.",
		".WWWn.",
		".WdWW.",
	]},
	"tower": {"name": "Watchtower", "icon": "cobble", "rows": [
		"C..C",
		"PPhP",
		"cwhc",
		"c.hc",
		"cwhc",
		"cPhc",
		"cwhc",
		"c.hc",
		"cdhc",
	]},
	"tree": {"name": "Tree", "icon": "leaves", "rows": [
		".lll.",
		"lllll",
		"lllll",
		".lTl.",
		"..T..",
		"..T..",
	]},
	"bridge": {"name": "Bridge", "icon": "planks", "rows": [
		"F.F.F.F",
		"PPPPPPP",
	]},
	"shop": {"name": "Market stall", "icon": "planks", "rows": [
		"RRRRR",
		"T...T",
		"T.n.T",
		"TFFFT",
	]},
	"well": {"name": "Well", "icon": "stone", "rows": [
		"TTTT",
		"T..T",
		"SSSS",
	]},
	"castle": {"name": "Castle tower", "icon": "mossy", "rows": [
		"M.M.M.M",
		"MMMMMMM",
		"cc.r.cc",
		"c.wcw.c",
		"co...oc",
		"cPPPPPc",
		"cc.k.cc",
		"c..r..c",
		"c..d..c",
	]},
	"brickhouse": {"name": "Brick house", "icon": "brick", "rows": [
		"..RRRR..",
		".RRRRRR.",
		"RRRRRRRR",
		".BwBBwB.",
		".BBBBBB.",
		".BBdBkB.",
	]},
	"lamppost": {"name": "Lamp post", "icon": "lantern", "rows": [
		"n",
		"F",
		"F",
	]},
}

static var _atlas: ImageTexture
static var _icons := {}


static func count() -> int:
	return TILES.size()


static func get_tile(id: int) -> Dictionary:
	return TILES[id] if id > 0 and id < TILES.size() else {}


static func is_solid(id: int) -> bool:
	return get_tile(id).get("solid", false)


static func is_bg(id: int) -> bool:
	return get_tile(id).get("layer", "fg") == "bg"


static func is_water(id: int) -> bool:
	return get_tile(id).get("water", false)


static func is_ladder(id: int) -> bool:
	return get_tile(id).get("ladder", false)


## Atlas UV rect (in 0..1) of a tile.
static func uv_rect(id: int) -> Rect2:
	var rows := ceili(float(TILES.size()) / COLS)
	var c := id % COLS
	var r := id / COLS
	var rect := Rect2(float(c) / COLS, float(r) / rows, 1.0 / COLS, 1.0 / rows)
	# Half a texel in from each edge so neighbouring tiles never bleed in.
	return rect.grow_individual(-0.5 / (COLS * PX), -0.5 / (rows * PX), -0.5 / (COLS * PX), -0.5 / (rows * PX))


static func atlas() -> ImageTexture:
	if _atlas:
		return _atlas
	var rows := ceili(float(TILES.size()) / COLS)
	var img := Image.create(COLS * PX, rows * PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for id in range(1, TILES.size()):
		var t := _paint(id)
		img.blit_rect(t, Rect2i(0, 0, PX, PX), Vector2i((id % COLS) * PX, (id / COLS) * PX))
	_atlas = ImageTexture.create_from_image(img)
	return _atlas


## A tile drawn bigger for the palette (nearest-neighbour scaled).
static func icon(id: int) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var img := _paint(id)
	img.resize(PX * 4, PX * 4, Image.INTERPOLATE_NEAREST)
	var tex := ImageTexture.create_from_image(img)
	_icons[id] = tex
	return tex


# ---------------------------------------------------------------- painting

static func _paint(id: int) -> Image:
	var img := Image.create(PX, PX, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r := U.rng(1000 + id * 17)
	var name := str(get_tile(id).get("name", "")).to_lower()
	match name:
		"grass":
			_noise(img, r, Color("7a5434"), Color("6a4628"))
			for x in PX:
				var h := 3 + int(r.next() * 3.0)
				for y in h:
					img.set_pixel(x, y, Color("5fbf4a") if y < h - 1 else Color("3f9a3a"))
			for x in range(0, PX, 3):
				img.set_pixel(x, 0, Color("8be06a"))
		"dirt":
			_noise(img, r, Color("7a5434"), Color("6a4628"))
			_specks(img, r, Color("8d6a48"), 6)
		"stone":
			_noise(img, r, Color("8a8f98"), Color("7a7f88"))
			_specks(img, r, Color("6a6e76"), 8)
		"sand":
			_noise(img, r, Color("e8d39a"), Color("dcc68a"))
			_specks(img, r, Color("cfb97c"), 6)
		"brick":
			img.fill(Color("b0523d"))
			for y in PX:
				for x in PX:
					var row := y / 4
					var off := 4 if row % 2 == 1 else 0
					if y % 4 == 3 or (x + off) % 8 == 7:
						img.set_pixel(x, y, Color("d9c7b0"))
		"planks":
			img.fill(Color("b8874e"))
			for y in PX:
				for x in PX:
					if y % 4 == 3:
						img.set_pixel(x, y, Color("8a6236"))
					elif (x + (y / 4) * 5) % 16 == 0:
						img.set_pixel(x, y, Color("8a6236"))
					elif r.next() < 0.06:
						img.set_pixel(x, y, Color("a67943"))
		"log", "trunk":
			img.fill(Color("7a5230"))
			for y in PX:
				for x in [2, 7, 12]:
					img.set_pixel(x, y, Color("5e3e22"))
			_specks(img, r, Color("8d6238"), 6)
		"leaves":
			for y in PX:
				for x in PX:
					var v := r.next()
					if v < 0.88:
						img.set_pixel(x, y, Color("3f9a3a") if v < 0.55 else (Color("56b048") if v < 0.8 else Color("2f7a2e")))
		"glass":
			for y in PX:
				for x in PX:
					if x == 0 or y == 0 or x == PX - 1 or y == PX - 1:
						img.set_pixel(x, y, Color("cfe8f5"))
			for k in 4:
				img.set_pixel(3 + k, 4 + k, Color("ffffff"))
				img.set_pixel(8 + k, 3 + k, Color("e6f4fb"))
		"water":
			_noise(img, r, Color("3d8fd1"), Color("3484c4"))
			for x in PX:
				img.set_pixel(x, 0, Color("8fd3ff"))
		"ladder":
			for y in PX:
				img.set_pixel(3, y, Color("8a6236"))
				img.set_pixel(12, y, Color("8a6236"))
				if y % 4 == 1:
					for x in range(3, 13):
						img.set_pixel(x, y, Color("b8874e"))
		"cobblestone", "stone wall":
			img.fill(Color("6a6e76") if name == "cobblestone" else Color("565a62"))
			for k in 9:
				var cx := int(r.next() * PX)
				var cy := int(r.next() * PX)
				for y in range(cy - 2, cy + 2):
					for x in range(cx - 3, cx + 3):
						img.set_pixel(posmod(x, PX), posmod(y, PX), Color("9aa0a8") if (x + y) % 5 else Color("8a9098"))
		"snow":
			_noise(img, r, Color("7a5434"), Color("6a4628"))
			for x in PX:
				var h := 4 + int(r.next() * 3.0)
				for y in h:
					img.set_pixel(x, y, Color("f4f8fc") if y < h - 1 else Color("cfdbe8"))
		"roof":
			img.fill(Color("b33a3a"))
			for y in PX:
				for x in PX:
					if y % 4 == 3:
						img.set_pixel(x, y, Color("7e2626"))
					elif (x + (y / 4) * 2) % 4 == 0:
						img.set_pixel(x, y, Color("cc4d4d"))
		"door":
			img.fill(Color("6e4a2a"))
			for y in PX:
				img.set_pixel(0, y, Color("4a3018"))
				img.set_pixel(PX - 1, y, Color("4a3018"))
				img.set_pixel(7, y, Color("5a3c20"))
			img.set_pixel(11, 8, Color("f2c14e"))
		"window":
			img.fill(Color("caa47a"))
			for y in range(3, 13):
				for x in range(3, 13):
					img.set_pixel(x, y, Color("ffe08a") if (x != 7 and y != 7) else Color("6e4a2a"))
		"flowers":
			for k in 5:
				var x := 2 + k * 3
				for y in range(10, PX):
					img.set_pixel(x, y, Color("3f9a3a"))
				var c: Color = [Color("ff6b8a"), Color("ffd166"), Color("9b7bff"), Color("ffffff"), Color("ff9a4a")][k]
				img.set_pixel(x, 9, c)
				img.set_pixel(x - 1, 9, c)
				img.set_pixel(x + 1, 9, c)
				img.set_pixel(x, 8, c)
		"tall grass":
			for x in PX:
				var h := 5 + int(r.next() * 9.0)
				for y in range(PX - h, PX):
					if (x + y) % 2 == 0 or r.next() < 0.5:
						img.set_pixel(x, y, Color("4fae46") if y > PX - h + 2 else Color("7fd060"))
		"lantern":
			for y in range(0, 5):
				img.set_pixel(7, y, Color("3a3a3a"))
			for y in range(5, 12):
				for x in range(5, 11):
					img.set_pixel(x, y, Color("ffd166") if (x > 5 and x < 10 and y > 5 and y < 11) else Color("3a3a3a"))
		"gold":
			_noise(img, r, Color("f2c14e"), Color("e0ad38"))
			_specks(img, r, Color("fff0a8"), 5)
		"ice":
			_noise(img, r, Color("aee0f7"), Color("9cd4ef"))
			for k in 5:
				img.set_pixel(2 + k, 10 - k, Color("ffffff"))
		"wall":
			img.fill(Color("c9b79a"))
			for y in PX:
				for x in PX:
					if y % 8 == 7:
						img.set_pixel(x, y, Color("a8957a"))
					elif r.next() < 0.05:
						img.set_pixel(x, y, Color("bba88a"))
		"mossy stone":
			_noise(img, r, Color("7d838c"), Color("6e737c"))
			for k in 14:
				img.set_pixel(int(r.next() * PX), int(r.next() * 6), Color("5fa64a") if k % 2 else Color("4a8a3a"))
		"marble":
			_noise(img, r, Color("ecebe6"), Color("e2e0da"))
			for k in 6:
				img.set_pixel(2 + k * 2, 3 + (k * 5) % 10, Color("b9b6ae"))
		"crate":
			img.fill(Color("b8874e"))
			for k in PX:
				img.set_pixel(k, 0, Color("8a6236"))
				img.set_pixel(k, PX - 1, Color("8a6236"))
				img.set_pixel(0, k, Color("8a6236"))
				img.set_pixel(PX - 1, k, Color("8a6236"))
				img.set_pixel(k, k, Color("8a6236"))
		"hay":
			_noise(img, r, Color("e9c46a"), Color("d4a83f"))
			for x in PX:
				img.set_pixel(x, 5, Color("b8862f"))
				img.set_pixel(x, 11, Color("b8862f"))
		"cloud":
			for y in PX:
				for x in PX:
					var dd := Vector2(x - 7.5, (y - 9.0) * 1.4).length()
					if dd < 8.5 or (y > 8):
						img.set_pixel(x, y, Color("ffffff") if y < 10 else Color("dfe8f2"))
		"bookshelf":
			img.fill(Color("6e4a2a"))
			for row in 2:
				for k in 6:
					var bc: Color = [Color("b33a3a"), Color("3d6fb5"), Color("3f9a3a"), Color("e9c46a")][(k + row) % 4]
					for y in range(2 + row * 7, 7 + row * 7):
						img.set_pixel(2 + k * 2, y, bc)
				for x in PX:
					img.set_pixel(x, 7 + row * 7, Color("4a3018"))
		"vines":
			for k in 5:
				var vx := 1 + k * 3
				for y in PX:
					if (y + k) % 7 != 0:
						img.set_pixel(vx + (1 if (y / 3) % 2 else 0), y, Color("3f9a3a") if y % 3 else Color("56b048"))
		"mushroom":
			for y in range(9, PX):
				img.set_pixel(7, y, Color("f4ead8"))
				img.set_pixel(8, y, Color("f4ead8"))
			for y in range(4, 9):
				for x in range(3, 13):
					if absf(x - 7.5) < (y - 2) * 1.4:
						img.set_pixel(x, y, Color("e63946") if (x + y) % 4 else Color("ffffff"))
		"torch":
			for y in range(7, PX):
				img.set_pixel(7, y, Color("6e4a2a"))
				img.set_pixel(8, y, Color("6e4a2a"))
			for y in range(2, 7):
				for x in range(5, 11):
					if absf(x - 7.5) < (y - 1) * 0.8:
						img.set_pixel(x, y, Color("ffd166") if y > 3 else Color("ff7a2e"))
		"banner":
			for x in range(2, 14):
				img.set_pixel(x, 0, Color("6e4a2a"))
			for y in range(1, 14):
				for x in range(4, 12):
					img.set_pixel(x, y, Color("3d6fb5"))
			for y in range(5, 9):
				img.set_pixel(7, y, Color("f2c14e"))
				img.set_pixel(8, y, Color("f2c14e"))
			img.set_pixel(4, 14, Color("3d6fb5"))
			img.set_pixel(11, 14, Color("3d6fb5"))
		"fence":
			for y in range(4, PX):
				img.set_pixel(3, y, Color("8a6236"))
				img.set_pixel(12, y, Color("8a6236"))
			for x in PX:
				img.set_pixel(x, 7, Color("b8874e"))
				img.set_pixel(x, 12, Color("b8874e"))
	return img


static func _noise(img: Image, r: U.Rng, a: Color, b: Color) -> void:
	for y in PX:
		for x in PX:
			img.set_pixel(x, y, a if r.next() < 0.6 else b)


static func _specks(img: Image, r: U.Rng, c: Color, n: int) -> void:
	for k in n:
		img.set_pixel(int(r.next() * PX), int(r.next() * PX), c)
