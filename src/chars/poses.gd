class_name Poses
## Held poses: built-in ones and the pose library (poses you make in the
## pose editor and save to reuse on any character, in any scene).
##
## A pose is a dictionary of joint angles in the same frame the imported-rig
## poses use (see ModelRig._pose_angles): for each slot in JOINTS a pair
## [x, y], where x swings a limb forward/up (negative) or back, and y moves an
## arm or leg out to the side. Elbows bend forward with negative x and turn
## the forearm in across the body with positive y; knees bend back with
## positive x. "spine" is [lean forward, lean sideways], "head" is
## [turn, nod down], "lift" raises or drops the body (a fraction of height).
## Saved with the character ("pose" in the cast), so a scene doesn't need the
## library to play.
##
## Built-in characters have no elbows or knees: they show the upper limbs,
## spine, head and lift. Pixel 2D characters show the nearest sprite frame
## ("sprite" in the pose, or one worked out from the arms and legs).
##
## Library file: user://assets/poses.json (a list of poses with "name").

const JOINTS := ["head", "spine", "upperArmL", "lowerArmL", "upperArmR", "lowerArmR", "upperLegL", "lowerLegL", "upperLegR", "lowerLegR"]
const JOINT_NAMES := {"head": "Head", "spine": "Body", "upperArmL": "Left arm", "lowerArmL": "Left elbow", "upperArmR": "Right arm",
	"lowerArmR": "Right elbow", "upperLegL": "Left leg", "lowerLegL": "Left knee", "upperLegR": "Right leg", "lowerLegR": "Right knee"}
## Slider ranges per joint: [[x min, x max], [y min, y max]] (radians).
const RANGES := {
	"head": [[-1.2, 1.2], [-0.6, 0.7]],
	"spine": [[-0.5, 1.2], [-0.5, 0.5]],
	"upperArmL": [[-3.1, 1.0], [-0.4, 1.6]], "upperArmR": [[-3.1, 1.0], [-0.4, 1.6]],
	"lowerArmL": [[-2.6, 0.0], [-0.8, 1.8]], "lowerArmR": [[-2.6, 0.0], [-0.8, 1.8]],
	"upperLegL": [[-1.8, 0.8], [-0.3, 0.9]], "upperLegR": [[-1.8, 0.8], [-0.3, 0.9]],
	"lowerLegL": [[0.0, 2.4], [0.0, 0.0]], "lowerLegR": [[0.0, 2.4], [0.0, 0.0]],
}

static var FILE := "user://assets/poses.json"

const BUILTIN := {
	"hips": {"name": "Hands on hips", "sprite": "idle0", "spine": [-0.04, 0.0],
		"upperArmL": [0.15, 0.75], "lowerArmL": [-1.9, 1.5], "upperArmR": [0.15, 0.75], "lowerArmR": [-1.9, 1.5]},
	"crossed": {"name": "Arms crossed", "sprite": "idle0", "head": [0.0, -0.08],
		"upperArmL": [-0.5, 0.12], "lowerArmL": [-1.75, 1.35], "upperArmR": [-0.4, 0.12], "lowerArmR": [-1.85, 1.35]},
	"think": {"name": "Thinking", "sprite": "idle2", "head": [0.25, 0.18], "spine": [0.04, 0.0],
		"upperArmR": [-0.7, 0.1], "lowerArmR": [-2.4, 0.25], "upperArmL": [-0.3, 0.12], "lowerArmL": [-1.65, 1.3]},
	"salute": {"name": "Salute", "sprite": "wave0", "head": [0.0, -0.05],
		"upperArmR": [-0.9, 1.05], "lowerArmR": [-2.3, 0], "upperArmL": [0.0, 0.05]},
	"shrug": {"name": "Shrug", "sprite": "idle1", "head": [0.15, 0.0], "spine": [0.0, 0.06], "lift": 0.01,
		"upperArmL": [-0.25, 0.45], "lowerArmL": [-1.3, 0], "upperArmR": [-0.25, 0.45], "lowerArmR": [-1.3, 0]},
	"bow": {"name": "Bow", "sprite": "crouch", "head": [0.0, 0.3], "spine": [0.75, 0.0],
		"upperArmL": [-0.1, 0.05], "upperArmR": [-0.1, 0.05]},
	"kneel": {"name": "Kneel", "sprite": "crouch", "lift": -0.24, "head": [0.0, 0.1],
		"upperLegL": [-1.5, 0.05], "lowerLegL": [1.5, 0], "upperLegR": [0.3, 0.05], "lowerLegR": [2.0, 0],
		"upperArmL": [-0.5, 0.1], "lowerArmL": [-0.6, 0], "upperArmR": [0.0, 0.08]},
	"victory": {"name": "Victory fist", "sprite": "cel0", "head": [0.0, -0.2],
		"upperArmR": [-2.9, 0.2], "lowerArmR": [-0.25, 0], "upperArmL": [0.15, 0.75], "lowerArmL": [-1.9, 1.5]},
	"cheer": {"name": "Both arms up", "sprite": "cel1", "head": [0.0, -0.25],
		"upperArmL": [-2.8, 0.45], "lowerArmL": [-0.2, 0], "upperArmR": [-2.8, 0.45], "lowerArmR": [-0.2, 0]},
	"surprised": {"name": "Surprised", "sprite": "hurt", "head": [0.0, -0.12], "spine": [-0.1, 0.0],
		"upperArmL": [-1.5, 0.85], "lowerArmL": [-1.3, 0], "upperArmR": [-1.5, 0.85], "lowerArmR": [-1.3, 0]},
	"scared": {"name": "Cowering", "sprite": "crouch", "lift": -0.06, "head": [0.0, 0.35], "spine": [0.35, 0.0],
		"upperArmL": [-2.0, 0.3], "lowerArmL": [-2.1, 0], "upperArmR": [-2.0, 0.3], "lowerArmR": [-2.1, 0],
		"upperLegL": [-0.4, 0.05], "lowerLegL": [0.7, 0], "upperLegR": [-0.4, 0.05], "lowerLegR": [0.7, 0]},
	"lookout": {"name": "Looking far", "sprite": "point", "head": [0.3, -0.1],
		"upperArmR": [-1.6, 0.55], "lowerArmR": [-2.0, 0]},
	"pray": {"name": "Hands together", "sprite": "idle0", "head": [0.0, 0.25],
		"upperArmL": [-0.75, 0.0], "lowerArmL": [-1.9, 0.55], "upperArmR": [-0.75, 0.0], "lowerArmR": [-1.9, 0.55]},
	"hero": {"name": "Hero stance", "sprite": "guard", "spine": [-0.06, 0.0], "head": [0.0, -0.08],
		"upperLegL": [-0.35, 0.25], "lowerLegL": [0.3, 0], "upperLegR": [0.2, 0.25],
		"upperArmL": [0.15, 0.75], "lowerArmL": [-1.9, 1.5], "upperArmR": [-0.2, 0.3], "lowerArmR": [-0.3, 0]},
}
const BUILTIN_ORDER := ["hips", "crossed", "think", "salute", "shrug", "bow", "kneel", "victory", "cheer", "surprised", "scared", "lookout", "pray", "hero"]


