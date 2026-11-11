class_name SpringRig
extends RefCounted
## Spring bones: hair, skirts, tails, capes and ribbons on imported characters
## sway, lag behind when the character moves and settle back.
##
## Chains come from bone names (VRoid's "J_Sec_*" secondary bones, "hair",
## "skirt", "tail", MMD 髪 / スカート ...). Each joint follows the VRM spring
## model: its tail keeps its momentum (less drag), is pulled back towards its
## rest direction (stiffness) and down (gravity), stays at its length, and is
## pushed out of spheres on the head, chest, hips and thighs.
##
## It runs in Actor.animate with the scene's time step, so takes and resumed
## exports play out exactly the same (Godot's own SpringBoneSimulator3D steps
## on engine frames, which a replay doesn't have).

const WORDS := ["j_sec", "hair", "skirt", "sleeve", "ribbon", "tail", "cape", "cloak", "scarf", "ponytail", "twintail", "braid", "bang", "tassel",
	"sash", "coat", "hood", "cloth", "kami", "ahoge", "髪", "スカート", "リボン", "尻尾", "マント"]
## Body bones are never springs, even when their names contain a word above.
const BODY := ["arm", "leg", "spine", "chest", "neck", "hand", "foot", "finger", "thumb", "toe", "eye", "jaw", "tongue", "hips", "pelvis", "shoulder", "clavicle", "head_"]
const MAX_JOINTS := 128

var sk: Skeleton3D
## Each joint: {b, parent, tail_local, len, stiff, drag, grav, r, cur, prev}.
var joints: Array = []
## Collision spheres: [[bone, offset_local(skeleton space), radius_factor]].
var spheres: Array = []
var _fresh := true


static func is_spring_name(name: String) -> bool:
	var n := name.to_lower()
	var hit := false
	for w in WORDS:
		if n.contains(w):
			hit = true
			break
	if not hit:
		return false
	if n.contains("j_sec"):
		return true
	for b in BODY:
		if n.contains(b):
			return false
	return true


## Face bones under the head are never hair.
const FACE := ["eye", "jaw", "tongue", "teeth", "tooth", "mouth", "brow", "lid", "cheek", "lip", "nose", "ear"]


## Finds the spring chains of a skeleton; null when there are none.
static func build(skel: Skeleton3D, bones: Dictionary) -> SpringRig:
	var spring := {}
	for b in skel.get_bone_count():
		if is_spring_name(skel.get_bone_name(b)):
			spring[b] = true
	_by_shape(skel, bones, spring)
	if spring.is_empty():
		return null
	var s := SpringRig.new()
	s.sk = skel
	# Joints in parent-first order (bone order in a skeleton is parent-first).
	for b in skel.get_bone_count():
		if not spring.has(b) or s.joints.size() >= MAX_JOINTS:
			continue
		var kids := Array(skel.get_bone_children(b)).filter(func(c): return spring.has(c))
		var tail := Vector3.ZERO
		if kids.size() >= 1:
			# Tail towards the (first) child joint.
			tail = skel.get_bone_rest(kids[0]).origin
		else:
			# Last joint: a virtual tail continuing the chain's direction.
			var p := skel.get_bone_parent(b)
			var along := skel.get_bone_rest(b).origin
			tail = skel.get_bone_rest(b).basis.inverse() * along * 0.7 if p >= 0 and along.length() > 1e-5 else Vector3(0, 0.05, 0)
		if tail.length() < 1e-5:
			continue
		var n := skel.get_bone_name(b).to_lower()
		var skirt := n.contains("skirt") or n.contains("スカート") or n.contains("cape") or n.contains("cloak") or n.contains("coat")
		var tailish := n.contains("tail") or n.contains("尻尾")
		s.joints.append({"b": b, "parent": skel.get_bone_parent(b), "tail_local": tail, "len": tail.length(),
			"stiff": 2.0 if skirt else (1.0 if tailish else 1.5), "drag": 0.55 if skirt else 0.45, "grav": 0.25 if skirt else 0.15,
			"r": 0.035 if skirt else 0.02})
	if s.joints.is_empty():
		return null
	# Keep hair out of the head and body, skirts out of the legs.
	for slot in ["head", "spine", "hips", "upperLegL", "upperLegR"]:
		if bones.has(slot):
			var b: int = bones[slot]
			var off := Vector3.ZERO
			var c := ModelRig._main_child(skel, b)
			if c >= 0:
				off = skel.get_bone_rest(c).origin * (0.5 if slot != "hips" else 0.2)
			s.spheres.append([b, off, {"head": 0.065, "spine": 0.085, "hips": 0.08, "upperLegL": 0.05, "upperLegR": 0.05}[slot]])
	return s


