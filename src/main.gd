extends Node
## App entry: builds the theme, the 3D studio, the home screen and the HUD,
## routes scene input (mouse, keyboard, touch gestures) and handles app
## lifecycle (autosave on close or when a phone backgrounds the app).
##
## `godot --path . -- --smoke` runs an end-to-end self test with rendering
## and writes screenshots to user://smoke/ (see tests/README.md).

var studio := Studio.new()
var ui := CanvasLayer.new()
var home: Home
var hud: Hud
var icons := IconStudio.new()
var busy := PanelContainer.new()
## Dims (see-through) whatever is behind "Building your scene…".
var busy_bg := ColorRect.new()

# Input state.
var _ptrs := {}          # index -> {role, start, pos, t0, moved, button}
var _gesture := {}
var _mouse_drag := {}
var _keys_move := Vector2.ZERO
var _last_tap := 0


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	var dpi_scale := 1.0
	if App.is_mobile:
		dpi_scale = clampf(DisplayServer.screen_get_dpi() / 160.0, 1.0, 3.5)
	else:
		dpi_scale = maxf(1.0, DisplayServer.screen_get_scale())
	UIK.scale = dpi_scale * float(App.device["ui_scale"])
	var theme := UIK.make_theme()

	add_child(icons)
	studio.name = "Studio"
	add_child(studio)
	ui.layer = 10
	add_child(ui)
	var root := Control.new()
	root.name = "UIRoot"
	root.theme = theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	home = Home.new()
	home.name = "Home"
	home.icons = icons
	root.add_child(home)
	hud = Hud.new()
	hud.name = "Hud"
	hud.studio = studio
	hud.icons = icons
	root.add_child(hud)
	home.new_scene.connect(_ask_new_scene)
	home.open_project.connect(_open_project)
	hud.go_home.connect(_go_home)

	busy_bg.color = Color(0.04, 0.05, 0.08, 0.55)
	busy_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	busy_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	busy_bg.visible = false
	root.add_child(busy_bg)
	busy.add_theme_stylebox_override("panel", UIK.glass(16))
	var bl := UIK.label("Building your scene…", 16, Color.WHITE, true)
	busy.add_child(bl)
	_hide_busy()
	root.add_child(busy)

	hud.set_home_mode(true)
	App.settings_changed.connect(func(): studio.atmo.apply_quality())

	if "--smoke" in OS.get_cmdline_user_args():
		_smoke.call_deferred()


func _hide_busy() -> void:
	busy.visible = false
	busy_bg.visible = false


func _show_busy(on: bool) -> void:
	busy.visible = on
	busy_bg.visible = on
	if on:
		busy.size = busy.get_combined_minimum_size()
		busy.position = (busy.get_viewport_rect().size - busy.size) / 2
	await get_tree().process_frame
	await get_tree().process_frame


## Home screen: asks what to call the new scene, then makes it.
func _ask_new_scene(style: String) -> void:
	if style == "pixel":
		# Pixel 2D comes in two views; each is its own kind of world.
		hud.prompt("New Pixel 2D scene", _suggested_name(style), "Scene name", "Create", func(n: String, view: String): _new_scene(view, n), Styles.PIXEL_VIEWS)
		return
	hud.prompt("Name your scene", _suggested_name(style), "Scene name", "Create", func(n: String): _new_scene(style, n))


func _suggested_name(style: String) -> String:
	var n := 1
	for p in ProjectStore.index():
		if p.get("style") == style:
			n += 1
	return ProjectStore.unique_name(Styles.STYLES[style]["name"] + " scene " + str(n))


func _new_scene(style: String, scene_name := "") -> void:
	await _show_busy(true)
	await studio.new_scene(style)
	studio.project_id = ProjectStore.new_id()
	studio.project_name = ProjectStore.unique_name(scene_name) if scene_name != "" else _suggested_name(style)
	_enter_studio()
	# Let the camera settle on the cast before taking the thumbnail.
	for i in 12:
		await get_tree().process_frame
	await studio.save_now(true)


