class_name UIK
## UI kit: colour tokens, theme and small widget builders shared by the home
## screen, the studio HUD and the sheets. Dark "glass" over the 3D scene with
## the clapperboard-tape yellow accent from the web build.

const BG := Color("151C29")
const SURFACE := Color(0.118, 0.149, 0.212, 0.96)
const RAISE := Color("263147")
const RAISE_HI := Color("2f3c56")
const INK := Color("EDEFF4")
const MUTED := Color("9AA6BD")
const LINE := Color(0.93, 0.94, 0.96, 0.12)
const TAPE := Color("F2C14E")
const TAPE_INK := Color("1C2433")
const TAPE_SOFT := Color(0.95, 0.76, 0.31, 0.2)
const REC := Color("EF4444")
const GLASS := Color(0.063, 0.086, 0.133, 0.62)

static var font: Font
static var font_bold: Font
static var scale := 1.0


static func px(v: float) -> int:
	return int(round(v * scale))


static func make_theme() -> Theme:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Bricolage Grotesque", "Inter", "Noto Sans", "Segoe UI", "Roboto", "Helvetica Neue", "Arial", "sans-serif"])
	sf.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	sf.hinting = TextServer.HINTING_LIGHT
	sf.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	font = sf
	var sfb := SystemFont.new()
	sfb.font_names = sf.font_names
	sfb.font_weight = 700
	font_bold = sfb
	var t := Theme.new()
	t.default_font = sf
	t.default_font_size = px(15)
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", TAPE_INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_color", "TextEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_color("caret_color", "LineEdit", TAPE)
	t.set_color("selection_color", "LineEdit", TAPE_SOFT)
	t.set_color("font_color", "CheckButton", INK)
	t.set_color("font_hover_color", "CheckButton", INK)
	t.set_color("font_pressed_color", "CheckButton", INK)
	t.set_color("font_hover_pressed_color", "CheckButton", INK)
	t.set_color("font_color", "OptionButton", INK)
	t.set_stylebox("normal", "Button", box(RAISE, 12, LINE))
	t.set_stylebox("hover", "Button", box(RAISE_HI, 12, LINE))
	t.set_stylebox("pressed", "Button", box(TAPE, 12))
	t.set_stylebox("hover_pressed", "Button", box(TAPE, 12))
	t.set_stylebox("disabled", "Button", box(Color(RAISE, 0.5), 12))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 12, TAPE, 2))
	var le := box(RAISE, 12, LINE)
	le.content_margin_left = px(12)
	le.content_margin_right = px(12)
	le.content_margin_top = px(9)
	le.content_margin_bottom = px(9)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", box(RAISE, 12, TAPE, 2))
	t.set_stylebox("normal", "TextEdit", le)
	t.set_stylebox("focus", "TextEdit", box(RAISE, 12, TAPE, 2))
	t.set_stylebox("panel", "PanelContainer", box(SURFACE, 22, LINE))
	t.set_stylebox("panel", "Panel", box(SURFACE, 22, LINE))
	var tip := box(Color(0.06, 0.08, 0.12, 0.95), 10)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", INK)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(1, 1, 1, 0.18)
	grab.set_corner_radius_all(4)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	t.set_stylebox("scroll", "HScrollBar", StyleBoxEmpty.new())
	t.set_stylebox("grabber", "HScrollBar", grab)
	var sl := StyleBoxFlat.new()
	sl.bg_color = Color(1, 1, 1, 0.14)
	sl.set_corner_radius_all(4)
	sl.content_margin_top = 3
	sl.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", sl)
	var sla := StyleBoxFlat.new()
	sla.bg_color = TAPE
	sla.set_corner_radius_all(4)
	sla.content_margin_top = 3
	sla.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", sla)
	t.set_stylebox("grabber_area_highlight", "HSlider", sla)
	t.set_icon("grabber", "HSlider", _dot(px(18), TAPE))
	t.set_icon("grabber_highlight", "HSlider", _dot(px(20), TAPE))
	t.set_color("font_color", "ProgressBar", INK)
	t.set_stylebox("background", "ProgressBar", box(Color(1, 1, 1, 0.12), 6))
	t.set_stylebox("fill", "ProgressBar", box(TAPE, 6))
	t.set_stylebox("panel", "PopupMenu", box(SURFACE, 12, LINE))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", TAPE_INK)
	t.set_stylebox("hover", "PopupMenu", box(TAPE, 8))
	t.set_stylebox("normal", "OptionButton", box(RAISE, 12, LINE))
	t.set_stylebox("hover", "OptionButton", box(RAISE_HI, 12, LINE))
	t.set_stylebox("pressed", "OptionButton", box(RAISE_HI, 12, LINE))
	return t


