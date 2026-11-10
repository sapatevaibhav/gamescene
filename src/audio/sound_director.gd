class_name SoundDirector
extends Node
## Everything you hear in a scene: footsteps by surface, splashes, jumps,
## landings, swings and hits, a pop when someone speaks, the ambience loop,
## background music and the sound clips on the timeline.
##
## While a take or film export records, every sound is also logged to the
## recorder ({t, key, cat, vol, from, loop, until, fi, fo}), which mixes the
## log into the video's soundtrack. Live players and the log both come from
## the same logical clock, so the export matches what you heard. Nothing here
## touches App.sim_rng, so sound never changes how a scene plays out.

const BUSES := ["Music", "SFX", "Ambience", "UI"]
## Footsteps further than this from the camera are silent.
const HEAR := 26.0
const FADE := 1.2
## Crossfade when the background music changes (a new mood, a new pick).
const XFADE := 1.5

var studio: Node
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
## Looping voices: name -> {player, key, pos, vol, ev}. Names: "bg", "amb",
## "clip:<id>".
var _voices := {}
## Per-actor footstep state, by actor id.
var _feet := {}
var _clip_seq := 1
var _amb_fade := 1.0
## Players fading out after a change: [{player, vol, rate}].
var _outgoing: Array = []
var _preview: AudioStreamPlayer
var _preview_key := ""
## The last effects played, newest last (for tests and debugging).
var heard: Array = []


static func ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")


func _ready() -> void:
	ensure_buses()
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)


# ---------------------------------------------------------------- one-shots

## Plays a sound effect at full category volume times `vol`.
func play(name: String, v := 0, vol := 1.0) -> void:
	if not App.settings.get("sfx", true) or vol <= 0.01:
		return
	var key := "sfx:%s:%d" % [name, v]
	var rec: Recorder = studio.recorder if studio else null
	if rec and rec.skipping:
		# Replaying to where a resumed export stopped: log only.
		rec.log_sound({"key": key, "cat": "sfx", "vol": vol})
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = Sounds.stream(key)
	p.volume_db = linear_to_db(vol)
	p.play()
	heard.append(key)
	if heard.size() > 64:
		heard.pop_front()
	if rec and rec.active:
		rec.log_sound({"key": key, "cat": "sfx", "vol": vol})


## Plays a sound made at `at`, quieter the further it is from the camera.
func play_at(name: String, at: Vector3, v := 0, vol := 1.0) -> void:
	var g := hear(at)
	if g > 0.0:
		play(name, v, vol * g)


## How loud something at `p` is from the camera (0..1).
func hear(p: Vector3) -> float:
	var cam: Node3D = studio.camera
	var d: float
	if studio.is_side():
		d = Vector2(p.x - cam.global_position.x, p.y - cam.global_position.y).length()
	elif studio.is_top():
		d = Vector2(p.x - cam.global_position.x, p.z - cam.global_position.z).length()
	else:
		d = p.distance_to(cam.global_position)
	if d > HEAR:
		return 0.0
	return clampf(1.0 / (1.0 + pow(d / 7.0, 2.0)), 0.0, 1.0) * (1.0 - d / HEAR) * 1.6


func speech(a: Actor) -> void:
	play_at("pop", a.pos, a.id % 3, 0.35)


# ---------------------------------------------------------------- loop

## Called every frame by the studio after the simulation and animation.
func tick(dt: float) -> void:
	_bus_volumes()
	_footsteps(dt)
	_ambience(dt)
	_music(dt)
	_clips(dt)
	_fade_outgoing(dt)


func _bus_volumes() -> void:
	var vols := {"Music": float(App.settings.get("music_vol", 0.7)), "SFX": float(App.settings.get("sfx_vol", 0.8)),
		"Ambience": float(App.settings.get("amb_vol", 0.6)), "UI": 0.6 if App.device.get("ui_sounds", true) else 0.0}
	for b in vols:
		var i := AudioServer.get_bus_index(b)
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(vols[b], 0.0001)))