func _open_project(id: String) -> void:
	var d := ProjectStore.load_project(id)
	if d.is_empty():
		App.toast("That scene couldn’t be found on this device.")
		return
	await _show_busy(true)
	var err := studio.load_data(d)
	if err != "":
		_hide_busy()
		App.toast(err)
		return
	studio.project_id = id
	studio.project_name = d.get("name", "Scene")
	_enter_studio()


func _enter_studio() -> void:
	_hide_busy()
	home.visible = false
	studio.in_studio = true
	hud.set_home_mode(false)
	hud.take = 1
	hud.slate_label.text = "Record"
	hud.layout()
	if studio.camera.mode == "cine":
		studio.camera.cine_reset()
	if not App.is_touch:
		if studio.is_top():
			App.toast("WASD walks · Shift runs · left click attacks · right click a character for their menu · B builds")
		elif studio.is_side():
			App.toast("A/D walk · W or Space jumps · W/S climb ladders · Shift runs · left click attacks · right click a character for their menu · B builds with tiles")
		elif App.device["mouse_look"] == "capture":
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			App.toast("Mouse looks · WASD moves · Shift sprints · Ctrl crouches · left click attacks · right click a character for their menu · Esc frees the cursor")
		else:
			App.toast("Drag to look · WASD moves · Shift sprints · Ctrl crouches · left click attacks · right click a character for their menu")


func _go_home() -> void:
	_release_mouse()
	if studio.recorder.active:
		studio.recorder.stop()
	if studio.project_id != "":
		await studio.save_now(true)
	studio.in_studio = false
	hud.set_home_mode(true)
	home.refresh()
	home.visible = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if studio.in_studio and studio.project_id != "":
			if studio.recorder.active:
				await studio.recorder.stop()
			await studio.save_now(true)
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if studio.in_studio and studio.dirty:
			studio.save_now()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if hud.sheet.visible:
			hud.back_view()
		elif studio.in_studio:
			_go_home()


# ---------------------------------------------------------------- input

func _typing() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


func _process(_dt: float) -> void:
	if not studio.in_studio:
		return
	var mv := Vector2.ZERO
	if not _typing():
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			mv.y += 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			mv.y -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			mv.x += 1
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			mv.x -= 1
	if hud.joy.visible:
		mv += Vector2(hud.joy.knob.x, -hud.joy.knob.y)
	if mv.length() > 1:
		mv = mv.normalized()
	studio.input_move = mv
	var typing := _typing()
	studio.input_jump = hud.jump_held or (not typing and Input.is_physical_key_pressed(KEY_SPACE))
	studio.input_sprint = not typing and Input.is_physical_key_pressed(KEY_SHIFT)
	studio.input_crouch = not typing and Input.is_physical_key_pressed(KEY_CTRL)
	var up := 0.0
	if hud.up_held or (not typing and (Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_SPACE))):
		up += 1
	if hud.down_held or (not typing and Input.is_physical_key_pressed(KEY_Q)):
		up -= 1
	studio.camera.up_input = up


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or not studio.in_studio:
		return
	if k.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_release_mouse()
		elif hud.sheet.visible:
			hud.close_sheet()
		elif studio.tools.kind != "":
			studio.tools.set_tool("")
		elif hud.clean:
			hud.set_clean(false)
		return
	if _typing():
		return
	if k.ctrl_pressed and k.keycode == KEY_Z:
		if k.shift_pressed:
			studio.redo()
		else:
			studio.undo()
		return
	if k.ctrl_pressed and k.keycode == KEY_Y:
		studio.redo()
		return
	if k.ctrl_pressed and k.keycode == KEY_S:
		studio.save_now(true)
		App.toast("Saved.")
		return
	match k.physical_keycode:
		KEY_R:
			hud.toggle_record()
		KEY_P:
			hud.screenshot()
		KEY_H:
			hud.set_clean(not hud.clean)
		KEY_T:
			hud.toggle_timeline()
		KEY_C:
			var order := CameraRig.MODES
			studio.camera.set_mode(order[(order.find(studio.camera.mode) + 1) % order.size()])
			App.toast("Camera: " + {"third": "Follow", "first": "First person", "cine": "Cinematic", "free": "Free"}[studio.camera.mode])
			studio.mark_dirty()
		KEY_B:
			if studio.tools.kind != "":
				studio.tools.set_tool("")
			else:
				studio.tools.set_tool("blocks" if studio.world.is_voxel or studio.is_flat() else "objects")
		KEY_F:
			if studio.camera.mode == "free":
				studio.camera.set_mode("third")


