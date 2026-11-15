class_name Sheets
extends RefCounted
## Content of every sheet (panel) in the studio. `render()` fills the body
## and returns the title ("" means the view no longer applies).

var hud: Hud
var char_group := "people"
var block_cat := "nature"
var new_cue := {"actor": "", "action": "say", "start": 0.0, "dur": 3.0, "text": ""}
var maker := {"pattern": "speckled", "top": "#c8413b", "side": "#c8413b"}


func _init(h: Hud) -> void:
	hud = h


var studio: Studio:
	get:
		return hud.studio


func render(name: String, arg: Variant, b: VBoxContainer) -> String:
	if has_method("v_" + name):
		return call("v_" + name, arg, b)
	return ""


# ---------------------------------------------------------------- helpers

## The first line of a page: what this page is for, in plain words.
func _purpose(b: Control, text: String) -> void:
	var l := UIK.para(text, 14, UIK.GRAY_200)
	b.add_child(l)


## Which "More options" folds are open (by page), so they stay as you left them.
var _folds := {}


## A "More options" fold: rarely used settings, hidden until asked for.
## Returns the box to put them in (empty and hidden while folded).
func _fold(b: Control, key: String, title := "More options", icon := "") -> VBoxContainer:
	var open: bool = _folds.get(key, false)
	# Its own colour, so it reads as "there's more here", not as an action.
	var t := Button.new()
	t.focus_mode = Control.FOCUS_NONE
	t.custom_minimum_size.y = UIK.px(44)
	var sb := UIK.box(Color(UIK.SECONDARY_500, 0.16), 12, Color(UIK.SECONDARY_300, 0.55), 1)
	var sh := UIK.box(Color(UIK.SECONDARY_500, 0.28), 12, UIK.SECONDARY_300, 1)
	t.add_theme_stylebox_override("normal", sb)
	t.add_theme_stylebox_override("hover", sh)
	t.add_theme_stylebox_override("pressed", sh)
	t.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row := UIK.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for ic in ([icon] if icon != "" else []) + ["__text", "up" if open else "down"]:
		if ic == "__text":
			var l := UIK.label(title, 14, UIK.SECONDARY_100, true)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(l)
			continue
		var tr := TextureRect.new()
		tr.texture = Icons.tex(ic, UIK.px(18), UIK.SECONDARY_100)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(tr)
	t.add_child(row)
	t.pressed.connect(func():
		_folds[key] = not _folds.get(key, false)
		_rerender())
	b.add_child(UIK.spacer(4))
	b.add_child(t)
	var box := UIK.vbox(10)
	box.visible = open
	b.add_child(box)
	return box


func _section(b: Control, text: String) -> void:
	b.add_child(UIK.spacer(4))
	b.add_child(UIK.label(text, 13, UIK.MUTED, true))


func _tiles(b: Control, items: Array) -> void:
	var g := UIK.grid(2, 10)
	for it in items:
		g.add_child(UIK.tile(it[0], it[1], it[2], it.size() > 4 and it[4], it[3]))
	b.add_child(g)


func _picks(b: Control) -> GridContainer:
	var f := UIK.pick_grid(8)
	b.add_child(f)
	return f


func _look_icon(look: Dictionary) -> Texture2D:
	var style := studio.style_key
	if style in ["pixel", "pixeltop"] and not look.has("model"):
		return PixelSprites.icon(look)
	var key := "look|" + style + "|" + JSON.stringify(look).md5_text()
	return hud.icons.request(key, func(): return _build_look(look, style), "char")


func _build_look(look: Dictionary, style: String) -> Node3D:
	var r: Dictionary = ModelRig.build(look, style) if look.has("model") else Rigs.build(look, style)
	return r["root"]


func _face_icon(look: Dictionary) -> Texture2D:
	var style := studio.style_key
	if style in ["pixel", "pixeltop"] and not look.has("model"):
		return PixelSprites.icon(look)
	var key := "face|" + style + "|" + JSON.stringify(look).md5_text()
	return hud.icons.request(key, func(): return _build_look(look, style), "face")


func _prop_icon(key: String) -> Texture2D:
	var style := studio.style_key
	return hud.icons.request("prop|" + style + "|" + key, func(): return Props.build(style, key, 7), "prop")


func _rerender() -> void:
	hud.render_sheet()


# ---------------------------------------------------------------- add

func v_add(_a, b: VBoxContainer) -> String:
	_purpose(b, "Put things into your scene.")
	var items := [["person", "Character", "People, monsters, animals", func(): hud.push_view("addChar")]]
	if studio.world.is_voxel:
		items.append(["cube", "Blocks", "Place and break", func(): hud.push_view("blocks")])
		items.append(["house", "Buildings", "Houses, towers, trees", func(): hud.push_view("prefabs")])
	elif studio.is_side():
		items.append(["cube", "Tiles", "Paint ground, walls, ladders", func(): hud.push_view("tiles")])
		items.append(["house", "Buildings", "Cottages, towers, trees", func(): hud.push_view("pprefabs")])
	elif studio.is_top():
		items.append(["cube", "Ground", "Paint grass, paths, water", func(): hud.push_view("tiles")])
		items.append(["tree", "Objects", "Trees, houses, rocks", func(): hud.push_view("pprefabs")])
	else:
		items.append(["tree", "Objects", "Trees, houses, props", func(): hud.push_view("objects")])
		items.append(["hill", "Ground", "Raise hills, dig valleys, pour water", func(): studio.tools.set_tool("terrain"); hud.close_sheet()])
	items.append(["fire", "Effects", "Campfires, sparkles, smoke, dust", func(): hud.push_view("effects")])
	if AssetTags.can_import_sprites(studio.style_key):
		items.append(["upload", "Sprite", "Import .png or .ase", func(): _import_sprite("char")])
	elif AssetTags.can_import_models(studio.style_key):
		items.append(["upload", "3D character", "Import " + AssetTags.formats_text(studio.style_key), func(): _import_model()])
	else:
		items.append(["upload", "Skin", "Upload a 64×64 character PNG", func(): _upload_skin()])
	_tiles(b, items)
	b.add_child(UIK.para("Every building tool has the same bar: Add, Remove and Copy." + ("" if App.is_touch else " Press B to open it."), 12))
	_rights(b)
	return "Add"


func v_effects(_a, b: VBoxContainer) -> String:
	_purpose(b, "Fire, magic and air you can place anywhere. They move with the scene clock, so every take and video looks the same.")
	var f := _picks(b)
	for k in SceneFx.ORDER:
		var kd: Dictionary = SceneFx.KINDS[k]
		f.add_child(UIK.pick(Icons.tex(str(kd["icon"]), 48, UIK.TAPE), str(kd["name"]), studio.tools.kind == "effects" and studio.tools.effect == k, func():
			studio.tools.set_tool("effects", {"effect": k})
			hud.close_sheet(), false, 74))
	b.add_child(UIK.para("Campfires light up the night, keep characters from walking into them, and anyone set to Gather sits round the nearest one.", 12))
	if not studio.fx.items.is_empty():
		b.add_child(UIK.danger("Remove all effects (%d)" % studio.fx.items.size(), func():
			studio.checkpoint()
			studio.fx.clear()
			studio.mark_dirty()
			_rerender()))
	return "Effects"


func v_addChar(_a, b: VBoxContainer) -> String:
	var presets := Rigs.presets_for(studio.style_key)
	var groups := []
	for g in Rigs.GROUPS:
		for k in presets:
			if presets[k].get("group", "people") == g[0]:
				groups.append(g)
				break
	if groups.size() > 1:
		var chips := UIK.flow()
		for g in groups:
			chips.add_child(UIK.chip(g[1], char_group == g[0], func(): char_group = g[0]; _rerender()))
		b.add_child(chips)
	else:
		char_group = "people"
	var f := _picks(b)
	var vox: bool = studio.world.is_voxel
	for k in presets:
		var p: Dictionary = presets[k]
		if groups.size() > 1 and p.get("group", "people") != char_group:
			continue
		f.add_child(UIK.pick(_look_icon({"preset": k}), p.get("label", k), false, func(): _add_char({"preset": k}, p), vox and not p.has("creature")))
	if char_group == "people":
		f.add_child(UIK.pick(Icons.tex("shuffle", 48, UIK.TAPE), "Random", false, func(): _add_char({"cfg": Rigs.random_cfg(studio.style_key)}, {})))
		if vox:
			f.add_child(UIK.pick(Icons.tex("upload", 48, UIK.TAPE), "Upload skin", false, _upload_skin))
			b.add_child(UIK.para("Uploaded skins use the common 64×64 (or legacy 64×32) character layout.", 12))
	if AssetTags.can_import_sprites(studio.style_key):
		_section(b, "Your sprites")
		var sf := _picks(b)
		sf.add_child(UIK.pick(Icons.tex("upload", 48, UIK.TAPE), "Import", false, func(): _import_sprite("char")))
		for sid in _style_sprites("char"):
			sf.add_child(UIK.pick(SpriteImport.icon(sid), SpriteImport.display_name(sid), false, func(): _add_char({"sprite": sid}, {"label": SpriteImport.display_name(sid).left(18)}), true))
		b.add_child(UIK.para("Import .png sprite sheets (a strip of frames, or an RPG grid of 3–4 columns × 4 rows: down, left, right, up) or Aseprite .ase/.aseprite files. Aseprite tags name the actions: idle, walk, run, jump, dance, wave, sit, sleep, cheer, laugh, cry, point, attack, talk; add _down, _up, _left or _right for the top view.", 12))
	_models_section(b, func(id): _add_char({"model": id}, {"label": id.get_basename()}))
	return "Add a character"


func _models_section(b: VBoxContainer, on_pick: Callable) -> void:
	var style := studio.style_key
	if not AssetTags.can_import_models(style):
		return
	_section(b, "3D models")
	_rights(b)
	var f := _picks(b)
	f.add_child(UIK.pick(Icons.tex("upload", 48, UIK.TAPE), "Import", false, _import_model))
	var mine := _style_models()
	for id in mine:
		f.add_child(UIK.pick(_look_icon({"model": id}), ModelRig.display_name(id), false, func(): on_pick.call(id)))
	b.add_child(UIK.para("Humanoid %s files work best. Clips named idle, walk, run, dance, wave, sit, sleep, cheer, laugh, cry, point or attack play automatically; other actions use built-in poses. Models imported here stay in %s worlds.%s" % [AssetTags.formats_text(style), Styles.get_style(style)["name"], (" Low-poly models only: up to %s triangles." % AssetTags._k(AssetTags.max_tris(style, "models"))) if AssetTags.max_tris(style, "models") > 0 else ""], 12))
	if not mine.is_empty() or not _style_props().is_empty():
		b.add_child(UIK.btn("Manage imported models", func(): hud.push_view("imports"), false, "trash"))


## Imported characters and objects that belong to this world's style.
func _style_models() -> Array:
	return AssetTags.only("models", ModelRig.list_models(), studio.style_key)


func _style_props() -> Array:
	return AssetTags.only("props", AssetLib.list(), studio.style_key)


func _add_char(look: Dictionary, p: Dictionary) -> void:
	var group: String = p.get("group", "people")
	var name: String = p.get("label", "Someone") if group != "people" else U.pick(Rigs.NAMES)
	var s := studio.spawn_near()
	studio.checkpoint()
	var a := studio.add_actor({"name": name, "look": look, "behavior": p.get("beh", "idle"), "lines": (p.get("lines", []) as Array).duplicate(), "x": s.x, "z": s.y, "yaw": randf() * TAU})
	if a:
		studio.capture_start()
		studio.mark_dirty()
		studio.cast_changed.emit()
		hud.toast(a.name + " joined the scene.")