## A built-in pose by key ({} when unknown), with "key" set.
static func builtin(key: String) -> Dictionary:
	if not BUILTIN.has(key):
		return {}
	var p: Dictionary = (BUILTIN[key] as Dictionary).duplicate(true)
	p["key"] = key
	return p


## The pose's angle for `slot` as a Vector2 (zero when it doesn't set it).
static func joint(p: Dictionary, slot: String) -> Vector2:
	var v: Variant = p.get(slot)
	if v is Array and (v as Array).size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is Vector2:
		return v
	return Vector2.ZERO


static func set_joint(p: Dictionary, slot: String, v: Vector2) -> void:
	p[slot] = [snappedf(v.x, 0.01), snappedf(v.y, 0.01)]
	p.erase("sprite")


## Left and right swapped (head turn and body lean flip too).
static func mirrored(p: Dictionary) -> Dictionary:
	var out := p.duplicate(true)
	for s in JOINTS:
		if s.ends_with("L") or s.ends_with("R"):
			var other: String = s.left(s.length() - 1) + ("R" if s.ends_with("L") else "L")
			if p.has(other):
				out[s] = (p[other] as Array).duplicate()
			else:
				out.erase(s)
	for s in ["head", "spine"]:
		if p.has(s):
			out[s] = [-float(p[s][0]), float(p[s][1])] if s == "head" else [float(p[s][0]), -float(p[s][1])]
	return out


## The sprite frame a Pixel 2D character shows for this pose.
static func sprite_frame(p: Dictionary) -> String:
	if p.has("sprite"):
		return str(p["sprite"])
	var al := joint(p, "upperArmL")
	var ar := joint(p, "upperArmR")
	var ll := joint(p, "upperLegL")
	var lr := joint(p, "upperLegR")
	if minf(ll.x, lr.x) < -1.1 and float(p.get("lift", 0.0)) < -0.15:
		return "sit"
	if float(p.get("lift", 0.0)) < -0.05 or joint(p, "spine").x > 0.4:
		return "crouch"
	if al.x < -2.2 and ar.x < -2.2:
		return "cel1"
	if al.x < -2.2 or ar.x < -2.2:
		return "cel0"
	if al.x < -1.2 or ar.x < -1.2:
		return "point"
	return "idle0"


# ---------------------------------------------------------------- library

## Saved poses, oldest first.
static func library() -> Array:
	if not FileAccess.file_exists(FILE):
		return []
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if not d is Array:
		return []
	return (d as Array).filter(func(x): return x is Dictionary and x.has("name"))


static func _write(arr: Array) -> bool:
	DirAccess.make_dir_recursive_absolute(FILE.get_base_dir())
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(arr))
	return true


## Saves `p` under `name` (replacing a saved pose of the same name).
static func save_pose(name: String, p: Dictionary) -> bool:
	var n := name.strip_edges().left(32)
	if n == "":
		return false
	var lib := library().filter(func(x): return str(x["name"]).to_lower() != n.to_lower())
	var q := p.duplicate(true)
	q.erase("key")
	q["name"] = n
	lib.append(q)
	return _write(lib)


static func delete_pose(name: String) -> bool:
	return _write(library().filter(func(x): return str(x["name"]) != name))