func _footsteps(dt: float) -> void:
	if not App.settings.get("sfx", true):
		return
	var seen := {}
	for a in studio.actors:
		seen[a.id] = true
		if a.rig.is_empty():
			continue
		var f: Dictionary = _feet.get(a.id, {})
		if f.is_empty():
			f = {"step": floori(a.walk / PI), "air": 0.0, "atk": a.attack_t, "hurt": a.hurt_t, "swim": 0.0, "n": 0}
			_feet[a.id] = f
		var sp := Vector2(a.vel.x, a.vel.z).length() if not studio.is_side() else absf(a.vel.x)
		var g := hear(a.pos)
		var size := clampf(a.k(), 0.4, 1.6)
		var step := floori(a.walk / PI)
		if a.swimming:
			f["swim"] = float(f["swim"]) + dt
			if sp > 0.3 and float(f["swim"]) > 1.1:
				f["swim"] = 0.0
				if g > 0.0:
					play("swim", int(f["n"]) % 4, 0.5 * g)
				f["n"] = int(f["n"]) + 1
		elif a.on_ground:
			if float(f["air"]) > 0.3 and g > 0.0:
				var surf := _surface(a)
				play("land", 0, 0.5 * g * size)
				play("step_" + surf, int(f["n"]) % 4, 0.6 * g * size)
			f["air"] = 0.0
			if step != int(f["step"]) and sp > 0.35 and g > 0.0:
				var loud := clampf(0.35 + sp * 0.09, 0.35, 0.85) * (0.6 if a.crouch else 1.0)
				play("step_" + _surface(a), int(f["n"]) % 4, loud * g * size)
				f["n"] = int(f["n"]) + 1
		else:
			if float(f["air"]) == 0.0 and a.vel.y > 2.0 and g > 0.0:
				play("jump", 0, 0.35 * g)
			f["air"] = float(f["air"]) + dt
		f["step"] = step
		if a.attack_t > float(f["atk"]) + 0.01 and g > 0.0:
			play("swing", a.id % 2, 0.6 * g)
		f["atk"] = a.attack_t
		if a.hurt_t > float(f["hurt"]) + 0.01 and g > 0.0:
			play("hit", a.id % 2, 0.7 * g)
		f["hurt"] = a.hurt_t
	for id in _feet.keys():
		if not seen.has(id):
			_feet.erase(id)


func _surface(a: Actor) -> String:
	if a.swimming:
		return "water"
	var w: Node = studio.world
	if w and w.has_method("surface_at"):
		var s: String = w.surface_at(a.pos)
		return s
	return "grass"


# ---------------------------------------------------------------- loops

func _ambience(dt: float) -> void:
	var want := str(App.settings.get("ambience", "auto"))
	if want == "auto":
		want = Sounds.auto_ambience()
	if want == "off":
		want = ""
	var v: Dictionary = _voices.get("amb", {})
	var cur := str(v.get("key", "")).substr(4)
	if want != cur:
		# Fade the old loop out, then start the new one.
		_amb_fade = maxf(0.0, _amb_fade - dt / FADE)
		if _amb_fade <= 0.0 or v.is_empty():
			_stop_voice("amb", FADE if not v.is_empty() else 0.0)
			if want != "":
				_start_voice("amb", "amb:" + want, "Ambience", 0.0, 1.0, true, FADE)
	else:
		_amb_fade = minf(1.0, _amb_fade + dt / FADE)
	_advance("amb", dt, _amb_fade)


## The background music to play now: the scene's pick, or the mood's tune
## when it is set to "mood".
static func music_key() -> String:
	var m := str(App.settings.get("music", ""))
	if m == "mood":
		m = "tune:" + str(Synth.MOOD_TUNES.get(str(App.settings.get("mood", "day")), "meadow"))
	if m != "" and not Sounds.exists(m):
		m = ""
	return m


func _music(dt: float) -> void:
	var want := music_key()
	var v: Dictionary = _voices.get("bg", {})
	if str(v.get("key", "")) != want:
		# Crossfade: the old tune fades out while the new one fades in.
		_fade_out_voice("bg", XFADE if not v.is_empty() else 0.0)
		if want != "":
			_start_voice("bg", want, "Music", 0.0, 1.0, true, XFADE if not v.is_empty() else 0.4)
	_advance("bg", dt, 1.0)