func _upload_skin() -> void:
	hud.pick_file(PackedStringArray(["*.png ; PNG skins"]), func(path: String):
		var img := Image.load_from_file(path)
		if img == null:
			hud.toast("That image couldn’t be read.")
			return
		var err := Rigs.validate_skin(img)
		if err != "":
			hud.toast(err)
			return
		_add_char({"png": U.image_to_data_url(img)}, {"label": path.get_file().get_basename().left(18), "group": "mobs"}), "Choose a skin")


func _import_model() -> void:
	var style := studio.style_key
	if not AssetTags.can_import_models(style):
		hud.toast("Blocky worlds use skins instead of 3D models.")
		return
	hud.pick_file(AssetTags.model_filters(style), func(path: String):
		var ext := path.get_extension().to_lower()
		if not (AssetTags.rules(style)["formats"] as Array).has(ext):
			hud.toast("%s worlds take %s characters." % [Styles.get_style(style)["name"], AssetTags.formats_text(style)])
			return
		hud.toast("Importing " + path.get_file() + "…")
		var before := ModelRig.list_models()
		var id := ModelRig.import_file(path)
		if id == "":
			hud.toast("That model couldn’t be loaded.")
			return
		var why := AssetTags.check_import(style, "models", ModelRig.DIR + id)
		if why != "":
			# Keep the file only if another style already had it.
			if not before.has(id):
				ModelRig.remove(id)
			hud.toast(why)
			return
		AssetTags.tag("models", id, style)
		_add_char({"model": id}, {"label": path.get_file().get_basename().left(18), "group": "mobs"})
		if hud.view_stack.size() > 0:
			_rerender(), "Import a 3D model")


# ---------------------------------------------------------------- imports

## Lists imported characters and objects with delete buttons, so files can be
## removed and imported again. Scenes using a deleted file show a placeholder.
## Shown wherever files come in: the app bundles only original or CC0 art,
## and what people import is theirs to answer for.
const RIGHTS := "Only import things you made or have the right to use. What you add, and what you make with it, is your responsibility."


func _rights(b: Control) -> void:
	b.add_child(UIK.para(RIGHTS, 11, UIK.MUTED))


func v_imports(_a, b: VBoxContainer) -> String:
	_rights(b)
	var style := studio.style_key
	var chars := _style_models()
	var objs := _style_props()
	var sprites: Array = _style_sprites("char") + _style_sprites("object") + _style_sprites("tileset") if AssetTags.can_import_sprites(style) else []
	if not sprites.is_empty():
		_section(b, "Pixel sprites")
		for sid in sprites:
			b.add_child(_import_row(SpriteImport.icon(sid), SpriteImport.display_name(sid), sid + ".png", 0, func():
				if AssetTags.untag("sprites", sid, style):
					SpriteImport.remove(sid)
				hud.toast("Removed " + SpriteImport.display_name(sid))
				_rerender()))
		if chars.is_empty() and objs.is_empty():
			return "Imported models"
	b.add_child(UIK.para("The library for %s worlds. Each world style keeps its own imports." % Styles.get_style(style)["name"], 12))
	if chars.is_empty() and objs.is_empty():
		b.add_child(UIK.para("Nothing imported yet.", 14))
		return "Imported models"
	if not chars.is_empty():
		_section(b, "Characters")
		for id in chars:
			var users := studio.actors.filter(func(x): return x.look.get("model", "") == id).size()
			b.add_child(_import_row(_look_icon({"model": id}), ModelRig.display_name(id), id, users, func():
				# Only delete the file when no other style still uses it.
				if AssetTags.untag("models", id, style):
					ModelRig.remove(id)
				hud.icons.clear()
				hud.toast("Removed " + ModelRig.display_name(id))
				_rerender()))
	if not objs.is_empty():
		_section(b, "Objects")
		for id in objs:
			var key: String = AssetLib.PREFIX + id
			var placed: int = 0 if studio.world.is_voxel else studio.world.props.filter(func(p): return p.key == key).size()
			b.add_child(_import_row(_prop_icon(key), AssetLib.display_name(key), id, placed, func():
				if AssetTags.untag("props", id, style):
					AssetLib.remove(id)
				hud.icons.clear()
				hud.toast("Removed " + AssetLib.display_name(key))
				_rerender()))
	b.add_child(UIK.para("Removing a model deletes its copy from the app's library, not your original file. Characters or objects in saved scenes that use it appear as grey placeholders until you import it again.", 12))
	return "Imported models"


func _import_row(tex: Texture2D, title: String, id: String, in_use: int, on_delete: Callable) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UIK.box(UIK.GRAY_700, 14, UIK.GRAY_600))
	var h := UIK.hbox(10)
	var thumb := TextureRect.new()
	thumb.texture = tex
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.custom_minimum_size = Vector2(UIK.px(44), UIK.px(44))
	h.add_child(thumb)
	var v := UIK.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := UIK.label(title, 15, UIK.INK, true)
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	t.custom_minimum_size.x = 1
	v.add_child(t)
	var sub := UIK.label(id.get_extension().to_upper() + ("  ·  used %d× in this scene" % in_use if in_use > 0 else ""), 12, UIK.PRIMARY_300 if in_use > 0 else UIK.MUTED)
	v.add_child(sub)
	h.add_child(v)
	var del := UIK.danger("Delete", func():
		var warn := ("\n\nIt's used %d× in this scene; those will show as grey placeholders until you import it again." % in_use) if in_use > 0 else ""
		hud.ask("Delete “%s” from the library?%s" % [title, warn], "Delete", on_delete))
	del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(del)
	row.add_child(h)
	return row


# ---------------------------------------------------------------- building

func v_blocks(_a, b: VBoxContainer) -> String:
	var chips := UIK.flow()
	for c in Blocks.CATS:
		if c[0] == "mine" and Blocks.by_cat("mine").is_empty():
			continue
		chips.add_child(UIK.chip(c[1], block_cat == c[0], func(): block_cat = c[0]; _rerender()))
	b.add_child(chips)
	var f := _picks(b)
	for id in Blocks.by_cat(block_cat):
		var bl := Blocks.get_block(id)
		f.add_child(UIK.pick(Blocks.icon(id), bl.get("name", "?"), studio.tools.kind == "blocks" and studio.tools.block == id, func():
			studio.tools.set_tool("blocks", {"block": id, "mode": "place"})
			hud.close_sheet(), true, 74))
	b.add_child(UIK.btn("Make your own block", func(): hud.push_view("maker"), false, "paint"))
	return "Blocks"


## Pixel 2D tile palette. Ground-type tiles stand in the way; the rest
## (walls, windows, ladders, flowers) sit behind the characters.
func v_tiles(_a, b: VBoxContainer) -> String:
	if studio.is_top():
		var tf := _picks(b)
		for id in range(1, PixelTopArt.GROUND.size()):
			if PixelTopArt.GROUND[id].get("system", false):
				continue
			tf.add_child(UIK.pick(PixelTopArt.ground_icon(id), PixelTopArt.GROUND[id]["name"], studio.tools.kind == "tiles" and studio.tools.tile == id, func():
				studio.tools.set_tool("tiles", {"tile": id, "mode": "place"})
				hud.close_sheet(), true))
		b.add_child(UIK.para("Tap or drag to paint the ground. Right-drag removes objects (or turns ground back to grass). Water is swum across.", 12))
		_tile_sets(b)
		return "Ground"
	for grp in [["In the way", false], ["Behind the characters", true]]:
		_section(b, grp[0])
		var f := _picks(b)
		for id in range(1, PixelTiles.count()):
			if PixelTiles.is_bg(id) != grp[1]:
				continue
			f.add_child(UIK.pick(PixelTiles.icon(id), PixelTiles.get_tile(id)["name"], studio.tools.kind == "tiles" and studio.tools.tile == id, func():
				studio.tools.set_tool("tiles", {"tile": id, "mode": "place"})
				hud.close_sheet(), true))
	b.add_child(UIK.para("Tap or drag to paint. Right-drag erases. Water is see-through and can be swum in; ladders can be climbed with W and S.", 12))
	_tile_sets(b)
	return "Tiles"


## Imported tile sets (Pixel 2D): import button, then every tile to paint.
var tiles_behind := false


func _tile_sets(b: VBoxContainer) -> void:
	_section(b, "Your tile sets")
	if studio.is_side():
		b.add_child(UIK.toggle("Put imported tiles behind the characters", tiles_behind, func(on: bool): tiles_behind = on))
	var f := _picks(b)
	f.add_child(UIK.pick(Icons.tex("upload", 48, UIK.TAPE), "Import", false, _import_tileset))
	var shown := 0
	for set_id in _style_sprites("tileset"):
		for i in TileSets.tiles_of(set_id):
			if shown >= 96:
				break
			shown += 1
			f.add_child(UIK.pick(TileSets.icon(set_id, int(i)), "", false, func():
				var id: int = studio.world.custom_id(set_id, int(i), tiles_behind)
				if id == 0:
					hud.toast("This scene already uses %d imported tiles (the most it can hold)." % TileSets.MAX_CUSTOM)
					return
				studio.tools.set_tool("tiles", {"tile": id, "mode": "place"})
				hud.close_sheet(), true, 56))
	b.add_child(UIK.para("Import a .png or .webp grid of 16, 32 or 8 px tiles; empty cells are skipped. Tile sets stay in %s worlds." % Styles.get_style(studio.style_key).get("view_name", "this kind of"), 12))


func _import_tileset() -> void:
	var style := studio.style_key
	hud.pick_file(PackedStringArray(["*.png, *.PNG, *.webp, *.WEBP ; Tile sets"]), func(path: String):
		var id := TileSets.import_file(path)
		if id == "":
			hud.toast(TileSets.last_error)
			return
		AssetTags.tag("sprites", id, style)
		hud.toast("%d tiles of %d px imported." % [TileSets.tiles_of(id).size(), int(SpriteImport.meta(id)["tile"])])
		_rerender(), "Import a tile set")


func v_pprefabs(_a, b: VBoxContainer) -> String:
	var f := _picks(b)
	if studio.is_top():
		for k in PixelTopArt.OBJ_ORDER:
			f.add_child(UIK.pick(PixelTopArt.obj_icon(k), PixelTopArt.OBJECTS[k]["name"], studio.tools.kind == "pprefab" and studio.tools.pprefab == k, func():
				studio.tools.set_tool("pprefab", {"pprefab": k})
				hud.close_sheet(), true))
	else:
		for k in PixelTiles.PREFABS:
			var p: Dictionary = PixelTiles.PREFABS[k]
			f.add_child(UIK.pick(PixelTiles.icon(PixelTiles.ID[p["icon"]]), p["name"], studio.tools.kind == "pprefab" and studio.tools.pprefab == k, func():
				studio.tools.set_tool("pprefab", {"pprefab": k})
				hud.close_sheet(), true))
	_section(b, "Your sprites")
	var mine := _picks(b)
	mine.add_child(UIK.pick(Icons.tex("upload", 48, UIK.TAPE), "Import", false, func(): _import_sprite("object")))
	for id in _style_sprites("object"):
		var key: String = SpriteImport.PREFIX + id
		mine.add_child(UIK.pick(SpriteImport.icon(id), SpriteImport.display_name(id), studio.tools.pprefab == key, func():
			studio.tools.set_tool("pprefab", {"pprefab": key})
			hud.close_sheet(), true))
	b.add_child(UIK.para("Import pixel objects from .png, .webp, .ase or .aseprite files. %s They stay in %s worlds." % ["They stand on the ground and block walking." if studio.is_top() else "They stand behind the characters.", Styles.get_style(studio.style_key).get("view_name", "")], 12))
	return "Objects" if studio.is_top() else "Buildings"


## Imported pixel sprites of a kind that belong to this world's view.
func _style_sprites(kind: String) -> Array:
	return AssetTags.only("sprites", SpriteImport.list(kind), studio.style_key)


