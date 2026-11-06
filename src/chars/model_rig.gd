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
const SLOT_NAMES := {
	"hips": ["hips", "pelvis"], "spine": ["spine"], "head": ["head"],
	"upperArmL": ["leftarm", "leftupperarm", "upperarm_l", "l_upperarm", "arm_l", "upperarml"],
	"upperArmR": ["rightarm", "rightupperarm", "upperarm_r", "r_upperarm", "arm_r", "upperarmr"],
	"upperLegL": ["leftupleg", "leftupperleg", "thigh_l", "l_thigh", "upperleg_l", "upperlegl"],
	"upperLegR": ["rightupleg", "rightupperleg", "thigh_r", "r_thigh", "upperleg_r", "upperlegr"],
}

static var _cache := {}


## Copies a model file into the asset store; returns its id ("" on failure).
static func import_file(path: String) -> String:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return ""
	var ext := path.get_extension().to_lower()
	var id := "%08x" % (hash(bytes.slice(0, mini(bytes.size(), 400000))) & 0xFFFFFFFF) + "." + ext
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(DIR + id, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_buffer(bytes)
	f.close()
	if _load_scene(id) == null:
		DirAccess.remove_absolute(DIR + id)
		return ""
	return id


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
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(DIR + id, state) != OK:
		return null
	return doc.generate_scene(state) as Node3D


static func build(look: Dictionary) -> Dictionary:
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
		# Normalise to ~1.75 m tall, feet on the ground, facing +Z.
		var bb := Kit.bounds(model)
		var h := maxf(bb.size.y, 0.01)
		var s := 1.75 / h
		var want: float = float(look.get("height", 1.75)) / 1.75
		scene.scale = Vector3.ONE * s * want
		bb = Kit.bounds(model)
		scene.position.y -= bb.position.y
		scene.position.x -= bb.get_center().x
		scene.position.z -= bb.get_center().z
		if look.get("flip", false):
			scene.rotation.y = PI
	var dummy := func() -> Node3D:
		var n := Kit.group()
		model.add_child(n)
		return n
	var height := Kit.bounds(model).size.y if scene else 2.0
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
		var sk := _find(scene, "Skeleton3D") as Skeleton3D
		if sk:
			rig["skel"] = sk
			for slot in SLOT_NAMES:
				for b in sk.get_bone_count():
					var bn := sk.get_bone_name(b).to_lower().replace(":", "").replace("mixamorig", "").replace(".", "_").replace(" ", "")
					var hit := false
					for pat in SLOT_NAMES[slot]:
						if bn == pat or bn.ends_with(pat):
							hit = true
							break
					if hit:
						rig["bones"][slot] = b
						break
			if rig["bones"].has("head"):
				var hp := sk.global_transform * sk.get_bone_global_rest(rig["bones"]["head"])
				rig["headH"] = (root.global_transform.affine_inverse() * hp.origin).y if root.is_inside_tree() else (hp.origin.y * scene.scale.y + scene.position.y)
	return rig


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
			sk.set_bone_pose_rotation(b, rest * Quaternion(Vector3.RIGHT, swing[slot]))
	if bones.has("head"):
		var hb: int = bones["head"]
		var hr := sk.get_bone_rest(hb).basis.get_rotation_quaternion()
		a.head_yaw = lerpf(a.head_yaw, a.hy, 0.15)
		sk.set_bone_pose_rotation(hb, hr * Quaternion(Vector3.UP, a.head_yaw * 0.7))
