extends RefCounted
## Test models made in code (no files from anyone's library): a small
## humanoid with a skinned mesh, saved as .glb. Options pick the bone names
## (Mixamo or VRoid), T-pose or A-pose, rolled bone axes, a Z-up armature,
## a hair strand, face shapes and a "Wave" clip.
##   const Fx := preload("res://tests/fixtures.gd")

const MIXAMO := {"hips": "mixamorig_Hips", "spine": "mixamorig_Spine", "head": "mixamorig_Head",
	"upperArmL": "mixamorig_LeftArm", "lowerArmL": "mixamorig_LeftForeArm", "handL": "mixamorig_LeftHand",
	"upperArmR": "mixamorig_RightArm", "lowerArmR": "mixamorig_RightForeArm", "handR": "mixamorig_RightHand",
	"upperLegL": "mixamorig_LeftUpLeg", "lowerLegL": "mixamorig_LeftLeg", "footL": "mixamorig_LeftFoot",
	"upperLegR": "mixamorig_RightUpLeg", "lowerLegR": "mixamorig_RightLeg", "footR": "mixamorig_RightFoot"}
const VROID := {"hips": "J_Bip_C_Hips", "spine": "J_Bip_C_Spine", "head": "J_Bip_C_Head",
	"upperArmL": "J_Bip_L_UpperArm", "lowerArmL": "J_Bip_L_LowerArm", "handL": "J_Bip_L_Hand",
	"upperArmR": "J_Bip_R_UpperArm", "lowerArmR": "J_Bip_R_LowerArm", "handR": "J_Bip_R_Hand",
	"upperLegL": "J_Bip_L_UpperLeg", "lowerLegL": "J_Bip_L_LowerLeg", "footL": "J_Bip_L_Foot",
	"upperLegR": "J_Bip_R_UpperLeg", "lowerLegR": "J_Bip_R_LowerLeg", "footR": "J_Bip_R_Foot"}

## [slot, parent slot, position in character space (metres, +Z forward,
## left = +X), in T-pose].
const LAYOUT := [
	["hips", "", Vector3(0, 1.0, 0)],
	["spine", "hips", Vector3(0, 1.25, 0)],
	["head", "spine", Vector3(0, 1.62, 0)],
	["upperArmL", "spine", Vector3(0.2, 1.45, 0)],
	["lowerArmL", "upperArmL", Vector3(0.48, 1.45, 0)],
	["handL", "lowerArmL", Vector3(0.74, 1.45, 0)],
	["upperArmR", "spine", Vector3(-0.2, 1.45, 0)],
	["lowerArmR", "upperArmR", Vector3(-0.48, 1.45, 0)],
	["handR", "lowerArmR", Vector3(-0.74, 1.45, 0)],
	["upperLegL", "hips", Vector3(0.1, 0.95, 0)],
	["lowerLegL", "upperLegL", Vector3(0.1, 0.5, 0)],
	["footL", "lowerLegL", Vector3(0.1, 0.06, 0)],
	["upperLegR", "hips", Vector3(-0.1, 0.95, 0)],
	["lowerLegR", "upperLegR", Vector3(-0.1, 0.5, 0)],
	["footR", "lowerLegR", Vector3(-0.1, 0.06, 0)],
]


## Character-space positions, with the arms hanging 40° down for an A-pose.
static func positions(a_pose: bool) -> Dictionary:
	var p := {}
	for row in LAYOUT:
		p[row[0]] = row[2]
	if a_pose:
		for side in ["L", "R"]:
			var sh: Vector3 = p["upperArm" + side]
			var s := 1.0 if side == "L" else -1.0
			var dir := Vector3(s * cos(deg_to_rad(40)), -sin(deg_to_rad(40)), 0)
			p["lowerArm" + side] = sh + dir * 0.28
			p["hand" + side] = sh + dir * 0.54
	return p


