extends Node
## Home screen: picking several scenes and deleting removes exactly those;
## the Recordings and Screenshots tabs list what's in the export folders,
## newest first.

var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		push_error("FAIL: " + what)
	else:
		print("ok   ", what)


func _ready() -> void:
	var ids := []
	for i in 3:
		var id := ProjectStore.new_id() + str(i)
		ProjectStore.save(id, {"name": "Bulk %d" % i, "style": "anime", "world": {}})
		ids.append(id)
	# Exports to list (the runner points the export folder at scratch).
	var dir := Recorder.output_dir()
	ok(dir.contains("test_projects"), "exports go to the test scratch folder")
	FileAccess.open(dir.path_join("take-a.mp4"), FileAccess.WRITE).store_string("not really a video")
	await get_tree().create_timer(1.1).timeout
	FileAccess.open(dir.path_join("take-b.avi"), FileAccess.WRITE).store_string("nor this")
	DirAccess.make_dir_recursive_absolute(dir.path_join("seq"))
	var img := Image.create(64, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color.ORANGE)
	img.save_png(dir.path_join("seq/frame_00001.png"))
	img.save_png(dir.path_join("still.png"))
	var m: Node = load("res://src/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(m)
	await get_tree().process_frame
	await get_tree().process_frame
	var home: Home = m.home
	await get_tree().process_frame
	home._set_selecting(true)
	await get_tree().process_frame
	home._tile_pressed(ids[0])
	home._tile_pressed(ids[1])
	home._delete_selected()
	await get_tree().process_frame
	var yes: Button = null
	for b in m.hud.modal.find_children("*", "Button", true, false):
		if (b as Button).text == "Delete":
			yes = b
	yes.pressed.emit()
	await get_tree().process_frame
	var left := ProjectStore.index().map(func(p): return p["id"])
	ok(not left.has(ids[0]) and not left.has(ids[1]) and left.has(ids[2]) and not home._selecting and not home._bar.visible, "deleting the selected scenes removes exactly those")
	ProjectStore.delete(ids[2])
	# Recordings and screenshots.
	var recs := Media.recordings()
	ok(recs.size() == 3 and recs.map(func(r): return r["kind"]).has("frames"), "recordings: videos and a PNG sequence (%s)" % [recs.map(func(r): return r["name"])])
	ok(int(recs[0]["time"]) >= int(recs[-1]["time"]), "newest first")
	var shots := Media.screenshots()
	ok(shots.size() == 1 and shots[0]["name"] == "still", "screenshots: the PNG, not the sequence's frames")
	home._tab = "recordings"
	home.refresh()
	await get_tree().process_frame
	ok(home._recent.get_child_count() == 3, "the Recordings tab shows them")
	home._tab = "screenshots"
	home.refresh()
	var done := [false]
	Media.thumb_async(shots[0], func(tex): done[0] = tex != null)
	var t0 := Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < 5000:
		await get_tree().process_frame
	ok(home._recent.get_child_count() == 1 and done[0], "the Screenshots tab shows them, with a thumbnail")
	print("FAILS: ", fails)
	await SoundDirector.hush(get_tree())
	get_tree().quit(1 if fails > 0 else 0)
