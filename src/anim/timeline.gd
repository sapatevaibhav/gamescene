class_name Timeline
extends RefCounted
## Keyframes for timeline mode: position and facing per character, and a
## camera track (position, rotation, field of view). Saved with the project as
##   {"cam": [{t, p, q, fov, e}], "<actor name>": [{t, p, yaw, e}]}
## Keys in each track are kept sorted by time. `e` is the easing into the
## next key: "s" (smooth in/out) or "l" (linear). A character key with
## `j: true` is a jump (set by director mode): the character is put there at
## that moment and is not walked towards it, so their behaviour runs before.

const CAM := "cam"
## Two keys closer than this count as the same moment.
const SAME_T := 0.05

var keys := {}


func clear() -> void:
	keys = {}


func load_data(d: Variant) -> void:
	keys = {}
	if not d is Dictionary:
		return
	for k in d:
		var arr: Array = d[k] if d[k] is Array else []
		var clean: Array = arr.filter(func(x): return x is Dictionary and x.has("t") and x.has("p"))
		if not clean.is_empty():
			clean.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
			keys[k] = clean


func to_data() -> Dictionary:
	return keys.duplicate(true)


func track(name: String) -> Array:
	return keys.get(name, [])


func has_track(name: String) -> bool:
	return not track(name).is_empty()


func length() -> float:
	var t := 0.0
	for k in keys:
		var arr: Array = keys[k]
		if not arr.is_empty():
			t = maxf(t, float(arr[-1]["t"]))
	return t


## Adds a key, replacing any key at (almost) the same time. Returns its index.
func set_key(name: String, key: Dictionary) -> int:
	var arr: Array = keys.get(name, [])
	var t: float = key["t"]
	for i in arr.size():
		if absf(float(arr[i]["t"]) - t) < SAME_T:
			arr[i] = key
			keys[name] = arr
			return i
	arr.append(key)
	arr.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	keys[name] = arr
	return arr.find(key)


func remove_key(name: String, i: int) -> void:
	var arr: Array = keys.get(name, [])
	if i < 0 or i >= arr.size():
		return
	arr.remove_at(i)
	if arr.is_empty():
		keys.erase(name)


## Moves a key in time and re-sorts the track. Returns the key's new index.
func move_key(name: String, i: int, t: float) -> int:
	var arr: Array = keys.get(name, [])
	if i < 0 or i >= arr.size():
		return i
	var key: Dictionary = arr[i]
	key["t"] = snappedf(maxf(0.0, t), 0.01)
	arr.sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))
	return arr.find(key)


func rename_track(old: String, new: String) -> void:
	if old == new or not keys.has(old) or keys.has(new):
		return
	keys[new] = keys[old]
	keys.erase(old)


func key_index_near(name: String, t: float, tol: float) -> int:
	var arr := track(name)
	var best := -1
	var bd := tol
	for i in arr.size():
		var d := absf(float(arr[i]["t"]) - t)
		if d <= bd:
			bd = d
			best = i
	return best


static func actor_key(t: float, a: Actor, jump := false) -> Dictionary:
	var k := {"t": snappedf(t, 0.01), "p": [U.r2(a.pos.x), U.r2(a.pos.y), U.r2(a.pos.z)], "yaw": snappedf(a.yaw, 0.001), "e": "l"}
	if jump:
		k["j"] = true
	return k


## Jump keys of a track with t0 < t <= t1 (the ones the clock just crossed).
func jumps_crossed(name: String, t0: float, t1: float) -> Array:
	return track(name).filter(func(k): return k.get("j", false) and float(k["t"]) > t0 and float(k["t"]) <= t1)


static func camera_key(t: float, cam: Camera3D) -> Dictionary:
	var q := cam.global_basis.get_rotation_quaternion()
	var p := cam.global_position
	return {"t": snappedf(t, 0.01), "p": [U.r2(p.x), U.r2(p.y), U.r2(p.z)],
		"q": [snappedf(q.x, 0.0001), snappedf(q.y, 0.0001), snappedf(q.z, 0.0001), snappedf(q.w, 0.0001)],
		"fov": snappedf(cam.fov, 0.1), "e": "s", "size": snappedf(cam.size, 0.01)}


static func _v(k: Dictionary) -> Vector3:
	var p: Array = k["p"]
	return Vector3(p[0], p[1], p[2])


static func _q(k: Dictionary) -> Quaternion:
	var q: Array = k.get("q", [0, 0, 0, 1])
	return Quaternion(q[0], q[1], q[2], q[3]).normalized()


## Finds the segment around `t`: [key_a, key_b, eased weight]. Holds the
## first/last key outside the keyed range.
static func _segment(arr: Array, t: float) -> Array:
	if t <= float(arr[0]["t"]):
		return [arr[0], arr[0], 0.0]
	if t >= float(arr[-1]["t"]):
		return [arr[-1], arr[-1], 0.0]
	for i in range(arr.size() - 1):
		var a: Dictionary = arr[i]
		var b: Dictionary = arr[i + 1]
		var ta: float = a["t"]
		var tb: float = b["t"]
		if t >= ta and t <= tb:
			var w := (t - ta) / maxf(tb - ta, 1e-4)
			if a.get("e", "l") == "s":
				w = U.ease_io(w)
			return [a, b, w]
	return [arr[-1], arr[-1], 0.0]


## Character pose at `t`, or {} when the track doesn't drive the character at
## that moment. A track drives its character from the scene start (moving
## from `start` towards the first key) until its last key, except on the way
## into a jump key, where the character is left to their behaviour.
func actor_pose(name: String, t: float, start: Dictionary) -> Dictionary:
	var arr := track(name)
	if arr.is_empty() or t > float(arr[-1]["t"]) + 1e-4:
		return {}
	var ka: Dictionary
	var kb: Dictionary
	var w: float
	if t < float(arr[0]["t"]):
		if start.is_empty() or arr[0].get("j", false):
			return {}
		ka = {"t": 0.0, "p": start["pos"], "yaw": start.get("yaw", 0.0)}
		kb = arr[0]
		w = t / maxf(float(kb["t"]), 1e-4)
	else:
		var seg := _segment(arr, t)
		ka = seg[0]
		kb = seg[1]
		w = seg[2]
		if kb != ka and kb.get("j", false):
			return {}
	return {"pos": _v(ka).lerp(_v(kb), w), "yaw": lerp_angle(float(ka.get("yaw", 0.0)), float(kb.get("yaw", 0.0)), w)}


## Camera transform at `t` (holds the first/last key outside the range).
func camera_pose(t: float) -> Dictionary:
	var arr := track(CAM)
	if arr.is_empty():
		return {}
	var seg := _segment(arr, t)
	var ka: Dictionary = seg[0]
	var kb: Dictionary = seg[1]
	var w: float = seg[2]
	return {"pos": _v(ka).lerp(_v(kb), w), "rot": _q(ka).slerp(_q(kb), w),
		"fov": lerpf(float(ka.get("fov", 70.0)), float(kb.get("fov", 70.0)), w),
		"size": lerpf(float(ka.get("size", 13.0)), float(kb.get("size", 13.0)), w)}
