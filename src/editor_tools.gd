class_name EditorTools
extends Node3D
## World editing tools: blocks (place/break/pick), prefab buildings, objects
## (place/select/move/rotate/resize/delete), ground sculpting, camera-path
## points and moving actors. The HUD shows a toolbar for the active tool.

signal tool_changed

var studio: Studio
var kind := ""          # "", blocks, prefab, objects, terrain, move_actor, tiles, pprefab
var mode := "place"     # blocks: place | break | pick
var block := 1
var prefab := "cottage"
var rot := 0
var prop := ""          # object key to place
var sel: Dictionary = {}  # selected prop
var moving := false
var terra := "raise"
var actor_id := 0
## Pixel 2D: tile to paint, building to stamp (and mirrored or not).
var tile := 1
var pprefab := "cottage"
var flip := false
## Effect to place (effects tool): a SceneFx kind.
var effect := "fire"
## Objects / buildings tools (every world): "place" (Add) or "erase" (Remove).
var obj_mode := "place"
var _last_tile := Vector2i(-1, -1)
var _paint_button := MOUSE_BUTTON_LEFT
var painting := false
var paint_pos := Vector2.ZERO
var _ring: MeshInstance3D
var _ghost: MeshInstance3D


func _ready() -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = 0.92
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 4
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color("F2C14E")
	m.no_depth_test = true
	m.render_priority = 10
	_ring = MeshInstance3D.new()
	_ring.mesh = tm
	_ring.material_override = m
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.scale = Vector3(1, 0.05, 1)
	_ring.visible = false
	add_child(_ring)
	var bm := BoxMesh.new()
	bm.size = Vector3(1.02, 1.02, 1.02)
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_color = Color(1, 1, 1, 0.18)
	_ghost = MeshInstance3D.new()
	_ghost.mesh = bm
	_ghost.material_override = gm
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)


func set_tool(k: String, opts := {}) -> void:
	if kind == "terrain" and k != "terrain" and studio.world and not studio.world.is_voxel:
		studio.world.rebuild_grass()
	if studio.is_flat():
		# Pixel 2D builds with tiles; the 3D tools map onto them.
		k = {"blocks": "tiles", "prefab": "pprefab", "objects": "", "terrain": ""}.get(k, k)
	elif k in ["tiles", "pprefab"]:
		k = ""
	for key in opts:
		set(key, opts[key])
	if (opts.has("pprefab") or opts.has("prefab") or opts.has("prop") or opts.has("effect")) and not opts.has("obj_mode"):
		# Picking something to place switches back to placing.
		obj_mode = "place"
	# Keep the picked tile / building valid for this kind of world.
	if studio.is_top():
		if PixelTopWorld.obj_def(pprefab).is_empty():
			pprefab = "tree"
		if tile < 1 or (tile >= PixelTopArt.GROUND.size() and tile < TileSets.CUSTOM_BASE):
			tile = PixelTopArt.G["grass"]
	elif studio.is_side():
		if not PixelTiles.PREFABS.has(pprefab) and not SpriteImport.is_key(pprefab):
			pprefab = "cottage"
		if tile < 1 or (tile >= PixelTiles.count() and tile < TileSets.CUSTOM_BASE):
			tile = PixelTiles.ID["grass"]
	kind = k
	if k != "objects":
		sel = {}
		moving = false
	painting = false
	_ghost.visible = false
	_update_ring()
	tool_changed.emit()


func _ray(screen: Vector2) -> Array:
	var cam: Camera3D = studio.camera
	return [cam.project_ray_origin(screen), cam.project_ray_normal(screen)]


