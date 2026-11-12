class_name Home
extends Control
## Home screen: pick a style to start a new scene, or reopen a saved one.
## Below the styles: your scenes, recordings and screenshots, as tabs (one
## full grid at a time, nothing to scroll sideways). Selecting scenes for
## deleting uses a bar floating at the bottom, so nothing above moves.

signal new_scene(style: String)
signal open_project(id: String)

var icons: IconStudio
var hud_ask: Callable
var _col := VBoxContainer.new()
var _cards: GridContainer = null
var _recent: GridContainer = null
var _scroll := ScrollContainer.new()
## Multi-select mode for bulk actions on saved scenes.
var _selecting := false
var _selected := {}
## "scenes", "recordings" or "screenshots".
var _tab := "scenes"
var _bar: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UIK.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Touch screens scroll by dragging; a scroll bar that comes and goes as
	# the page is rebuilt (Select, switching tabs) made the page jump sideways.
	if App.is_touch:
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_scroll)
	var center := MarginContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(center)
	_col.add_theme_constant_override("separation", UIK.px(12))
	_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(_col)
	_bar = PanelContainer.new()
	# A colour of its own, so the selection actions stand out from the page.
	var bsb := UIK.box(UIK.SECONDARY_700, 18, UIK.PRIMARY_500, 2)
	bsb.shadow_color = Color(0, 0, 0, 0.45)
	bsb.shadow_size = UIK.px(14)
	_bar.add_theme_stylebox_override("panel", bsb)
	_bar.visible = false
	add_child(_bar)
	get_viewport().size_changed.connect(func():
		if _narrow() != _was_narrow and visible:
			refresh()
		else:
			_layout())
	refresh()


func _layout() -> void:
	var w := get_viewport_rect().size.x
	# Full width with comfortable side gutters.
	var gutter := float(UIK.px(40 if w >= UIK.px(900) else 16))
	var inner := w - gutter * 2.0
	var m: MarginContainer = _scroll.get_child(0)
	# Fixed side margins (not centring), so the page never shifts sideways.
	m.add_theme_constant_override("margin_left", int(gutter))
	m.add_theme_constant_override("margin_right", int(gutter))
	# Phones: clear the status bar / notch and the gesture bar.
	var ins := App.safe_insets()
	m.add_theme_constant_override("margin_top", UIK.px(22) + int(ins.position.y))
	m.add_theme_constant_override("margin_bottom", UIK.px(36) + int(ins.size.y))
	if _settings and is_instance_valid(_page):
		_page.custom_minimum_size.x = minf(inner, UIK.px(720))
	if _cards == null or _recent == null:
		return
	_cards.columns = 4 if w >= UIK.px(900) else 2
	var gap := UIK.px(14)
	_recent.columns = maxi(2, int((inner + gap) / float(UIK.px(250) + gap)))
	if _bar.visible:
		var vs := get_viewport_rect().size
		_bar.size = _bar.get_combined_minimum_size()
		_bar.position = Vector2((vs.x - _bar.size.x) / 2.0, vs.y - _bar.size.y - UIK.px(18) - ins.size.y)


## A phone held upright (or any narrow window).
func _narrow() -> bool:
	return get_viewport_rect().size.x < UIK.px(600)


## Scene / recording tiles: two to a row even on a phone held upright.
func _tile_size() -> Vector2:
	return Vector2(UIK.px(140), UIK.px(168)) if _narrow() else Vector2(UIK.px(200), UIK.px(204))


var _was_narrow := false


## The home screen's settings page instead of the scenes (gear in the header).
var _settings := false


