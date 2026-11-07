extends Node
## Opens every studio panel in every style; any script error fails the run.


func _ready() -> void:
	var m: Node = load("res://src/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().process_frame
	await get_tree().process_frame
	var n := 0
	for style in Styles.STYLE_ORDER:
		await m._new_scene(style)
		var hud: Hud = m.hud
		var a: Actor = m.studio.actors[1]
		var views := [["add", null], ["addChar", null], ["cast", null], ["actor", a.id], ["script", null], ["mood", null], ["film", null], ["shot", 0], ["settings", null]]
		if m.studio.world.is_voxel:
			views += [["blocks", null], ["maker", null], ["prefabs", null]]
		else:
			views += [["objects", null]]
		for v in views:
			hud.open_sheet(v[0], v[1])
			await get_tree().process_frame
			n += 1
		for mode in CameraRig.MODES:
			m.studio.camera.set_mode(mode)
			hud.open_sheet("camera")
			await get_tree().process_frame
			n += 1
		m.studio.camera.cine["shot"] = "path"
		m.studio.camera.set_mode("cine")
		hud.open_sheet("camera")
		await get_tree().process_frame
		for t in ["blocks", "prefab", "objects", "terrain", "move_actor"]:
			m.studio.tools.set_tool(t)
			await get_tree().process_frame
		m.studio.tools.set_tool("")
		hud.toggle_record()
		await get_tree().create_timer(0.1).timeout
		hud.close_sheet()
		await m._go_home()
	print("UI OK: rendered %d panels" % n)
	get_tree().quit(0)
