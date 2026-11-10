class_name CameraRig
extends Camera3D
## Director's camera: third person, first person, free fly and cinematic shots
## (orbit, dolly, crane, push-in and user camera paths), plus shake and
## depth of field. Ported from the web `updateCamera` with the same maths.

const MODES := ["third", "first", "cine", "free"]
## Not in MODES (not cycled with C, not saved): "keys" follows the timeline's
## camera track at the scene clock.
const SHOTS := [["orbit", "Orbit"], ["dolly", "Dolly"], ["crane", "Crane"], ["push", "Push in"], ["path", "Camera path"]]

var studio: Node  # Studio
var mode := "third"
var yaw := PI
var pitch := 0.3
var dist := 6.0
var free_pos := Vector3(40, 14, 52)
## Cinematic state, saved with the project.
var cine := {"shot": "orbit", "dur": 12.0, "dist": 6.0, "height": 2.2, "points": [], "target": 0}
var cine_t := 0.0
var cine_base := 0.0
var _smooth := Vector3.ZERO
var _cine_init := false
var _shake_t := 0.0
var attrs := CameraAttributesPractical.new()

## Free-camera movement input set by the controller each frame.
var move_input := Vector2.ZERO
var up_input := 0.0


func _ready() -> void:
	near = 0.05
	far = 600.0
	attributes = attrs


func clamp_pitch() -> void:
	if mode == "third":
		pitch = clampf(pitch, -0.35, 1.35)
	else:
		pitch = clampf(pitch, -1.5, 1.5)


static func look_dir(y: float, p: float) -> Vector3:
	return Vector3(-sin(y) * cos(p), -sin(p), -cos(y) * cos(p))


func yaw_now() -> float:
	var d := -global_transform.basis.z
	return atan2(-d.x, -d.z)


func cine_target() -> Actor:
	var a: Actor = studio.actor_by_id(int(cine.get("target", 0)))
	return a if a else studio.player


func cine_reset() -> void:
	var a := cine_target()
	cine_t = 0.0
	cine_base = a.yaw if a else 0.0
	if a:
		_smooth = Vector3(a.pos.x, a.head_y() - 0.2, a.pos.z)
	_cine_init = true


func set_mode(m: String) -> void:
	if m == mode:
		return
	if m == "free":
		free_pos = global_position
		var d := -global_transform.basis.z
		yaw = yaw_now()
		pitch = -asin(clampf(d.y, -1, 1))
	if (m == "third" or m == "first") and mode == "free":
		yaw = yaw_now()
	mode = m
	clamp_pitch()
	if m == "cine":
		cine_reset()


func _clip(from: Vector3, dir: Vector3, d: float) -> float:
	if studio.world == null:
		return d
	return studio.world.clip_cam(from, dir, d)


func update_camera(dt: float) -> void:
	if studio.world and studio.world.get("is_side") == true:
		_update_side(dt)
		return
	if studio.world and studio.world.get("is_top") == true:
		_update_top(dt)
		return
	if projection != PROJECTION_PERSPECTIVE:
		projection = PROJECTION_PERSPECTIVE
	fov = App.settings["fov"]
	var player: Actor = studio.player
	var head := Vector3(Styles.SIZE / 2.0, 8, Styles.SIZE / 2.0)
	if player:
		head = Vector3(player.pos.x, player.head_y() - 0.1, player.pos.z)
		if player.swimming and mode == "third" and studio.world.has_method("water_surface"):
			# Orbit a point clear of the water, or the camera (which keeps out
			# of the water) would be pulled right up to the bobbing head.
			head.y = maxf(head.y, float(studio.world.water_surface(player.pos)) + 0.9)
	if mode == "first" and player == null:
		mode = "third"
	match mode:
		"third":
			var cp := cos(pitch)
			var off := Vector3(sin(yaw) * cp, sin(pitch), cos(yaw) * cp)
			global_position = head + off * _clip(head, off, dist)
			_look_at_safe(head)
		"first":
			global_position = Vector3(player.pos.x, player.head_y() + 0.05, player.pos.z)
			_look_at_safe(global_position + look_dir(yaw, pitch))
		"keys":
			var pose: Dictionary = studio.timeline.camera_pose(studio.play_t)
			if pose.is_empty():
				mode = "third"
			else:
				global_position = pose["pos"]
				global_basis = Basis(pose["rot"] as Quaternion)
				fov = pose["fov"]
		"free":
			var d := look_dir(yaw, pitch)
			var r := Vector3(cos(yaw), 0, -sin(yaw))
			var sp := 9.0 * dt
			free_pos += d * move_input.y * sp + r * move_input.x * sp
			free_pos.y += up_input * sp
			var size := float(Styles.SIZE)
			free_pos = free_pos.clamp(Vector3(-30, 0.3, -30), Vector3(size + 30, 80, size + 30))
			if studio.world and not studio.world.is_voxel:
				free_pos.y = maxf(free_pos.y, studio.world.ground_at(free_pos.x, free_pos.z) + 0.3)
			global_position = free_pos
			_look_at_safe(free_pos + d)
		_:
			_update_cine(dt)
	if App.settings["shake"]:
		_shake_t += dt
		var tt := _shake_t
		rotate_object_local(Vector3.RIGHT, sin(tt * 1.7) * 0.006 + sin(tt * 3.3) * 0.003)
		rotate_object_local(Vector3.UP, sin(tt * 1.3 + 1) * 0.006 + sin(tt * 2.9) * 0.002)
		rotate_object_local(Vector3.BACK, sin(tt * 0.9) * 0.004)
	_update_dof()