func refresh() -> void:
	_was_narrow = _narrow()
	if _settings:
		_build_settings()
		return
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
	top.add_child(UIK.icon_btn("gear", func(): _open_settings(true), "Settings", 40, false))
	_col.add_child(top)
	_col.add_child(UIK.spacer(18))
	# On a phone, no bigger than the "GameScene Studio" header above it.
	var h1 := UIK.label("What are you making?", 18 if _narrow() else 52, UIK.INK, true)
	h1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_col.add_child(h1)
	_col.add_child(UIK.spacer(6))
	_cards = UIK.grid(4, 16)
	for k in Styles.HOME_ORDER:
		_cards.add_child(_style_card(k))
	_col.add_child(_cards)
	# Your own work sits clearly apart from the four ways to start.
	_col.add_child(UIK.spacer(40 if _narrow() else 30))
	var rule := ColorRect.new()
	rule.color = UIK.LINE
	rule.custom_minimum_size.y = maxf(1.0, UIK.px(1))
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_child(rule)
	_col.add_child(UIK.spacer(14))
	_col.add_child(UIK.label("Your work", 22 if _narrow() else 24, UIK.INK, true))
	var idx := ProjectStore.index()
	var recs := Media.recordings()
	var shots := Media.screenshots()
	# Tabs on the left, the tab's actions on the right (below them on a
	# narrow phone screen). The row keeps its height in every state, so
	# nothing below it moves.
	var rh := UIK.flow(8)
	var tabs := UIK.hbox(6)
	for tb in [["scenes", "Scenes", idx.size()], ["recordings", "Recordings", recs.size()], ["screenshots", "Screenshots", shots.size()]]:
		tabs.add_child(UIK.chip("%s  %d" % [tb[1], tb[2]], _tab == tb[0], func():
			if _tab != tb[0]:
				_tab = tb[0]
				_selecting = false
				_selected.clear()
				_refresh_keep_scroll()))
	rh.add_child(tabs)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rh.add_child(gap)
	var items := _items(idx, recs, shots)
	var sel := UIK.btn("Done" if _selecting else "Select", func(): _set_selecting(not _selecting), _selecting, "check")
	sel.disabled = items.is_empty()
	rh.add_child(sel)
	match _tab:
		"scenes":
			rh.add_child(UIK.btn("Open a file", func(): _open_file(), false, "folder"))
		"recordings":
			if Media.can_reveal():
				rh.add_child(UIK.btn("Open folder", func(): OS.shell_open(Recorder.output_dir("video")), false, "folder"))
		"screenshots":
			if Media.can_reveal():
				rh.add_child(UIK.btn("Open folder", func(): OS.shell_open(Recorder.output_dir("image")), false, "folder"))
	_col.add_child(rh)
	_recent = UIK.grid(2, 14)
	match _tab:
		"scenes":
			if idx.is_empty():
				_col.add_child(UIK.para("Nothing yet. Pick a style above to build your first scene.", 14))
			for p in idx:
				_recent.add_child(_recent_tile(p))
		"recordings":
			if recs.is_empty():
				_col.add_child(UIK.para("No recordings yet. Press Record in a scene, or export a film from the Film panel.", 14))
			for it in recs:
				_recent.add_child(_media_tile(it))
		"screenshots":
			if shots.is_empty():
				_col.add_child(UIK.para("No screenshots yet. Use the picture button at the top right of a scene (or P).", 14))
			for it in shots:
				_recent.add_child(_media_tile(it))
	_col.add_child(_recent)
	_update_bar(items)
	_layout()


## What the current tab lists, by selection key: scene ids, or file paths.
func _items(idx: Array, recs: Array, shots: Array) -> Array:
	match _tab:
		"recordings":
			return recs.map(func(r): return r["path"])
		"screenshots":
			return shots.map(func(r): return r["path"])
	return idx.map(func(p): return p["id"])


