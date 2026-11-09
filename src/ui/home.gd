class_name Home
extends Control
## Home screen: pick a style to start a new scene, or reopen a saved one.

signal new_scene(style: String)
signal open_project(id: String)

var icons: IconStudio
var hud_ask: Callable
var _col := VBoxContainer.new()
var _cards := GridContainer.new()
var _recent := GridContainer.new()
var _scroll := ScrollContainer.new()
## Multi-select mode for bulk actions on saved scenes.
var _selecting := false
var _selected := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UIK.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	# Full width with comfortable side gutters.
	var gutter := float(UIK.px(40 if w >= UIK.px(900) else 16))
	var inner := w - gutter * 2.0
	_col.custom_minimum_size.x = inner
	var m: MarginContainer = _scroll.get_child(0)
	m.add_theme_constant_override("margin_top", UIK.px(22))
	m.add_theme_constant_override("margin_bottom", UIK.px(36))
	_cards.columns = 4 if w >= UIK.px(900) else 2
	var gap := UIK.px(14)
	_recent.columns = maxi(2, int((inner + gap) / float(UIK.px(250) + gap)))


func refresh() -> void:
	UIK.clear(_col)
	var top := UIK.hbox(10)
	var mark := TextureRect.new()
	mark.texture = load("res://assets/brand/mark.png")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.custom_minimum_size = Vector2(UIK.px(30), UIK.px(30))
	top.add_child(mark)
	top.add_child(UIK.label("GameScene", 18, UIK.INK, true))
	top.add_child(UIK.label("Studio", 18, UIK.MUTED))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(UIK.label("· v " + str(ProjectSettings.get_setting("application/config/version")), 13, UIK.MUTED))
	_col.add_child(top)
	_col.add_child(UIK.spacer(18))
	var h1 := UIK.label("What are you making?", 52, UIK.INK, true)
	h1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_col.add_child(h1)
	_col.add_child(UIK.spacer(6))
	_cards = UIK.grid(4, 16)
	for k in Styles.HOME_ORDER:
		_cards.add_child(_style_card(k))
	_col.add_child(_cards)
	_col.add_child(UIK.spacer(18))
	var rh := UIK.hbox()
	var t := UIK.label("Your scenes", 20, UIK.INK, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rh.add_child(t)
	var idx := ProjectStore.index()
	if _selecting:
		rh.add_child(UIK.btn("All" if _selected.size() < idx.size() else "None", func(): _select_all(idx)))
		var del := UIK.danger("Delete (%d)" % _selected.size(), func(): _delete_selected())
		del.disabled = _selected.is_empty()
		rh.add_child(del)
		rh.add_child(UIK.btn("Done", func(): _set_selecting(false), true, "check"))
	else:
		if not idx.is_empty():
			rh.add_child(UIK.btn("Select", func(): _set_selecting(true), false, "check"))
		var open := UIK.btn("Open a file", func(): _open_file(), false, "folder")
		rh.add_child(open)
	_col.add_child(rh)
	if _selecting:
		_col.add_child(UIK.para("Tap scenes to select them.", 13))
	_recent = UIK.grid(2, 14)
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
	UIK._card_states(b, false, 20)
	b.clip_contents = true
	var v := UIK.vbox(2)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	if k == "pixel":
		tr.texture = PixelSprites.icon({"preset": preset})
	else:
		tr.texture = icons.request("home|" + k, func(): return Rigs.build({"preset": preset}, k)["root"], "char")
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(UIK.px(200), UIK.px(204))
	b.clip_contents = true
	UIK._card_states(b, false, 16)
	var v := UIK.vbox(0)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = UIK.px(6)
	v.offset_right = -UIK.px(6)
	v.offset_top = UIK.px(6)
	v.offset_bottom = -UIK.px(8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Thumbnail in a clipping frame so it never spills into neighbours.
	var frame := Panel.new()
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var fsb := UIK.box(UIK.GRAY_800, 12)
	frame.add_theme_stylebox_override("panel", fsb)
	var tr := TextureRect.new()
	tr.texture = ProjectStore.thumb(id)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tr.texture == null:
		tr.texture = Icons.tex("film", 48, UIK.GRAY_400)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	frame.add_child(tr)
	v.add_child(frame)
	var cap := MarginContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_theme_constant_override("margin_left", UIK.px(6))
	cap.add_theme_constant_override("margin_right", UIK.px(6))
	cap.add_theme_constant_override("margin_top", UIK.px(8))
	var cv := UIK.vbox(2)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := UIK.label(p.get("name", "Scene"), 15, UIK.INK, true)
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.clip_text = true
	n.custom_minimum_size.x = 1
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(n)
	var s := UIK.label(Styles.get_style(p.get("style", "blocky"))["name"] + " · " + _when(int(p.get("updated", 0))), 12, UIK.MUTED)
	s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	s.clip_text = true
	s.custom_minimum_size.x = 1
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(s)
	cap.add_child(cv)
	v.add_child(cap)
	b.add_child(v)
	var more := MenuButton.new()
	more.icon = Icons.tex("more", UIK.px(20), Color.WHITE)
	more.flat = false
	more.add_theme_stylebox_override("normal", UIK.glass(10))
	more.add_theme_stylebox_override("hover", UIK.box(Color(UIK.GRAY_700, 0.95), 10, UIK.GRAY_400))
	more.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	more.offset_left = -UIK.px(48)
	more.offset_right = -UIK.px(12)
	more.offset_top = UIK.px(12)
	more.offset_bottom = UIK.px(44)
	var pm := more.get_popup()
	pm.add_item("Rename", 0)
	pm.add_item("Duplicate", 1)
	pm.add_item("Export file", 2)
	pm.add_item("Delete", 3)
	pm.id_pressed.connect(func(item: int): _tile_action(id, p, item))
	if _selecting:
		more.visible = false
		var on := _selected.has(id)
		UIK._card_states(b, on, 16)
		var tick := PanelContainer.new()
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tb := UIK.box(UIK.TAPE if on else Color(0.06, 0.08, 0.13, 0.6), 14, Color.WHITE, 2)
		tb.content_margin_left = UIK.px(4)
		tb.content_margin_right = UIK.px(4)
		tb.content_margin_top = UIK.px(4)
		tb.content_margin_bottom = UIK.px(4)
		tick.add_theme_stylebox_override("panel", tb)
		var ic := TextureRect.new()
		ic.texture = Icons.tex("check", UIK.px(18), UIK.TAPE_INK if on else Color(1, 1, 1, 0.0))
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tick.add_child(ic)
		tick.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		tick.offset_left = -UIK.px(44)
		tick.offset_right = -UIK.px(14)
		tick.offset_top = UIK.px(14)
		tick.offset_bottom = UIK.px(44)
		b.add_child(tick)
	b.add_child(more)
	b.pressed.connect(func(): _tile_pressed(id))
	return b


## Short, friendly timestamp: "Today 15:57", "Yesterday 09:10", "Nov 3".
func _when(t: int) -> String:
	var now := int(Time.get_unix_time_from_system())
	var d := Time.get_datetime_dict_from_unix_time(t)
	var hm := "%02d:%02d" % [d["hour"], d["minute"]]
	var days := (now - now % 86400 - (t - t % 86400)) / 86400
	if days <= 0:
		return "Today " + hm
	if days == 1:
		return "Yesterday " + hm
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d" % [months[int(d["month"]) - 1], d["day"]]


func _tile_pressed(id: String) -> void:
	if not _selecting:
		open_project.emit(id)
		return
	if _selected.has(id):
		_selected.erase(id)
	else:
		_selected[id] = true
	_refresh_keep_scroll()


func _set_selecting(on: bool) -> void:
	_selecting = on
	_selected.clear()
	_refresh_keep_scroll()


func _select_all(idx: Array) -> void:
	if _selected.size() < idx.size():
		for p in idx:
			_selected[p["id"]] = true
	else:
		_selected.clear()
	_refresh_keep_scroll()


func _delete_selected() -> void:
	if _selected.is_empty():
		return
	var n := _selected.size()
	var hud: Hud = get_parent().get_node("Hud")
	hud.ask("Delete %d scene%s? This can’t be undone." % [n, "" if n == 1 else "s"], "Delete", func():
		for id in _selected.keys():
			ProjectStore.delete(id)
		App.toast("Deleted %d scene%s." % [n, "" if n == 1 else "s"])
		_selecting = false
		_selected.clear()
		_refresh_keep_scroll())


func _refresh_keep_scroll() -> void:
	var sc := _scroll.scroll_vertical
	refresh()
	await get_tree().process_frame
	_scroll.scroll_vertical = sc


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
	hud.prompt("Rename scene", p.get("name", ""), "Scene name", "Save", func(n: String):
		ProjectStore.rename(id, ProjectStore.unique_name(n, id))
		refresh())


func _open_file() -> void:
	var hud: Hud = get_parent().get_node("Hud")
	hud.pick_file(PackedStringArray(["*.json ; GameScene project"]), func(path: String):
		var id := ProjectStore.import_from(path)
		if id.begins_with("!"):
			App.toast(id.substr(1))
			return
		refresh()
		open_project.emit(id), "Open a scene")
