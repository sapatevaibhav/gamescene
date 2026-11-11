class_name AnimLib
## The animation library: Mixamo-style clips (.fbx, .glb, .gltf) imported
## once and played on any imported humanoid character.
##
## A clip is stored rig-neutral, in character space (x right, y up, z
## forward): for each body slot (hips, spine, head, upper and lower arms and
## legs) its rotation away from the rest pose on every frame, the direction
## the bone points at rest, and how the hips move (as a fraction of the
## character's height). Playing it on another rig turns each of its bones by
## the same amount, after first lining the bone up with the source's rest
## direction, so a T-pose clip works on an A-pose character, and the bone
## naming and axes of either rig don't matter.
##
## Files: user://assets/anims/<id>.anim (Godot store_var), shared by scenes.
## Characters refer to clips as "<id>#<clip index>" in look["anims"], keyed
## by action ("idle", "walk", "dance", ...).

const EXTS := ["fbx", "glb", "gltf"]
const FPS := 30.0
## Body slots in parent-first order.
const SLOTS := ["hips", "spine", "head", "upperArmL", "lowerArmL", "upperArmR", "lowerArmR", "upperLegL", "lowerLegL", "upperLegR", "lowerLegR"]
const LIMBS := ["upperArmL", "lowerArmL", "upperArmR", "lowerArmR", "upperLegL", "lowerLegL", "upperLegR", "lowerLegR"]

static var DIR := "user://assets/anims/"
static var last_error := ""
static var _cache := {}


static func list() -> Array:
	if not DirAccess.dir_exists_absolute(DIR):
		return []
	var out := Array(DirAccess.get_files_at(DIR)).filter(func(f): return str(f).ends_with(".anim"))
	out.sort()
	return out.map(func(f): return str(f).get_basename())


