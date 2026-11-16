class_name SpriteImport
## Pixel 2D imports: character sprite sheets and object sprites from
##   - .png / .webp sheets: a strip of frames, or an RPG-style grid (3 or 4
##     columns × 4 rows: down, left, right, up), or a single picture;
##   - .ase / .aseprite files: every frame, layers flattened, tags as actions.
## Each import is stored as a PNG sheet plus a JSON description in
## user://assets/sprites/, and tagged with the style it was imported into.
##
## Aseprite tags name the actions: "idle", "walk", "run", "jump", "dance",
## "wave", "sit", "sleep", "celebrate"/"cheer", "laugh", "cry", "point",
## "attack", "fight", "talk", "hurt", "climb". Add "_down", "_up", "_left",
## "_right" (or "_front", "_back", "_side") for the top view's directions.

const PREFIX := "spr:"
const STATES := {
	"idle": ["idle", "stand", "breath"], "walk": ["walk", "move"], "run": ["run", "sprint"], "jump": ["jump", "fall"],
	"dance": ["dance"], "wave": ["wave", "hello"], "sit": ["sit"], "sleep": ["sleep", "lie"], "celebrate": ["celebrat", "cheer", "victory", "win"],
	"laugh": ["laugh"], "cry": ["cry", "sad"], "point": ["point"], "attack": ["attack", "slash", "punch", "hit", "swing"],
	"fight": ["fight", "guard", "combat"], "talk": ["talk", "speak"], "hurt": ["hurt", "damage", "ouch"], "climb": ["climb"], "swim": ["swim", "paddle"],
}
const DIRS := {"down": "front", "front": "front", "south": "front", "up": "back", "back": "back", "north": "back",
	"left": "side", "right": "side", "side": "side", "east": "side", "west": "side"}
const FPS := 8.0

static var _tex := {}
static var _meta := {}


static func dir() -> String:
	return ModelRig.DIR.trim_suffix("/").get_base_dir().path_join("sprites") + "/"


static func is_key(key: String) -> bool:
	return key.begins_with(PREFIX)


static func id_of(key: String) -> String:
	return key.substr(PREFIX.length())


static func display_name(id: String) -> String:
	return id.get_basename().get_slice("~", 0).replace("-", " ").capitalize()


## Imported sprite ids of a kind ("char" or "object").
static func list(kind: String) -> Array:
	var out := []
	var d := DirAccess.open(dir())
	if d == null:
		return out
	for f in d.get_files():
		if f.get_extension() == "json" and str(meta(f.get_basename()).get("kind", "")) == kind:
			out.append(f.get_basename())
	out.sort()
	return out


static func meta(id: String) -> Dictionary:
	if _meta.has(id):
		return _meta[id]
	var p := dir() + id + ".json"
	if not FileAccess.file_exists(p):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	var m: Dictionary = d if d is Dictionary else {}
	_meta[id] = m
	return m


static func texture(id: String) -> ImageTexture:
	if _tex.has(id):
		return _tex[id]
	var p := dir() + id + ".png"
	if not FileAccess.file_exists(p):
		return null
	var img := Image.load_from_file(p)
	if img == null:
		return null
	var t := ImageTexture.create_from_image(img)
	_tex[id] = t
	return t


static func remove(id: String) -> void:
	for ext in [".png", ".json"]:
		if FileAccess.file_exists(dir() + id + ext):
			DirAccess.remove_absolute(dir() + id + ext)
	_tex.erase(id)
	_meta.erase(id)


# ---------------------------------------------------------------- import

## Imports a sprite file as "char" or "object"; returns its id, or "" with
## a reason in `last_error`.
static var last_error := ""


