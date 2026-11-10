class_name AudioFiles
## Imported music and sounds (.ogg, .mp3, .wav), kept in user://assets/audio/
## and shared by every scene. Ids are "<slug>~<hash>.<ext>" so re-importing
## the same file reuses it. Project files embed the ones a scene uses.

const EXTS := ["ogg", "mp3", "wav"]

static var DIR := "user://assets/audio/"
static var last_error := ""
static var _streams := {}


static func import_file(path: String) -> String:
	last_error = ""
	var ext := path.get_extension().to_lower()
	if not ext in EXTS:
		last_error = "Use an .ogg, .mp3 or .wav file."
		return ""
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		last_error = "That file couldn’t be read."
		return ""
	if bytes.size() > 60 * 1024 * 1024:
		last_error = "That file is too big (up to 60 MB)."
		return ""
	var id := U.slug(path.get_file().get_basename()) + "~%06x" % (hash(bytes.slice(0, mini(bytes.size(), 200000))) & 0xFFFFFF) + "." + ext
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(DIR + id, FileAccess.WRITE)
	if f == null:
		last_error = "Couldn’t save the sound."
		return ""
	f.store_buffer(bytes)
	f.close()
	_streams.erase(id)
	if stream(id) == null:
		DirAccess.remove_absolute(DIR + id)
		last_error = "That file isn’t a sound Godot can play."
		return ""
	return id


static func list() -> Array:
	if not DirAccess.dir_exists_absolute(DIR):
		return []
	var out := Array(DirAccess.get_files_at(DIR)).filter(func(f): return str(f).get_extension().to_lower() in EXTS)
	out.sort()
	return out


static func has(id: String) -> bool:
	return FileAccess.file_exists(DIR + id)


static func display_name(id: String) -> String:
	return id.get_basename().split("~")[0].replace("-", " ").capitalize()


static func remove(id: String) -> void:
	_streams.erase(id)
	DirAccess.remove_absolute(DIR + id)


static func stream(id: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	if not has(id):
		return null
	var s: AudioStream = null
	match id.get_extension().to_lower():
		"ogg":
			s = AudioStreamOggVorbis.load_from_file(DIR + id)
		"mp3":
			s = AudioStreamMP3.load_from_file(DIR + id)
		"wav":
			s = AudioStreamWAV.load_from_file(DIR + id)
	if s != null and s.get_length() <= 0.0:
		s = null
	_streams[id] = s
	return s
