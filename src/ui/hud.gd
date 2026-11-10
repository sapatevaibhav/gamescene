class_name Hud
extends Control
## Studio overlay: top buttons, dock, record slate, tool strip, sheets
## (bottom sheet on phones, side panel on wide screens), touch controls,
## toasts, dialogs and the recording frame guide.

signal go_home

var studio: Studio
var icons: IconStudio
var sheets: Sheets

var top_left := HBoxContainer.new()
var top_right := HBoxContainer.new()
var undo_btn: Button
var redo_btn: Button
var fps_label := Label.new()
var dock := PanelContainer.new()
var dock_row := HBoxContainer.new()
var dock_btns := {}
var slate := Button.new()
var slate_label := Label.new()
var slate_dot := Panel.new()
var toolbar := PanelContainer.new()
var toolbar_row := HBoxContainer.new()
var tool_hint := Label.new()
var sheet := PanelContainer.new()
var sheet_title := Label.new()
var sheet_back: Button
var sheet_body := VBoxContainer.new()
var sheet_scroll := ScrollContainer.new()
var toast_panel := PanelContainer.new()
var toast_label := Label.new()
var countdown := Label.new()
var modal := Control.new()
## Dims and blurs everything behind a popup so it stands out.
var modal_shade := ColorRect.new()

