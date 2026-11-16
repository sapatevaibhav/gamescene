extends Node
## Export reliability (0.17): a resumed film export continues exactly where
## it stopped (same frames, same sound); pausing freezes the scene; a crashed
## or saved-for-later export resumes from its segments and joins into one
## video with sound; PNG sequences resume too; green/blue screen and
## transparency hide the world; exports cool down when the device slows.
## Phones (0.19): without ffmpeg, MP4 goes through the phone plugin's encoder
## (a fake plugin stands in for it here), in resumable segments too.
## Rendering is replaced by solid frames ("fake_frames") or no output ("dry"),
## so this runs headless.

var fails := 0
var FPS := 10


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		push_error("FAIL: " + what)
	else:
		print("ok   ", what)


func _ready() -> void:
	ok(Recorder.choose_kind("scene", true) == "mp4" and Recorder.choose_kind("green", false) == "avi"
		and Recorder.choose_kind("alpha", true) == "mov" and Recorder.choose_kind("alpha", false) == "png", "file types for each background, with and without ffmpeg")
	var st := Studio.new()
	add_child(st)
	await get_tree().process_frame
	await st.new_scene("anime")
	st.in_studio = true
	st.project_id = "test-export"
	App.settings["fps"] = FPS
	# Scenes start quiet; the export checks need a soundtrack.
	App.settings["music"] = "mood"
	App.settings["sfx"] = true
	var a: Actor = st.actors[1]
	st.cues = [{"actor": a.name, "action": "say", "text": "Ready?", "start": 0.2, "dur": 1.0},
		{"actor": a.name, "action": "walkto", "x": a.pos.x + 5.0, "z": a.pos.z, "start": 0.3, "dur": 1.5}]
	st.shots = [{"name": "A", "mode": "cine", "shot": "orbit", "target": a.name, "dur": 1.0, "dist": 5.0, "height": 2.0},
		{"name": "B", "mode": "cine", "shot": "dolly", "target": a.name, "dur": 1.0, "dist": 4.0, "height": 1.6, "fade_out": true}]
	st.capture_start()
	_determinism(st)
	_pause(st)
	_backgrounds(st)
	await _cool(st)
	if Recorder.ffmpeg_path() != "":
		await _crash_and_resume(st)
		await _take(st)
	else:
		print("skip MP4 segment checks: no ffmpeg")
	await _png(st)
	await _phone(st)
	_open_and_share()
	st.in_studio = false
	print("FAILS: ", fails)
	await SoundDirector.hush(get_tree())
	get_tree().quit(1 if fails > 0 else 0)


## One frame as the engine would do it: simulate, then capture.
func _frame(st: Studio) -> void:
	st._process(1.0 / FPS)
	st.recorder._on_post_draw()


func _digest(st: Studio) -> String:
	var s := "%.4f|" % st.play_t
	for x in st.actors:
		s += "%.3f,%.3f,%.3f %s %.2f;" % [x.pos.x, x.pos.y, x.pos.z, x.last_line, x.speak_t]
	var c := st.camera.global_position
	return s + "cam %.3f,%.3f,%.3f" % [c.x, c.y, c.z]


func _events(rec: Recorder, from_t: float) -> Array:
	return rec.sound_events.filter(func(e): return float(e["t"]) >= from_t - 1e-4).map(func(e): return "%s@%.3f" % [e["key"], e["t"]])


func _determinism(st: Studio) -> void:
	var rec := st.recorder
	rec.dry = true
	var total := 20
	ok(st.export_film(), "film export starts (dry)")
	ok(rec.total_frames == total, "2 shots of 1 s at %d fps = %d frames" % [FPS, total])
	var full := []
	for i in total:
		_frame(st)
		full.append(_digest(st))
	ok(not rec.active and rec.frames == total, "it stops by itself after the last frame")
	var ev_full := _events(rec, 1.2)
	# Play the scene around a bit, then export again: it must come out the same.
	st.play_scene(false)
	for i in 50:
		st._process(1.0 / 30.0)
	st.export_film()
	var again := true
	for i in total:
		_frame(st)
		if _digest(st) != full[i]:
			if again:
				print("  first difference at frame %d:\n   %s\n   %s" % [i, full[i], _digest(st)])
			again = false
	ok(again, "exporting again after playing around gives the same frames and lines")
	# Same export, resumed at frame 12.
	ok(st.export_film({"kind": "dry", "done": 12, "out": "", "work": "", "total": total, "segments": []}), "a resumed export starts")
	ok(rec.frames == 12 and full[11] == _digest(st), "replaying to frame 12 lands on the same moment")
	var same := true
	for i in range(12, total):
		_frame(st)
		if _digest(st) != full[i]:
			same = false
	ok(same, "and every frame after it matches the uninterrupted export")
	var ev_b := _events(rec, 1.2)
	ok(ev_b == ev_full, "the sound after the resume point matches too (%d sounds)" % ev_full.size())
	rec.dry = false


