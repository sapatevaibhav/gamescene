extends Node
## Runs one test script as a node so autoloads (App) exist:
##   godot --headless --path . res://tests/runner.tscn -- test_core


const SCRATCH := "user://test_projects/"
## Holding the classes keeps their redirected static paths alive: Godot
## unloads (and resets) scripts nothing references.
var _hold := [ProjectStore, ModelRig, AssetLib, AudioFiles, Recorder, AnimLib, Poses, Licence]


func _ready() -> void:
	# Scenes made by tests go to a scratch folder, wiped before and after, so
	# they never show up on the real home screen.
	_wipe()
	ProjectStore.DIR = SCRATCH
	ModelRig.DIR = SCRATCH + "models/"
	AssetLib.DIR = SCRATCH + "props/"
	AudioFiles.DIR = SCRATCH + "audio/"
	AnimLib.DIR = SCRATCH + "anims/"
	Poses.FILE = SCRATCH + "poses.json"
	Licence.FILE = SCRATCH + "licence.gslicence"
	# Device settings changed by a test (the tour, ...) stay in the scratch
	# folder too; the user's own are only read.
	App.device_file = SCRATCH + "device.json"
	Recorder.DIR_OVERRIDE = SCRATCH + "exports/"
	Recorder.JOB_DIR = SCRATCH + "jobs/"
	AssetTags.reload()
	var args := OS.get_cmdline_user_args()
	var name: String = args[0] if args.size() > 0 else "test_core"
	var s: GDScript = load("res://tests/%s.gd" % name)
	if s == null or not s.can_instantiate():
		# A test that doesn't load (parse error) fails at once, instead of
		# leaving the runner waiting forever.
		push_error("FAIL: test script %s didn't load" % name)
		get_tree().quit(1)
		return
	# A hung test fails after 10 minutes instead of blocking the run.
	get_tree().create_timer(600.0).timeout.connect(func():
		push_error("FAIL: %s took over 10 minutes" % name)
		get_tree().quit(1))
	var n: Node = s.new()
	add_child(n)


func _exit_tree() -> void:
	_wipe()


static func _wipe() -> void:
	_rm(SCRATCH)


static func _rm(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		_rm(dir.path_join(sub))
	DirAccess.remove_absolute(dir)
