class_name Recorder
extends Node
## Frame-accurate video export. The scene is rendered into an off-screen
## SubViewport at the chosen resolution and aspect (independent of the window,
## editor UI never appears), simulated with a fixed timestep of 1/fps so every
## take is smooth even if rendering is slow.
##
## Two modes: a live "take" (you direct while it records) and "film" export,
## which replays the scene from its start and cuts between the shot list.
##
## Output (see choose_kind): H.264 MP4 through ffmpeg, or on phones through
## the phone's own encoder (Native: MediaCodec segments joined with
## MediaMuxer), Motion-JPEG AVI without either; with a transparent background, ProRes 4444 MOV through ffmpeg or a PNG
## sequence without it. Green and blue screen replace the world and sky with a
## flat colour behind the characters.
##
## Reliability: film exports through ffmpeg are encoded in 10 s segments in a
## work folder, with a job file recording what's done. An export can pause,
## be saved for later, or be interrupted (even by a crash) and resume where it
## stopped: the scene is replayed to that frame without rendering (the
## simulation is deterministic) and recording carries on. PNG sequences resume
## the same way. Exports can also pause to let a hot device cool down.
##
## Sound: the SoundDirector logs every sound played while recording
## (log_sound / end_sound). At the end the log is mixed into one track
## (AudioMixer) and added to the video.

signal started
signal finished(path: String, secs: float)
signal progress(frac: float)

const SEG_SECONDS := 10.0
const BACKGROUNDS := [["scene", "Scene"], ["green", "Green screen"], ["blue", "Blue screen"], ["alpha", "Transparent"]]
const BG_COLORS := {"green": Color("00b140"), "blue": Color("0047bb")}

var studio: Node
var vp := SubViewport.new()
var cam := Camera3D.new()
var overlay := Control.new()
## The burned-in subtitle, drawn directly (box, outline and text) so it is
## right on the very frame it appears; a Label inside the recording view
## showed an empty box for its first frames.
var subtitle := SubtitleView.new()
var fade := ColorRect.new()
var title_label := Label.new()

var active := false
var film := false
var fps := 30
var frames := 0
var total_frames := 0
var out_path := ""
## Paused by you or to cool down: nothing is simulated or rendered.
var paused := false
var cooling := false
## Replaying to where a resumed export stopped (no rendering, no live sound).
var skipping := false
## Frames rendered (scene frozen, nothing saved) before the first real one,
## so the renderer and fonts have settled: the first frames of a session
## otherwise came out different (and the first subtitle blank).
const WARMUP := 10
var _warmup := 0
## "mp4", "mov", "avi", "png" or "dry" (tests: no output at all).
var kind := ""
## The resumable film export in progress (saved as JSON in JOB_DIR), or {}.
var job: Dictionary = {}
## Tests: write solid frames instead of the viewport, or write nothing.
var fake_frames := false
var dry := false
## Seconds since recording started, on the simulation clock.
var sound_t := 0.0
var sound_events: Array = []

## The segment being written: {stdio, pid, path} for ffmpeg, {native: id,
## path} for the phone encoder.
var _ff := {}
## "ffmpeg" or "native": what encodes MP4 segments.
var _enc := "ffmpeg"
var _avi: AviWriter
var _sub_t := 0.0
var _shot_i := -1
var _shot_end := 0
var _shots: Array = []
var _cancel := false
var _suspend := false
var _bg := "scene"
var _hidden: Array = []
var _size := Vector2i.ZERO
var _work := ""
var _seg_frames := 300
var _seg_count := 0
var _pending: Array = []
## Finished segments of a live take (takes don't keep a job).
var _loose_segments: Array = []
## While recording, the window shows the frame being recorded instead of
## drawing the scene a second time.
var _preview_layer: CanvasLayer
var _preview: TextureRect
var _fog_reproj := true
var _vsync := DisplayServer.VSYNC_ENABLED
var _rendered := 0
var _render_ms := 0
var _last_ms := 0
var _frame_ms: Array = []
var _baseline := 0.0
var _cool_until := 0