## Builds the model. opts: names (MIXAMO/VROID), a_pose, roll, z_up, hair,
## shapes (Array of blend shape names), wave (adds the clip).
static func build(opts: Dictionary) -> Node3D:
	var names: Dictionary = opts.get("names", MIXAMO)
	var pos := positions(opts.get("a_pose", false))
	var root := Node3D.new()
	root.name = "Model"
	var arm := Node3D.new()
	arm.name = "Armature"
	root.add_child(arm)
	# Z-up armature (Blender style): the node turns it upright.
	var ba := Basis(Vector3.RIGHT, -PI / 2) if opts.get("z_up", false) else Basis.IDENTITY
	arm.basis = ba
	var bai := ba.inverse()
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	arm.add_child(sk)
	# Global rest transforms in skeleton space; rolled axes make every bone's
	# local frame different from the character's.
	var glob := {}
	var idx := {}
	var rows: Array = LAYOUT.duplicate()
	if opts.get("hair", false):
		rows += [["hair1", "head", Vector3(0, 1.72, -0.08)], ["hair2", "hair1", Vector3(0, 1.62, -0.12)], ["hair3", "hair2", Vector3(0, 1.52, -0.14)]]
		pos["hair1"] = Vector3(0, 1.72, -0.08)
		pos["hair2"] = Vector3(0, 1.62, -0.12)
		pos["hair3"] = Vector3(0, 1.52, -0.14)
	var k := 0
	for row in rows:
		var slot: String = row[0]
		var nm: String = names.get(slot, "J_Sec_Hair1_0%s" % slot.substr(4) if slot.begins_with("hair") else slot)
		var b := sk.get_bone_count()
		sk.add_bone(nm)
		idx[slot] = b
		var roll := Basis(Vector3(0.3, 1, 0.2).normalized(), 0.7 * k) if opts.get("roll", false) else Basis.IDENTITY
		glob[slot] = Transform3D(bai * roll, bai * (pos[slot] as Vector3))
		var parent: String = row[1]
		if parent != "":
			sk.set_bone_parent(b, idx[parent])
			sk.set_bone_rest(b, (glob[parent] as Transform3D).affine_inverse() * glob[slot])
		else:
			sk.set_bone_rest(b, glob[slot])
		k += 1
	sk.reset_bone_poses()
	# A skinned mesh: a little pyramid at every bone, bound to it.
	var verts := PackedVector3Array()
	var bones_arr := PackedInt32Array()
	var weights := PackedFloat32Array()
	for slot in idx:
		var o: Vector3 = (glob[slot] as Transform3D).origin
		for d in [Vector3(0.02, 0, 0), Vector3(-0.02, 0, 0.02), Vector3(0, 0.03, -0.02)]:
			verts.append(o + d)
			bones_arr.append_array([idx[slot], 0, 0, 0])
			weights.append_array([1.0, 0, 0, 0])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_BONES] = bones_arr
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var am := ArrayMesh.new()
	var shapes: Array = opts.get("shapes", [])
	var blends := []
	for sname in shapes:
		am.add_blend_shape(sname)
		var ba2 := []
		ba2.resize(Mesh.ARRAY_MAX)
		var moved := PackedVector3Array()
		for v in verts:
			moved.append(v + Vector3(0, 0.005, 0))
		ba2[Mesh.ARRAY_VERTEX] = moved
		blends.append(ba2)
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, blends)
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = am
	sk.add_child(mi)
	mi.skeleton = NodePath("..")
	mi.skin = sk.create_skin_from_rest_transforms()
	if opts.get("wave", false):
		root.add_child(_wave_player(sk, idx, glob, ba))
	return root


## "Wave": the right arm swings from out to the side (T-pose) to straight
## up over one second, with the forearm following.
static func _wave_player(sk: Skeleton3D, idx: Dictionary, glob: Dictionary, ba: Basis) -> AnimationPlayer:
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	var anim := Animation.new()
	anim.length = 1.0
	# Turn about the character's forward axis, in skeleton space.
	var delta := Quaternion(ba.inverse() * Vector3(0, 0, 1), -PI / 2)
	for slot in ["upperArmR", "lowerArmR"]:
		var b: int = idx[slot]
		var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(tr, NodePath("Armature/Skeleton3D:" + sk.get_bone_name(b)))
		var rest_q := sk.get_bone_rest(b).basis.get_rotation_quaternion()
		anim.rotation_track_insert_key(tr, 0.0, rest_q)
		# Upper arm: the whole turn; forearm: none relative to its parent.
		var g0: Quaternion = (glob[slot] as Transform3D).basis.get_rotation_quaternion()
		var p := sk.get_bone_parent(b)
		var pg0: Quaternion = sk.get_bone_global_rest(p).basis.get_rotation_quaternion()
		var pg1: Quaternion = (delta * pg0) if slot == "lowerArmR" else pg0
		var g1: Quaternion = delta * g0
		anim.rotation_track_insert_key(tr, 1.0, (pg1.inverse() * g1).normalized())
	var lib := AnimationLibrary.new()
	lib.add_animation("Wave", anim)
	ap.add_animation_library("", lib)
	return ap


## Saves a model to `path` (.glb); returns OK or an error.
static func save(model: Node3D, path: String) -> int:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_scene(model, st)
	if err == OK:
		err = doc.write_to_filesystem(st, path)
	model.free()
	return err
