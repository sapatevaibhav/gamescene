class_name U
## Small shared helpers: seeded random numbers, colour maths and angle helpers.
## Ported 1:1 from the web build so procedural content (worlds, props, skins)
## stays identical for the same seed.


## Mulberry32 generator, identical to the JS `rng(seed)` so seeds reproduce the
## same layouts. Call `next()` for a float in [0, 1).
class Rng:
	var a: int

	func _init(seed: int) -> void:
		a = seed & 0xFFFFFFFF

	func next() -> float:
		a = (a + 0x6D2B79F5) & 0xFFFFFFFF
		var t: int = _imul(a ^ (a >> 15), 1 | a)
		t = ((t + _imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t
		t &= 0xFFFFFFFF
		return float((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296.0

	func range_f(lo: float, hi: float) -> float:
		return lo + next() * (hi - lo)

	func range_i(lo: int, hi_exclusive: int) -> int:
		return lo + int(next() * float(hi_exclusive - lo))

	func pick(arr: Array) -> Variant:
		if arr.is_empty():
			return null
		return arr[int(next() * arr.size()) % arr.size()]

	static func _imul(x: int, y: int) -> int:
		return ((x & 0xFFFFFFFF) * (y & 0xFFFFFFFF)) & 0xFFFFFFFF


static func rng(seed: int) -> Rng:
	return Rng.new(seed)


## Shared non-deterministic picker for UI-driven choices (names, random looks).
static func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[randi() % arr.size()]


## Returns `v` with probability `p`, otherwise null (for optional random look parts).
static func maybe(v: Variant, p: float) -> Variant:
	if randf() < p:
		return v
	return null


static func col(hex: String) -> Color:
	if hex.is_empty():
		return Color.WHITE
	if hex.begins_with("rgba") or hex.begins_with("rgb"):
		var inner := hex.substr(hex.find("(") + 1).trim_suffix(")")
		var p := inner.split(",")
		var c := Color(float(p[0]) / 255.0, float(p[1]) / 255.0, float(p[2]) / 255.0, 1.0)
		if p.size() > 3:
			c.a = float(p[3])
		return c
	return Color.html(hex)


## Multiply a colour's RGB by `f` (the JS `shadeHex`).
static func shade_hex(hex: String, f: float) -> String:
	var c := col(hex)
	return "#" + Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1)).to_html(false)


static func shade(c: Color, f: float) -> Color:
	return Color(clampf(c.r * f, 0, 1), clampf(c.g * f, 0, 1), clampf(c.b * f, 0, 1), c.a)


static func wrap_a(a: float) -> float:
	return wrapf(a, -PI, PI)


static func ease_io(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


static func damp(current: Variant, target: Variant, rate: float, dt: float) -> Variant:
	return lerp(current, target, 1.0 - exp(-rate * dt))


static func fmt_time(s: float) -> String:
	var n := int(floor(s))
	return "%d:%02d" % [n / 60, n % 60]


static func slug(s: String) -> String:
	var out := ""
	for ch in s.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif not out.ends_with("-"):
			out += "-"
	out = out.trim_prefix("-").trim_suffix("-")
	return out if out != "" else "scene"


## Base-36 run-length encoding, compatible with the web build's saves.
static func rle_encode(a: PackedByteArray) -> String:
	if a.is_empty():
		return ""
	var out := PackedStringArray()
	var v := a[0]
	var n := 0
	for i in a.size():
		if a[i] == v:
			n += 1
		else:
			out.append(to36(v) + "*" + to36(n))
			v = a[i]
			n = 1
	out.append(to36(v) + "*" + to36(n))
	return ",".join(out)


static func rle_decode(s: String, length: int) -> PackedByteArray:
	var a := PackedByteArray()
	a.resize(length)
	var i := 0
	if s.is_empty():
		return a
	for part in s.split(","):
		var kv := part.split("*")
		if kv.size() < 2:
			continue
		var v := from36(kv[0])
		var n := from36(kv[1])
		for k in n:
			if i >= length:
				break
			a[i] = v
			i += 1
	return a


static func to36(n: int) -> String:
	if n == 0:
		return "0"
	const D := "0123456789abcdefghijklmnopqrstuvwxyz"
	var s := ""
	while n > 0:
		s = D[n % 36] + s
		n /= 36
	return s


static func from36(s: String) -> int:
	const D := "0123456789abcdefghijklmnopqrstuvwxyz"
	var n := 0
	for ch in s.to_lower():
		n = n * 36 + D.find(ch)
	return n


static func r2(v: float) -> float:
	return snappedf(v, 0.01)


## Decodes `data:image/png;base64,...` or raw base64 into an Image.
static func image_from_data_url(src: String) -> Image:
	var b64 := src
	var comma := src.find(",")
	if src.begins_with("data:") and comma >= 0:
		b64 = src.substr(comma + 1)
	if b64.length() < 8:
		return null
	var buf := Marshalls.base64_to_raw(b64)
	if buf.is_empty():
		return null
	var img := Image.new()
	if img.load_png_from_buffer(buf) != OK:
		if img.load_jpg_from_buffer(buf) != OK:
			if img.load_webp_from_buffer(buf) != OK:
				return null
	return img


static func image_to_data_url(img: Image) -> String:
	return "data:image/png;base64," + Marshalls.raw_to_base64(img.save_png_to_buffer())