## Hover preview for block placement.
func hover(screen: Vector2) -> void:
	if kind in ["tiles", "pprefab"] and studio.is_flat():
		var rr := _ray(screen)
		var th: Dictionary = studio.world.ray(rr[0], rr[1], 200.0)
		_ghost.visible = not th.is_empty()
		if _ghost.visible:
			if studio.is_top():
				_ghost.scale = Vector3(1, 0.1, 1)
				_ghost.position = Vector3(int(th["x"]) + 0.5, 0.3, int(th["z"]) + 0.5)
			else:
				_ghost.scale = Vector3(1, 1, 0.1)
				_ghost.position = Vector3(int(th["x"]) + 0.5, int(th["y"]) + 0.5, PixelWorld.LANE - 0.5)
		return
	_ghost.scale = Vector3.ONE
	if kind != "blocks" or studio.world == null or not studio.world.is_voxel:
		_ghost.visible = false
		return
	var r := _ray(screen)
	var hit: Dictionary = studio.world.ray(r[0], r[1], 60.0)
	if hit.is_empty():
		_ghost.visible = false
		return
	var p := Vector3(hit["x"], hit["y"], hit["z"])
	if mode == "place":
		p += Vector3(hit["nx"], hit["ny"], hit["nz"])
		if hit.get("floor", false):
			p.y = 0
	_ghost.position = p + Vector3(0.5, 0.5, 0.5)
	_ghost.visible = true