func _import_sprite(kind: String) -> void:
	var style := studio.style_key
	hud.pick_file(PackedStringArray(AssetTags.SPRITE_FILTERS), func(path: String):
		var id := SpriteImport.import_file(path, kind)
		if id == "":
			hud.toast(SpriteImport.last_error)
			return
		AssetTags.tag("sprites", id, style)
		var m := SpriteImport.meta(id)
		if kind == "char":
			var acts := (m["anims"] as Dictionary).keys().map(func(k): return str(k).get_slice(":", 0))
			var uniq := []
			for x in acts:
				if not uniq.has(x):
					uniq.append(x)
			hud.toast("%d frames of %d×%d · actions: %s" % [int(m["frames"]), int(m["fw"]), int(m["fh"]), ", ".join(PackedStringArray(uniq))])
			_add_char({"sprite": id}, {"label": SpriteImport.display_name(id).left(18), "group": "people"})
		else:
			studio.tools.set_tool("pprefab", {"pprefab": SpriteImport.PREFIX + id})
			hud.toast("Tap where it should go.")
			hud.close_sheet()
		if hud.view_stack.size() > 0:
			_rerender(), "Import a pixel sprite")


func v_maker(_a, b: VBoxContainer) -> String:
	_section(b, "Pattern")
	var chips := UIK.flow()
	for p in [["speckled", "Speckled"], ["bricks", "Bricks"], ["planks", "Planks"], ["stripes", "Stripes"], ["tiles", "Tiles"], ["plain", "Plain"]]:
		chips.add_child(UIK.chip(p[1], maker["pattern"] == p[0], func(): maker["pattern"] = p[0]; _rerender()))
	b.add_child(chips)
	_section(b, "Colours")
	var row := UIK.hbox(12)
	for side in ["top", "side"]:
		var v := UIK.vbox(4)
		v.add_child(UIK.label(side.capitalize(), 13, UIK.MUTED))
		var cp := ColorPickerButton.new()
		cp.color = U.col(maker[side])
		cp.custom_minimum_size = Vector2(UIK.px(90), UIK.px(42))
		cp.edit_alpha = false
		cp.color_changed.connect(func(c: Color): maker[side] = "#" + c.to_html(false))
		v.add_child(cp)
		row.add_child(v)
	b.add_child(row)
	var acts := UIK.hbox()
	acts.add_child(UIK.btn("Create block", func():
		var id := Blocks.add_custom({"pattern": maker["pattern"], "top": maker["top"], "side": maker["side"], "name": "My block"})
		if id < 0:
			hud.toast("The block library is full.")
			return
		_after_custom(id), true))
	acts.add_child(UIK.btn("From image", func():
		hud.pick_file(PackedStringArray(["*.png, *.jpg, *.webp ; Images"]), func(path: String):
			var img := Image.load_from_file(path)
			if img == null:
				hud.toast("That image couldn’t be read.")
				return
			img.resize(16, 16, Image.INTERPOLATE_BILINEAR)
			var id := Blocks.add_custom({"mode": "image", "side": U.image_to_data_url(img), "name": path.get_file().get_basename().left(16)})
			if id < 0:
				hud.toast("The block library is full.")
				return
			_after_custom(id))))
	b.add_child(acts)
	b.add_child(UIK.para("Images are scaled to 16×16 pixels. Custom blocks are saved inside the scene.", 12))
	return "Make a block"


func _after_custom(id: int) -> void:
	studio.world.rebuild()
	studio.mark_dirty()
	block_cat = "mine"
	studio.tools.set_tool("blocks", {"block": id, "mode": "place"})
	hud.close_sheet()
	hud.toast("Block ready. Tap to place it.")


func v_prefabs(_a, b: VBoxContainer) -> String:
	var f := _picks(b)
	for k in VoxelWorld.PREFABS:
		var p: Dictionary = VoxelWorld.PREFABS[k]
		var icon_id: int = Blocks.ID.get(p.get("icon", "planks"), 1)
		f.add_child(UIK.pick(Blocks.icon(icon_id), p["name"], studio.tools.kind == "prefab" and studio.tools.prefab == k, func():
			studio.tools.set_tool("prefab", {"prefab": k})
			hud.close_sheet(), true))
	return "Buildings"


func v_objects(_a, b: VBoxContainer) -> String:
	var f := _picks(b)
	var defs := Props.defs(studio.style_key)
	for k in defs:
		f.add_child(UIK.pick(_prop_icon(k), defs[k]["name"], studio.tools.prop == k, func():
			studio.tools.set_tool("objects", {"prop": k})
			hud.close_sheet()))
	_section(b, "Your 3D objects")
	var mine := _picks(b)
	mine.add_child(UIK.pick(Icons.tex("upload", 48, UIK.TAPE), "Import", false, _import_props))
	for id in _style_props():
		var key: String = AssetLib.PREFIX + id
		mine.add_child(UIK.pick(_prop_icon(key), AssetLib.display_name(key), studio.tools.prop == key, func():
			studio.tools.set_tool("objects", {"prop": key})
			hud.close_sheet()))
	b.add_child(UIK.para("Import trees, rocks, buildings or whole asset packs (.glb, .gltf, .fbx — pick many files at once). Objects imported here stay in %s worlds.%s" % [Styles.get_style(studio.style_key)["name"], " They get cel shading, and leaves sway in the wind." if studio.style_key == "anime" else ""], 12))
	if not _style_props().is_empty() or not _style_models().is_empty():
		b.add_child(UIK.btn("Manage imported models", func(): hud.push_view("imports"), false, "trash"))
	b.add_child(UIK.btn("Edit placed objects", func():
		studio.tools.set_tool("objects", {"prop": ""})
		hud.close_sheet(), false, "pickI"))
	return "Objects"


func _import_props() -> void:
	hud.pick_files(PackedStringArray(["*.glb, *.GLB, *.gltf, *.GLTF, *.fbx, *.FBX ; 3D objects", "* ; All files"]), import_props, "Import 3D objects")


## Adds 3D object files to this style's object library (also used for files
## dropped on the window).
func import_props(paths: PackedStringArray) -> void:
	var ok := 0
	var too_big := 0
	var before := AssetLib.list()
	for pth in paths:
		var pid := AssetLib.import_file(pth)
		if pid == "":
			continue
		if AssetTags.check_import(studio.style_key, "props", AssetLib.DIR + pid) != "":
			too_big += 1
			if not before.has(pid):
				AssetLib.remove(pid)
			continue
		AssetTags.tag("props", pid, studio.style_key)
		ok += 1
	var msg := "Imported %d of %d object%s." % [ok, paths.size(), "" if paths.size() == 1 else "s"]
	if too_big > 0:
		msg += " %d %s too detailed for a low-poly world (over %s triangles)." % [too_big, "was" if too_big == 1 else "were", AssetTags._k(AssetTags.max_tris(studio.style_key, "props"))]
	hud.toast(msg)
	if hud.sheet.visible:
		_rerender()


# ---------------------------------------------------------------- cast

func v_cast(_a, b: VBoxContainer) -> String:
	_purpose(b, "Who’s in the scene and what each one does. Tap someone to change them.")
	# Grid of face portraits with name and current action underneath.
	var g := UIK.grid(3, 8)
	for a in studio.actors:
		var card := Button.new()
		card.focus_mode = Control.FOCUS_NONE
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size = Vector2(UIK.px(100), UIK.px(138))
		card.tooltip_text = a.name
		card.clip_contents = true
		UIK._card_states(card, a == studio.player, 16)
		var v := UIK.vbox(2)
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.offset_left = UIK.px(6)
		v.offset_right = -UIK.px(6)
		v.offset_top = UIK.px(6)
		v.offset_bottom = -UIK.px(8)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var face := Panel.new()
		face.clip_contents = true
		face.size_flags_vertical = Control.SIZE_EXPAND_FILL
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_theme_stylebox_override("panel", UIK.box(UIK.GRAY_800, 12))
		var thumb := TextureRect.new()
		thumb.texture = _face_icon(a.look)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		thumb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(thumb)
		v.add_child(face)
		var nl := UIK.label(a.name, 14, UIK.INK, true)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nl.clip_text = true
		nl.custom_minimum_size.x = 1
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(nl)
		var bl := UIK.label("You" if a == studio.player else Styles.behavior_label(a.base_behavior), 12, UIK.PRIMARY_300 if a == studio.player else UIK.MUTED)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bl.clip_text = true
		bl.custom_minimum_size.x = 1
		bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(bl)
		card.add_child(v)
		card.pressed.connect(func(): hud.push_view("actor", a.id))
		g.add_child(card)
	b.add_child(g)
	b.add_child(UIK.btn("Add a character", func(): hud.push_view("addChar"), true, "plus"))
	_section(b, "Everyone at once")
	var chips := UIK.flow()
	for beh in Styles.BEHAVIORS:
		chips.add_child(UIK.chip(beh[1], false, func():
			studio.checkpoint()
			for x in studio.actors:
				if x != studio.player:
					x.set_behavior(beh[0])
			studio.capture_start()
			studio.mark_dirty()
			_rerender()))
	b.add_child(chips)
	return "Cast (%d)" % studio.actors.size()


