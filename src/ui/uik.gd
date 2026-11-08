class_name UIK
## UI kit: colour tokens, theme and small widget builders shared by the home
## screen, the studio HUD and the sheets. Dark "glass" over the 3D scene with
## the clapperboard-tape yellow accent from the web build.

# ---- Design tokens -----------------------------------------------------
# One palette for the whole app (like --primary / --secondary / --gray in CSS).
# Primary: clapperboard amber. Secondary: sky blue. Grays: cool slate.
const PRIMARY_100 := Color("FDEFC7")
const PRIMARY_300 := Color("F7D77F")
const PRIMARY_500 := Color("F2C14E")
const PRIMARY_700 := Color("B8860F")
const SECONDARY_100 := Color("D3ECFA")
const SECONDARY_300 := Color("86C8EE")
const SECONDARY_500 := Color("3D9BDA")
const SECONDARY_700 := Color("1F6A9E")
const GRAY_50 := Color("F3F5F9")
const GRAY_100 := Color("E2E6EE")
const GRAY_200 := Color("C2C9D6")
const GRAY_300 := Color("9AA6BD")
const GRAY_400 := Color("6F7B92")
const GRAY_500 := Color("4C576D")
const GRAY_600 := Color("3A4459")
const GRAY_700 := Color("2C3548")
const GRAY_800 := Color("212939")
const GRAY_900 := Color("171E2B")
const GRAY_950 := Color("10151F")
const DANGER := Color("E5484D")

# Semantic aliases used by the widgets (all built from the tokens above).
const BG := GRAY_900
const SURFACE := Color(GRAY_800, 0.98)
const RAISE := GRAY_700
const RAISE_HI := GRAY_600
const INK := GRAY_50
const MUTED := GRAY_300
const LINE := GRAY_600
const TAPE := PRIMARY_500
const TAPE_INK := GRAY_950
const TAPE_SOFT := Color(PRIMARY_500, 0.22)
const REC := DANGER
const GLASS := Color(GRAY_900, 0.82)

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
	t.set_stylebox("normal", "Button", raised(GRAY_600, 12, GRAY_950, 2))
	t.set_stylebox("hover", "Button", raised(GRAY_500, 12, GRAY_950, 3))
	t.set_stylebox("pressed", "Button", raised(PRIMARY_500, 12, PRIMARY_700, 0))
	t.set_stylebox("hover_pressed", "Button", raised(PRIMARY_500, 12, PRIMARY_700, 0))
	t.set_stylebox("disabled", "Button", box(Color(RAISE, 0.5), 12))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
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
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var cb := box(Color(0, 0, 0, 0), 12)
		if st in ["hover", "hover_pressed"]:
			cb.bg_color = Color(1, 1, 1, 0.05)
		t.set_stylebox(st, "CheckButton", cb)
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
	# The UI font sits high in its line box; 2 px more on top centres text.
	s.content_margin_top = px(9)
	s.content_margin_bottom = px(7)
	if border.a > 0:
		s.set_border_width_all(bw)
		s.border_color = border
	s.anti_aliasing = true
	s.anti_aliasing_size = 0.5
	s.corner_detail = 12
	return s


## Raised look: a darker bottom edge makes the control sit up off the page.
static func raised(c: Color, radius := 12, edge := GRAY_950, lift := 2) -> StyleBoxFlat:
	var s := box(c, radius, edge, 1)
	s.border_width_bottom = px(lift) + 1
	s.content_margin_bottom = px(7) - px(lift) + 1 + px(lift)
	return s


