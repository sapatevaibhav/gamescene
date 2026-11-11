extends Node
## Drives the editing tools through screen taps, like a user would.

var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		push_error("FAIL: " + what)
	else:
		print("ok   ", what)


func _ready() -> void:
	var studio := Studio.new()
	add_child(studio)
	await get_tree().process_frame
	var vs := get_viewport().get_visible_rect().size
	var center := vs / 2
	# Blocky: look straight down at the ground from the free camera.
	await studio.new_scene("blocky")
	studio.in_studio = true
	var cam := studio.camera
	cam.mode = "free"
	cam.free_pos = Vector3(10.5, 20, 10.5)
	cam.yaw = 0.0
	cam.pitch = PI / 2 - 0.0005  # straight down, so hills never catch the ray
	cam.update_camera(0.016)
	var w: VoxelWorld = studio.world
	var gy := w.ground_y(10.5, 10.5)
	studio.tools.set_tool("blocks", {"block": Blocks.ID["stone"], "mode": "place"})
	studio.tools.tap(center)
	ok(w.get_b(10, gy, 10) == Blocks.ID["stone"], "place block on ground")
	studio.tools.mode = "break"
	studio.tools.tap(center)
	ok(w.get_b(10, gy, 10) == 0, "break block")
	studio.undo()
	ok(w.get_b(10, gy, 10) == Blocks.ID["stone"], "undo restores block")
	studio.redo()
	ok(w.get_b(10, gy, 10) == 0, "redo removes it again")
	studio.tools.set_tool("prefab", {"prefab": "cottage"})
	var before: String = w.serialize()["rle"]
	studio.tools.tap(center)
	ok(w.serialize()["rle"] != before, "stamp prefab")
	# Terrain styles: place a prop, select it, rotate/resize/delete, sculpt.
	for style in ["anime", "lowpoly"]:
		await studio.new_scene(style)
		studio.in_studio = true
		cam = studio.camera
		cam.mode = "free"
		cam.free_pos = Vector3(8.5, 25, 40.5)
		cam.yaw = 0.0
		cam.pitch = 1.5
		cam.update_camera(0.016)
		var tw: TerrainWorld = studio.world
		# The world is random: clear a wide spot (big tree canopies reach in
		# and catch the tap) and start with nothing selected.
		for p in tw.props.duplicate():
			if Vector2(p.x - 8.5, p.z - 40.5).length() < 10:
				tw.remove_prop(p)
		studio.tools.sel = {}
		# The world is random: keep the cast off the spot so nothing blocks it.
		for x in studio.actors:
			if Vector2(x.pos.x - 8.5, x.pos.z - 40.5).length() < 4:
				x.pos = Vector3(30, tw.ground_at(30, 30), 30)
		var n := tw.props.size()
		var key: String = Props.defs(style).keys()[0]
		studio.tools.set_tool("objects", {"prop": key})
		studio.tools.tap(center)
		ok(tw.props.size() == n + 1, "%s place %s" % [style, key])
		studio.tools.tap(center)
		ok(not studio.tools.sel.is_empty(), "%s select prop" % style)
		var rot: float = studio.tools.sel["rot"]
		studio.tools.rotate_sel()
		studio.tools.resize_sel()
		ok(studio.tools.sel["rot"] != rot, "%s rotate prop" % style)
		studio.tools.delete_sel()
		ok(tw.props.size() == n, "%s delete prop" % style)
		var h0 := tw.terrain_h(8.5, 40.5)
		studio.tools.set_tool("terrain", {"terra": "raise"})
		studio.tools.begin_paint(center)
		for i in 20:
			studio.tools._process(0.05)
		studio.tools.end_paint()
		ok(tw.terrain_h(8.5, 40.5) > h0 + 0.5, "%s raise ground (%.2f -> %.2f)" % [style, h0, tw.terrain_h(8.5, 40.5)])
		var a := studio.actors[1]
		studio.tools.set_tool("move_actor", {"actor_id": a.id})
		studio.tools.tap(center)
		ok(Vector2(a.pos.x - 8.5, a.pos.z - 40.5).length() < 2.5, "%s move actor by tap" % style)
		cam.free_pos = Vector3(a.pos.x, a.pos.y + 1.0, a.pos.z + 4)
		cam.pitch = 0.1
		cam.update_camera(0.016)
		studio.tools.set_tool("")
		var hit := studio.tools.tap(center)
		ok(hit == a.id, "%s tap selects actor" % style)
	print("FAILS: ", fails)
	get_tree().quit(1 if fails else 0)