func v_actor(id: Variant, b: VBoxContainer) -> String:
	var a := studio.actor_by_id(int(id))
	if a == null:
		return ""
	var hero := UIK.hbox(14)
	var thumb := TextureRect.new()
	thumb.texture = _look_icon(a.look)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.custom_minimum_size = Vector2(UIK.px(72), UIK.px(72))
	hero.add_child(thumb)
	var name_edit := UIK.line_edit(a.name, "Name", func(t: String):
		studio.rename_actor(a, t.strip_edges().left(24) if t.strip_edges() != "" else "Someone"))
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero.add_child(name_edit)
	b.add_child(hero)
	var directing := studio.directing()
	if directing:
		_section(b, "What they do from %s" % TimelinePanel._fmt(studio.play_t))
		b.add_child(UIK.para("Director mode: picking an action adds a 5 s moment to the story at the playhead. Drag its edge in the timeline to change how long it lasts.", 12))
	elif a != studio.player:
		_section(b, "What they do")
	if directing or a != studio.player:
		var g := UIK.grid(3, 8)
		for beh in Styles.BEHAVIORS:
			var t := UIK.chip(beh[1], a.behavior == beh[0] if directing else a.base_behavior == beh[0], func():
				if studio.directing():
					studio.direct_action(a, beh[0])
					hud.toast("%s: %s from %s" % [a.name, beh[1], TimelinePanel._fmt(studio.play_t)])
				else:
					a.set_behavior(beh[0])
					studio.capture_start()
				studio.mark_dirty()
				_rerender())
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(t)
		b.add_child(g)
	if a.base_behavior == "dance" or a.behavior == "dance":
		_section(b, "Dance")
		var dg := UIK.flow()
		for d in Actor.DANCES:
			dg.add_child(UIK.chip(d[1], a.dance_style == d[0], func():
				a.dance_style = d[0]
				studio.mark_dirty()
				_rerender()))
		b.add_child(dg)
		b.add_child(UIK.para("Mix changes style every few seconds; any other style loops.", 12))
	if a != studio.player and (a.base_behavior == "pose" or a.behavior == "pose"):
		_section(b, "Pose")
		b.add_child(_pose_chips(a))
		if not directing:
			b.add_child(UIK.btn("Shape a pose", func(): hud.push_view("pose", a.id), false, "pose"))
	if a != studio.player:
		_section(b, "Feelings")
		b.add_child(UIK.para(_feelings_text(a), 12))
		b.add_child(UIK.btn("Friends, rivals and fears", func(): hud.push_view("feelings", a.id), false, "heart"))
	if a != studio.player:
		b.add_child(UIK.toggle("Notice the player (turn to look)", a.notice, func(on: bool): a.notice = on; studio.mark_dirty()))
		b.add_child(UIK.toggle("Chat while doing a task", a.chat_busy, func(on: bool): a.chat_busy = on; studio.mark_dirty()))
	_section(b, "Lines (one per line, said when chatting%s)" % (" and while busy" if a.chat_busy else ""))
	var te := TextEdit.new()
	te.text = "\n".join(PackedStringArray(a.lines.map(func(x): return str(x))))
	te.custom_minimum_size.y = UIK.px(110)
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.placeholder_text = "Have you seen the player?\nI saw them near the village."
	te.text_changed.connect(func():
		a.lines = Array(te.text.split("\n", false)).map(func(x): return x.strip_edges()).filter(func(x): return x != "")
		studio.mark_dirty())
	b.add_child(te)
	var say := UIK.hbox()
	say.add_child(UIK.btn("Say a line now", func(): a.say(a.line()), false, "chat"))
	b.add_child(say)
	_section(b, "Direct")
	var r1 := UIK.flow(8)
	r1.add_child(UIK.btn("Move from here" if directing else "Move", func():
		studio.tools.set_tool("move_actor", {"actor_id": a.id})
		hud.close_sheet(), false, "move"))
	r1.add_child(UIK.btn("Film them", func():
		studio.camera.cine["target"] = a.id
		studio.camera.set_mode("cine")
		studio.camera.cine_reset()
		hud.close_sheet(), false, "camera"))
	if a != studio.player:
		r1.add_child(UIK.btn("Play as them", func():
			studio.set_player(a)
			_rerender(), false, "play"))
	if a.rig.get("kind", "") == "model" and a.rig.get("skel") != null:
		r1.add_child(UIK.btn("Animations", func(): hud.push_view("anims", a.id), false, "dance"))
	b.add_child(r1)
	_section(b, "Look")
	var f := _picks(b)
	var presets := Rigs.presets_for(studio.style_key)
	for k in presets:
		f.add_child(UIK.pick(_look_icon({"preset": k}), presets[k].get("label", k), a.look.get("preset", "") == k, func():
			studio.checkpoint()
			a.set_look({"preset": k})
			studio.mark_dirty()
			_rerender(), studio.world.is_voxel and not presets[k].has("creature"), 74))
	f.add_child(UIK.pick(Icons.tex("shuffle", 48, UIK.TAPE), "Random", false, func():
		a.set_look({"cfg": Rigs.random_cfg(studio.style_key)})
		studio.mark_dirty()
		_rerender(), false, 74))
	for mid in ModelRig.list_models():
		if not _style_models().has(mid) and a.look.get("model", "") != mid:
			continue
		f.add_child(UIK.pick(_look_icon({"model": mid}), str(mid).get_basename().left(10), a.look.get("model", "") == mid, func():
			a.set_look({"model": mid})
			studio.mark_dirty()
			_rerender(), false, 74))
	if a != studio.player:
		b.add_child(UIK.spacer(6))
		b.add_child(UIK.danger("Remove from scene", func():
			studio.checkpoint()
			studio.remove_actor(a)
			hud.back_view()))
	return a.name


# ---------------------------------------------------------------- poses

var _pose_joint := "upperArmR"
var _pose_name := ""


## Built-in and saved poses as chips; picking one makes them hold it (in
## director mode, from the playhead for 5 s).
func _pose_chips(a: Actor) -> Control:
	var f := UIK.flow()
	var cur := a.pose
	var all: Array = Poses.BUILTIN_ORDER.map(func(k): return Poses.builtin(k))
	all.append_array(Poses.library())
	for p in all:
		var on: bool = (p.has("key") and str(cur.get("key", "")) == str(p["key"])) or (not p.has("key") and not cur.has("key") and str(cur.get("name", "")) == str(p["name"]))
		f.add_child(UIK.chip(str(p["name"]), on, func(): _apply_pose(a, p)))
	return f


func _apply_pose(a: Actor, p: Dictionary) -> void:
	if studio.directing():
		studio.direct_action(a, "pose", 5.0, p)
		hud.toast("%s: %s from %s" % [a.name, p["name"], TimelinePanel._fmt(studio.play_t)])
	else:
		a.pose = p.duplicate(true)
		a.base_pose = a.pose
		if a.base_behavior != "pose":
			a.set_behavior("pose")
			studio.capture_start()
	studio.mark_dirty()
	_rerender()


func _feelings_text(a: Actor) -> String:
	var parts := []
	for kind in [["friend", "Friends with"], ["rival", "Rivals with"], ["scared", "Scared of"]]:
		var names := []
		for n in a.rel:
			if a.rel[n] == kind[0] and studio.actor_by_name(n) != null:
				names.append(n)
		if not names.is_empty():
			parts.append("%s %s" % [kind[1], ", ".join(PackedStringArray(names))])
	return ("; ".join(PackedStringArray(parts)) + ".") if not parts.is_empty() else "No feelings about anyone yet: they treat everyone the same."


var _rel_both := true


## Friends, rivals and fears: how this character feels about everyone else.
func v_feelings(id: Variant, b: VBoxContainer) -> String:
	var a := studio.actor_by_id(int(id))
	if a == null:
		return ""
	_purpose(b, "How %s feels about the others. Friends greet each other, hang out together and stand up for each other. Rivals glare, mutter and pick fights. Scared ones run away." % a.name)
	b.add_child(UIK.toggle("Friends and rivals both ways", _rel_both, func(on: bool): _rel_both = on))
	for o in studio.actors:
		if o == a:
			continue
		var row := UIK.hbox(6)
		var nl := UIK.label(o.name + (" (you)" if o == studio.player else ""), 14, UIK.INK, true)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nl.clip_text = true
		nl.custom_minimum_size.x = UIK.px(70)
		row.add_child(nl)
		for fk in Actor.FEELINGS:
			if fk[0] == "":
				continue
			var on: bool = a.rel.get(o.name, "") == fk[0]
			row.add_child(UIK.chip(fk[1], on, func():
				var v: String = "" if on else fk[0]
				_set_feeling(a, o, v)
				if _rel_both and fk[0] != "scared" and o != studio.player:
					_set_feeling(o, a, v)
				studio.mark_dirty()
				_rerender()))
		b.add_child(row)
	return "%s’s feelings" % a.name


func _set_feeling(a: Actor, o: Actor, v: String) -> void:
	if v == "":
		a.rel.erase(o.name)
	else:
		a.rel[o.name] = v


const POSE_AXES := {"head": ["Turn", "Nod"], "spine": ["Lean forward", "Lean sideways"], "upperArm": ["Raise (forward)", "Out to the side"],
	"lowerArm": ["Bend", ""], "upperLeg": ["Raise (forward)", "Out to the side"], "lowerLeg": ["Bend", ""]}


## The pose editor: pick a joint, set its angles, save to the library.
func v_pose(id: Variant, b: VBoxContainer) -> String:
	var a := studio.actor_by_id(int(id))
	if a == null:
		return ""
	if a.base_behavior != "pose":
		a.set_behavior("pose")
		studio.capture_start()
	_purpose(b, "Start from a pose, then pick a joint and drag the sliders. Save it to use on anyone, in any scene.")
	b.add_child(_pose_chips(a))
	_section(b, "Joint")
	var jf := UIK.flow()
	for j in Poses.JOINTS:
		jf.add_child(UIK.chip(Poses.JOINT_NAMES[j], _pose_joint == j, func(): _pose_joint = j; _rerender()))
	b.add_child(jf)
	var j := _pose_joint
	var base_j: String = j.rstrip("LR") if j.begins_with("upper") or j.begins_with("lower") else j
	var axes: Array = POSE_AXES.get(base_j, ["Angle", ""])
	var rng: Array = Poses.RANGES[j]
	var cur := Poses.joint(a.pose, j)
	var deg := func(x: float) -> String: return "%d°" % roundi(rad_to_deg(x))
	var edit := func(axis: int, x: float) -> void:
		var p := a.pose.duplicate(true)
		p.erase("key")
		var v := Poses.joint(p, j)
		if axis == 0:
			v.x = x
		else:
			v.y = x
		Poses.set_joint(p, j, v)
		if not str(p.get("name", "")).ends_with("*") and p.has("name"):
			p["name"] = str(p["name"]) + "*"
		a.pose = p
		a.base_pose = p
		studio.mark_dirty()
	# Forward is negative in the pose; show raising as positive.
	var flip_x: bool = j.begins_with("upper") or j.begins_with("lowerArm") or j == "head"
	b.add_child(UIK.slider(axes[0], -cur.x if flip_x else cur.x, -rng[0][1] if flip_x else rng[0][0], -rng[0][0] if flip_x else rng[0][1], 0.02,
		func(x: float): edit.call(0, -x if flip_x else x), deg))
	if axes[1] != "":
		b.add_child(UIK.slider(axes[1], cur.y, rng[1][0], rng[1][1], 0.02, func(x: float): edit.call(1, x), deg))
	b.add_child(UIK.slider("Crouch or lift", float(a.pose.get("lift", 0.0)), -0.3, 0.1, 0.01, func(x: float):
		var p := a.pose.duplicate(true)
		p.erase("key")
		p.erase("sprite")
		p["lift"] = snappedf(x, 0.01)
		a.pose = p
		a.base_pose = p
		studio.mark_dirty(), func(x: float): return "%d%%" % roundi(x * 100)))
	var r := UIK.flow(8)
	r.add_child(UIK.btn("Mirror", func():
		a.pose = Poses.mirrored(a.pose)
		a.pose.erase("key")
		a.base_pose = a.pose
		studio.mark_dirty()
		_rerender(), false, "shuffle"))
	r.add_child(UIK.btn("Stand straight", func():
		a.pose = {"name": "Standing"}
		a.base_pose = a.pose
		studio.mark_dirty()
		_rerender(), false, "stand"))
	b.add_child(r)
	_section(b, "Pose library")
	if _pose_name == "":
		_pose_name = str(a.pose.get("name", "")).trim_suffix("*")
	var row := UIK.hbox(6)
	var le := UIK.line_edit(_pose_name, "Name this pose", func(t: String): _pose_name = t)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(le)
	row.add_child(UIK.btn("Save", func():
		var n := _pose_name.strip_edges()
		if n == "":
			hud.toast("Give the pose a name first.")
			return
		var p := a.pose.duplicate(true)
		p.erase("key")
		if Poses.save_pose(n, p):
			p["name"] = n.left(32)
			a.pose = p
			a.base_pose = p
			studio.mark_dirty()
			hud.toast("Saved “%s” to your poses." % n)
		else:
			hud.toast("Couldn’t save the pose.")
		_rerender(), true, "save"))
	b.add_child(row)
	var lib := Poses.library()
	if lib.is_empty():
		b.add_child(UIK.para("Saved poses show up for every character, in every scene and style.", 12))
	else:
		for p in lib:
			var lr := UIK.hbox(6)
			var nl := UIK.label(str(p["name"]), 14)
			nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lr.add_child(nl)
			lr.add_child(UIK.icon_btn("trash", func():
				Poses.delete_pose(str(p["name"]))
				_rerender(), "Delete pose", 36, false))
			b.add_child(lr)
	if a.rig.get("kind", "") == "sprite":
		b.add_child(UIK.para("Pixel 2D characters show the nearest picture they have (arms up, pointing, crouching, sitting).", 12))
	elif a.rig.get("kind", "") != "model":
		b.add_child(UIK.para("Built-in characters have no elbows or knees, so those joints only show on imported 3D characters.", 12))
	return "Pose"


# ---------------------------------------------------------------- script (timeline cues)

