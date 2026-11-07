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

func _section(b: Control, text: String) -> void:
	b.add_child(UIK.spacer(4))
	b.add_child(UIK.label(text, 13, UIK.MUTED, true))


func _tiles(b: Control, items: Array) -> void:
	var g := UIK.grid(2, 10)
	for it in items:
		g.add_child(UIK.tile(it[0], it[1], it[2], it.size() > 4 and it[4], it[3]))
	b.add_child(g)


func _picks(b: Control) -> HFlowContainer:
	var f := UIK.flow(8)
	b.add_child(f)
	return f


func _look_icon(look: Dictionary) -> Texture2D:
	var style := studio.style_key
	var key := "look|" + style + "|" + JSON.stringify(look).md5_text()
	return hud.icons.request(key, func(): return _build_look(look, style), "char")


func _build_look(look: Dictionary, style: String) -> Node3D:
	var r: Dictionary = ModelRig.build(look) if look.has("model") else Rigs.build(look, style)
	return r["root"]


func _prop_icon(key: String) -> Texture2D:
	var style := studio.style_key
	return hud.icons.request("prop|" + style + "|" + key, func(): return Props.build(style, key, 7), "prop")


func _rerender() -> void:
	hud.render_sheet()


# ---------------------------------------------------------------- add

func v_add(_a, b: VBoxContainer) -> String:
	var items := [["person", "Character", "People, monsters, animals", func(): hud.push_view("addChar")]]
	if studio.world.is_voxel:
		items.append(["cube", "Blocks", "Place and break", func(): hud.push_view("blocks")])
		items.append(["house", "Buildings", "Houses, towers, trees", func(): hud.push_view("prefabs")])
	else:
		items.append(["tree", "Objects", "Trees, houses, props", func(): hud.push_view("objects")])
		items.append(["hill", "Ground", "Raise hills, dig valleys", func(): studio.tools.set_tool("terrain"); hud.close_sheet()])
	items.append(["upload", "3D model", "Import .glb or .vrm", func(): _import_model()])
	_tiles(b, items)
	b.add_child(UIK.para("Tip: tap a character in the scene to direct them. Press B for the build tool.", 12))
	return "Add"


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
	_models_section(b, func(id): _add_char({"model": id}, {"label": id.get_basename()}))
	return "Add a character"


func _models_section(b: VBoxContainer, on_pick: Callable) -> void:
	_section(b, "3D models")
	var f := _picks(b)
	f.add_child(UIK.pick(Icons.tex("upload", 48, UIK.TAPE), "Import", false, _import_model))
	for id in ModelRig.list_models():
		f.add_child(UIK.pick(_look_icon({"model": id}), str(id).get_basename().left(10), false, func(): on_pick.call(id)))
	b.add_child(UIK.para("Humanoid .glb/.vrm files work best. Clips named idle, walk, run, dance, wave or sit play automatically.", 12))


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
	hud.pick_file(PackedStringArray(["*.glb, *.vrm, *.gltf ; 3D models"]), func(path: String):
		hud.toast("Importing " + path.get_file() + "…")
		var id := ModelRig.import_file(path)
		if id == "":
			hud.toast("That model couldn’t be loaded.")
			return
		_add_char({"model": id}, {"label": path.get_file().get_basename().left(18), "group": "mobs"})
		if hud.view_stack.size() > 0:
			_rerender(), "Import a 3D model")


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
	b.add_child(UIK.btn("Edit placed objects", func():
		studio.tools.set_tool("objects", {"prop": ""})
		hud.close_sheet(), false, "pickI"))
	return "Objects"


# ---------------------------------------------------------------- cast