func _fade_out_voice(name: String, fo: float) -> void:
	var v: Dictionary = _voices.get(name, {})
	if v.is_empty():
		return
	if fo <= 0.0:
		_stop_voice(name, 0.0)
		return
	var rec: Recorder = studio.recorder if studio else null
	if rec and rec.active and int(v["ev"]) >= 0:
		rec.end_sound(int(v["ev"]), fo)
	_outgoing.append({"player": v["player"], "vol": float(v["vol"]) * _fade_in(v), "rate": 1.0 / fo})
	_voices.erase(name)


func _fade_outgoing(dt: float) -> void:
	for o in _outgoing.duplicate():
		var p: AudioStreamPlayer = o["player"]
		o["vol"] = float(o["vol"]) - dt * float(o["rate"])
		if not is_instance_valid(p) or float(o["vol"]) <= 0.0:
			if is_instance_valid(p):
				p.stop()
				p.queue_free()
			_outgoing.erase(o)
		else:
			p.volume_db = linear_to_db(maxf(float(o["vol"]), 0.0001))


## 0..1 while a voice is fading in.
static func _fade_in(v: Dictionary) -> float:
	var fi := float(v.get("fi", 0.0))
	return 1.0 if fi <= 0.0 else clampf(float(v.get("age", 0.0)) / fi, 0.0, 1.0)


## Timeline sound clips: {src, start, dur, vol, id}. They play while the
## scene plays (timeline, director mode, takes and film export).
func _clips(dt: float) -> void:
	var running: bool = studio.playing and not studio.paused
	var t: float = studio.play_t
	var live := {}
	for c in studio.audio:
		if not c.has("id"):
			c["id"] = _clip_seq
			_clip_seq += 1
		var name := "clip:%d" % int(c["id"])
		var s0 := float(c.get("start", 0.0))
		var dur := clip_len(c)
		var on := running and t >= s0 and t < s0 + dur
		if not on:
			continue
		live[name] = true
		var vol := float(c.get("vol", 1.0)) * clip_gain(c, t - s0)
		var v: Dictionary = _voices.get(name, {})
		if v.is_empty() or str(v.get("key", "")) != str(c.get("src", "")):
			_stop_voice(name, 0.0)
			var src := str(c.get("src", ""))
			var ln := Sounds.length(src)
			if ln <= 0.0:
				continue
			_start_voice(name, src, "Music", fmod(t - s0, ln), vol, true)
		_advance(name, dt, vol)
	for name in _voices.keys():
		if str(name).begins_with("clip:") and not live.has(name):
			_stop_voice(name, 0.0)


## Plays for its set duration, or the sound's own length (tunes loop).
static func clip_len(c: Dictionary) -> float:
	if float(c.get("dur", 0.0)) > 0.0:
		return float(c["dur"])
	var ln := Sounds.length(str(c.get("src", "")))
	return ln if ln > 0.0 else 4.0


## Short fade in, and a fade out over the last second.
static func clip_gain(c: Dictionary, local: float) -> float:
	var dur := clip_len(c)
	return clampf(local / 0.05, 0.0, 1.0) * clampf((dur - local) / minf(1.0, dur * 0.3), 0.0, 1.0)


func _start_voice(name: String, key: String, bus: String, from: float, vol: float, loop: bool, fi := 0.0) -> void:
	var st := Sounds.stream(key)
	if st == null:
		return
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.stream = st
	_set_loop(st, loop)
	add_child(p)
	p.volume_db = linear_to_db(maxf(vol, 0.0001))
	p.play(from)
	_voices[name] = {"player": p, "key": key, "pos": from, "vol": vol, "ev": -1, "loop": loop, "fi": fi, "age": 0.0, "cat": "music" if bus == "Music" else "amb"}