func _release_mouse() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _look(dx: float, dy: float, s: float) -> void:
	var cam := studio.camera
	if studio.is_flat():
		# 2D: dragging pans the free camera; other modes follow.
		if cam.mode == "free":
			var k := cam.size / maxf(1.0, get_viewport().get_visible_rect().size.y)
			cam.free_pos += Vector3(-dx * k, dy * k, 0) if studio.is_side() else Vector3(-dx * k, 0, -dy * k)
		return
	if cam.mode == "cine":
		cam.cine_base -= dx * s
		cam.cine["height"] = clampf(float(cam.cine["height"]) + dy * 0.02, 0, 14)
	else:
		cam.yaw -= dx * s
		cam.pitch += dy * s
		cam.clamp_pitch()


func _zoom(f: float) -> void:
	var cam := studio.camera
	if studio.is_flat() and cam.mode != "cine":
		cam.dist = clampf(cam.dist * f, 1.5, 16)
		return
	match cam.mode:
		"cine":
			cam.cine["dist"] = clampf(float(cam.cine["dist"]) * f, 1.5, 24)
		"third":
			cam.dist = clampf(cam.dist * f, 1.5, 16)
		"free":
			cam.free_pos += CameraRig.look_dir(cam.yaw, cam.pitch) * (1.0 - f) * 12.0
		_:
			App.settings["fov"] = clampf(float(App.settings["fov"]) * f, 25, 110)


## Scene click. With a build tool: the tool acts. Otherwise the primary
## button is the player's action (attack) and the secondary button opens the
## menu of the character under the cursor. Touch: tapping a character opens
## their menu.
func _tap(pos: Vector2, button: int, touch := false) -> void:
	if studio.tools.kind != "":
		studio.tools.tap(pos, button)
		return
	if button == MOUSE_BUTTON_RIGHT or touch:
		var id := studio.tools.tap(pos, button)
		if id >= 0:
			_release_mouse()
			hud.open_sheet("actor", id)
		elif hud.sheet.visible:
			hud.close_sheet()
		return
	if button == MOUSE_BUTTON_LEFT and studio.player:
		if hud.sheet.visible and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			hud.close_sheet()
			return
		studio.player.attack()


func _unhandled_input(event: InputEvent) -> void:
	if not studio.in_studio:
		return
	if hud.clean and event is InputEventMouseButton and event.pressed and event.double_click:
		hud.set_clean(false)
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_touch(event)
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton:
		_mouse_button(event)
	elif event is InputEventMouseMotion:
		_mouse_motion(event)
	elif event is InputEventMagnifyGesture:
		if not _over_ui(event.position):
			_zoom(1.0 / event.factor)
	elif event is InputEventPanGesture:
		if _over_ui(event.position):
			return
		_look(event.delta.x * 8, event.delta.y * 8, 0.0045)


## True when the pointer is over a panel or button (not the 3D scene).
func _over_ui(pos: Vector2) -> bool:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return false
	if hud.sheet.visible and hud.sheet.get_global_rect().has_point(pos):
		return true
	for n in [hud.dock, hud.toolbar, hud.top_left, hud.top_right, hud.slate, hud.timeline_panel]:
		var c := n as Control
		if c.visible and c.get_global_rect().has_point(pos):
			return true
	return hud.modal.get_child_count() > 0


