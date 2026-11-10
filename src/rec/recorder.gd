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
##
## Sound: the SoundDirector logs every sound played while recording
## (log_sound / end_sound). When recording stops the log is mixed into one
## track (AudioMixer) and added to the video: muxed by ffmpeg into the MP4,
## or written as a PCM stream into the AVI.

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
## Seconds since recording started, on the simulation clock.
var sound_t := 0.0
var sound_events: Array = []
var _video_path := ""
static var _ffmpeg := ""
static var _ffmpeg_checked := false
## When set, videos and stills go here instead of the system folders (tests).
static var DIR_OVERRIDE := ""


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
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(overlay)
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(fade)
	sub_panel.visible = false
	overlay.add_child(sub_panel)
	sub_panel.add_child(subtitle)
	title_label.visible = false
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	if DIR_OVERRIDE != "":
		DirAccess.make_dir_recursive_absolute(DIR_OVERRIDE)
		return ProjectSettings.globalize_path(DIR_OVERRIDE)
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
	title_label.add_theme_font_size_override("font_size", int(size.y * 0.075))
	sub_panel.custom_minimum_size = Vector2(0, 0)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func sync_camera(src: Camera3D) -> void:
	cam.global_transform = src.global_transform
	cam.fov = src.fov
	cam.projection = src.projection
	cam.size = src.size
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
	_shot_end = 0
	total_frames = 0
	for s in shots:
		total_frames += int(round(float(s.get("dur", 4.0)) * fps))
	_configure(size)
	sound_t = 0.0
	sound_events = []
	var name := U.slug(str(studio.project_name)) + "-" + Time.get_datetime_string_from_system().replace(":", "").replace("T", "-")
	var dir := output_dir()
	var ff := ffmpeg_path()
	if ff != "":
		out_path = dir + "/" + name + ".mp4"
		# Video first; the soundtrack is added when recording stops.
		_video_path = dir + "/." + name + "-video.mp4"
		var args := ["-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "%dx%d" % [size.x, size.y], "-r", str(fps), "-i", "-",
			"-c:v", "libx264", "-preset", "medium", "-crf", "17", "-pix_fmt", "yuv420p", "-movflags", "+faststart", _video_path]
		_ff = OS.execute_with_pipe(ff, args, true)
		if _ff.is_empty():
			ff = ""
	if ff == "":
		out_path = dir + "/" + name + ".avi"
		_avi = AviWriter.new()
		if not _avi.open(out_path, size.x, size.y, fps, AudioMixer.RATE):
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
		if not _cancel and frames > 0:
			await _add_sound_mp4(secs)
		elif not _cancel:
			DirAccess.rename_absolute(_video_path, out_path)
		DirAccess.remove_absolute(_video_path)
	if _avi:
		if not _cancel and frames > 0:
			_avi.write_audio(AudioMixer.pcm16(_mix(secs)))
		_avi.close()
		_avi = null
	if _cancel:
		DirAccess.remove_absolute(out_path)
		App.toast("Export cancelled.")
		return
	finished.emit(out_path, secs)


# ---------------------------------------------------------------- sound

## Logs a sound starting now; returns its index (for end_sound). A `len`
## stops it that many seconds later.
func log_sound(e: Dictionary) -> int:
	e["t"] = sound_t
	if e.has("len"):
		e["until"] = sound_t + float(e["len"])
		e.erase("len")
	sound_events.append(e)
	return sound_events.size() - 1


## Stops a logged sound now, fading out over `fo` seconds.
func end_sound(i: int, fo := 0.0) -> void:
	if i < 0 or i >= sound_events.size():
		return
	var e: Dictionary = sound_events[i]
	if e.has("until") and float(e["until"]) <= sound_t:
		return  # Already over (a clip that reached its end).
	e["until"] = sound_t + fo
	e["fo"] = fo


func _mix(secs: float) -> PackedFloat32Array:
	var vols := {"music": float(App.settings.get("music_vol", 0.7)), "sfx": float(App.settings.get("sfx_vol", 0.8)), "amb": float(App.settings.get("amb_vol", 0.6))}
	return AudioMixer.render(sound_events, secs, vols)


