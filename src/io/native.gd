class_name Native
## Phone features from the platform plugin: the Android plugin in
## platform/android (singleton "GameSceneNative", added to Android exports by
## addons/gamescene_native). Every call has a fallback, so desktop builds and
## phone builds without the plugin keep working:
##
## - share(): the system share sheet (else the file opens in its viewer).
## - save_to_gallery(): copies an export into the phone's gallery.
## - take_opened_file() / file_opened: a project another app opened us with.
## - The H.264 encoder (enc_open / enc_frame / enc_close) and mux_start /
##   mux_state, which join segments and add the soundtrack: phones record MP4
##   without ffmpeg (Recorder uses these when ffmpeg is missing).
## - video_thumbnail(): a frame of a video for the Recordings tab.

const SINGLETON := "GameSceneNative"
## The gallery album (Movies/… and Pictures/…).
const ALBUM := "GameScene Studio"

## Tests: an object that stands in for the plugin (same method names).
static var fake: Object = null
static var _can_encode := -1


static func plugin() -> Object:
	if fake != null:
		return fake
	if Engine.has_singleton(SINGLETON):
		return Engine.get_singleton(SINGLETON)
	return null


static func available() -> bool:
	return plugin() != null


## True when MP4 can be made without ffmpeg (the phone's H.264 encoder).
static func can_encode() -> bool:
	var p := plugin()
	if p == null:
		return false
	if fake != null:
		return bool(p.call("can_encode"))
	if _can_encode < 0:
		_can_encode = 1 if p.call("can_encode") else 0
	return _can_encode == 1


## Opens the share sheet for these files. False when there is no share sheet.
static func share(paths: Array, title := "GameScene Studio") -> bool:
	var p := plugin()
	if p == null or paths.is_empty():
		return false
	return bool(p.call("share", PackedStringArray(paths.map(func(x): return str(x))), title))


## Copies a finished video or picture into the gallery. Returns where it went
## ("" if it couldn't).
static func save_to_gallery(path: String) -> String:
	var p := plugin()
	if p == null:
		return ""
	return str(p.call("save_to_gallery", path, ALBUM))


## A project file another app opened us with since the last call, or "".
static func take_opened_file() -> String:
	var p := plugin()
	if p == null:
		return ""
	return str(p.call("take_opened_file"))


## Calls `cb(path)` whenever another app opens a file with us while running.
static func on_file_opened(cb: Callable) -> void:
	var p := plugin()
	if p != null and p.has_signal("file_opened") and not p.is_connected("file_opened", cb):
		p.connect("file_opened", cb)


# ---------------------------------------------------------------- encoder

## Starts an H.264 MP4 file; returns an id, or -1.
static func enc_open(path: String, size: Vector2i, fps: int) -> int:
	var p := plugin()
	if p == null:
		return -1
	return int(p.call("enc_open", path, size.x, size.y, fps, 0))


static func enc_frame(id: int, img: Image) -> bool:
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return bool(plugin().call("enc_frame", id, img.get_data()))


static func enc_close(id: int) -> bool:
	var p := plugin()
	return p != null and bool(p.call("enc_close", id))


## Joins MP4 segments in order and adds `wav` ("" for none) as AAC sound,
## in the background; poll mux_state().
static func mux_start(segments: Array, wav: String, out: String, fps: int) -> bool:
	var p := plugin()
	return p != null and bool(p.call("mux_start", PackedStringArray(segments.map(func(x): return str(x))), wav, out, fps))


## "", "running", "ok" or "error: …".
static func mux_state() -> String:
	var p := plugin()
	return str(p.call("mux_state")) if p != null else ""


## Saves a frame of a video as a PNG `width` pixels wide.
static func video_thumbnail(path: String, out: String, width := 480) -> bool:
	var p := plugin()
	if p == null:
		return false
	return bool(p.call("video_thumbnail", path, out, width))