static func load_lib(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var p := DIR + id + ".anim"
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	var d: Variant = f.get_var(false) if f else null
	var lib: Dictionary = d if d is Dictionary else {}
	_cache[id] = lib
	return lib


## Every clip in the library: [[key, name, seconds], ...].
static func all_clips() -> Array:
	var out := []
	for id in list():
		var lib := load_lib(id)
		var clips: Array = lib.get("clips", [])
		for i in clips.size():
			var c: Dictionary = clips[i]
			out.append(["%s#%d" % [id, i], str(c.get("name", "Clip")), float(c.get("frames", 1)) / FPS])
	return out


static func clip(key: String) -> Dictionary:
	var parts := key.split("#")
	if parts.size() != 2:
		return {}
	var clips: Array = load_lib(parts[0]).get("clips", [])
	var i := int(parts[1])
	return clips[i] if i >= 0 and i < clips.size() else {}


static func clip_name(key: String) -> String:
	return str(clip(key).get("name", "Missing clip"))


static func remove(id: String) -> void:
	_cache.erase(id)
	DirAccess.remove_absolute(DIR + id + ".anim")


# ---------------------------------------------------------------- import

## Imports every clip in an animation file; returns the library id or "".
static func import_file(path: String) -> String:
	last_error = ""
	var ext := path.get_extension().to_lower()
	if not ext in EXTS:
		last_error = "Use an .fbx, .glb or .gltf animation file."
		return ""
	var doc: GLTFDocument = FBXDocument.new() if ext == "fbx" else GLTFDocument.new()
	var state: GLTFState = FBXState.new() if ext == "fbx" else GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		last_error = "That file couldn’t be read."
		return ""
	var scene := doc.generate_scene(state) as Node3D
	if scene == null:
		last_error = "That file couldn’t be read."
		return ""
	var bytes := FileAccess.get_file_as_bytes(path)
	var id := U.slug(path.get_file().get_basename()) + "~%06x" % (hash(bytes.slice(0, mini(bytes.size(), 400000))) & 0xFFFFFF)
	var lib := sample(scene, path.get_file().get_basename())
	scene.free()
	if lib.is_empty():
		return ""
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(DIR + id + ".anim", FileAccess.WRITE)
	if f == null:
		last_error = "Couldn’t save the animation."
		return ""
	f.store_var(lib, false)
	f.close()
	_cache.erase(id)
	return id


## Samples every animation of a scene (with a skeleton and AnimationPlayer)
## into the rig-neutral form. The tracks are read directly and applied to
## the skeleton by hand, so this needs no scene tree.
static func sample(scene: Node3D, name: String) -> Dictionary:
	var sk := ModelRig._main_skeleton(scene)
	var ap := ModelRig._find(scene, "AnimationPlayer") as AnimationPlayer
	if sk == null:
		last_error = "That file has no skeleton."
		return {}
	if ap == null or ap.get_animation_list().is_empty():
		last_error = "That file has no animations."
		return {}
	var bones := ModelRig.find_bones(sk)
	if not (bones.has("hips") and bones.has("upperArmL") and bones.has("upperLegL")):
		last_error = "That skeleton doesn’t look like a person (no hips, arms or legs found)."
		return {}
	var bq := Kit._local_xf(scene, sk).basis.get_rotation_quaternion()
	var bs := Kit._local_xf(scene, sk).basis
	var height := maxf(ModelRig._bone_extent(scene, scene).size.y, 0.01)
	var rest_dir := {}
	var rest_q := {}
	for slot in SLOTS:
		if not bones.has(slot):
			continue
		var b: int = bones[slot]
		rest_q[slot] = bq * sk.get_bone_global_rest(b).basis.get_rotation_quaternion()
		rest_dir[slot] = _dir(sk, bones, slot, bs, true)
	var hips_rest: Vector3 = bs * sk.get_bone_global_rest(bones["hips"]).origin
	var clips := []
	for an in ap.get_animation_list():
		if String(an) == "RESET":
			continue
		var anim := ap.get_animation(an)
		# Bone tracks of the skeleton: [track, bone, type].
		var tracks := []
		for tr in anim.get_track_count():
			var tt := anim.track_get_type(tr)
			if not tt in [Animation.TYPE_ROTATION_3D, Animation.TYPE_POSITION_3D]:
				continue
			var path := anim.track_get_path(tr)
			if path.get_subname_count() == 0:
				continue
			var b := sk.find_bone(path.get_subname(0))
			if b >= 0:
				tracks.append([tr, b, tt])
		if tracks.is_empty():
			continue
		var n := maxi(2, int(ceil(anim.length * FPS)) + 1)
		var arrs := {}
		for slot in rest_q:
			arrs[slot] = PackedFloat32Array()
		var hips := PackedVector3Array()
		for fi in n:
			var t := minf(fi / FPS, anim.length)
			sk.reset_bone_poses()
			for e in tracks:
				if e[2] == Animation.TYPE_ROTATION_3D:
					sk.set_bone_pose_rotation(e[1], anim.rotation_track_interpolate(e[0], t))
				else:
					sk.set_bone_pose_position(e[1], anim.position_track_interpolate(e[0], t))
			var cache := {}
			for slot in rest_q:
				var g: Quaternion = bq * _gpose(sk, bones[slot], cache).basis.get_rotation_quaternion()
				var dq: Quaternion = (g * (rest_q[slot] as Quaternion).inverse()).normalized()
				var arr: PackedFloat32Array = arrs[slot]
				arr.append_array([dq.x, dq.y, dq.z, dq.w])
				arrs[slot] = arr
			hips.append((bs * _gpose(sk, bones["hips"], cache).origin - hips_rest) / height)
		clips.append({"name": _clip_label(String(an), name), "frames": n, "slots": arrs, "hips": hips})
	sk.reset_bone_poses()
	if clips.is_empty():
		last_error = "That file has no animations for its skeleton."
		return {}
	return {"name": name, "rest_dir": rest_dir, "clips": clips}


## A bone's pose in skeleton space, from the local poses up its parents
## (a skeleton outside the scene tree doesn't update its global poses).
static func _gpose(sk: Skeleton3D, b: int, cache: Dictionary) -> Transform3D:
	if cache.has(b):
		return cache[b]
	var p := sk.get_bone_parent(b)
	var g := sk.get_bone_pose(b) if p < 0 else _gpose(sk, p, cache) * sk.get_bone_pose(b)
	cache[b] = g
	return g


static func _clip_label(an: String, file: String) -> String:
	var s := an.get_slice("|", an.get_slice_count("|") - 1)
	if s.to_lower() in ["mixamo.com", "take 001", "take001", "animation", "default", ""]:
		s = file
	return s.replace("_", " ").strip_edges().capitalize().left(32)


## Rest direction of a slot's bone in character space: towards its main child
## (limbs), or straight up for the hips, spine and head.
static func _dir(sk: Skeleton3D, bones: Dictionary, slot: String, bs: Basis, _src: bool) -> Vector3:
	var b: int = bones[slot]
	var c := ModelRig._main_child(sk, b)
	if c < 0 or not slot in LIMBS:
		return Vector3.UP
	var d := bs * (sk.get_bone_global_rest(c).origin - sk.get_bone_global_rest(b).origin)
	return d.normalized() if d.length() > 1e-6 else Vector3.DOWN


# ---------------------------------------------------------------- playback

## Poses an imported character with a clip at time `t` (looping).
static func apply(a: Actor, key: String, t: float) -> bool:
	var c := clip(key)
	if c.is_empty():
		return false
	var lib := load_lib(key.get_slice("#", 0))
	var m := a.rig
	var sk: Skeleton3D = m.get("skel")
	if sk == null:
		return false
	var bones: Dictionary = m["bones"]
	var bt: Quaternion = m.get("char_q", Quaternion.IDENTITY)
	var bti := bt.inverse()
	var n := int(c["frames"])
	var ft := fposmod(t * FPS, float(maxi(n - 1, 1)))
	var i0 := int(floor(ft))
	var i1 := mini(i0 + 1, n - 1)
	var w := ft - i0
	# Line each target bone up with the source's rest direction once.
	var align: Dictionary = m.get("anim_align", {}).get(key, {})
	if align.is_empty():
		align = _alignment(m, sk, bones, lib.get("rest_dir", {}))
		if not m.has("anim_align"):
			m["anim_align"] = {}
		m["anim_align"][key] = align
	var slots: Dictionary = c["slots"]
	for slot in SLOTS:
		if not slots.has(slot) or not bones.has(slot):
			continue
		var arr: PackedFloat32Array = slots[slot]
		var q0 := Quaternion(arr[i0 * 4], arr[i0 * 4 + 1], arr[i0 * 4 + 2], arr[i0 * 4 + 3])
		var q1 := Quaternion(arr[i1 * 4], arr[i1 * 4 + 1], arr[i1 * 4 + 2], arr[i1 * 4 + 3])
		var dq := q0.slerp(q1, w)
		var b: int = bones[slot]
		var g0: Quaternion = bt * sk.get_bone_global_rest(b).basis.get_rotation_quaternion()
		var g: Quaternion = dq * (align.get(slot, Quaternion.IDENTITY) as Quaternion) * g0
		var g_sk := bti * g
		var p := sk.get_bone_parent(b)
		var pq := sk.get_bone_global_pose(p).basis.get_rotation_quaternion() if p >= 0 else Quaternion.IDENTITY
		sk.set_bone_pose_rotation(b, (pq.inverse() * g_sk).normalized())
	# Hips: move with the clip (up and down, and a little side to side).
	var hp: PackedVector3Array = c.get("hips", PackedVector3Array())
	if hp.size() == n and bones.has("hips"):
		var d := hp[i0].lerp(hp[i1], w)
		d.x = clampf(d.x, -0.15, 0.15)
		d.z = clampf(d.z, -0.15, 0.15)
		var hb: int = bones["hips"]
		var scale_sk: float = float(m.get("height", 1.75)) / maxf(float(m.get("skel_scale", 1.0)), 1e-5)
		var want: Vector3 = sk.get_bone_global_rest(hb).origin + (bti * d) * scale_sk
		var p := sk.get_bone_parent(hb)
		var pg := sk.get_bone_global_pose(p) if p >= 0 else Transform3D.IDENTITY
		sk.set_bone_pose_position(hb, pg.affine_inverse() * want)
	return true


## Per slot: the turn (in character space) that points the target's rest bone
## the way the source's rest bone points.
static func _alignment(m: Dictionary, sk: Skeleton3D, bones: Dictionary, src_dirs: Dictionary) -> Dictionary:
	var out := {}
	var bt: Quaternion = m.get("char_q", Quaternion.IDENTITY)
	var bs := Basis(bt)
	for slot in LIMBS:
		if not bones.has(slot) or not src_dirs.has(slot):
			continue
		var t_dir := _dir(sk, bones, slot, bs, false)
		var s_dir: Vector3 = src_dirs[slot]
		if t_dir.length() > 0.5 and s_dir.length() > 0.5 and t_dir.dot(s_dir) < 0.9999:
			out[slot] = Quaternion(t_dir.normalized(), s_dir.normalized())
	return out
