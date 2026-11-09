extends Node

const KEYS := ["root", "model", "upper", "head", "hc", "armL", "armR", "legL", "legR", "headH", "height", "sitDrop", "kind", "scale"]

func check(rig: Dictionary, label: String) -> int:
	var bad := 0
	if rig.get("kind", "") == "sprite":
		# Pixel 2D: one quad showing a frame of a painted sprite sheet.
		for k in ["root", "mesh", "mat", "height", "headH", "scale"]:
			if not rig.has(k):
				push_error("%s missing %s" % [label, k]); bad += 1
		var tex: Texture2D = (rig["mat"] as ShaderMaterial).get_shader_parameter("tex")
		if tex == null or tex.get_width() != PixelSprites.FRAME * PixelSprites.COLS:
			push_error("%s has no sprite sheet" % label); bad += 1
		(rig["root"] as Node).free()
		return bad
	for k in KEYS:
		if not rig.has(k):
			push_error("%s missing %s" % [label, k]); bad += 1
	for k in ["root", "model", "upper", "head", "armL", "armR", "legL", "legR"]:
		if not (rig.get(k) is Node3D):
			push_error("%s %s not Node3D" % [label, k]); bad += 1
	if rig.get("hc") != null and not (rig["hc"] is Node3D):
		push_error("%s hc bad" % label); bad += 1
	var n := _count(rig["root"])
	if n < 3:  # merged rigs (e.g. the blocky slime) can be just body + face parts
		push_error("%s too few meshes %d" % [label, n]); bad += 1
	(rig["root"] as Node).free()
	return bad

func _count(n: Node) -> int:
	var c := 1 if n is MeshInstance3D else 0
	for ch in n.get_children():
		c += _count(ch)
	return c

func _ready() -> void:
	var bad := 0
	var total := 0
	for style in ["blocky", "anime", "lowpoly", "pixel", "pixeltop"]:
		var P := Rigs.presets_for(style)
		for key in P:
			bad += check(Rigs.build({"preset": key}, style), style + "/" + key); total += 1
		for i in 4:
			bad += check(Rigs.build({"cfg": Rigs.random_cfg(style)}, style), style + "/random"); total += 1
		assert(Rigs.DEFAULT_CAST.has(style))
		for c in Rigs.DEFAULT_CAST[style]:
			assert(P.has(c[0]), "default cast preset missing " + c[0])
	var img := Skins.paint_skin(Skins.SKIN_PRESETS["sage"])
	var url := U.image_to_data_url(img)
	bad += check(Rigs.build({"png": url}, "blocky"), "png64"); total += 1
	var legacy := Image.create_empty(64, 32, false, Image.FORMAT_RGBA8)
	legacy.fill(Color(0.5, 0.3, 0.2))
	bad += check(Rigs.build({"png": U.image_to_data_url(legacy), "slim": true}, "blocky"), "png32"); total += 1
	bad += check(Rigs.build({"png": "garbage"}, "blocky"), "pngbad"); total += 1
	print("validate 40x40: ", Rigs.validate_skin(Image.create_empty(40, 40, false, Image.FORMAT_RGBA8)))
	print("validate ok: '", Rigs.validate_skin(img), "'")
	print("RIGS built=%d problems=%d" % [total, bad])
	get_tree().quit(1 if bad else 0)
