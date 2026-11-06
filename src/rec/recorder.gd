class_name Recorder
extends Node
## Frame-accurate video export. The scene is rendered into an off-screen
## SubViewport at the chosen resolution and aspect (independent of the window,
## editor UI never appears), simulated with a fixed timestep of 1/fps so every
## take is smooth even if rendering is slow, and encoded to H.264 MP4 through
## ffmpeg when available or to Motion-JPEG AVI otherwise.
##
## Two modes: a live "take" (you direct while it records) and "film" export,
## which replays the scene from its start and cuts between the shot list.

signal started
signal finished(path: String, secs: float)
signal progress(frac: float)

var studio: Node
var vp := SubViewport.new()
var cam := Camera3D.new()
var overlay := Control.new()
var subtitle := Label.new()
var sub_panel := PanelContainer.new()
var fade := ColorRect.new()
var title_label := Label.new()

var active := false
var film := false
var fps := 30
var frames := 0
var total_frames := 0
var out_path := ""
var _ff := {}
var _avi: AviWriter
var _sub_t := 0.0
var _shot_i := -1
var _shot_end := 0
var _shots: Array = []
var _cancel := false
var _snap := false
static var _ffmpeg := ""
static var _ffmpeg_checked := false


func _ready() -> void:
	vp.size = Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.msaa_3d = Viewport.MSAA_4X
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
	vp.positional_shadow_atlas_size = 4096
	add_child(vp)
	cam.current = true
	vp.add_child(cam)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(overlay)
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(fade)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.07, 0.62)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	sub_panel.add_theme_stylebox_override("panel", sb)
	sub_panel.visible = false
	overlay.add_child(sub_panel)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", Color.WHITE)
	sub_panel.add_child(subtitle)
	title_label.visible = false
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title_label.add_theme_constant_override("shadow_offset_y", 4)
	overlay.add_child(title_label)
	RenderingServer.frame_post_draw.connect(_on_post_draw)


static func ffmpeg_path() -> String:
	if _ffmpeg_checked:
		return _ffmpeg
	_ffmpeg_checked = true
	if OS.has_feature("mobile") or OS.has_feature("web"):
		return ""
	var candidates := ["ffmpeg", "/usr/bin/ffmpeg", "/usr/local/bin/ffmpeg", "/opt/homebrew/bin/ffmpeg", "C:/ffmpeg/bin/ffmpeg.exe"]
	for c in candidates:
		var out := []
		if OS.execute(c, ["-hide_banner", "-version"], out, true) == 0:
			_ffmpeg = c
			break
	return _ffmpeg


static func output_dir(kind := "video") -> String:
	var base := OS.get_system_dir(OS.SYSTEM_DIR_MOVIES if kind == "video" else OS.SYSTEM_DIR_PICTURES)
	var dir := (base + "/GameScene Studio") if base != "" else ProjectSettings.globalize_path("user://exports")
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		dir = ProjectSettings.globalize_path("user://exports")
		DirAccess.make_dir_recursive_absolute(dir)
	return dir


func _configure(size: Vector2i) -> void:
	vp.size = size
	vp.world_3d = get_viewport().world_3d
	var qd := App.q()
	vp.msaa_3d = Viewport.MSAA_4X if qd["msaa"] >= 2 else Viewport.MSAA_2X
	vp.scaling_3d_scale = 1.0
	var fs := int(size.y * 0.036)
	subtitle.add_theme_font_size_override("font_size", fs)
	title_label.add_theme_font_size_override("font_size", int(size.y * 0.075))
	sub_panel.custom_minimum_size = Vector2(0, 0)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func sync_camera(src: Camera3D) -> void:
	cam.global_transform = src.global_transform
	cam.fov = src.fov
	cam.near = src.near
	cam.far = src.far
	cam.attributes = src.attributes


## Starts recording. `shots` empty = live take; otherwise film export.
func start(size: Vector2i, rate: int, shots: Array = []) -> bool:
	if active:
		return false
	fps = rate
	frames = 0
	_cancel = false
	film = not shots.is_empty()
	_shots = shots
	_shot_i = -1
	total_frames = 0
	for s in shots:
		total_frames += int(round(float(s.get("dur", 4.0)) * fps))
	_configure(size)
	var name := U.slug(str(studio.project_name)) + "-" + Time.get_datetime_string_from_system().replace(":", "").replace("T", "-")
	var dir := output_dir()
	var ff := ffmpeg_path()
	if ff != "":
		out_path = dir + "/" + name + ".mp4"
		var args := ["-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % [size.x, size.y], "-r", str(fps), "-i", "-",
			"-c:v", "libx264", "-preset", "medium", "-crf", "17", "-pix_fmt", "yuv420p", "-movflags", "+faststart", out_path]
		_ff = OS.execute_with_pipe(ff, args, false)
		if _ff.is_empty():
			ff = ""
	if ff == "":
		out_path = dir + "/" + name + ".avi"
		_avi = AviWriter.new()
		if not _avi.open(out_path, size.x, size.y, fps):
			App.toast("Couldn’t write to " + dir)
			_avi = null
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			return false
	active = true
	App.fixed_dt = 1.0 / fps
	if film:
		_next_shot()
	started.emit()
	return true