## Handles a tap/click on the scene. Returns an actor id when an actor was
## tapped with no tool active (the HUD opens its sheet), else -1.
func tap(screen: Vector2, button := MOUSE_BUTTON_LEFT) -> int:
	var w = studio.world
	var r := _ray(screen)
	var o: Vector3 = r[0]
	var d: Vector3 = r[1]
	match kind:
		"tiles":
			_paint_tile(screen, button)
			return -1
		"pprefab":
			var ph: Dictionary = w.ray(o, d, 200.0)
			if ph.is_empty():
				return -1
			if obj_mode == "erase" or button == MOUSE_BUTTON_RIGHT:
				studio.checkpoint()
				if not _erase_at(ph):
					App.toast("Nothing to remove there.")
				studio.mark_dirty()
				return -1
			studio.checkpoint()
			if studio.is_top():
				var od := PixelTopWorld.obj_def(pprefab)
				if not w.place_object(pprefab, int(ph["x"]) - int(od.get("fw", 1)) / 2, int(ph["z"])):
					App.toast("Something’s already there.")
					return -1
			elif SpriteImport.is_key(pprefab):
				var sd := SpriteImport.object_def(pprefab)
				w.add_decor(pprefab, int(ph["x"]) - int(sd["fw"]) / 2, w.ground_y(float(ph["x"])))
			else:
				var rows: Array = PixelTiles.PREFABS[pprefab]["rows"]
				var wide: int = (rows[0] as String).length()
				w.stamp_prefab(pprefab, int(ph["x"]) - wide / 2, w.ground_y(float(ph["x"])), flip)
			_unstick_actors()
			studio.mark_dirty()
			return -1
		"blocks", "prefab":
			var hit: Dictionary = w.ray(o, d, 60.0)
			if hit.is_empty():
				return -1
			if kind == "prefab" and (obj_mode == "erase" or button == MOUSE_BUTTON_RIGHT):
				# Remove: the whole building or tree under the pointer.
				if hit.get("floor", false):
					return -1
				studio.checkpoint()
				if w.clear_structure(hit["x"], hit["y"], hit["z"]) == 0:
					App.toast("That’s the ground. Tap a building or tree.")
					return -1
				studio.mark_dirty()
				return -1
			if kind == "prefab":
				studio.checkpoint()
				w.stamp_prefab(prefab, hit["x"], 0 if hit.get("floor", false) else hit["y"] + 1, hit["z"], rot)
				_unstick_actors()
				studio.mark_dirty()
				return -1
			var m := "break" if button == MOUSE_BUTTON_RIGHT else ("pick" if button == MOUSE_BUTTON_MIDDLE else mode)
			if m == "break":
				if hit.get("floor", false):
					return -1
				studio.checkpoint()
				w.set_b(hit["x"], hit["y"], hit["z"], 0)
			elif m == "pick":
				if not hit.get("floor", false):
					block = hit["v"]
					mode = "place"
					tool_changed.emit()
				return -1
			else:
				var x: int = hit["x"] + hit["nx"]
				var y: int = 0 if hit.get("floor", false) else hit["y"] + hit["ny"]
				var z: int = hit["z"] + hit["nz"]
				if x < 0 or y < 0 or z < 0 or x >= VoxelWorld.WX or y >= VoxelWorld.WY or z >= VoxelWorld.WZ:
					return -1
				var b := Blocks.get_block(block)
				if _actor_overlaps(x, y, z) and not b.get("see", false):
					App.toast("Someone’s standing there.")
					return -1
				studio.checkpoint()
				w.set_b(x, y, z, block)
			studio.mark_dirty()
			return -1
		"objects":
			var hit: Dictionary = w.pick(o, d, 120.0)
			if hit.is_empty():
				return -1
			var p = hit.get("prop")
			var pt: Vector3 = hit["point"]
			if obj_mode == "erase" or button == MOUSE_BUTTON_RIGHT:
				# Remove: the object under the pointer.
				if p is Dictionary:
					sel = p
					delete_sel()
				else:
					App.toast("Tap an object to remove it.")
				return -1
			if p is Dictionary and not moving:
				sel = p
				_update_ring()
				tool_changed.emit()
				return -1
			var size := float(Styles.SIZE)
			if moving and not sel.is_empty():
				studio.checkpoint()
				sel["x"] = clampf(pt.x, 1, size - 1)
				sel["z"] = clampf(pt.z, 1, size - 1)
				w.update_prop(sel)
				moving = false
				_update_ring()
				studio.mark_dirty()
				tool_changed.emit()
				return -1
			if not sel.is_empty():
				sel = {}
				_update_ring()
				tool_changed.emit()
				return -1
			if prop != "" and pt.x > 0.5 and pt.z > 0.5 and pt.x < size - 0.5 and pt.z < size - 0.5:
				studio.checkpoint()
				var cam_p: Vector3 = studio.camera.global_position
				w.add_prop(prop, pt.x, pt.z, atan2(cam_p.x - pt.x, cam_p.z - pt.z), 1.0)
				_unstick_actors()
				studio.atmo.register_lights(w)
				studio.mark_dirty()
			return -1
		"effects":
			var hit: Dictionary = w.pick(o, d, 200.0)
			if hit.is_empty() or not hit.has("point"):
				return -1
			var pt: Vector3 = hit["point"]
			if obj_mode == "erase" or button == MOUSE_BUTTON_RIGHT:
				var i := studio.fx.index_near(pt, 1.8)
				if i < 0:
					App.toast("Tap an effect to remove it.")
					return -1
				studio.checkpoint()
				studio.fx.remove_at(i)
				studio.mark_dirty()
				return -1
			var size := float(Styles.SIZE)
			if pt.x < 0.5 or pt.z < 0.5 or pt.x > size - 0.5 or pt.z > size - 0.5:
				return -1
			studio.checkpoint()
			if not studio.is_flat() and (not w.is_voxel or int(hit.get("ny", 1)) != 1):
				pt.y = w.ground_at(pt.x, pt.z)
			studio.fx.add(effect, pt)
			studio.mark_dirty()
			return -1
		"move_actor":
			var hit: Dictionary = w.pick(o, d, 120.0)
			var a := studio.actor_by_id(actor_id)
			if hit.is_empty() or a == null:
				return -1
			var pt: Vector3 = hit["point"]
			var s := studio.find_spot(pt.x, pt.z)
			if studio.directing():
				# Director mode: they're put there from this moment on.
				studio.direct_move(a, Vector3(s.x, w.ground_at(s.x, s.y), s.y))
				set_tool("")
				App.toast("%s moves there at %s." % [a.name, U.fmt_time(studio.play_t)])
				return -1
			studio.checkpoint()
			a.pos = Vector3(s.x, w.ground_at(s.x, s.y), s.y)
			a.home = a.pos
			a.vel = Vector3.ZERO
			studio.capture_start()
			studio.mark_dirty()
			set_tool("")
			App.toast(a.name + " moved.")
			return -1
		"terrain":
			return -1
	return _actor_at(o, d)


