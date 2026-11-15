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
		var views := [["add", null], ["addChar", null], ["cast", null], ["actor", a.id], ["feelings", a.id], ["pose", a.id], ["actor", a.id], ["effects", null], ["script", null], ["mood", null], ["film", null], ["shot", 0], ["settings", null], ["imports", null], ["sound", null], ["sounds", null], ["anims", a.id]]
		if m.studio.world.is_voxel:
			views += [["blocks", null], ["maker", null], ["prefabs", null]]
		elif m.studio.is_flat():
			views += [["tiles", null], ["pprefabs", null]]
		else:
			views += [["objects", null]]
		# A trigger in the making (the editor needs one), and one saved, so the
		# Story page lists it.
		hud.sheets.new_trig = {"when": "touch", "_touch": "actor", "target": a.name, "who": "", "actor": "@target", "action": "wave", "text": "", "dur": 3.0}
		m.studio.triggers.load_data([{"when": "enter", "who": "@player", "x": 40.0, "z": 40.0, "r": 3.0, "actor": a.name, "action": "say", "text": "Hi"}])
		views += [["trigger", -1], ["trigger", 0]]
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
		for t in ["blocks", "prefab", "objects", "terrain", "move_actor", "tiles", "pprefab", "effects", "pick_spot"]:
			m.studio.tools.set_tool(t)
			await get_tree().process_frame
		m.studio.tools.set_tool("")
		# The timeline with a sound clip picked, and its edit sheet.
		m.studio.audio = [{"src": "tune:meadow", "start": 0.0, "dur": 4.0, "vol": 1.0}]
		hud.toggle_timeline()
		hud.timeline_panel.select_clip(m.studio.audio[0])
		hud.open_sheet("clip")
		await get_tree().process_frame
		hud.toggle_timeline()
		m.studio.audio = []
		# Previewing a shot, then leaving the preview.
		var mode0: String = m.studio.camera.mode
		hud.start_shot_preview(0)
		await get_tree().process_frame
		if not hud.previewing() or m.studio.camera.mode != "cine":
			push_error("shot preview didn't start")
		hud.stop_shot_preview(true)
		await get_tree().process_frame
		if hud.previewing() or m.studio.camera.mode != mode0 or hud.view_stack.is_empty() or hud.view_stack[-1][0] != "shot":
			push_error("shot preview didn't end back on the shot (%s)" % m.studio.camera.mode)
		hud.close_sheet()
		hud.toggle_record()
		await get_tree().create_timer(0.1).timeout
		hud.close_sheet()
		await m._go_home()
	print("UI OK: rendered %d panels" % n)
	get_tree().quit(0)
