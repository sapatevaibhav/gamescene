extends Node
## Keeping the four world styles distinct, naming new scenes, and imported
## characters actually performing every action.
##   - Import rules per style (blocky: skins only; low-poly: triangle cap).
##   - Per-style asset tags.
##   - Scene names are unique.
##   - Built-in poses on imported rigs, measured from bone positions. Uses
##     copies of the models in the real library (read only), if there are any.

var fails := 0


func ok(cond: bool, what: String) -> void:
	if not cond:
		fails += 1
		push_error("FAIL: " + what)
	else:
		print("ok   ", what)


func _ready() -> void:
	_rules()
	_tags()
	_tris()
	_names()
	var studio := Studio.new()
	add_child(studio)
	await get_tree().process_frame
	await studio.new_scene("anime")
	studio.in_studio = false  # we drive animation by hand
	_poses(studio)
	print("FAILS: ", fails)
	get_tree().quit(1 if fails > 0 else 0)


func _rules() -> void:
	ok(not AssetTags.can_import_models("blocky") and not AssetTags.can_import_objects("blocky") and AssetTags.rules("blocky")["skins"], "blocky takes skins only")
	ok((AssetTags.rules("anime")["formats"] as Array).has("vrm"), "anime takes VRM")
	ok(not (AssetTags.rules("lowpoly")["formats"] as Array).has("vrm"), "VRM only in anime")
	ok(not AssetTags.can_import_models("pixel") and AssetTags.can_import_sprites("pixel") and AssetTags.can_import_sprites("pixeltop"), "2D views take sprites, not 3D models")
	ok(AssetTags.max_tris("lowpoly", "models") > 0 and AssetTags.max_tris("anime", "models") == 0, "triangle cap only in low-poly")
	ok(AssetTags.model_filters("blocky").is_empty() and AssetTags.model_filters("anime")[0].contains("*.vrm"), "file filters follow the style")
	ok(AssetTags.formats_text("lowpoly") == ".glb, .gltf or .fbx", "formats text (%s)" % AssetTags.formats_text("lowpoly"))


func _tags() -> void:
	ok(AssetTags.styles_of("models", "old~1.glb") == ["anime"], "untagged imports count as anime")
	AssetTags.tag("models", "a~1.glb", "lowpoly")
	AssetTags.tag("models", "a~1.glb", "blocky")
	ok(AssetTags.only("models", ["a~1.glb", "old~1.glb"], "lowpoly") == ["a~1.glb"], "only this style's models are listed")
	ok(AssetTags.only("models", ["a~1.glb", "old~1.glb"], "anime") == ["old~1.glb"], "other styles don't see it")
	ok(not AssetTags.untag("models", "a~1.glb", "lowpoly"), "removing from one style keeps it for the other")
	ok(AssetTags.untag("models", "a~1.glb", "blocky"), "removing from the last style frees the file")
	AssetTags.reload()
	ok(not AssetTags.only("models", ["a~1.glb"], "blocky").has("a~1.glb"), "tags persist across reloads")


## Writes a .glb with one sphere of the given detail; returns its path.
func _sphere_glb(name: String, radial: int, rings: int) -> String:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radial_segments = radial
	sm.rings = rings
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sm.get_mesh_arrays())
	mi.mesh = am
	root.add_child(mi)
	mi.owner = root
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_scene(root, st)
	DirAccess.make_dir_recursive_absolute("user://test_projects/")
	var path := "user://test_projects/%s.glb" % name
	doc.write_to_filesystem(st, path)
	root.free()
	return path


func _tris() -> void:
	var small := _sphere_glb("small", 16, 8)
	var big := _sphere_glb("big", 192, 96)
	var ns := AssetTags.count_tris(small)
	var nb := AssetTags.count_tris(big)
	ok(ns > 100 and ns < 1000, "counts triangles of a simple model (%d)" % ns)
	ok(nb > 15000, "counts triangles of a detailed model (%d)" % nb)
	ok(AssetTags.check_import("lowpoly", "models", small) == "", "low-poly accepts a simple model")
	ok(AssetTags.check_import("lowpoly", "models", big).begins_with("Too detailed"), "low-poly rejects a detailed model")
	ok(AssetTags.check_import("anime", "models", big) == "", "anime has no cap")


func _names() -> void:
	ProjectStore.save("t1", {"name": "Harbour", "style": "anime", "world": {}})
	ok(ProjectStore.unique_name("Harbour") == "Harbour 2", "taken names get a number")
	ok(ProjectStore.unique_name("harbour", "t1") == "harbour", "renaming a scene to its own name is fine")
	ok(ProjectStore.unique_name("  ") == "Untitled scene", "blank names get a default")
	ProjectStore.delete("t1")


# ---------------------------------------------------------------- poses