static func import_file(path: String, kind: String) -> String:
	last_error = ""
	var ext := path.get_extension().to_lower()
	var sheet: Dictionary
	if ext in ["ase", "aseprite"]:
		sheet = read_aseprite(path)
	elif ext in ["png", "webp"]:
		sheet = _read_picture(path)
	else:
		last_error = "Pixel sprites must be .png, .webp, .ase or .aseprite."
		return ""
	if sheet.is_empty():
		if last_error == "":
			last_error = "That sprite couldn’t be read."
		return ""
	var frames: Array = sheet["frames"]
	if kind == "object":
		frames = [frames[0]]
		sheet["anims"] = {"idle": [0]}
	var bytes := FileAccess.get_file_as_bytes(path)
	var id := U.slug(path.get_file().get_basename()) + "~%06x" % (hash(bytes.slice(0, mini(bytes.size(), 200000))) & 0xFFFFFF)
	var fw: int = (frames[0] as Image).get_width()
	var fh: int = (frames[0] as Image).get_height()
	var cols := mini(frames.size(), 8)
	var rows := ceili(float(frames.size()) / cols)
	var img := Image.create(fw * cols, fh * rows, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in frames.size():
		img.blit_rect(frames[i], Rect2i(0, 0, fw, fh), Vector2i((i % cols) * fw, (i / cols) * fh))
	DirAccess.make_dir_recursive_absolute(dir())
	if img.save_png(dir() + id + ".png") != OK:
		last_error = "Couldn’t save the sprite."
		return ""
	# How tall the art really is (empty rows at the top don't count).
	var used := (frames[0] as Image).get_used_rect()
	var m := {"kind": kind, "fw": fw, "fh": fh, "cols": cols, "rows": rows, "frames": frames.size(), "anims": sheet["anims"],
		"art_h": used.end.y if used.size.y > 0 else fh, "art_w": used.size.x if used.size.x > 0 else fw, "source": path.get_file()}
	var f := FileAccess.open(dir() + id + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(m))
	f.close()
	_meta.erase(id)
	_tex.erase(id)
	return id


## PNG/WebP: a strip, an RPG direction grid, or one picture.
static func _read_picture(path: String) -> Dictionary:
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return {}
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var frames := []
	var anims := {}
	if (w % 3 == 0 and h % 4 == 0 and w / 3 == h / 4) or (w % 4 == 0 and h % 4 == 0 and w / 4 == h / 4 and w != h * 4):
		# RPG grid: rows are down, left, right, up; columns are walk steps.
		var cols := 3 if w / 3 == h / 4 else 4
		var fw := w / cols
		var fh := h / 4
		for r in 4:
			for c in cols:
				frames.append(img.get_region(Rect2i(c * fw, r * fh, fw, fh)))
		var walk := [1, 0, 1, 2] if cols == 3 else [0, 1, 2, 3]
		var names := ["front", "side_left", "side", "back"]
		for r in 4:
			var seq := walk.map(func(c): return r * cols + c)
			if names[r] == "side_left":
				continue
			anims["walk:" + names[r]] = seq
			anims["idle:" + names[r]] = [r * cols + (1 if cols == 3 else 0)]
		anims["walk"] = anims["walk:side"]
		anims["idle"] = anims["idle:front"]
	elif w > h and w % h == 0:
		for k in w / h:
			frames.append(img.get_region(Rect2i(k * h, 0, h, h)))
		anims = {"idle": [0], "walk": range(frames.size())}
	elif h > w and h % w == 0:
		for k in h / w:
			frames.append(img.get_region(Rect2i(0, k * w, w, w)))
		anims = {"idle": [0], "walk": range(frames.size())}
	else:
		frames.append(img)
		anims = {"idle": [0]}
	return {"frames": frames, "anims": anims}


# ---------------------------------------------------------------- aseprite

## Reads an Aseprite file: {frames: [Image], anims: {state[:dir]: [i]}}.
## Layers are flattened (visible, normal layers with their opacity); tags
## become actions.
static func read_aseprite(path: String) -> Dictionary:
	var b := FileAccess.get_file_as_bytes(path)
	if b.size() < 128 or b.decode_u16(4) != 0xA5E0:
		last_error = "That isn’t an Aseprite file."
		return {}
	var n_frames := b.decode_u16(6)
	var w := b.decode_u16(8)
	var h := b.decode_u16(10)
	var depth := b.decode_u16(12)
	var transparent := b.decode_u8(28)
	if w == 0 or h == 0 or w > 1024 or h > 1024 or n_frames == 0 or n_frames > 512:
		last_error = "That sprite is too big (up to 1024 × 1024 px and 512 frames)."
		return {}
	var palette: Array = []
	palette.resize(256)
	palette.fill(Color(0, 0, 0, 1))
	var layers: Array = []  # {visible, opacity, group}
	var tags: Array = []    # [name, from, to]
	var cels: Array = []    # per frame: [{layer, x, y, opacity, img | link}]
	var pos := 128
	for fi in n_frames:
		var frame_bytes := b.decode_u32(pos)
		if b.decode_u16(pos + 4) != 0xF1FA:
			last_error = "That Aseprite file looks damaged."
			return {}
		var n_chunks := b.decode_u32(pos + 12)
		if n_chunks == 0:
			n_chunks = b.decode_u16(pos + 6)
		var cp := pos + 16
		var frame_cels := []
		for ci in n_chunks:
			var csize := b.decode_u32(cp)
			var ctype := b.decode_u16(cp + 4)
			var d := cp + 6
			match ctype:
				0x2004:
					var flags := b.decode_u16(d)
					var ltype := b.decode_u16(d + 2)
					var opacity := b.decode_u8(d + 12)
					layers.append({"visible": (flags & 1) != 0, "opacity": opacity / 255.0, "group": ltype == 1})
				0x2005:
					var cel := {"layer": b.decode_u16(d), "x": b.decode_s16(d + 2), "y": b.decode_s16(d + 4), "opacity": b.decode_u8(d + 6) / 255.0}
					var ctp := b.decode_u16(d + 7)
					var pd := d + 16
					if ctp == 1:
						cel["link"] = b.decode_u16(pd)
					elif ctp == 0 or ctp == 2:
						var cw := b.decode_u16(pd)
						var chh := b.decode_u16(pd + 2)
						var bpp := 4 if depth == 32 else (2 if depth == 16 else 1)
						var raw: PackedByteArray
						if ctp == 0:
							raw = b.slice(pd + 4, pd + 4 + cw * chh * bpp)
						else:
							raw = b.slice(pd + 4, cp + csize).decompress(cw * chh * bpp, FileAccess.COMPRESSION_DEFLATE)
						if raw.size() < cw * chh * bpp:
							last_error = "That Aseprite file has a cel that couldn’t be unpacked."
							return {}
						cel["img"] = _pixels(raw, cw, chh, depth, palette, transparent)
					if cel.has("img") or cel.has("link"):
						frame_cels.append(cel)
				0x2018:
					var nt := b.decode_u16(d)
					var tp := d + 10
					for ti in nt:
						var from := b.decode_u16(tp)
						var to := b.decode_u16(tp + 2)
						var name_len := b.decode_u16(tp + 17)
						var tname := b.slice(tp + 19, tp + 19 + name_len).get_string_from_utf8()
						tags.append([tname, from, to])
						tp += 19 + name_len
				0x2019:
					var first := b.decode_u32(d + 4)
					var last := b.decode_u32(d + 8)
					var ep := d + 20
					for k in range(first, last + 1):
						var eflags := b.decode_u16(ep)
						if k < 256:
							palette[k] = Color8(b[ep + 2], b[ep + 3], b[ep + 4], b[ep + 5])
						ep += 6
						if eflags & 1:
							ep += 2 + b.decode_u16(ep)
				0x0004, 0x0011:
					var packets := b.decode_u16(d)
					var pp := d + 2
					var k := 0
					for pk in packets:
						k += b[pp]
						var cnt: int = b[pp + 1]
						if cnt == 0:
							cnt = 256
						pp += 2
						for c in cnt:
							if k < 256:
								var mul := 4 if ctype == 0x0011 else 1
								palette[k] = Color8(mini(255, b[pp] * mul), mini(255, b[pp + 1] * mul), mini(255, b[pp + 2] * mul))
							k += 1
							pp += 3
			cp += csize
		cels.append(frame_cels)
		pos += frame_bytes
	# Flatten each frame.
	var frames := []
	for fi in n_frames:
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var list: Array = cels[fi].duplicate()
		list.sort_custom(func(x, y): return int(x["layer"]) < int(y["layer"]))
		for cel in list:
			var li: int = cel["layer"]
			if li >= layers.size() or not layers[li]["visible"] or layers[li]["group"]:
				continue
			var src: Variant = cel.get("img")
			if cel.has("link"):
				src = null
				var lf: int = cel["link"]
				if lf < cels.size():
					for c2 in cels[lf]:
						if int(c2["layer"]) == li and c2.has("img"):
							src = c2["img"]
							cel = c2.merged({"layer": li}, true)
			if src == null:
				continue
			_blend(img, src, int(cel["x"]), int(cel["y"]), float(cel["opacity"]) * float(layers[li]["opacity"]))
		frames.append(img)
	return {"frames": frames, "anims": _anims_from_tags(tags, n_frames)}


static func _pixels(raw: PackedByteArray, w: int, h: int, depth: int, palette: Array, transparent: int) -> Image:
	if depth == 32:
		return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, raw)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for i in w * h:
		var c: Color
		if depth == 16:
			var v := raw[i * 2] / 255.0
			c = Color(v, v, v, raw[i * 2 + 1] / 255.0)
		else:
			var pi: int = raw[i]
			c = Color(0, 0, 0, 0) if pi == transparent else palette[pi]
		img.set_pixel(i % w, i / w, c)
	return img