## Selecting: a bar floating at the bottom with the count, All/None,
## Show in folder (recordings, screenshots) and Delete; the page itself
## doesn't change shape.
func _update_bar(items: Array) -> void:
	UIK.clear(_bar)
	_bar.visible = _selecting
	if not _bar.visible:
		return
	var h := UIK.hbox(8)
	var what: String = {"scenes": "scenes", "recordings": "recordings", "screenshots": "screenshots"}[_tab]
	var l := UIK.label("Tap %s to select them" % what if _selected.is_empty() else "%d selected" % _selected.size(), 15, UIK.INK, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size.x = UIK.px(240)
	# Narrow screens: no room for the label; "Delete (n)" shows the count.
	l.visible = get_viewport_rect().size.x >= UIK.px(640)
	h.add_child(l)
	h.add_child(UIK.btn("All" if _selected.size() < items.size() else "None", func(): _select_all(items)))
	if _tab != "scenes":
		var show: Button
		if Media.can_reveal():
			# One file at a time: several opened a file manager window each.
			if _selected.size() <= 1:
				show = UIK.btn("Show in folder", func(): _reveal_selected(), false, "folder")
		else:
			show = UIK.btn("Share", func(): Media.share(_selected.keys()), false, "upload")
		if show:
			show.disabled = _selected.is_empty()
			h.add_child(show)
	var del := UIK.danger("Delete (%d)" % _selected.size(), func(): _delete_selected())
	del.disabled = _selected.is_empty()
	h.add_child(del)
	h.add_child(UIK.btn("Done", func(): _set_selecting(false), true, "check"))
	_bar.add_child(h)


## A recording or screenshot: thumbnail (made in the background), name, when
## and size. Tap opens it; the menu shows it in its folder or deletes it.
func _media_tile(it: Dictionary) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = _tile_size()
	b.clip_contents = true
	UIK._card_states(b, false, 16)
	var v := UIK.vbox(0)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = UIK.px(6)
	v.offset_right = -UIK.px(6)
	v.offset_top = UIK.px(6)
	v.offset_bottom = -UIK.px(8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := Panel.new()
	frame.clip_contents = true
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", UIK.box(UIK.GRAY_800, 12))
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := "film" if it["kind"] != "image" else "image"
	var cached := Media.cached_thumb(it)
	if cached:
		tr.texture = cached
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	else:
		tr.texture = Icons.tex(icon, 48, UIK.GRAY_400)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		# A weak reference: the page may be rebuilt before the thumbnail is
		# ready, and a lambda holding a freed node errors when called.
		var wr: WeakRef = weakref(tr)
		Media.thumb_async(it, func(tex: Texture2D):
			var t: TextureRect = wr.get_ref()
			if tex and t:
				t.texture = tex
				t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED)
	frame.add_child(tr)
	if it["kind"] != "image":
		# A play badge so videos read as videos.
		var badge := TextureRect.new()
		badge.texture = Icons.tex("playtri", UIK.px(22), Color.WHITE)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		badge.offset_left = UIK.px(10)
		badge.offset_top = -UIK.px(34)
		badge.offset_right = UIK.px(34)
		badge.offset_bottom = -UIK.px(10)
		frame.add_child(badge)
	v.add_child(frame)
	var cap := MarginContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_theme_constant_override("margin_left", UIK.px(6))
	cap.add_theme_constant_override("margin_right", UIK.px(6))
	cap.add_theme_constant_override("margin_top", UIK.px(8))
	var cv := UIK.vbox(2)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := UIK.label(str(it["name"]), 15, UIK.INK, true)
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.clip_text = true
	n.custom_minimum_size.x = 1
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(n)
	var what := "%d frames" % int(it.get("frames", 0)) if it["kind"] == "frames" else Media.size_text(int(it["bytes"]))
	var s2 := UIK.label(_when(int(it["time"])) + " · " + what, 12, UIK.MUTED)
	s2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	s2.clip_text = true
	s2.custom_minimum_size.x = 1
	s2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(s2)
	cap.add_child(cv)
	v.add_child(cap)
	b.add_child(v)
	var more := _more(str(it["name"]), [["Open", "playtri"], ["Rename", "edit"], ["Show in folder" if Media.can_reveal() else "Share", "folder" if Media.can_reveal() else "upload"],
		["Delete", "trash", true]], _media_action.bind(it))
	if _selecting:
		more.visible = false
		var on := _selected.has(it["path"])
		UIK._card_states(b, on, 16)
		b.add_child(_tick(on))
	b.add_child(more)
	b.pressed.connect(func():
		if _selecting:
			_tile_pressed(str(it["path"]))
		else:
			OS.shell_open(str(it["path"])))
	return b


func _style_card(k: String) -> Control:
	var sty: Dictionary = Styles.STYLES[k]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(UIK.px(150), UIK.px(232 if _narrow() else 260))
	UIK._card_states(b, false, 20)
	b.clip_contents = true
	var v := UIK.vbox(0)
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
	# A soft shade towards the bottom, like ground under the character.
	var shade := TextureRect.new()
	var sg := GradientTexture2D.new()
	var sgg := Gradient.new()
	sgg.set_color(0, Color(0, 0, 0, 0))
	sgg.set_color(1, Color(0, 0, 0, 0.3))
	sgg.set_offset(0, 0.55)
	sg.gradient = sgg
	sg.fill_from = Vector2(0.5, 0)
	sg.fill_to = Vector2(0.5, 1)
	shade.texture = sg
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(shade)
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
	# "3D" / "2D" tag.
	var tag := PanelContainer.new()
	var tsb := UIK.box(Color(UIK.GRAY_950, 0.55), 8)
	tsb.content_margin_left = UIK.px(8)
	tsb.content_margin_right = UIK.px(8)
	tsb.content_margin_top = UIK.px(2)
	tsb.content_margin_bottom = UIK.px(2)
	tag.add_theme_stylebox_override("panel", tsb)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(UIK.label("2D" if sty["world"] in ["pixel", "pixeltop"] else "3D", 11, Color.WHITE, true))
	tag.position = Vector2(UIK.px(10), UIK.px(10))
	ph.add_child(tag)
	v.add_child(ph)
	var cap := MarginContainer.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		cap.add_theme_constant_override("margin_" + side, UIK.px(12))
	var cv := UIK.vbox(2)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n := UIK.label(sty["name"], 16, UIK.INK, true)
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.clip_text = true
	n.custom_minimum_size.x = 1
	cv.add_child(n)
	var bl := UIK.label(sty["blurb"], 12, UIK.MUTED)
	bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Always two lines tall, so every card is the same shape whether its
	# description takes one line or two.
	bl.max_lines_visible = 2
	bl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	bl.custom_minimum_size = Vector2(1, UIK.px(32))
	bl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
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
	b.custom_minimum_size = _tile_size()
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
	var more := _more(str(p.get("name", "Scene")), [["Rename", "edit"], ["Duplicate", "duplicate"],
		["Share file" if App.is_mobile and Native.available() else "Export file", "upload" if App.is_mobile else "download"], ["Delete", "trash", true]],
		func(item: int): _tile_action(id, p, item))
	if _selecting:
		more.visible = false
		var on := _selected.has(id)
		UIK._card_states(b, on, 16)
		b.add_child(_tick(on))
	b.add_child(more)
	b.pressed.connect(func(): _tile_pressed(id))
	return b


## The "⋯" button on a tile. With a mouse it drops a small menu; on touch
## screens it opens a full-width action sheet with big rows (Hud.choose).
## `items`: [[label, icon, danger]]; `cb(index)`.
func _more(title: String, items: Array, cb: Callable) -> Button:
	var more: Button
	if App.is_touch:
		more = Button.new()
		more.pressed.connect(func(): (get_parent().get_node("Hud") as Hud).choose(title, items, cb))
	else:
		var mb := MenuButton.new()
		var pm := mb.get_popup()
		for i in items.size():
			pm.add_item(str(items[i][0]), i)
		pm.id_pressed.connect(cb)
		more = mb
	more.focus_mode = Control.FOCUS_NONE
	more.icon = Icons.tex("more", UIK.px(20), Color.WHITE)
	more.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	more.flat = false
	more.add_theme_stylebox_override("normal", UIK.glass(10))
	more.add_theme_stylebox_override("hover", UIK.box(Color(UIK.GRAY_700, 0.95), 10, UIK.GRAY_400))
	more.add_theme_stylebox_override("pressed", UIK.box(Color(UIK.GRAY_700, 0.95), 10, UIK.GRAY_400))
	more.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	# A bigger target on touch screens.
	var s := 44 if App.is_touch else 36
	more.offset_left = -UIK.px(12 + s)
	more.offset_right = -UIK.px(12)
	more.offset_top = UIK.px(12)
	more.offset_bottom = UIK.px(12 + s * 32 / 36)
	return more


func _media_action(item: int, it: Dictionary) -> void:
	match item:
		0:
			OS.shell_open(str(it["path"]))
		1:
			var hud: Hud = get_parent().get_node("Hud")
			hud.prompt("Rename", str(it["name"]), "Name", "Save", func(n: String):
				var err := Media.rename(it, n)
				if err != "":
					App.toast(err)
				_refresh_keep_scroll())
		2:
			if Media.can_reveal():
				Media.reveal([str(it["path"])])
			else:
				Media.share([str(it["path"])])
		3:
			var hud: Hud = get_parent().get_node("Hud")
			hud.ask("Delete “%s”? This can’t be undone." % it["name"], "Delete", func():
				Media.remove(it)
				_refresh_keep_scroll())


## Shows the selected files in their folder. Explorer and Finder highlight
## one file at a time, so with several selected, say which one it is.
func _reveal_selected() -> void:
	var paths: Array = _selected.keys()
	paths.sort()
	var n := Media.reveal(paths)
	if n < paths.size():
		App.toast("Showing the first of %d: %s. Explorer and Finder highlight one file at a time." % [paths.size(), str(paths[0]).get_file()])


## The round check mark on a tile while selecting.
func _tick(on: bool) -> Control:
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
	return tick


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


func _select_all(items: Array) -> void:
	if _selected.size() < items.size():
		for k in items:
			_selected[k] = true
	else:
		_selected.clear()
	_refresh_keep_scroll()


func _delete_selected() -> void:
	if _selected.is_empty():
		return
	var n := _selected.size()
	var hud: Hud = get_parent().get_node("Hud")
	var noun: String = {"scenes": "scene", "recordings": "recording", "screenshots": "screenshot"}[_tab] + ("" if n == 1 else "s")
	hud.ask("Delete %d %s? This can’t be undone." % [n, noun], "Delete", func():
		if _tab == "scenes":
			for id in _selected.keys():
				ProjectStore.delete(id)
		else:
			var all := Media.recordings() + Media.screenshots()
			for it in all:
				if _selected.has(it["path"]):
					Media.remove(it)
		App.toast("Deleted %d %s." % [n, noun])
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
			hud.export_project(id, str(p.get("name", "scene")))
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


# ---------------------------------------------------------------- settings

func _open_settings(on: bool) -> void:
	_settings = on
	_selecting = false
	_selected.clear()
	refresh()
	_scroll.scroll_vertical = 0


## The settings page's column (inside _col).
var _page: VBoxContainer


func _heading(text: String) -> void:
	_page.add_child(UIK.spacer(10))
	_page.add_child(UIK.label(text, 13, UIK.MUTED, true))


## Global settings: how new scenes start, the phone dock, this device, and
## the footer.
func _build_settings() -> void:
	UIK.clear(_col)
	_update_bar([])
	# A readable column: full width on a phone, centred and at most about
	# 720 px wide on a desktop.
	var w := get_viewport_rect().size.x
	var inner := w - float(UIK.px(40 if w >= UIK.px(900) else 16)) * 2.0
	_page = UIK.vbox(12)
	_page.custom_minimum_size.x = minf(inner, UIK.px(720))
	_page.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_col.add_child(_page)
	# Title on the left, a round close button on the right (as the studio's
	# panels have).
	var top := UIK.hbox(10)
	var title := UIK.label("Settings", 22, UIK.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(UIK.icon_btn("close", func(): _open_settings(false), "Close settings", 40))
	_page.add_child(top)

	_heading("New scenes")
	_page.add_child(UIK.toggle("Sound on (music and sound effects)", App.device.get("new_sound", false), func(on: bool): App.set_device("new_sound", on)))
	_page.add_child(UIK.toggle("Characters chat on their own (speech bubbles)", App.device.get("new_chatter", false), func(on: bool): App.set_device("new_chatter", on)))
	_page.add_child(UIK.toggle("Characters speak up when hit", App.device.get("new_hit_lines", true), func(on: bool): App.set_device("new_hit_lines", on)))
	_page.add_child(UIK.para("For scenes you make from now on. Each scene can still change these in its own settings; ambience always starts on Auto.", 12))

	_heading("Studio buttons")
	var g := UIK.grid(2, 12)
	for opt in [["full", "Full", "Every button along the bottom."], ["compact", "Compact", "A Menu button that opens the row; ‹ folds it."]]:
		g.add_child(_dock_option(opt[0], opt[1], opt[2]))
	_page.add_child(g)

	_heading("This device")
	var q := UIK.flow()
	for k in App.QUALITY:
		q.add_child(UIK.chip(App.QUALITY[k]["label"], App.device["quality"] == k, func():
			App.set_device("quality", k)
			refresh()))
	_page.add_child(q)
	var fr := UIK.flow()
	for c in [[30, "30 fps"], [60, "60 fps"], [0, "Highest frame rate"]]:
		fr.add_child(UIK.chip(c[1], int(App.device.get("fps_cap", 0)) == c[0], func():
			App.set_device("fps_cap", c[0])
			App.apply_fps()
			refresh()))
	_page.add_child(fr)
	_page.add_child(UIK.slider("Interface size", App.device["ui_scale"], 0.8, 1.6, 0.05, func(x): App.set_device("ui_scale", x), func(x): return "%d%%" % int(x * 100)))
	_page.add_child(UIK.para("Interface size applies the next time you open the app.", 12))
	_page.add_child(UIK.toggle("Show name tags", App.device["names"], func(on): App.set_device("names", on)))
	_page.add_child(UIK.toggle("Show frame rate", App.device["show_fps"], func(on): App.set_device("show_fps", on)))
	_page.add_child(UIK.toggle("Countdown beeps before a take", App.device.get("ui_sounds", false), func(on): App.set_device("ui_sounds", on)))
	_page.add_child(UIK.toggle("Pause exports to cool down when the device slows", App.device.get("cool_down", false), func(on): App.set_device("cool_down", on)))

	# Footer.
	_page.add_child(UIK.spacer(28))
	var rule := ColorRect.new()
	rule.color = UIK.LINE
	rule.custom_minimum_size.y = maxf(1.0, UIK.px(1))
	_page.add_child(rule)
	var foot := UIK.vbox(4)
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	var ver := UIK.label("GameScene Studio · v " + str(ProjectSettings.get_setting("application/config/version")), 12, UIK.MUTED)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_child(ver)
	var link := LinkButton.new()
	link.text = "ekaai.tech"
	link.uri = "https://ekaai.tech"
	link.focus_mode = Control.FOCUS_NONE
	link.add_theme_font_override("font", UIK.font_bold)
	link.add_theme_font_size_override("font_size", UIK.px(14))
	link.add_theme_color_override("font_color", UIK.PRIMARY_500)
	link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	foot.add_child(link)
	_page.add_child(UIK.spacer(8))
	_page.add_child(foot)
	# Desktop: the same page, in bigger type.
	if not _narrow():
		for n in _page.find_children("*", "", true, false):
			if n is Label or n is Button:
				var c := n as Control
				c.add_theme_font_size_override("font_size", int(round(c.get_theme_font_size("font_size") * 1.2)))
	_layout()


## One dock choice: a picture of it (built from the real icons) and a line
## on how it works.
func _dock_option(key: String, title: String, desc: String) -> Control:
	var on: bool = App.device.get("dock", "full") == key
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(UIK.px(140), UIK.px(172 if _narrow() else 236))
	UIK._card_states(b, on, 16)
	b.pressed.connect(func():
		App.set_device("dock", key)
		refresh())
	var v := UIK.vbox(8)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = UIK.px(14)
	v.offset_right = -UIK.px(14)
	v.offset_top = UIK.px(14)
	v.offset_bottom = -UIK.px(16)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Text on top, the picture of the dock below it (at the card's foot, so
	# both cards' pictures line up).
	var t := UIK.label(title + ("  ✓" if on else ""), 15, UIK.INK, true)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var d := UIK.label(desc, 12, UIK.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 1
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(gap)
	if key == "full":
		v.add_child(_dock_picture(["plus", "cast", "script", "camera", "sun", "speaker", "film"], false))
	else:
		v.add_child(_dock_picture(["lines"], false))
		v.add_child(_dock_picture(["plus", "cast", "script", "camera", "sun", "speaker", "film"], true))
	b.add_child(v)
	return b


## A small dock: dark glass with the icons, plus the narrow fold tab.
func _dock_picture(icons: Array, fold: bool) -> Control:
	var p := PanelContainer.new()
	var sb := UIK.glass(10)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sb.set_content_margin(side, UIK.px(4))
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UIK.hbox(2)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Bigger on a desktop, where the cards are wide.
	var k := 1.0 if _narrow() else 2.5
	var size := UIK.px((12 if icons.size() > 1 else 16) * k)
	for ic in icons:
		var tr := TextureRect.new()
		tr.texture = Icons.tex(str(ic), size, Color.WHITE)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		tr.custom_minimum_size = Vector2(size + UIK.px(4), size + UIK.px(8))
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(tr)
	if fold:
		var f := TextureRect.new()
		f.texture = Icons.tex("back", UIK.px(10 * k), UIK.GRAY_300)
		f.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		f.custom_minimum_size = Vector2(UIK.px(8 * k), size + UIK.px(8))
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(f)
	p.add_child(h)
	return p