static var _ffmpeg := ""
static var _ffmpeg_checked := false
## When set, videos and stills go here instead of the system folders (tests).
static var DIR_OVERRIDE := ""
static var JOB_DIR := "user://exports/jobs/"
## Tests: segment length in frames (0 = SEG_SECONDS).
static var SEG_FRAMES := 0


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
	subtitle.visible = false
	overlay.add_child(subtitle)
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


static var _dirs := {}


## Where videos ("video") and screenshots ("image") go: the system Videos /
## Pictures folder (on Android that is the gallery's Movies and Pictures
## folders, written through the media store), else the app's own storage.
static func output_dir(what := "video") -> String:
	if DIR_OVERRIDE != "":
		DirAccess.make_dir_recursive_absolute(DIR_OVERRIDE)
		return ProjectSettings.globalize_path(DIR_OVERRIDE)
	if _dirs.has(what):
		return _dirs[what]
	var base := OS.get_system_dir(OS.SYSTEM_DIR_MOVIES if what == "video" else OS.SYSTEM_DIR_PICTURES)
	var dir := (base + "/GameScene Studio") if base != "" else ""
	if dir == "" or not _writable(dir):
		dir = ProjectSettings.globalize_path("user://exports")
		DirAccess.make_dir_recursive_absolute(dir)
	_dirs[what] = dir
	return dir


