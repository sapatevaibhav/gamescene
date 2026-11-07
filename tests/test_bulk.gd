extends Node
## Multi-select on the home screen deletes exactly the chosen scenes.
func _ready() -> void:
	var ids := []
	for i in 3:
		var id := ProjectStore.new_id() + str(i)
		ProjectStore.save(id, {"name": "Bulk %d" % i, "style": "anime", "world": {}})
		ids.append(id)
	var m: Node = load("res://src/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().process_frame
	await get_tree().process_frame
	var home: Home = m.home
	home._set_selecting(true)
	home._tile_pressed(ids[0])
	home._tile_pressed(ids[1])
	home._delete_selected()
	await get_tree().process_frame
	# Press the dialog's confirm button.
	var yes: Button = null
	for b in m.hud.modal.find_children("*", "Button", true, false):
		if (b as Button).text == "Delete":
			yes = b
	yes.pressed.emit()
	var left := ProjectStore.index().map(func(p): return p["id"])
	var ok: bool = not left.has(ids[0]) and not left.has(ids[1]) and left.has(ids[2]) and not home._selecting
	ProjectStore.delete(ids[2])
	print("BULK DELETE ", "OK" if ok else "FAILED")
	get_tree().quit(0 if ok else 1)
