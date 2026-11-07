class_name ModelRig
## Imported .glb / .vrm characters. Models are copied into user://assets/models
## and referenced by id from look.model, so projects stay portable. If the file
## carries animation clips they are matched by name (idle, walk, run, dance...);
## otherwise humanoid bones are swung procedurally.

const DIR := "user://assets/models/"
const CLIP_PATTERNS := {
	"idle": ["idle", "stand", "breath"], "walk": ["walk"], "run": ["run", "sprint", "jog"], "dance": ["dance"],
	"wave": ["wave", "hello", "greet"], "sit": ["sit"], "jump": ["jump"], "talk": ["talk", "speak"],
}
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
	if _load_scene(id) == null:
		DirAccess.remove_absolute(DIR + id)
		return ""
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
			rig["grest"] = {}
			rig["base"] = {}
			for slot in rig["bones"]:
				var bi: int = rig["bones"][slot]
				var g := sk.get_bone_global_rest(bi).basis.orthonormalized()
				rig["axes"][slot] = (g.inverse() * (up if slot == "head" else side)).normalized()
				rig["grest"][slot] = g.get_rotation_quaternion()
				rig["base"][slot] = Quaternion.IDENTITY
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
	# Framing hints for thumbnails (skinned mesh bounds can't be trusted).
	root.set_meta("frame_h", float(rig["height"]))
	root.set_meta("head_h", float(rig["headH"]))
	return rig


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
	return out


static func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r:
			return r
	return null


static func _state(a: Actor, sp: float) -> String:
	if not a.on_ground and a.vel.y > 1:
		return "jump"
	if sp > 3.3:
		return "run"
	if sp > 0.2:
		return "walk"
	if a.speak_t > 0:
		return "talk"
	if a.behavior in ["dance", "wave", "sit"]:
		return a.behavior
	return "idle"


static func animate(a: Actor, _dt: float, sp: float, _is_player: bool) -> void:
	var m := a.rig
	var state := _state(a, sp)
	var ap: AnimationPlayer = m.get("anim")
	var clips: Dictionary = m["clips"]
	if ap and not clips.is_empty():
		var clip: String = clips.get(state, clips.get("walk" if state == "run" else "idle", ""))
		if clip == "" and not clips.is_empty():
			clip = clips.values()[0]
		if clip != "" and ap.current_animation != clip:
			ap.play(clip, 0.25)
		ap.speed_scale = clampf(sp / 1.7, 0.6, 2.2) if state in ["walk", "run"] else 1.0
		return
	var sk: Skeleton3D = m.get("skel")
	if sk == null:
		return
	var bones: Dictionary = m["bones"]
	var amt := minf(1.0, sp / 3.2)
	var sw := sin(a.walk) * 0.7 * amt
	var t := a.t
	var swing := {"upperLegL": sw, "upperLegR": -sw, "upperArmL": -sw * 0.8, "upperArmR": sw * 0.8}
	if state == "dance":
		swing = {"upperArmL": -2.4 + sin(t * 8) * 0.3, "upperArmR": -2.4 - sin(t * 8) * 0.3, "upperLegL": maxf(0, sin(t * 8)) * -0.4, "upperLegR": maxf(0, -sin(t * 8)) * -0.4}
	elif state == "wave":
		swing["upperArmR"] = -2.6 + sin(t * 9) * 0.3
	elif state == "sit":
		swing = {"upperLegL": -1.4, "upperLegR": -1.4, "upperArmL": -0.4, "upperArmR": -0.4}
	for slot in swing:
		if bones.has(slot):
			var b: int = bones[slot]
			var rest := sk.get_bone_rest(b).basis.get_rotation_quaternion()
			if m.has("grest"):
				# Swing in skeleton space on top of the relaxed base pose,
				# then express it in the bone's local frame.
				var gq: Quaternion = m["grest"][slot]
				var base: Quaternion = m["base"][slot]
				var q := Quaternion(m["side"], swing[slot]) * base
				sk.set_bone_pose_rotation(b, rest * (gq.inverse() * q * gq))
			else:
				var axis: Vector3 = (m.get("axes", {}) as Dictionary).get(slot, Vector3.RIGHT)
				sk.set_bone_pose_rotation(b, rest * Quaternion(axis, swing[slot]))
	if bones.has("head"):
		var hb: int = bones["head"]
		var hr := sk.get_bone_rest(hb).basis.get_rotation_quaternion()
		a.head_yaw = lerpf(a.head_yaw, a.hy, 0.15)
		var haxis: Vector3 = (m.get("axes", {}) as Dictionary).get("head", Vector3.UP)
		sk.set_bone_pose_rotation(hb, hr * Quaternion(haxis, a.head_yaw * 0.7))
