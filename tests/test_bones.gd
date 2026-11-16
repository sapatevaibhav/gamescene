extends Node
## Bone-name matching across common rig conventions.

const RIGS := {
	"Mixamo": ["mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Neck", "mixamorig_Head", "mixamorig_LeftShoulder", "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_RightShoulder", "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_RightUpLeg", "mixamorig_RightLeg"],
	"Unreal": ["root", "pelvis", "spine_01", "spine_02", "neck_01", "head", "clavicle_l", "upperarm_l", "upperarm_twist_01_l", "lowerarm_l", "clavicle_r", "upperarm_r", "lowerarm_r", "thigh_l", "thigh_twist_01_l", "calf_l", "thigh_r", "calf_r"],
	"Unity/Godot": ["Hips", "Spine", "Chest", "Neck", "Head", "LeftShoulder", "LeftUpperArm", "LeftLowerArm", "RightShoulder", "RightUpperArm", "RightLowerArm", "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg"],
	"Blender": ["root", "hips", "spine", "chest", "neck", "head", "shoulder.L", "upper_arm.L", "forearm.L", "shoulder.R", "upper_arm.R", "forearm.R", "thigh.L", "shin.L", "thigh.R", "shin.R"],
	"Rigify": ["DEF-spine", "DEF-spine.001", "DEF-spine.006", "DEF-shoulder.L", "DEF-upper_arm.L", "DEF-upper_arm.L.001", "DEF-forearm.L", "DEF-upper_arm.R", "DEF-forearm.R", "DEF-thigh.L", "DEF-shin.L", "DEF-thigh.R", "DEF-shin.R"],
	"VRM": ["J_Bip_C_Hips", "J_Bip_C_Spine", "J_Bip_C_Chest", "J_Bip_C_Neck", "J_Bip_C_Head", "J_Bip_L_Shoulder", "J_Bip_L_UpperArm", "J_Bip_L_LowerArm", "J_Bip_R_UpperArm", "J_Bip_R_LowerArm", "J_Bip_L_UpperLeg", "J_Bip_L_LowerLeg", "J_Bip_R_UpperLeg", "J_Bip_R_LowerLeg"],
	"MMD (JP)": ["センター", "下半身", "上半身", "首", "頭", "左肩", "左腕", "左ひじ", "右肩", "右腕", "右ひじ", "左足", "左ひざ", "右足", "右ひざ"],
	"MMD (EN, Sketchfab)": ["_rootJoint", "Hips_02", "Spine_03", "Chest_04", "Neck_05", "Head_06", "Left shoulder_058", "Left arm_059", "Left elbow_061", "Right shoulder_080", "Right arm_081", "Right elbow_083", "Left leg_100", "Left knee_101", "Right leg_110", "Right knee_111"],
	"Daz": ["hip", "pelvis", "abdomenLower", "chestUpper", "neckLower", "head", "lCollar", "lShldrBend", "lShldrTwist", "lForearmBend", "rCollar", "rShldrBend", "rForearmBend", "lThighBend", "lThighTwist", "lShin", "rThighBend", "rShin"],
	"Character Creator": ["CC_Base_BoneRoot", "CC_Base_Hip", "CC_Base_Pelvis", "CC_Base_Waist", "CC_Base_Spine01", "CC_Base_Head", "CC_Base_L_Clavicle", "CC_Base_L_Upperarm", "CC_Base_L_Forearm", "CC_Base_R_Upperarm", "CC_Base_R_Forearm", "CC_Base_L_Thigh", "CC_Base_L_Calf", "CC_Base_R_Thigh", "CC_Base_R_Calf"],
	"Valve": ["ValveBiped.Bip01_Pelvis", "ValveBiped.Bip01_Spine", "ValveBiped.Bip01_Head1", "ValveBiped.Bip01_L_Clavicle", "ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_R_Calf"],
	"3ds Max Biped": ["Bip001", "Bip001 Pelvis", "Bip001 Spine", "Bip001 Neck", "Bip001 Head", "Bip001 L Clavicle", "Bip001 L UpperArm", "Bip001 L Forearm", "Bip001 R Clavicle", "Bip001 R UpperArm", "Bip001 R Forearm", "Bip001 L Thigh", "Bip001 L Calf", "Bip001 R Thigh", "Bip001 R Calf"],
}

const EXPECT := {
	"upperArmL": ["leftarm", "upperarm_l", "leftupperarm", "upper_arm_l", "def-upper_arm_l", "j_bip_l_upperarm", "左腕", "leftarm", "lshldrbend", "cc_base_l_upperarm", "valvebiped_bip01_l_upperarm", "bip001lupperarm"],
	"upperLegL": ["leftupleg", "thigh_l", "leftupperleg", "thigh_l", "def-thigh_l", "j_bip_l_upperleg", "左足", "leftleg", "lthighbend", "cc_base_l_thigh", "valvebiped_bip01_l_thigh", "bip001lthigh"],
}


func _ready() -> void:
	var fails := 0
	var k := 0
	for rig_name in RIGS:
		var sk := Skeleton3D.new()
		for n in RIGS[rig_name]:
			sk.add_bone(n)
		var found := ModelRig.find_bones(sk)
		var missing := []
		for slot in ModelRig.SLOT_NAMES:
			if not found.has(slot):
				missing.append(slot)
		var wrong := []
		for slot in EXPECT:
			if found.has(slot) and ModelRig._norm_bone(sk.get_bone_name(found[slot])) != EXPECT[slot][k]:
				wrong.append("%s=%s" % [slot, sk.get_bone_name(found[slot])])
		var good := missing.is_empty() and wrong.is_empty()
		if not good:
			fails += 1
		var desc := []
		for slot in found:
			desc.append("%s:%s" % [slot, sk.get_bone_name(found[slot])])
		print("%s %-20s %s%s" % ["ok  " if good else "FAIL", rig_name, ", ".join(desc), ("  missing " + str(missing) if missing else "") + ("  wrong " + str(wrong) if wrong else "")])
		sk.free()
		k += 1
	print("FAILS: ", fails)
	await SoundDirector.hush(get_tree())
	get_tree().quit(1 if fails else 0)