func _update_cine(dt: float) -> void:
	var a := cine_target()
	if not _cine_init:
		cine_reset()
	if a:
		_smooth = _smooth.lerp(Vector3(a.pos.x, a.head_y() - 0.2, a.pos.z), 1.0 - exp(-dt * 4.0))
	cine_t += dt
	var dur: float = maxf(1.0, float(cine["dur"]))
	var u := fmod(cine_t, dur) / dur
	var pp := u * 2.0 if u < 0.5 else 2.0 - u * 2.0
	var s := _smooth
	var r: float = cine["dist"]
	var h: float = cine["height"]
	var b := cine_base
	var f := Vector2(sin(b), cos(b))
	var sd := Vector2(cos(b), -sin(b))
	var shot: String = cine["shot"]
	var pts: Array = cine["points"]
	if shot == "path" and pts.size() >= 2:
		global_position = _path_point(pts, u)
		var seg := u * (pts.size() - 1)
		var i := mini(pts.size() - 2, int(floor(seg)))
		var q0 := _q(pts[i])
		var q1 := _q(pts[i + 1])
		global_basis = Basis(q0.slerp(q1, U.ease_io(clampf(seg - i, 0, 1))))
		return
	match shot:
		"dolly":
			var k := lerpf(-1, 1, U.ease_io(pp)) * r * 0.9
			global_position = Vector3(s.x + f.x * r + sd.x * k, s.y + h - 1, s.z + f.y * r + sd.y * k)
		"crane":
			var d := r * lerpf(1.1, 0.8, U.ease_io(pp))
			global_position = Vector3(s.x + f.x * d, s.y + lerpf(-0.8, h + 5, U.ease_io(pp)), s.z + f.y * d)
		"push":
			var d2 := lerpf(r * 1.6, 1.1, U.ease_io(pp))
			global_position = Vector3(s.x + f.x * d2, s.y + lerpf(h * 0.4, 0.15, U.ease_io(pp)), s.z + f.y * d2)
		_:
			var an := b + u * TAU
			global_position = Vector3(s.x + sin(an) * r, s.y + h - 1, s.z + cos(an) * r)
	var off := global_position - s
	var len := off.length()
	if len > 0.01:
		off /= len
		global_position = s + off * _clip(s, off, len)
	_look_at_safe(s)


# ---------------------------------------------------------------- Pixel 2D

## View height in metres for the side camera (zoom follows `dist`).
func side_size() -> float:
	return clampf(dist * 2.2, 4.0, 40.0)


