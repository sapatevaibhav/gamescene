extends Node
## Runs one test script as a node so autoloads (App) exist:
##   godot --headless --path . res://tests/runner.tscn -- test_core


const SCRATCH := "user://test_projects/"
## Holding the classes keeps their redirected static paths alive: Godot
## unloads (and resets) scripts nothing references.
var _hold := [ProjectStore, ModelRig, AssetLib]


func _ready() -> void:
	# Scenes made by tests go to a scratch folder, wiped before and after, so
	# they never show up on the real home screen.
	_wipe()
	ProjectStore.DIR = SCRATCH
	ModelRig.DIR = SCRATCH + "models/"
	AssetLib.DIR = SCRATCH + "props/"
	AssetTags.reload()
	var args := OS.get_cmdline_user_args()
	var name: String = args[0] if args.size() > 0 else "test_core"
	var s: GDScript = load("res://tests/%s.gd" % name)
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
