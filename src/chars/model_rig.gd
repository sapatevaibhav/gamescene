class_name ModelRig
## Imported .glb / .vrm characters. Models are copied into user://assets/models
## and referenced by id from look.model, so projects stay portable. If the file
## carries animation clips they are matched by name (idle, walk, run, dance...);
## otherwise humanoid bones are swung procedurally.

## Imported character files. Tests point this at a scratch folder.
static var DIR := "user://assets/models/"
const CLIP_PATTERNS := {
	"idle": ["idle", "stand", "breath"], "walk": ["walk"], "run": ["run", "sprint", "jog"], "dance": ["dance"],
	"wave": ["wave", "hello", "greet"], "sit": ["sit"], "jump": ["jump"], "talk": ["talk", "speak"],
	"sleep": ["sleep", "lie", "lying", "laydown"], "celebrate": ["celebrat", "cheer", "victory", "win"],
	"laugh": ["laugh"], "cry": ["cry", "sad", "sob"], "point": ["point"],
	"attack": ["attack", "punch", "slash", "swing", "hit"], "fight": ["fight", "combat", "boxing", "guard"], "swim": ["swim", "paddle"],
}
## Behaviours that play their own clip (or a built-in pose) while standing.
const POSE_STATES := ["dance", "wave", "sit", "sleep", "celebrate", "laugh", "cry", "point", "fight", "pose"]
## Body-part bone names by rig convention, after normalisation (lower case,
## spaces removed, "." -> "_", numeric suffixes like "_059" dropped,
## "mixamorig:" stripped). Most specific names first: matching tries exact
## names across all patterns before falling back to "ends with".
## Conventions covered: Mixamo, Unity/Godot humanoid, Unreal (UE4/UE5),
## Blender default + Rigify (DEF-/ORG-), VRM/VRoid (J_Bip_*), MMD (English
## and Japanese), Daz Genesis, Reallusion CC/iClone (CC_Base_*), Valve
## (ValveBiped.Bip01_*), 3ds Max Biped (Bip001 *), generic L/R prefixes.
const SLOT_NAMES := {
	"hips": [
		"hips", "hip", "pelvis", "root_hips", "j_bip_c_hips", "cc_base_hip", "cc_base_pelvis", "bip001pelvis", "bip01pelvis",
		"valvebiped_bip01_pelvis", "def-hips", "def-pelvis", "spine_root", "センター", "下半身", "腰", "center", "lowerbody", "hip_c",
	],
	"spine": [
		"spine", "spine1", "spine_01", "spine01", "chest", "upperchest", "j_bip_c_spine", "j_bip_c_chest", "cc_base_spine01", "cc_base_waist",
		"bip001spine", "bip01spine", "valvebiped_bip01_spine", "def-spine", "def-spine_001", "abdomen", "abdomenlower", "abdomenupper",
		"chestlower", "torso", "上半身", "upperbody", "waist",
	],
	"head": [
		"head", "j_bip_c_head", "cc_base_head", "bip001head", "bip01head", "valvebiped_bip01_head1", "valvebiped_bip01_head", "def-head",
		"org-head", "頭", "head_c", "head1",
	],
	"upperArmL": [
		"leftarm", "leftupperarm", "upperarm_l", "l_upperarm", "upperarml", "lupperarm", "arm_l", "l_arm", "larm", "armleft", "left_arm",
		"j_bip_l_upperarm", "cc_base_l_upperarm", "bip001lupperarm", "bip01lupperarm", "valvebiped_bip01_l_upperarm",
		"def-upper_arm_l", "org-upper_arm_l", "upper_arm_l", "upper_arm_left", "upperarm_left", "lshldrbend", "lshldr", "lshoulderbend",
		"leftshoulder_arm", "左腕", "腕_l", "arm_left", "l_shoulder_arm", "uparm_l", "l_uparm", "luparm",
	],
	"upperArmR": [
		"rightarm", "rightupperarm", "upperarm_r", "r_upperarm", "upperarmr", "rupperarm", "arm_r", "r_arm", "rarm", "armright", "right_arm",
		"j_bip_r_upperarm", "cc_base_r_upperarm", "bip001rupperarm", "bip01rupperarm", "valvebiped_bip01_r_upperarm",
		"def-upper_arm_r", "org-upper_arm_r", "upper_arm_r", "upper_arm_right", "upperarm_right", "rshldrbend", "rshldr", "rshoulderbend",
		"rightshoulder_arm", "右腕", "腕_r", "arm_right", "r_shoulder_arm", "uparm_r", "r_uparm", "ruparm",
	],
	"upperLegL": [
		"leftupleg", "leftupperleg", "thigh_l", "l_thigh", "upperleg_l", "upperlegl", "lthigh", "leftthigh", "leftleg", "leg_l", "l_leg", "legl",
		"j_bip_l_upperleg", "cc_base_l_thigh", "bip001lthigh", "bip01lthigh", "valvebiped_bip01_l_thigh", "def-thigh_l", "org-thigh_l",
		"upper_leg_l", "upleg_l", "l_upleg", "lthighbend", "lthigh_bend", "左足", "足_l", "leg_left", "thigh_left", "upperleg_left",
	],
	"upperLegR": [
		"rightupleg", "rightupperleg", "thigh_r", "r_thigh", "upperleg_r", "upperlegr", "rthigh", "rightthigh", "rightleg", "leg_r", "r_leg", "legr",
		"j_bip_r_upperleg", "cc_base_r_thigh", "bip001rthigh", "bip01rthigh", "valvebiped_bip01_r_thigh", "def-thigh_r", "org-thigh_r",
		"upper_leg_r", "upleg_r", "r_upleg", "rthighbend", "rthigh_bend", "右足", "足_r", "leg_right", "thigh_right", "upperleg_right",
	],
}