## Pixel 2D: an orthographic camera looking straight at the tile plane.
## Follow tracks the player, free pans, cinematic shots pan, rise and zoom,
## and "keys" follows the timeline. The view snaps to the pixel grid so
## sprites don't shimmer.
func _update_side(dt: float) -> void:
	projection = PROJECTION_ORTHOGONAL
	attrs.dof_blur_far_enabled = false
	attrs.dof_blur_near_enabled = false
	var lane := PixelWorld.LANE
	var focus := Vector2(Styles.SIZE / 2.0, 16.0)
	var sz := side_size()
	match mode:
		"keys":
			var pose: Dictionary = studio.timeline.camera_pose(studio.play_t)
			if pose.is_empty():
				mode = "third"
			else:
				var pp: Vector3 = pose["pos"]
				focus = Vector2(pp.x, pp.y)
				sz = float(pose.get("size", sz))
		"free":
			var sp := 9.0 * dt * sz / 13.0
			free_pos += Vector3(move_input.x, move_input.y + up_input, 0) * sp
			focus = Vector2(free_pos.x, free_pos.y)
		"cine":
			var a := cine_target()
			if not _cine_init:
				cine_reset()
			if a:
				_smooth = _smooth.lerp(Vector3(a.pos.x, a.pos.y + 1.2, lane), 1.0 - exp(-dt * 4.0))
			cine_t += dt
			var dur: float = maxf(1.0, float(cine["dur"]))
			var u := fmod(cine_t, dur) / dur
			var pp := U.ease_io(u * 2.0 if u < 0.5 else 2.0 - u * 2.0)
			var r: float = cine["dist"]
			var h: float = cine["height"]
			focus = Vector2(_smooth.x, _smooth.y)
			sz = clampf(r * 2.0, 4.0, 40.0)
			var pts: Array = cine["points"]
			match str(cine["shot"]):
				"path":
					if pts.size() >= 2:
						var p3 := _path_point(pts, u)
						focus = Vector2(p3.x, p3.y)
				"dolly":
					focus.x += lerpf(-r, r, pp)
				"crane":
					focus.y += lerpf(-1.0, h + 4.0, pp)
				"push":
					sz = clampf(lerpf(r * 3.0, r * 0.9, pp), 3.0, 40.0)
				_:
					focus.x += sin(u * TAU) * r * 0.8
		_:
			var pl: Actor = studio.player
			if pl:
				# Frame a little above them: more sky, less dirt.
				var want := Vector3(pl.pos.x, pl.pos.y + 1.0 + sz * 0.14, lane)
				if _smooth.z != lane:
					_smooth = want
				_smooth = _smooth.lerp(want, 1.0 - exp(-dt * 6.0))
				focus = Vector2(_smooth.x, _smooth.y)
			if mode == "first":
				sz *= 0.6
	size = sz
	focus.y = clampf(focus.y, sz * 0.5 - 2.0, PixelWorld.H)
	var px := 1.0 / PixelWorld.PPM
	global_position = Vector3(snappedf(focus.x, px), snappedf(focus.y, px), lane + 30.0)
	global_basis = Basis.IDENTITY


## Jump the follow camera straight to `p` (after going through a door).
func snap_to(p: Vector3) -> void:
	_smooth = Vector3(p.x, 0.0, p.z)


## Pixel 2D top view: orthographic, straight down, north at the top of the
## screen. Same modes as the side view, moving over the ground instead.
func _update_top(dt: float) -> void:
	projection = PROJECTION_ORTHOGONAL
	attrs.dof_blur_far_enabled = false
	attrs.dof_blur_near_enabled = false
	yaw = 0.0
	var focus := Vector2(Styles.SIZE / 2.0, Styles.SIZE / 2.0)
	var sz := side_size()
	match mode:
		"keys":
			var pose: Dictionary = studio.timeline.camera_pose(studio.play_t)
			if pose.is_empty():
				mode = "third"
			else:
				var pp: Vector3 = pose["pos"]
				focus = Vector2(pp.x, pp.z)
				sz = float(pose.get("size", sz))
		"free":
			var sp := 9.0 * dt * sz / 13.0
			free_pos += Vector3(move_input.x, 0, -move_input.y) * sp
			focus = Vector2(free_pos.x, free_pos.z)
		"cine":
			var a := cine_target()
			if not _cine_init:
				cine_reset()
			if a:
				_smooth = _smooth.lerp(Vector3(a.pos.x, 0, a.pos.z), 1.0 - exp(-dt * 4.0))
			cine_t += dt
			var dur: float = maxf(1.0, float(cine["dur"]))
			var u := fmod(cine_t, dur) / dur
			var pp := U.ease_io(u * 2.0 if u < 0.5 else 2.0 - u * 2.0)
			var r: float = cine["dist"]
			focus = Vector2(_smooth.x, _smooth.z)
			sz = clampf(r * 2.0, 4.0, 40.0)
			var pts: Array = cine["points"]
			match str(cine["shot"]):
				"path":
					if pts.size() >= 2:
						var p3 := _path_point(pts, u)
						focus = Vector2(p3.x, p3.z)
				"dolly":
					focus.x += lerpf(-r, r, pp)
				"crane":
					sz = clampf(lerpf(r * 1.2, r * 3.2, pp), 3.0, 40.0)
				"push":
					sz = clampf(lerpf(r * 3.0, r * 0.9, pp), 3.0, 40.0)
				_:
					focus += Vector2(sin(u * TAU), cos(u * TAU)) * r * 0.6
		_:
			var pl: Actor = studio.player
			if pl:
				var want := Vector3(pl.pos.x, 0, pl.pos.z)
				if _smooth.y != 0.0 or _smooth.distance_to(want) > 30.0:
					_smooth = want
				_smooth = _smooth.lerp(want, 1.0 - exp(-dt * 6.0))
				focus = Vector2(_smooth.x, _smooth.z)
			if mode == "first":
				sz *= 0.6
	size = sz
	var px := 1.0 / PixelWorld.PPM
	global_position = Vector3(snappedf(focus.x, px), 60.0, snappedf(focus.y, px))
	global_basis = Basis(Vector3.RIGHT, -PI / 2)