const CUE_ACTIONS := [["say", "Say"], ["walkto", "Walk to"], ["runto", "Run to"], ["idle", "Stand"], ["wander", "Wander"], ["talk", "Chat"], ["group", "Hang out"], ["dance", "Dance"], ["wave", "Wave"], ["sit", "Sit"], ["follow", "Follow"], ["flee", "Run away"], ["gather", "Gather"], ["sleep", "Sleep"], ["celebrate", "Celebrate"], ["laugh", "Laugh"], ["cry", "Cry"], ["point", "Point"], ["fight", "Fight"], ["pose", "Pose"]]


func v_script(_a, b: VBoxContainer) -> String:
	_purpose(b, "What happens, and when: who says what, who walks where. Play runs it from the start; recordings and exports follow it too.")
	var top := UIK.flow(8)
	top.add_child(UIK.btn("Play story", hud.play_script, true, "playtri"))
	top.add_child(UIK.btn("Timeline", hud.toggle_timeline, false, "film"))
	b.add_child(top)
	var cues := studio.cues.duplicate()
	cues.sort_custom(func(x, y): return float(x.get("start", 0)) < float(y.get("start", 0)))
	_section(b, "The story so far (%d)" % cues.size())
	if cues.is_empty():
		b.add_child(UIK.para("Nothing yet. Add the first moment below.", 12))
	for c in cues:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UIK.box(UIK.RAISE, 14, UIK.LINE))
		var h := UIK.hbox(8)
		var v := UIK.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var act_label := ""
		for ca in CUE_ACTIONS:
			if ca[0] == c.get("action"):
				act_label = ca[1]
		v.add_child(UIK.label("%s  %s" % [c.get("actor", "?"), act_label], 15, UIK.INK, true))
		var detail := "at %.1fs for %.1fs" % [float(c.get("start", 0)), float(c.get("dur", 3))]
		if c.get("action") == "say":
			detail = "“%s”  %s" % [str(c.get("text", "")), detail]
		var dl := UIK.para(detail, 12)
		v.add_child(dl)
		h.add_child(v)
		h.add_child(UIK.icon_btn("trash", func():
			studio.cues.erase(c)
			studio.mark_dirty()
			_rerender(), "Delete", 38, false))
		row.add_child(h)
		b.add_child(row)
	_section(b, "Add a moment")
	if new_cue["actor"] == "" or studio.actor_by_name(new_cue["actor"]) == null:
		new_cue["actor"] = studio.actors[0].name if not studio.actors.is_empty() else ""
	b.add_child(UIK.label("Who", 13, UIK.MUTED))
	var who := UIK.flow()
	for a in studio.actors:
		who.add_child(UIK.chip(a.name, new_cue["actor"] == a.name, func(): new_cue["actor"] = a.name; _rerender()))
	b.add_child(who)
	b.add_child(UIK.label("Action", 13, UIK.MUTED))
	var acts := UIK.flow()
	for ca in CUE_ACTIONS:
		acts.add_child(UIK.chip(ca[1], new_cue["action"] == ca[0], func(): new_cue["action"] = ca[0]; _rerender()))
	b.add_child(acts)
	if new_cue["action"] == "say":
		b.add_child(UIK.line_edit(new_cue["text"], "What they say", func(t: String): new_cue["text"] = t))
	elif new_cue["action"] in ["walkto", "runto"]:
		b.add_child(UIK.para("They head to where the camera is looking when you add the line.", 12))
	b.add_child(UIK.slider("Starts at", new_cue["start"], 0, 120, 0.5, func(x): new_cue["start"] = x, func(x): return "%.1fs" % x))
	b.add_child(UIK.slider("Lasts", new_cue["dur"], 0.5, 30, 0.5, func(x): new_cue["dur"] = x, func(x): return "%.1fs" % x))
	b.add_child(UIK.btn("Add to the story", _add_cue, true, "plus"))
	_section(b, "When something happens (%d)" % studio.triggers.list.size())
	b.add_child(UIK.para("Things that set off a reaction, live or while the story plays: someone walks into an area, or touches a character or an object.", 12))
	for i in studio.triggers.list.size():
		var tg: Dictionary = studio.triggers.list[i]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UIK.box(UIK.RAISE, 14, UIK.LINE))
		var h := UIK.hbox(8)
		var tl := UIK.para(Triggers.describe(tg), 13, UIK.INK)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(tl)
		h.add_child(UIK.icon_btn("edit", func():
			new_trig = tg.duplicate(true)
			hud.push_view("trigger", i), "Change", 38, false))
		h.add_child(UIK.icon_btn("trash", func():
			studio.triggers.list.remove_at(i)
			studio.triggers.reset()
			studio.triggers.refresh()
			studio.mark_dirty()
			_rerender(), "Delete", 38, false))
		row.add_child(h)
		b.add_child(row)
	b.add_child(UIK.btn("Add a trigger", func():
		new_trig = {"when": "enter", "who": "", "r": 3.0, "actor": "@who", "action": "say", "text": "", "dur": 3.0, "once": false}
		hud.push_view("trigger", -1), false, "plus"))
	var more := _fold(b, "story")
	more.add_child(UIK.para("The scene start is where everyone stands when the story begins. Move people where you want them, then:", 12))
	more.add_child(UIK.btn("Set scene start here", func():
		studio.capture_start()
		studio.mark_dirty()
		hud.toast("Everyone’s current spot is now the scene start."), false, "pin"))
	more.add_child(UIK.para("The Timeline is for exact timing: keyframes for characters and camera moves.", 12))
	return "Story"


# ---------------------------------------------------------------- triggers

## The trigger being made or changed (see Triggers for its keys).
var new_trig := {}


## Makes or changes a trigger (`idx` -1 = a new one).
func v_trigger(idx: Variant, b: VBoxContainer) -> String:
	var t := new_trig
	if t.is_empty():
		return ""
	var i := int(idx)
	var when := str(t.get("when", "enter"))
	var kind := "enter" if when == "enter" else ("touch_actor" if str(t.get("target", "")) != "" or t.get("_touch") == "actor" else "touch_spot")
	_purpose(b, "When something happens, someone reacts. Works live and while the story plays, the same every take.")
	_section(b, "When")
	var wf := UIK.flow()
	for w in Triggers.WHEN:
		wf.add_child(UIK.chip(w[1], kind == w[0], func():
			t["when"] = "enter" if w[0] == "enter" else "touch"
			t["_touch"] = "actor" if w[0] == "touch_actor" else "spot"
			if w[0] != "touch_actor":
				t.erase("target")
			if w[0] == "enter":
				t.erase("label")
			_rerender()))
	b.add_child(wf)
	b.add_child(UIK.label("Who sets it off", 13, UIK.MUTED))
	var who := UIK.flow()
	var opts := [["", "Anyone"], ["@player", "You"]]
	for a in studio.actors:
		if a != studio.player:
			opts.append([a.name, a.name])
	for o in opts:
		who.add_child(UIK.chip(o[1], str(t.get("who", "")) == o[0], func(): t["who"] = o[0]; _rerender()))
	b.add_child(who)
	var placed := t.has("x") or str(t.get("target", "")) != ""
	match kind:
		"enter":
			b.add_child(UIK.label("Where", 13, UIK.MUTED))
			b.add_child(UIK.btn("Move the area" if t.has("x") else "Place the area", func(): _pick_spot("Tap the ground where the area goes", false), not t.has("x"), "pin"))
			b.add_child(UIK.slider("Size (across)", float(t.get("r", 3.0)) * 2.0, 1.0, 16.0, 0.5, func(x): t["r"] = x / 2.0, func(x): return "%.1f m" % x))
		"touch_actor":
			b.add_child(UIK.label("Touching whom", 13, UIK.MUTED))
			var tf := UIK.flow()
			for a in studio.actors:
				tf.add_child(UIK.chip(a.name, str(t.get("target", "")) == a.name, func():
					t["target"] = a.name
					t.erase("x")
					_rerender()))
			b.add_child(tf)
		_:
			b.add_child(UIK.label("Which object", 13, UIK.MUTED))
			b.add_child(UIK.btn(("Touching: %s (tap to change)" % t.get("label", "that spot")) if t.has("x") else "Tap the object", func(): _pick_spot("Tap the object they should touch", true), not t.has("x"), "pin"))
	_section(b, "Then")
	b.add_child(UIK.label("Who reacts", 13, UIK.MUTED))
	var rf := UIK.flow()
	var ropts := [["@who", "Whoever it was"]]
	if kind == "touch_actor":
		ropts.append(["@target", "The one touched"])
	for a in studio.actors:
		if a != studio.player:
			ropts.append([a.name, a.name])
	for o in ropts:
		rf.add_child(UIK.chip(o[1], str(t.get("actor", "@who")) == o[0], func(): t["actor"] = o[0]; _rerender()))
	b.add_child(rf)
	b.add_child(UIK.label("What they do", 13, UIK.MUTED))
	var af := UIK.flow()
	for ac in Triggers.ACTIONS:
		af.add_child(UIK.chip(ac[1], str(t.get("action", "say")) == ac[0], func(): t["action"] = ac[0]; _rerender()))
	b.add_child(af)
	var say := str(t.get("action", "say")) == "say"
	b.add_child(UIK.line_edit(str(t.get("text", "")), "What they say" if say else "And they say… (optional)", func(x: String): t["text"] = x))
	if not str(t.get("action", "")) in ["walkto", "runto"]:
		b.add_child(UIK.slider("For", float(t.get("dur", 3.0)), 1.0, 15.0, 0.5, func(x): t["dur"] = x, func(x): return "%.1f s" % x))
	b.add_child(UIK.toggle("Only the first time", t.get("once", false) == true, func(on: bool): t["once"] = on))
	var row := UIK.flow(8)
	row.add_child(UIK.btn("Save trigger", func():
		if not placed:
			hud.toast("Place the area first." if kind == "enter" else ("Pick who gets touched." if kind == "touch_actor" else "Tap the object first."))
			return
		if say and str(t.get("text", "")).strip_edges() == "":
			hud.toast("Type what they say.")
			return
		var keep := t.duplicate(true)
		keep.erase("_touch")
		if i >= 0 and i < studio.triggers.list.size():
			studio.triggers.list[i] = keep
		else:
			studio.triggers.list.append(keep)
		studio.triggers.reset()
		studio.triggers.refresh()
		studio.mark_dirty()
		new_trig = {}
		hud.back_view(), true, "check"))
	b.add_child(row)
	return "Trigger"


## Hides the sheet so the next tap picks a spot (or object), then comes back.
func _pick_spot(hint: String, object: bool) -> void:
	var t := new_trig
	var idx: Variant = hud.view_stack[-1][1] if not hud.view_stack.is_empty() else -1
	var stack: Array = hud.view_stack.duplicate()
	studio.tools.spot_hint = hint
	studio.tools.spot_cb = func(hit: Dictionary):
		var p: Vector3 = hit["point"]
		t["x"] = U.r2(p.x)
		t["z"] = U.r2(p.z)
		if object:
			t["label"] = _object_label(hit, p)
		hud.view_stack = stack
		hud.render_sheet()
	hud.close_sheet()
	studio.tools.set_tool("pick_spot")


## A name for what was tapped: an object, an effect, a block, or a spot.
func _object_label(hit: Dictionary, p: Vector3) -> String:
	var fi := studio.fx.index_near(p, 1.5)
	if fi >= 0:
		return str(SceneFx.KINDS[studio.fx.items[fi]["k"]]["name"]).to_lower()
	var pr: Variant = hit.get("prop")
	if pr is Dictionary:
		return Props.display_name(studio.style_key, str(pr["key"])).to_lower()
	if studio.is_top() and int(hit.get("object", -1)) >= 0:
		var o: Array = studio.world.objects[int(hit["object"])]
		return str(PixelTopArt.OBJECTS.get(str(o[0]), {}).get("name", "the object")).to_lower()
	if studio.world.is_voxel and hit.has("v") and not hit.get("floor", false):
		return str(Blocks.get_block(int(hit["v"])).get("name", "the block")).to_lower()
	return "that spot"


