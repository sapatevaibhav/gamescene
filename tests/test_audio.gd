extends Node
## Sound (0.16): the built-in sounds and music are made, loop and repeat
## exactly; footsteps follow the surface in every style; ambience follows the
## weather; timeline clips play with the scene; a recording logs what plays
## and mixes it into a track; the AVI writer stores it; imported audio works;
## saves keep clips and sound settings.

var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		push_error("FAIL: " + what)
	else:
		print("ok   ", what)


func _ready() -> void:
	_synth()
	_mixer()
	_avi()
	_import()
	var studio := Studio.new()
	add_child(studio)
	await get_tree().process_frame
	for style in Styles.STYLE_ORDER:
		await studio.new_scene(style)
		studio.in_studio = true
		_steps(studio, style)
	await studio.new_scene("anime")
	studio.in_studio = true
	_loops(studio)
	_clips(studio)
	_record(studio)
	_save(studio)
	studio.in_studio = false
	print("FAILS: ", fails)
	get_tree().quit(1 if fails > 0 else 0)


func _sim(st: Studio, frames: int) -> void:
	for i in frames:
		st._process(1.0 / 30.0)


static func _peak(w: AudioStreamWAV) -> float:
	var d := w.data
	var m := 0
	for i in range(0, d.size(), 2):
		m = maxi(m, absi(d.decode_s16(i)))
	return m / 32768.0


func _synth() -> void:
	var names := ["step_grass", "step_dirt", "step_stone", "step_wood", "step_sand", "step_snow", "step_water", "swim", "land", "jump", "swing", "hit", "place", "break", "pop", "click", "toggle", "chime", "beep", "go"]
	var quiet := []
	for n in names:
		var w := Synth.sfx(n)
		if w.get_length() <= 0.0 or w.get_length() > 1.0 or _peak(w) < 0.05:
			quiet.append(n)
	ok(quiet.is_empty(), "%d sound effects are made, short and audible %s" % [names.size(), quiet])
	ok(Synth.sfx("step_grass", 0).data != Synth.sfx("step_grass", 1).data, "footsteps come in variations")
	# No crackle: single-sample spikes in the world's sounds come across like a
	# loose microphone cable.
	var crackly := []
	for n in ["step_grass", "step_dirt", "step_stone", "step_wood", "step_sand", "step_snow", "step_water", "swim", "land", "jump", "swing", "hit", "break"]:
		for v in 4:
			var r := _jumpiness(Synth.sfx(n, v))
			if r > 3.5:
				crackly.append("%s:%d (%.1f)" % [n, v, r])
	ok(crackly.is_empty(), "effects are smooth, no crackle or clicks %s" % [crackly])
	# Night crickets: soft chirps, never lining up into a loud buzz.
	var night := Synth.ambience("night").data
	var win := Synth.RATE / 20
	var levels := []
	for k in range(0, night.size() / 2 / win):
		var e := 0.0
		var prev := 0.0
		for i in range(k * win, (k + 1) * win):
			var x := night.decode_s16(i * 2) / 32768.0
			e += (x - prev) * (x - prev)
			prev = x
		levels.append(sqrt(e / win))
	var sorted := levels.duplicate()
	sorted.sort()
	var med: float = sorted[sorted.size() / 2]
	ok(sorted[-1] / med < 4.0, "crickets never build into a buzz (loudest moment %.1fx the usual)" % (sorted[-1] / med))
	for a in ["day", "night", "rain", "wind", "water"]:
		var w := Synth.ambience(a)
		ok(absf(w.get_length() - 8.0) < 0.01 and w.loop_mode == AudioStreamWAV.LOOP_FORWARD and _peak(w) > 0.02, "ambience '%s' is an audible 8 s loop" % a)
	# Two tunes cover both kinds (calm, and with drums); every tune shares
	# the same code, and building all eleven took most of this suite's time.
	for t in ["meadow", "adventure"]:
		var t0 := Time.get_ticks_msec()
		var w := Synth.tune(t)
		var ms := Time.get_ticks_msec() - t0
		ok(w.get_length() > 12.0 and w.get_length() < 45.0 and w.loop_mode == AudioStreamWAV.LOOP_FORWARD and _peak(w) > 0.2,
			"tune '%s': %.1f s loop, made in %d ms" % [t, w.get_length(), ms])
	var first := Synth.tune("meadow").data
	Synth._cache.clear()
	ok(Synth.tune("meadow").data == first, "sounds are the same every time (fixed seeds)")
	var known := Synth.TUNE_ORDER.all(func(t): return Synth.SONGS.has(t) and Synth.TUNES.has(t))
	ok(known, "every tune has a recipe and a name")
	ok(Sounds.label("tune:mystery") == "Mystery" and Sounds.length("tune:meadow") > 10.0 and Sounds.stream("nope:x") == null, "sound keys resolve")
	ok(Sounds.surface_of("Oak planks") == "wood" and Sounds.surface_of("cobble") == "stone" and Sounds.surface_of("Snow") == "snow"
		and Sounds.surface_of("Path") == "dirt" and Sounds.surface_of("flowers") == "grass" and Sounds.surface_of("Sand") == "sand", "surfaces by name")


