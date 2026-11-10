extends Node
## Keeping the four world styles distinct and naming new scenes.
##   - Import rules per style (blocky: skins only; low-poly: triangle cap).
##   - Per-style asset tags.
##   - Scene names are unique.

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