func _pause(st: Studio) -> void:
	var rec := st.recorder
	rec.dry = true
	st.export_film()
	for i in 5:
		_frame(st)
	rec.pause()
	var t0 := st.play_t
	var p0 := st.actors[1].pos
	for i in 10:
		_frame(st)
	ok(rec.frames == 5 and st.play_t == t0 and st.actors[1].pos == p0, "paused: no frames, the scene stands still")
	rec.resume()
	_frame(st)
	ok(rec.frames == 6 and st.play_t > t0, "resume carries on")
	rec.cancel()
	rec.dry = false


func _backgrounds(st: Studio) -> void:
	var rec := st.recorder
	rec.dry = true
	App.settings["bg"] = "green"
	st.export_film()
	var env: Environment = rec.cam.environment
	ok(env != null and env.background_mode == Environment.BG_COLOR and env.background_color == Recorder.BG_COLORS["green"] and not env.fog_enabled,
		"green screen: flat green behind, no fog")
	ok(not st.world.visible and env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, "the world is hidden and characters keep neutral light")
	rec.cancel()
	ok(st.world.visible and rec.cam.environment == null, "the world comes back after the export")
	App.settings["bg"] = "alpha"
	st.export_film()
	ok(rec.vp.transparent_bg and rec.cam.environment.background_mode == Environment.BG_CLEAR_COLOR, "transparent: the frame is cleared to nothing")
	rec.cancel()
	ok(not rec.vp.transparent_bg, "and goes back to normal")
	App.settings["bg"] = "scene"
	rec.dry = false


func _cool(st: Studio) -> void:
	var rec := st.recorder
	rec.dry = true
	st.export_film()
	_frame(st)
	rec.cool_down(0.3)
	ok(rec.paused and rec.cooling and rec.status()["cooling"], "cooling down pauses the export")
	# Headless timers don't follow the wall clock; wait on real time.
	var until := Time.get_ticks_msec() + 450
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
	rec._process(0.0)
	ok(not rec.paused and not rec.cooling, "and it carries on by itself afterwards")
	rec.cancel()
	rec.dry = false


func _wait_inactive(rec: Recorder) -> void:
	var t0 := Time.get_ticks_msec()
	while (rec.active or not rec._pending.is_empty()) and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().create_timer(0.05).timeout


func _probe(path: String) -> String:
	var out := []
	OS.execute(Recorder.ffmpeg_path().replace("ffmpeg", "ffprobe"), ["-v", "error", "-count_frames", "-show_entries", "stream=codec_type,nb_read_frames", "-of", "csv=p=0", path], out, true)
	return "".join(out).strip_edges().replace("\n", " | ")