## Phones can refuse files in shared folders even when the folder exists.
static func _writable(dir: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return false
	var probe := dir.path_join(".gamescene-probe")
	var f := FileAccess.open(probe, FileAccess.WRITE)
	if f == null:
		return false
	f.store_8(1)
	f.close()
	DirAccess.remove_absolute(probe)
	return true


## True when exports land in the app's own storage rather than a folder the
## gallery / file manager sees (then finished files are copied to the gallery).
static func private_output(what := "video") -> bool:
	return output_dir(what).begins_with(ProjectSettings.globalize_path("user://"))


## The file type for a background ("scene", "green", "blue", "alpha").
## `has_native`: the phone's H.264 encoder (MP4 only, no transparency).
static func choose_kind(bg: String, has_ffmpeg: bool, has_native := false) -> String:
	if bg == "alpha":
		return "mov" if has_ffmpeg else "png"
	return "mp4" if has_ffmpeg or has_native else "avi"


## The file type this device makes for a background.
static func kind_for(bg: String) -> String:
	return choose_kind(bg, ffmpeg_path() != "", Native.can_encode())


## What the Film panel says the export will be.
static func kind_label(k: String) -> String:
	if k == "mp4" and ffmpeg_path() == "" and Native.can_encode():
		return "H.264 MP4 (this phone’s encoder)"
	return {"mp4": "H.264 MP4 (ffmpeg)", "avi": "Motion-JPEG AVI (install ffmpeg for MP4)",
		"mov": "ProRes 4444 MOV with transparency (ffmpeg)", "png": "PNG image sequence with transparency, plus sound.wav (install ffmpeg for a MOV)"}.get(k, k)


func _configure(size: Vector2i) -> void:
	_size = size
	vp.size = size
	vp.world_3d = get_viewport().world_3d
	var qd := App.q()
	vp.msaa_3d = Viewport.MSAA_4X if qd["msaa"] >= 2 else Viewport.MSAA_2X
	vp.scaling_3d_scale = 1.0
	title_label.add_theme_font_size_override("font_size", int(size.y * 0.075))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func sync_camera(src: Camera3D) -> void:
	cam.global_transform = src.global_transform
	cam.fov = src.fov
	cam.projection = src.projection
	cam.size = src.size
	cam.near = src.near
	cam.far = src.far
	cam.attributes = src.attributes


# ---------------------------------------------------------------- preview

## Recording draws the scene once, into the video frame; the window shows
## that frame (letterboxed) and stops drawing the 3D scene itself. Also turns
## off volumetric fog's frame-to-frame blending, so a frame looks the same
## whether or not the frames before it were rendered (resumed exports).
func _show_preview(on: bool) -> void:
	var main := get_viewport()
	if main == null or dry:
		return
	var env: Environment = studio.atmo.env if studio and studio.atmo else null
	if on:
		if _preview_layer == null:
			_preview_layer = CanvasLayer.new()
			_preview_layer.layer = -1
			var bg := ColorRect.new()
			bg.color = Color.BLACK
			bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_preview_layer.add_child(bg)
			_preview = TextureRect.new()
			_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_preview_layer.add_child(_preview)
			add_child(_preview_layer)
		_preview.texture = vp.get_texture()
		_preview_layer.visible = true
		main.disable_3d = true
		# Don't wait for the screen: with vsync, a window hidden behind others
		# (or on another workspace) slowed the export to a frame a second.
		_vsync = DisplayServer.window_get_vsync_mode()
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		if env:
			_fog_reproj = env.volumetric_fog_temporal_reprojection_enabled
			env.volumetric_fog_temporal_reprojection_enabled = false
	else:
		if _preview_layer:
			_preview_layer.visible = false
			_preview.texture = null
		main.disable_3d = false
		DisplayServer.window_set_vsync_mode(_vsync)
		if env:
			env.volumetric_fog_temporal_reprojection_enabled = _fog_reproj


# ---------------------------------------------------------------- background

## Green/blue screen and transparency: the world, sky and weather go, the
## characters stay lit as before against a flat colour (or nothing).
func _apply_bg() -> void:
	_restore_bg()
	_bg = str(App.settings.get("bg", "scene"))
	if _bg == "scene" or studio == null or studio.atmo == null:
		return
	var src: Environment = studio.atmo.env
	var env := src.duplicate() as Environment
	env.background_mode = Environment.BG_CLEAR_COLOR if _bg == "alpha" else Environment.BG_COLOR
	env.background_color = BG_COLORS.get(_bg, Color(0, 0, 0, 0))
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	# Light the characters as the sky did, without tinting them green.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.8, 0.86)
	env.ambient_light_energy = maxf(src.ambient_light_energy, 0.6)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	if _bg == "alpha":
		env.glow_enabled = false
	cam.environment = env
	vp.transparent_bg = _bg == "alpha"
	var hide: Array = [studio.world]
	for n in studio.atmo.find_children("*", "GeometryInstance3D", true, false):
		hide.append(n)
	for n in hide:
		if n is Node3D and (n as Node3D).visible:
			(n as Node3D).visible = false
			_hidden.append(n)


func _restore_bg() -> void:
	for n in _hidden:
		if is_instance_valid(n):
			(n as Node3D).visible = true
	_hidden.clear()
	cam.environment = null
	vp.transparent_bg = false


# ---------------------------------------------------------------- jobs

## What a resumable export depends on: the scene as it starts, the shots,
## the frame rate and background (the size is kept in the job, so a resized
## window doesn't matter).
static func scene_hash(st: Node, rate: int) -> String:
	var d: Dictionary = st.serialize()
	var cast := []
	for c in d.get("cast", []):
		var cc: Dictionary = (c as Dictionary).duplicate()
		cc.erase("pos")
		cc.erase("yaw")
		cast.append(cc)
	var settings: Dictionary = (d.get("settings", {}) as Dictionary).duplicate()
	if settings.get("cycle", false):
		settings.erase("time")
	settings.erase("frame")
	settings.erase("res")
	var key := [d.get("world"), d.get("seed"), d.get("start"), d.get("cues"), d.get("keys"), d.get("audio"), d.get("shots"), cast, settings, rate]
	return str(hash(JSON.stringify(key)))


static func _job_path(project_id: String) -> String:
	return JOB_DIR + (project_id if project_id != "" else "unsaved") + ".json"


## An unfinished export of this scene that can carry on, or {}.
static func find_job(st: Node, rate: int) -> Dictionary:
	var p := _job_path(str(st.project_id))
	if not FileAccess.file_exists(p):
		return {}
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not j is Dictionary:
		return {}
	var jd: Dictionary = j
	var ok: bool = jd.get("hash", "") == scene_hash(st, rate) and int(jd.get("done", 0)) > 0 and int(jd.get("done", 0)) < int(jd.get("total", 0))
	if ok and jd.get("kind", "") in ["mp4", "mov"]:
		for s in jd.get("segments", []):
			if not FileAccess.file_exists(str(s)):
				ok = false
	if ok and jd.get("kind", "") in ["mp4", "mov"]:
		ok = Native.can_encode() if jd.get("enc", "ffmpeg") == "native" else ffmpeg_path() != ""
	return jd if ok else {}


## Drops an unfinished export and its files.
static func discard_job(project_id: String) -> void:
	var p := _job_path(project_id)
	if FileAccess.file_exists(p):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
		if j is Dictionary:
			if str(j.get("work", "")) != "":
				_rm_dir(str(j["work"]))
			if str(j.get("kind", "")) == "png" and str(j.get("out", "")) != "":
				_rm_dir(str(j["out"]))
		DirAccess.remove_absolute(p)


func _save_job() -> void:
	if job.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(JOB_DIR)
	var f := FileAccess.open(_job_path(str(job.get("id", ""))), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(job))


static func _rm_dir(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(dir)


# ---------------------------------------------------------------- start / stop

## Starts recording. `shots` empty = live take; otherwise film export.
## `resume` is a job from find_job() to carry on from.
func start(size: Vector2i, rate: int, shots: Array = [], resume: Dictionary = {}) -> bool:
	if active:
		return false
	fps = rate
	frames = 0
	_cancel = false
	_suspend = false
	paused = false
	cooling = false
	film = not shots.is_empty()
	_shots = shots
	_shot_i = -1
	_shot_end = 0
	total_frames = 0
	for s in shots:
		total_frames += int(round(float(s.get("dur", 4.0)) * fps))
	_configure(size)
	_apply_bg()
	_show_preview(true)
	sound_t = 0.0
	sound_events = []
	_pending = []
	_rendered = 0
	_render_ms = 0
	_last_ms = 0
	_frame_ms = []
	_baseline = 0.0
	kind = "dry" if dry else kind_for(_bg)
	_enc = "ffmpeg" if kind != "mp4" or ffmpeg_path() != "" else "native"
	var dir := output_dir()
	var name := U.slug(str(studio.project_name)) + "-" + Time.get_datetime_string_from_system().replace(":", "").replace("T", "-")
	var skip := 0
	_seg_frames = SEG_FRAMES if SEG_FRAMES > 0 else int(SEG_SECONDS * fps)
	if not film:
		_seg_frames = 1 << 30
	job = {}
	if not resume.is_empty() and film and resume.get("kind", "") == kind and resume.get("enc", "ffmpeg") == _enc:
		job = resume.duplicate(true)
		skip = int(job["done"])
		out_path = str(job["out"])
		_work = str(job.get("work", ""))
	else:
		if film:
			discard_job(str(studio.project_id))
		match kind:
			"mp4":
				out_path = dir + "/" + name + ".mp4"
			"mov":
				out_path = dir + "/" + name + ".mov"
			"png":
				out_path = dir + "/" + name
			"avi":
				out_path = dir + "/" + name + ".avi"
			_:
				out_path = ""
		_work = (dir + "/.gamescene-work/" + name) if kind in ["mp4", "mov"] else ""
		if _enc == "native":
			# Keep the parts in the app's own storage, out of the gallery.
			_work = ProjectSettings.globalize_path("user://exports/work/" + name)
		if _work != "":
			DirAccess.make_dir_recursive_absolute(_work)
		if film and kind in ["mp4", "mov", "png"]:
			job = {"id": str(studio.project_id), "hash": scene_hash(studio, rate), "kind": kind, "enc": _enc, "out": out_path, "work": _work,
				"total": total_frames, "done": 0, "segments": [], "fps": fps, "w": size.x, "h": size.y, "name": str(studio.project_name)}
	if kind == "png":
		DirAccess.make_dir_recursive_absolute(out_path)
	elif kind == "avi":
		_avi = AviWriter.new()
		if not _avi.open(out_path, size.x, size.y, fps, AudioMixer.RATE):
			App.toast("Couldn’t write to " + dir)
			_avi = null
			_end_render()
			return false
	active = true
	App.fixed_dt = 1.0 / fps
	if film:
		_next_shot()
	started.emit()
	if skip > 0:
		_fast_forward(skip)
	_warmup = 0 if dry or fake_frames else WARMUP
	return true


## True while the scene must stand still: paused, cooling or warming up.
func holding() -> bool:
	return active and (paused or _warmup > 0)


## Replays the scene up to `n` frames in without rendering, so a resumed
## export carries on exactly where it stopped.
func _fast_forward(n: int) -> void:
	skipping = true
	var dt := 1.0 / fps
	for i in n:
		studio._process(dt)
		_frame_done(false)
	skipping = false


func pause() -> void:
	if active and not paused:
		paused = true
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED


func resume() -> void:
	if active and paused:
		paused = false
		cooling = false
		_last_ms = 0
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS


## Film exports that can resume: stops now and keeps what's done.
func can_suspend() -> bool:
	return active and film and not job.is_empty()


func suspend() -> void:
	if can_suspend():
		_suspend = true
		stop()


func cancel() -> void:
	_cancel = true
	stop()


func _end_render() -> void:
	_show_preview(false)
	App.fixed_dt = 0.0
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	fade.color.a = 0
	title_label.visible = false
	subtitle.visible = false
	_restore_bg()


func stop() -> void:
	if not active:
		return
	active = false
	paused = false
	cooling = false
	_end_render()
	var secs := float(frames) / fps
	if kind in ["mp4", "mov"]:
		if not _ff.is_empty():
			_close_segment()
		while not _pending.is_empty():
			_poll_pending()
			if not _pending.is_empty():
				await get_tree().create_timer(0.05).timeout
	if _cancel:
		if kind in ["mp4", "mov"]:
			_rm_dir(_work)
		elif kind == "png":
			_rm_dir(out_path)
		elif _avi:
			_avi.close()
			_avi = null
			DirAccess.remove_absolute(out_path)
		if not job.is_empty():
			DirAccess.remove_absolute(_job_path(str(job.get("id", ""))))
		job = {}
		App.toast("Export cancelled.")
		return
	if _suspend:
		_save_job()
		App.toast("Export saved at %d%%. Export the film again to carry on." % int(100.0 * float(job.get("done", frames)) / maxf(1, total_frames)))
		return
	match kind:
		"mp4", "mov":
			await _finish_segments(secs)
		"avi":
			if frames > 0:
				_avi.write_audio(AudioMixer.pcm16(_mix(secs)))
			_avi.close()
			_avi = null
		"png":
			if not sound_events.is_empty():
				AudioMixer.save_wav(out_path + "/sound.wav", _mix(secs))
	if not job.is_empty():
		DirAccess.remove_absolute(_job_path(str(job.get("id", ""))))
	job = {}
	publish(out_path)
	finished.emit(out_path, secs)


# ---------------------------------------------------------------- frames

func _process(_dt: float) -> void:
	if not active:
		return
	if cooling and Time.get_ticks_msec() >= _cool_until:
		resume()
	if not _pending.is_empty():
		_poll_pending()


func _on_post_draw() -> void:
	if not active or paused or skipping:
		return
	if _warmup > 0:
		_warmup -= 1
		return
	var img: Image = null
	if fake_frames:
		img = Image.create(_size.x, _size.y, false, Image.FORMAT_RGBA8 if kind in ["mov", "png"] else Image.FORMAT_RGB8)
		img.fill(Color.from_hsv(fmod(frames * 0.01, 1.0), 0.6, 0.8, 1.0))
	elif kind != "dry":
		img = vp.get_texture().get_image()
		if img == null:
			return
	_write(img)
	_frame_done(true)
	_watch_heat()


func _write(img: Image) -> void:
	match kind:
		"mp4", "mov":
			if _ff.is_empty():
				_open_segment()
			if _ff.is_empty():
				return
			if _ff.has("native"):
				if not Native.enc_frame(int(_ff["native"]), img):
					App.toast("The video encoder stopped unexpectedly.")
					cancel()
					return
				_seg_count += 1
				return
			var want := Image.FORMAT_RGBA8 if kind == "mov" else Image.FORMAT_RGB8
			if img.get_format() != want:
				img.convert(want)
			(_ff["stdio"] as FileAccess).store_buffer(img.get_data())
			_seg_count += 1
			if not OS.is_process_running(int(_ff["pid"])):
				App.toast("The video encoder stopped unexpectedly.")
				cancel()
		"avi":
			if img.get_format() != Image.FORMAT_RGB8:
				img.convert(Image.FORMAT_RGB8)
			_avi.write_frame(img)
		"png":
			img.convert(Image.FORMAT_RGBA8)
			img.save_png(out_path + "/frame_%05d.png" % (frames + 1))


## Counts a frame: closes a finished segment, moves to the next shot, ends
## the film. `rendered` is false while replaying to a resume point.
func _frame_done(rendered: bool) -> void:
	frames += 1
	if rendered:
		_rendered += 1
		if kind in ["mp4", "mov"] and _seg_count >= _seg_frames:
			_close_segment()
		elif kind == "png" and not job.is_empty():
			job["done"] = frames
			if frames % 30 == 0:
				_save_job()
	if film:
		progress.emit(float(frames) / maxf(1, total_frames))
		if frames >= total_frames:
			if rendered:
				stop()
		elif frames >= _shot_end:
			_next_shot()


func _open_segment() -> void:
	var ff := ffmpeg_path()
	var i: int = (job.get("segments", []) as Array).size() + _pending.size() if not job.is_empty() else _pending.size() + _loose_segments.size()
	var path := _work + "/seg%03d.%s" % [i, kind]
	_seg_count = 0
	if _enc == "native":
		var id := Native.enc_open(path, _size, fps)
		if id < 0:
			App.toast("The video encoder couldn’t start.")
			_ff = {}
		else:
			_ff = {"native": id, "path": path}
		return
	var args := ["-hide_banner", "-loglevel", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgba" if kind == "mov" else "rgb24",
		"-s", "%dx%d" % [_size.x, _size.y], "-r", str(fps), "-i", "-"]
	if kind == "mov":
		args += ["-c:v", "prores_ks", "-profile:v", "4444", "-pix_fmt", "yuva444p10le", path]
	else:
		args += ["-c:v", "libx264", "-preset", "medium", "-crf", "17", "-pix_fmt", "yuv420p", path]
	_ff = OS.execute_with_pipe(ff, args, true)
	_seg_count = 0
	if _ff.is_empty():
		App.toast("The video encoder couldn’t start.")
	else:
		_ff["path"] = path


func _close_segment() -> void:
	if _ff.is_empty():
		return
	if _ff.has("native"):
		# The phone encoder finishes the file right away.
		if Native.enc_close(int(_ff["native"])):
			_pending.append({"pid": -1, "path": str(_ff["path"]), "frames": _seg_count})
		else:
			App.toast("A part of the video couldn’t be saved; it will be made again.")
		_ff = {}
		_seg_count = 0
		return
	(_ff["stdio"] as FileAccess).close()
	_pending.append({"pid": int(_ff["pid"]), "path": str(_ff["path"]), "frames": _seg_count})
	_ff = {}
	_seg_count = 0


## Segments whose encoder has finished are added to the job, in order.
func _poll_pending() -> void:
	while not _pending.is_empty():
		var p: Dictionary = _pending[0]
		if int(p["pid"]) > 0 and OS.is_process_running(int(p["pid"])):
			return
		_pending.pop_front()
		if not job.is_empty():
			(job["segments"] as Array).append(p["path"])
			job["done"] = int(job["done"]) + int(p["frames"])
			_save_job()
		else:
			_loose_segments.append(p["path"])


## Joins the segments, adds the soundtrack, and cleans up the work folder.
func _finish_segments(secs: float) -> void:
	var segs: Array = job.get("segments", []) if not job.is_empty() else _loose_segments
	_loose_segments = []
	if segs.is_empty():
		_rm_dir(_work)
		return
	if _enc == "native":
		await _join_native(segs, secs)
		return
	var list := _work + "/segments.txt"
	var f := FileAccess.open(list, FileAccess.WRITE)
	for s in segs:
		f.store_line("file '%s'" % str(s).replace("'", "'\\''"))
	f.close()
	var args := ["-hide_banner", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", list]
	var wav := _work + "/sound.wav"
	var with_sound := not sound_events.is_empty() and AudioMixer.save_wav(wav, _mix(secs))
	if with_sound:
		args += ["-i", wav, "-map", "0:v", "-map", "1:a", "-c:v", "copy"]
		args += ["-c:a", "pcm_s16le"] if kind == "mov" else ["-c:a", "aac", "-b:a", "192k"]
		args += ["-shortest"]
	else:
		args += ["-c:v", "copy"]
	if kind == "mp4":
		args += ["-movflags", "+faststart"]
	args.append(out_path)
	var pid := OS.create_process(ffmpeg_path(), args)
	var t0 := Time.get_ticks_msec()
	while pid > 0 and OS.is_process_running(pid) and Time.get_ticks_msec() - t0 < 300000:
		await get_tree().create_timer(0.1).timeout
	var out := FileAccess.open(out_path, FileAccess.READ)
	if out == null or out.get_length() == 0:
		App.toast("Joining the video failed; the parts are in " + _work)
		return
	out.close()
	_rm_dir(_work)


## The phone encoder's join: segments in order plus the soundtrack (AAC).
func _join_native(segs: Array, secs: float) -> void:
	var wav := _work + "/sound.wav"
	if sound_events.is_empty() or not AudioMixer.save_wav(wav, _mix(secs)):
		wav = ""
	if not Native.mux_start(segs, wav, out_path, fps):
		App.toast("Joining the video failed; the parts are in " + _work)
		return
	var t0 := Time.get_ticks_msec()
	while Native.mux_state() == "running" and Time.get_ticks_msec() - t0 < 300000:
		await get_tree().create_timer(0.1).timeout
	var state := Native.mux_state()
	var out := FileAccess.open(out_path, FileAccess.READ)
	if state != "ok" or out == null or out.get_length() == 0:
		App.toast("Joining the video failed; the parts are in " + _work)
		return
	out.close()
	_rm_dir(_work)


# ---------------------------------------------------------------- heat

## A device that gets hot slows down. When frames start taking more than
## twice as long as they did early on, pause for 20 s to let it cool.
func _watch_heat() -> void:
	var now := Time.get_ticks_msec()
	if _last_ms > 0:
		var d := now - _last_ms
		_render_ms += d
		if film and App.device.get("cool_down", false):
			_frame_ms.append(d)
			if _frame_ms.size() > 90:
				_frame_ms.pop_front()
			if _baseline <= 0.0 and _frame_ms.size() >= 60:
				var s := _frame_ms.duplicate()
				s.sort()
				_baseline = float(s[s.size() / 2])
			elif _baseline > 0.0 and _frame_ms.size() >= 60:
				var avg := 0.0
				for x in _frame_ms.slice(-60):
					avg += float(x)
				avg /= 60.0
				if avg > _baseline * 2.2 and avg > 40.0:
					cool_down(20.0)
	_last_ms = now


func cool_down(secs: float) -> void:
	pause()
	cooling = true
	_cool_until = Time.get_ticks_msec() + int(secs * 1000.0)
	_frame_ms.clear()
	_baseline = 0.0


## For the progress panel.
func status() -> Dictionary:
	var left := total_frames - frames
	var per := float(_render_ms) / maxf(1.0, float(_rendered - 1)) if _rendered > 1 else 0.0
	return {"frames": frames, "total": total_frames, "shot": _shot_i + 1, "shots": _shots.size(), "paused": paused, "cooling": cooling,
		"cool_left": maxf(0.0, (_cool_until - Time.get_ticks_msec()) / 1000.0), "eta": per * left / 1000.0 if per > 0.0 else -1.0,
		"kind": kind, "resumable": can_suspend()}


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


# ---------------------------------------------------------------- per frame

## Called by the studio every simulated frame while recording.
func tick(dt: float) -> void:
	if not active:
		return
	sound_t += dt
	sync_camera(studio.camera)
	if _sub_t > 0:
		_sub_t -= dt
		if _sub_t <= 0:
			subtitle.visible = false
	if film and _shot_i >= 0 and _shot_i < _shots.size():
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


# ---------------------------------------------------------------- subtitles

## Subtitle looks: "box" (dark rounded box), "outline" (white with a dark
## outline) and "cinema" (warm yellow with an outline).
const SUB_STYLES := [["box", "Box"], ["outline", "Outline"], ["cinema", "Cinema yellow"]]
const SUB_SIZES := {"s": 0.028, "m": 0.036, "l": 0.046}


## How subtitles look for the scene settings at frame height `h`:
## {fs, box (StyleBoxFlat), color, outline, outline_color}.
static func subtitle_look(h: float) -> Dictionary:
	var style := str(App.settings.get("sub_style", "box"))
	var fs := maxi(8, int(h * float(SUB_SIZES.get(str(App.settings.get("sub_size", "m")), 0.036))))
	var sb := StyleBoxFlat.new()
	sb.content_margin_left = fs * 0.6
	sb.content_margin_right = fs * 0.6
	sb.content_margin_top = fs * 0.28
	sb.content_margin_bottom = fs * 0.34
	sb.set_corner_radius_all(int(fs * 0.3))
	sb.bg_color = Color(0.03, 0.04, 0.07, 0.62) if style == "box" else Color(0, 0, 0, 0)
	return {"fs": fs, "box": sb, "color": Color("ffe066") if style == "cinema" else Color.WHITE,
		"outline": 0 if style == "box" else maxi(2, int(fs * 0.16)), "outline_color": Color(0.02, 0.02, 0.04, 0.95)}


## Styles a Label like a subtitle (the Film panel's preview).
static func style_subtitle(label: Label, h: float) -> void:
	var lk := subtitle_look(h)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", lk["fs"])
	label.add_theme_constant_override("outline_size", lk["outline"])
	label.add_theme_color_override("font_outline_color", lk["outline_color"])
	label.add_theme_color_override("font_color", lk["color"])
	label.add_theme_stylebox_override("normal", lk["box"])


## Draws a subtitle: its box, then the text (outlined for the outline and
## cinema looks), centred and wrapped to the box width.
class SubtitleView:
	extends Control

	var text := ""
	var look := {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if text == "" or look.is_empty():
			return
		var sb: StyleBox = look["box"]
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var font := ThemeDB.fallback_font
		var fs: int = look["fs"]
		var x0 := sb.get_margin(SIDE_LEFT)
		var w := size.x - x0 - sb.get_margin(SIDE_RIGHT)
		var y := sb.get_margin(SIDE_TOP) + font.get_ascent(fs)
		if int(look["outline"]) > 0:
			draw_multiline_string_outline(font, Vector2(x0, y), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, -1, int(look["outline"]), look["outline_color"])
		draw_multiline_string(font, Vector2(x0, y), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, -1, look["color"])


static func subtitle_text(who: String, text: String) -> String:
	return (who + ": " if who != "" and App.settings.get("sub_names", true) else "") + text


func show_subtitle(who: String, text: String, dur: float) -> void:
	if not active or not App.settings.get("subtitles", true):
		return
	var s := vp.size
	# Size the box from the measured text, with the size and margins just
	# set: the theme lookups still return the old ones until the next frame
	# is drawn (and none is while a resumed export replays), which left the
	# box empty or far too tall.
	var lk := subtitle_look(s.y)
	var fs: int = lk["fs"]
	var sb: StyleBox = lk["box"]
	var line := subtitle_text(who, text)
	var mx := sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT)
	var my := sb.get_margin(SIDE_TOP) + sb.get_margin(SIDE_BOTTOM)
	var font := ThemeDB.fallback_font
	var w := minf(s.x * 0.86, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + mx + 8.0)
	var hh := font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, w - mx, fs).y + my
	var top := str(App.settings.get("sub_pos", "bottom")) == "top"
	subtitle.text = line
	subtitle.look = lk
	subtitle.size = Vector2(w, hh)
	subtitle.position = Vector2((s.x - w) / 2.0, s.y * 0.08 if top else s.y * 0.88 - hh)
	subtitle.visible = true
	subtitle.queue_redraw()
	_sub_t = dur


# ---------------------------------------------------------------- stills

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
	publish(path, "image")
	return path


## Phones: a finished file kept in the app's own storage is also copied into
## the gallery, so it shows up in Photos / Gallery.
static func publish(path: String, what := "video") -> void:
	if App.is_mobile and DIR_OVERRIDE == "" and private_output(what) and FileAccess.file_exists(path):
		Native.save_to_gallery(path)


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