func _stop_voice(name: String, fo: float) -> void:
	var v: Dictionary = _voices.get(name, {})
	if v.is_empty():
		return
	var p: AudioStreamPlayer = v["player"]
	if is_instance_valid(p):
		p.stop()
		p.queue_free()
	var rec: Recorder = studio.recorder if studio else null
	if rec and rec.active and int(v["ev"]) >= 0:
		rec.end_sound(int(v["ev"]), fo)
	_voices.erase(name)


## Moves a voice's clock on, keeps the live player in step, and logs it to
## a recording that hasn't heard it yet.
func _advance(name: String, dt: float, vol: float) -> void:
	var v: Dictionary = _voices.get(name, {})
	if v.is_empty():
		return
	var p: AudioStreamPlayer = v["player"]
	var ln: float = p.stream.get_length() if p.stream else 0.0
	v["pos"] = float(v["pos"]) + dt
	if ln > 0.0 and v["loop"]:
		v["pos"] = fmod(float(v["pos"]), ln)
	v["age"] = float(v.get("age", 0.0)) + dt
	v["vol"] = vol
	p.volume_db = linear_to_db(maxf(vol * (_fade_in(v) if not name.begins_with("clip:") else 1.0), 0.0001))
	var rec: Recorder = studio.recorder
	if not rec.active:
		v["ev"] = -1
		# Live: the player keeps its own (real) time. Slow frames make the
		# scene clock lag behind it, and pulling the music back to that
		# clock made it jump and repeat. Just follow the player.
		if p.playing:
			v["pos"] = p.get_playback_position()
	elif int(v["ev"]) < 0:
		# Fading in only if it has only just started.
		var fi := float(v.get("fi", 0.0)) if float(v["pos"]) < float(v.get("fi", 0.0)) else 0.0
		var e := {"key": v["key"], "cat": v["cat"], "vol": 1.0, "from": float(v["pos"]), "loop": v["loop"], "fi": fi}
		if name.begins_with("clip:"):
			# Clips carry their own gain curve; log the clip's volume and
			# where it ends.
			var c := _clip_by_name(name)
			e["vol"] = float(c.get("vol", 1.0))
			e["fi"] = 0.05 if float(v["pos"]) < 0.05 else 0.0
			e["fo"] = minf(1.0, clip_len(c) * 0.3)
			e["len"] = clip_len(c) - (studio.play_t - float(c.get("start", 0.0)))
		v["ev"] = rec.log_sound(e)


func _clip_by_name(name: String) -> Dictionary:
	var id := int(name.substr(5))
	for c in studio.audio:
		if int(c.get("id", -1)) == id:
			return c
	return {}


static func _set_loop(st: AudioStream, loop: bool) -> void:
	if st is AudioStreamWAV:
		var w := st as AudioStreamWAV
		if loop and w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_end = w.data.size() / (2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1) / (2 if w.stereo else 1)
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
	elif st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = loop
	elif st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = loop


## Restarts the loops from their beginning (a take or export starts).
func restart() -> void:
	_feet.clear()
	_stop_voice("bg", 0.0)
	for name in _voices.keys():
		if str(name).begins_with("clip:"):
			_stop_voice(name, 0.0)


## Plays a sound from the start to try it out (again to stop). Returns
## whether it is now playing.
func preview(key: String) -> bool:
	if _preview == null:
		_preview = AudioStreamPlayer.new()
		_preview.bus = "Music"
		add_child(_preview)
	if _preview.playing and _preview_key == key:
		_preview.stop()
		return false
	var st := Sounds.stream(key)
	if st == null:
		return false
	_preview_key = key
	_preview.stream = st
	_preview.play()
	return true


func stop_preview() -> void:
	if _preview:
		_preview.stop()


func previewing(key: String) -> bool:
	return _preview != null and _preview.playing and _preview_key == key


func stop_all() -> void:
	stop_preview()
	for o in _outgoing:
		if is_instance_valid(o["player"]):
			(o["player"] as AudioStreamPlayer).queue_free()
	_outgoing.clear()
	for name in _voices.keys():
		_stop_voice(name, 0.0)
	for p in _pool:
		p.stop()
	_feet.clear()