## Applies the shared button states. Resting looks like a soft hover; on
## hover it lifts slightly (lighter, taller bottom edge); pressed/selected
## uses the primary colour. variant: neutral | primary | danger | selected | ghost.
static func style_button(b: BaseButton, variant := "neutral", radius := 12) -> void:
	var rest: StyleBoxFlat
	var lift: StyleBoxFlat
	var press := raised(PRIMARY_500, radius, PRIMARY_700, 0)
	match variant:
		"primary":
			rest = raised(PRIMARY_500, radius, PRIMARY_700, 2)
			lift = raised(PRIMARY_300, radius, PRIMARY_700, 3)
			press = raised(PRIMARY_700, radius, PRIMARY_700, 0)
		"selected":
			rest = raised(PRIMARY_500, radius, PRIMARY_700, 2)
			lift = raised(PRIMARY_300, radius, PRIMARY_700, 3)
		"ghost":
			rest = box(Color(0, 0, 0, 0), radius)
			lift = box(Color(1, 1, 1, 0.1), radius)
		_:
			rest = raised(GRAY_600, radius, GRAY_950, 2)
			lift = raised(GRAY_500, radius, GRAY_950, 3)
	b.add_theme_stylebox_override("normal", rest)
	b.add_theme_stylebox_override("hover", lift)
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_stylebox_override("hover_pressed", press)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", box(Color(GRAY_700, 0.6), radius))
	var ink := TAPE_INK if variant in ["primary", "selected"] else INK
	if variant == "danger":
		ink = DANGER
	for k in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(k, ink)
	b.add_theme_color_override("font_pressed_color", TAPE_INK)
	b.add_theme_color_override("font_hover_pressed_color", TAPE_INK)
	b.add_theme_color_override("font_disabled_color", GRAY_400)


## Card-like buttons (tiles, picker cells): raised, with a primary outline
## when selected.
static func _card_states(b: BaseButton, on: bool, radius: int) -> void:
	var edge := PRIMARY_500 if on else GRAY_950
	var rest := raised(GRAY_700 if not on else GRAY_600, radius, edge, 2)
	var lift := raised(GRAY_600, radius, edge, 3)
	if on:
		rest.set_border_width_all(2)
		rest.border_width_bottom = px(3) + 1
		lift.set_border_width_all(2)
		lift.border_width_bottom = px(4) + 1
	b.add_theme_stylebox_override("normal", rest)
	b.add_theme_stylebox_override("hover", lift)
	b.add_theme_stylebox_override("pressed", raised(GRAY_600, radius, PRIMARY_500, 0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func glass(radius := 16) -> StyleBoxFlat:
	return box(GLASS, radius, GRAY_600, 1)


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


## Grid whose column count follows its width; cells stretch so rows fill edge to edge.
static func pick_grid(sep := 8, min_cell := 80) -> GridContainer:
	var g := grid(1, sep)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var relayout := func():
		var cols := maxi(1, int((g.size.x + px(sep)) / (px(min_cell) + px(sep))))
		if g.columns != cols:
			g.columns = cols
	g.resized.connect(relayout)
	g.child_entered_tree.connect(func(c: Node):
		if c is Control:
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			c.custom_minimum_size.x = px(min_cell))
	return g


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
	style_button(b, "primary" if primary else "neutral")
	b.pressed.connect(cb)
	return b


static func danger(text: String, cb: Callable) -> Button:
	var b := btn(text, cb)
	style_button(b, "danger")
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
		var g := glass(14)
		var gh := glass(14)
		gh.bg_color = Color(GRAY_700, 0.92)
		gh.border_color = GRAY_400
		b.add_theme_stylebox_override("normal", g)
		b.add_theme_stylebox_override("hover", gh)
		b.add_theme_stylebox_override("pressed", box(Color(PRIMARY_500, 0.6), 14, PRIMARY_300, 1))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	else:
		style_button(b, "neutral")
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
	style_button(b, "selected" if on else "neutral")
	b.pressed.connect(cb)
	return b


## Big tile with icon, title and subtitle.
static func tile(icon: String, title: String, sub: String, on: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(px(140), px(118))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_states(b, on, 18)
	var v := vbox(4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_card_states(b, on, 16)
	var v := vbox(3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
