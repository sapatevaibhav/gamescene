class_name Home
extends Control
## Home screen: pick a style to start a new scene, or reopen a saved one.

signal new_scene(style: String)
signal open_project(id: String)

var icons: IconStudio
var hud_ask: Callable
var _col := VBoxContainer.new()
var _cards := GridContainer.new()
var _recent := HFlowContainer.new()
var _scroll := ScrollContainer.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UIK.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var center := MarginContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(center)
	_col.add_theme_constant_override("separation", UIK.px(12))
	_col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.add_child(_col)
	get_viewport().size_changed.connect(_layout)
	refresh()


func _layout() -> void:
	var w := get_viewport_rect().size.x
	var inner := minf(w - UIK.px(40), UIK.px(1080))
	_col.custom_minimum_size.x = inner
	var m: MarginContainer = _scroll.get_child(0)
	m.add_theme_constant_override("margin_top", UIK.px(22))
	m.add_theme_constant_override("margin_bottom", UIK.px(36))
	_cards.columns = 4 if w >= UIK.px(900) else 2


func refresh() -> void:
	UIK.clear(_col)
	var top := UIK.hbox(10)
	var mark := TextureRect.new()
	mark.texture = load("res://icon.svg")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.custom_minimum_size = Vector2(UIK.px(30), UIK.px(30))
	top.add_child(mark)
	top.add_child(UIK.label("GameScene", 18, UIK.INK, true))
	top.add_child(UIK.label("Studio", 18, UIK.MUTED))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(UIK.label("Offline · v" + str(ProjectSettings.get_setting("application/config/version")), 13, UIK.MUTED))
	_col.add_child(top)
	_col.add_child(UIK.spacer(18))
	var h1 := UIK.label("What are you making?", 52, UIK.INK, true)
	h1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_col.add_child(h1)
	_col.add_child(UIK.spacer(6))
	_cards = UIK.grid(4, 16)
	for k in Styles.STYLE_ORDER:
		_cards.add_child(_style_card(k))
	_col.add_child(_cards)
	_col.add_child(UIK.spacer(18))
	var rh := UIK.hbox()
	var t := UIK.label("Your scenes", 20, UIK.INK, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rh.add_child(t)
	var open := UIK.btn("Open a file", func(): _open_file(), false, "folder")
	rh.add_child(open)
	_col.add_child(rh)
	_recent = UIK.flow(12)
	var idx := ProjectStore.index()
	if idx.is_empty():
		_col.add_child(UIK.para("Nothing yet. Pick a style above to build your first scene.", 14))
	for p in idx:
		_recent.add_child(_recent_tile(p))
	_col.add_child(_recent)
	_layout()


func _style_card(k: String) -> Control:
	var sty: Dictionary = Styles.STYLES[k]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(UIK.px(150), UIK.px(260))
	b.add_theme_stylebox_override("normal", UIK.box(UIK.RAISE, 20, UIK.LINE))
	b.add_theme_stylebox_override("hover", UIK.box(UIK.RAISE_HI, 20, UIK.TAPE, 2))
	b.add_theme_stylebox_override("pressed", UIK.box(UIK.RAISE_HI, 20, UIK.TAPE, 2))
	var v := UIK.vbox(2)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ph := Panel.new()
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ph.clip_contents = true
	var sb := StyleBoxTexture.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, U.col(sty["swatch"][0]))
	g.set_color(1, U.col(sty["swatch"][1]))
	gt.gradient = g
	gt.fill_from = Vector2(0.2, 0)
	gt.fill_to = Vector2(0.8, 1)
	sb.texture = gt
	ph.add_theme_stylebox_override("panel", sb)
	var tr := TextureRect.new()
	var cast: Array = Rigs.DEFAULT_CAST.get(k, [])
	var preset: String = cast[0][0] if not cast.is_empty() else ""
	tr.texture = icons.request("home|" + k, func(): return Rigs.build({"preset": preset}, k)["root"], "char")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(tr)
	v.add_child(ph)
	var cap := MarginContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		cap.add_theme_constant_override("margin_" + side, UIK.px(12))
	var cv := UIK.vbox(2)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := UIK.label(sty["name"], 17, UIK.INK, true)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(n)
	var bl := UIK.label(sty["blurb"], 13, UIK.MUTED)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(bl)
	cap.add_child(cv)
	v.add_child(cap)
	b.add_child(v)
	b.pressed.connect(func(): new_scene.emit(k))
	return b