func _mouse_button(e: InputEventMouseButton) -> void:
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	# Wheel over a panel (e.g. a scroll that hit the end) must not zoom.
	if e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and _over_ui(e.position):
		return
	if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
		_zoom(0.9)
		return
	if e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
		_zoom(1.1)
		return
	var center := get_viewport().get_visible_rect().size / 2
	# Pixel 2D is pointed at, never mouse-looked.
	if App.device["mouse_look"] == "capture" and not studio.is_flat():
		if e.pressed and not captured and e.button_index == MOUSE_BUTTON_LEFT:
			hud.close_sheet()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		if captured and e.pressed:
			if studio.tools.kind == "terrain" and e.button_index == MOUSE_BUTTON_LEFT:
				studio.tools.begin_paint(center)
			else:
				_tap(center, e.button_index)
			return
		if captured and not e.pressed:
			studio.tools.end_paint()
			return
	if e.pressed:
		_mouse_drag = {"start": e.position, "moved": 0.0, "t0": Time.get_ticks_msec(), "button": e.button_index}
		if studio.tools.paints() and (e.button_index == MOUSE_BUTTON_LEFT or studio.tools.kind == "tiles"):
			studio.tools.begin_paint(e.position, e.button_index)
			_mouse_drag["paint"] = true
	else:
		if _mouse_drag.is_empty():
			return
		if _mouse_drag.get("paint", false):
			studio.tools.end_paint()
		elif _mouse_drag["moved"] < 6.0 and Time.get_ticks_msec() - int(_mouse_drag["t0"]) < 400 and _mouse_drag["button"] == e.button_index:
			_tap(e.position, e.button_index)
		_mouse_drag = {}


func _mouse_motion(e: InputEventMouseMotion) -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(e.relative.x, e.relative.y, 0.0024)
		return
	studio.tools.hover(e.position)
	if _mouse_drag.is_empty():
		return
	_mouse_drag["moved"] = maxf(_mouse_drag["moved"], e.position.distance_to(_mouse_drag["start"]))
	if _mouse_drag.get("paint", false):
		studio.tools.paint(e.position)
		return
	if _mouse_drag["moved"] < 4.0:
		return
	if _mouse_drag["button"] == MOUSE_BUTTON_MIDDLE and studio.camera.mode == "free":
		var cam := studio.camera
		var r := Vector3(cos(cam.yaw), 0, -sin(cam.yaw))
		cam.free_pos += -r * e.relative.x * 0.03 + Vector3.UP * e.relative.y * 0.03
		return
	_look(e.relative.x, e.relative.y, 0.0045)


func _touch(e: InputEvent) -> void:
	var vs := get_viewport().get_visible_rect().size
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			var p := {"role": "look", "start": t.position, "pos": t.position, "t0": Time.get_ticks_msec(), "moved": 0.0}
			_ptrs[t.index] = p
			if _ptrs.size() >= 2:
				for k in _ptrs:
					if _ptrs[k]["role"] == "joy":
						hud.joy.visible = false
						hud.joy.knob = Vector2.ZERO
					if _ptrs[k]["role"] == "paint":
						studio.tools.end_paint()
					_ptrs[k]["role"] = "gesture"
				_gesture = {}
				return
			if studio.tools.paints():
				p["role"] = "paint"
				studio.tools.begin_paint(t.position)
			elif t.position.x < vs.x * 0.42 and not hud.joy.visible and studio.camera.mode != "cine":
				p["role"] = "joy"
				hud.joy.center = t.position
				hud.joy.knob = Vector2.ZERO
				hud.joy.visible = true
				hud.joy.queue_redraw()
		else:
			if not _ptrs.has(t.index):
				return
			var p: Dictionary = _ptrs[t.index]
			_ptrs.erase(t.index)
			match p["role"]:
				"joy":
					hud.joy.visible = false
					hud.joy.knob = Vector2.ZERO
				"paint":
					studio.tools.end_paint()
				"gesture":
					_gesture = {}
					for k in _ptrs:
						_ptrs[k]["role"] = "none"
					return
			if p["moved"] < 12.0 and Time.get_ticks_msec() - int(p["t0"]) < 350:
				var now := Time.get_ticks_msec()
				if now - _last_tap < 300 and studio.tools.kind == "":
					_double_tap()
				else:
					_tap(t.position, MOUSE_BUTTON_LEFT, true)
				_last_tap = now
		return
	var d := e as InputEventScreenDrag
	if not _ptrs.has(d.index):
		return
	var p: Dictionary = _ptrs[d.index]
	var delta: Vector2 = d.position - p["pos"]
	p["pos"] = d.position
	p["moved"] = maxf(p["moved"], d.position.distance_to(p["start"]))
	match p["role"]:
		"gesture":
			var pts := []
			for k in _ptrs:
				pts.append(_ptrs[k]["pos"])
			if pts.size() < 2:
				return
			var dist: float = (pts[0] as Vector2).distance_to(pts[1])
			var mid: Vector2 = (pts[0] + pts[1]) / 2.0
			if not _gesture.is_empty():
				var z: float = dist / maxf(1.0, _gesture["d"])
				var md: Vector2 = mid - _gesture["m"]
				_zoom(1.0 / z)
				_look(md.x, md.y, 0.005)
			_gesture = {"d": dist, "m": mid}
		"joy":
			var off: Vector2 = d.position - hud.joy.center
			var r := Hud.Joystick.R
			if off.length() > r:
				off = off.normalized() * r
			hud.joy.knob = off / r
			hud.joy.queue_redraw()
		"look":
			_look(delta.x, delta.y, 0.0062)
		"paint":
			studio.tools.paint(d.position)


