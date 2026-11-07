extends Node
## Renders a few views of one style for a visual check (needs a window):
##   godot --path . res://tests/runner.tscn -- test_look anime


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var style: String = args[1] if args.size() > 1 else "anime"
	get_window().size = Vector2i(1600, 900)
	var m: Node = load("res://src/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().process_frame
	await get_tree().process_frame
	await m._new_scene(style)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	m.hud.set_clean(true)
	m.hud.restore_btn.visible = false
	var dir := "user://look/"
	DirAccess.make_dir_recursive_absolute(dir)
	var cam: CameraRig = m.studio.camera
	var shots := [
		["third", func(): cam.mode = "third"; cam.yaw = PI + 0.4; cam.pitch = 0.18; cam.dist = 5.0],
		["face", func():
			var pl: Actor = m.studio.player
			pl.yaw = 0.0
			cam.mode = "free"
			cam.free_pos = pl.pos + Vector3(0.25, pl.height() * 0.86, 1.25)
			cam.yaw = 0.2
			cam.pitch = 0.08],
		["group", func():
			var pl: Actor = m.studio.player
			cam.mode = "free"
			cam.free_pos = pl.pos + Vector3(0, 1.6, 6.0)
			cam.yaw = 0.0
			cam.pitch = 0.08],

		["aerial", func(): cam.mode = "free"; cam.free_pos = Vector3(-6, 22, -6); cam.yaw = PI * 1.25; cam.pitch = 0.45],
	]
	for s in shots:
		s[1].call()
		for i in 45:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(dir + "%s-%s.png" % [style, s[0]])
		var t0 := Time.get_ticks_usec()
		for i in 60:
			await get_tree().process_frame
		print("%s fps: %.1f (quality %s)" % [s[0], 60.0 / ((Time.get_ticks_usec() - t0) / 1e6), App.device["quality"]])
	get_tree().quit()