func _recent_tile(p: Dictionary) -> Control:
	var id: String = p["id"]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(UIK.px(190), UIK.px(176))
	b.add_theme_stylebox_override("normal", UIK.box(UIK.RAISE, 16, UIK.LINE))
	b.add_theme_stylebox_override("hover", UIK.box(UIK.RAISE_HI, 16, UIK.TAPE, 2))
	var v := UIK.vbox(2)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := TextureRect.new()
	tr.texture = ProjectStore.thumb(id)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.custom_minimum_size.y = UIK.px(116)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tr.texture == null:
		tr.texture = Icons.tex("film", 64, UIK.MUTED)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	v.add_child(tr)
	var cap := MarginContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_theme_constant_override("margin_left", UIK.px(10))
	cap.add_theme_constant_override("margin_right", UIK.px(10))
	var cv := UIK.vbox(0)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := UIK.label(p.get("name", "Scene"), 14, UIK.INK, true)
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.custom_minimum_size.x = UIK.px(150)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(n)
	var when := Time.get_datetime_string_from_unix_time(int(p.get("updated", 0))).replace("T", " ").left(16)
	var s := UIK.label(Styles.get_style(p.get("style", "blocky"))["name"] + " · " + when, 12, UIK.MUTED)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(s)
	cap.add_child(cv)
	v.add_child(cap)
	b.add_child(v)
	var more := MenuButton.new()
	more.icon = Icons.tex("more", UIK.px(20), Color.WHITE)
	more.flat = false
	more.add_theme_stylebox_override("normal", UIK.glass(10))
	more.position = Vector2(UIK.px(146), UIK.px(6))
	more.custom_minimum_size = Vector2(UIK.px(36), UIK.px(32))
	var pm := more.get_popup()
	pm.add_item("Rename", 0)
	pm.add_item("Duplicate", 1)
	pm.add_item("Export file", 2)
	pm.add_item("Delete", 3)
	pm.id_pressed.connect(func(item: int): _tile_action(id, p, item))
	b.add_child(more)
	b.pressed.connect(func(): open_project.emit(id))
	return b


func _tile_action(id: String, p: Dictionary, item: int) -> void:
	var hud: Hud = get_parent().get_node("Hud")
	match item:
		0:
			_rename(id, p)
		1:
			ProjectStore.duplicate_project(id)
			refresh()
		2:
			hud.save_file(U.slug(p.get("name", "scene")) + ".gamescene.json", PackedStringArray(["*.json ; GameScene project"]), func(path: String):
				if ProjectStore.export_to(id, path):
					App.toast("Exported " + path.get_file())
				else:
					App.toast("Couldn’t write that file."))
		3:
			hud.ask("Delete “%s”? This can’t be undone." % p.get("name", "Scene"), "Delete", func():
				ProjectStore.delete(id)
				refresh())


func _rename(id: String, p: Dictionary) -> void:
	var hud: Hud = get_parent().get_node("Hud")
	UIK.clear(hud.modal)
	var card := hud._card()
	var v: VBoxContainer = card.get_child(0)
	v.add_child(UIK.label("Rename scene", 20, UIK.INK, true))
	var e := UIK.line_edit(p.get("name", ""), "Scene name", func(_t): pass)
	v.add_child(e)
	var row := UIK.hbox()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UIK.btn("Cancel", func(): UIK.clear(hud.modal)))
	row.add_child(UIK.btn("Save", func():
		var n := e.text.strip_edges()
		if n != "":
			ProjectStore.rename(id, n.left(40))
		UIK.clear(hud.modal)
		refresh(), true))
	v.add_child(row)
	hud.modal.add_child(card)
	hud._center(card)
	e.grab_focus()
	e.select_all()


func _open_file() -> void:
	var hud: Hud = get_parent().get_node("Hud")
	hud.pick_file(PackedStringArray(["*.json ; GameScene project"]), func(path: String):
		var id := ProjectStore.import_from(path)
		if id.begins_with("!"):
			App.toast(id.substr(1))
			return
		refresh()
		open_project.emit(id), "Open a scene")
