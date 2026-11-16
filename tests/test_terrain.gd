extends Node

func _ready() -> void:
	var fails := 0
	for style in ["anime", "lowpoly"]:
		Kit.shade = Styles.get_style(style).shade
		for key in Props.defs(style):
			for seed in [1, 42, 99999]:
				var n := Props.build(style, key, seed)
				if n == null:
					print("FAIL build ", style, " ", key); fails += 1
				else:
					var bb := Kit.bounds(n)
					if bb.size.length() < 0.05:
						print("FAIL tiny bounds ", style, " ", key, bb); fails += 1
					n.free()
		var w := TerrainWorld.new()
		add_child(w)
		w.new_world(style)
		print(style, ": props=", w.props.size(), " grass=", w._grass_mmi.multimesh.visible_instance_count if w._grass_mmi.multimesh else 0)
		if w.props.size() < 20:
			print("FAIL few props"); fails += 1
		var c := TerrainWorld.TN / 2.0
		var h0 := w.terrain_h(c + 1, c + 1)
		w.brush(c + 1, c + 1, "raise", 0.5)
		if w.terrain_h(c + 1, c + 1) <= h0:
			print("FAIL brush raise"); fails += 1
		w.brush(c + 1, c + 1, "smooth", 0.5)
		w.rebuild()
		var hit := w.pick(Vector3(c, 30, c + 0.3), Vector3(0, -1, 0.001), 100)
		print(" pick down center: ", hit.get("point"), " prop=", hit.get("prop", {}).get("key") if hit.get("prop") != null else "none")
		if hit.is_empty():
			print("FAIL pick"); fails += 1
		var miss := w.pick(Vector3(c, 30, c), Vector3(0, 1, 0), 100)
		if not miss.is_empty():
			print("FAIL pick up should miss"); fails += 1
		var p0: Dictionary = w.props[0]
		var hp := w.pick(Vector3(p0.x, 40, p0.z), Vector3(0, -1, 0), 100)
		if hp.get("prop") == null:
			print("FAIL prop pick ", p0.key); fails += 1
		print(" blocked at prop: ", w.body_blocked(Vector3(p0.x, w.terrain_h(p0.x, p0.z), p0.z)), " clip:", w.clip_cam(Vector3(c, 5, c), Vector3(1, -1, 0).normalized(), 10))
		var d := w.serialize()
		var js := JSON.stringify(d)
		var w2 := TerrainWorld.new()
		add_child(w2)
		w2.load_data(JSON.parse_string(js), style)
		if w2.props.size() != w.props.size() or absf(w2.terrain_h(10.3, 20.7) - w.terrain_h(10.3, 20.7)) > 0.02:
			print("FAIL roundtrip"); fails += 1
		if JSON.stringify(w2.serialize()) != js:
			print("FAIL roundtrip stable"); fails += 1
		w.animate(0.016, 1.0)
		w.queue_free()
		w2.queue_free()
	print("DONE fails=", fails)
	await SoundDirector.hush(get_tree())
	get_tree().quit(fails)
