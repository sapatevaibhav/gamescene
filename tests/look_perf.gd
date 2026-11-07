extends Node
## Frame-time breakdown for one style (needs a window):
##   godot --path . res://tests/runner.tscn -- look_perf anime


func _measure() -> String:
	for i in 20:
		await get_tree().process_frame
	var rid := get_viewport().get_viewport_rid()
	var t0 := Time.get_ticks_usec()
	var gpu := 0.0
	for i in 60:
		await get_tree().process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	return "%.1f fps  gpu %.1f ms  draws %d  objects %d" % [60.0 / ((Time.get_ticks_usec() - t0) / 1e6), gpu / 60.0,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var style: String = args[1] if args.size() > 1 else "anime"
	var m: Node = load("res://src/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().process_frame
	await m._new_scene(style)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var cam: CameraRig = m.studio.camera
	cam.mode = "third"
	cam.yaw = PI + 0.4
	cam.pitch = 0.18
	cam.dist = 5.0
	print("%s (%s quality, %s): %s" % [style, App.device["quality"], RenderingServer.get_video_adapter_name(), await _measure()])
	get_tree().quit()