## Rigs with meaningless bone names (converted MMD models, "HB1_3_2"...):
## chains of 3 or more bones hanging off the head (not face bones) are hair,
## and off the torso (not leading to an arm or leg) are skirts or ribbons.
static func _by_shape(skel: Skeleton3D, bones: Dictionary, spring: Dictionary) -> void:
	if not bones.has("head") or not bones.has("hips"):
		return
	var limbs := {}
	for slot in ["upperArmL", "upperArmR", "upperLegL", "upperLegR"]:
		if bones.has(slot):
			limbs[bones[slot]] = true
	# The torso: from the head up to the hips.
	var torso := {}
	var b: int = bones["head"]
	while b >= 0:
		torso[b] = true
		if b == bones["hips"]:
			break
		b = skel.get_bone_parent(b)
	for t in torso:
		for c in skel.get_bone_children(t):
			if torso.has(c) or _holds(skel, c, limbs) or _face(skel.get_bone_name(c)):
				continue
			if _depth(skel, c) >= 3:
				_mark(skel, c, spring)


static func _holds(skel: Skeleton3D, b: int, set: Dictionary) -> bool:
	if set.has(b):
		return true
	for c in skel.get_bone_children(b):
		if _holds(skel, c, set):
			return true
	return false


static func _depth(skel: Skeleton3D, b: int) -> int:
	var d := 0
	for c in skel.get_bone_children(b):
		d = maxi(d, _depth(skel, c))
	return d + 1


static func _face(name: String) -> bool:
	var n := name.to_lower()
	for w in FACE:
		if n.contains(w):
			return true
	return false


static func _mark(skel: Skeleton3D, b: int, spring: Dictionary) -> void:
	if _face(skel.get_bone_name(b)):
		return
	spring[b] = true
	for c in skel.get_bone_children(b):
		_mark(skel, c, spring)


## Back to rest: tails where the bones point now (after a jump or a reset).
func reset() -> void:
	_fresh = true


## One step of `dt` seconds; `h` is the character's height in metres (sizes
## of the collision spheres). Call after the body pose is set.
func step(dt: float, h: float) -> void:
	if not is_instance_valid(sk) or not sk.is_inside_tree():
		return
	var xf := sk.global_transform
	var scale := xf.basis.get_scale().x
	var inv := xf.affine_inverse()
	var balls := []
	for sp in spheres:
		var g := sk.get_bone_global_pose(int(sp[0]))
		balls.append([xf * (g * (sp[1] as Vector3)), float(sp[2]) * h])
	var grav := Vector3.DOWN
	for j in joints:
		var b: int = j["b"]
		var pg := sk.get_bone_global_pose(int(j["parent"])) if int(j["parent"]) >= 0 else Transform3D.IDENTITY
		var rest := sk.get_bone_rest(b)
		var head_sk := pg * rest.origin
		var rot0 := pg.basis.orthonormalized() * rest.basis.orthonormalized()
		var dir0 := (rot0 * (j["tail_local"] as Vector3)).normalized()
		var length := float(j["len"]) * (pg.basis.get_scale().x if pg != Transform3D.IDENTITY else 1.0) * scale
		var head := xf * head_sk
		var rest_tail := head + (xf.basis.orthonormalized() * dir0) * length
		if _fresh or not j.has("cur"):
			j["cur"] = rest_tail
			j["prev"] = rest_tail
		var cur: Vector3 = j["cur"]
		var prev: Vector3 = j["prev"]
		var nxt := cur + (cur - prev) * (1.0 - float(j["drag"])) \
			+ (xf.basis.orthonormalized() * dir0) * float(j["stiff"]) * dt \
			+ grav * float(j["grav"]) * dt
		nxt = head + (nxt - head).normalized() * length
		var jr := float(j["r"]) * h * 0.5
		for ball in balls:
			var c: Vector3 = ball[0]
			var r: float = ball[1] + jr
			var d := nxt - c
			if d.length() < r and d.length() > 1e-6:
				nxt = c + d.normalized() * r
				nxt = head + (nxt - head).normalized() * length
		# Never more than 65° from where it hangs at rest: hair sways and
		# trails, it doesn't fly out sideways.
		var rest_dir := (rest_tail - head).normalized()
		var now_dir := (nxt - head).normalized()
		var ang := rest_dir.angle_to(now_dir)
		if ang > deg_to_rad(65):
			var axis := rest_dir.cross(now_dir)
			if axis.length() > 1e-6:
				nxt = head + rest_dir.rotated(axis.normalized(), deg_to_rad(65)) * length
		j["prev"] = cur
		j["cur"] = nxt
		# Turn the bone so its tail points at the simulated tail.
		var want := (inv.basis.orthonormalized() * (nxt - head)).normalized()
		var q := Quaternion(dir0, want) * rot0.get_rotation_quaternion()
		var local := pg.basis.orthonormalized().get_rotation_quaternion().inverse() * q if int(j["parent"]) >= 0 else q
		sk.set_bone_pose_rotation(b, local.normalized())
	_fresh = false