func cancel() -> void:
	_cancel = true
	stop()


func stop() -> void:
	if not active:
		return
	active = false
	App.fixed_dt = 0.0
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	fade.color.a = 0
	title_label.visible = false
	sub_panel.visible = false
	var secs := float(frames) / fps
	if not _ff.is_empty():
		var pipe: FileAccess = _ff["stdio"]
		pipe.close()
		var pid: int = _ff["pid"]
		var t0 := Time.get_ticks_msec()
		while OS.is_process_running(pid) and Time.get_ticks_msec() - t0 < 60000:
			await get_tree().create_timer(0.1).timeout
		_ff = {}
	if _avi:
		_avi.close()
		_avi = null
	if _cancel:
		DirAccess.remove_absolute(out_path)
		App.toast("Export cancelled.")
		return
	finished.emit(out_path, secs)


func _on_post_draw() -> void:
	if not active:
		return
	var img := vp.get_texture().get_image()
	if img == null:
		return
	if img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGB8)
	if not _ff.is_empty():
		var pipe: FileAccess = _ff["stdio"]
		pipe.store_buffer(img.get_data())
		if pipe.get_error() != OK:
			App.toast("The video encoder stopped unexpectedly.")
			cancel()
			return
	elif _avi:
		_avi.write_frame(img)
	frames += 1
	if film:
		progress.emit(float(frames) / maxf(1, total_frames))
		if frames >= total_frames:
			stop()
		elif frames >= _shot_end:
			_next_shot()


## Called by the studio every simulated frame while recording.
func tick(dt: float) -> void:
	if not active:
		return
	sync_camera(studio.camera)
	if _sub_t > 0:
		_sub_t -= dt
		if _sub_t <= 0:
			sub_panel.visible = false
	if film and _shot_i >= 0:
		var shot: Dictionary = _shots[_shot_i]
		var start := _shot_end - int(round(float(shot.get("dur", 4.0)) * fps))
		var local := float(frames - start) / fps
		var remain := float(_shot_end - frames) / fps
		var a := 0.0
		if shot.get("fade_in", false) and local < 0.4:
			a = 1.0 - local / 0.4
		if shot.get("fade_out", false) and remain < 0.4:
			a = maxf(a, 1.0 - remain / 0.4)
		fade.color.a = a
		var title: String = shot.get("title", "")
		title_label.visible = title != "" and local < 2.6
		title_label.text = title
		title_label.modulate.a = clampf(minf(local / 0.4, (2.6 - local) / 0.4), 0, 1)


func _next_shot() -> void:
	_shot_i += 1
	if _shot_i >= _shots.size():
		return
	var shot: Dictionary = _shots[_shot_i]
	_shot_end += int(round(float(shot.get("dur", 4.0)) * fps))
	studio.apply_shot(shot)


func show_subtitle(who: String, text: String, dur: float) -> void:
	if not active or not App.settings.get("subtitles", true):
		return
	subtitle.text = (who + ": " if who != "" else "") + text
	sub_panel.visible = true
	var s := vp.size
	sub_panel.size = Vector2.ZERO
	var w := minf(s.x * 0.86, subtitle.get_theme_font("font").get_string_size(subtitle.text, HORIZONTAL_ALIGNMENT_LEFT, -1, subtitle.get_theme_font_size("font_size")).x + 48)
	sub_panel.custom_minimum_size = Vector2(w, 0)
	sub_panel.size = Vector2(w, 0)
	sub_panel.position = Vector2((s.x - w) / 2.0, s.y * 0.86 - sub_panel.get_combined_minimum_size().y)
	_sub_t = dur


## Renders one still at the export resolution and saves it as PNG.
func screenshot(size: Vector2i) -> String:
	if active:
		return ""
	_configure(size)
	sync_camera(studio.camera)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if img == null:
		return ""
	var path := output_dir("image") + "/" + U.slug(str(studio.project_name)) + "-" + Time.get_datetime_string_from_system().replace(":", "").replace("T", "-") + ".png"
	img.save_png(path)
	return path


## Small thumbnail for the home screen.
func thumbnail() -> Image:
	_configure(Vector2i(480, 300))
	sync_camera(studio.camera)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if img:
		img.convert(Image.FORMAT_RGB8)
	return img