func _poses(studio: Studio) -> void:
	var src := "user://assets/models/"  # the real library: read only
	var ids := Array(DirAccess.get_files_at(src)).filter(func(f): return f.get_extension() in ["glb", "vrm"])
	if ids.is_empty():
		print("skip pose checks: no imported models in the library")
		return
	DirAccess.make_dir_recursive_absolute(ModelRig.DIR)
	for id in ids:
		DirAccess.copy_absolute(src + id, ModelRig.DIR + id)
		_pose_model(studio, id)


func _pose_model(studio: Studio, id: String) -> void:
	var tag := ModelRig.display_name(id)
	var a := studio.add_actor({"name": "Probe", "look": {"model": id}, "x": 40.0, "z": 40.0, "yaw": 0.0})
	if a == null or a.rig.get("skel") == null:
		ok(false, "%s builds with a skeleton" % tag)
		return
	a.notice = false
	var sk: Skeleton3D = a.rig["skel"]
	var bones: Dictionary = a.rig["bones"]
	for need in ["lowerArmL", "lowerArmR", "lowerLegL", "lowerLegR"]:
		ok(bones.has(need), "%s: found %s through the skeleton chain" % [tag, need])
	if not (bones.has("lowerArmR") and bones.has("lowerArmL")):
		studio.remove_actor(a)
		return
	var hand_r := ModelRig._main_child(sk, bones["lowerArmR"])
	var hand_l := ModelRig._main_child(sk, bones["lowerArmL"])
	var h := a.height()
	var w := func(b: int) -> Vector3: return sk.global_transform * sk.get_bone_global_pose(b).origin
	var run := func(beh: String, secs := 0.7, speak := false) -> Dictionary:
		a.set_behavior(beh)
		a.t = 0.0
		a.vel = Vector3.ZERO
		a.speak_t = 5.0 if speak else 0.0
		for i in int(secs * 30):
			a.animate(1.0 / 30.0, false)
		return {"hr": w.call(hand_r), "hl": w.call(hand_l), "head": w.call(bones["head"]), "hips": w.call(bones["hips"]),
			"sr": w.call(bones["upperArmR"]), "kneeL": w.call(bones["lowerLegL"]), "root": a.root().position, "rx": a.root().rotation.x}
	var idle: Dictionary = run.call("idle")
	var fwd := Vector3(0, 0, 1)  # yaw 0 faces +Z
	ok(idle["hr"].y < idle["sr"].y - 0.15 * h, "%s: idle arms hang down" % tag)
	var talk: Dictionary = run.call("talk", 0.5, true)
	ok((talk["hr"] - idle["hr"]).length() > 0.05 * h, "%s: talking gestures" % tag)
	var dance: Dictionary = run.call("dance", 1.0)
	ok(dance["hr"].y > dance["sr"].y and dance["hl"].y > dance["sr"].y, "%s: dance raises both arms" % tag)
	var wave: Dictionary = run.call("wave")
	ok(wave["hr"].y > wave["head"].y - 0.05 * h, "%s: wave lifts the right hand to head height" % tag)
	var sit: Dictionary = run.call("sit")
	ok(sit["hips"].y < idle["hips"].y - 0.15 * h, "%s: sitting lowers the hips (%.2f m)" % [tag, idle["hips"].y - sit["hips"].y])
	ok((sit["kneeL"] - sit["hips"]).dot(fwd) > 0.12 * h, "%s: sitting puts the knees in front" % tag)
	var cel: Dictionary = run.call("celebrate")
	ok(cel["hr"].y > cel["head"].y and cel["hl"].y > cel["head"].y, "%s: celebrate puts both hands above the head" % tag)
	var laugh: Dictionary = run.call("laugh")
	# Belly: the lower two thirds of the hips-to-neck span, whatever the proportions.
	var belly_top: float = laugh["hips"].y + 0.65 * (laugh["head"].y - laugh["hips"].y)
	ok(laugh["hr"].y > idle["hr"].y + 0.05 * h and laugh["hr"].y < belly_top, "%s: laughing holds the belly" % tag)
	var cry: Dictionary = run.call("cry")
	ok(cry["hr"].distance_to(cry["head"]) < 0.22 * h and cry["hl"].distance_to(cry["head"]) < 0.22 * h, "%s: crying brings the hands to the face (%.2f m)" % [tag, cry["hr"].distance_to(cry["head"])])
	var point: Dictionary = run.call("point")
	ok((point["hr"] - point["sr"]).dot(fwd) > 0.2 * h and absf(point["hr"].y - point["sr"].y) < 0.12 * h, "%s: pointing straight ahead" % tag)
	var fight: Dictionary = run.call("fight")
	ok(fight["hr"].y > idle["hr"].y + 0.15 * h and (fight["hr"] - fight["hips"]).dot(fwd) > 0.05 * h, "%s: fight guard is up in front" % tag)
	var sleep: Dictionary = run.call("sleep")
	ok(absf(sleep["rx"] + PI / 2) < 0.01 and sleep["head"].y - a.pos.y < 0.3 * h, "%s: sleeping lies down" % tag)
	studio.remove_actor(a)