func _add_cue() -> void:
	var c := new_cue.duplicate()
	if c["actor"] == "":
		return
	if c["action"] == "say" and str(c["text"]).strip_edges() == "":
		hud.toast("Type what they say first.")
		return
	if c["action"] in ["walkto", "runto"]:
		var cam := studio.camera
		var hit: Dictionary = studio.world.pick(cam.global_position, -cam.global_basis.z, 120.0)
		if hit.is_empty():
			hud.toast("Point the camera at the ground first.")
			return
		var p: Vector3 = hit["point"]
		c["x"] = U.r2(p.x)
		c["z"] = U.r2(p.z)
	studio.cues.append(c)
	new_cue["start"] = float(c["start"]) + float(c["dur"])
	new_cue["text"] = ""
	studio.mark_dirty()
	_rerender()


# ---------------------------------------------------------------- camera

func v_camera(_a, b: VBoxContainer) -> String:
	_purpose(b, "How you look at the scene right now. A live take (the red Record button) films through this camera.")
	var cam := studio.camera
	var tiles := [["follow", "Follow", "Third person", "third"], ["eye", "First person", "Their eyes", "first"], ["film", "Cinematic", "Auto shots", "cine"], ["drone", "Free camera", "Fly anywhere", "free"]]
	var g := UIK.grid(2, 10)
	for t in tiles:
		g.add_child(UIK.tile(t[0], t[1], t[2], cam.mode == t[3], func(): cam.set_mode(t[3]); studio.mark_dirty(); _rerender()))
	b.add_child(g)
	if cam.mode == "cine":
		_section(b, "Shot")
		var chips := UIK.flow()
		for s in CameraRig.SHOTS:
			chips.add_child(UIK.chip(s[1], cam.cine["shot"] == s[0], func():
				cam.cine["shot"] = s[0]
				cam.cine_reset()
				studio.mark_dirty()
				_rerender()))
		b.add_child(chips)
		if cam.cine["shot"] == "path":
			var n: int = (cam.cine["points"] as Array).size()
			b.add_child(UIK.para("%d point%s. Fly the free camera to each spot and add a point; the shot glides through them in order." % [n, "" if n == 1 else "s"], 12))
			var pr := UIK.flow()
			pr.add_child(UIK.btn("Add point from view", func():
				cam.add_path_point()
				studio.mark_dirty()
				hud.toast("Point %d added." % (cam.cine["points"] as Array).size())
				_rerender(), true, "pin"))
			pr.add_child(UIK.btn("Clear", func():
				cam.cine["points"] = []
				studio.mark_dirty()
				_rerender()))
			b.add_child(pr)
		_section(b, "Subject")
		var who := UIK.flow()
		who.add_child(UIK.chip("Player", int(cam.cine.get("target", 0)) == 0, func(): cam.cine["target"] = 0; cam.cine_reset(); _rerender()))
		for a in studio.actors:
			if a == studio.player:
				continue
			who.add_child(UIK.chip(a.name, int(cam.cine.get("target", 0)) == a.id, func(): cam.cine["target"] = a.id; cam.cine_reset(); _rerender()))
		b.add_child(who)
		b.add_child(UIK.slider("Shot length", cam.cine["dur"], 4, 40, 1, func(x): cam.cine["dur"] = x; studio.mark_dirty(), func(x): return "%ds" % int(x)))
		b.add_child(UIK.slider("Distance", cam.cine["dist"], 1.5, 24, 0.5, func(x): cam.cine["dist"] = x; studio.mark_dirty()))
		b.add_child(UIK.slider("Height", cam.cine["height"], 0, 14, 0.2, func(x): cam.cine["height"] = x; studio.mark_dirty()))
	elif cam.mode == "third":
		b.add_child(UIK.slider("Distance", cam.dist, 1.5, 16, 0.5, func(x): cam.dist = x; studio.mark_dirty()))
	var more := _fold(b, "camera")
	more.add_child(UIK.label("Lens", 13, UIK.MUTED, true))
	more.add_child(UIK.slider("Field of view", App.settings["fov"], 25, 110, 1, func(x): App.settings["fov"] = x; studio.mark_dirty(), func(x): return "%d°" % int(x)))
	more.add_child(UIK.toggle("Depth of field (focus on the subject)", App.settings["dof"], func(on): App.settings["dof"] = on; studio.mark_dirty()))
	more.add_child(UIK.toggle("Handheld shake", App.settings["shake"], func(on): App.settings["shake"] = on; studio.mark_dirty()))
	more.add_child(UIK.label("Live takes", 13, UIK.MUTED, true))
	var cd := UIK.flow()
	for n in [0, 3, 5]:
		cd.add_child(UIK.chip("No countdown" if n == 0 else "%ds countdown" % n, int(App.settings["countdown"]) == n, func(): App.settings["countdown"] = n; _rerender()))
	more.add_child(cd)
	more.add_child(UIK.toggle("Restart the cinematic shot when a take starts", App.settings["restart"], func(on): App.settings["restart"] = on))
	return "Camera"


# ---------------------------------------------------------------- mood

func v_mood(_a, b: VBoxContainer) -> String:
	_purpose(b, "Time of day, weather and sky.")
	if studio.is_side():
		_section(b, "Backdrop")
		var bc := UIK.flow()
		for k in PixelWorld.BACKDROPS:
			bc.add_child(UIK.chip(PixelWorld.BACKDROPS[k]["name"], studio.world.backdrop == k, func():
				studio.world.set_backdrop(k)
				studio.mark_dirty()
				_rerender()))
		b.add_child(bc)
		_section(b, "Mood")
	var g := UIK.grid(2, 10)
	for k in Styles.MOOD_ORDER:
		var m: Dictionary = Styles.MOODS[k]
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = m["label"]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_BOTTOM
		btn.custom_minimum_size = Vector2(UIK.px(140), UIK.px(86))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_override("font", UIK.font_bold)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
		var sb := StyleBoxTexture.new()
		sb.texture = _gradient(U.col(m["sw"][0]), U.col(m["sw"][1]))
		sb.content_margin_left = UIK.px(12)
		sb.content_margin_top = UIK.px(44)
		sb.texture_margin_left = 0
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)
		if App.settings["mood"] == k:
			btn.add_theme_stylebox_override("focus", UIK.box(Color(0, 0, 0, 0), 18, UIK.TAPE, 3))
			btn.text = "✓ " + m["label"]
		btn.pressed.connect(func():
			studio.atmo.apply_mood(k)
			# The music follows the new mood, unless you picked your own file.
			if str(App.settings.get("music", "")).begins_with("tune:"):
				App.settings["music"] = "mood"
			studio.mark_dirty()
			_rerender())
		g.add_child(btn)
	b.add_child(g)
	_section(b, "Weather")
	var w := UIK.flow()
	for x in [["clear", "Clear"], ["rain", "Rain & storm"], ["snow", "Snow"]]:
		w.add_child(UIK.chip(x[1], App.settings["weather"] == x[0], func():
			App.settings["weather"] = x[0]
			studio.atmo.apply()
			studio.mark_dirty()
			_rerender()))
	b.add_child(w)
	var more := _fold(b, "mood")
	more.add_child(UIK.slider("Time of day", App.settings["time"], 0, 24, 0.1, func(x):
		App.settings["time"] = x
		studio.atmo.apply()
		studio.mark_dirty(), func(x): return "%d:%02d" % [int(x), int(fmod(x, 1.0) * 60)]))
	more.add_child(UIK.slider("View distance (fog)", App.settings["fog"], 20, 200, 1, func(x):
		App.settings["fog"] = x
		studio.atmo.apply()
		studio.mark_dirty(), func(x): return "%dm" % int(x)))
	more.add_child(UIK.toggle("Day and night cycle", App.settings["cycle"], func(on): App.settings["cycle"] = on; studio.mark_dirty()))
	return "Mood"


static var _grad_cache := {}


func _gradient(a: Color, c: Color) -> Texture2D:
	var key := a.to_html() + c.to_html()
	if _grad_cache.has(key):
		return _grad_cache[key]
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, c)
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0.4, 1)
	gt.width = 64
	gt.height = 64
	_grad_cache[key] = gt
	return gt


# ---------------------------------------------------------------- film (record & shots)

const SHOT_TYPES := [["orbit", "Orbit"], ["dolly", "Dolly"], ["crane", "Crane"], ["push", "Push in"], ["path", "Path"], ["third", "Follow"], ["first", "First person"], ["keys", "Keyframed"]]


func v_film(_a, b: VBoxContainer) -> String:
	_purpose(b, "Make a video of the whole scene: it plays from the start and cuts between your shots. (To film what you do live, use the red Record button.)")
	_section(b, "Shots (%d, %s)" % [studio.shots.size(), U.fmt_time(_shots_len())])
	for i in studio.shots.size():
		var s: Dictionary = studio.shots[i]
		var row := Button.new()
		row.focus_mode = Control.FOCUS_NONE
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = UIK.px(48)
		var kind := str(s.get("shot", "orbit")) if s.get("mode", "cine") == "cine" else str(s.get("mode"))
		var tgt := str(s.get("target", ""))
		row.text = "%d.  %s  ·  %s%s  ·  %.1fs" % [i + 1, s.get("name", "Shot"), _shot_label(kind), (" on " + tgt) if tgt != "" else "", float(s.get("dur", 4))]
		UIK._card_states(row, false, 12)
		row.pressed.connect(func(): hud.push_view("shot", i))
		b.add_child(row)
	var add_shot := UIK.btn("Add shot", func():
		studio.shots.append({"name": "Shot %d" % (studio.shots.size() + 1), "mode": "cine", "shot": "orbit", "target": "", "dur": 4.0, "dist": 6.0, "height": 2.2})
		studio.mark_dirty()
		hud.push_view("shot", studio.shots.size() - 1), false, "plus")
	add_shot.custom_minimum_size.y = UIK.px(48)
	b.add_child(add_shot)
	_section(b, "Video")
	var fr := UIK.flow()
	for f in [["full", "Window"], ["16:9", "16:9 wide"], ["9:16", "9:16 Shorts"], ["1:1", "1:1 square"]]:
		fr.add_child(UIK.chip(f[1], App.settings["frame"] == f[0], func():
			App.settings["frame"] = f[0]
			hud.frame_guide.queue_redraw()
			studio.mark_dirty()
			_rerender()))
	b.add_child(fr)
	var res := UIK.flow()
	for k in App.RES:
		res.add_child(UIK.chip(App.RES[k]["label"], str(App.settings["res"]) == k, func(): App.settings["res"] = k; studio.mark_dirty(); _rerender()))
	b.add_child(res)
	b.add_child(UIK.toggle("Burn in subtitles for dialogue", App.settings["subtitles"], func(on): App.settings["subtitles"] = on; studio.mark_dirty(); _rerender()))
	var bgk := str(App.settings.get("bg", "scene"))
	var vs := hud.get_viewport_rect().size
	var sz := App.export_size(vs.x / vs.y)
	var unfinished := studio.unfinished_export()
	var go := UIK.btn("Carry on export" if not unfinished.is_empty() else "Export video", hud.export_film_flow, true, "film")
	go.custom_minimum_size.y = UIK.px(50)
	b.add_child(UIK.spacer(4))
	b.add_child(go)
	b.add_child(UIK.para("%d × %d · %s" % [sz.x, sz.y, Recorder.kind_label(Recorder.kind_for(bgk))], 12))
	var more := _fold(b, "export")
	more.add_child(UIK.label("Frame rate", 13, UIK.MUTED, true))
	var fps := UIK.flow()
	for f in [24, 30, 60]:
		fps.add_child(UIK.chip("%d fps" % f, int(App.settings["fps"]) == f, func(): App.settings["fps"] = f; studio.mark_dirty(); _rerender()))
	more.add_child(fps)
	more.add_child(UIK.label("Background", 13, UIK.MUTED, true))
	var bgr := UIK.flow()
	for o in Recorder.BACKGROUNDS:
		bgr.add_child(UIK.chip(o[1], bgk == o[0], func():
			App.settings["bg"] = o[0]
			studio.mark_dirty()
			_rerender()))
	more.add_child(bgr)
	if bgk in ["green", "blue"]:
		more.add_child(UIK.para("The world and sky are replaced by flat %s behind the characters, for keying in a video editor. Characters keep their lighting." % ("green" if bgk == "green" else "blue"), 12))
	elif bgk == "alpha":
		more.add_child(UIK.para("Only the characters, on a transparent background, to lay over other footage.", 12))
	if App.settings["subtitles"]:
		more.add_child(UIK.label("Subtitles", 13, UIK.MUTED, true))
		_subtitle_options(more)
	if Media.can_reveal():
		more.add_child(UIK.btn("Open videos folder", func(): OS.shell_open(Recorder.output_dir()), false, "folder"))
	return "Export"


