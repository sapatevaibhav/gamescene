class_name TimelinePanel
extends PanelContainer
## Timeline mode, docked along the bottom of the studio: transport controls,
## a ruler with the playhead, one track for the camera and one per character.
## Character tracks show script cues as blocks and keyframes as diamonds.
##   - Click or drag the ruler / an empty spot to scrub.
##   - Drag a diamond to retime a key; drag a cue block to move it, or its
##     right edge to change how long it lasts.
##   - Click a name to pick the track that "Key" records into.

var hud: Hud
var studio: Studio
var view := TimelineView.new()
var bar := HFlowContainer.new()
var play_btn: Button
var time_label := Label.new()
var key_btn: Button
var place_btn: Button
var ease_btn: Button
var del_btn: Button
var loop := false
var cam_preview := true
## The sound clip picked on the Sound row (one of studio.audio), or {}.
var sel_clip: Dictionary = {}
var _prev_cam_mode := ""


func _init(h: Hud) -> void:
	hud = h
	studio = h.studio
	add_theme_stylebox_override("panel", UIK.box(UIK.SURFACE, 18, UIK.LINE))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := UIK.vbox(6)
	bar.add_theme_constant_override("h_separation", UIK.px(6))
	bar.add_theme_constant_override("v_separation", UIK.px(6))
	v.add_child(bar)
	view.panel = self
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(view)
	add_child(v)
	visible = false


func open() -> void:
	visible = true
	view.sel_track = studio.player.name if studio.player else Timeline.CAM
	view.sel_key = -1
	studio.seek(0.0)
	_sync_camera()
	rebuild_bar()


func close() -> void:
	if not visible:
		return
	visible = false
	studio.play_scene(false)
	for a in studio.actors:
		a.goto = {}
		a.set_behavior(a.base_behavior, false)
	studio.reset_to_start()
	studio.playing = false
	_restore_camera()


func is_playing() -> bool:
	return studio.playing and not studio.paused


func toggle_play() -> void:
	if is_playing():
		studio.paused = true
	else:
		if studio.play_t >= _end() - 0.01:
			studio.seek(0.0)
		studio.playing = true
		studio.paused = false
	_sync_camera()
	rebuild_bar()


func rewind() -> void:
	studio.seek(0.0)
	rebuild_bar()


func scrub(t: float) -> void:
	studio.seek(clampf(t, 0.0, view.span))
	_sync_camera()
	if play_btn and not studio.paused:
		rebuild_bar()


## Called every frame by the HUD while open: stops or loops at the end.
func tick() -> void:
	if is_playing() and studio.play_t >= _end():
		if loop:
			studio.seek(0.0)
			studio.paused = false
		else:
			studio.paused = true
			rebuild_bar()
	time_label.text = "%s / %s" % [_fmt(studio.play_t), _fmt(_end())]
	view.queue_redraw()


func _end() -> float:
	return maxf(1.0, studio.script_length())


static func _fmt(t: float) -> String:
	return "%d:%04.1f" % [floori(t / 60.0), fmod(t, 60.0)]


# ---------------------------------------------------------------- camera

func _sync_camera() -> void:
	var want := cam_preview and studio.timeline.has_track(Timeline.CAM)
	var cam := studio.camera
	if want and cam.mode != "keys":
		_prev_cam_mode = cam.mode
		cam.set_mode("keys")
	elif not want and cam.mode == "keys":
		_restore_camera()


func _restore_camera() -> void:
	var cam := studio.camera
	if cam.mode == "keys":
		cam.set_mode(_prev_cam_mode if _prev_cam_mode != "" and _prev_cam_mode != "keys" else "free")
	_prev_cam_mode = ""


# ---------------------------------------------------------------- keys

func add_key() -> void:
	var tr_name := view.sel_track
	var t := snappedf(studio.play_t, 0.01)
	if tr_name == Timeline.CAM:
		if studio.camera.mode == "keys":
			cam_preview = false
			_sync_camera()
			hud.toast("Camera preview is off so you can frame the shot. Move the camera, then press Key again.")
			rebuild_bar()
			return
		view.sel_key = studio.timeline.set_key(Timeline.CAM, Timeline.camera_key(t, studio.camera))
	else:
		var a := studio.actor_by_name(tr_name)
		if a == null:
			return
		view.sel_key = studio.timeline.set_key(tr_name, Timeline.actor_key(t, a))
	studio.mark_dirty()
	_sync_camera()
	rebuild_bar()


