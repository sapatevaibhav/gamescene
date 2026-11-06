class_name Painter
## Tiny anti-aliased 2D painter on Images, standing in for the web build's
## canvas calls (fillRect, ellipse, arc strokes, gradients) used for skins
## and face decals.


static func new_img(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)


## Paints `c` over the pixel with extra coverage `a` (source-over).
static func over(img: Image, x: int, y: int, c: Color, a := 1.0) -> void:
	if a <= 0.0 or x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var src := Color(c.r, c.g, c.b, c.a * clampf(a, 0.0, 1.0))
	if src.a >= 0.999:
		img.set_pixel(x, y, src)
	else:
		img.set_pixel(x, y, img.get_pixel(x, y).blend(src))


## Canvas fillRect: replaces when opaque, blends when translucent.
static func rect(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	var x0 := maxi(0, x)
	var y0 := maxi(0, y)
	var x1 := mini(img.get_width(), x + w)
	var y1 := mini(img.get_height(), y + h)
	if x1 <= x0 or y1 <= y0:
		return
	if c.a >= 0.999:
		img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), c)
		return
	for yy in range(y0, y1):
		for xx in range(x0, x1):
			over(img, xx, yy, c)


## Per-pixel brightness noise, identical to the JS `speckle`.
static func speckle(img: Image, hex: String, vari: float, seed: int, x0 := 0, y0 := 0, w := 16, h := 16) -> void:
	var r := U.rng(seed)
	var c := U.col(hex)
	var R := int(round(c.r * 255.0))
	var G := int(round(c.g * 255.0))
	var B := int(round(c.b * 255.0))
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			var n := 1.0 + (r.next() - 0.5) * 2.0 * vari
			if x < img.get_width() and y < img.get_height() and x >= 0 and y >= 0:
				img.set_pixel(x, y, Color8(clampi(int(R * n), 0, 255), clampi(int(G * n), 0, 255), clampi(int(B * n), 0, 255)))


## Filled ellipse. `grad` = [y_top, y_bottom, [[t, Color], ...]] for a
## vertical linear gradient (canvas createLinearGradient on the Y axis).
static func ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color, rot := 0.0, grad := []) -> void:
	var R := maxf(rx, ry) + 1.5
	var cr := cos(rot)
	var sr := sin(rot)
	var mn := minf(rx, ry)
	for y in range(int(floor(cy - R)), int(ceil(cy + R)) + 1):
		for x in range(int(floor(cx - R)), int(ceil(cx + R)) + 1):
			var px := x + 0.5 - cx
			var py := y + 0.5 - cy
			var lx := px * cr + py * sr
			var ly := -px * sr + py * cr
			var d := sqrt((lx / rx) * (lx / rx) + (ly / ry) * (ly / ry))
			var a := clampf(0.5 - (d - 1.0) * mn, 0.0, 1.0)
			if a <= 0.0:
				continue
			var col := c
			if not grad.is_empty():
				col = gradient_at(grad[2], (y + 0.5 - float(grad[0])) / (float(grad[1]) - float(grad[0])))
			over(img, x, y, col, a)


static func circle(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	ellipse(img, cx, cy, r, r, c)


static func gradient_at(stops: Array, t: float) -> Color:
	t = clampf(t, 0.0, 1.0)
	if t <= float(stops[0][0]):
		return stops[0][1]
	for i in range(1, stops.size()):
		var t0: float = stops[i - 1][0]
		var t1: float = stops[i][0]
		if t <= t1:
			return (stops[i - 1][1] as Color).lerp(stops[i][1], (t - t0) / maxf(0.0001, t1 - t0))
	return stops[stops.size() - 1][1]


## Round-capped stroke along a polyline of Vector2 points.
static func stroke(img: Image, pts: PackedVector2Array, width: float, c: Color) -> void:
	if pts.size() < 2:
		return
	var hw := width * 0.5
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	for y in range(int(floor(lo.y - hw - 1)), int(ceil(hi.y + hw + 1)) + 1):
		for x in range(int(floor(lo.x - hw - 1)), int(ceil(hi.x + hw + 1)) + 1):
			var q := Vector2(x + 0.5, y + 0.5)
			var dmin := 1e9
			for i in range(pts.size() - 1):
				var cp := Geometry2D.get_closest_point_to_segment(q, pts[i], pts[i + 1])
				dmin = minf(dmin, q.distance_to(cp))
			over(img, x, y, c, clampf(hw - dmin + 0.5, 0.0, 1.0))


static func arc_pts(cx: float, cy: float, rx: float, ry: float, a0: float, a1: float, n := 32) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var t := lerpf(a0, a1, float(i) / n)
		out.append(Vector2(cx + rx * cos(t), cy + ry * sin(t)))
	return out


static func quad_pts(p0: Vector2, c: Vector2, p1: Vector2, n := 24) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		out.append(p0 * (1.0 - t) * (1.0 - t) + c * 2.0 * (1.0 - t) * t + p1 * t * t)
	return out


## Radial gradient over the whole image (blush).
static func radial(img: Image, cx: float, cy: float, r0: float, r1: float, stops: Array) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			over(img, x, y, gradient_at(stops, (d - r0) / (r1 - r0)))


static func tex(img: Image, mipmaps := true) -> ImageTexture:
	if mipmaps:
		img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