func _shot_label(kind: String) -> String:
	for s in SHOT_TYPES:
		if s[0] == kind:
			return s[1]
	return kind


func _shots_len() -> float:
	var t := 0.0
	for s in studio.shots:
		t += float(s.get("dur", 4))
	return t


func v_shot(i: Variant, b: VBoxContainer) -> String:
	var idx := int(i)
	if idx < 0 or idx >= studio.shots.size():
		return ""
	var s: Dictionary = studio.shots[idx]
	b.add_child(UIK.line_edit(s.get("name", ""), "Shot name", func(t): s["name"] = t; studio.mark_dirty()))
	_section(b, "Camera")
	var chips := UIK.flow()
	var cur := str(s.get("shot", "orbit")) if s.get("mode", "cine") == "cine" else str(s.get("mode"))
	for st in SHOT_TYPES:
		chips.add_child(UIK.chip(st[1], cur == st[0], func():
			if st[0] in ["third", "first", "keys"]:
				s["mode"] = st[0]
			else:
				s["mode"] = "cine"
				s["shot"] = st[0]
			studio.mark_dirty()
			_rerender()))
	b.add_child(chips)
	if cur == "keys":
		var n: int = studio.timeline.track(Timeline.CAM).size()
		b.add_child(UIK.para("Follows the camera keys from the timeline (%d key%s) at the scene clock." % [n, "" if n == 1 else "s"], 12))
	if cur == "path":
		var n: int = (s.get("points", []) as Array).size()
		b.add_child(UIK.para("Uses %d path point%s copied from the camera panel." % [n, "" if n == 1 else "s"], 12))
		b.add_child(UIK.btn("Copy current camera path", func():
			s["points"] = (studio.camera.cine["points"] as Array).duplicate(true)
			studio.mark_dirty()
			_rerender()))
	_section(b, "Subject")
	var who := UIK.flow()
	who.add_child(UIK.chip("Player", str(s.get("target", "")) == "", func(): s["target"] = ""; studio.mark_dirty(); _rerender()))
	for a in studio.actors:
		if a != studio.player:
			who.add_child(UIK.chip(a.name, str(s.get("target", "")) == a.name, func(): s["target"] = a.name; studio.mark_dirty(); _rerender()))
	b.add_child(who)
	b.add_child(UIK.slider("Length", s.get("dur", 4.0), 1, 30, 0.5, func(x): s["dur"] = x; studio.mark_dirty(), func(x): return "%.1fs" % x))
	b.add_child(UIK.slider("Distance", s.get("dist", 6.0), 1.5, 24, 0.5, func(x): s["dist"] = x; studio.mark_dirty()))
	b.add_child(UIK.slider("Height", s.get("height", 2.2), 0, 14, 0.2, func(x): s["height"] = x; studio.mark_dirty()))
	b.add_child(UIK.line_edit(s.get("title", ""), "Title card (optional)", func(t): s["title"] = t; studio.mark_dirty()))
	b.add_child(UIK.toggle("Fade in", s.get("fade_in", false), func(on): s["fade_in"] = on; studio.mark_dirty()))
	b.add_child(UIK.toggle("Fade out", s.get("fade_out", false), func(on): s["fade_out"] = on; studio.mark_dirty()))
	var r := UIK.flow()
	r.add_child(UIK.btn("Preview", func(): hud.start_shot_preview(idx), false, "playtri"))
	if idx > 0:
		r.add_child(UIK.btn("Move up", func():
			studio.shots.remove_at(idx)
			studio.shots.insert(idx - 1, s)
			studio.mark_dirty()
			hud.view_stack[-1][1] = idx - 1
			_rerender(), false, "up"))
	r.add_child(UIK.danger("Delete", func():
		studio.shots.remove_at(idx)
		studio.mark_dirty()
		hud.back_view()))
	b.add_child(r)
	return s.get("name", "Shot")


# ---------------------------------------------------------------- settings