## Puts the picked character where the camera is aiming and keys them there.
func place_at_aim() -> void:
	var a := studio.actor_by_name(view.sel_track)
	if a == null:
		return
	var cam := studio.camera
	var hit: Dictionary = studio.world.pick(cam.global_position, -cam.global_basis.z, 120.0)
	if hit.is_empty():
		hud.toast("Point the camera at the ground first.")
		return
	var p: Vector3 = hit["point"]
	a.pos = Vector3(p.x, studio.world.ground_at(p.x, p.z), p.z)
	a.vel = Vector3.ZERO
	a.animate(0.0, a == studio.player)
	add_key()


func delete_key() -> void:
	if view.sel_key < 0:
		return
	studio.timeline.remove_key(view.sel_track, view.sel_key)
	view.sel_key = -1
	studio.mark_dirty()
	key_edited()


func toggle_ease() -> void:
	var arr := studio.timeline.track(view.sel_track)
	if view.sel_key < 0 or view.sel_key >= arr.size():
		return
	var k: Dictionary = arr[view.sel_key]
	k["e"] = "l" if k.get("e", "l") == "s" else "s"
	studio.mark_dirty()
	key_edited()


## Re-runs the scene to the playhead after keys or cues changed.
func key_edited() -> void:
	studio.seek(studio.play_t)
	_sync_camera()
	rebuild_bar()


func select(track_name: String, key_i: int) -> void:
	var changed := track_name != view.sel_track or key_i != view.sel_key
	view.sel_track = track_name
	view.sel_key = key_i
	if track_name != TimelineView.SOUND and not sel_clip.is_empty():
		sel_clip = {}
		changed = true
	if changed:
		rebuild_bar()


func select_clip(c: Dictionary) -> void:
	view.sel_track = TimelineView.SOUND
	view.sel_key = -1
	sel_clip = c
	rebuild_bar()
	view.queue_redraw()


func delete_clip() -> void:
	if sel_clip.is_empty():
		return
	studio.audio.erase(sel_clip)
	sel_clip = {}
	studio.mark_dirty()
	key_edited()


# ---------------------------------------------------------------- toolbar

func rebuild_bar() -> void:
	# The time label is reused across rebuilds, so keep it out of the clear.
	if time_label.get_parent():
		time_label.get_parent().remove_child(time_label)
	UIK.clear(bar)
	play_btn = UIK.icon_btn("pause" if is_playing() else "playtri", toggle_play, "Play / pause (T toggles the timeline)", 38, false)
	bar.add_child(play_btn)
	bar.add_child(UIK.icon_btn("undo", rewind, "Back to the start", 38, false))
	time_label.add_theme_font_size_override("font_size", UIK.px(13))
	time_label.add_theme_color_override("font_color", UIK.INK)
	time_label.custom_minimum_size = Vector2(UIK.px(92), UIK.px(38))
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(time_label)
	bar.add_child(UIK.chip("Loop", loop, func(): loop = not loop; rebuild_bar()))
	if view.sel_track == TimelineView.SOUND:
		bar.add_child(UIK.btn("Add sound", func(): hud.open_sheet("sounds"), true, "plus"))
		if not sel_clip.is_empty():
			bar.add_child(UIK.btn("Edit", func(): hud.open_sheet("clip"), false, "speaker"))
			del_btn = UIK.icon_btn("trash", delete_clip, "Remove sound", 38, false)
			bar.add_child(del_btn)
		bar.add_child(UIK.icon_btn("close", hud.toggle_timeline, "Close timeline", 38, false))
		tick()
		hud.layout()
		return
	var who := "Camera" if view.sel_track == Timeline.CAM else view.sel_track
	key_btn = UIK.btn("Key " + who, add_key, true, "pin")
	bar.add_child(key_btn)
	if view.sel_track != Timeline.CAM:
		place_btn = UIK.btn("Place at aim", place_at_aim, false, "place")
		bar.add_child(place_btn)
	if view.sel_key >= 0:
		var arr := studio.timeline.track(view.sel_track)
		if view.sel_key < arr.size():
			var smooth: bool = arr[view.sel_key].get("e", "l") == "s"
			ease_btn = UIK.chip("Smooth" if smooth else "Linear", smooth, toggle_ease)
			bar.add_child(ease_btn)
			del_btn = UIK.icon_btn("trash", delete_key, "Delete key", 38, false)
			bar.add_child(del_btn)
	if studio.timeline.has_track(Timeline.CAM):
		bar.add_child(UIK.chip("Camera preview", cam_preview, func():
			cam_preview = not cam_preview
			_sync_camera()
			rebuild_bar()))
	bar.add_child(UIK.icon_btn("close", hud.toggle_timeline, "Close timeline", 38, false))
	tick()
	hud.layout()