func _crash_and_resume(st: Studio) -> void:
	var rec := st.recorder
	rec.fake_frames = true
	Recorder.SEG_FRAMES = 5
	ok(st.export_film(), "MP4 film export starts (5-frame segments)")
	ok(rec.kind == "mp4" and not rec.job.is_empty(), "it keeps a job so it can resume")
	for i in 7:
		_frame(st)
	# Let the first segment's encoder finish, then "crash": the app goes away
	# mid-segment without stopping anything.
	rec.pause()
	var t0 := Time.get_ticks_msec()
	while rec._pending.size() > 0 and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().create_timer(0.05).timeout
		rec._poll_pending()
	(rec._ff["stdio"] as FileAccess).close()
	rec._ff = {}
	rec.active = false
	rec.paused = false
	App.fixed_dt = 0.0
	var j := st.unfinished_export()
	ok(not j.is_empty() and int(j["done"]) == 5, "after a crash the finished segment is kept (%s frames done)" % j.get("done", "?"))
	# A changed scene can't carry on from it.
	st.cues.append({"actor": st.actors[2].name, "action": "dance", "start": 0.0, "dur": 1.0})
	ok(st.unfinished_export().is_empty(), "a changed scene doesn't offer to carry on")
	st.cues.pop_back()
	j = st.unfinished_export()
	ok(not j.is_empty(), "the unchanged scene does")
	var done := [false, ""]
	rec.finished.connect(func(p, _s): done[0] = true; done[1] = p, CONNECT_ONE_SHOT)
	ok(st.export_film(j), "the export carries on")
	ok(rec.frames == 5, "from frame 5")
	while rec.active:
		_frame(st)
	var t1 := Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t1 < 60000:
		await get_tree().create_timer(0.1).timeout
	ok(done[0] and FileAccess.file_exists(done[1]), "the segments are joined into one video")
	var pr := _probe(done[1])
	ok(pr.contains("video,20") and pr.contains("audio"), "it has all 20 frames and a sound track (%s)" % pr)
	ok(st.unfinished_export().is_empty() and not DirAccess.dir_exists_absolute(rec._work), "the job and work folder are cleaned up")
	# Finish later: stop now, carry on next time.
	st.export_film()
	for i in 8:
		_frame(st)
	rec.suspend()
	await _wait_inactive(rec)
	j = st.unfinished_export()
	ok(not j.is_empty() and int(j["done"]) == 8, "'Finish later' keeps everything rendered so far (%s frames)" % j.get("done", "?"))
	Recorder.discard_job(st.project_id)
	ok(st.unfinished_export().is_empty(), "'Start again' throws it away")
	Recorder.SEG_FRAMES = 0
	rec.fake_frames = false


func _take(st: Studio) -> void:
	var rec := st.recorder
	rec.fake_frames = true
	var done := [false, ""]
	rec.finished.connect(func(p, _s): done[0] = true; done[1] = p, CONNECT_ONE_SHOT)
	ok(st.start_take(), "a live take records")
	for i in 15:
		_frame(st)
	st.stop_take()
	var t0 := Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < 60000:
		await get_tree().create_timer(0.1).timeout
	ok(done[0] and str(done[1]).ends_with(".mp4") and _probe(done[1]).contains("video,15"), "the take is a 15-frame MP4 (%s)" % _probe(done[1]))
	rec.fake_frames = false


func _png(st: Studio) -> void:
	var rec := st.recorder
	var had := [Recorder._ffmpeg, Recorder._ffmpeg_checked]
	Recorder._ffmpeg = ""
	Recorder._ffmpeg_checked = true
	App.settings["bg"] = "alpha"
	rec.fake_frames = true
	ok(st.export_film() and rec.kind == "png", "transparent without ffmpeg: a PNG sequence")
	for i in 6:
		_frame(st)
	rec.suspend()
	await _wait_inactive(rec)
	var j := st.unfinished_export()
	ok(not j.is_empty() and int(j["done"]) == 6, "a PNG sequence can finish later too")
	var done := [false, ""]
	rec.finished.connect(func(p, _s): done[0] = true; done[1] = p, CONNECT_ONE_SHOT)
	st.export_film(j)
	while rec.active:
		_frame(st)
	var t0 := Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < 10000:
		await get_tree().create_timer(0.05).timeout
	var files := Array(DirAccess.get_files_at(done[1]))
	var pngs := files.filter(func(f): return str(f).ends_with(".png"))
	var img := Image.load_from_file(done[1] + "/frame_00020.png")
	ok(pngs.size() == 20 and files.has("sound.wav"), "all 20 frames and sound.wav (%d frames)" % pngs.size())
	ok(img != null and img.detect_alpha() != Image.ALPHA_NONE or img.get_format() == Image.FORMAT_RGBA8, "frames keep their alpha channel")
	rec.fake_frames = false
	App.settings["bg"] = "scene"
	Recorder._ffmpeg = had[0]
	Recorder._ffmpeg_checked = had[1]


