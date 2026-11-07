extends Node
## Runs one test script as a node so autoloads (App) exist:
##   godot --headless --path . res://tests/runner.tscn -- test_core


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var name: String = args[0] if args.size() > 0 else "test_core"
	var s: GDScript = load("res://tests/%s.gd" % name)
	var n: Node = s.new()
	add_child(n)
