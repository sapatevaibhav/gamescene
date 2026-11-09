extends Node
## Renders the Pixel 2D style for a visual check (needs a window):
##   godot --path . res://tests/runner.tscn -- look_pixel
## Renders both views. Writes user://look/pixel-*.png and prints each path.


func _shot(name: String) -> void:
	for i in 20:
		await get_tree().process_frame
	var path := "user://look/pixel-%s.png" % name
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", ProjectSettings.globalize_path(path))


func _ready() -> void:
	get_window().size = Vector2i(1600, 900)
	DirAccess.make_dir_recursive_absolute("user://look/")
	var m: Node = load("res://src/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	for i in 30:
		await get_tree().process_frame
	await m._new_scene("pixel")
	m.hud.set_clean(true)
	m.hud.restore_btn.visible = false
	var st: Studio = m.studio
	var cam := st.camera
	await _shot("follow")
	cam.set_mode("free")
	cam.dist = 11.0
	cam.free_pos = Vector3(40, 20, 0)
	await _shot("wide")
	st.atmo.apply_mood("sunset")
	await _shot("sunset")
	st.atmo.apply_mood("horror")
	await _shot("night")
	st.atmo.apply_mood("day")
	var acts := ["dance", "wave", "sit", "celebrate", "cry", "point", "fight", "sleep"]
	var x := 30.0
	for i in st.actors.size():
		var a: Actor = st.actors[i]
		a.pos = Vector3(x, st.world.ground_at(x), PixelWorld.LANE)
		a.notice = false
		if a != st.player:
			a.set_behavior(acts[i % acts.size()])
		x += 2.2
	st.player.say("Hello, pixel world!", 30.0)
	cam.dist = 4.5
	cam.free_pos = Vector3(37, 16, 0)
	await _shot("cast")
	# Top view.
	m.hud.set_clean(false)
	await m._new_scene("pixeltop", "Top look")
	m.hud.set_clean(true)
	m.hud.restore_btn.visible = false
	st = m.studio
	cam = st.camera
	await _shot("top-follow")
	cam.set_mode("free")
	cam.dist = 10.0
	cam.free_pos = Vector3(40, 0, 40)
	await _shot("top-wide")
	st.atmo.apply_mood("horror")
	await _shot("top-night")
	get_tree().quit()