## Exact raw names (lower case) checked before normalisation, for rigs whose
## numbering carries meaning (Rigify's DEF-spine.006 is the head).
const RAW_NAMES := {
	"hips": ["def-spine", "def-hips"],
	"spine": ["def-spine.001", "def-spine.002"],
	"head": ["def-spine.006", "def-head", "org-spine.006"],
}

## Names that look like a match but are helpers (twist, roll, IK, end bones).
const BONE_EXCLUDE := ["twist", "roll", "_ik", "ik_", "pole", "target", "_tip", "helper", "dummy", "socket", "mch-", "ctrl", "nub", "fk_"]

static var _cache := {}


## Copies a model file into the asset store; returns its id ("" on failure).
static func import_file(path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return ""
	var ext := path.get_extension().to_lower()
	DirAccess.make_dir_recursive_absolute(DIR)
	var stem := U.slug(path.get_file().get_basename()) + "~%06x" % (hash(bytes.slice(0, mini(bytes.size(), 400000))) & 0xFFFFFF)
	var id: String
	if ext in ["glb", "vrm"]:
		id = stem + "." + ext
		var f := FileAccess.open(DIR + id, FileAccess.WRITE)
		if f == null:
			return ""
		f.store_buffer(bytes)
		f.close()
	else:
		# .gltf (external files) and .fbx: convert to one self-contained .glb,
		# keeping skeleton, skin and animation clips.
		var doc: GLTFDocument = FBXDocument.new() if ext == "fbx" else GLTFDocument.new()
		var state: GLTFState = FBXState.new() if ext == "fbx" else GLTFState.new()
		# Gather textures from around the file so they get embedded.
		var staged := AssetLib.stage(path)
		var err0 := doc.append_from_file(staged, state)
		if err0 != OK:
			AssetLib.unstage(staged, path)
			return ""
		var scene := doc.generate_scene(state)
		if scene:
			AssetLib.fix_materials(scene, staged.get_base_dir())
		AssetLib.unstage(staged, path)
		if scene == null:
			return ""
		id = stem + ".glb"
		var gdoc := GLTFDocument.new()
		var gstate := GLTFState.new()
		var err := gdoc.append_from_scene(scene, gstate)
		if err == OK:
			err = gdoc.write_to_filesystem(gstate, DIR + id)
		scene.free()
		if err != OK:
			return ""
	# Check the stored copy opens (the scene made for the check isn't kept).
	var check := _load_scene(id)
	if check == null:
		DirAccess.remove_absolute(DIR + id)
		return ""
	check.free()
	return id


static func remove(id: String) -> void:
	DirAccess.remove_absolute(DIR + id)
	_cache.erase(id)


static func display_name(id: String) -> String:
	return id.get_basename().get_slice("~", 0).replace("-", " ").capitalize()


static func list_models() -> Array:
	var out := []
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	for f in d.get_files():
		if f.get_extension() in ["glb", "vrm", "gltf"]:
			out.append(f)
	return out


static func _load_scene(id: String) -> Node3D:
	# Missing (deleted) files fall back to a placeholder without engine errors.
	if id == "" or not FileAccess.file_exists(DIR + id):
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(DIR + id, state) != OK:
		return null
	return doc.generate_scene(state) as Node3D


static func build(look: Dictionary, style := "") -> Dictionary:
	var id: String = look.get("model", "")
	var scene: Node3D = _load_scene(id) if id != "" else null
	var root := Kit.group()
	var model := Kit.group()
	root.add_child(model)
	if scene == null:
		# Missing file: show a neutral placeholder so the scene still opens.
		Kit.shade = "standard"
		model.add_child(Kit.cyl(0.25, 0.3, 1.6, 12, Kit.mat("#9aa3ad"), 0, 0.8, 0))
		model.add_child(Kit.ball(0.22, Kit.mat("#c9ced9"), 0, 1.8, 0))
	else:
		model.add_child(scene)
		_clean_materials(scene)
		# Normalise to ~1.75 m tall, feet on the ground, facing +Z. Rigged
		# models are measured from their bones: skinned meshes often store
		# vertices in centimetres while the scale lives on the skeleton, so
		# mesh bounds would be wildly off.
		var want: float = float(look.get("height", 1.75))
		var ext := _bone_extent(model, scene)
		if ext.size.y > 0.001:
			var s := want / (ext.size.y * 1.08)
			scene.scale = Vector3.ONE * s
			ext = _bone_extent(model, scene)
			scene.position -= Vector3(ext.get_center().x, ext.position.y - ext.size.y * 0.02, ext.get_center().z)
		else:
			var bb := Kit.bounds(model)
			scene.scale = Vector3.ONE * want / maxf(bb.size.y, 0.01)
			bb = Kit.bounds(model)
			scene.position -= Vector3(bb.get_center().x, bb.position.y, bb.get_center().z)
		if look.get("flip", false):
			scene.rotation.y = PI
	var dummy := func() -> Node3D:
		var n := Kit.group()
		model.add_child(n)
		return n
	if scene and style == "anime":
		AssetLib._toonify(scene, 1.8)
	var ext2 := _bone_extent(model, scene) if scene else AABB()
	var height := ext2.size.y * 1.08 if ext2.size.y > 0.01 else (Kit.bounds(model).size.y if scene else 2.0)
	var rig := {"root": root, "model": model, "upper": dummy.call(), "head": dummy.call(), "hc": null,
		"armL": dummy.call(), "armR": dummy.call(), "legL": dummy.call(), "legR": dummy.call(),
		"headH": height * 0.9, "height": height, "sitDrop": height * 0.25, "kind": "model", "scale": 1.0,
		"clips": {}, "anim": null, "skel": null, "bones": {}, "state": ""}
	if scene:
		var ap := _find(scene, "AnimationPlayer") as AnimationPlayer
		if ap:
			rig["anim"] = ap
			for state in CLIP_PATTERNS:
				for clip in ap.get_animation_list():
					var lc := String(clip).to_lower()
					for pat in CLIP_PATTERNS[state]:
						if lc.contains(pat):
							rig["clips"][state] = clip
							break
					if rig["clips"].has(state):
						break
			for clip in ap.get_animation_list():
				ap.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			# Advanced by hand each frame, so action poses can be laid on top.
			ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var sk := _main_skeleton(scene)
		if sk:
			rig["skel"] = sk
			rig["bones"] = find_bones(sk)
			# Swing axes: the character's side axis (and up axis for the head)
			# expressed in each bone's local rest frame, so any rig convention
			# (Mixamo, Biped, VRM) swings limbs forward/back correctly.
			var skel_xf := Kit._local_xf(root, sk) if not root.is_inside_tree() else root.global_transform.affine_inverse() * sk.global_transform
			var side := (skel_xf.basis.inverse() * Vector3.RIGHT).normalized()
			var up := (skel_xf.basis.inverse() * Vector3.UP).normalized()
			rig["axes"] = {}
			rig["side"] = side
			rig["fwd"] = (skel_xf.basis.inverse() * Vector3.BACK).normalized()
			rig["grest"] = {}
			rig["base"] = {}
			for slot in rig["bones"]:
				var bi: int = rig["bones"][slot]
				var g := sk.get_bone_global_rest(bi).basis.orthonormalized()
				rig["axes"][slot] = (g.inverse() * (up if slot == "head" else side)).normalized()
				rig["grest"][slot] = g.get_rotation_quaternion()
				rig["base"][slot] = Quaternion.IDENTITY
				# Elbows and knees: some rigs are stored with the limb already
				# bent (e.g. 3ds Max Biped exports); straighten the forearm /
				# shin along its upper limb first, so bends start from straight.
				if slot.begins_with("lower"):
					var up_bone: int = rig["bones"].get(str(slot).replace("lower", "upper"), -1)
					var tip := _main_child(sk, bi)
					if up_bone >= 0 and tip >= 0:
						var d_up := (sk.get_bone_global_rest(bi).origin - sk.get_bone_global_rest(up_bone).origin).normalized()
						var d_low := (sk.get_bone_global_rest(tip).origin - sk.get_bone_global_rest(bi).origin).normalized()
						if d_up.length() > 0.5 and d_low.length() > 0.5:
							rig["base"][slot] = Quaternion(d_low, d_up)
				# Arms: whatever the rest pose (T-pose, A-pose, arms down),
				# rotate the upper arm to hang relaxed at the side first.
				if slot.begins_with("upperArm"):
					var dir := _limb_dir(sk, bi)
					if dir != Vector3.ZERO:
						var sgn := -1.0 if slot == "upperArmR" else 1.0
						# Character space: down, slightly out to the side and forward.
						var want := (skel_xf.basis.inverse() * Vector3(sgn * 0.22, -1.0, 0.06)).normalized()
						rig["base"][slot] = Quaternion(dir, want)
			if rig["bones"].has("head"):
				var head_p := Kit._local_xf(root, sk) * sk.get_bone_global_rest(rig["bones"]["head"]).origin
				rig["headH"] = clampf(head_p.y + 0.06, 0.4, rig["height"])
	rig["blink"] = _blink_shapes(scene) if scene else []
	rig["mouth"] = _mouth_shapes(scene) if scene else []
	rig["expr"] = _expr_shapes(scene) if scene else {}
	var ssk: Skeleton3D = rig["skel"]
	if ssk:
		# Skeleton space -> character space (+Z forward, Y up), for clips.
		var sxf := Kit._local_xf(root, ssk)
		rig["char_q"] = sxf.basis.get_rotation_quaternion()
		rig["skel_scale"] = sxf.basis.get_scale().x
		rig["springs"] = SpringRig.build(ssk, rig["bones"])
	# Framing hints for thumbnails (skinned mesh bounds can't be trusted).
	root.set_meta("frame_h", float(rig["height"]))
	root.set_meta("head_h", float(rig["headH"]))
	return rig


## Face shapes that close the eyes: [[MeshInstance3D, shape index], ...].
## Covers VRM/VRoid ("Blink", "Fcl_EYE_Close"), ARKit ("eyeBlinkLeft"),
## MMD ("まばたき") and game rigs with left/right winks ("Eye_WinkA_L").
static func _blink_shapes(scene: Node) -> Array:
	var both := []
	var sides := []
	for n in AssetLib._find_all(scene, "MeshInstance3D"):
		var mi := n as MeshInstance3D
		if not (mi.mesh is ArrayMesh):
			continue
		var am := mi.mesh as ArrayMesh
		for i in am.get_blend_shape_count():
			var nm := String(am.get_blend_shape_name(i)).to_lower().replace(" ", "_")
			if nm in ["blink", "eye_close", "eyes_closed", "eyeclose", "fcl_eye_close", "まばたき", "eye_blink", "blink_both"]:
				both.append([mi, i])
			elif nm.contains("blink") or nm.contains("winka") or (nm.contains("eye") and nm.contains("close")):
				sides.append([mi, i])
	return both if not both.is_empty() else sides


## Face shapes that open the mouth: [[MeshInstance3D, shape index], ...].
## Covers VRM/VRoid ("A", "aa", "Fcl_MTH_A"), ARKit ("jawOpen"), MMD
## ("あ") and game exports ("Mouth_A01", "Mouth_Open01").
static func _mouth_shapes(scene: Node) -> Array:
	var best := []
	var loose := []
	for n in AssetLib._find_all(scene, "MeshInstance3D"):
		var mi := n as MeshInstance3D
		if not (mi.mesh is ArrayMesh):
			continue
		var am := mi.mesh as ArrayMesh
		for i in am.get_blend_shape_count():
			var nm := String(am.get_blend_shape_name(i)).to_lower().replace(" ", "_")
			if nm in ["a", "aa", "vrc.v_aa", "fcl_mth_a", "mth_a", "mouth_a", "jawopen", "jaw_open", "mouthopen", "mouth_open", "あ", "mouth_a01", "v_aa"]:
				best.append([mi, i])
			elif nm.contains("mouth") and (nm.contains("open") or nm.ends_with("_a01") or nm.ends_with("_a")):
				loose.append([mi, i])
	var out := best if not best.is_empty() else loose
	return out.slice(0, 1)


## Face shapes for feelings, by name: {"joy": [[mesh, index], ...],
## "angry": [...], "sorrow": [...], "surprised": [...]}. Covers VRM 0 / 1
## ("Joy", "happy", "Angry", "Sorrow", "sad", "Surprised"), VRoid
## ("Fcl_ALL_Joy" ...), MMD (笑い, 怒り, 困る) and game exports
## ("Mouth_Smile01", "Brow_Angry_L", "Brow_Trouble_R" ...).
const EXPR_WORDS := {
	"joy": ["joy", "happy", "smile", "笑"],
	"angry": ["angry", "anger", "怒"],
	"sorrow": ["sorrow", "sad", "trouble", "困", "悲"],
	"surprised": ["surprised", "surprise", "驚"],
}


static func _expr_shapes(scene: Node) -> Dictionary:
	var out := {}
	for n in AssetLib._find_all(scene, "MeshInstance3D"):
		var mi := n as MeshInstance3D
		if not (mi.mesh is ArrayMesh):
			continue
		var am := mi.mesh as ArrayMesh
		for i in am.get_blend_shape_count():
			var nm := String(am.get_blend_shape_name(i)).to_lower()
			# Eye-closing shapes would fight the blinking.
			if nm.contains("blink") or nm.contains("close"):
				continue
			# VRM's "Fun" (a happy, relaxed face) counts as joy.
			var kind := "joy" if nm == "fun" or nm == "fcl_all_fun" else ""
			for k in EXPR_WORDS:
				if kind != "":
					break
				for w in EXPR_WORDS[k]:
					if nm.contains(w):
						kind = k
						break
			if kind != "":
				var arr: Array = out.get_or_add(kind, [])
				if arr.size() < 4:
					arr.append([mi, i])
	return out


## Game-style rigs: hide VFX-only meshes, and stop vertex colours (often
## outline/mask data) from tinting textured surfaces.
static func _clean_materials(scene: Node) -> void:
	for n in AssetLib._find_all(scene, "MeshInstance3D"):
		var mi := n as MeshInstance3D
		var nm := String(mi.name).to_lower()
		# VFX meshes and attached skill props (vehicles, helmets...) start hidden.
		if nm.contains("effect") or nm.ends_with("vat") or nm.contains("_vat") or nm.begins_with("vat") or nm.begins_with("skillobj") or nm.contains("_skillobj"):
			mi.visible = false
			continue
		if mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			var m := mi.get_active_material(si) as BaseMaterial3D
			if m and m.albedo_texture and m.vertex_color_use_as_albedo:
				var c := m.duplicate() as BaseMaterial3D
				c.vertex_color_use_as_albedo = false
				mi.set_surface_override_material(si, c)


## Direction (skeleton space) from a limb bone to its main child joint, used
## to find how the arm is posed at rest. Zero when it can't be determined.
static func _limb_dir(sk: Skeleton3D, b: int) -> Vector3:
	var p := sk.get_bone_global_rest(b).origin
	var best := Vector3.ZERO
	var best_len := 0.0
	for c in sk.get_bone_children(b):
		var nm := sk.get_bone_name(c).to_lower()
		var d := sk.get_bone_global_rest(c).origin - p
		var score := d.length()
		# Prefer the real elbow over twist/helper children.
		if nm.contains("elbow") or nm.contains("forearm") or nm.contains("lowerarm") or nm.contains("lower_arm") or nm.contains("ひじ"):
			score *= 4.0
		if nm.contains("twist") or nm.contains("roll"):
			score *= 0.25
		if score > best_len:
			best_len = score
			best = d
	return best.normalized() if best.length() > 1e-5 else Vector3.ZERO


## Bounding box of the skeleton's rest-pose joints in `model` space
## (empty AABB when the model has no skeleton).
static func _bone_extent(model: Node3D, scene: Node3D) -> AABB:
	var sk := _main_skeleton(scene)
	if sk == null or sk.get_bone_count() < 4:
		return AABB()
	var xf := Kit._local_xf(model, sk)
	var out := AABB()
	var first := true
	for b in sk.get_bone_count():
		var p := xf * sk.get_bone_global_rest(b).origin
		if first:
			out = AABB(p, Vector3.ZERO)
			first = false
		else:
			out = out.expand(p)
	return out


static var _suffix := RegEx.create_from_string("(_\\d+)+$")


## "Left arm_059" -> "leftarm", "mixamorig:LeftArm" -> "leftarm",
## "Bip001 L UpperArm" -> "bip001lupperarm".
static func _norm_bone(name: String) -> String:
	var n := name.to_lower().replace("mixamorig", "").replace(":", "").replace(".", "_")
	n = _suffix.sub(n, "")
	return n.replace(" ", "").trim_prefix("_")


## The character's skeleton: the one with the most bones (rigs can carry
## extra skeletons for vehicles or props).
static func _main_skeleton(scene: Node) -> Skeleton3D:
	var best: Skeleton3D = null
	for n in AssetLib._find_all(scene, "Skeleton3D"):
		var sk := n as Skeleton3D
		if best == null or sk.get_bone_count() > best.get_bone_count():
			best = sk
	return best


## Maps body slots to bone indices using SLOT_NAMES: exact name matches
## first (in pattern order), then "ends with" matches, skipping helper bones.
static func find_bones(sk: Skeleton3D) -> Dictionary:
	var names := []
	var raws := []
	for b in sk.get_bone_count():
		var raw := sk.get_bone_name(b)
		raws.append(raw.to_lower())
		var bn := _norm_bone(raw)
		var skip := raw.begins_with("+")
		for x in BONE_EXCLUDE:
			if bn.contains(x):
				skip = true
		if bn.ends_with("_end") or bn.ends_with("end_l") or bn.ends_with("end_r"):
			skip = true
		names.append("" if skip else bn)
	var out := {}
	for slot in SLOT_NAMES:
		var pats: Array = SLOT_NAMES[slot]
		var found := -1
		for pat in RAW_NAMES.get(slot, []):
			var ri := raws.find(pat)
			if ri >= 0:
				found = ri
				break
		for pat in pats:
			if found >= 0:
				break
			var i := names.find(pat)
			if i >= 0:
				found = i
				break
		if found < 0:
			for pat in pats:
				for i in names.size():
					var n: String = names[i]
					if n != "" and n.ends_with(pat) and not out.values().has(i):
						found = i
						break
				if found >= 0:
					break
		if found >= 0:
			out[slot] = found
	# Elbows and knees: the main child of the upper arm / thigh, whatever the
	# rig calls them (Mixamo "LeftForeArm", VRM "J_Bip_L_LowerArm", ...).
	for pair in [["upperArmL", "lowerArmL"], ["upperArmR", "lowerArmR"], ["upperLegL", "lowerLegL"], ["upperLegR", "lowerLegR"]]:
		if out.has(pair[0]):
			var c := _main_child(sk, out[pair[0]])
			if c >= 0:
				out[pair[1]] = c
	return out


## The child that continues a limb: not a twist/helper bone, and with the
## most bones below it (the hand or foot chain).
static func _main_child(sk: Skeleton3D, b: int) -> int:
	var best := -1
	var best_n := -1
	for c in sk.get_bone_children(b):
		var bn := _norm_bone(sk.get_bone_name(c))
		var skip := false
		for x in BONE_EXCLUDE:
			if bn.contains(x):
				skip = true
		if skip:
			continue
		var n := _subtree(sk, c)
		if n > best_n:
			best_n = n
			best = c
	return best


static func _subtree(sk: Skeleton3D, b: int) -> int:
	var n := 1
	for c in sk.get_bone_children(b):
		n += _subtree(sk, c)
	return n


static func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r:
			return r
	return null


static func _state(a: Actor, sp: float) -> String:
	if a.swimming:
		return "swim"
	if a.attack_t > 0.0:
		return "attack"
	if not a.on_ground and a.vel.y > 1:
		return "jump"
	if sp > 3.3:
		return "run"
	if sp > 0.2:
		return "walk"
	var b := a.shown()
	if a.speak_t > 0 and b != "sleep" and b != "pose":
		return "talk"
	if b in POSE_STATES:
		return b
	return "idle"


## States that don't need a clip of their own: any idle/walk clip will do.
const BASIC_STATES := ["idle", "walk", "run", "jump"]


static func animate(a: Actor, dt: float, sp: float, _is_player: bool) -> void:
	var state := _state(a, sp)
	var key := library_clip(a, state)
	if key != "":
		# A clip from the animation library plays this action.
		if a._clip_state != state:
			a._clip_state = state
			a._clip_t = 0.0
		a._clip_t += dt * (clampf(sp / 1.7, 0.6, 2.2) if state in ["walk", "run"] else 1.0)
		var r := a.root()
		r.position = a.pos
		r.basis = Basis(Vector3.UP, a.yaw).scaled_local(Vector3.ONE * a.k())
		AnimLib.apply(a, key, a._clip_t)
	else:
		a._clip_state = ""
		_animate_body(a, dt, sp, state)
	# Hair, skirts and tails follow whatever pose was set.
	var springs: SpringRig = a.rig.get("springs")
	if springs:
		springs.step(dt, a.height())


## The library clip this character uses for `state`, or "".
static func library_clip(a: Actor, state: String) -> String:
	var anims: Dictionary = a.look.get("anims", {}) if a.look.get("anims") is Dictionary else {}
	if anims.is_empty():
		return ""
	var key := str(anims.get(state, ""))
	if key == "" and state == "run":
		key = str(anims.get("walk", ""))
	if key != "" and AnimLib.clip(key).is_empty():
		return ""
	return key


static func _animate_body(a: Actor, dt: float, sp: float, state: String) -> void:
	var m := a.rig
	var ap: AnimationPlayer = m.get("anim")
	var clips: Dictionary = m["clips"]
	if state == "sleep" and not clips.has("sleep"):
		# No lying clip: tip the whole model onto its back, centred on the spot.
		var r := a.root()
		var h := a.height()
		# Turn to face, then tip back (a combined Euler would roll them over).
		r.basis = (Basis(Vector3.UP, a.yaw) * Basis(Vector3.RIGHT, -PI / 2)).scaled_local(Vector3.ONE * a.k())
		r.position = a.pos + Vector3(sin(a.yaw), 0, cos(a.yaw)) * h * 0.45 + Vector3(0, h * 0.08, 0)
	if ap and not clips.is_empty():
		var fallback := "idle"
		if state == "run":
			fallback = "walk"
		elif state == "fight":
			fallback = "attack" if clips.has("attack") else "idle"
		var clip: String = clips.get(state, clips.get(fallback, ""))
		if clip == "":
			clip = clips.values()[0]
		if ap.current_animation != clip:
			ap.play(clip, 0.25)
		ap.speed_scale = clampf(sp / 1.7, 0.6, 2.2) if state in ["walk", "run"] else 1.0
		ap.advance(dt)
		if clips.has(state) or state in BASIC_STATES:
			return
		# No clip for this action: lay the built-in pose over the idle clip.
	_pose(a, state, sp)


## Built-in poses for rigs without a clip for the action. Angles are in the
## character's frame: x swings forward (negative) / back, y moves an arm out
## to the side. Elbows bend forward with negative x, knees back with positive.
static func _pose_angles(a: Actor, state: String, sp: float) -> Dictionary:
	var t := a.t
	var amt := minf(1.0, sp / 3.2)
	var sw := sin(a.walk) * 0.7 * amt
	var p := {"upperLegL": Vector2(sw, 0), "upperLegR": Vector2(-sw, 0), "upperArmL": Vector2(-sw * 0.8, 0), "upperArmR": Vector2(sw * 0.8, 0),
		"lowerArmL": Vector2(-0.15 - amt * 0.3, 0), "lowerArmR": Vector2(-0.15 - amt * 0.3, 0),
		"lowerLegL": Vector2(maxf(0.0, -sw) * 0.9, 0), "lowerLegR": Vector2(maxf(0.0, sw) * 0.9, 0),
		"spine": Vector2(sin(t * 1.7) * 0.015, 0), "lift": 0.0, "headPitch": 0.0, "spin": 0.0}
	match state:
		"talk":
			p["upperArmR"] = Vector2(-0.55 + sin(t * 5.0) * 0.25, 0.1)
			p["lowerArmR"] = Vector2(-1.0 + sin(t * 5.0 + 1.0) * 0.2, 0)
			p["upperArmL"] = Vector2(-0.2, 0.05)
			p["lowerArmL"] = Vector2(-0.5, 0)
			p["headPitch"] = sin(t * 7.0) * 0.06
		"dance":
			var dp := Actor.dance_pose(a.dance_style, t)
			for k in dp:
				if dp[k] is Vector2:
					p[k] = dp[k]
			p["lift"] = float(dp["lift"])
			p["spin"] = float(dp["spin"])
			p["spine"] = Vector2(0.0, float(dp["lean"]))
			p["headPitch"] = float(dp["hpitch"])
		"wave":
			p["upperArmR"] = Vector2(-2.5, 0.35)
			p["lowerArmR"] = Vector2(-0.4 + sin(t * 9.0) * 0.45, 0)
		"sit":
			# On the ground, legs out in front.
			p["upperLegL"] = Vector2(-1.5, 0.08)
			p["upperLegR"] = Vector2(-1.5, 0.08)
			p["lowerLegL"] = Vector2(0.1, 0)
			p["lowerLegR"] = Vector2(0.1, 0)
			p["upperArmL"] = Vector2(-0.35, 0.15)
			p["upperArmR"] = Vector2(-0.35, 0.15)
			p["lowerArmL"] = Vector2(-0.4, 0)
			p["lowerArmR"] = Vector2(-0.4, 0)
			p["spine"] = Vector2(-0.05, 0)
			p["lift"] = -0.27
		"sleep":
			for k in ["upperLegL", "upperLegR", "lowerLegL", "lowerLegR", "upperArmL", "upperArmR"]:
				p[k] = Vector2(0, 0.05 if k.begins_with("upperArm") else 0.0)
			p["lowerArmL"] = Vector2(-0.2, 0)
			p["lowerArmR"] = Vector2(-0.2, 0)
			p["spine"] = Vector2.ZERO
		"celebrate":
			var j := absf(sin(t * 7.0))
			p["lift"] = j * 0.06
			p["upperArmL"] = Vector2(-2.9 + sin(t * 14.0) * 0.2, 0.35)
			p["upperArmR"] = Vector2(-2.9 - sin(t * 14.0) * 0.2, 0.35)
			p["lowerArmL"] = Vector2(-0.25, 0)
			p["lowerArmR"] = Vector2(-0.25, 0)
			p["lowerLegL"] = Vector2((1.0 - j) * 0.35, 0)
			p["lowerLegR"] = Vector2((1.0 - j) * 0.35, 0)
			p["upperLegL"] = Vector2(-(1.0 - j) * 0.2, 0)
			p["upperLegR"] = Vector2(-(1.0 - j) * 0.2, 0)
			p["headPitch"] = -0.25
		"laugh":
			# Lean back, hands on the belly, shaking.
			p["spine"] = Vector2(-0.18 + sin(t * 16.0) * 0.05, 0)
			p["upperArmL"] = Vector2(-0.2, 0.1)
			p["upperArmR"] = Vector2(-0.2, 0.1)
			p["lowerArmL"] = Vector2(-1.1, 0)
			p["lowerArmR"] = Vector2(-1.1, 0)
			p["headPitch"] = -0.3 + sin(t * 16.0) * 0.08
		"cry":
			# Head down, hands to the face, shoulders shaking.
			p["spine"] = Vector2(0.25 + sin(t * 18.0) * 0.03, 0)
			p["upperArmL"] = Vector2(-1.1, -0.05)
			p["upperArmR"] = Vector2(-1.1, -0.05)
			p["lowerArmL"] = Vector2(-2.0, 0)
			p["lowerArmR"] = Vector2(-2.0, 0)
			p["headPitch"] = 0.4
		"point":
			p["upperArmR"] = Vector2(-1.5, 0.05)
			p["lowerArmR"] = Vector2(0.0, 0)
		"fight":
			# Boxer's guard: elbows down and a little out, fists up in front
			# of each shoulder (apart, not crossed over the chest).
			p["upperArmL"] = Vector2(-0.55, 0.4)
			p["upperArmR"] = Vector2(-0.45, 0.4)
			p["lowerArmL"] = Vector2(-1.9, 0)
			p["lowerArmR"] = Vector2(-1.9, 0)
			p["upperLegL"] = Vector2(-0.25, 0.1)
			p["upperLegR"] = Vector2(0.15, 0.1)
			p["lowerLegL"] = Vector2(0.35, 0)
			p["lowerLegR"] = Vector2(0.35, 0)
		"swim":
			# Upright: arms pull, legs kick; the spine leans in when moving
			# (eased on the actor so it never snaps).
			var moving := sp > 0.3
			a._swim_lean = lerpf(a._swim_lean, 0.35 if moving else 0.05, 0.08)
			var st := t * (5.0 if moving else 3.0)
			p["upperArmL"] = Vector2(-1.4 + sin(st) * 0.9, 0.9 + sin(st) * 0.4)
			p["upperArmR"] = Vector2(-1.4 - sin(st) * 0.9, 0.9 - sin(st) * 0.4)
			p["lowerArmL"] = Vector2(-0.3, 0)
			p["lowerArmR"] = Vector2(-0.3, 0)
			p["upperLegL"] = Vector2(sin(st * 1.6) * 0.45, 0)
			p["upperLegR"] = Vector2(-sin(st * 1.6) * 0.45, 0)
			p["spine"] = Vector2(a._swim_lean, 0)
			p["headPitch"] = -0.25 - a._swim_lean * 0.5
		"pose":
			var ps := a.shown_pose()
			for slot in Poses.JOINTS:
				if slot != "head" and ps.has(slot):
					p[slot] = Poses.joint(ps, slot)
			p["lift"] = float(ps.get("lift", 0.0))
			var hd := Poses.joint(ps, "head")
			p["headPitch"] = hd.y
			p["headYaw"] = hd.x
		"attack":
			var k := 1.0 - a.attack_t / Actor.ATTACK_TIME
			p["upperArmR"] = Vector2(-2.6 + smoothstep(0.15, 0.6, k) * 3.0, 0.2)
			p["lowerArmR"] = Vector2(-0.3, 0)
			p["spine"] = Vector2(sin(k * PI) * -0.12, 0)
	return p


static func _pose(a: Actor, state: String, sp: float) -> void:
	var m := a.rig
	var sk: Skeleton3D = m.get("skel")
	if sk == null:
		return
	var bones: Dictionary = m["bones"]
	var p := _pose_angles(a, state, sp)
	var h := a.height()
	var r := a.root()
	if state != "sleep":
		r.position = a.pos + Vector3(0, float(p["lift"]) * h, 0)
		r.rotation = Vector3(0, a.yaw + float(p["spin"]), 0)
	var side: Vector3 = m.get("side", Vector3.RIGHT)
	var fwd: Vector3 = m.get("fwd", Vector3.BACK)
	for slot in bones:
		if not p.has(slot):
			continue
		var ang: Vector2 = p[slot]
		var b: int = bones[slot]
		var rest := sk.get_bone_rest(b).basis.get_rotation_quaternion()
		if not m.has("grest"):
			var axis: Vector3 = (m.get("axes", {}) as Dictionary).get(slot, Vector3.RIGHT)
			sk.set_bone_pose_rotation(b, rest * Quaternion(axis, ang.x))
			continue
		var gq: Quaternion = m["grest"][slot]
		var base: Quaternion = m["base"].get(slot, Quaternion.IDENTITY)
		var q: Quaternion
		if slot.begins_with("lower"):
			# Bend in the frame the (relaxed) upper limb carries it in.
			var up_slot: String = str(slot).replace("lower", "upper")
			var pb: Quaternion = m["base"].get(up_slot, Quaternion.IDENTITY)
			q = Quaternion((pb.inverse() * side).normalized(), ang.x) * base
		else:
			# Out to the side: left arm/leg rolls one way, right the other.
			var out_sign := 1.0 if slot.ends_with("L") else -1.0
			q = Quaternion(side, ang.x) * Quaternion(fwd, ang.y * out_sign) * base
		sk.set_bone_pose_rotation(b, rest * (gq.inverse() * q * gq))
	if bones.has("head"):
		var hb: int = bones["head"]
		var hr := sk.get_bone_rest(hb).basis.get_rotation_quaternion()
		a.head_yaw = lerpf(a.head_yaw, float(p["headYaw"]) / 0.7 if p.has("headYaw") else a.hy, 0.15)
		var haxis: Vector3 = (m.get("axes", {}) as Dictionary).get("head", Vector3.UP)
		var pitch := float(p["headPitch"]) + a.hp * 0.5
		var hq := Quaternion(haxis, a.head_yaw * 0.7)
		if m.has("grest"):
			var hg: Quaternion = m["grest"]["head"]
			hq = hq * (hg.inverse() * Quaternion(side, pitch) * hg)
		sk.set_bone_pose_rotation(hb, hr * hq)
	if state == "sit" or state == "sleep":
		_rest_on_ground(a, state, sk, bones)


## Sitting and lying: puts the body itself on the ground. Rigs differ in leg
## length, hip height and how deep the body is, so a fixed drop left long-
## legged models sitting in mid-air and sleepers floating on their backs.
## Measured from the trunk bones only (hair, skirts and tails hang lower and
## would lift the body off the ground).
static func _rest_on_ground(a: Actor, state: String, sk: Skeleton3D, bones: Dictionary) -> void:
	var low := INF
	for slot in (["hips"] if state == "sit" else ["hips", "spine", "head"]):
		if bones.has(slot):
			low = minf(low, (sk.global_transform * sk.get_bone_global_pose(int(bones[slot]))).origin.y)
	if low == INF:
		return
	# The bones run through the middle of the body: rest it on its seat or
	# back, about this far below them.
	var r := a.root()
	r.position.y += a.pos.y + a.height() * (0.065 if state == "sit" else 0.07) - low
