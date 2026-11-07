extends Node
## Imports a character file and builds it:
##   godot --headless --path . res://tests/runner.tscn -- test_fbx /path/to/model.fbx
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("usage: -- test_fbx /path/to/model.(fbx|glb|vrm|gltf)  (skipped)")
		get_tree().quit(0)
		return
	var path: String = args[1]
	var id := ModelRig.import_file(path)
	print("import id: '%s'" % id)
	if id != "":
		var rig := ModelRig.build({"model": id})
		print("height %.2f  clips %s  bones %s  skeleton %s" % [rig["height"], rig["clips"].keys(), rig["bones"].keys(), rig["skel"] != null])
	get_tree().quit(0 if id != "" else 1)
