class_name Synth
## Every built-in sound is made here, in code: footsteps, splashes, hits, UI
## clicks, looping ambiences and the built-in music. Nothing is downloaded or
## sampled, so all of it is original. Sounds are 22.05 kHz mono and cached;
## each one has a fixed seed, so it is identical on every run.

const RATE := 22050

static var _cache := {}
static var _lock := Mutex.new()


static func _cached(key: String) -> AudioStreamWAV:
	_lock.lock()
	var w: AudioStreamWAV = _cache.get(key)
	_lock.unlock()
	return w


static func _put(key: String, w: AudioStreamWAV) -> void:
	_lock.lock()
	_cache[key] = w
	_lock.unlock()


## Makes the music ahead of time (run on a worker thread at startup), so
## picking a tune never stalls the interface.
static func prewarm() -> void:
	# The mood tunes first: scenes follow the mood by default.
	for m in MOOD_TUNES:
		tune(MOOD_TUNES[m])
	for t in TUNE_ORDER:
		tune(t)
	for a in ["day", "night"]:
		ambience(a)


## Sound effects. `v` picks a variation (footsteps have 4).
static func sfx(name: String, v := 0) -> AudioStreamWAV:
	var key := "sfx:%s:%d" % [name, v]
	var hit := _cached(key)
	if hit:
		return hit
	var r := RandomNumberGenerator.new()
	r.seed = hash(key)
	var s: PackedFloat32Array
	match name:
		"step_grass":
			s = _step(r, 0.12, 900.0, 0.7, 75.0, 0.5, 0.0, 0.45)
		"step_dirt":
			s = _step(r, 0.10, 600.0, 0.8, 85.0, 0.7, 0.0, 0.5)
		"step_stone":
			s = _step(r, 0.07, 1700.0, 1.4, 150.0, 0.45, 0.0, 0.45)
		"step_wood":
			s = _step(r, 0.09, 700.0, 1.6, 170.0, 0.9, 0.0, 0.55)
		"step_sand":
			s = _step(r, 0.15, 1100.0, 0.6, 0.0, 0.0, 0.0, 0.35)
		"step_snow":
			s = _step(r, 0.16, 1300.0, 0.7, 60.0, 0.35, 0.5, 0.4)
		"step_water", "splash":
			s = _splash(r, 0.22 if name == "step_water" else 0.55, 0.5 if name == "step_water" else 0.8)
		"swim":
			s = _splash(r, 0.45, 0.45)
		"land":
			s = _thud(r, 0.18, 90.0, 0.8)
		"jump":
			s = _whoosh(r, 0.16, 0.25, true)
		"swing":
			s = _whoosh(r, 0.22, 0.5, false)
		"hit":
			s = _thud(r, 0.16, 140.0, 0.9)
		"place":
			s = _thud(r, 0.09, 220.0, 0.6)
		"break":
			s = _step(r, 0.2, 800.0, 0.8, 120.0, 0.8, 0.6, 0.55)
		"pop":
			s = _blip(r, 0.07, 520.0, 880.0, 0.35)
		"click":
			s = _blip(r, 0.025, 1800.0, 1500.0, 0.18)
		"toggle":
			s = _blip(r, 0.04, 900.0, 1300.0, 0.2)
		"chime":
			s = _chime(0.5, [784.0, 1046.5], 0.25)
		"beep":
			s = _chime(0.16, [880.0], 0.3)
		"go":
			s = _chime(0.35, [1318.5], 0.35)
		_:
			s = _blip(r, 0.05, 600.0, 600.0, 0.2)
	if not name in ["click", "toggle", "chime", "beep", "go", "pop"]:
		# Soften: no hiss or clicks above ~2.4 kHz in the world's sounds.
		s = _soften(s)
	var w := _wav(s)
	_put(key, w)
	return w


## Seamless 8 s loops: "day", "night", "rain", "wind", "water".
static func ambience(name: String) -> AudioStreamWAV:
	var key := "amb:" + name
	var hit := _cached(key)
	if hit:
		return hit
	var r := RandomNumberGenerator.new()
	r.seed = hash(key)
	var n := RATE * 8
	var s := PackedFloat32Array()
	match name:
		"day":
			s = _wind(r, n, 0.12, 0.004)
			_birds(r, s, 9)
		"night":
			s = _wind(r, n, 0.05, 0.003)
			_crickets(r, s)
		"rain":
			s = _rain(r, n)
		"wind":
			s = _wind(r, n, 0.32, 0.012)
		"water":
			s = _wind(r, n, 0.1, 0.03)
			for i in 26:
				_bubble(r, s, r.randi_range(0, n - 1), 0.12)
		_:
			s.resize(n)
	var w := _wav(s, true)
	_put(key, w)
	return w