func _q(p: Dictionary) -> Quaternion:
	var q: Array = p.get("q", [0, 0, 0, 1])
	return Quaternion(q[0], q[1], q[2], q[3]).normalized()


func _v(p: Dictionary) -> Vector3:
	var a: Array = p.get("p", [0, 0, 0])
	return Vector3(a[0], a[1], a[2])


## Centripetal Catmull-Rom through the path points (Three's CatmullRomCurve3).
func _path_point(pts: Array, t: float) -> Vector3:
	var n := pts.size()
	var p := (n - 1) * t
	var i := int(floor(p))
	var w := p - i
	if i >= n - 1:
		i = n - 2
		w = 1.0
	var p0 := _v(pts[i - 1]) if i > 0 else 2.0 * _v(pts[0]) - _v(pts[1])
	var p1 := _v(pts[i])
	var p2 := _v(pts[i + 1])
	var p3 := _v(pts[i + 2]) if i + 2 < n else 2.0 * _v(pts[n - 1]) - _v(pts[n - 2])
	var dt0 := pow(maxf(p0.distance_squared_to(p1), 1e-8), 0.25)
	var dt1 := pow(maxf(p1.distance_squared_to(p2), 1e-8), 0.25)
	var dt2 := pow(maxf(p2.distance_squared_to(p3), 1e-8), 0.25)
	if dt1 < 1e-4:
		dt1 = 1.0
	if dt0 < 1e-4:
		dt0 = dt1
	if dt2 < 1e-4:
		dt2 = dt1
	var t1 := ((p1 - p0) / dt0 - (p2 - p0) / (dt0 + dt1) + (p2 - p1) / dt1) * dt1
	var t2 := ((p2 - p1) / dt1 - (p3 - p1) / (dt1 + dt2) + (p3 - p2) / dt2) * dt1
	var w2 := w * w
	var w3 := w2 * w
	return (2 * w3 - 3 * w2 + 1) * p1 + (w3 - 2 * w2 + w) * t1 + (-2 * w3 + 3 * w2) * p2 + (w3 - w2) * t2


func add_path_point() -> void:
	var q := global_basis.get_rotation_quaternion()
	var p := global_position
	(cine["points"] as Array).append({"p": [U.r2(p.x), U.r2(p.y), U.r2(p.z)], "q": [snappedf(q.x, 0.0001), snappedf(q.y, 0.0001), snappedf(q.z, 0.0001), snappedf(q.w, 0.0001)]})


func _look_at_safe(target: Vector3) -> void:
	var d := target - global_position
	if d.length_squared() < 1e-6:
		return
	var up := Vector3.UP
	if absf(d.normalized().dot(up)) > 0.999:
		up = Vector3.BACK
	look_at(target, up)


func _update_dof() -> void:
	var on: bool = App.settings.get("dof", false)
	attrs.dof_blur_far_enabled = on
	attrs.dof_blur_near_enabled = on and mode != "first"
	if not on:
		return
	var focus := 6.0
	var a: Actor = cine_target() if mode == "cine" else studio.player
	if a:
		focus = global_position.distance_to(Vector3(a.pos.x, a.head_y(), a.pos.z))
	attrs.dof_blur_far_distance = focus + 3.0
	attrs.dof_blur_far_transition = maxf(4.0, focus)
	attrs.dof_blur_near_distance = maxf(0.3, focus * 0.45)
	attrs.dof_blur_near_transition = maxf(0.3, focus * 0.3)
	attrs.dof_blur_amount = 0.09


func to_dict() -> Dictionary:
	return {"mode": mode if MODES.has(mode) else "third", "yaw": yaw, "pitch": pitch, "dist": dist}


func cine_dict() -> Dictionary:
	return {"shot": cine["shot"], "dur": cine["dur"], "dist": cine["dist"], "height": cine["height"], "points": cine["points"]}


func load_view(v: Dictionary, c: Dictionary) -> void:
	mode = v.get("mode", "third")
	if not MODES.has(mode):
		mode = "third"
	yaw = v.get("yaw", PI)
	pitch = v.get("pitch", 0.3)
	dist = v.get("dist", 6.0)
	cine = {"shot": c.get("shot", "orbit"), "dur": float(c.get("dur", 12)), "dist": float(c.get("dist", 6)), "height": float(c.get("height", 2.2)), "points": c.get("points", []), "target": 0}
	_cine_init = false