## The track area: ruler, rows, cue blocks, key diamonds and the playhead.
class TimelineView:
	extends Control

	var panel: TimelinePanel
	var sel_track := ""
	var sel_key := -1
	## Seconds visible across the lanes; fixed while dragging.
	var span := 15.0
	var scroll := 0
	var _drag := ""  # "", "scrub", "key", "cue", "cue_end"
	var _drag_cue: Dictionary = {}
	var _drag_off := 0.0
	var _pending_seek := -1.0

	const ACTION_COLORS := {"say": UIK.SECONDARY_500, "walkto": Color("4CAF7A"), "runto": Color("3E9B68")}
	## Row id of the sound clips.
	const SOUND := "♪sound"
	const SOUND_COLOR := Color("8A6BD8")

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true
		custom_minimum_size.y = UIK.px(120)

	func _name_w() -> float:
		return float(UIK.px(96))

	func _row_h() -> float:
		return float(UIK.px(28))

	func _ruler_h() -> float:
		return float(UIK.px(22))

	func rows() -> Array:
		var r := [Timeline.CAM, SOUND]
		for a in panel.studio.actors:
			r.append(a.name)
		return r

	func wanted_height() -> float:
		return _ruler_h() + _row_h() * rows().size() + UIK.px(4)

	func _lane_w() -> float:
		return maxf(10.0, size.x - _name_w() - UIK.px(10))

	func t_to_x(t: float) -> float:
		return _name_w() + t / span * _lane_w()

	func x_to_t(x: float) -> float:
		return clampf((x - _name_w()) / _lane_w() * span, 0.0, span)

	func _row_y(i: int) -> float:
		return _ruler_h() + (i - scroll) * _row_h()

	func _row_at(y: float) -> int:
		if y < _ruler_h():
			return -1
		return int((y - _ruler_h()) / _row_h()) + scroll

	func _process(_dt: float) -> void:
		if _pending_seek >= 0.0:
			var t := _pending_seek
			_pending_seek = -1.0
			panel.scrub(t)
		if _drag == "":
			var want := maxf(15.0, ceilf(panel.studio.script_length() * 1.25 + 2.0))
			if absf(want - span) > 0.01:
				span = want
				queue_redraw()

	func _draw() -> void:
		var st := panel.studio
		var font := get_theme_default_font()
		var fs := UIK.px(12)
		var nw := _name_w()
		var rh := _row_h()
		var rr := rows()
		draw_rect(Rect2(Vector2.ZERO, size), UIK.GRAY_900)
		# Ruler.
		var step := 1.0
		for s in [1.0, 2.0, 5.0, 10.0, 15.0, 30.0, 60.0]:
			step = s
			if _lane_w() / span * s >= UIK.px(44):
				break
		var t := 0.0
		while t <= span + 1e-3:
			var x := t_to_x(t)
			draw_line(Vector2(x, _ruler_h() - UIK.px(6)), Vector2(x, size.y), Color(UIK.GRAY_600, 0.5))
			draw_string(font, Vector2(x + 3, _ruler_h() - UIK.px(8)), "%ds" % int(t), HORIZONTAL_ALIGNMENT_LEFT, -1, UIK.px(11), UIK.MUTED)
			t += step
		# Rows.
		for i in rr.size():
			var y := _row_y(i)
			if y + rh < _ruler_h() or y > size.y:
				continue
			var tn: String = rr[i]
			var on := tn == sel_track
			draw_rect(Rect2(0, y, size.x, rh - 1), Color(UIK.TAPE, 0.10) if on else (Color(UIK.GRAY_800, 0.9) if i % 2 == 0 else Color(UIK.GRAY_800, 0.6)))
			var label := "Camera" if tn == Timeline.CAM else ("♪ Sound" if tn == SOUND else tn)
			if st.player and tn == st.player.name:
				label = "★ " + label
			draw_string(font, Vector2(UIK.px(8), y + rh * 0.5 + fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, nw - UIK.px(12), fs, UIK.TAPE if on else UIK.INK)
			if tn == SOUND:
				_draw_clips(y, font)
				continue
			if tn != Timeline.CAM:
				_draw_cues(tn, y, font)
			_draw_keys(tn, y, on)
		draw_line(Vector2(nw, 0), Vector2(nw, size.y), UIK.LINE)
		# Playhead.
		var px := t_to_x(st.play_t)
		draw_line(Vector2(px, 0), Vector2(px, size.y), UIK.REC, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(px - 6, 0), Vector2(px + 6, 0), Vector2(px, 8)]), UIK.REC)

	func _draw_cues(tn: String, y: float, font: Font) -> void:
		var rh := _row_h()
		for c in panel.studio.cues:
			if str(c.get("actor", "")) != tn:
				continue
			var x0 := t_to_x(float(c.get("start", 0)))
			var x1 := t_to_x(float(c.get("start", 0)) + float(c.get("dur", 3)))
			var col: Color = ACTION_COLORS.get(c.get("action", ""), UIK.GRAY_500)
			var r := Rect2(x0, y + 4, maxf(4.0, x1 - x0), rh - 9)
			draw_style_box(UIK.box(Color(col, 0.75), 6), r)
			var txt: String = c.get("action", "")
			if txt == "say":
				txt = "“%s”" % str(c.get("text", ""))
			draw_string(font, Vector2(x0 + 5, y + rh * 0.5 + UIK.px(4)), txt, HORIZONTAL_ALIGNMENT_LEFT, maxf(0.0, r.size.x - 8), UIK.px(11), Color.WHITE)

	func _draw_clips(y: float, font: Font) -> void:
		var rh := _row_h()
		for c in panel.studio.audio:
			var x0 := t_to_x(float(c.get("start", 0)))
			var x1 := t_to_x(float(c.get("start", 0)) + SoundDirector.clip_len(c))
			var r := Rect2(x0, y + 4, maxf(4.0, x1 - x0), rh - 9)
			var sel: bool = c == panel.sel_clip
			draw_style_box(UIK.box(Color(SOUND_COLOR, 0.95 if sel else 0.7), 6, UIK.TAPE if sel else Color(0, 0, 0, 0), 2 if sel else 0), r)
			# Where a shorter sound loops back to its start.
			var ln := Sounds.length(str(c.get("src", "")))
			if ln > 0.0:
				var tl := float(c.get("start", 0)) + ln
				while tl < float(c.get("start", 0)) + SoundDirector.clip_len(c) - 0.05:
					var lx := t_to_x(tl)
					draw_line(Vector2(lx, y + 6), Vector2(lx, y + rh - 7), Color(1, 1, 1, 0.35), 1.0)
					tl += ln
			draw_string(font, Vector2(x0 + 5, y + rh * 0.5 + UIK.px(4)), "♪ " + Sounds.label(str(c.get("src", ""))), HORIZONTAL_ALIGNMENT_LEFT, maxf(0.0, r.size.x - 8), UIK.px(11), Color.WHITE)

	func _hit_clip(x: float) -> Array:
		var arr: Array = panel.studio.audio
		for i in range(arr.size() - 1, -1, -1):
			var c: Dictionary = arr[i]
			var x0 := t_to_x(float(c.get("start", 0)))
			var x1 := t_to_x(float(c.get("start", 0)) + SoundDirector.clip_len(c))
			if x >= x0 - 2 and x <= x1 + 4:
				return [c, x1 - x < UIK.px(8)]
		return []

	func _draw_keys(tn: String, y: float, on_row: bool) -> void:
		var arr := panel.studio.timeline.track(tn)
		var cy := y + _row_h() * 0.5
		var r := float(UIK.px(6))
		for i in arr.size():
			var x := t_to_x(float(arr[i]["t"]))
			# No line into a jump key: the character isn't walked there.
			if i + 1 < arr.size() and not arr[i + 1].get("j", false):
				draw_line(Vector2(x, cy), Vector2(t_to_x(float(arr[i + 1]["t"])), cy), Color(UIK.TAPE, 0.45), 2.0)
			var sel := on_row and i == sel_key
			var col := UIK.TAPE if sel else (UIK.SECONDARY_300 if tn == Timeline.CAM else UIK.INK)
			if arr[i].get("j", false):
				var q := r * 0.8
				draw_rect(Rect2(x - q, cy - q, q * 2, q * 2), col)
				continue
			var pts := PackedVector2Array([Vector2(x, cy - r), Vector2(x + r, cy), Vector2(x, cy + r), Vector2(x - r, cy)])
			draw_colored_polygon(pts, col)
			if arr[i].get("e", "l") == "s":
				draw_circle(Vector2(x, cy), 2.0, UIK.GRAY_900)

	func _hit_key(tn: String, x: float) -> int:
		var arr := panel.studio.timeline.track(tn)
		var best := -1
		var bd := float(UIK.px(9))
		for i in arr.size():
			var d := absf(t_to_x(float(arr[i]["t"])) - x)
			if d <= bd:
				bd = d
				best = i
		return best

	func _hit_cue(tn: String, x: float) -> Array:
		for c in panel.studio.cues:
			if str(c.get("actor", "")) != tn:
				continue
			var x0 := t_to_x(float(c.get("start", 0)))
			var x1 := t_to_x(float(c.get("start", 0)) + float(c.get("dur", 3)))
			if x >= x0 - 2 and x <= x1 + 4:
				return [c, x1 - x < UIK.px(8)]
		return []

	func _gui_input(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb:
			if mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and mb.pressed:
				var vis := int((size.y - _ruler_h()) / _row_h())
				var mx := maxi(0, rows().size() - vis)
				scroll = clampi(scroll + (1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, mx)
				queue_redraw()
				accept_event()
				return
			if mb.button_index != MOUSE_BUTTON_LEFT:
				return
			accept_event()
			if mb.pressed:
				_press(mb.position)
			else:
				if _drag in ["key", "cue", "cue_end"]:
					panel.studio.mark_dirty()
					panel.key_edited()
				_drag = ""
			return
		var mm := e as InputEventMouseMotion
		if mm and _drag != "":
			accept_event()
			_motion(mm.position)

	func _press(p: Vector2) -> void:
		var ri := _row_at(p.y)
		var rr := rows()
		if ri >= 0 and ri < rr.size():
			var tn: String = rr[ri]
			if p.x < _name_w():
				panel.select(tn, -1)
				queue_redraw()
				return
			if tn == SOUND:
				var hcl := _hit_clip(p.x)
				if not hcl.is_empty():
					panel.select_clip(hcl[0])
					_drag_cue = hcl[0]
					_drag = "cue_end" if hcl[1] else "cue"
					_drag_off = x_to_t(p.x) - float(_drag_cue.get("start", 0))
					return
				panel.select(tn, -1)
				_drag = "scrub"
				_pending_seek = x_to_t(p.x)
				queue_redraw()
				return
			var ki := _hit_key(tn, p.x)
			if ki >= 0:
				panel.select(tn, ki)
				_drag = "key"
				queue_redraw()
				return
			if tn != Timeline.CAM:
				var hc := _hit_cue(tn, p.x)
				if not hc.is_empty():
					panel.select(tn, -1)
					_drag_cue = hc[0]
					_drag = "cue_end" if hc[1] else "cue"
					_drag_off = x_to_t(p.x) - float(_drag_cue.get("start", 0))
					return
			panel.select(tn, -1)
		_drag = "scrub"
		_pending_seek = x_to_t(p.x)
		queue_redraw()

	func _motion(p: Vector2) -> void:
		var t := x_to_t(p.x)
		match _drag:
			"scrub":
				_pending_seek = t
			"key":
				sel_key = panel.studio.timeline.move_key(sel_track, sel_key, t)
			"cue":
				_drag_cue["start"] = snappedf(maxf(0.0, t - _drag_off), 0.1)
			"cue_end":
				_drag_cue["dur"] = snappedf(maxf(0.5, t - float(_drag_cue.get("start", 0))), 0.1)
		queue_redraw()


func _notification(what: int) -> void:
	# The time label lives outside the tree until the bar is first built.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(time_label) and time_label.get_parent() == null:
		time_label.free()