# ---------------------------------------------------------------- music

const TUNES := {
	"meadow": {"name": "Meadow", "desc": "Calm and warm"},
	"golden": {"name": "Golden Hour", "desc": "Slow and warm"},
	"daydream": {"name": "Daydream", "desc": "Soft and airy"},
	"enchanted": {"name": "Enchanted", "desc": "Gentle harp, a little magic"},
	"midnight": {"name": "Midnight", "desc": "Quiet and eerie"},
	"rainy": {"name": "Rainy Day", "desc": "Soft and wistful"},
	"snowfall": {"name": "Snowfall", "desc": "Music box, calm and bright"},
	"adventure": {"name": "Adventure", "desc": "Upbeat, with drums"},
	"playful": {"name": "Playful", "desc": "Light and bouncy"},
	"mystery": {"name": "Mystery", "desc": "Slow and curious"},
	"chase": {"name": "Chase", "desc": "Tense and fast"},
}
const TUNE_ORDER := ["meadow", "golden", "daydream", "enchanted", "midnight", "rainy", "snowfall", "adventure", "playful", "mystery", "chase"]
## The tune each mood plays when the music is set to follow the mood.
const MOOD_TUNES := {"day": "meadow", "sunset": "golden", "dreamy": "daydream", "fantasy": "enchanted", "horror": "midnight", "storm": "rainy", "snow": "snowfall"}

## Song recipes: tempo, key (MIDI root), scale, chord degrees per bar and
## which instruments play.
const SONGS := {
	"meadow": {"bpm": 84, "root": 60, "scale": [0, 2, 4, 5, 7, 9, 11], "chords": [0, 4, 5, 3, 0, 4, 3, 4], "pad": 0.16, "bass": "whole", "lead": "calm", "drums": ""},
	"golden": {"bpm": 68, "root": 62, "scale": [0, 2, 4, 5, 7, 9, 11], "chords": [0, 3, 5, 4, 0, 3, 1, 4], "pad": 0.15, "bass": "whole", "lead": "arp", "drums": "", "gain": 0.8},
	"daydream": {"bpm": 62, "root": 64, "scale": [0, 2, 4, 6, 7, 9, 11], "chords": [0, 1, 0, 1, 5, 4, 0, 1], "pad": 0.17, "bass": "whole", "lead": "musicbox", "drums": "", "gain": 0.75},
	"enchanted": {"bpm": 80, "root": 62, "scale": [0, 2, 3, 5, 7, 9, 10], "chords": [0, 6, 5, 6, 0, 3, 4, 6], "pad": 0.12, "bass": "whole", "lead": "arp", "drums": "", "gain": 0.8},
	"midnight": {"bpm": 54, "root": 50, "scale": [0, 1, 3, 5, 7, 8, 10], "chords": [0, 0, 1, 0, 5, 5, 1, 0], "pad": 0.2, "bass": "whole", "lead": "sparse", "drums": "", "gain": 0.7},
	"rainy": {"bpm": 64, "root": 57, "scale": [0, 2, 3, 5, 7, 8, 10], "chords": [0, 5, 2, 6, 0, 5, 3, 4], "pad": 0.14, "bass": "whole", "lead": "calm", "drums": "", "gain": 0.75},
	"snowfall": {"bpm": 70, "root": 67, "scale": [0, 2, 4, 5, 7, 9, 11], "chords": [0, 4, 5, 3, 0, 4, 3, 4], "pad": 0.1, "bass": "whole", "lead": "musicbox", "drums": "", "gain": 0.75},
	"adventure": {"bpm": 116, "root": 62, "scale": [0, 2, 4, 5, 7, 9, 11], "chords": [0, 3, 5, 4, 0, 3, 4, 4], "pad": 0.1, "bass": "eighths", "lead": "busy", "drums": "rock"},
	"playful": {"bpm": 124, "root": 65, "scale": [0, 2, 4, 7, 9], "chords": [0, 3, 0, 4, 0, 3, 4, 0], "pad": 0.0, "bass": "bounce", "lead": "staccato", "drums": "light"},
	"mystery": {"bpm": 72, "root": 57, "scale": [0, 2, 3, 5, 7, 8, 10], "chords": [0, 5, 2, 6, 0, 5, 3, 4], "pad": 0.2, "bass": "whole", "lead": "sparse", "drums": ""},
	"chase": {"bpm": 138, "root": 52, "scale": [0, 2, 3, 5, 7, 8, 10], "chords": [0, 0, 5, 5, 3, 3, 4, 4], "pad": 0.06, "bass": "pulse", "lead": "busy", "drums": "rock"},
}


