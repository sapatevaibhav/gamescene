extends Node
## Global app state (autoload "App"): settings, device tier, notifications.

signal toast_requested(msg: String)
signal settings_changed

const SCHEMA_VERSION := 5

## Per-scene settings are saved with the project; device settings are not.
var settings := {
	"time": 11.0, "cycle": false, "weather": "clear", "fog": 110.0, "mood": "day",
	"frame": "full", "fov": 70.0, "shake": false, "dof": false, "subtitles": true,
	"fps": 30, "countdown": 3, "restart": true, "res": "1080",
	"music": "mood", "music_vol": 0.7, "sfx": true, "sfx_vol": 0.8, "ambience": "auto", "amb_vol": 0.6,
	"sub_style": "box", "sub_size": "m", "sub_pos": "bottom", "sub_names": true, "bg": "scene",
}

const SCENE_KEYS := ["time", "cycle", "weather", "fog", "mood", "frame", "fov", "shake", "dof", "subtitles", "fps", "countdown", "restart", "res",
	"music", "music_vol", "sfx", "sfx_vol", "ambience", "amb_vol", "sub_style", "sub_size", "sub_pos", "sub_names", "bg"]
## Sound, subtitle and export background settings a new (or older) scene
## starts with.
const SCENE_DEFAULTS := {"music": "mood", "music_vol": 0.7, "sfx": true, "sfx_vol": 0.8, "ambience": "auto", "amb_vol": 0.6,
	"sub_style": "box", "sub_size": "m", "sub_pos": "bottom", "sub_names": true, "bg": "scene"}

var device := {
	"quality": "high", "show_fps": false, "names": true, "auto_jump": true, "mouse_look": "drag", "ui_scale": 1.0, "ui_sounds": true, "cool_down": false,
}

var is_touch := false
var is_mobile := false

## Fixed simulation step while recording (0 = real time).
var fixed_dt := 0.0
## RNG for scene simulation; reseeded for deterministic takes.
var sim_rng := RandomNumberGenerator.new()

const QUALITY := {
	"low": {"label": "Battery saver", "scale": 0.6, "shadow": 1024, "ssao": false, "ssil": false, "vfog": false, "glow": false, "msaa": 0, "grass": 0.35, "cast": 16, "lights": 0, "fxaa": true},
	"balanced": {"label": "Balanced", "scale": 0.8, "shadow": 2048, "ssao": false, "ssil": false, "vfog": false, "glow": true, "msaa": 0, "grass": 0.6, "cast": 24, "lights": 4, "fxaa": true},
	"high": {"label": "High", "scale": 1.0, "shadow": 4096, "ssao": true, "ssil": false, "vfog": true, "glow": true, "msaa": 2, "grass": 1.0, "cast": 40, "lights": 10, "fxaa": false},
	"ultra": {"label": "Cinematic", "scale": 1.0, "shadow": 8192, "ssao": true, "ssil": true, "vfog": true, "glow": true, "msaa": 4, "grass": 1.4, "cast": 60, "lights": 16, "fxaa": false},
}

const RES := {
	"720": {"label": "720p", "h": 720},
	"1080": {"label": "1080p", "h": 1080},
	"1440": {"label": "1440p", "h": 1440},
	"2160": {"label": "4K", "h": 2160},
}

const FRAMES := {"full": 0.0, "16:9": 16.0 / 9.0, "9:16": 9.0 / 16.0, "1:1": 1.0}


func _ready() -> void:
	is_mobile = OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios")
	is_touch = is_mobile or DisplayServer.is_touchscreen_available()
	device["quality"] = "balanced" if is_mobile else "high"
	# Integrated GPUs (Intel UHD/Iris, AMD APUs) default to Balanced.
	if RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_INTEGRATED_GPU:
		device["quality"] = "balanced"
	# Desktop: the mouse drives the camera (Esc frees the cursor).
	device["mouse_look"] = "drag" if is_mobile else "capture"
	if is_mobile:
		settings["res"] = "720"
		# Phones get hot on long exports: pause to cool down by default.
		device["cool_down"] = true
	load_device()
	sim_rng.randomize()
	# Make the music ahead of time, but not in headless runs (tests, tools):
	# they make a tune only when they need it.
	if DisplayServer.get_name() != "headless":
		_warm = WorkerThreadPool.add_task(Synth.prewarm, false, "Make music")


var _warm := -1


func _exit_tree() -> void:
	if _warm >= 0:
		Synth.stop_prewarm = true
		WorkerThreadPool.wait_for_task_completion(_warm)
		_warm = -1


func q() -> Dictionary:
	return QUALITY.get(device["quality"], QUALITY["high"])


func toast(msg: String) -> void:
	toast_requested.emit(msg)


func reset_scene_defaults() -> void:
	for k in SCENE_DEFAULTS:
		settings[k] = SCENE_DEFAULTS[k]


var _ui_player: AudioStreamPlayer


## Interface sounds (the countdown's "beep" and "go"), on the UI bus; off
## with the "Countdown beeps" setting.
func ui(name := "click") -> void:
	if not device.get("ui_sounds", true) or DisplayServer.get_name() == "headless":
		return
	if _ui_player == null:
		SoundDirector.ensure_buses()
		_ui_player = AudioStreamPlayer.new()
		_ui_player.bus = "UI"
		_ui_player.max_polyphony = 4
		add_child(_ui_player)
	_ui_player.stream = Synth.sfx(name)
	_ui_player.play()


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	settings_changed.emit()


func set_device(key: String, value: Variant) -> void:
	device[key] = value
	save_device()
	settings_changed.emit()


func sim_randf() -> float:
	return sim_rng.randf()


func save_device() -> void:
	device["mouse_v"] = 2
	device["quality_v"] = 2
	var f := FileAccess.open("user://device.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(device))


func load_device() -> void:
	if not FileAccess.file_exists("user://device.json"):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://device.json"))
	if d is Dictionary:
		for k in d:
			# Saves from before mouse capture became the default keep the new default.
			if k == "mouse_look" and not d.has("mouse_v"):
				continue
			if k == "quality" and not d.has("quality_v"):
				continue
			if device.has(k):
				device[k] = d[k]


## Height in pixels of the chosen export resolution and frame aspect.
func export_size(window_aspect: float) -> Vector2i:
	var h: int = RES.get(str(settings["res"]), RES["1080"])["h"]
	var r: float = FRAMES.get(settings["frame"], 0.0)
	if r <= 0.0:
		r = window_aspect
	var w: int
	if r >= 1.0:
		w = int(round(h * r))
	else:
		# Portrait: the resolution names the short side.
		w = h
		h = int(round(w / r))
	return Vector2i(w & ~1, h & ~1)