func v_settings(_a, b: VBoxContainer) -> String:
	_purpose(b, "This scene first, then this device. (How new scenes start is in Settings on the home screen.)")
	_section(b, "This scene")
	b.add_child(UIK.toggle("Characters chat on their own (speech bubbles)", App.settings.get("chatter", true), func(on: bool):
		App.settings["chatter"] = on
		studio.mark_dirty()))
	b.add_child(UIK.toggle("Characters speak up when hit", App.settings.get("hit_lines", true), func(on: bool):
		App.settings["hit_lines"] = on
		studio.mark_dirty()))
	b.add_child(UIK.toggle("Characters react to what happens nearby (fights, monsters, friends, fire)", App.settings.get("reactions", true), func(on: bool):
		App.settings["reactions"] = on
		studio.mark_dirty()))
	var r := UIK.flow()
	r.add_child(UIK.btn("Share scene file" if App.is_mobile and Native.available() else "Export scene file", func():
		await studio.save_now()
		hud.export_project(studio.project_id, studio.project_name), false, "download"))
	b.add_child(r)
	_section(b, "Quality")
	var q := UIK.flow()
	for k in App.QUALITY:
		q.add_child(UIK.chip(App.QUALITY[k]["label"], App.device["quality"] == k, func():
			App.set_device("quality", k)
			studio.atmo.apply_quality()
			studio.atmo.apply()
			_rerender()))
	b.add_child(q)
	b.add_child(UIK.para("Lower is smoother on older phones. Exported videos always render at full quality.", 12))
	_section(b, "Controls")
	b.add_child(UIK.toggle("Show name tags", App.device["names"], func(on):
		App.set_device("names", on)
		for a in studio.actors:
			a.refresh_tag()))
	b.add_child(UIK.toggle("Auto-jump onto blocks", App.device["auto_jump"], func(on): App.set_device("auto_jump", on)))
	if not App.is_touch:
		b.add_child(UIK.toggle("Lock the mouse to look around", App.device["mouse_look"] == "capture", func(on): App.set_device("mouse_look", "capture" if on else "drag")))
	var more := _fold(b, "settings")
	more.add_child(UIK.label("Frame rate", 13, UIK.MUTED, true))
	var fr := UIK.flow()
	for c in [[30, "30 fps"], [60, "60 fps"], [0, "Highest"]]:
		fr.add_child(UIK.chip(c[1], int(App.device.get("fps_cap", 0)) == c[0], func():
			App.set_device("fps_cap", c[0])
			App.apply_fps()
			_rerender()))
	more.add_child(fr)
	more.add_child(UIK.toggle("Show frame rate", App.device["show_fps"], func(on): App.set_device("show_fps", on)))
	more.add_child(UIK.toggle("Countdown beeps before a take", App.device.get("ui_sounds", false), func(on): App.set_device("ui_sounds", on)))
	more.add_child(UIK.toggle("Pause exports to cool down when the device slows", App.device.get("cool_down", false), func(on): App.set_device("cool_down", on)))
	more.add_child(UIK.slider("Interface size", App.device["ui_scale"], 0.8, 1.6, 0.05, func(x): App.set_device("ui_scale", x), func(x): return "%d%%" % int(x * 100)))
	more.add_child(UIK.para("Interface size applies the next time you open the app.", 12))
	if not App.is_touch:
		more.add_child(UIK.label("Keys", 13, UIK.MUTED, true))
		more.add_child(UIK.para("WASD move · Space jump · Shift sprint · Ctrl crouch · left click attack · right click a character for their menu · drag to look · wheel zoom · C camera · B build · T timeline · R record · P screenshot · H clean view · Ctrl+Z undo · Esc close", 12))
	more.add_child(UIK.label("About", 13, UIK.MUTED, true))
	b = more
	var logo := TextureRect.new()
	logo.texture = load("res://assets/brand/wordmark.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, UIK.px(110))
	b.add_child(logo)
	b.add_child(UIK.para("GameScene Studio is a visual workspace for creating, animating and bringing game scenes to life.", 13, UIK.GRAY_200))
	var renderer: String = {"forward_plus": "Forward+", "mobile": "Mobile", "gl_compatibility": "Compatibility"}.get(RenderingServer.get_current_rendering_method(), RenderingServer.get_current_rendering_method())
	b.add_child(UIK.para("Version %s  •  Godot %s  •  %s" % [ProjectSettings.get_setting("application/config/version"), Engine.get_version_info()["string"], renderer], 12))
	var credits := RichTextLabel.new()
	credits.bbcode_enabled = true
	credits.fit_content = true
	credits.scroll_active = false
	credits.autowrap_mode = TextServer.AUTOWRAP_OFF
	credits.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	credits.add_theme_font_size_override("normal_font_size", UIK.px(13))
	credits.add_theme_font_size_override("bold_font_size", UIK.px(13))
	credits.add_theme_font_override("bold_font", UIK.font_bold)
	credits.add_theme_color_override("default_color", UIK.MUTED)
	credits.text = "Built by [url=https://ekaai.tech][b][color=#%s]ekaai.tech[/color][/b][/url]" % UIK.SECONDARY_300.to_html(false)
	credits.meta_clicked.connect(func(url): OS.shell_open(str(url)))
	b.add_child(credits)
	return "Settings"


# ---------------------------------------------------------------- sound

## A row for a sound: name, a play/stop preview button and a pick action.
func _sound_row(key: String, sub: String, on: bool, cb: Callable) -> Control:
	var h := UIK.hbox(6)
	var pick := Button.new()
	pick.focus_mode = Control.FOCUS_NONE
	pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
	pick.text = Sounds.label(key) + ("   ·  " + sub if sub != "" else "")
	pick.custom_minimum_size.y = UIK.px(46)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.clip_text = true
	UIK._card_states(pick, on, 12)
	# Centre the text on the card's face, not face + raised bottom edge.
	for st in ["normal", "hover", "pressed"]:
		var sb := pick.get_theme_stylebox(st).duplicate() as StyleBoxFlat
		sb.content_margin_top -= UIK.px(7)
		pick.add_theme_stylebox_override(st, sb)
	pick.pressed.connect(cb)
	h.add_child(pick)
	var pv := UIK.icon_btn("pause" if studio.sound.previewing(key) else "playtri", func():
		studio.sound.preview(key)
		_rerender(), "Listen", 40, false)
	h.add_child(pv)
	return h


func _import_sound(then: Callable) -> void:
	hud.pick_file(PackedStringArray(["*.ogg, *.mp3, *.wav ; Sound files"]), func(path: String):
		var id := AudioFiles.import_file(path)
		if id == "":
			hud.toast(AudioFiles.last_error)
			return
		hud.toast("Imported " + AudioFiles.display_name(id) + ".")
		then.call("file:" + id), "Import music or a sound")


## Scene sound: background music, ambience, effects and volumes.
func v_sound(_a, b: VBoxContainer) -> String:
	_purpose(b, "Music, ambience and sound effects, live and in your videos.")
	_section(b, "Background music")
	var cur := str(App.settings.get("music", ""))
	var top := UIK.flow()
	top.add_child(UIK.chip("Match the mood", cur == "mood", func():
		App.settings["music"] = "mood"
		studio.sound.stop_preview()
		studio.mark_dirty()
		_rerender()))
	top.add_child(UIK.chip("No music", cur == "", func():
		App.settings["music"] = ""
		studio.sound.stop_preview()
		studio.mark_dirty()
		_rerender()))
	if cur.begins_with("tune:") or cur.begins_with("file:"):
		top.add_child(UIK.chip("♪ " + Sounds.label(cur), true, func(): pass))
	b.add_child(top)
	if cur == "mood":
		var mood := str(App.settings.get("mood", "day"))
		b.add_child(UIK.para("Playing %s for %s. Changing the mood changes the music (with a crossfade)." % [
			Sounds.label("tune:" + str(Synth.MOOD_TUNES.get(mood, "meadow"))), str((Styles.MOODS.get(mood, {}) as Dictionary).get("label", mood)).to_lower()], 12))
	var tunes := _fold(b, "tunes", "Choose a tune", "playtri")
	for t in Synth.TUNE_ORDER:
		var key: String = "tune:" + t
		tunes.add_child(_sound_row(key, Synth.TUNES[t]["desc"], cur == key, func():
			App.settings["music"] = key
			studio.sound.stop_preview()
			studio.mark_dirty()
			_rerender()))
	for id in AudioFiles.list():
		var key: String = "file:" + id
		tunes.add_child(_sound_row(key, "Imported", cur == key, func():
			App.settings["music"] = key
			studio.sound.stop_preview()
			studio.mark_dirty()
			_rerender()))
	tunes.add_child(UIK.btn("Import music or a sound", func():
		_import_sound(func(key: String):
			App.settings["music"] = key
			studio.mark_dirty()
			_rerender()), false, "upload"))
	tunes.add_child(UIK.para("For music that starts at a set moment, add it to the timeline's Sound row.", 12))
	_section(b, "Ambience")
	var amb := UIK.flow()
	for a in Sounds.AMBIENCES:
		amb.add_child(UIK.chip(a[1], str(App.settings.get("ambience", "auto")) == a[0], func():
			App.settings["ambience"] = a[0]
			studio.mark_dirty()
			_rerender()))
	b.add_child(amb)
	if str(App.settings.get("ambience", "auto")) == "auto":
		var now := Sounds.auto_ambience()
		for a in Sounds.AMBIENCES:
			if a[0] == now:
				b.add_child(UIK.para("Follows the mood and weather: %s right now." % str(a[1]).to_lower(), 12))
	_section(b, "Effects")
	b.add_child(UIK.toggle("Footsteps, splashes and hits", App.settings.get("sfx", true), func(on):
		App.settings["sfx"] = on
		studio.mark_dirty()))
	var vol := _fold(b, "volume", "Volume", "speaker")
	var pct := func(x: float) -> String: return "%d%%" % int(round(x * 100))
	vol.add_child(UIK.slider("Music", float(App.settings.get("music_vol", 0.7)), 0.0, 1.0, 0.05, func(x):
		App.settings["music_vol"] = x
		studio.mark_dirty(), pct))
	vol.add_child(UIK.slider("Effects", float(App.settings.get("sfx_vol", 0.8)), 0.0, 1.0, 0.05, func(x):
		App.settings["sfx_vol"] = x
		studio.mark_dirty(), pct))
	vol.add_child(UIK.slider("Ambience", float(App.settings.get("amb_vol", 0.6)), 0.0, 1.0, 0.05, func(x):
		App.settings["amb_vol"] = x
		studio.mark_dirty(), pct))
	vol.add_child(UIK.para("Exported videos are mixed at these volumes.", 12))
	return "Sound"


## Picks a sound to put on the timeline at the playhead.
func v_sounds(_a, b: VBoxContainer) -> String:
	b.add_child(UIK.para("Starts at %s on the timeline. Drag it to move it, or drag its end to make it shorter or longer (music loops)." % TimelinePanel._fmt(studio.play_t), 12))
	var add := func(key: String) -> void:
		var ln := Sounds.length(key)
		var dur := minf(ln, 12.0) if key.begins_with("tune:") else ln
		var c := {"src": key, "start": snappedf(studio.play_t, 0.1), "dur": snappedf(maxf(dur, 0.5), 0.1), "vol": 1.0}
		studio.audio.append(c)
		studio.sound.stop_preview()
		studio.mark_dirty()
		hud.timeline_panel.select_clip(c)
		hud.close_sheet()
	_section(b, "Music")
	for t in Synth.TUNE_ORDER:
		var key: String = "tune:" + t
		b.add_child(_sound_row(key, Synth.TUNES[t]["desc"], false, add.bind(key)))
	_section(b, "Imported")
	var files := AudioFiles.list()
	if files.is_empty():
		b.add_child(UIK.para("Nothing imported yet.", 12))
	for id in files:
		var key: String = "file:" + id
		b.add_child(_sound_row(key, "%.1f s" % Sounds.length(key), false, add.bind(key)))
	b.add_child(UIK.btn("Import music or a sound", func(): _import_sound(add), false, "upload"))
	_rights(b)
	return "Add a sound"


## Edits the timeline sound clip selected in the timeline.
func v_clip(_a, b: VBoxContainer) -> String:
	var c: Dictionary = hud.timeline_panel.sel_clip
	if c.is_empty() or not studio.audio.has(c):
		return "Sound"
	var key := str(c.get("src", ""))
	b.add_child(_sound_row(key, "", true, func(): pass))
	var edited := func() -> void:
		studio.mark_dirty()
		hud.timeline_panel.view.queue_redraw()
	b.add_child(UIK.slider("Volume", float(c.get("vol", 1.0)), 0.0, 1.0, 0.05, func(x):
		c["vol"] = x
		edited.call(), func(x: float) -> String: return "%d%%" % int(round(x * 100))))
	b.add_child(UIK.slider("Starts at", float(c.get("start", 0.0)), 0.0, maxf(60.0, float(c.get("start", 0.0)) + 10.0), 0.1, func(x):
		c["start"] = x
		edited.call(), func(x: float) -> String: return "%.1f s" % x))
	b.add_child(UIK.slider("Length", SoundDirector.clip_len(c), 0.5, maxf(60.0, SoundDirector.clip_len(c) + 10.0), 0.1, func(x):
		c["dur"] = x
		edited.call(), func(x: float) -> String: return "%.1f s" % x))
	if Sounds.length(key) > 0.0 and SoundDirector.clip_len(c) > Sounds.length(key) + 0.05:
		b.add_child(UIK.para("Longer than the sound, so it loops.", 12))
	b.add_child(UIK.danger("Remove from the timeline", func():
		hud.timeline_panel.delete_clip()
		hud.close_sheet()))
	return "Sound clip"


## Subtitle style, size, position and names, with a live preview.
func _subtitle_options(b: VBoxContainer) -> void:
	var set_sub := func(k: String, v: Variant) -> void:
		App.settings[k] = v
		studio.mark_dirty()
		_rerender()
	var st := UIK.flow()
	for o in Recorder.SUB_STYLES:
		st.add_child(UIK.chip(o[1], App.settings.get("sub_style", "box") == o[0], set_sub.bind("sub_style", o[0])))
	b.add_child(st)
	var sz := UIK.flow()
	for o in [["s", "Small"], ["m", "Medium"], ["l", "Large"]]:
		sz.add_child(UIK.chip(o[1], App.settings.get("sub_size", "m") == o[0], set_sub.bind("sub_size", o[0])))
	for o in [["bottom", "Bottom"], ["top", "Top"]]:
		sz.add_child(UIK.chip(o[1], App.settings.get("sub_pos", "bottom") == o[0], set_sub.bind("sub_pos", o[0])))
	sz.add_child(UIK.chip("Speaker names", App.settings.get("sub_names", true), set_sub.bind("sub_names", not App.settings.get("sub_names", true))))
	b.add_child(sz)
	# Preview on a little frame the shape of the video.
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UIK.box(Color("2c3e50"), 10))
	frame.custom_minimum_size = Vector2(0, UIK.px(120))
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_BEGIN if App.settings.get("sub_pos", "bottom") == "top" else BoxContainer.ALIGNMENT_END
	var center := CenterContainer.new()
	var sl := Label.new()
	Recorder.style_subtitle(sl, UIK.px(300))
	# A centring box gives a wrapping label no width (one letter per line):
	# the short preview line doesn't need to wrap.
	sl.autowrap_mode = TextServer.AUTOWRAP_OFF
	sl.text = Recorder.subtitle_text("Vaibh", "Shall we go see the lake?")
	center.add_child(sl)
	box.add_child(center)
	frame.add_child(box)
	b.add_child(frame)


# ---------------------------------------------------------------- animation library

const ANIM_ACTIONS := [["idle", "Idle"], ["walk", "Walk"], ["run", "Run"], ["talk", "Talk"], ["dance", "Dance"], ["wave", "Wave"], ["sit", "Sit"],
	["celebrate", "Celebrate"], ["laugh", "Laugh"], ["cry", "Cry"], ["point", "Point"], ["fight", "Fight"], ["sleep", "Sleep"]]
var _anim_action := "dance"


## Picks library clips for an imported character's actions.
func v_anims(id: Variant, b: VBoxContainer) -> String:
	var a := studio.actor_by_id(int(id))
	if a == null:
		return ""
	var anims: Dictionary = a.look.get("anims", {}) if a.look.get("anims") is Dictionary else {}
	b.add_child(UIK.para("Use animation clips (Mixamo and other .fbx, .glb or .gltf files) for %s's actions. Clips are fitted to any humanoid, whatever its rest pose or bone names." % a.name, 12))
	b.add_child(UIK.btn("Import animations", func():
		hud.pick_file(PackedStringArray(["*.fbx, *.glb, *.gltf ; Animation files"]), func(path: String):
			hud.toast("Importing " + path.get_file() + "…")
			var lid := AnimLib.import_file(path)
			if lid == "":
				hud.toast(AnimLib.last_error)
				return
			hud.toast("Added %d clip%s." % [(AnimLib.load_lib(lid).get("clips", []) as Array).size(), "" if (AnimLib.load_lib(lid).get("clips", []) as Array).size() == 1 else "s"])
			_rerender(), "Import animations"), false, "upload"))
	_section(b, "Action")
	var acts := UIK.flow()
	for ac in ANIM_ACTIONS:
		var label: String = ac[1] + (" ●" if anims.has(ac[0]) else "")
		acts.add_child(UIK.chip(label, _anim_action == ac[0], func():
			_anim_action = ac[0]
			_rerender()))
	b.add_child(acts)
	_section(b, "Clip for %s" % _anim_action)
	var cur := str(anims.get(_anim_action, ""))
	var set_clip := func(key: String) -> void:
		var d: Dictionary = anims.duplicate()
		if key == "":
			d.erase(_anim_action)
		else:
			d[_anim_action] = key
		a.look["anims"] = d
		studio.mark_dirty()
		_rerender()
	b.add_child(UIK.chip("Built-in pose", cur == "", set_clip.bind("")))
	var clips := AnimLib.all_clips()
	if clips.is_empty():
		b.add_child(UIK.para("No clips yet. Import some to get started.", 12))
	for c in clips:
		var row := UIK.hbox(6)
		var pick := UIK.chip("%s  ·  %.1f s" % [c[1], c[2]], cur == c[0], set_clip.bind(str(c[0])))
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(pick)
		b.add_child(row)
	if not _anim_action in ["idle", "walk", "run", "talk"]:
		b.add_child(UIK.btn("Try it", func():
			a.set_behavior(_anim_action, false)
			hud.close_sheet(), false, "playtri"))
	return "Animations"