## Pixel 2D: removes what's under the pointer. Top view: the object whose
## picture is there. Side view: the whole tree/building (connected tiles).
func _erase_at(hit: Dictionary) -> bool:
	var w = studio.world
	if studio.is_top():
		var i: int = w.object_at_point(hit["point"])
		if i < 0:
			return false
		w.remove_object(i)
		return true
	return w.clear_structure(int(hit["x"]), int(hit["y"])) > 0


## Pixel 2D: paints (or breaks, or picks) the tile under the pointer. Used
## for taps and while dragging; each tile is touched once per stroke.
func _paint_tile(screen: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	var w = studio.world
	var r := _ray(screen)
	var hit: Dictionary = w.ray(r[0], r[1], 200.0)
	if hit.is_empty():
		return
	var top := studio.is_top()
	var cell := Vector2i(int(hit["x"]), int(hit["z"] if top else hit["y"]))
	if cell == _last_tile:
		return
	_last_tile = cell
	var m := "break" if button == MOUSE_BUTTON_RIGHT else ("pick" if button == MOUSE_BUTTON_MIDDLE else mode)
	if top:
		# Top view: paint the ground; erasing removes an object first.
		match m:
			"pick":
				tile = int(hit["ground"])
				mode = "place"
				tool_changed.emit()
				return
			"break":
				var oi: int = w.object_at_point(hit["point"])
				if oi >= 0:
					w.remove_object(oi)
				else:
					w.set_ground(cell.x, cell.y, PixelTopArt.G["grass"])
			_:
				w.set_ground(cell.x, cell.y, tile)
		studio.mark_dirty()
		return
	if m == "break" and w.remove_decor_at(cell.x, cell.y):
		studio.mark_dirty()
		return
	match m:
		"pick":
			var id: int = hit["fg"] if int(hit["fg"]) != 0 else hit["bg"]
			if id != 0:
				tile = id
				mode = "place"
				tool_changed.emit()
			return
		"break":
			if int(hit["fg"]) == 0 and int(hit["bg"]) == 0:
				return
			w.set_tile(cell.x, cell.y, 0)
		_:
			if w.tile_solid(tile) and _actor_on_tile(cell):
				App.toast("Someone’s standing there.")
				return
			w.set_tile(cell.x, cell.y, tile)
	studio.mark_dirty()


func _erase_drag(screen: Vector2) -> void:
	var r := _ray(screen)
	var hit: Dictionary = studio.world.ray(r[0], r[1], 200.0)
	if not hit.is_empty() and _erase_at(hit):
		studio.mark_dirty()


func _actor_on_tile(c: Vector2i) -> bool:
	for a in studio.actors:
		if a.pos.x + PixelWorld.HW > c.x and a.pos.x - PixelWorld.HW < c.x + 1 and a.pos.y + PixelWorld.HH > c.y and a.pos.y < c.y + 1:
			return true
	return false


func _actor_at(o: Vector3, d: Vector3) -> int:
	var best := -1
	var bd := 1e9
	for a in studio.actors:
		if a.rig.is_empty():
			continue
		# Ray against a capsule-ish box around the actor.
		var h := a.height()
		var c := a.pos + Vector3(0, h * 0.5, 0)
		var bb := AABB(c - Vector3(0.4, h * 0.5, 0.4), Vector3(0.8, h, 0.8))
		var hit: Variant = bb.intersects_ray(o, d)
		if hit != null:
			var dist := o.distance_to(hit)
			if dist < bd:
				bd = dist
				best = a.id
	return best


func _actor_overlaps(x: int, y: int, z: int) -> bool:
	for a in studio.actors:
		if a.pos.x + Actor.HW > x and a.pos.x - Actor.HW < x + 1 and a.pos.z + Actor.HW > z and a.pos.z - Actor.HW < z + 1 and a.pos.y + Actor.HH > y and a.pos.y < y + 1:
			return true
	return false


func _unstick_actors() -> void:
	var w = studio.world
	for a in studio.actors:
		if w.body_blocked(a.pos):
			if w.is_voxel or w.get("is_side") == true:
				a.pos.y = w.ground_at(a.pos.x, a.pos.z)
			else:
				var s := studio.find_spot(a.pos.x, a.pos.z)
				a.pos.x = s.x
				a.pos.z = s.y


## Tools that act while dragged (ground sculpting, tile painting, erasing
## 2D objects).
func paints() -> bool:
	return kind in ["terrain", "tiles"] or (kind == "pprefab" and obj_mode == "erase")


func begin_paint(screen: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	if not paints():
		return
	studio.checkpoint()
	painting = true
	paint_pos = screen
	if kind == "tiles":
		_last_tile = Vector2i(-1, -1)
		_paint_button = button
		_paint_tile(screen, button)
	elif kind == "pprefab":
		_erase_drag(screen)


func paint(screen: Vector2) -> void:
	paint_pos = screen
	if painting and kind == "tiles":
		_paint_tile(screen, _paint_button)
	elif painting and kind == "pprefab":
		_erase_drag(screen)


func end_paint() -> void:
	if painting:
		painting = false
		studio.mark_dirty()


func _process(delta: float) -> void:
	if painting and kind == "terrain" and studio.world and not studio.world.is_voxel:
		var r := _ray(paint_pos)
		var hit: Dictionary = studio.world.pick(r[0], r[1], 150.0)
		if not hit.is_empty():
			var pt: Vector3 = hit["point"]
			studio.world.brush(pt.x, pt.z, terra, minf(delta, 0.05))
			for a in studio.actors:
				if Vector2(a.pos.x - pt.x, a.pos.z - pt.z).length() < 4.0:
					a.pos.y = studio.world.ground_at(a.pos.x, a.pos.z)
	if not sel.is_empty():
		_update_ring()


# ---------------------------------------------------------------- selection edits

func sel_name() -> String:
	if sel.is_empty():
		return ""
	return Props.display_name(studio.style_key, sel["key"])


func rotate_sel() -> void:
	if sel.is_empty():
		return
	studio.checkpoint()
	sel["rot"] = float(sel["rot"]) + PI / 4
	studio.world.update_prop(sel)
	studio.mark_dirty()


func resize_sel() -> void:
	if sel.is_empty():
		return
	studio.checkpoint()
	var sizes := [0.6, 0.8, 1.0, 1.25, 1.6, 2.0]
	var i := 0
	for k in sizes.size():
		if absf(sizes[k] - float(sel["s"])) < 0.05:
			i = k
	sel["s"] = sizes[(i + 1) % sizes.size()]
	studio.world.update_prop(sel)
	_unstick_actors()
	studio.mark_dirty()


func delete_sel() -> void:
	if sel.is_empty():
		return
	studio.checkpoint()
	studio.world.remove_prop(sel)
	sel = {}
	_update_ring()
	studio.atmo.register_lights(studio.world)
	studio.mark_dirty()
	tool_changed.emit()


func _update_ring() -> void:
	if sel.is_empty() or kind != "objects" or not is_instance_valid(sel.get("node")):
		_ring.visible = false
		return
	var node: Node3D = sel["node"]
	var r := maxf(float(sel["hw"]), float(sel["hd"])) * float(sel["s"]) + 0.35
	_ring.scale = Vector3(r, 0.05, r)
	_ring.position = Vector3(float(sel["x"]), node.global_position.y + 0.06, float(sel["z"]))
	_ring.visible = true
