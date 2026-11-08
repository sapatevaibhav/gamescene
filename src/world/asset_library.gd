class_name AssetLib
## Imported environment assets (trees, rocks, buildings, props) for the
## terrain styles. Files are converted to self-contained .glb in
## user://assets/props and placed in scenes as prop key "glb:<id>", so they
## save, undo, collide and export like built-in objects. In the anime style
## their materials are swapped for cel shading (texture kept), leaves get
## alpha cut-out and wind sway.

## Imported object files. Tests point this at a scratch folder.
static var DIR := "user://assets/props/"
const TOON_TEX := preload("res://src/shaders/toon_tex.gdshader")
const TOON_TEX_DS := preload("res://src/shaders/toon_tex_ds.gdshader")
const PREFIX := "glb:"
const FOLIAGE_WORDS := ["leaf", "leaves", "foliage", "bush", "grass", "fern", "plant", "flower", "canopy", "needle", "branch"]

static var _scenes := {}


static func is_key(key: String) -> bool:
	return key.begins_with(PREFIX)


static func id_of(key: String) -> String:
	return key.substr(PREFIX.length())


static func exists(key: String) -> bool:
	return is_key(key) and FileAccess.file_exists(DIR + id_of(key))


static func list() -> Array:
	var out := []
	var d := DirAccess.open(DIR)
	if d:
		for f in d.get_files():
			if f.get_extension() == "glb":
				out.append(f)
	out.sort()
	return out


static func display_name(key: String) -> String:
	return id_of(key).get_basename().get_slice("~", 0).capitalize()


const IMAGE_EXT := ["png", "jpg", "jpeg", "tga", "webp", "bmp"]


## FBX/glTF files often reference textures by paths that don't match where
## the images actually are (e.g. "source/x.png" while they ship in
## "textures/"), and Godot can't load loose images outside the project. This
## copies the model plus every image found near it (its folder, subfolders
## and the parent folder) into a temp folder, flat and under source/ and
## textures/, so the loader finds them. Returns the staged model path; call
## unstage() afterwards.
static func stage(path: String) -> String:
	var ext := path.get_extension().to_lower()
	if ext == "glb" or ext == "vrm":
		return path
	var tmp := ProjectSettings.globalize_path("user://import_tmp/%d/" % Time.get_ticks_usec())
	for sub in ["", "source/", "textures/", "Textures/", "texture/"]:
		DirAccess.make_dir_recursive_absolute(tmp + sub)
	var staged := tmp + path.get_file()
	if DirAccess.copy_absolute(path, staged) != OK:
		return path
	var base := path.get_base_dir()
	var images := {}
	_find_images(base, 3, images)
	_find_images(base.get_base_dir(), 2, images)
	for name in images:
		for sub in ["", "source/", "textures/", "Textures/", "texture/"]:
			DirAccess.copy_absolute(images[name], tmp + sub + name)
	# glTF: keep its .bin next to it.
	if ext == "gltf":
		for f in DirAccess.get_files_at(base):
			if f.get_extension().to_lower() == "bin":
				DirAccess.copy_absolute(base.path_join(f), tmp + f)
	return staged


const DIFFUSE_WORDS := ["diff", "diffuse", "color", "colour", "albedo", "basecolor", "base"]
const SKIP_WORDS := ["mat", "material", "tex", "texture", "png", "jpg", "jpeg", "tga", "webp", "map", "s", "01", "02", "001"]


