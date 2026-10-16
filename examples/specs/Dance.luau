--!strict
-- A disco dance, looping, two beats a second. On the first beat the hips sway to the right and dip,
-- the knees bending, the right arm pointing up at the sky, the left hand on the hip; between the
-- beats the body rises and the arm sweeps down across it; on the second beat the hips sway to the
-- left and dip, the arm pointing down across the hip; then back up. The head bobs on each beat.
-- Whole body, flowing (the "impact" key lands on the beat).

type Rotation = { x: number?, y: number?, z: number?, px: number?, py: number?, pz: number? }
type Pose = { [string]: Rotation }

-- The left hand on the hip, the elbow out, the whole dance long (found with the rig).
local HAND_ON_HIP_ARM = { x = -70, y = -15, z = -80 }
local HAND_ON_HIP_FOREARM = { x = 125 }

-- A dip on a beat, the hips swayed to `side` (1: right, -1: left), the right arm at `arm`.
local function dip(side: number, arm: Pose): Pose
	local pose: Pose = {
		LowerTorso = { x = 0, y = 8 * side, z = -3 * side, py = -0.06 },
		UpperTorso = { x = -4, y = -6 * side, z = 4 * side },
		Head = { x = 8, y = 0, z = -4 * side },
		LeftUpperArm = HAND_ON_HIP_ARM,
		LeftLowerArm = HAND_ON_HIP_FOREARM,
		RightUpperLeg = { x = 14 },
		RightLowerLeg = { x = -28 },
		RightFoot = { x = 14 },
		LeftUpperLeg = { x = 14 },
		LeftLowerLeg = { x = -28 },
		LeftFoot = { x = 14 },
	}
	for part, rotation in arm do
		pose[part] = rotation
	end
	return pose
end

-- Up between two beats, the right arm at `arm`.
local function rise(arm: Pose): Pose
	local pose: Pose = {
		LowerTorso = { x = 0, y = 0, z = 0, py = 0 },
		UpperTorso = { x = 0, y = 0, z = 0 },
		Head = { x = -4, y = 0, z = 0 },
		LeftUpperArm = HAND_ON_HIP_ARM,
		LeftLowerArm = HAND_ON_HIP_FOREARM,
		RightUpperLeg = { x = 2 },
		RightLowerLeg = { x = -4 },
		RightFoot = { x = 2 },
		LeftUpperLeg = { x = 2 },
		LeftLowerLeg = { x = -4 },
		LeftFoot = { x = 2 },
	}
	for part, rotation in arm do
		pose[part] = rotation
	end
	return pose
end

-- The right arm pointing up at the sky, out to the side: raised by the side (not swung forward
-- over the top, which turns an arm inside out).
local POINT_UP: Pose = {
	RightUpperArm = { x = 20, y = 0, z = 140 },
	RightLowerArm = { x = 5 },
	RightHand = { x = -80, y = 0 },
}
-- Sweeping down across the chest.
local ACROSS: Pose = {
	RightUpperArm = { x = 80, y = 0, z = -15 },
	RightLowerArm = { x = 30 },
	RightHand = { x = -30, y = 0 },
}
-- Pointing down across the left hip.
local POINT_DOWN: Pose = {
	RightUpperArm = { x = 25, y = 0, z = -30 },
	RightLowerArm = { x = 5 },
	RightHand = { x = -45, y = 0 },
}
-- Rising back up the side.
local UP_THE_SIDE: Pose = {
	RightUpperArm = { x = 100, y = 0, z = 45 },
	RightLowerArm = { x = 20 },
	RightHand = { x = -20, y = 0 },
}

return {
	name = "Dance",
	length = 60,
	loop = true,
	flow = true,
	keys = {
		{ frame = 0, velocity = "flow", pose = dip(1, POINT_UP) },
		{ frame = 15, pose = rise(ACROSS) },
		{ frame = 30, velocity = "impact", pose = dip(-1, POINT_DOWN) },
		{ frame = 45, pose = rise(UP_THE_SIDE) },
		{ frame = 60, velocity = "flow", pose = dip(1, POINT_UP) },
	},
}
