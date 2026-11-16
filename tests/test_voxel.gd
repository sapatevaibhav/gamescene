extends Node

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	Blocks.init()
	print("blocks: ", Blocks.BLOCKS.size() - 1, " builtin_count=", Blocks.BUILTIN_COUNT, " tiles=", Blocks.BUILTIN_TILES, " init_ms=", Time.get_ticks_msec() - t0)
	for c in Blocks.CATS:
		print("  ", c[0], ": ", Blocks.by_cat(c[0]).size())
	var ic := Blocks.icon(Blocks.ID["grass"])
	print("icon size ", ic.get_size())
	Blocks.atlas_image().save_png("user://test-atlas.png")
	var big := Image.create_empty(36 * 16, 36 * 14, false, Image.FORMAT_RGBA8)
	for i in range(1, mini(Blocks.BLOCKS.size(), 16 * 14 + 1)):
		var im := (Blocks.icon(i) as ImageTexture).get_image()
		big.blit_rect(im, Rect2i(0, 0, 36, 36), Vector2i(((i - 1) % 16) * 36, ((i - 1) / 16) * 36))
	big.save_png("user://test-icons.png")
	var w := VoxelWorld.new()
	add_child(w)
	for k in ["meadow", "desert", "snow", "plaza", "flat"]:
		t0 = Time.get_ticks_msec()
		w.generate(k, 42)
		w.rebuild()
		var n := 0
		for v in w.data:
			if v != 0: n += 1
		print(k, ": filled=", n, " ground(24,24)=", w.ground_y(24, 24), " ms=", Time.get_ticks_msec() - t0)
	w.generate("meadow", 7)
	w.stamp_prefab("cottage", 10, w.ground_y(10, 10), 10, 1)
	w.stamp_prefab("tower", 36, w.ground_y(36, 36), 36, 0)
	var cid := Blocks.add_custom({"name": "Mine", "pattern": "bricks", "top": "#c84040", "side": "#4040c8", "kind": "solid"})
	print("custom id ", cid)
	w.set_b(5, 20, 5, cid)
	w.rebuild()
	var d := w.serialize()
	var json := JSON.stringify(d)
	var before := w.data.duplicate()
	var w2 := VoxelWorld.new()
	add_child(w2)
	w2.load_data(JSON.parse_string(json))
	print("roundtrip equal: ", w2.data == before, " customs=", Blocks.BLOCKS.size() - Blocks.BUILTIN_COUNT, " rle_len=", str(d["rle"]).length())
	var hit := w.ray(Vector3(24.5, 20, 24.5), Vector3(0, -1, 0), 60)
	print("ray down: ", hit)
	hit = w.ray(Vector3(-5, 8, 24.5), Vector3(1, -0.1, 0).normalized(), 60)
	print("ray side: ", hit)
	print("box_hits at ground: ", w.box_hits(Vector3(24.5, w.ground_y(24.5, 24.5), 24.5)), " below: ", w.box_hits(Vector3(24.5, 1, 24.5)))
	print("clip_cam: ", w.clip_cam(Vector3(24.5, 20, 24.5), Vector3(0, -1, 0), 30))
	var legacy := {"rle": U.rle_encode(PackedByteArray([1, 2, 30])), "custom": []}
	print("legacy remap ok")
	w.animate(0.016, 1.0)
	print("lights: ", w._lights.size())
	await SoundDirector.hush(get_tree())
	get_tree().quit()