## Game-ripped and DCC exports often leave materials without their texture
## links. Matches unlinked materials to images in `dir` by name
## ("..._Mat_Body" -> "..._Tex_Body_Diff.png"), turns off vertex-colour
## tinting (many rigs store outline data there) and treats diffuse alpha as a
## mask rather than transparency. Returns how many materials were fixed.
static func fix_materials(root: Node, dir: String) -> int:
	var images := {}
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() in IMAGE_EXT:
			var toks := _tokens(f.get_basename())
			var diffuse := false
			for t in toks:
				if DIFFUSE_WORDS.has(t):
					diffuse = true
			if diffuse:
				images[f] = toks
	if images.is_empty():
		return 0
	# Tokens shared by most images (character name, "tex"...) don't identify a part.
	var freq := {}
	for f in images:
		for t in images[f]:
			freq[t] = int(freq.get(t, 0)) + 1
	var fixed := 0
	var loaded := {}
	for n in _find_all(root, "MeshInstance3D"):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var m := mi.get_active_material(si) as BaseMaterial3D
			if m == null:
				continue
			var lname := m.resource_name.to_lower()
			# Whole-word check ("avatar" contains "vat"!).
			var mtok := _tokens(m.resource_name)
			var is_fx := mtok.has("glass") or mtok.has("eff") or mtok.has("vat") or mtok.has("vat1") or lname.begins_with("eff")
			var tex := m.albedo_texture
			var missing := tex == null or tex.get_width() == 0
			if missing and not is_fx:
				var mt := _tokens(m.resource_name)
				var best := ""
				var best_score := 0
				for f in images:
					var score := 0
					var unique := false
					for t in mt:
						if t in images[f]:
							# Part names unique to one image ("hair", "face") decide.
							if int(freq.get(t, 0)) == 1:
								score += 10
								unique = true
							else:
								score += 1
					if not unique:
						score = 0
					if score > best_score:
						best_score = score
						best = f
				if best == "" and (lname.contains("leather") or lname.contains("cloth")):
					for f in images:
						if "body" in images[f]:
							best = f
				if best != "":
					if not loaded.has(best):
						var img := Image.load_from_file(dir.path_join(best))
						loaded[best] = ImageTexture.create_from_image(img) if img else null
					if loaded[best]:
						m.albedo_texture = loaded[best]
						m.albedo_color = Color.WHITE
						fixed += 1
			if not is_fx:
				m.vertex_color_use_as_albedo = false
				m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	return fixed


static func _tokens(name: String) -> Array:
	var out := []
	for t in name.to_lower().replace("-", "_").replace(" ", "_").replace(".", "_").split("_", false):
		if not (t in SKIP_WORDS):
			out.append(t)
	return out


static func unstage(staged: String, original: String) -> void:
	if staged == original:
		return
	_rm_tree(staged.get_base_dir())


static func _find_images(dir: String, depth: int, out: Dictionary) -> void:
	if depth < 0 or dir == "" or not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		if f.get_extension().to_lower() in IMAGE_EXT and not out.has(f):
			out[f] = dir.path_join(f)
	for d in DirAccess.get_directories_at(dir):
		_find_images(dir.path_join(d), depth - 1, out)