## Biggest sample-to-sample jump relative to the sound's loudness.
static func _jumpiness(w: AudioStreamWAV) -> float:
	var d := w.data
	var mx := 0.0
	var rms := 0.0
	var prev := 0.0
	for i in range(0, d.size(), 2):
		var x := d.decode_s16(i) / 32768.0
		mx = maxf(mx, absf(x - prev))
		rms += x * x
		prev = x
	return mx / maxf(sqrt(rms / (d.size() / 2)), 1e-6)


func _mixer() -> void:
	var pcm := AudioMixer.decode(Synth.sfx("hit"))
	ok(absf(pcm.size() - Synth.sfx("hit").get_length() * AudioMixer.RATE) < 64, "sounds decode at the mix rate")
	var ev := [{"t": 0.5, "key": "sfx:hit:0", "cat": "sfx", "vol": 1.0},
		{"t": 0.0, "key": "amb:rain", "cat": "amb", "vol": 1.0, "loop": true, "from": 7.5, "until": 1.0, "fo": 0.2}]
	var mix := AudioMixer.render(ev, 2.0, {"sfx": 1.0, "amb": 1.0})
	var r := func(a: float, b: float) -> float:
		var m := 0.0
		for i in range(int(a * AudioMixer.RATE), int(b * AudioMixer.RATE)):
			m = maxf(m, absf(mix[i]))
		return m
	ok(mix.size() == 2 * AudioMixer.RATE, "mix is as long as the video")
	ok(r.call(0.05, 0.45) > 0.01, "a loop starting 7.5 s in wraps round and keeps playing")
	ok(r.call(0.5, 0.6) > r.call(0.05, 0.45), "the hit lands at 0.5 s")
	ok(r.call(1.3, 2.0) < 0.001, "the loop stops when it ends")
	var mute := AudioMixer.render(ev, 2.0, {"sfx": 0.0, "amb": 0.0})
	var silent := true
	for i in range(0, mute.size(), 97):
		if absf(mute[i]) > 0.0:
			silent = false
			break
	ok(silent, "category volumes apply to the mix")


func _avi() -> void:
	var path := OS.get_cache_dir().path_join("gs-test-audio.avi")
	var w := AviWriter.new()
	ok(w.open(path, 64, 48, 10, AudioMixer.RATE), "AVI with a sound stream opens")
	var img := Image.create(64, 48, false, Image.FORMAT_RGB8)
	img.fill(Color.CORNFLOWER_BLUE)
	for i in 10:
		w.write_frame(img)
	var tone := PackedFloat32Array()
	tone.resize(AudioMixer.RATE)
	for i in tone.size():
		tone[i] = sin(i * 0.06) * 0.5
	w.write_audio(AudioMixer.pcm16(tone))
	w.close()
	var probe := Recorder.ffmpeg_path().replace("ffmpeg", "ffprobe")
	if Recorder.ffmpeg_path() == "" or not FileAccess.file_exists(probe) and probe != "ffprobe":
		print("skip AVI probe: no ffprobe")
	else:
		var out := []
		OS.execute(probe, ["-v", "error", "-show_entries", "stream=codec_type,codec_name,sample_rate,duration", "-of", "csv=p=0", path], out, true)
		var txt := "".join(out)
		ok(txt.contains("mjpeg") and txt.contains("pcm_s16le") and txt.contains("44100"), "ffprobe sees MJPEG video and 44.1 kHz PCM sound (%s)" % txt.strip_edges().replace("\n", " | "))
	DirAccess.remove_absolute(path)


