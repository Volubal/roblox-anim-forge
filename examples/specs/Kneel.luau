--!strict
-- Defeated: drops onto the right knee, the left foot planted, head bowed and the left forearm on the
-- left knee, holds it, then gets back up (two seconds). Whole body: the pelvis lowered with py.

local STAND = {
	LowerTorso = { x = 0, py = 0 },
	UpperTorso = { x = 0 },
	Head = { x = 0 },
	RightUpperArm = { x = 10, z = 4 },
	RightLowerArm = { x = 15 },
	RightHand = { x = -10 },
	LeftUpperArm = { x = 8, z = -4 },
	LeftLowerArm = { x = 12 },
	RightUpperLeg = { x = 0 },
	RightLowerLeg = { x = 0 },
	RightFoot = { x = 0 },
	LeftUpperLeg = { x = 0 },
	LeftLowerLeg = { x = 0 },
	LeftFoot = { x = 0 },
}

local KNEEL = {
	LowerTorso = { x = 0, py = -0.8 },
	UpperTorso = { x = -12 },
	Head = { x = -18 },
	RightUpperArm = { x = 15, z = 6 },
	RightLowerArm = { x = 25 },
	RightHand = { x = -20 },
	LeftUpperArm = { x = 55, z = -6 },
	LeftLowerArm = { x = 35 },
	RightUpperLeg = { x = -8 },
	RightLowerLeg = { x = -82 },
	-- The toes tucked under, on the ground, ready to push back up.
	RightFoot = { x = 80 },
	LeftUpperLeg = { x = 80 },
	LeftLowerLeg = { x = -80 },
	LeftFoot = { x = 0 },
}

-- Halfway down: the left foot still planted, the right one stepping back onto its toes, both feet
-- kept on the ground (found with the rig).
local GOING_DOWN = table.clone(KNEEL)
GOING_DOWN.LowerTorso = { x = 0, py = -0.4 }
GOING_DOWN.UpperTorso = { x = -6 }
GOING_DOWN.Head = { x = -9 }
GOING_DOWN.RightUpperLeg = { x = 16 }
GOING_DOWN.RightLowerLeg = { x = -67 }
GOING_DOWN.RightFoot = { x = 51 }
GOING_DOWN.LeftUpperLeg = { x = 51 }
GOING_DOWN.LeftLowerLeg = { x = -67 }
GOING_DOWN.LeftFoot = { x = 16 }

-- Settled a hair lower, the breath out.
local KNEEL_SETTLED = {
	LowerTorso = { x = 0, py = -0.82 },
	UpperTorso = { x = -14 },
	Head = { x = -20 },
	RightUpperArm = { x = 14, z = 6 },
	RightLowerArm = { x = 24 },
	RightHand = { x = -20 },
	LeftUpperArm = { x = 54, z = -6 },
	LeftLowerArm = { x = 36 },
	RightUpperLeg = { x = -8 },
	RightLowerLeg = { x = -82 },
	-- The toes tucked under, on the ground, ready to push back up.
	RightFoot = { x = 80 },
	LeftUpperLeg = { x = 80 },
	LeftLowerLeg = { x = -80 },
	LeftFoot = { x = 0 },
}

-- Halfway up: pushing on the left leg.
-- Pushing back up: the right knee off the ground first, its toes still on it, the left foot planted
-- (found with the rig: nothing goes through the ground on the way up).
local PUSHING_UP = table.clone(KNEEL_SETTLED)
PUSHING_UP.LowerTorso = { x = 0, py = -0.6 }
PUSHING_UP.UpperTorso = { x = -11 }
PUSHING_UP.Head = { x = -13 }
PUSHING_UP.RightUpperLeg = { x = 13 }
PUSHING_UP.RightLowerLeg = { x = -91 }
PUSHING_UP.RightFoot = { x = 78 }
PUSHING_UP.LeftUpperLeg = { x = 63 }
PUSHING_UP.LeftLowerLeg = { x = -83 }
PUSHING_UP.LeftFoot = { x = 20 }

local RISING = {
	LowerTorso = { x = 0, py = -0.38 },
	UpperTorso = { x = -8 },
	Head = { x = -6 },
	RightUpperArm = { x = 12, z = 5 },
	RightLowerArm = { x = 20 },
	RightHand = { x = -15 },
	LeftUpperArm = { x = 30, z = -5 },
	LeftLowerArm = { x = 25 },
	RightUpperLeg = { x = 15 },
	RightLowerLeg = { x = -75 },
	-- On its toes, the heel up, about to stand.
	RightFoot = { x = 60 },
	LeftUpperLeg = { x = 50 },
	LeftLowerLeg = { x = -55 },
	LeftFoot = { x = 5 },
}

return {
	name = "Kneel",
	length = 120,
	keys = {
		{ frame = 0, ease = "In", pose = STAND },
		{ frame = 8, ease = "Out", pose = GOING_DOWN },
		{ frame = 16, ease = "InOut", pose = KNEEL },
		{ frame = 84, ease = "In", pose = KNEEL_SETTLED },
		{ frame = 94, ease = "Out", pose = PUSHING_UP },
		{ frame = 104, ease = "InOut", pose = RISING },
		{ frame = 120, ease = "Linear", pose = STAND },
	},
}
