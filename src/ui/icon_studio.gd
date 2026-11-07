class_name IconStudio
extends SubViewport
## Renders thumbnails of characters and props off-screen, one per frame, into
## textures the UI can show immediately (they fill in when ready).

var _queue: Array = []
var _cache := {}
var _cam := Camera3D.new()
var _stage := Node3D.new()
var _busy := false


func _ready() -> void:
	own_world_3d = true
	transparent_bg = true
	size = Vector2i(160, 160)
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.82, 0.9)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38, 35, 0)
	key.light_energy = 1.25
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 200, 0)
	rim.light_energy = 0.5
	add_child(rim)
	_cam.fov = 30
	add_child(_cam)
	add_child(_stage)


## Returns a texture for `key`, building it with `builder` (returns Node3D)
## on a later frame. `kind` "char" frames the face+body, "prop" the whole.
func request(key: String, builder: Callable, kind := "char") -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0.06))
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	_queue.append([tex, builder, kind])
	if not _busy:
		_pump()
	return tex


func _pump() -> void:
	_busy = true
	while not _queue.is_empty():
		var job: Array = _queue.pop_front()
		var node: Node3D = job[1].call()
		if node == null:
			continue
		_stage.add_child(node)
		_frame(node, job[2])
		render_target_update_mode = SubViewport.UPDATE_ONCE
		if DisplayServer.get_name() == "headless":
			_stage.remove_child(node)
			node.queue_free()
			continue
		await RenderingServer.frame_post_draw
		var img := get_texture().get_image()
		if img:
			(job[0] as ImageTexture).set_image(img)
		_stage.remove_child(node)
		node.queue_free()
	_busy = false


func _frame(node: Node3D, kind: String) -> void:
	var bb := Kit.bounds(node)
	# Characters carry their real height/head height (skinned mesh bounds lie).
	if node.has_meta("frame_h"):
		var fh: float = node.get_meta("frame_h")
		bb = AABB(Vector3(-fh * 0.22, 0, -fh * 0.15), Vector3(fh * 0.44, fh, fh * 0.3))
	if bb.size == Vector3.ZERO:
		bb = AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 1.8, 1))
	var c := bb.get_center()
	var r := bb.size.length() * 0.5
	var dir := Vector3(0.55, 0.32, 1.0).normalized()
	if kind == "face":
		# Head-and-shoulders portrait.
		var fh2: float = node.get_meta("frame_h", bb.size.y)
		var hh: float = node.get_meta("head_h", fh2 * 0.88)
		var head_r := maxf(fh2 - hh, fh2 * 0.07)
		c = Vector3(0, hh - head_r * 0.15, 0)
		r = head_r * 2.0
		dir = Vector3(0.18, 0.05, 1.0).normalized()
	elif kind == "char":
		# Favour the upper body so faces read at small sizes.
		c.y = bb.position.y + bb.size.y * 0.6
		r = maxf(bb.size.y * 0.48, maxf(bb.size.x, bb.size.z) * 0.6)
		dir = Vector3(0.35, 0.12, 1.0).normalized()
	var d := r / sin(deg_to_rad(_cam.fov * 0.5)) * 0.95
	_cam.look_at_from_position(c + dir * d, c, Vector3.UP)
	_cam.near = maxf(0.01, d - r * 3)
	_cam.far = d + r * 3


func clear() -> void:
	_cache.clear()
