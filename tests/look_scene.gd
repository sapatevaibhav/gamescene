extends Node
## Renders a few views of one style for a visual check (needs a window):
##   godot --path . res://tests/runner.tscn -- look_scene anime


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var style: String = args[1] if args.size() > 1 else "anime"
	get_window().size = Vector2i(1600, 900)
	var m: Node = load("res://src/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in 40:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("user://look/")
	get_viewport().get_texture().get_image().save_png("user://look/home.png")
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

		["aerial", func(): cam.mode = "free"; cam.free_pos = Vector3(40, 24, 88); cam.yaw = 0.0; cam.pitch = 0.42],
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
	m.hud.set_clean(false)
	m.hud.open_sheet("actor", m.studio.actors[1].id)
	for i in 30:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(dir + "%s-sheet.png" % style)
	m.hud.open_sheet("cast")
	for i in 10:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var vs := img.get_size()
	img.get_region(Rect2i(0, vs.y - 90, mini(vs.x, 520), 90)).save_png(dir + "dock.png")
	m.hud.close_sheet()
	m.studio.tools.set_tool("objects", {"prop": "oak"})
	for i in 10:
		await get_tree().process_frame
	img = get_viewport().get_texture().get_image()
	img.get_region(Rect2i(0, vs.y - 90, mini(vs.x, 520), 90)).save_png(dir + "toolbar.png")
	get_tree().quit()