static func tune(name: String) -> AudioStreamWAV:
	var key := "tune:" + name
	var hit := _cached(key)
	if hit:
		return hit
	var song: Dictionary = SONGS.get(name, SONGS["meadow"])
	var r := RandomNumberGenerator.new()
	r.seed = hash(key)
	var beat := 60.0 / float(song["bpm"])
	var bars: Array = song["chords"]
	var n := int(bars.size() * 4 * beat * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var scale: Array = song["scale"]
	var root: int = song["root"]
	var deg := func(d: int, oct := 0) -> float:
		var sz := scale.size()
		var o := floori(float(d) / sz)
		var semi: int = scale[posmod(d, sz)] + 12 * (o + oct)
		return 440.0 * pow(2.0, (root + semi - 69) / 12.0)
	var last := 4
	for b in bars.size():
		var c: int = bars[b]
		var t0 := b * 4 * beat
		# Pad: the chord's three notes, held for the bar.
		if float(song["pad"]) > 0.0:
			for k in 3:
				_note(s, t0, 4 * beat, deg.call(c + k * 2, 0), float(song["pad"]) / 3.0, "pad")
		# Bass.
		var bf: float = deg.call(c, -2)
		match str(song["bass"]):
			"whole":
				_note(s, t0, 4 * beat, bf, 0.32, "bass")
			"eighths":
				for e in 8:
					_note(s, t0 + e * beat * 0.5, beat * 0.45, bf * (2.0 if e % 4 == 3 else 1.0), 0.26, "bass")
			"bounce":
				for e in 4:
					_note(s, t0 + e * beat, beat * 0.4, bf if e % 2 == 0 else deg.call(c + 4, -2), 0.3, "bass")
			"pulse":
				for e in 16:
					_note(s, t0 + e * beat * 0.25, beat * 0.2, bf, 0.2 if e % 4 else 0.3, "bass")
		# Lead: a walk over the scale that lands on chord notes on the beat.
		var steps: Array = []
		match str(song["lead"]):
			"calm":
				steps = [[0, 1.5], [1.5, 0.5], [2, 2]]
			"busy":
				steps = [[0, 0.5], [0.5, 0.5], [1, 1], [2, 0.5], [2.5, 0.5], [3, 1]]
			"staccato":
				steps = [[0, 0.5], [0.5, 0.5], [1.5, 0.5], [2, 0.5], [3, 0.5], [3.5, 0.5]]
			"sparse":
				steps = [[0, 2], [2.5, 1.5]] if b % 2 == 0 else [[1, 3]]
			"arp", "musicbox":
				pass
		if song["lead"] == "arp":
			# Harp: the chord rolled up and down in eighth notes.
			var roll := [0, 2, 4, 7, 9, 7, 4, 2]
			for e in 8:
				_note(s, t0 + e * beat * 0.5, beat * 0.9, deg.call(c + roll[e], 0), 0.13, "harp")
		elif song["lead"] == "musicbox":
			# Music box: a high, sparse tune on chord notes.
			var pat := [[0, 1.0], [1, 0.5], [1.5, 0.5], [2, 1.5]] if b % 2 == 0 else [[0, 1.5], [2, 2.0]]
			for st in pat:
				var mb: int = c + [0, 2, 4, 7][r.randi_range(0, 3)] + 7
				_note(s, t0 + float(st[0]) * beat, float(st[1]) * beat, deg.call(mb, 1), 0.11, "bell")
		for st in steps:
			var on_beat := fmod(float(st[0]), 1.0) == 0.0
			var want: int = c + [0, 2, 4][r.randi_range(0, 2)] + 7
			if on_beat:
				last = want if absi(want - last) <= 4 else last + signi(want - last) * 2
			else:
				last += [-1, 1, 1, -2, 2][r.randi_range(0, 4)]
			last = clampi(last, 4, 13)
			var dur := float(st[1]) * beat * (0.5 if song["lead"] == "staccato" else 0.95)
			_note(s, t0 + float(st[0]) * beat, dur, deg.call(last, 0), 0.2, "bell" if song["lead"] == "sparse" else "pluck")
		# Drums.
		if song["drums"] != "":
			for e in 8:
				var te := t0 + e * beat * 0.5
				if e % 4 == 0:
					_drum(s, te, "kick", r)
				if song["drums"] == "rock" and e % 4 == 2:
					_drum(s, te, "snare", r)
				_drum(s, te, "hat", r)
	# Soft limiter.
	var gain := 0.9 * float(song.get("gain", 1.0))
	for i in n:
		var x := s[i] * gain
		s[i] = x / (1.0 + absf(x) * 0.6)
	var w := _wav(s, true)
	_put(key, w)
	return w


## Adds one note, wrapping past the end so the loop is seamless. Each
## instrument has its own tight loop; envelopes decay by multiplication.
static func _note(s: PackedFloat32Array, t: float, dur: float, f: float, amp: float, kind: String) -> void:
	var n := s.size()
	var i0 := int(t * RATE)
	var tail := 0.4 if kind in ["pad", "bell", "harp"] else 0.08
	var held := int(dur * RATE)
	var ln := int((dur + tail) * RATE)
	var tl := maxf(1.0, tail * RATE)
	var w := TAU * f / RATE
	var att := (0.12 if kind == "pad" else 0.004) * RATE
	var decay := {"pad": 0.0, "bass": 3.0, "bell": 2.2, "pluck": 5.0, "harp": 2.6}.get(kind, 5.0) as float
	var dk := exp(-decay / RATE)
	var e := 1.0
	var k := i0 % n
	match kind:
		"pad":
			for j in ln:
				var g := minf(1.0, j / att) * (1.0 if j < held else maxf(0.0, 1.0 - (j - held) / tl))
				var ph := w * j
				s[k] += (sin(ph) + 0.5 * sin(ph * 1.003 + 1.0) + 0.2 * sin(ph * 2.0)) * g * amp
				k += 1
				if k >= n:
					k = 0
		"bell":
			var e2 := 1.0
			var dk2 := exp(-6.0 / RATE)
			for j in ln:
				var ph := w * j
				s[k] += (sin(ph) + 0.4 * sin(ph * 2.76) * e2) * minf(1.0, j / att) * e * amp
				e *= dk
				e2 *= dk2
				k += 1
				if k >= n:
					k = 0
		"bass":
			for j in ln:
				var ph := w * j
				s[k] += (sin(ph) + 0.35 * sin(ph * 2.0)) * minf(1.0, j / att) * e * (1.0 if j < held else maxf(0.0, 1.0 - (j - held) / tl)) * amp
				e *= dk
				k += 1
				if k >= n:
					k = 0
		_:
			# Pluck: stops once it has died away.
			for j in ln:
				if e < 0.002:
					break
				var ph := w * j
				s[k] += (sin(ph) + 0.3 * sin(ph * 3.0)) * minf(1.0, j / att) * e * (1.0 if j < held else maxf(0.0, 1.0 - (j - held) / tl)) * amp
				e *= dk
				k += 1
				if k >= n:
					k = 0


static func _drum(s: PackedFloat32Array, t: float, kind: String, r: RandomNumberGenerator) -> void:
	var n := s.size()
	var i0 := int(t * RATE)
	var lp := 0.0
	match kind:
		"kick":
			var ph := 0.0
			for j in int(0.28 * RATE):
				var tt := float(j) / RATE
				ph += TAU * (48.0 + 90.0 * exp(-tt * 30.0)) / RATE
				s[(i0 + j) % n] += sin(ph) * exp(-tt * 9.0) * 0.5
		"snare":
			for j in int(0.16 * RATE):
				var tt := float(j) / RATE
				var nz := r.randf_range(-1, 1)
				s[(i0 + j) % n] += (nz * 0.6 + sin(TAU * 185.0 * tt) * 0.4) * exp(-tt * 22.0) * 0.28
		"hat":
			for j in int(0.035 * RATE):
				var tt := float(j) / RATE
				var nz := r.randf_range(-1, 1)
				lp += (nz - lp) * 0.5
				s[(i0 + j) % n] += (nz - lp) * exp(-tt * 90.0) * 0.12


# ---------------------------------------------------------------- effects

## A footstep: band-passed noise around `fc` Hz (a soft scuff, never the
## bare hiss or single-sample clicks that sound like a loose cable), a low
## thud at `thump` Hz, and for snow a few soft crunch grains.
static func _step(r: RandomNumberGenerator, dur: float, fc: float, q: float, thump: float, thump_amp: float, grit: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var f := 2.0 * sin(PI * fc * r.randf_range(0.85, 1.15) / RATE)
	var q1 := 1.0 / q
	var low := 0.0
	var band := 0.0
	var tf := thump * r.randf_range(0.9, 1.1)
	# Grains: short (8-15 ms) smooth bursts for snow's crunch.
	var grains := []
	for k in int(grit * 8.0):
		grains.append([r.randi_range(0, n - 1), int(r.randf_range(0.008, 0.015) * RATE)])
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.006) * exp(-t / (dur * 0.3))
		var x := r.randf_range(-1, 1)
		var high := x - low - q1 * band
		band += f * high
		low += f * band
		var y := band * 0.9 * env
		if tf > 0.0:
			y += sin(TAU * tf * t) * minf(1.0, t / 0.004) * exp(-t * 35.0) * thump_amp
		for g in grains:
			var gi: int = i - int(g[0])
			if gi >= 0 and gi < int(g[1]):
				y += band * 0.8 * sin(PI * gi / float(g[1]))
		s[i] = y * amp
	return s


static func _splash(r: RandomNumberGenerator, dur: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.01) * exp(-t / (dur * 0.3))
		var nz := r.randf_range(-1, 1)
		lp += (nz - lp) * (0.35 - t / dur * 0.25)
		s[i] = lp * env * amp
	for k in int(dur * 18):
		_bubble(r, s, r.randi_range(0, n / 2), 0.25 * amp)
	return s


static func _bubble(r: RandomNumberGenerator, s: PackedFloat32Array, at: int, amp: float) -> void:
	var f := r.randf_range(500, 1400)
	var ln := int(r.randf_range(0.02, 0.05) * RATE)
	var ph := 0.0
	var n := s.size()
	for j in ln:
		var t := float(j) / RATE
		ph += TAU * f * (1.0 + t * 12.0) / RATE
		s[(at + j) % n] += sin(ph) * exp(-t * 60.0) * amp


static func _thud(r: RandomNumberGenerator, dur: float, f: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var lp := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * f * (1.0 + exp(-t * 40.0)) / RATE
		var nz := r.randf_range(-1, 1)
		lp += (nz - lp) * 0.2
		s[i] = (sin(ph) * 0.8 + lp * 0.5 * exp(-t * 30.0)) * exp(-t / (dur * 0.3)) * amp
	return s


## Air moving: band-passed noise whose pitch rises and falls (a swing), or
## only rises (a jump).
static func _whoosh(r: RandomNumberGenerator, dur: float, amp: float, up: bool) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var low := 0.0
	var band := 0.0
	for i in n:
		var t := float(i) / n
		var fc := lerpf(300.0, 900.0, t) if up else 300.0 + 700.0 * sin(PI * t)
		var f := 2.0 * sin(PI * fc / RATE)
		var high := r.randf_range(-1, 1) - low - 0.7 * band
		band += f * high
		low += f * band
		s[i] = band * sin(PI * t) * sin(PI * t) * amp
	return s


static func _blip(_r: RandomNumberGenerator, dur: float, f0: float, f1: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		ph += TAU * lerpf(f0, f1, t) / RATE
		s[i] = sin(ph) * minf(1.0, t * 20.0) * (1.0 - t) * amp
	return s


static func _chime(dur: float, notes: Array, amp: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var gap := int(0.09 * RATE)
	for k in notes.size():
		var f: float = notes[k]
		for i in range(k * gap, n):
			var t := float(i - k * gap) / RATE
			s[i] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * minf(1.0, t / 0.004) * exp(-t * 7.0) * amp
	return s


# ---------------------------------------------------------------- ambience

## Brown-ish noise with slow gusts; `gust` periods divide the loop so it wraps.
static func _wind(r: RandomNumberGenerator, n: int, amp: float, bright: float) -> PackedFloat32Array:
	var fade := RATE / 2
	var m := n + fade
	var raw := PackedFloat32Array()
	raw.resize(m)
	var lp := 0.0
	var lp2 := 0.0
	var p1 := r.randf() * TAU
	var p2 := r.randf() * TAU
	for i in m:
		var t := float(i) / RATE
		lp += (r.randf_range(-1, 1) - lp) * (0.02 + bright)
		lp2 += (lp - lp2) * 0.08
		var g := 0.6 + 0.25 * sin(TAU * t / 8.0 + p1) + 0.15 * sin(TAU * t / 2.0 + p2)
		raw[i] = lp2 * g * amp * 6.0
	return _loopify(raw, n, fade)


static func _rain(r: RandomNumberGenerator, n: int) -> PackedFloat32Array:
	var fade := RATE / 2
	var m := n + fade
	var raw := PackedFloat32Array()
	raw.resize(m)
	var lp := 0.0
	var lp2 := 0.0
	for i in m:
		var nz := r.randf_range(-1, 1)
		lp += (nz - lp) * 0.45
		lp2 += (lp - lp2) * 0.05
		raw[i] = (lp - lp2) * 0.22 + lp2 * 0.5
	var s := _loopify(raw, n, fade)
	for k in 90:
		var at := r.randi_range(0, n - 1)
		var f := r.randf_range(1800, 4200)
		for j in int(0.012 * RATE):
			var t := float(j) / RATE
			s[(at + j) % n] += sin(TAU * f * t) * exp(-t * 400.0) * 0.12
	return s


static func _birds(r: RandomNumberGenerator, s: PackedFloat32Array, calls: int) -> void:
	var n := s.size()
	for c in calls:
		var at := r.randi_range(0, n - 1)
		var base := r.randf_range(2300, 3600)
		var notes := r.randi_range(2, 5)
		var amp := r.randf_range(0.03, 0.06)
		for k in notes:
			var ln := int(r.randf_range(0.05, 0.12) * RATE)
			var sweep := r.randf_range(-0.35, 0.45)
			var ph := 0.0
			for j in ln:
				var t := float(j) / ln
				ph += TAU * base * (1.0 + sweep * t + 0.04 * sin(TAU * 30.0 * j / RATE)) / RATE
				s[(at + j) % n] += sin(ph) * sin(PI * t) * amp
			at += ln + int(r.randf_range(0.03, 0.09) * RATE)


## Crickets: short chirps of 3-4 soft syllables (about 18 ms each) at
## slightly different pitches, timed with jitter so different crickets never
## line up into a buzz. Quiet and softened, like insects a little way off.
static func _crickets(r: RandomNumberGenerator, s: PackedFloat32Array) -> void:
	var n := s.size()
	var add := PackedFloat32Array()
	add.resize(n)
	for c in 4:
		var f := r.randf_range(3600, 4600)
		var gap := r.randf_range(0.55, 0.95)
		var amp := r.randf_range(0.012, 0.024)
		var syl := r.randi_range(3, 4)
		var at := r.randf_range(0.0, gap)
		while at < 8.0:
			for k in syl:
				var i0 := int((at + k * 0.04) * RATE)
				var ln := int(0.018 * RATE)
				var fk := f * r.randf_range(0.985, 1.015)
				for j in ln:
					var e := sin(PI * j / ln)
					add[(i0 + j) % n] += sin(TAU * fk * j / RATE) * e * e * amp
			# Each cricket keeps its own loose rhythm, never metronomic.
			at += gap * r.randf_range(0.8, 1.25) + (r.randf_range(0.6, 1.6) if r.randf() < 0.15 else 0.0)
	# A little way off: soften the highs, then mix in.
	var lp := 0.0
	for i in n:
		lp += (add[i] - lp) * 0.6
		s[i] += lp


## Two passes of a gentle low-pass, and a 3 ms fade at each end.
static func _soften(s: PackedFloat32Array) -> PackedFloat32Array:
	var a := 0.0
	var b := 0.0
	var n := s.size()
	var edge := int(0.003 * RATE)
	for i in n:
		a += (s[i] - a) * 0.5
		b += (a - b) * 0.5
		var g := minf(1.0, minf(float(i), float(n - 1 - i)) / edge)
		s[i] = b * g
	return s


static func _loopify(raw: PackedFloat32Array, n: int, fade: int) -> PackedFloat32Array:
	var s := raw.slice(0, n)
	for i in fade:
		var w := float(i) / fade
		s[i] = raw[i] * w + raw[n + i] * (1.0 - w)
	return s


# ---------------------------------------------------------------- output

static func _wav(s: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var d := PackedByteArray()
	d.resize(s.size() * 2)
	for i in s.size():
		d.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = d
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w