func _import() -> void:
	# A WAV written by the mixer imports and plays back.
	var src := OS.get_cache_dir().path_join("gs-test-beep.wav")
	var tone := PackedFloat32Array()
	tone.resize(AudioMixer.RATE / 2)
	for i in tone.size():
		tone[i] = sin(i * 0.05) * 0.4
	AudioMixer.save_wav(src, tone)
	ok(AudioFiles.DIR.begins_with("user://test_projects/"), "imports go to the test scratch folder")
	var id := AudioFiles.import_file(src)
	ok(id != "" and AudioFiles.list().has(id), "imported a .wav (%s)" % id)
	ok(absf(Sounds.length("file:" + id) - 0.5) < 0.02, "imported sound is 0.5 s long")
	ok(AudioFiles.import_file(src.get_basename() + ".txt") == "" and AudioFiles.last_error != "", "other files are refused")
	DirAccess.remove_absolute(src)


func _steps(st: Studio, style: String) -> void:
	var pl := st.player
	var w: Node = st.world
	var surf: String = w.surface_at(pl.pos)
	ok(surf in ["grass", "dirt", "stone", "wood", "sand", "snow", "water"], "%s: surface under the player is '%s'" % [style, surf])
	st.sound.heard.clear()
	st.camera.set_mode("third")
	st.input_move = Vector2(1, 0) if st.is_side() else Vector2(0, 1)
	_sim(st, 60)
	st.input_move = Vector2.ZERO
	var steps := st.sound.heard.filter(func(k): return str(k).begins_with("sfx:step_"))
	ok(steps.size() >= 3, "%s: walking makes footsteps (%d, e.g. %s)" % [style, steps.size(), steps.slice(0, 2)])
	var amb: Dictionary = st.sound._voices.get("amb", {})
	ok(not amb.is_empty() and (amb["player"] as AudioStreamPlayer).playing, "%s: ambience plays (%s)" % [style, amb.get("key", "")])


func _loops(st: Studio) -> void:
	st.atmo.apply_mood("storm")
	_sim(st, 90)
	ok(str(st.sound._voices.get("amb", {}).get("key", "")) == "amb:rain", "stormy weather brings rain sounds")
	App.settings["ambience"] = "off"
	_sim(st, 60)
	ok(not st.sound._voices.has("amb"), "ambience can be turned off")
	App.settings["ambience"] = "auto"
	# New scenes follow the mood; a new mood crossfades to its tune.
	App.reset_scene_defaults()
	ok(App.settings["music"] == "mood", "new scenes play the mood's music")
	st.atmo.apply_mood("sunset")
	_sim(st, 3)
	ok(str(st.sound._voices.get("bg", {}).get("key", "")) == "tune:golden", "sunset plays Golden Hour")
	st.atmo.apply_mood("snow")
	_sim(st, 3)
	var bgv: Dictionary = st.sound._voices.get("bg", {})
	ok(str(bgv.get("key", "")) == "tune:snowfall" and st.sound._outgoing.any(func(o): return (o["player"] as AudioStreamPlayer).stream == Synth.tune("golden")), "changing the mood crossfades to its tune (Snowfall in, Golden Hour out)")
	ok(db_to_linear((bgv["player"] as AudioStreamPlayer).volume_db) < 0.2, "the new tune starts quiet")
	_sim(st, 60)
	ok(st.sound._outgoing.is_empty() and db_to_linear((bgv["player"] as AudioStreamPlayer).volume_db) > 0.95, "and the old one is gone after the fade")
	var missing := []
	for mood in Styles.MOOD_ORDER:
		if not Synth.MOOD_TUNES.has(mood) or not Synth.TUNES.has(Synth.MOOD_TUNES[mood]):
			missing.append(mood)
	ok(missing.is_empty(), "every mood has its own tune %s" % [missing])
	# Slow frames: the scene clock runs behind real time, but live music must
	# not be pulled back to it (that made it jump and repeat).
	var p: AudioStreamPlayer = bgv["player"]
	var seeks := 0
	var last := -1.0
	for i in 40:
		st._process(1.0 / 30.0)
		var at := p.get_playback_position()
		if last >= 0.0 and at < last - 0.05 and at > 0.5:
			seeks += 1
		last = at
	ok(seeks == 0 and absf(float(bgv["pos"]) - p.get_playback_position()) < 0.1, "live music keeps its own time (no jumps back)")
	App.settings["music"] = "tune:meadow"
	_sim(st, 2)
	var bg: Dictionary = st.sound._voices.get("bg", {})
	ok(not bg.is_empty() and (bg["player"] as AudioStreamPlayer).playing, "background music plays")
	App.settings["music"] = ""
	_sim(st, 2)
	ok(not st.sound._voices.has("bg"), "and stops when set to none")
	App.settings["sfx"] = false
	st.sound.heard.clear()
	st.input_move = Vector2(0, 1)
	_sim(st, 40)
	st.input_move = Vector2.ZERO
	ok(st.sound.heard.is_empty(), "effects can be turned off")
	App.settings["sfx"] = true