func _double_tap() -> void:
	# Double tap: frame the player again.
	var cam := studio.camera
	if cam.mode == "free":
		cam.set_mode("third")
	if studio.player:
		cam.yaw = studio.player.yaw + PI


# ---------------------------------------------------------------- self test

func _smoke() -> void:
	var dir := "user://smoke/"
	DirAccess.make_dir_recursive_absolute(dir)
	var log := []
	for i in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir + "00-home.png")
	for style in Styles.STYLE_ORDER:
		var t0 := Time.get_ticks_msec()
		await _new_scene(style)
		log.append("%s: built in %d ms, %d actors" % [style, Time.get_ticks_msec() - t0, studio.actors.size()])
		for i in 90:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(dir + "%s-1-third.png" % style)
		studio.camera.set_mode("cine")
		studio.camera.cine["shot"] = "orbit"
		studio.camera.cine_reset()
		for i in 60:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(dir + "%s-2-cine.png" % style)
		studio.atmo.apply_mood("sunset")
		for i in 20:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(dir + "%s-3-sunset.png" % style)
		studio.atmo.apply_mood("horror")
		for i in 20:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(dir + "%s-4-night.png" % style)
		studio.atmo.apply_mood("storm" if style != "blocky" else "snow")
		for i in 30:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(dir + "%s-5-weather.png" % style)
		studio.atmo.apply_mood("day")
		hud.open_sheet("add")
		hud.push_view("addChar")
		for i in 30:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(dir + "%s-6-sheet.png" % style)
		hud.close_sheet()
		# Save / load round trip.
		var d := studio.serialize()
		var json := JSON.stringify(d)
		var err := studio.load_data(JSON.parse_string(json))
		log.append("%s: reload %s, json %d bytes, actors %d" % [style, "ok" if err == "" else err, json.length(), studio.actors.size()])
		# A short film export (two shots).
		studio.shots = [{"name": "A", "mode": "cine", "shot": "crane", "dur": 1.0, "dist": 8.0, "height": 3.0, "title": "Smoke test", "fade_in": true},
			{"name": "B", "mode": "third", "dur": 1.0}]
		App.settings["res"] = "720"
		App.settings["frame"] = "16:9"
		if studio.export_film():
			while studio.recorder.active:
				await get_tree().process_frame
			await get_tree().create_timer(1.0).timeout
			log.append("%s: film %s (%d frames)" % [style, studio.recorder.out_path, studio.recorder.frames])
		App.settings["frame"] = "full"
		await _go_home()
		for i in 10:
			await get_tree().process_frame
	for i in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir + "99-home.png")
	var f := FileAccess.open(dir + "log.txt", FileAccess.WRITE)
	f.store_string("\n".join(PackedStringArray(log)))
	f.close()
	print("SMOKE OK\n" + "\n".join(PackedStringArray(log)))
	get_tree().quit()