static func _blend(dst: Image, src: Image, ox: int, oy: int, opacity: float) -> void:
	for y in src.get_height():
		var dy := oy + y
		if dy < 0 or dy >= dst.get_height():
			continue
		for x in src.get_width():
			var dx := ox + x
			if dx < 0 or dx >= dst.get_width():
				continue
			var s := src.get_pixel(x, y)
			var a := s.a * opacity
			if a <= 0.0:
				continue
			var d := dst.get_pixel(dx, dy)
			var out_a := a + d.a * (1.0 - a)
			var rgb := (Color(s.r, s.g, s.b) * a + Color(d.r, d.g, d.b) * d.a * (1.0 - a)) / maxf(out_a, 1e-5)
			dst.set_pixel(dx, dy, Color(rgb.r, rgb.g, rgb.b, out_a))


## Tag names -> actions (and top-view directions).
static func _anims_from_tags(tags: Array, n: int) -> Dictionary:
	var anims := {}
	for t in tags:
		var lower := str(t[0]).to_lower().replace("-", "_").replace(" ", "_")
		var state := ""
		for s in STATES:
			for pat in STATES[s]:
				if lower.contains(pat):
					state = s
					break
			if state != "":
				break
		if state == "":
			continue
		var dir_name := ""
		for part in lower.split("_"):
			if DIRS.has(part):
				dir_name = DIRS[part]
		var seq := range(int(t[1]), mini(int(t[2]), n - 1) + 1)
		if dir_name != "":
			anims[state + ":" + dir_name] = seq
			if not anims.has(state):
				anims[state] = seq
		else:
			anims[state] = seq
	if anims.is_empty():
		anims["walk"] = range(n)
	if not anims.has("idle"):
		anims["idle"] = [(anims.get("walk", [0]) as Array)[0]]
	return anims