## Stands in for the Android plugin (GameSceneNative): segments are text
## files saying how many frames they got; the join writes what it was given.
class FakePhone:
	extends RefCounted
	var opened := {}
	var shared: Array = []
	var joins := 0

	func can_encode() -> bool:
		return true

	func enc_open(path: String, w: int, h: int, fps: int, _br: int) -> int:
		var id := opened.size() + 1
		opened[id] = {"path": path, "w": w, "h": h, "fps": fps, "n": 0, "bad": 0}
		return id

	func enc_frame(id: int, data: PackedByteArray) -> bool:
		var e: Dictionary = opened[id]
		if data.size() != int(e["w"]) * int(e["h"]) * 4:
			e["bad"] = int(e["bad"]) + 1
		e["n"] = int(e["n"]) + 1
		return true

	func enc_close(id: int) -> bool:
		var e: Dictionary = opened[id]
		var f := FileAccess.open(str(e["path"]), FileAccess.WRITE)
		f.store_string("%d %d" % [e["n"], e["bad"]])
		f.close()
		return true

	func mux_start(segs: PackedStringArray, wav: String, out: String, fps: int) -> bool:
		var total := 0
		var bad := 0
		for sg in segs:
			var parts := FileAccess.get_file_as_string(sg).split(" ")
			total += int(parts[0])
			bad += int(parts[1])
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string("frames=%d bad=%d segs=%d sound=%s fps=%d" % [total, bad, segs.size(), FileAccess.file_exists(wav), fps])
		f.close()
		joins += 1
		return true

	func mux_state() -> String:
		return "ok"

	func share(paths: PackedStringArray, _title: String) -> bool:
		shared = Array(paths)
		return true


func _phone(st: Studio) -> void:
	var rec := st.recorder
	var had := [Recorder._ffmpeg, Recorder._ffmpeg_checked]
	Recorder._ffmpeg = ""
	Recorder._ffmpeg_checked = true
	var phone := FakePhone.new()
	Native.fake = phone
	ok(Recorder.kind_for("scene") == "mp4" and Recorder.kind_for("alpha") == "png" and Recorder.kind_label("mp4").contains("phone"),
		"a phone without ffmpeg makes MP4 with its own encoder (transparent stays PNG)")
	rec.fake_frames = true
	Recorder.SEG_FRAMES = 5
	ok(st.export_film() and rec.kind == "mp4" and rec._enc == "native" and rec.job.get("enc") == "native", "the phone film export starts and keeps a job")
	ok(not rec._work.begins_with(Recorder.output_dir()), "its parts are kept in the app's own storage")
	for i in 7:
		_frame(st)
	rec.suspend()
	await _wait_inactive(rec)
	var j := st.unfinished_export()
	ok(not j.is_empty() and int(j["done"]) == 7, "'Finish later' keeps all 7 frames (%s)" % j.get("done", "?"))
	Native.fake = null
	ok(st.unfinished_export().is_empty(), "without the phone encoder it can't carry on")
	Native.fake = phone
	var done := [false, ""]
	rec.finished.connect(func(p, _s): done[0] = true; done[1] = p, CONNECT_ONE_SHOT)
	ok(st.export_film(j) and rec.frames == 7, "it carries on from frame 7")
	while rec.active:
		_frame(st)
	var t0 := Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < 30000:
		await get_tree().create_timer(0.05).timeout
	var got := FileAccess.get_file_as_string(str(done[1])) if done[0] else ""
	ok(got == "frames=20 bad=0 segs=5 sound=true fps=%d" % FPS, "the segments and the soundtrack are joined into one MP4 (%s)" % got)
	ok(str(done[1]).ends_with(".mp4") and st.unfinished_export().is_empty() and not DirAccess.dir_exists_absolute(rec._work), "the job and parts are cleaned up")
	Recorder.SEG_FRAMES = 0
	rec.fake_frames = false
	Native.fake = null
	Recorder._ffmpeg = had[0]
	Recorder._ffmpeg_checked = had[1]


func _open_and_share() -> void:
	var dir := Recorder.output_dir()
	var a := dir.path_join("a.json")
	FileAccess.open(a, FileAccess.WRITE).store_string("{}")
	var main_script: GDScript = load("res://src/main.gd")
	var got: PackedStringArray = main_script.launch_files(PackedStringArray(["--verbose", a, dir.path_join("missing.json"), dir.path_join("x.png")]))
	ok(got == PackedStringArray([a]), "a project file named on the command line is opened (and nothing else)")
	var phone := FakePhone.new()
	Native.fake = phone
	var frames := dir.path_join("seq")
	DirAccess.make_dir_recursive_absolute(frames)
	for n in ["frame_00001.png", "frame_00002.png"]:
		FileAccess.open(frames.path_join(n), FileAccess.WRITE).store_8(0)
	Media.share([a, frames])
	ok(phone.shared.size() == 3 and phone.shared[0] == a, "sharing goes to the share sheet, a PNG sequence as its frames")
	Native.fake = null
