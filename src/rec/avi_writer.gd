class_name AviWriter
extends RefCounted
## Minimal Motion-JPEG AVI writer in pure GDScript. Used when ffmpeg is not
## available (phones, locked-down desktops) so video export always works.
## With `audio_rate` > 0 it also has a mono 16-bit PCM sound stream, written
## at the end with write_audio().

var _f: FileAccess
var _w := 0
var _h := 0
var _fps := 30
var _frames := 0
var _index := PackedByteArray()
var _movi_start := 0
var _riff_size_pos := 0
var _movi_size_pos := 0
var _avih_frames_pos := 0
var _strh_len_pos := 0
var _auds_len_pos := 0
var _audio_rate := 0
var _audio_samples := 0
var quality := 0.9


func open(path: String, w: int, h: int, fps: int, audio_rate := 0) -> bool:
	_f = FileAccess.open(path, FileAccess.WRITE)
	if _f == null:
		return false
	_w = w
	_h = h
	_fps = fps
	_audio_rate = audio_rate
	var auds_list := (8 + 4 + 8 + 56 + 8 + 18) if audio_rate > 0 else 0
	_f.store_buffer("RIFF".to_ascii_buffer())
	_riff_size_pos = _f.get_position()
	_f.store_32(0)
	_f.store_buffer("AVI ".to_ascii_buffer())
	# hdrl
	_f.store_buffer("LIST".to_ascii_buffer())
	_f.store_32(4 + 8 + 56 + 8 + 4 + 8 + 56 + 8 + 40 + auds_list)
	_f.store_buffer("hdrl".to_ascii_buffer())
	_f.store_buffer("avih".to_ascii_buffer())
	_f.store_32(56)
	_f.store_32(int(1000000.0 / fps))
	_f.store_32(0)
	_f.store_32(0)
	_f.store_32(0x10)  # AVIF_HASINDEX
	_avih_frames_pos = _f.get_position()
	_f.store_32(0)
	_f.store_32(0)
	_f.store_32(2 if audio_rate > 0 else 1)
	_f.store_32(0)
	_f.store_32(w)
	_f.store_32(h)
	for _i in 4:
		_f.store_32(0)
	# strl
	_f.store_buffer("LIST".to_ascii_buffer())
	_f.store_32(4 + 8 + 56 + 8 + 40)
	_f.store_buffer("strl".to_ascii_buffer())
	_f.store_buffer("strh".to_ascii_buffer())
	_f.store_32(56)
	_f.store_buffer("vids".to_ascii_buffer())
	_f.store_buffer("MJPG".to_ascii_buffer())
	_f.store_32(0)
	_f.store_16(0)
	_f.store_16(0)
	_f.store_32(0)
	_f.store_32(1)
	_f.store_32(fps)
	_f.store_32(0)
	_strh_len_pos = _f.get_position()
	_f.store_32(0)
	_f.store_32(0)
	_f.store_32(0xFFFFFFFF)
	_f.store_32(0)
	_f.store_16(0)
	_f.store_16(0)
	_f.store_16(w)
	_f.store_16(h)
	_f.store_buffer("strf".to_ascii_buffer())
	_f.store_32(40)
	_f.store_32(40)
	_f.store_32(w)
	_f.store_32(h)
	_f.store_16(1)
	_f.store_16(24)
	_f.store_buffer("MJPG".to_ascii_buffer())
	_f.store_32(w * h * 3)
	for _i in 4:
		_f.store_32(0)
	if audio_rate > 0:
		_f.store_buffer("LIST".to_ascii_buffer())
		_f.store_32(4 + 8 + 56 + 8 + 18)
		_f.store_buffer("strl".to_ascii_buffer())
		_f.store_buffer("strh".to_ascii_buffer())
		_f.store_32(56)
		_f.store_buffer("auds".to_ascii_buffer())
		_f.store_32(0)
		_f.store_32(0)
		_f.store_16(0)
		_f.store_16(0)
		_f.store_32(0)
		_f.store_32(2)  # scale = block align
		_f.store_32(audio_rate * 2)  # rate = bytes per second
		_f.store_32(0)
		_auds_len_pos = _f.get_position()
		_f.store_32(0)
		_f.store_32(audio_rate * 2)
		_f.store_32(0xFFFFFFFF)
		_f.store_32(2)
		for _i in 4:
			_f.store_16(0)
		_f.store_buffer("strf".to_ascii_buffer())
		_f.store_32(18)
		_f.store_16(1)  # PCM
		_f.store_16(1)  # mono
		_f.store_32(audio_rate)
		_f.store_32(audio_rate * 2)
		_f.store_16(2)
		_f.store_16(16)
		_f.store_16(0)
	# movi
	_f.store_buffer("LIST".to_ascii_buffer())
	_movi_size_pos = _f.get_position()
	_f.store_32(0)
	_movi_start = _f.get_position()
	_f.store_buffer("movi".to_ascii_buffer())
	return true


func write_frame(img: Image) -> void:
	var jpg := img.save_jpg_to_buffer(quality)
	var pad := jpg.size() & 1
	var offset := _f.get_position() - _movi_start
	_f.store_buffer("00dc".to_ascii_buffer())
	_f.store_32(jpg.size())
	_f.store_buffer(jpg)
	if pad:
		_f.store_8(0)
	var e := PackedByteArray()
	e.append_array("00dc".to_ascii_buffer())
	e.resize(16)
	e.encode_u32(4, 0x10)
	e.encode_u32(8, offset)
	e.encode_u32(12, jpg.size())
	_index.append_array(e)
	_frames += 1


## Appends the sound track (mono 16-bit PCM), in one-second chunks.
func write_audio(pcm: PackedByteArray) -> void:
	if _f == null or _audio_rate <= 0:
		return
	var step := _audio_rate * 2
	var at := 0
	while at < pcm.size():
		var part := pcm.slice(at, mini(pcm.size(), at + step))
		var offset := _f.get_position() - _movi_start
		_f.store_buffer("01wb".to_ascii_buffer())
		_f.store_32(part.size())
		_f.store_buffer(part)
		if part.size() & 1:
			_f.store_8(0)
		var e := PackedByteArray()
		e.append_array("01wb".to_ascii_buffer())
		e.resize(16)
		e.encode_u32(4, 0x10)
		e.encode_u32(8, offset)
		e.encode_u32(12, part.size())
		_index.append_array(e)
		at += step
	_audio_samples += pcm.size() / 2


func close() -> void:
	if _f == null:
		return
	var movi_end := _f.get_position()
	_f.store_buffer("idx1".to_ascii_buffer())
	_f.store_32(_index.size())
	_f.store_buffer(_index)
	var end := _f.get_position()
	_f.seek(_riff_size_pos)
	_f.store_32(end - 8)
	_f.seek(_movi_size_pos)
	_f.store_32(movi_end - _movi_start)
	_f.seek(_avih_frames_pos)
	_f.store_32(_frames)
	_f.seek(_strh_len_pos)
	_f.store_32(_frames)
	if _audio_rate > 0:
		_f.seek(_auds_len_pos)
		_f.store_32(_audio_samples)
	_f.close()
	_f = null