# ---------------------------------------------------------------- use

## Frame names from PixelSprites ("walk2", "cel0"...) -> states.
const NAME_STATE := {"cel": "celebrate", "atk": "attack", "guard": "fight", "tread": "swim"}


static func frame_index(m: Dictionary, name: String, facing: String, t: float) -> int:
	var anims: Dictionary = m["anims"]
	var base := name.rstrip("0123456789")
	var state: String = NAME_STATE.get(base, base)
	var tries := [state + ":" + facing, state]
	match state:
		"run":
			tries += ["walk:" + facing, "walk"]
		"attack":
			tries += ["fight"]
		"fight":
			tries += ["attack"]
		"swim":
			tries += ["walk:" + facing, "walk"]
		"celebrate":
			# Some dances clap and cheer: a sheet with only a dance keeps dancing.
			tries += ["dance"]
		"dance":
			tries += ["celebrate"]
	tries += ["idle:" + facing, "idle"]
	for k in tries:
		var seq: Array = anims.get(k, [])
		if not seq.is_empty():
			return int(seq[int(t * FPS) % seq.size()])
	return 0


static func build_char(id: String, view: String) -> Dictionary:
	var m := meta(id)
	var tex := texture(id)
	if m.is_empty() or tex == null:
		# Deleted file: a stand-in so scenes still open.
		return PixelSprites.build({"preset": "villager"}, view)
	var fw: int = m["fw"]
	var fh: int = m["fh"]
	var rig := PixelSprites.quad_rig(tex, Vector2i(int(m["cols"]), int(m["rows"])), Vector2(fw, fh) / PixelWorld.PPM, view)
	var h := maxf(0.4, float(m.get("art_h", fh)) / PixelWorld.PPM)
	rig.merge({"anims": m["anims"], "height": h, "headH": h * 0.85, "scale": 1.0, "creature": false, "imported": id})
	rig["root"].set_meta("frame_h", h)
	rig["root"].set_meta("head_h", h * 0.85)
	return rig


static func icon(id: String) -> Texture2D:
	var tex := texture(id)
	var m := meta(id)
	if tex == null or m.is_empty():
		return PixelSprites.icon({"preset": "villager"})
	var img := tex.get_image().get_region(Rect2i(0, 0, int(m["fw"]), int(m["fh"])))
	var s := maxi(img.get_width(), img.get_height())
	var k := maxi(1, 128 / s)
	img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## Imported objects for the top view: footprint from the sprite's width.
static func object_def(key: String) -> Dictionary:
	var m := meta(id_of(key))
	if m.is_empty():
		return {"name": "Missing sprite", "w": 16, "h": 16, "fw": 1, "fd": 1, "solid": false}
	return {"name": display_name(id_of(key)), "w": int(m["fw"]), "h": int(m["fh"]), "fw": maxi(1, ceili(float(m.get("art_w", m["fw"])) / PixelWorld.PPM)), "fd": 1, "solid": true}


static func object_texture(key: String) -> ImageTexture:
	return texture(id_of(key))
