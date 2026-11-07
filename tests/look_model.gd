extends Node
## Renders an imported character walking and dancing (needs a window).
func _ready() -> void:
	var m: Node = load("res://src/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().process_frame
	await m._new_scene("anime")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	m.hud.set_clean(true)
	var ids := ModelRig.list_models()
	var want: String = OS.get_cmdline_user_args()[1] if OS.get_cmdline_user_args().size() > 1 else ""
	for i in ids.size():
		if want != "" and String(ids[i]).contains(want):
			ids = [ids[i]]
			break
	var st: Studio = m.studio
	var pl := st.player
	pl.set_look({"model": ids[0]})
	pl.pos = Vector3(40, st.world.ground_at(40, 40), 40)
	var npc := st.actors[1]
	npc.set_look({"model": ids[0]})
	npc.set_behavior("dance")
	npc.pos = pl.pos + Vector3(1.6, 0, 0)
	var cam := st.camera
	cam.mode = "third"; cam.yaw = PI * 0.5; cam.pitch = 0.1; cam.dist = 4.5
	cam.yaw = PI * 0.75
	st.input_move = Vector2(0.0, 0.5)
	for i in 14:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://look/model-walk.png")
	cam.yaw = PI * 0.5
	for i in 1:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://look/model-walk2.png")
	st.input_move = Vector2.ZERO
	cam.mode = "third"; cam.yaw = pl.yaw + PI; cam.pitch = 0.05; cam.dist = 2.6
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://look/model-front.png")
	m.hud.set_clean(false)
	m.hud.open_sheet("cast")
	for i in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("user://look/cast-grid.png")
	get_tree().quit()
