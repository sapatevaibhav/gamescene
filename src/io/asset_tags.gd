class_name AssetTags
## Which world styles each imported character model or 3D object belongs to,
## so the four styles keep their own libraries. Stored next to the assets in
## user://assets/styles.json as {"models": {id: [styles]}, "props": {...}}.
## Importing the same file in another style adds that style to it.
## Files imported before tagging existed count as anime (the style most
## imported characters were made for).

## Lives beside the asset folders (user://assets/styles.json). Derived from
## ModelRig.DIR so tests that move the library move this file too.
static func path() -> String:
	return ModelRig.DIR.trim_suffix("/").get_base_dir().path_join("styles.json")
const LEGACY_STYLE := "anime"

## What each style can import. Blocky worlds only take skins: their
## characters, mobs and buildings are made from blocks. Low-poly worlds cap
## the triangle count so detailed models don't break the look (0 = no cap).
const RULES := {
	"blocky": {"skins": true, "models": false, "objects": false, "formats": []},
	"anime": {"skins": false, "models": true, "objects": true, "formats": ["glb", "vrm", "gltf", "fbx"]},
	# Pixel 2D views take pixel sprites (characters and objects) only.
	"pixel": {"skins": false, "models": false, "objects": false, "sprites": true, "formats": []},
	"pixeltop": {"skins": false, "models": false, "objects": false, "sprites": true, "formats": []},
	"lowpoly": {"skins": false, "models": true, "objects": true, "formats": ["glb", "gltf", "fbx"], "max_tris_models": 15000, "max_tris_props": 20000},
}

static var _data: Dictionary = {}
static var _loaded := false


static func rules(style: String) -> Dictionary:
	return RULES.get(style, RULES["anime"])


static func can_import_models(style: String) -> bool:
	return rules(style)["models"]


static func can_import_objects(style: String) -> bool:
	return rules(style)["objects"]


static func can_import_sprites(style: String) -> bool:
	return rules(style).get("sprites", false)


const SPRITE_FILTERS := ["*.png, *.PNG, *.webp, *.WEBP, *.ase, *.ASE, *.aseprite, *.ASEPRITE ; Pixel sprites"]


## File-dialog filters for character models in this style.
static func model_filters(style: String) -> PackedStringArray:
	var exts: Array = rules(style)["formats"]
	if exts.is_empty():
		return PackedStringArray()
	var pats := PackedStringArray()
	for e in exts:
		pats.append("*." + e)
		pats.append("*." + e.to_upper())
	return PackedStringArray([", ".join(pats) + " ; 3D characters"])


## Human-readable list, e.g. ".glb, .vrm, .gltf or .fbx".
static func formats_text(style: String) -> String:
	var exts: Array = rules(style)["formats"]
	var parts := exts.map(func(e): return "." + e)
	if parts.size() <= 1:
		return "".join(parts)
	return ", ".join(parts.slice(0, parts.size() - 1)) + " or " + parts[-1]


## Triangle limit for imports of `kind` ("models" or "props") in `style`.
static func max_tris(style: String, kind: String) -> int:
	return int(rules(style).get("max_tris_" + kind, 0))


## Triangles in a .glb/.gltf file (all meshes, counted once each).
static func count_tris(path: String) -> int:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return -1
	var total := 0
	for gm in state.get_meshes():
		var im: ImporterMesh = (gm as GLTFMesh).mesh
		if im == null:
			continue
		for i in im.get_surface_count():
			if im.get_surface_primitive_type(i) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arr := im.get_surface_arrays(i)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
				total += (idx as PackedInt32Array).size() / 3
			else:
				total += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


## "" when the file fits the style, else a message explaining why not.
static func check_import(style: String, kind: String, path: String) -> String:
	var cap := max_tris(style, kind)
	if cap <= 0:
		return ""
	var n := count_tris(path)
	if n > cap:
		return "Too detailed for a low-poly world: %s triangles (the limit is %s). Use a simpler model, or import it into an anime world." % [_k(n), _k(cap)]
	return ""


static func _k(n: int) -> String:
	return "%.1fk" % (n / 1000.0) if n >= 1000 else str(n)


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_data = {"models": {}, "props": {}, "sprites": {}}
	if FileAccess.file_exists(path()):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path()))
		if d is Dictionary:
			for k in ["models", "props", "sprites"]:
				if d.get(k) is Dictionary:
					_data[k] = d[k]


static func _save() -> void:
	DirAccess.make_dir_recursive_absolute(path().get_base_dir())
	var f := FileAccess.open(path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_data))


static func styles_of(kind: String, id: String) -> Array:
	_load()
	var v: Variant = (_data[kind] as Dictionary).get(id, [LEGACY_STYLE])
	return v if v is Array else [str(v)]


static func tag(kind: String, id: String, style: String) -> void:
	_load()
	var st := styles_of(kind, id) if (_data[kind] as Dictionary).has(id) else []
	if not st.has(style):
		st.append(style)
	(_data[kind] as Dictionary)[id] = st
	_save()


## Takes `style` off an asset. Returns true when no style uses it any more
## (so the file itself can go).
static func untag(kind: String, id: String, style: String) -> bool:
	_load()
	var st := styles_of(kind, id).filter(func(x): return x != style)
	if st.is_empty():
		(_data[kind] as Dictionary).erase(id)
	else:
		(_data[kind] as Dictionary)[id] = st
	_save()
	return st.is_empty()


static func forget(kind: String, id: String) -> void:
	_load()
	(_data[kind] as Dictionary).erase(id)
	_save()


## Only the ids that belong to `style`.
static func only(kind: String, ids: Array, style: String) -> Array:
	return ids.filter(func(id): return styles_of(kind, id).has(style))


## Re-reads the file (tests and imports from other scenes).
static func reload() -> void:
	_loaded = false
	_load()
