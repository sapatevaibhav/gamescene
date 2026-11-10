extends Node
## Sleeping: eyes close (eye pieces squash, blocky eyelids show, imported
## models' blink shapes) and "z Z z" drifts up over the sleeper; awake
## characters blink now and then.

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
	for style in Styles.STYLE_ORDER:
		await studio.new_scene(style)
		_style(studio, style)
	await _imported(studio)
	print("FAILS: ", fails)
	get_tree().quit(1 if fails > 0 else 0)


func _closed(a: Actor) -> bool:
	for e in a._eyes:
		if (e[0] as Node3D).scale.y < (e[1] as Vector3).y * 0.5:
			return true
	for l in a._lids:
		if (l as Node3D).visible:
			return true
	for b in a.rig.get("blink", []):
		if (b[0] as MeshInstance3D).get_blend_shape_value(int(b[1])) > 0.5:
			return true
	return false


func _style(studio: Studio, style: String) -> void:
	var a: Actor = null
	for x in studio.actors:
		if x != studio.player and not x.rig.get("creature", false) and x.rig.get("kind", "") != "quad":
			a = x
			break
	var flat := style in ["pixel", "pixeltop"]
	if not flat:
		ok(not a._eyes.is_empty() or not a._lids.is_empty(), "%s: %s has eyes that can close" % [style, a.name])
	a.set_behavior("sleep")
	a.t = 1.0
	a.animate(0.05, false)
	if not flat:
		ok(_closed(a), "%s: eyes close while sleeping" % style)
	ok(a._zzz != null and a._zzz.get_child_count() == 3, "%s: z's float over the sleeper" % style)
	var l0: Label3D = a._zzz.get_child(0)
	var y0 := l0.position.y if style != "pixeltop" else -l0.position.z
	a.animate(0.5, false)
	var y1 := l0.position.y if style != "pixeltop" else -l0.position.z
	ok(y1 != y0, "%s: and drift" % style)
	if not flat:
		for i in 3:
			a.animate(0.05, false)
		var hp := a.head_point()
		ok(hp.y < a.pos.y + a.height() * 0.5, "%s: lies down (head %.2f m up)" % [style, hp.y - a.pos.y])
		ok(a.tag == null or a.tag.global_position.distance_to(hp) < 0.6 * a.k(), "%s: name tag sits over the lying head" % style)
		ok(l0.global_position.distance_to(hp) < 1.2 * a.k(), "%s: z's rise from the head" % style)
	a.set_behavior("idle")
	a.t = 2.0
	a.animate(0.05, false)
	ok(a._zzz == null and (flat or not _closed(a)), "%s: awake again: eyes open, no z's" % style)
	if not flat:
		# Blinks: closed for a moment every few seconds.
		var blinked := false
		for i in 300:
			a.animate(1.0 / 30.0, false)
			blinked = blinked or _closed(a)
		ok(blinked, "%s: blinks now and then" % style)


func _imported(studio: Studio) -> void:
	var src := "user://assets/models/"
	var ids := Array(DirAccess.get_files_at(src)).filter(func(f): return f.get_extension() in ["glb", "vrm"])
	if ids.is_empty():
		print("skip imported-model checks: no models in the library")
		return
	DirAccess.make_dir_recursive_absolute(ModelRig.DIR)
	await studio.new_scene("anime")
	for id in ids:
		DirAccess.copy_absolute(src + id, ModelRig.DIR + id)
		var a := studio.add_actor({"name": "M", "look": {"model": id}, "x": 40.0, "z": 40.0})
		var nm := ModelRig.display_name(id)
		var shapes: Array = a.rig.get("blink", [])
		print("     %s: %d eye-closing face shapes" % [id, shapes.size()])
		# Facing any way, they lie on their back (and keep sleeping while
		# a line is still being spoken).
		a.yaw = 1.2
		a.set_behavior("sleep")
		a.speak_t = 3.0
		for i in 3:
			a.animate(0.05, false)
		var fwd := a.root().global_basis.orthonormalized() * Vector3.BACK
		ok(fwd.y > 0.9, "%s: sleeps face up (front %s)" % [nm, fwd.snappedf(0.01)])
		var hp := a.head_point()
		ok(hp.y < a.pos.y + a.height() * 0.4, "%s: lies down" % nm)
		ok(a.tag == null or a.tag.global_position.distance_to(hp) < 0.6, "%s: name tag over the head" % nm)
		ok(a._zzz and (a._zzz.get_child(0) as Node3D).global_position.distance_to(hp) < 1.2, "%s: z's rise from the head" % nm)
		if not shapes.is_empty():
			ok(_closed(a), "%s: closes its eyes with its face shapes while sleeping" % nm)
		a.set_behavior("idle")
		a.speak_t = 0.0
		a.t = 2.0
		a.animate(0.05, false)
		if not shapes.is_empty():
			ok(not _closed(a), "%s: opens them again" % nm)
		studio.remove_actor(a)