const SHADE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur = 2.6;
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur).rgb;
	COLOR = vec4(c * 0.55, 1.0);
}
"""
var frame_guide := FrameGuide.new()
var crosshair := Crosshair.new()
var joy := Joystick.new()
var pad := VBoxContainer.new()
var restore_btn: Button
var play_bar := PanelContainer.new()
var timeline_panel: TimelinePanel
var play_label := Label.new()
var play_pause: Button

var clean := false
var view_stack: Array = []
var _toast_t := 0.0
var _counting := false
var take := 1
var jump_held := false
var up_held := false
var down_held := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheets = Sheets.new(self)

	frame_guide.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame_guide)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(crosshair)

	# Top bar.
	top_left.add_theme_constant_override("separation", UIK.px(8))
	top_left.add_child(UIK.icon_btn("home", func(): go_home.emit(), "Home"))
	undo_btn = UIK.icon_btn("undo", _undo, "Undo (Ctrl+Z)")
	redo_btn = UIK.icon_btn("redo", _redo, "Redo (Ctrl+Shift+Z)")
	top_left.add_child(undo_btn)
	top_left.add_child(redo_btn)
	add_child(top_left)
	top_right.add_theme_constant_override("separation", UIK.px(8))
	top_right.add_child(UIK.icon_btn("image", screenshot, "Screenshot (P)"))
	top_right.add_child(UIK.icon_btn("eyeview", func(): set_clean(true), "Clean view (H)"))
	top_right.add_child(UIK.icon_btn("gear", func(): open_sheet("settings"), "Settings"))
	add_child(top_right)
	fps_label.add_theme_font_size_override("font_size", UIK.px(12))
	fps_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	fps_label.visible = false
	add_child(fps_label)

	# Dock.
	dock.add_theme_stylebox_override("panel", _bar_panel())
	dock_row.add_theme_constant_override("separation", UIK.px(2))
	for tab in [["add", "plus", "Add"], ["cast", "cast", "Cast"], ["script", "script", "Script"], ["camera", "camera", "Camera"], ["mood", "sun", "Mood"], ["sound", "speaker", "Sound"], ["film", "film", "Film"]]:
		var b := _dock_button(tab[0], tab[1], tab[2])
		dock_btns[tab[0]] = b
		dock_row.add_child(b)
	dock.add_child(dock_row)
	add_child(dock)

	# Record button: a pill with a red dot; turns red while recording.
	slate.focus_mode = Control.FOCUS_NONE
	slate.custom_minimum_size = Vector2(UIK.px(128), UIK.px(54))
	slate.tooltip_text = "Record a take (R)"
	_style_record(false)
	var sh := UIK.hbox(10)
	sh.alignment = BoxContainer.ALIGNMENT_CENTER
	sh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot_sb := StyleBoxFlat.new()
	dot_sb.bg_color = UIK.REC
	dot_sb.set_corner_radius_all(UIK.px(8))
	dot_sb.set_border_width_all(UIK.px(2))
	dot_sb.border_color = Color(1, 1, 1, 0.9)
	slate_dot.add_theme_stylebox_override("panel", dot_sb)
	slate_dot.custom_minimum_size = Vector2(UIK.px(16), UIK.px(16))
	slate_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slate_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.add_child(slate_dot)
	slate_label.text = "Record"
	slate_label.add_theme_font_override("font", UIK.font_bold)
	slate_label.add_theme_font_size_override("font_size", UIK.px(16))
	slate_label.add_theme_color_override("font_color", Color.WHITE)
	slate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.add_child(slate_label)
	slate.add_child(sh)
	slate.pressed.connect(toggle_record)
	add_child(slate)

	# Tool strip.
	toolbar.add_theme_stylebox_override("panel", _bar_panel())
	toolbar_row.add_theme_constant_override("separation", UIK.px(2))
	toolbar.add_child(toolbar_row)
	toolbar.visible = false
	add_child(toolbar)
	tool_hint.add_theme_font_size_override("font_size", UIK.px(13))
	tool_hint.add_theme_stylebox_override("normal", UIK.glass(12))
	tool_hint.add_theme_color_override("font_color", Color.WHITE)
	tool_hint.visible = false
	tool_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tool_hint)

	# Script playback bar.
	play_bar.add_theme_stylebox_override("panel", UIK.glass(14))
	var pr := UIK.hbox(8)
	play_pause = UIK.icon_btn("pause", toggle_pause, "Pause and direct", 36, false)
	pr.add_child(play_pause)
	pr.add_child(UIK.icon_btn("stop", func(): stop_script(), "Stop", 36, false))
	play_label.add_theme_color_override("font_color", Color.WHITE)
	pr.add_child(play_label)
	play_bar.add_child(pr)
	play_bar.visible = false
	add_child(play_bar)

	# Sheet.
	sheet.add_theme_stylebox_override("panel", UIK.box(UIK.SURFACE, 22, UIK.LINE))
	var sv := UIK.vbox(4)
	var head := UIK.hbox(6)
	sheet_back = UIK.icon_btn("back", back_view, "Back", 38, false)
	UIK.style_button(sheet_back, "neutral")
	head.add_child(sheet_back)
	sheet_title.add_theme_font_override("font", UIK.font_bold)
	sheet_title.add_theme_font_size_override("font_size", UIK.px(21))
	sheet_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_title.clip_text = true
	head.add_child(sheet_title)
	var close := UIK.icon_btn("close", close_sheet, "Close", 38, false)
	UIK.style_button(close, "neutral")
	head.add_child(close)
	sv.add_child(head)
	sheet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sheet_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet_body.add_theme_constant_override("separation", UIK.px(10))
	var pad_m := MarginContainer.new()
	pad_m.add_theme_constant_override("margin_left", UIK.px(4))
	pad_m.add_theme_constant_override("margin_right", UIK.px(8))
	pad_m.add_theme_constant_override("margin_bottom", UIK.px(12))
	pad_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad_m.add_child(sheet_body)
	sheet_scroll.add_child(pad_m)
	sv.add_child(sheet_scroll)
	sheet.add_child(sv)
	sheet.visible = false
	add_child(sheet)

	timeline_panel = TimelinePanel.new(self)
	add_child(timeline_panel)

	# Touch controls.
	joy.visible = false
	joy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(joy)
	pad.add_theme_constant_override("separation", UIK.px(10))
	pad.add_child(_hold_btn("up", func(v): up_held = v, 60))
	pad.add_child(_hold_btn("down", func(v): down_held = v, 60))
	pad.add_child(_hold_btn("up", func(v): jump_held = v, 70))
	pad.visible = App.is_touch
	add_child(pad)

	restore_btn = UIK.btn("Show controls", func(): set_clean(false))
	restore_btn.modulate.a = 0.4
	restore_btn.visible = false
	add_child(restore_btn)

	toast_panel.add_theme_stylebox_override("panel", UIK.glass(12))
	toast_label.add_theme_color_override("font_color", Color.WHITE)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_panel.add_child(toast_label)
	toast_panel.visible = false
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_panel)

	countdown.add_theme_font_override("font", UIK.font_bold)
	countdown.add_theme_font_size_override("font_size", UIK.px(180))
	countdown.add_theme_color_override("font_color", Color.WHITE)
	countdown.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	countdown.add_theme_constant_override("shadow_offset_y", 6)
	countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	countdown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	countdown.visible = false
	countdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(countdown)

	modal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var shade_mat := ShaderMaterial.new()
	var shade_sh := Shader.new()
	shade_sh.code = SHADE_SHADER
	shade_mat.shader = shade_sh
	modal_shade.material = shade_mat
	modal_shade.visible = false
	add_child(modal_shade)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.child_entered_tree.connect(func(_c): modal_shade.visible = true)
	modal.child_exiting_tree.connect(func(_c): _update_shade.call_deferred())
	add_child(modal)

	App.toast_requested.connect(toast)
	studio.tools.tool_changed.connect(render_toolbar)
	studio.recording_changed.connect(_on_recording)
	studio.recorder.finished.connect(_on_take_done)
	studio.recorder.progress.connect(_on_progress)
	studio.cast_changed.connect(_on_cast_changed)
	get_viewport().size_changed.connect(layout)
	layout()


func _on_cast_changed() -> void:
	if _top_name() == "cast":
		render_sheet()
	if timeline_panel.visible:
		timeline_panel.rebuild_bar()


func _dock_button(tab: String, icon: String, text: String) -> Button:
	var b := _bar_button(icon, text)
	b.pressed.connect(func(): _on_tab(tab))
	return b


## Icon-over-label button used by the dock and the tool strip. Every state
## shares the same padding, so nothing shifts on hover, and the content is
## centred in the bar. mode: "rest" | "on" (toggled) | "active" (primary).
func _bar_button(icon: String, text: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = text
	b.set_meta("icon", icon)
	b.custom_minimum_size = Vector2(UIK.px(64), UIK.px(60))
	# Our own centred column: icon above label, optically centred.
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", UIK.px(4))
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = UIK.px(2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := TextureRect.new()
	tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	tr.custom_minimum_size = Vector2(UIK.px(22), UIK.px(22))
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(tr)
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", UIK.px(12))
	l.add_theme_font_override("font", UIK.font_bold)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(l)
	b.add_child(col)
	b.set_meta("tex", tr)
	b.set_meta("label", l)
	_bar_mode(b, "rest")
	return b


func _bar_panel() -> StyleBoxFlat:
	var sb := UIK.glass(18)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		sb.set_content_margin(side, UIK.px(5))
	return sb


func _bar_box(c: Color, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := UIK.box(c, 13, border, 1 if border.a > 0 else 0)
	sb.content_margin_top = UIK.px(12)
	sb.content_margin_bottom = UIK.px(2)
	sb.content_margin_left = UIK.px(6)
	sb.content_margin_right = UIK.px(6)
	return sb


func _bar_mode(b: Button, mode: String) -> void:
	var active := mode == "active"
	var ink := UIK.TAPE_INK if active else UIK.INK
	(b.get_meta("tex") as TextureRect).texture = Icons.tex(str(b.get_meta("icon", "plus")), UIK.px(22), ink)
	(b.get_meta("label") as Label).add_theme_color_override("font_color", ink)
	var rest: StyleBoxFlat
	match mode:
		"active":
			rest = _bar_box(UIK.PRIMARY_500)
		"on":
			rest = _bar_box(Color(UIK.PRIMARY_500, 0.22), UIK.PRIMARY_500)
		_:
			rest = _bar_box(Color(0, 0, 0, 0))
	var hover := _bar_box(UIK.PRIMARY_300 if active else UIK.GRAY_600, UIK.PRIMARY_500 if mode == "on" else Color(0, 0, 0, 0))
	b.add_theme_stylebox_override("normal", rest)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("hover_pressed", hover)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _hold_btn(icon: String, set_fn: Callable, size: int) -> Button:
	var b := UIK.icon_btn(icon, func(): pass, "", size)
	var r := UIK.glass(size / 2)
	b.add_theme_stylebox_override("normal", r)
	b.button_down.connect(func(): set_fn.call(true))
	b.button_up.connect(func(): set_fn.call(false))
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	return b


func _on_tab(tab: String) -> void:
	if _top_name() == tab or (view_stack.size() > 0 and view_stack[0][0] == tab):
		close_sheet()
		return
	open_sheet(tab)


# ---------------------------------------------------------------- layout

func wide() -> bool:
	return get_viewport_rect().size.x >= UIK.px(900)


func layout() -> void:
	var vs := get_viewport_rect().size
	var m := float(UIK.px(12))
	top_left.position = Vector2(m, m)
	top_left.size = top_left.get_combined_minimum_size()
	top_right.size = top_right.get_combined_minimum_size()
	top_right.position = Vector2(vs.x - top_right.size.x - m, m)
	fps_label.position = Vector2(m + top_left.size.x + 12, m + 14)
	dock.size = dock.get_combined_minimum_size()
	dock.position = Vector2(m, vs.y - dock.size.y - m)
	slate.size = slate.custom_minimum_size
	slate.position = Vector2(vs.x - slate.size.x - m, vs.y - slate.size.y - m)
	toolbar.size = toolbar.get_combined_minimum_size()
	toolbar.position = Vector2(m, vs.y - toolbar.size.y - m)
	tool_hint.size = tool_hint.get_combined_minimum_size()
	tool_hint.position = Vector2((vs.x - tool_hint.size.x) / 2, vs.y - toolbar.size.y - tool_hint.size.y - m * 2.5)
	play_bar.size = play_bar.get_combined_minimum_size()
	play_bar.position = Vector2((vs.x - play_bar.size.x) / 2, m)
	pad.size = pad.get_combined_minimum_size()
	pad.position = Vector2(vs.x - pad.size.x - m - 2, vs.y - slate.size.y - pad.size.y - m * 3)
	restore_btn.size = restore_btn.get_combined_minimum_size()
	restore_btn.position = Vector2(m, vs.y - restore_btn.size.y - m)
	if _pv_bar and _pv_bar.visible:
		_pv_bar.size = _pv_bar.get_combined_minimum_size()
		_pv_bar.position = Vector2((vs.x - _pv_bar.size.x) / 2, m + (play_bar.size.y + m if play_bar.visible else 0.0))
	if wide():
		var w := float(UIK.px(400))
		sheet.position = Vector2(vs.x - w - 16, top_right.size.y + m * 2)
		sheet.size = Vector2(w, vs.y - sheet.position.y - slate.size.y - m * 3)
	else:
		var h := vs.y * 0.6
		sheet.position = Vector2(8, vs.y - h - dock.size.y - m * 2)
		sheet.size = Vector2(vs.x - 16, h)
	if timeline_panel.visible:
		# Docked above the dock; leaves room for the side panel on wide screens.
		var right := vs.x - m
		if sheet.visible and wide():
			right = sheet.position.x - m
		var tw_ := maxf(UIK.px(320), right - m)
		timeline_panel.size = Vector2(tw_, 0)
		var want := timeline_panel.get_combined_minimum_size().y - timeline_panel.view.custom_minimum_size.y + timeline_panel.view.wanted_height()
		var th := minf(want, vs.y * 0.45)
		timeline_panel.size = Vector2(tw_, th)
		timeline_panel.position = Vector2(m, vs.y - dock.size.y - th - m * 2)
	var tw := minf(vs.x * 0.92, UIK.px(460))
	var font := toast_label.get_theme_font("font")
	var fs := toast_label.get_theme_font_size("font_size")
	var text_w := font.get_string_size(toast_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + UIK.px(30)
	tw = minf(tw, maxf(text_w, UIK.px(120)))
	toast_label.custom_minimum_size.x = tw - UIK.px(24)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if text_w > tw else TextServer.AUTOWRAP_OFF
	toast_panel.size = Vector2(tw, 0)
	toast_panel.size = toast_panel.get_combined_minimum_size()
	toast_panel.position = Vector2((vs.x - toast_panel.size.x) / 2, UIK.px(72))
	frame_guide.queue_redraw()
	for c in modal.get_children():
		if c is Control:
			_center(c)


func _center(c: Control) -> void:
	var vs := get_viewport_rect().size
	c.size = Vector2(c.custom_minimum_size.x, 0)
	c.size = c.get_combined_minimum_size()
	c.position = (vs - c.size) / 2
	# Wrapped labels only know their height after a layout pass.
	await get_tree().process_frame
	if is_instance_valid(c) and c.is_inside_tree():
		c.size = Vector2(c.size.x, 0)
		c.size = c.get_combined_minimum_size()
		c.position = (vs - c.size) / 2


# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	if _toast_t > 0:
		_toast_t -= delta
		if _toast_t <= 0:
			toast_panel.visible = false
	fps_label.visible = App.device["show_fps"] and not clean and studio.in_studio
	if fps_label.visible:
		fps_label.text = "%d fps" % Engine.get_frames_per_second()
	undo_btn.disabled = not studio.can_undo()
	redo_btn.disabled = not studio.can_redo()
	var rec := studio.recorder
	if rec.active:
		var secs := float(rec.frames) / rec.fps
		slate_label.text = U.fmt_time(secs)
		slate_dot.modulate.a = 1.0 if fmod(Time.get_ticks_msec() / 500.0, 2.0) < 1.0 else 0.25
	if timeline_panel.visible:
		timeline_panel.tick()
		play_bar.visible = false
	elif studio.playing and not rec.active:
		play_bar.visible = true
		var total := studio.script_length()
		if studio.paused:
			play_label.text = "Directing at %s · tap a character to change what they do  " % TimelinePanel._fmt(studio.play_t)
		else:
			play_label.text = "Script  %s / %s" % [U.fmt_time(studio.play_t), U.fmt_time(total)]
		play_bar.size = play_bar.get_combined_minimum_size()
		play_bar.position.x = (get_viewport_rect().size.x - play_bar.size.x) / 2
		if studio.play_t > total + 1.0 and not studio.paused:
			stop_script()
	else:
		play_bar.visible = false
	var free := studio.camera.mode == "free"
	var kids := pad.get_children()
	(kids[0] as Control).visible = free
	(kids[1] as Control).visible = free
	(kids[2] as Control).visible = not free
	pad.visible = App.is_touch and not clean and not rec.active
	crosshair.visible = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not clean and not rec.active


func _top_name() -> String:
	return view_stack[-1][0] if not view_stack.is_empty() else ""


# ---------------------------------------------------------------- sheets

func open_sheet(name: String, arg: Variant = null) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	view_stack = [[name, arg]]
	render_sheet()


func push_view(name: String, arg: Variant = null) -> void:
	view_stack.append([name, arg])
	render_sheet()


func back_view() -> void:
	view_stack.pop_back()
	if view_stack.is_empty():
		close_sheet()
	else:
		render_sheet()


func close_sheet() -> void:
	view_stack.clear()
	sheet.visible = false
	for k in dock_btns:
		_bar_mode(dock_btns[k], "rest")


func render_sheet() -> void:
	if view_stack.is_empty():
		close_sheet()
		return
	var top: Array = view_stack[-1]
	var scroll := sheet_scroll.scroll_vertical
	var same: bool = sheet.visible and sheet_title.has_meta("view") and sheet_title.get_meta("view") == top[0]
	UIK.clear(sheet_body)
	var title: String = sheets.render(top[0], top[1], sheet_body)
	if title == "":
		back_view()
		return
	sheet_title.text = title
	sheet_title.set_meta("view", top[0])
	sheet_back.visible = view_stack.size() > 1
	sheet.visible = true
	var root_tab: String = view_stack[0][0]
	for k in dock_btns:
		var on: bool = k == root_tab
		_bar_mode(dock_btns[k], "active" if on else "rest")
	if same:
		await get_tree().process_frame
		sheet_scroll.scroll_vertical = scroll
	else:
		sheet_scroll.scroll_vertical = 0


# ---------------------------------------------------------------- toolbar

func render_toolbar() -> void:
	UIK.clear(toolbar_row)
	var t := studio.tools
	if t.kind == "":
		toolbar.visible = false
		tool_hint.visible = false
		dock.visible = not clean
		layout()
		return
	dock.visible = false
	toolbar.visible = not clean
	tool_hint.visible = not clean
	var hint := ""
	match t.kind:
		"blocks":
			var b := Blocks.get_block(t.block)
			toolbar_row.add_child(_tb_tex(Blocks.icon(t.block), "Block", func(): open_sheet("blocks")))
			toolbar_row.add_child(_tb("place", "place", "Place", t.mode == "place"))
			toolbar_row.add_child(_tb("break", "brk", "Break", t.mode == "break"))
			toolbar_row.add_child(_tb("pick", "pickI", "Pick", t.mode == "pick"))
			hint = {"place": "Tap to place " + str(b.get("name", "block")).to_lower(), "break": "Tap a block to break it", "pick": "Tap a block to copy it"}[t.mode]
			if not App.is_touch:
				hint += "  ·  right click breaks, middle click picks"
		"tiles":
			var top := studio.is_top()
			var custom_tile := t.tile >= TileSets.CUSTOM_BASE
			var ticon: Texture2D = studio.world.custom_icon(t.tile) if custom_tile else (PixelTopArt.ground_icon(maxi(1, t.tile)) if top else PixelTiles.icon(t.tile))
			toolbar_row.add_child(_tb_tex(ticon, "Ground" if top else "Tile", func(): open_sheet("tiles")))
			toolbar_row.add_child(_tb("place", "place", "Paint", t.mode == "place"))
			toolbar_row.add_child(_tb("break", "brk", "Erase", t.mode == "break"))
			toolbar_row.add_child(_tb("pick", "pickI", "Pick", t.mode == "pick"))
			var tn := "imported tile" if custom_tile else str((PixelTopArt.GROUND[maxi(1, t.tile)] if top else PixelTiles.get_tile(t.tile)).get("name", "tile")).to_lower()
			hint = {"place": "Tap or drag to paint " + tn, "break": "Tap or drag to erase tiles", "pick": "Tap a tile to copy it"}[t.mode]
			if not App.is_touch:
				hint += "  ·  right-drag erases"
		"pprefab":
			toolbar_row.add_child(_tb("pprefabs", "house", "Change", false))
			toolbar_row.add_child(_tb("oplace", "place", "Place", t.obj_mode == "place"))
			toolbar_row.add_child(_tb("oerase", "brk", "Erase", t.obj_mode == "erase"))
			var pname := ""
			if SpriteImport.is_key(t.pprefab):
				pname = SpriteImport.display_name(SpriteImport.id_of(t.pprefab))
			elif studio.is_top():
				pname = str(PixelTopArt.OBJECTS.get(t.pprefab, {"name": "object"})["name"])
			else:
				toolbar_row.add_child(_tb("flip", "rotate", "Flip", t.flip))
				pname = str(PixelTiles.PREFABS.get(t.pprefab, {"name": "building"})["name"])
			hint = "Tap the ground to place a " + pname.to_lower()
			if t.obj_mode == "erase":
				hint = "Tap or drag over trees, houses and objects to remove them" if studio.is_top() else "Tap a tree or building to remove all of it (the ground stays)"
			elif not App.is_touch:
				hint += "  ·  right click removes"
		"prefab":
			toolbar_row.add_child(_tb("prefabs", "house", "Change", false))
			toolbar_row.add_child(_tb("rot", "rotate", "Rotate", false))
			hint = "Tap the ground to build a " + str(VoxelWorld.PREFABS[t.prefab]["name"]).to_lower()
		"objects":
			if not t.sel.is_empty():
				toolbar_row.add_child(_tb("move", "move", "Move", t.moving))
				toolbar_row.add_child(_tb("prot", "rotate", "Rotate", false))
				toolbar_row.add_child(_tb("psize", "size", "Size", false))
				toolbar_row.add_child(_tb("pdel", "trash", "Delete", false))
				hint = "Tap where it should go" if t.moving else t.sel_name() + " selected"
			else:
				toolbar_row.add_child(_tb("objects", "tree", "Change", false))
				var pn: String = Props.display_name(studio.style_key, t.prop) if t.prop != "" else ""
				hint = ("Tap the ground to add a " + pn.to_lower() + ". Tap an object to edit it.") if pn != "" else "Tap an object to edit it"
		"terrain":
			toolbar_row.add_child(_tb("raise", "up", "Raise", t.terra == "raise"))
			toolbar_row.add_child(_tb("lower", "down", "Lower", t.terra == "lower"))
			toolbar_row.add_child(_tb("smooth", "smooth", "Smooth", t.terra == "smooth"))
			hint = "Press and drag on the ground. Two fingers or right-drag move the camera."
		"move_actor":
			var a := studio.actor_by_id(t.actor_id)
			hint = "Tap where " + (a.name if a else "they") + " should stand"
	toolbar_row.add_child(_tb("done", "check", "Done", false, true))
	tool_hint.text = "  " + hint + "  "
	layout()


func _tb(act: String, icon: String, text: String, on: bool, primary := false) -> Button:
	var b := _bar_button(icon, text)
	_bar_mode(b, "active" if primary else ("on" if on else "rest"))
	b.pressed.connect(func(): _tool_action(act))
	return b


func _tb_tex(tex: Texture2D, text: String, cb: Callable) -> Button:
	var b := _tb("", "cube", text, false)
	var tr: TextureRect = b.get_meta("tex")
	tr.texture = tex
	# Pictures (tiles, blocks) are bigger than icons: fit them in the icon box.
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(UIK.px(26), UIK.px(26))
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.expand_icon = false
	for c in b.pressed.get_connections():
		b.pressed.disconnect(c["callable"])
	b.pressed.connect(cb)
	return b


func _tool_action(a: String) -> void:
	var t := studio.tools
	match a:
		"done":
			t.set_tool("")
		"prefabs":
			open_sheet("prefabs")
		"pprefabs":
			open_sheet("pprefabs")
		"oplace", "oerase":
			t.obj_mode = "place" if a == "oplace" else "erase"
			render_toolbar()
		"flip":
			t.flip = not t.flip
			render_toolbar()
		"objects":
			open_sheet("objects")
		"place", "break", "pick":
			t.mode = a
			render_toolbar()
		"rot":
			t.rot = (t.rot + 1) % 4
			toast("Facing " + ["south", "west", "north", "east"][t.rot])
		"raise", "lower", "smooth":
			t.terra = a
			render_toolbar()
		"move":
			t.moving = not t.moving
			render_toolbar()
		"prot":
			t.rotate_sel()
		"psize":
			t.resize_sel()
		"pdel":
			t.delete_sel()


# ---------------------------------------------------------------- recording

# ---------------------------------------------------------------- shot preview

var _pv: Dictionary = {}
var _pv_bar: PanelContainer


func previewing() -> bool:
	return not _pv.is_empty()


## Looks through shot `i` of the shot list until you stop (bar or Esc); the
## camera then goes back to how it was.
func start_shot_preview(i: int) -> void:
	if i < 0 or i >= studio.shots.size():
		return
	var cam := studio.camera
	if _pv.is_empty():
		_pv = {"view": cam.to_dict(), "cine": cam.cine.duplicate(true), "free_pos": cam.free_pos}
	_pv["shot"] = i
	studio.apply_shot(studio.shots[i])
	close_sheet()
	if _pv_bar == null:
		_pv_bar = PanelContainer.new()
		_pv_bar.add_theme_stylebox_override("panel", _bar_panel())
		add_child(_pv_bar)
	UIK.clear(_pv_bar)
	var h := UIK.hbox(8)
	var l := UIK.label("Previewing “%s”" % str(studio.shots[i].get("name", "Shot")), 14, UIK.INK, true)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	h.add_child(UIK.btn("Back to shot", func(): stop_shot_preview(true), false, "undo"))
	h.add_child(UIK.btn("Stop preview", func(): stop_shot_preview(false), true, "close"))
	_pv_bar.add_child(h)
	_pv_bar.visible = true
	layout()


func stop_shot_preview(reopen := false) -> void:
	if _pv.is_empty():
		return
	var cam := studio.camera
	var v: Dictionary = _pv["view"]
	cam.cine = _pv["cine"]
	cam.free_pos = _pv["free_pos"]
	cam.set_mode(str(v.get("mode", "third")))
	cam.yaw = float(v.get("yaw", cam.yaw))
	cam.pitch = float(v.get("pitch", cam.pitch))
	cam.dist = float(v.get("dist", cam.dist))
	var i := int(_pv.get("shot", 0))
	_pv = {}
	if _pv_bar:
		_pv_bar.visible = false
	if reopen:
		open_sheet("film")
		push_view("shot", i)
	layout()


func toggle_record() -> void:
	if _counting:
		return
	if studio.recorder.active:
		studio.stop_take()
		return
	close_sheet()
	var n: int = int(App.settings["countdown"])
	if n > 0:
		_counting = true
		for i in range(n, 0, -1):
			countdown.text = str(i)
			countdown.visible = true
			App.ui("beep")
			await get_tree().create_timer(0.8).timeout
		countdown.visible = false
		_counting = false
	if studio.start_take():
		App.ui("go")
	else:
		toast("Recording couldn’t start.")


func _style_record(on: bool) -> void:
	var r := UIK.px(27)
	var rest := UIK.box(UIK.REC if on else UIK.GLASS, r, Color(1, 1, 1, 0.9) if on else UIK.GRAY_500, 2 if on else 1)
	var hover := UIK.box(UIK.REC.lightened(0.1) if on else Color(UIK.GRAY_700, 0.95), r, Color.WHITE if on else UIK.GRAY_300, 2 if on else 1)
	slate.add_theme_stylebox_override("normal", rest)
	slate.add_theme_stylebox_override("hover", hover)
	slate.add_theme_stylebox_override("pressed", hover)
	slate.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _on_recording(on: bool) -> void:
	_style_record(on)
	for n in [top_left, dock, toolbar, tool_hint]:
		n.modulate.a = 0.0 if on else 1.0
	if not on:
		slate_label.text = "Record"
		slate_dot.modulate.a = 1.0


func _on_progress(_frac: float) -> void:
	if studio.recorder.frames % 5 == 0:
		_refresh_progress()


func _on_take_done(path: String, secs: float) -> void:
	UIK.clear(modal)
	take += 1
	slate_label.text = "Record"
	var card := _card()
	var v: VBoxContainer = card.get_child(0)
	v.add_child(UIK.label("Saved", 22, UIK.INK, true))
	v.add_child(UIK.para("%s long · %s" % [U.fmt_time(secs), path.get_file()], 14))
	v.add_child(UIK.para(path.get_base_dir(), 12))
	var row := UIK.hbox()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UIK.btn("Open folder", func(): OS.shell_open(path.get_base_dir())))
	row.add_child(UIK.btn("Play", func(): OS.shell_open(path)))
	row.add_child(UIK.btn("Done", func(): UIK.clear(modal), true))
	v.add_child(row)
	modal.add_child(card)
	_center(card)


func show_progress(title: String) -> void:
	UIK.clear(modal)
	var card := _card()
	card.name = "progress"
	var v: VBoxContainer = card.get_child(0)
	v.add_child(UIK.label(title, 20, UIK.INK, true))
	var info := UIK.para("Starting…", 14, UIK.INK)
	info.name = "info"
	v.add_child(info)
	var bar := ProgressBar.new()
	bar.name = "bar"
	bar.custom_minimum_size = Vector2(UIK.px(320), UIK.px(14))
	bar.show_percentage = false
	v.add_child(bar)
	var note := UIK.para("Rendering every frame at full quality.", 12)
	note.name = "note"
	v.add_child(note)
	var row := UIK.hbox()
	row.name = "row"
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	modal.add_child(card)
	_center(card)
	# Keep the time left and the cool-down countdown ticking.
	var t := Timer.new()
	t.wait_time = 0.5
	t.autostart = true
	t.timeout.connect(_refresh_progress)
	card.add_child(t)
	_progress_buttons()
	_refresh_progress()


## Pause / resume, save for later (resumable exports), cancel.
func _progress_buttons() -> void:
	var p := modal.get_node_or_null("progress")
	if p == null:
		return
	var row: HBoxContainer = p.find_child("row", true, false)
	UIK.clear(row)
	var rec := studio.recorder
	if rec.paused:
		row.add_child(UIK.btn("Resume", func():
			rec.resume()
			_progress_buttons()
			_refresh_progress(), true, "playtri"))
	else:
		row.add_child(UIK.btn("Pause", func():
			rec.pause()
			_progress_buttons()
			_refresh_progress(), false, "pause"))
	if rec.can_suspend():
		row.add_child(UIK.btn("Finish later", func():
			UIK.clear(modal)
			rec.suspend(), false, "check"))
	row.add_child(UIK.danger("Cancel", func():
		rec.cancel()
		UIK.clear(modal)))


func _refresh_progress() -> void:
	var p := modal.get_node_or_null("progress")
	if p == null or not studio.recorder.active:
		return
	var s := studio.recorder.status()
	var fr := float(studio.recorder.fps)
	var parts := ["Shot %d of %d" % [s["shot"], s["shots"]], "%s / %s" % [U.fmt_time(s["frames"] / fr), U.fmt_time(s["total"] / fr)]]
	if s["cooling"]:
		parts.append("cooling down, back in %ds" % int(ceil(s["cool_left"])))
	elif s["paused"]:
		parts.append("paused")
	elif float(s["eta"]) >= 0.0:
		parts.append("about %s left" % U.fmt_time(float(s["eta"]) + 1.0))
	(p.find_child("info", true, false) as Label).text = "  ·  ".join(parts)
	(p.find_child("bar", true, false) as ProgressBar).value = 100.0 * float(s["frames"]) / maxf(1.0, float(s["total"]))
	var note := "Rendering every frame at full quality."
	if s["cooling"]:
		note = "Rendering slowed right down, so the device is probably hot. Taking a short break (Settings → Pause exports to cool down)."
	elif s["resumable"]:
		note += " You can pause, or finish later: it carries on where it stopped, even after closing the app."
	(p.find_child("note", true, false) as Label).text = note
	var paused_btn := (p.find_child("row", true, false) as Node).get_child(0) as Button
	if paused_btn and paused_btn.text != ("Resume" if s["paused"] else "Pause"):
		_progress_buttons()


func _card() -> PanelContainer:
	var card := PanelContainer.new()
	var sb := UIK.box(UIK.SURFACE, 22, UIK.LINE)
	sb.content_margin_left = UIK.px(20)
	sb.content_margin_right = UIK.px(20)
	sb.content_margin_top = UIK.px(18)
	sb.content_margin_bottom = UIK.px(18)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = UIK.px(16)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size.x = minf(UIK.px(440), get_viewport_rect().size.x - 32)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_child(UIK.vbox(10))
	return card


## Starts the film export, offering to carry on an unfinished one.
func export_film_flow() -> void:
	var j := studio.unfinished_export()
	if j.is_empty():
		_start_film(false, {})
		return
	UIK.clear(modal)
	var card := _card()
	var v: VBoxContainer = card.get_child(0)
	v.add_child(UIK.label("Carry on exporting?", 20, UIK.INK, true))
	v.add_child(UIK.para("An export of this scene stopped at %d%% (%s of %s). Carry on from there, or start again from the beginning." % [
		int(100.0 * float(j["done"]) / maxf(1.0, float(j["total"]))), U.fmt_time(float(j["done"]) / float(j["fps"])), U.fmt_time(float(j["total"]) / float(j["fps"]))], 14))
	var row := UIK.hbox()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UIK.btn("Start again", func(): _start_film(false, {})))
	row.add_child(UIK.btn("Carry on", func(): _start_film(true, j), true, "playtri"))
	v.add_child(row)
	modal.add_child(card)
	_center(card)


func _start_film(resume: bool, j: Dictionary) -> void:
	UIK.clear(modal)
	if not resume:
		Recorder.discard_job(str(studio.project_id))
	close_sheet()
	if studio.export_film(j):
		show_progress("Carrying on the export" if resume else "Exporting film")


func ask(msg: String, yes: String, cb: Callable) -> void:
	UIK.clear(modal)
	var card := _card()
	var v: VBoxContainer = card.get_child(0)
	var l := UIK.para(msg, 16, UIK.INK)
	v.add_child(l)
	var row := UIK.hbox()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UIK.btn("Cancel", func(): UIK.clear(modal)))
	row.add_child(UIK.btn(yes, func():
		UIK.clear(modal)
		cb.call(), true))
	v.add_child(row)
	modal.add_child(card)
	_center(card)


## Asks for a short piece of text (a name). Enter or the button confirms;
## an empty answer keeps the suggested text.
## With `choices` ([[key, label, description], ...]) it also asks to pick
## one, and `cb` gets (text, key).
func prompt(title: String, suggested: String, placeholder: String, yes: String, cb: Callable, choices: Array = []) -> void:
	UIK.clear(modal)
	var card := _card()
	var v: VBoxContainer = card.get_child(0)
	v.add_child(UIK.label(title, 20, UIK.INK, true))
	var e := UIK.line_edit(suggested, placeholder, func(_t): pass)
	e.max_length = 40
	v.add_child(e)
	var picked := [choices[0][0] if not choices.is_empty() else ""]
	if not choices.is_empty():
		var g := UIK.grid(2, 8)
		var tiles := []
		for c in choices:
			var tl := UIK.tile(c[3] if c.size() > 3 else "film", c[1], c[2], c[0] == picked[0], func(): pass)
			tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tiles.append(tl)
			g.add_child(tl)
		for i in tiles.size():
			(tiles[i] as Button).pressed.connect(func():
				picked[0] = choices[i][0]
				for j in tiles.size():
					UIK._card_states(tiles[j], j == i, 16))
		v.add_child(g)
	var done := func():
		var n := e.text.strip_edges()
		UIK.clear(modal)
		if choices.is_empty():
			cb.call(n if n != "" else suggested)
		else:
			cb.call(n if n != "" else suggested, picked[0])
	e.text_submitted.connect(func(_t): done.call())
	var row := UIK.hbox()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UIK.btn("Cancel", func(): UIK.clear(modal)))
	row.add_child(UIK.btn(yes, done, true))
	v.add_child(row)
	modal.add_child(card)
	_center(card)
	e.grab_focus()
	e.select_all()


func screenshot() -> void:
	close_sheet()
	var vs := get_viewport_rect().size
	var path: String = await studio.recorder.screenshot(App.export_size(vs.x / vs.y))
	if path != "":
		toast("Saved " + path.get_file() + " to " + path.get_base_dir().get_file())
	else:
		toast("Screenshot couldn’t be made here.")


## Opens or closes timeline mode (T).
func toggle_timeline() -> void:
	if timeline_panel.visible:
		timeline_panel.close()
	else:
		if not wide():
			close_sheet()
		timeline_panel.open()
	layout()


func play_script() -> void:
	if not studio.has_script():
		toast("Add a few lines to the script first.")
		return
	close_sheet()
	studio.play_scene(true)
	play_pause.icon = Icons.tex("pause", UIK.px(22), UIK.INK)


## Director mode from the script play bar: freeze the scene on the current
## moment so characters can be moved or given new actions, then carry on.
func toggle_pause() -> void:
	studio.paused = not studio.paused
	play_pause.icon = Icons.tex("playtri" if studio.paused else "pause", UIK.px(22), UIK.INK)
	play_pause.tooltip_text = "Resume" if studio.paused else "Pause and direct"
	if studio.paused and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _top_name() == "actor":
		render_sheet()


func stop_script() -> void:
	studio.play_scene(false)
	for a in studio.actors:
		a.goto = {}
		a.set_behavior(a.base_behavior, false)


# ---------------------------------------------------------------- misc

## At home only dialogs and toasts show; in the studio everything does.
func _update_shade() -> void:
	var n := 0
	for c in modal.get_children():
		if not c.is_queued_for_deletion():
			n += 1
	modal_shade.visible = n > 0


func set_home_mode(on: bool) -> void:
	if on:
		timeline_panel.close()
	for c in get_children():
		if c == modal or c == toast_panel or c == modal_shade:
			continue
		if c is Control:
			(c as Control).visible = not on
	if not on:
		close_sheet()
		restore_btn.visible = false
		joy.visible = false
		countdown.visible = false
		toolbar.visible = false
		tool_hint.visible = false
		play_bar.visible = false
		timeline_panel.visible = false
		set_clean(false)
		render_toolbar()


func set_clean(on: bool) -> void:
	clean = on
	if on:
		close_sheet()
		timeline_panel.close()
	for n in [top_left, top_right, slate]:
		n.visible = not on
	dock.visible = not on and studio.tools.kind == ""
	toolbar.visible = not on and studio.tools.kind != ""
	tool_hint.visible = toolbar.visible
	restore_btn.visible = on
	frame_guide.queue_redraw()


func toast(msg: String) -> void:
	toast_label.text = msg
	toast_panel.visible = true
	_toast_t = 3.2
	layout()


func _undo() -> void:
	studio.undo()


func _redo() -> void:
	studio.redo()


func _dialog_cb(ok: bool, paths: PackedStringArray, _f: int, cb: Callable) -> void:
	if ok and paths.size() > 0:
		cb.call(paths[0])


## Opens a file picker; `cb` gets the chosen path.
func pick_file(filters: PackedStringArray, cb: Callable, title := "Open") -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show(title, "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE, filters,
			_dialog_cb.bind(cb))
		return
	var fd := FileDialog.new()
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.filters = filters
	fd.title = title
	fd.use_native_dialog = true
	fd.file_selected.connect(func(p): cb.call(p))
	fd.canceled.connect(fd.queue_free)
	add_child(fd)
	fd.popup_centered_ratio(0.7)


## Picks several files at once; `cb` gets a PackedStringArray of paths.
func pick_files(filters: PackedStringArray, cb: Callable, title := "Open") -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show(title, "", "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILES, filters,
			func(ok: bool, paths: PackedStringArray, _f: int) -> void:
				if ok and paths.size() > 0:
					cb.call(paths))
		return
	var fd := FileDialog.new()
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILES
	fd.filters = filters
	fd.title = title
	fd.use_native_dialog = true
	fd.files_selected.connect(func(p): cb.call(p))
	add_child(fd)
	fd.popup_centered_ratio(0.7)


func save_file(default_name: String, filters: PackedStringArray, cb: Callable) -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Save", OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS), default_name, false, DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, filters,
			_dialog_cb.bind(cb))
		return
	var fd := FileDialog.new()
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	fd.filters = filters
	fd.current_file = default_name
	fd.use_native_dialog = true
	fd.file_selected.connect(func(p): cb.call(p))
	add_child(fd)
	fd.popup_centered_ratio(0.7)


## Letterbox guide for the chosen frame aspect (9:16, 1:1...).
class FrameGuide:
	extends Control

	func frame_rect() -> Rect2:
		var vs := get_viewport_rect().size
		var r: float = App.FRAMES.get(App.settings["frame"], 0.0)
		if r <= 0:
			return Rect2(Vector2.ZERO, vs)
		var w: float
		var h: float
		if vs.x / vs.y > r:
			h = vs.y
			w = h * r
		else:
			w = vs.x
			h = w / r
		return Rect2((vs - Vector2(w, h)) / 2, Vector2(w, h))

	func _draw() -> void:
		if App.settings["frame"] == "full":
			return
		var vs := get_viewport_rect().size
		var f := frame_rect()
		var c := Color(0.016, 0.027, 0.047, 0.82)
		draw_rect(Rect2(0, 0, vs.x, f.position.y), c)
		draw_rect(Rect2(0, f.end.y, vs.x, vs.y - f.end.y), c)
		draw_rect(Rect2(0, f.position.y, f.position.x, f.size.y), c)
		draw_rect(Rect2(f.end.x, f.position.y, vs.x - f.end.x, f.size.y), c)
		draw_rect(f, Color(1, 1, 1, 0.22), false, 1.0)

	func _process(_d: float) -> void:
		queue_redraw()


## Small aiming mark shown while the mouse controls the camera.
class Crosshair:
	extends Control

	func _draw() -> void:
		var c := get_viewport_rect().size / 2
		var col := Color(1, 1, 1, 0.85)
		draw_line(c + Vector2(-9, 0), c + Vector2(-3, 0), col, 2.0)
		draw_line(c + Vector2(3, 0), c + Vector2(9, 0), col, 2.0)
		draw_line(c + Vector2(0, -9), c + Vector2(0, -3), col, 2.0)
		draw_line(c + Vector2(0, 3), c + Vector2(0, 9), col, 2.0)


class ClapStripe:
	extends Control

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(0, 0, w, h), Color("1d222b"))
		var x := -h
		var i := 0
		while x < w + h:
			var col := Color("f3f3f3") if i % 2 == 0 else Color("1d222b")
			if get_parent() and get_parent().get_parent() is Hud and (get_parent().get_parent() as Hud).studio.recorder.active:
				col = Color("ef4444") if i % 2 == 0 else Color("1d222b")
			draw_colored_polygon(PackedVector2Array([Vector2(x, h), Vector2(x + 10, h), Vector2(x + 10 + h * 0.7, 0), Vector2(x + h * 0.7, 0)]), col)
			x += 10
			i += 1

	func _process(_d: float) -> void:
		queue_redraw()


## On-screen joystick for phones (drawn where the thumb lands).
class Joystick:
	extends Control
	var center := Vector2.ZERO
	var knob := Vector2.ZERO
	const R := 52.0

	func _draw() -> void:
		draw_circle(center, R + 6, Color(0.06, 0.09, 0.13, 0.45))
		draw_arc(center, R + 6, 0, TAU, 48, Color(1, 1, 1, 0.18), 1.5, true)
		draw_circle(center + knob * R, 24, Color(1, 1, 1, 0.85))
