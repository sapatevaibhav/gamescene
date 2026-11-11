class_name Media
## Your recordings and screenshots, for the home screen: files in the videos
## and pictures folders (Recorder.output_dir), newest first, with
## thumbnails made in the background and cached in user://cache/thumbs/.

const VIDEO_EXTS := ["mp4", "avi", "mov"]
const THUMB_DIR := "user://cache/thumbs/"

static var _thumbs := {}
static var _lock := Mutex.new()
## Thumbnail jobs still running (waited for when the app quits).
static var _tasks: Array = []


## Waits for every thumbnail job (the app is quitting).
static func wait_all() -> void:
	for t in _tasks:
		WorkerThreadPool.wait_for_task_completion(t)
	_tasks.clear()


## [{path, name, time, bytes, kind}] where kind is "video", "frames" (a PNG
## sequence folder) or "image".
static func recordings() -> Array:
	var dir := Recorder.output_dir("video")
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.begins_with(".") or not f.get_extension().to_lower() in VIDEO_EXTS:
			continue
		out.append(_item(dir.path_join(f), "video"))
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or not FileAccess.file_exists(dir.path_join(d).path_join("frame_00001.png")):
			continue
		var it := _item(dir.path_join(d), "frames")
		it["frames"] = Array(DirAccess.get_files_at(dir.path_join(d))).filter(func(x): return str(x).ends_with(".png")).size()
		out.append(it)
	out.sort_custom(func(a, b): return int(a["time"]) > int(b["time"]))
	return out


static func screenshots() -> Array:
	var dir := Recorder.output_dir("image")
	var out := []
	for f in DirAccess.get_files_at(dir):
		if f.begins_with(".") or f.get_extension().to_lower() != "png":
			continue
		out.append(_item(dir.path_join(f), "image"))
	out.sort_custom(func(a, b): return int(a["time"]) > int(b["time"]))
	return out


static func _item(path: String, kind: String) -> Dictionary:
	var t := FileAccess.get_modified_time(path) if kind != "frames" else FileAccess.get_modified_time(path.path_join("frame_00001.png"))
	var bytes := 0
	if kind != "frames":
		var f := FileAccess.open(path, FileAccess.READ)
		if f:
			bytes = f.get_length()
	return {"path": path, "name": path.get_file().get_basename() if kind != "frames" else path.get_file(), "time": t, "bytes": bytes, "kind": kind}


static func size_text(bytes: int) -> String:
	if bytes >= 1024 * 1024 * 1024:
		return "%.1f GB" % (bytes / 1073741824.0)
	if bytes >= 1024 * 1024:
		return "%.1f MB" % (bytes / 1048576.0)
	return "%d KB" % maxi(1, bytes / 1024)


## A cached thumbnail, or null (then call thumb_async).
static func cached_thumb(item: Dictionary) -> Texture2D:
	_lock.lock()
	var t: Texture2D = _thumbs.get(_key(item))
	_lock.unlock()
	return t


static func _key(item: Dictionary) -> String:
	return "%s|%d" % [item["path"], int(item["time"])]


## Makes the thumbnail on a worker thread and calls `cb(texture)` on the main
## thread (texture may be null: no ffmpeg for a video, or a bad file).
static func thumb_async(item: Dictionary, cb: Callable) -> void:
	# Release finished jobs (every job must be waited for once, or the
	# thread pool crashes when the app quits).
	var running := []
	for t in _tasks:
		if WorkerThreadPool.is_task_completed(t):
			WorkerThreadPool.wait_for_task_completion(t)
		else:
			running.append(t)
	_tasks = running
	_tasks.append(WorkerThreadPool.add_task(func():
		var img := _make_thumb(item)
		var tex: Texture2D = ImageTexture.create_from_image(img) if img else null
		_lock.lock()
		_thumbs[_key(item)] = tex
		_lock.unlock()
		cb.call_deferred(tex), false, "Thumbnail"))


static func _make_thumb(item: Dictionary) -> Image:
	var src := str(item["path"])
	match str(item["kind"]):
		"image":
			return _small(Image.load_from_file(src))
		"frames":
			return _small(Image.load_from_file(src.path_join("frame_00001.png")))
	# Video: one frame through ffmpeg, cached on disk.
	DirAccess.make_dir_recursive_absolute(THUMB_DIR)
	var cache := ProjectSettings.globalize_path(THUMB_DIR + "%x.png" % hash(_key(item)))
	if not FileAccess.file_exists(cache):
		var ff := Recorder.ffmpeg_path()
		if ff == "":
			return null
		OS.execute(ff, ["-hide_banner", "-loglevel", "error", "-y", "-ss", "0.5", "-i", src, "-frames:v", "1", "-vf", "scale=480:-2", cache], [], false)
	return Image.load_from_file(cache) if FileAccess.file_exists(cache) else null


static func _small(img: Image) -> Image:
	if img == null or img.is_empty():
		return null
	var w := 480
	if img.get_width() > w:
		img.resize(w, maxi(1, int(img.get_height() * float(w) / img.get_width())), Image.INTERPOLATE_BILINEAR)
	return img


## Phones have no file manager to point at: they share instead.
static func can_reveal() -> bool:
	return not App.is_mobile


## How many files one reveal can highlight: all of them on Linux (one
## request), one on Windows and macOS (Explorer and Finder take one file).
static func reveal_limit() -> int:
	return 1 << 20 if _linux() else 1


static func _linux() -> bool:
	return OS.get_name() in ["Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]


## Opens the folder with these files highlighted (as many as reveal_limit()
## allows; the first ones). On Linux this asks the file manager over D-Bus
## (org.freedesktop.FileManager1.ShowItems: Thunar, Nautilus, Dolphin, Nemo,
## Caja); elsewhere, or if that fails, Godot's own reveal (Explorer /select,
## Finder). Returns how many were highlighted.
static func reveal(paths: Array) -> int:
	if paths.is_empty():
		return 0
	if _linux():
		var uris := []
		for p in paths:
			uris.append("'file://%s'" % str(p).uri_encode().replace("%2F", "/"))
		var out := []
		var code := OS.execute("gdbus", ["call", "--session", "--dest", "org.freedesktop.FileManager1", "--object-path", "/org/freedesktop/FileManager1",
			"--method", "org.freedesktop.FileManager1.ShowItems", "[%s]" % ", ".join(uris), ""], out, true)
		if code == 0:
			return paths.size()
	OS.shell_show_in_file_manager(str(paths[0]))
	return 1


## The name of the share plugin a phone build can include: a singleton with
## share(paths: PackedStringArray, title: String) that opens the system share
## sheet (Android intent, iOS UIActivityViewController). Set up with the
## phone packaging.
const SHARE_PLUGIN := "GameSceneShare"


## Shares files through the system share sheet when the build has the share
## plugin; otherwise opens the first file in the phone's viewer, whose own
## share button is one tap away.
static func share(paths: Array) -> void:
	if paths.is_empty():
		return
	if Engine.has_singleton(SHARE_PLUGIN):
		Engine.get_singleton(SHARE_PLUGIN).call("share", PackedStringArray(paths.map(func(p): return str(p))), "GameScene Studio")
		return
	OS.shell_open(str(paths[0]))


static func remove(item: Dictionary) -> void:
	var p := str(item["path"])
	if item["kind"] == "frames":
		Recorder._rm_dir(p)
	else:
		DirAccess.remove_absolute(p)