static func _dot(d: int, c: Color) -> Texture2D:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d / 2.0
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - dist, 0, 1)
			var col := c if dist < r - 2.5 else Color.WHITE
			col.a = a
			img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


static func box(c: Color, radius := 12, border := Color(0, 0, 0, 0), bw := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(px(radius))
	s.content_margin_left = px(12)
	s.content_margin_right = px(12)
	s.content_margin_top = px(8)
	s.content_margin_bottom = px(8)
	if border.a > 0:
		s.set_border_width_all(bw)
		s.border_color = border
	s.anti_aliasing = true
	return s


static func glass(radius := 16) -> StyleBoxFlat:
	var s := box(GLASS, radius, Color(1, 1, 1, 0.14))
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = px(8)
	return s


static func label(text: String, size := 15, color := INK, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", px(size))
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font_bold)
	return l


static func para(text: String, size := 13, color := MUTED) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = px(120)
	return l


static func section(text: String) -> Label:
	var l := label(text, 13, MUTED, true)
	l.add_theme_constant_override("line_spacing", 0)
	var m := MarginContainer.new()
	return l


static func vbox(sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", px(sep))
	return v


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", px(sep))
	return h


static func flow(sep := 6) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", px(sep))
	f.add_theme_constant_override("v_separation", px(sep))
	return f


static func grid(cols: int, sep := 8) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", px(sep))
	g.add_theme_constant_override("v_separation", px(sep))
	return g


static func btn(text: String, cb: Callable, primary := false, icon := "") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font_bold)
	b.add_theme_font_size_override("font_size", px(14))
	b.custom_minimum_size.y = px(42)
	if icon != "":
		b.icon = Icons.tex(icon, px(20), TAPE_INK if primary else INK)
	if primary:
		b.add_theme_stylebox_override("normal", box(TAPE, 12))
		b.add_theme_stylebox_override("hover", box(TAPE.lightened(0.1), 12))
		b.add_theme_color_override("font_color", TAPE_INK)
		b.add_theme_color_override("font_hover_color", TAPE_INK)
	b.pressed.connect(cb)
	return b


static func danger(text: String, cb: Callable) -> Button:
	var b := btn(text, cb)
	b.add_theme_color_override("font_color", REC)
	b.add_theme_color_override("font_hover_color", REC)
	return b


static func icon_btn(icon: String, cb: Callable, tip := "", size := 46, glass_bg := true) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.icon = Icons.tex(icon, px(22), Color.WHITE if glass_bg else INK)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = false
	b.custom_minimum_size = Vector2(px(size), px(size))
	b.tooltip_text = tip
	if glass_bg:
		b.add_theme_stylebox_override("normal", glass(14))
		var h := glass(14)
		h.bg_color = Color(0.1, 0.13, 0.2, 0.78)
		b.add_theme_stylebox_override("hover", h)
		b.add_theme_stylebox_override("pressed", box(Color(TAPE, 0.55), 14))
	b.pressed.connect(cb)
	return b


## Selectable chip; `on` draws it in the accent colour.
static func chip(text: String, on: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font_bold)
	b.add_theme_font_size_override("font_size", px(14))
	b.custom_minimum_size.y = px(38)
	var n := box(RAISE, 12, LINE)
	n.content_margin_left = px(13)
	n.content_margin_right = px(13)
	var a := box(TAPE, 12)
	a.content_margin_left = px(13)
	a.content_margin_right = px(13)
	b.add_theme_stylebox_override("normal", a if on else n)
	b.add_theme_stylebox_override("hover", a if on else box(RAISE_HI, 12, LINE))
	b.add_theme_stylebox_override("pressed", a)
	if on:
		b.add_theme_color_override("font_color", TAPE_INK)
		b.add_theme_color_override("font_hover_color", TAPE_INK)
	b.pressed.connect(cb)
	return b


## Big tile with icon, title and subtitle.
static func tile(icon: String, title: String, sub: String, on: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(px(140), px(100))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := box(RAISE, 18, TAPE.darkened(0.2) if on else LINE, 2 if on else 1)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", box(RAISE_HI, 18, TAPE.darkened(0.2) if on else LINE, 2 if on else 1))
	b.add_theme_stylebox_override("pressed", box(RAISE_HI, 18, TAPE, 2))
	var v := vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = px(14)
	v.offset_top = px(12)
	v.offset_right = -px(10)
	v.offset_bottom = -px(10)
	var ic := PanelContainer.new()
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icb := box(TAPE if on else TAPE_SOFT, 12)
	icb.content_margin_left = px(9)
	icb.content_margin_right = px(9)
	icb.content_margin_top = px(9)
	icb.content_margin_bottom = px(9)
	ic.add_theme_stylebox_override("panel", icb)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var tr := TextureRect.new()
	tr.texture = Icons.tex(icon, px(22), TAPE_INK if on else INK)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.add_child(tr)
	v.add_child(ic)
	var tl := label(title, 16, INK, true)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tl)
	if sub != "":
		var sl := label(sub, 12, MUTED)
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(sl)
	b.add_child(v)
	b.pressed.connect(cb)
	return b


## Picker cell with a thumbnail texture and caption.
static func pick(tex: Texture2D, caption: String, on: bool, cb: Callable, pixel := false, size := 86) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(px(size), px(size + 22))
	b.tooltip_text = caption
	b.add_theme_stylebox_override("normal", box(RAISE, 16, TAPE.darkened(0.2) if on else LINE, 2 if on else 1))
	b.add_theme_stylebox_override("hover", box(RAISE_HI, 16, TAPE.darkened(0.2) if on else LINE, 2 if on else 1))
	b.add_theme_stylebox_override("pressed", box(RAISE_HI, 16, TAPE, 2))
	var v := vbox(3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_top = px(8)
	v.offset_bottom = -px(6)
	v.offset_left = px(4)
	v.offset_right = -px(4)
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(px(size - 30), px(size - 30))
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if pixel:
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	v.add_child(tr)
	var l := label(caption, 12, INK, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size.x = px(size - 10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	b.add_child(v)
	b.pressed.connect(cb)
	return b


## Labelled slider; `fmt` formats the value shown on the right.
static func slider(title: String, value: float, lo: float, hi: float, step: float, cb: Callable, fmt := Callable()) -> Control:
	var v := vbox(2)
	var h := hbox()
	var l := label(title, 13, MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var val := label("", 13, INK, true)
	h.add_child(val)
	v.add_child(h)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size.y = px(28)
	var show := func(x: float) -> void:
		val.text = fmt.call(x) if fmt.is_valid() else (str(int(x)) if step >= 1 else "%.1f" % x)
	show.call(value)
	s.value_changed.connect(func(x: float) -> void:
		show.call(x)
		cb.call(x))
	v.add_child(s)
	return v


static func toggle(title: String, on: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = title
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", px(15))
	c.toggled.connect(cb)
	return c


static func line_edit(text: String, placeholder: String, cb: Callable) -> LineEdit:
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = placeholder
	e.custom_minimum_size.y = px(42)
	e.text_changed.connect(cb)
	return e


static func spacer(h := 8) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = px(h)
	return c


static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