func v_cast(_a, b: VBoxContainer) -> String:
	for a in studio.actors:
		var row := Button.new()
		row.focus_mode = Control.FOCUS_NONE
		row.custom_minimum_size.y = UIK.px(64)
		row.add_theme_stylebox_override("normal", UIK.box(UIK.RAISE, 16, UIK.LINE))
		row.add_theme_stylebox_override("hover", UIK.box(UIK.RAISE_HI, 16, UIK.LINE))
		var h := UIK.hbox(12)
		h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		h.offset_left = UIK.px(8)
		h.offset_right = -UIK.px(10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tr := TextureRect.new()
		tr.texture = _look_icon(a.look)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.custom_minimum_size = Vector2(UIK.px(48), UIK.px(48))
		tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(tr)
		var v := UIK.vbox(0)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nl := UIK.label(a.name + ("  · you" if a == studio.player else ""), 16, UIK.INK, true)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(nl)
		var bl := UIK.label("Player" if a == studio.player else Styles.behavior_label(a.base_behavior), 13, UIK.MUTED)
		bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(bl)
		h.add_child(v)
		row.add_child(h)
		row.pressed.connect(func(): hud.push_view("actor", a.id))
		b.add_child(row)
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
	var tr := TextureRect.new()
	tr.texture = _look_icon(a.look)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.custom_minimum_size = Vector2(UIK.px(72), UIK.px(72))
	hero.add_child(tr)
	var name_edit := UIK.line_edit(a.name, "Name", func(t: String):
		a.name = t.strip_edges().left(24) if t.strip_edges() != "" else "Someone"
		a.refresh_tag()
		studio.mark_dirty())
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hero.add_child(name_edit)
	b.add_child(hero)
	if a != studio.player:
		_section(b, "What they do")
		var g := UIK.grid(3, 8)
		for beh in Styles.BEHAVIORS:
			var t := UIK.chip(beh[1], a.base_behavior == beh[0], func():
				a.set_behavior(beh[0])
				studio.capture_start()
				studio.mark_dirty()
				_rerender())
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_child(t)
		b.add_child(g)
		b.add_child(UIK.toggle("Notice the player (turn to look)", a.notice, func(on: bool): a.notice = on; studio.mark_dirty()))
	_section(b, "Lines (one per line, said when chatting)")
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
	r1.add_child(UIK.btn("Move", func():
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


# ---------------------------------------------------------------- script (timeline cues)

const CUE_ACTIONS := [["say", "Say"], ["walkto", "Walk to"], ["runto", "Run to"], ["idle", "Stand"], ["wander", "Wander"], ["talk", "Chat"], ["dance", "Dance"], ["wave", "Wave"], ["sit", "Sit"], ["follow", "Follow"], ["flee", "Run away"], ["gather", "Gather"]]


func v_script(_a, b: VBoxContainer) -> String:
	b.add_child(UIK.para("Simple mode: who does what, when. Play runs the script from the scene start; recording and film export follow it too.", 13))
	var top := UIK.hbox()
	top.add_child(UIK.btn("Play script", hud.play_script, true, "playtri"))
	top.add_child(UIK.btn("Set scene start here", func():
		studio.capture_start()
		studio.mark_dirty()
		hud.toast("Everyone’s current spot is now the scene start."), false, "pin"))
	b.add_child(top)
	var cues := studio.cues.duplicate()
	cues.sort_custom(func(x, y): return float(x.get("start", 0)) < float(y.get("start", 0)))
	_section(b, "Script (%d)" % cues.size())
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
	_section(b, "Add a line to the script")
	if new_cue["actor"] == "" or studio.actor_by_name(new_cue["actor"]) == null:
		new_cue["actor"] = studio.actors[0].name if not studio.actors.is_empty() else ""
	var who := UIK.flow()
	for a in studio.actors:
		who.add_child(UIK.chip(a.name, new_cue["actor"] == a.name, func(): new_cue["actor"] = a.name; _rerender()))
	b.add_child(who)
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
	b.add_child(UIK.btn("Add to script", _add_cue, true, "plus"))
	return "Script"


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
	_section(b, "Lens")
	b.add_child(UIK.slider("Field of view", App.settings["fov"], 25, 110, 1, func(x): App.settings["fov"] = x; studio.mark_dirty(), func(x): return "%d°" % int(x)))
	b.add_child(UIK.toggle("Depth of field (focus on the subject)", App.settings["dof"], func(on): App.settings["dof"] = on; studio.mark_dirty()))
	b.add_child(UIK.toggle("Handheld shake", App.settings["shake"], func(on): App.settings["shake"] = on; studio.mark_dirty()))
	_section(b, "Frame")
	var fr := UIK.flow()
	for f in [["full", "Full screen"], ["16:9", "16:9 wide"], ["9:16", "9:16 vertical"], ["1:1", "1:1 square"]]:
		fr.add_child(UIK.chip(f[1], App.settings["frame"] == f[0], func():
			App.settings["frame"] = f[0]
			hud.frame_guide.queue_redraw()
			studio.mark_dirty()
			_rerender()))
	b.add_child(fr)
	return "Camera"


# ---------------------------------------------------------------- mood

func v_mood(_a, b: VBoxContainer) -> String:
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
			studio.mark_dirty()
			_rerender())
		g.add_child(btn)
	b.add_child(g)
	_section(b, "Fine tune")
	b.add_child(UIK.slider("Time of day", App.settings["time"], 0, 24, 0.1, func(x):
		App.settings["time"] = x
		studio.atmo.apply()
		studio.mark_dirty(), func(x): return "%d:%02d" % [int(x), int(fmod(x, 1.0) * 60)]))
	b.add_child(UIK.toggle("Day and night cycle", App.settings["cycle"], func(on): App.settings["cycle"] = on; studio.mark_dirty()))
	var w := UIK.flow()
	for x in [["clear", "Clear"], ["rain", "Rain & storm"], ["snow", "Snow"]]:
		w.add_child(UIK.chip(x[1], App.settings["weather"] == x[0], func():
			App.settings["weather"] = x[0]
			studio.atmo.apply()
			studio.mark_dirty()
			_rerender()))
	b.add_child(w)
	b.add_child(UIK.slider("View distance (fog)", App.settings["fog"], 20, 200, 1, func(x):
		App.settings["fog"] = x
		studio.atmo.apply()
		studio.mark_dirty(), func(x): return "%dm" % int(x)))
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

const SHOT_TYPES := [["orbit", "Orbit"], ["dolly", "Dolly"], ["crane", "Crane"], ["push", "Push in"], ["path", "Path"], ["third", "Follow"], ["first", "First person"]]


func v_film(_a, b: VBoxContainer) -> String:
	var take := UIK.hbox()
	take.add_child(UIK.btn("Record a take", hud.toggle_record, true, "clap"))
	take.add_child(UIK.btn("Screenshot", hud.screenshot, false, "image"))
	b.add_child(take)
	b.add_child(UIK.para("A take records what you direct live, at a steady frame rate, without any editor controls.", 12))
	_section(b, "Shot list (%d shots, %s)" % [studio.shots.size(), U.fmt_time(_shots_len())])
	b.add_child(UIK.para("Export film replays the scene from its start and cuts between these shots — like a multi-camera shoot.", 12))
	for i in studio.shots.size():
		var s: Dictionary = studio.shots[i]
		var row := Button.new()
		row.focus_mode = Control.FOCUS_NONE
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size.y = UIK.px(52)
		var kind := str(s.get("shot", "orbit")) if s.get("mode", "cine") == "cine" else str(s.get("mode"))
		var tgt := str(s.get("target", ""))
		row.text = "%d.  %s   ·  %s%s  ·  %.1fs" % [i + 1, s.get("name", "Shot"), _shot_label(kind), (" on " + tgt) if tgt != "" else "", float(s.get("dur", 4))]
		row.add_theme_stylebox_override("normal", UIK.box(UIK.RAISE, 14, UIK.LINE))
		row.add_theme_stylebox_override("hover", UIK.box(UIK.RAISE_HI, 14, UIK.LINE))
		row.pressed.connect(func(): hud.push_view("shot", i))
		b.add_child(row)
	var sr := UIK.flow()
	sr.add_child(UIK.btn("Add shot", func():
		studio.shots.append({"name": "Shot %d" % (studio.shots.size() + 1), "mode": "cine", "shot": "orbit", "target": "", "dur": 4.0, "dist": 6.0, "height": 2.2})
		studio.mark_dirty()
		hud.push_view("shot", studio.shots.size() - 1), false, "plus"))
	sr.add_child(UIK.btn("Export film", func():
		if studio.export_film():
			hud.close_sheet()
			hud.show_progress("Exporting film"), true, "film"))
	b.add_child(sr)
	_section(b, "Output")
	var res := UIK.flow()
	for k in App.RES:
		res.add_child(UIK.chip(App.RES[k]["label"], str(App.settings["res"]) == k, func(): App.settings["res"] = k; studio.mark_dirty(); _rerender()))
	b.add_child(res)
	var fps := UIK.flow()
	for f in [24, 30, 60]:
		fps.add_child(UIK.chip("%d fps" % f, int(App.settings["fps"]) == f, func(): App.settings["fps"] = f; studio.mark_dirty(); _rerender()))
	b.add_child(fps)
	var fr := UIK.flow()
	for f in [["full", "Window"], ["16:9", "16:9"], ["9:16", "9:16 Shorts"], ["1:1", "1:1"]]:
		fr.add_child(UIK.chip(f[1], App.settings["frame"] == f[0], func():
			App.settings["frame"] = f[0]
			hud.frame_guide.queue_redraw()
			studio.mark_dirty()
			_rerender()))
	b.add_child(fr)
	var vs := hud.get_viewport_rect().size
	var sz := App.export_size(vs.x / vs.y)
	var enc := "H.264 MP4 (ffmpeg)" if Recorder.ffmpeg_path() != "" else "Motion-JPEG AVI (install ffmpeg for MP4)"
	b.add_child(UIK.para("%d × %d · %s" % [sz.x, sz.y, enc], 12))
	b.add_child(UIK.toggle("Burn in subtitles for dialogue", App.settings["subtitles"], func(on): App.settings["subtitles"] = on; studio.mark_dirty()))
	b.add_child(UIK.toggle("Restart cinematic shot when a take starts", App.settings["restart"], func(on): App.settings["restart"] = on))
	var cd := UIK.flow()
	for n in [0, 3, 5]:
		cd.add_child(UIK.chip("No countdown" if n == 0 else "%ds countdown" % n, int(App.settings["countdown"]) == n, func(): App.settings["countdown"] = n; _rerender()))
	b.add_child(cd)
	b.add_child(UIK.btn("Open videos folder", func(): OS.shell_open(Recorder.output_dir()), false, "folder"))
	return "Film"


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
			if st[0] in ["third", "first"]:
				s["mode"] = st[0]
			else:
				s["mode"] = "cine"
				s["shot"] = st[0]
			studio.mark_dirty()
			_rerender()))
	b.add_child(chips)
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
	r.add_child(UIK.btn("Preview", func():
		studio.apply_shot(s)
		hud.close_sheet(), false, "playtri"))
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
	_section(b, "Quality")
	var q := UIK.flow()
	for k in App.QUALITY:
		q.add_child(UIK.chip(App.QUALITY[k]["label"], App.device["quality"] == k, func():
			App.set_device("quality", k)
			studio.atmo.apply_quality()
			studio.atmo.apply()
			_rerender()))
	b.add_child(q)
	b.add_child(UIK.para("Cinematic adds global illumination bounce and 8K shadows; Battery saver suits older phones. Video export always renders at full quality.", 12))
	_section(b, "Controls")
	b.add_child(UIK.toggle("Show name tags", App.device["names"], func(on):
		App.set_device("names", on)
		for a in studio.actors:
			a.refresh_tag()))
	b.add_child(UIK.toggle("Auto-jump onto blocks", App.device["auto_jump"], func(on): App.set_device("auto_jump", on)))
	b.add_child(UIK.toggle("Lock the mouse to look around", App.device["mouse_look"] == "capture", func(on): App.set_device("mouse_look", "capture" if on else "drag")))
	b.add_child(UIK.toggle("Show frame rate", App.device["show_fps"], func(on): App.set_device("show_fps", on)))
	b.add_child(UIK.slider("Interface size", App.device["ui_scale"], 0.8, 1.6, 0.05, func(x): App.set_device("ui_scale", x), func(x): return "%d%%" % int(x * 100)))
	b.add_child(UIK.para("Interface size applies the next time you open the app.", 12))
	_section(b, "This scene")
	var r := UIK.flow()
	r.add_child(UIK.btn("Export scene file", func():
		await studio.save_now()
		hud.save_file(U.slug(studio.project_name) + ".gamescene.json", PackedStringArray(["*.json ; GameScene project"]), func(p: String):
			if ProjectStore.export_to(studio.project_id, p):
				hud.toast("Exported " + p.get_file())
			else:
				hud.toast("Couldn’t write that file.")), false, "download"))
	b.add_child(r)
	_section(b, "Keys")
	b.add_child(UIK.para("WASD move · Space jump · Shift walk · drag to look · wheel zoom · C camera · B build · R record · P screenshot · H clean view · Ctrl+Z undo · Esc close", 12))
	_section(b, "About")
	b.add_child(UIK.para("GameScene Studio %s — fully offline. Godot %s. Rendering: %s." % [ProjectSettings.get_setting("application/config/version"), Engine.get_version_info()["string"], RenderingServer.get_current_rendering_method()], 12))
	return "Settings"