## Muxes the mixed soundtrack into the MP4 (AAC). Without sound, or if
## muxing fails, the video is kept as it is.
func _add_sound_mp4(secs: float) -> void:
	var ok := false
	if not sound_events.is_empty():
		var wav := _video_path.get_basename() + ".wav"
		if AudioMixer.save_wav(wav, _mix(secs)):
			var args := ["-hide_banner", "-loglevel", "error", "-y", "-i", _video_path, "-i", wav, "-map", "0:v", "-map", "1:a",
				"-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", "-movflags", "+faststart", out_path]
			var pid := OS.create_process(ffmpeg_path(), args)
			var t0 := Time.get_ticks_msec()
			while pid > 0 and OS.is_process_running(pid) and Time.get_ticks_msec() - t0 < 120000:
				await get_tree().create_timer(0.1).timeout
			var f := FileAccess.open(out_path, FileAccess.READ) if pid > 0 else null
			ok = f != null and f.get_length() > 0
		DirAccess.remove_absolute(wav)
	if not ok:
		DirAccess.remove_absolute(out_path)
		DirAccess.rename_absolute(_video_path, out_path)


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
		if not OS.is_process_running(int(_ff["pid"])):
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
	sound_t += dt
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


## Subtitle looks: "box" (dark rounded box), "outline" (white with a dark
## outline) and "cinema" (warm yellow with an outline).
const SUB_STYLES := [["box", "Box"], ["outline", "Outline"], ["cinema", "Cinema yellow"]]
const SUB_SIZES := {"s": 0.028, "m": 0.036, "l": 0.046}


## Styles a subtitle panel and label from the scene settings; `h` is the
## frame height in pixels. Used for the video and the Film sheet preview.
static func style_subtitle(panel: PanelContainer, label: Label, h: float) -> void:
	var style := str(App.settings.get("sub_style", "box"))
	var fs := maxi(8, int(h * float(SUB_SIZES.get(str(App.settings.get("sub_size", "m")), 0.036))))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", fs)
	var sb := StyleBoxFlat.new()
	sb.content_margin_left = fs * 0.6
	sb.content_margin_right = fs * 0.6
	sb.content_margin_top = fs * 0.28
	sb.content_margin_bottom = fs * 0.34
	sb.set_corner_radius_all(int(fs * 0.3))
	if style == "box":
		sb.bg_color = Color(0.03, 0.04, 0.07, 0.62)
		label.add_theme_constant_override("outline_size", 0)
	else:
		sb.bg_color = Color(0, 0, 0, 0)
		label.add_theme_constant_override("outline_size", maxi(2, int(fs * 0.16)))
		label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.04, 0.95))
	label.add_theme_color_override("font_color", Color("ffe066") if style == "cinema" else Color.WHITE)
	panel.add_theme_stylebox_override("panel", sb)


static func subtitle_text(who: String, text: String) -> String:
	return (who + ": " if who != "" and App.settings.get("sub_names", true) else "") + text


func show_subtitle(who: String, text: String, dur: float) -> void:
	if not active or not App.settings.get("subtitles", true):
		return
	var s := vp.size
	style_subtitle(sub_panel, subtitle, s.y)
	subtitle.text = subtitle_text(who, text)
	sub_panel.visible = true
	sub_panel.size = Vector2.ZERO
	var w := minf(s.x * 0.86, subtitle.get_theme_font("font").get_string_size(subtitle.text, HORIZONTAL_ALIGNMENT_LEFT, -1, subtitle.get_theme_font_size("font_size")).x + 48)
	sub_panel.custom_minimum_size = Vector2(w, 0)
	sub_panel.size = Vector2(w, 0)
	var top := str(App.settings.get("sub_pos", "bottom")) == "top"
	sub_panel.position = Vector2((s.x - w) / 2.0, s.y * 0.08 if top else s.y * 0.88 - sub_panel.get_combined_minimum_size().y)
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
	if DisplayServer.get_name() == "headless":
		return null
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
