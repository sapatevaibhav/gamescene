class_name ProjectStore
## Project storage: one JSON file per scene plus a PNG thumbnail in
## user://projects, an index for the home screen, versioned schema with
## migrations, atomic writes, and import/export of portable .json files
## (including scenes exported from the old web build).

const DIR := "user://projects/"
const INDEX := DIR + "index.json"


static func _ensure() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


static func index() -> Array:
	_ensure()
	if not FileAccess.file_exists(INDEX):
		return []
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
	return d if d is Array else []


static func _save_index(i: Array) -> void:
	_write_atomic(INDEX, JSON.stringify(i))


static func _write_atomic(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	return DirAccess.rename_absolute(tmp, path) == OK


static func new_id() -> String:
	return "p" + String.num_int64(int(Time.get_unix_time_from_system() * 1000.0), 36) + str(randi() % 1000)


static func save(id: String, data: Dictionary, thumb: Image = null) -> bool:
	_ensure()
	data["app"] = "gamescene"
	data["v"] = App.SCHEMA_VERSION
	var ok := _write_atomic(DIR + id + ".json", JSON.stringify(data))
	if thumb:
		thumb.save_png(DIR + id + ".png")
	var idx := index()
	var rest: Array = idx.filter(func(p): return p.get("id") != id)
	rest.push_front({"id": id, "name": data.get("name", "Scene"), "style": data.get("style", "blocky"), "updated": Time.get_unix_time_from_system()})
	_save_index(rest.slice(0, 64))
	return ok


static func load_project(id: String) -> Dictionary:
	var path := DIR + id + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return migrate(d) if d is Dictionary else {}


static func thumb(id: String) -> Texture2D:
	var path := DIR + id + ".png"
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	return ImageTexture.create_from_image(img) if img else null


static func delete(id: String) -> void:
	for ext in [".json", ".png"]:
		if FileAccess.file_exists(DIR + id + ext):
			DirAccess.remove_absolute(DIR + id + ext)
	_save_index(index().filter(func(p): return p.get("id") != id))


static func rename(id: String, name: String) -> void:
	var d := load_project(id)
	if d.is_empty():
		return
	d["name"] = name
	save(id, d)


static func duplicate_project(id: String) -> String:
	var d := load_project(id)
	if d.is_empty():
		return ""
	var nid := new_id()
	d["name"] = str(d.get("name", "Scene")) + " copy"
	save(nid, d)
	if FileAccess.file_exists(DIR + id + ".png"):
		DirAccess.copy_absolute(DIR + id + ".png", DIR + nid + ".png")
	return nid


## Writes a portable project file. Imported models are embedded as base64 so
## the file opens on another device without the asset store.
static func export_to(id: String, path: String) -> bool:
	var d := load_project(id)
	if d.is_empty():
		return false
	var models := {}
	for c in d.get("cast", []):
		var m: String = (c.get("look", {}) as Dictionary).get("model", "")
		if m != "" and FileAccess.file_exists(ModelRig.DIR + m):
			models[m] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(ModelRig.DIR + m))
	var props := {}
	for e in (d.get("world", {}) as Dictionary).get("props", []):
		if e is Array and AssetLib.is_key(str(e[0])):
			var pid := AssetLib.id_of(str(e[0]))
			if FileAccess.file_exists(AssetLib.DIR + pid):
				props[pid] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(AssetLib.DIR + pid))
	if not models.is_empty() or not props.is_empty():
		d["assets"] = {"models": models, "props": props}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d))
	return true


## Imports a project file; returns the new id or an error string prefixed "!".
static func import_from(path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	var d: Variant = JSON.parse_string(text)
	if not d is Dictionary:
		return "!That file isn’t a GameScene project."
	d = migrate(d)
	if d.is_empty() or not Styles.STYLES.has(d.get("style", "")) or not d.has("world"):
		return "!That file isn’t a GameScene project."
	var assets: Dictionary = d.get("assets", {})
	for m in (assets.get("models", {}) as Dictionary):
		DirAccess.make_dir_recursive_absolute(ModelRig.DIR)
		var f := FileAccess.open(ModelRig.DIR + m, FileAccess.WRITE)
		if f:
			f.store_buffer(Marshalls.base64_to_raw(assets["models"][m]))
	for pid in (assets.get("props", {}) as Dictionary):
		DirAccess.make_dir_recursive_absolute(AssetLib.DIR)
		var pf := FileAccess.open(AssetLib.DIR + pid, FileAccess.WRITE)
		if pf:
			pf.store_buffer(Marshalls.base64_to_raw(assets["props"][pid]))
	d.erase("assets")
	var id := new_id()
	if not d.has("name"):
		d["name"] = path.get_file().get_basename()
	save(id, d)
	return id


## Upgrades older saves (web v1 "blockset", web v2) to the current schema.
static func migrate(d: Dictionary) -> Dictionary:
	if d.get("app", "") == "blockset":
		d = {"style": "blocky", "world": {"rle": d.get("world", ""), "custom": d.get("custom", [])}, "cast": d.get("cast", []), "settings": d.get("settings", {}), "cine": d.get("cine", {}), "view": d.get("view", {}), "name": "Imported scene", "v": 1}
	var v: int = int(d.get("v", 1))
	if v < 3:
		# v3 adds shots, cues and the scene start snapshot; all optional.
		if not d.has("shots"):
			d["shots"] = []
		if not d.has("cues"):
			d["cues"] = []
		var st: Dictionary = d.get("settings", {})
		for k in ["quality", "showFps", "names", "autoJump", "mouseLook"]:
			st.erase(k)
		d["settings"] = st
		d["v"] = 3
	return d