func _clips(st: Studio) -> void:
	st.audio = [{"src": "tune:playful", "start": 1.0, "dur": 3.0, "vol": 0.8}]
	ok(st.has_script() and st.script_length() >= 4.0, "a sound clip makes the scene playable and sets its length")
	st.play_scene(true)
	_sim(st, 15)
	ok(not st.sound._voices.keys().any(func(k): return str(k).begins_with("clip:")), "a clip is silent before its start")
	_sim(st, 30)
	var v: Dictionary = {}
	for k in st.sound._voices:
		if str(k).begins_with("clip:"):
			v = st.sound._voices[k]
	ok(not v.is_empty() and (v["player"] as AudioStreamPlayer).playing, "it plays once the scene reaches its start")
	st.paused = true
	_sim(st, 2)
	ok(not st.sound._voices.keys().any(func(k): return str(k).begins_with("clip:")), "pausing stops it")
	st.paused = false
	_sim(st, 90)
	ok(not st.sound._voices.keys().any(func(k): return str(k).begins_with("clip:")), "and it stops at its end")
	st.play_scene(false)


func _record(st: Studio) -> void:
	# The video can't render headless, so drive the recorder's clock by hand.
	var rec := st.recorder
	App.settings["music"] = "tune:adventure"
	st.audio = [{"src": "tune:mystery", "start": 0.5, "dur": 1.0, "vol": 1.0}]
	st.play_scene(true)
	rec.sound_events = []
	rec.sound_t = 0.0
	rec.active = true
	st.sound.restart()
	st.input_move = Vector2(0, 1)
	for i in 75:
		st._process(1.0 / 30.0)
	st.input_move = Vector2.ZERO
	rec.active = false
	var keys := rec.sound_events.map(func(e): return str(e["key"]))
	ok(keys.has("tune:adventure"), "the recording logs the background music")
	ok(keys.any(func(k): return k.begins_with("amb:")), "and the ambience")
	ok(keys.any(func(k): return k.begins_with("sfx:step_")), "and footsteps")
	var clip: Array = rec.sound_events.filter(func(e): return e["key"] == "tune:mystery")
	ok(clip.size() == 1 and absf(float(clip[0]["t"]) - 0.5) < 0.05 and absf(float(clip[0]["until"]) - 1.5) < 0.05, "the clip is logged from 0.5 s to 1.5 s")
	var bg: Array = rec.sound_events.filter(func(e): return e["key"] == "tune:adventure")
	ok(not bg.is_empty() and float(bg[0]["from"]) < 0.05, "music starts from the top when recording starts")
	var mix := rec._mix(2.5)
	var peak := 0.0
	for i in range(0, mix.size(), 11):
		peak = maxf(peak, absf(mix[i]))
	ok(mix.size() == int(ceil(2.5 * AudioMixer.RATE)) and peak > 0.05 and peak <= 1.0, "the log mixes into a %.1f s track (peak %.2f)" % [2.5, peak])
	App.settings["music"] = ""
	st.play_scene(false)
	st.audio = []


func _save(st: Studio) -> void:
	st.audio = [{"src": "tune:chase", "start": 2.0, "dur": 5.0, "vol": 0.5}]
	App.settings["music"] = "tune:meadow"
	App.settings["sub_style"] = "cinema"
	var d := st.serialize()
	ok(int(d["v"]) == 5 and (d["audio"] as Array).size() == 1 and d["settings"]["music"] == "tune:meadow", "saves keep sound clips and settings")
	App.settings["music"] = "tune:chase"
	st.load_data(JSON.parse_string(JSON.stringify(d)))
	ok(st.audio.size() == 1 and str(st.audio[0]["src"]) == "tune:chase" and App.settings["music"] == "tune:meadow" and App.settings["sub_style"] == "cinema", "and load them back")
	var old := d.duplicate(true)
	old["v"] = 4
	old.erase("audio")
	(old["settings"] as Dictionary).erase("music")
	(old["settings"] as Dictionary).erase("sub_style")
	st.load_data(old)
	ok(st.audio.is_empty() and App.settings["music"] == "mood" and App.settings["sub_style"] == "box", "older scenes load with no clips and default sound settings (music follows the mood)")
	ok(Sounds.files_used({"settings": {"music": "file:a.ogg"}, "audio": [{"src": "file:b.mp3"}, {"src": "tune:x"}]}) == ["a.ogg", "b.mp3"], "imported sounds a scene uses are found for embedding")
