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
	# New tiles, buildings and backdrop, and a swimmer.
	var pw: PixelWorld = st.world
	pw.set_backdrop("city")
	pw.stamp_prefab("castle", 62, pw.ground_y(62))
	pw.stamp_prefab("brickhouse", 52, pw.ground_y(52))
	var gy := pw.ground_y(46)
	for y in range(gy - 4, gy):
		for wx in range(44, 50):
			pw.fg[pw.idx(wx, y)] = PixelTiles.ID["water"]
	pw.rebuild()
	var sw: Actor = st.actors[1]
	sw.pos = Vector3(44.5, gy - 3, PixelWorld.LANE)
	sw.goto = {"x": 49.0, "z": PixelWorld.LANE}
	cam.dist = 7.0
	cam.free_pos = Vector3(55, 18, 0)
	st.atmo.apply_mood("sunset")
	await _shot("side-new")
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
	st.atmo.apply_mood("day")
	# Inside a house, and swimming in the pond.
	var tw: PixelTopWorld = st.world
	var hs: Array = tw.objects.filter(func(o): return o[0] == "house")[0]
	var ro := PixelTopWorld.room_origin(int(hs[3]))
	st.player.pos = Vector3(ro.x + 6.0, 0, ro.y + 5.0)
	cam.set_mode("third")
	cam.dist = 4.0
	cam.snap_to(st.player.pos)
	await _shot("top-inside")
	st.player.pos = Vector3(60.5, 0, 22.5)
	st.player.move_body(0.016)
	cam.snap_to(st.player.pos)
	await _shot("top-swim")
	# 3D: swimming in a pond dug with the ground tool.
	m.hud.set_clean(false)
	await m._new_scene("anime", "Swim look")
	m.hud.set_clean(true)
	m.hud.restore_btn.visible = false
	st = m.studio
	var aw: TerrainWorld = st.world
	for i in 600:
		if aw.terrain_h(46.5, 30.5) < aw.water - 2.2:
			break
		aw.brush(46.5, 30.5, "lower", 0.05)
	# Widen the pond so there's room to swim, then swim across it.
	for k in 400:
		aw.brush(46.5 + (k % 5) * 1.5, 30.5, "lower", 0.05)
	aw._rebuild_dirty()
	var sw3: Actor = st.actors[1]
	sw3.pos = Vector3(44.5, aw.terrain_h(44.5, 30.5), 30.5)
	sw3.goto = {"x": 53.0, "z": 30.5}
	st.camera.set_mode("free")
	st.camera.free_pos = Vector3(48.5, aw.water + 3.0, 36.0)
	st.camera.yaw = 0.25
	st.camera.pitch = 0.45
	for i in 50:
		await get_tree().process_frame
	await _shot("3d-swim")
	get_tree().quit()