static func _rm_tree(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_rm_tree(dir.path_join(d))
	DirAccess.remove_absolute(dir)


## Imports .glb / .gltf / .fbx; returns the new id ("" on failure).
static func import_file(path: String) -> String:
	var staged := stage(path)
	var id := _import_staged(staged, path)
	unstage(staged, path)
	return id


static func _import_staged(path: String, original: String) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var ext := path.get_extension().to_lower()
	var doc: GLTFDocument
	var state: GLTFState
	if ext == "fbx":
		doc = FBXDocument.new()
		state = FBXState.new()
	else:
		doc = GLTFDocument.new()
		state = GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return ""
	var bytes := FileAccess.get_file_as_bytes(original)
	var id := U.slug(original.get_file().get_basename()) + "~%06x.glb" % (hash(bytes.slice(0, mini(bytes.size(), 200000))) & 0xFFFFFF)
	var out := DIR + id
	if ext == "glb":
		DirAccess.copy_absolute(path, out)
	else:
		# Re-save as one self-contained .glb (embeds external textures).
		var scene := doc.generate_scene(state)
		fix_materials(scene, path.get_base_dir())
		var gdoc := GLTFDocument.new()
		var gstate := GLTFState.new()
		if gdoc.append_from_scene(scene, gstate) != OK or gdoc.write_to_filesystem(gstate, out) != OK:
			scene.free()
			return ""
		scene.free()
	_scenes.erase(id)
	return id if FileAccess.file_exists(out) else ""


static func remove(id: String) -> void:
	DirAccess.remove_absolute(DIR + id)
	_scenes.erase(id)


static func _load(id: String) -> PackedScene:
	if _scenes.has(id):
		return _scenes[id]
	if not FileAccess.file_exists(DIR + id):
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(DIR + id, state) != OK:
		return null
	var node := doc.generate_scene(state)
	if node == null:
		return null
	var ps := PackedScene.new()
	_own(node, node)
	ps.pack(node)
	node.free()
	_scenes[id] = ps
	return ps


static func _own(root: Node, n: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_own(root, c)


## Builds a placed instance: standing on y = 0, centred, cel-shaded in anime.
static func build(style: String, key: String) -> Node3D:
	var ps := _load(id_of(key)) if exists(key) else null
	if ps == null:
		# File removed from the library: keep a marker so the scene keeps it.
		var ph := Kit.group()
		Kit.shade = "standard"
		ph.add_child(Kit.box(0.8, 0.8, 0.8, Kit.mat("#9aa3ad", {"op": 0.6}), 0, 0.4, 0))
		return ph
	var inst := ps.instantiate() as Node3D
	var g := Kit.group()
	g.add_child(inst)
	var bb := Kit.bounds(g)
	# Some packs are authored in centimetres; bring absurd sizes into range.
	var hgt := maxf(bb.size.y, 0.001)
	if hgt > 60.0:
		inst.scale *= 6.0 / hgt
	bb = Kit.bounds(g)
	inst.position -= Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
	if style == "anime":
		_toonify(inst, bb.size.y)
	for a in _find_all(inst, "AnimationPlayer"):
		var ap := a as AnimationPlayer
		var clips := ap.get_animation_list()
		if not clips.is_empty():
			ap.get_animation(clips[0]).loop_mode = Animation.LOOP_LINEAR
			ap.play(clips[0])
	return g


static func _find_all(n: Node, cls: String) -> Array:
	var out := []
	if n.is_class(cls):
		out.append(n)
	for c in n.get_children():
		out.append_array(_find_all(c, cls))
	return out


static func _toonify(root: Node, height: float) -> void:
	for n in _find_all(root, "MeshInstance3D"):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src: Material = mi.get_active_material(s)
			var base := src as BaseMaterial3D
			var m := ShaderMaterial.new()
			m.shader = TOON_TEX
			var label := (mi.name + " " + (src.resource_name if src else "")).to_lower()
			var foliage := false
			for w in FOLIAGE_WORDS:
				if label.contains(w):
					foliage = true
			if base:
				m.set_shader_parameter("albedo", base.albedo_color)
				if base.albedo_texture:
					m.set_shader_parameter("albedo_tex", base.albedo_texture)
					m.set_shader_parameter("use_tex", true)
				var cut := base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
				if cut:
					m.set_shader_parameter("alpha_cut", maxf(base.alpha_scissor_threshold, 0.4))
					foliage = true
				# Skin-like warm colours shade warm, the rest cool.
				var c := base.albedo_color
				if c.r > c.b + 0.15 and c.r > 0.6:
					m.set_shader_parameter("shadow_tint", Color(0.92, 0.72, 0.74))
				elif c.g > c.r and c.g > c.b:
					m.set_shader_parameter("shadow_tint", Color(0.32, 0.5, 0.54))
			if foliage:
				m.shader = TOON_TEX_DS
				m.set_shader_parameter("wind", 0.05)
				m.set_shader_parameter("model_height", height)
				m.set_shader_parameter("shadow_tint", Color(0.32, 0.5, 0.54))
				m.render_priority = 0
			mi.set_surface_override_material(s, m)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
