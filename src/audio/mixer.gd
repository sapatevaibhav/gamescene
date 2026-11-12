class_name AudioMixer
## Renders the sound log of a recording into one track for the video. Each
## event is {t, key, cat, vol, from, loop, until, fi, fo}: start `key` at `t`
## seconds into the video, `from` seconds into the sound, optionally looping,
## stopping at `until` (or the end), with fade in/out times. Streams are
## decoded through AudioStreamPlayback.mix_audio, so .ogg/.mp3/.wav and the
## built-in sounds all work, with or without ffmpeg.

const RATE := 44100


## Mono samples for `dur` seconds. `vols` scales each category
## ("music", "sfx", "amb").
static func render(events: Array, dur: float, vols: Dictionary) -> PackedFloat32Array:
	var live := Live.new(vols)
	return live.finish(events, dur)


## Mixes a recording's sound log a little at a time while it records
## (Recorder calls mix_to every few frames), so stopping only has the last
## moment left to mix. Sounds start at or after "now" and only end later, so
## everything before the current time is final.
class Live:
	extends RefCounted
	var out := PackedFloat32Array()
	## Samples mixed so far.
	var done := 0
	var vols := {}
	var _decoded := {}
	## Events not finished yet (indices into the log), and how many of the
	## log's events have been seen.
	var _active: Array = []
	var _seen := 0

	func _init(v: Dictionary) -> void:
		vols = v

	## Mixes everything up to `t` seconds.
	func mix_to(events: Array, t: float) -> void:
		var n := int(t * RATE)
		if n <= done:
			return
		while _seen < events.size():
			_active.append(_seen)
			_seen += 1
		out.resize(n)
		var still := []
		for k in _active:
			if AudioMixer._add(events[k], out, done, n, _decoded, vols):
				still.append(k)
		_active = still
		# Gentle limiter so busy scenes don't clip.
		for i in range(done, n):
			var x := out[i]
			if absf(x) > 0.8:
				out[i] = signf(x) * (0.8 + (absf(x) - 0.8) / (1.0 + (absf(x) - 0.8) * 5.0))
		done = n

	## The whole track, `dur` seconds long.
	func finish(events: Array, dur: float) -> PackedFloat32Array:
		var n := int(ceil(dur * RATE))
		mix_to(events, float(n) / RATE + 0.5 / RATE)
		var o := out.duplicate()
		o.resize(n)
		return o


## Adds samples [a, b) of one logged sound to `out`. Returns false once the
## sound has ended (nothing after b to add).
static func _add(e: Dictionary, out: PackedFloat32Array, a: int, b: int, decoded: Dictionary, vols: Dictionary) -> bool:
	var key := str(e.get("key", ""))
	if not decoded.has(key):
		decoded[key] = decode(Sounds.stream(key))
	var pcm: PackedFloat32Array = decoded[key]
	var m := pcm.size()
	if m == 0:
		return false
	var gain := float(e.get("vol", 1.0)) * float(vols.get(str(e.get("cat", "sfx")), 1.0))
	if gain <= 0.001:
		return false
	var i0 := int(float(e.get("t", 0.0)) * RATE)
	var i1 := 1 << 40
	var ended := false
	if e.has("until") and float(e["until"]) >= 0.0:
		i1 = int(float(e["until"]) * RATE)
		ended = true
	var loop: bool = e.get("loop", false)
	var from := int(float(e.get("from", 0.0)) * RATE)
	if not loop:
		i1 = mini(i1, i0 + m - from)
		ended = true
	var lo := maxi(a, maxi(i0, 0))
	var hi := mini(b, i1)
	var fi := maxi(1, int(float(e.get("fi", 0.0)) * RATE))
	var fo := maxi(1, int(float(e.get("fo", 0.0)) * RATE))
	var span := i1 - i0
	if hi > lo:
		var src := posmod(from + (lo - i0), m)
		for i in range(lo, hi):
			var j := i - i0
			var g := gain
			if j < fi:
				g *= float(j) / fi
			if span - j < fo:
				g *= float(span - j) / fo
			out[i] += pcm[src] * g
			src += 1
			if src >= m:
				src = 0
	return not (ended and i1 <= b)


## One pass of a stream as mono samples at RATE.
static func decode(s: AudioStream) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if s == null:
		return out
	var ln := Sounds.duration(s)
	if ln <= 0.0:
		return out
	var frames := int(ceil(ln * RATE))
	var pb := s.instantiate_playback()
	if pb == null:
		return out
	pb.start(0.0)
	var buf := pb.mix_audio(1.0, frames)
	pb.stop()
	out.resize(buf.size())
	for i in buf.size():
		var v := buf[i]
		out[i] = (v.x + v.y) * 0.5
	return out


## 16-bit PCM bytes (little endian) for the samples.
static func pcm16(s: PackedFloat32Array) -> PackedByteArray:
	var d := PackedByteArray()
	d.resize(s.size() * 2)
	for i in s.size():
		d.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32767.0))
	return d


## Writes a mono 16-bit WAV file.
static func save_wav(path: String, s: PackedFloat32Array) -> bool:
	var data := pcm16(s)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + data.size())
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(1)
	f.store_32(RATE)
	f.store_32(RATE * 2)
	f.store_16(2)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(data.size())
	f.store_buffer(data)
	f.close()
	return true
