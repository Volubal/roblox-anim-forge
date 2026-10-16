--!strict
-- Gathering a plant (one second): the gatherer drops onto the right knee, leans over the plant,
-- reaches down with the left hand (the right one keeps its item, held aside), plucks it with a
-- short pull, brings it up to the chest and stands back up. Whole body, flowing, with overlap.

local STAND = {
	LowerTorso = { x = 0, py = 0 },
	UpperTorso = { x = 0 },
	Head = { x = 0 },
	RightUpperArm = { x = 10, z = 4 },
	RightLowerArm = { x = 15 },
	RightHand = { x = -10 },
	LeftUpperArm = { x = 8, z = -4 },
	LeftLowerArm = { x = 12 },
	LeftHand = { x = 0 },
	RightUpperLeg = { x = 0 },
	RightLowerLeg = { x = 0 },
	RightFoot = { x = 0 },
	LeftUpperLeg = { x = 0 },
	LeftLowerLeg = { x = 0 },
	LeftFoot = { x = 0 },
}

-- Halfway down: the left foot planted, the right one stepping back onto its toes (as Kneel).
local GOING_DOWN = {
	LowerTorso = { x = 0, py = -0.4 },
	UpperTorso = { x = -12 },
	Head = { x = -14 },
	RightUpperArm = { x = 12, z = 10 },
	RightLowerArm = { x = 22 },
	RightHand = { x = -15 },
	LeftUpperArm = { x = 25, z = -6 },
	LeftLowerArm = { x = 15 },
	LeftHand = { x = 0 },
	RightUpperLeg = { x = 16 },
	RightLowerLeg = { x = -67 },
	RightFoot = { x = 51 },
	LeftUpperLeg = { x = 51 },
	LeftLowerLeg = { x = -67 },
	LeftFoot = { x = 16 },
}

-- On the right knee, leaning over the plant, the left hand down on it, the eyes on it.
local REACH = {
	LowerTorso = { x = 0, py = -0.8 },
	UpperTorso = { x = -42 },
	Head = { x = -14 },
	-- The held item kept up, off the ground.
	RightUpperArm = { x = 18, z = 12 },
	RightLowerArm = { x = 55 },
	RightHand = { x = -25 },
	-- Down ahead, past the raised left knee, to the plant on the ground.
	LeftUpperArm = { x = 58, z = -8 },
	LeftLowerArm = { x = 6 },
	LeftHand = { x = -15 },
	RightUpperLeg = { x = -8 },
	RightLowerLeg = { x = -82 },
	-- The toes tucked under, on the ground, ready to push back up.
	RightFoot = { x = 80 },
	LeftUpperLeg = { x = 80 },
	LeftLowerLeg = { x = -80 },
	LeftFoot = { x = 0 },
}

-- The pluck: a short pull up, the elbow bending, the shoulders following.
local PLUCK = table.clone(REACH)
PLUCK.UpperTorso = { x = -34 }
PLUCK.Head = { x = -14 }
PLUCK.LeftUpperArm = { x = 52, z = -8 }
PLUCK.LeftLowerArm = { x = 55 }
PLUCK.LeftHand = { x = 10 }

-- Pushing back up on the left leg, the plant held up to the chest.
local RISING = {
	LowerTorso = { x = 0, py = -0.38 },
	UpperTorso = { x = -8 },
	Head = { x = -6 },
	RightUpperArm = { x = 12, z = 8 },
	RightLowerArm = { x = 20 },
	RightHand = { x = -15 },
	LeftUpperArm = { x = 30, z = -10 },
	LeftLowerArm = { x = 95 },
	LeftHand = { x = 10 },
	RightUpperLeg = { x = 15 },
	RightLowerLeg = { x = -75 },
	-- On its toes, the heel up, about to stand.
	RightFoot = { x = 60 },
	LeftUpperLeg = { x = 50 },
	LeftLowerLeg = { x = -55 },
	LeftFoot = { x = 5 },
}

return {
	name = "Gather",
	length = 60,
	-- One continuous movement down, the pluck and back up, never stopping on a key.
	flow = true,
	keys = {
		{ frame = 0, pose = STAND },
		{ frame = 9, pose = GOING_DOWN },
		{ frame = 18, pose = REACH },
		{ frame = 30, pose = PLUCK },
		{ frame = 46, pose = RISING },
		{ frame = 60, pose = STAND },
	},
	-- The hips lead: the chest follows, then the head and the arms, the hands last.
	overlap = {
		after = 0,
		lags = {
			UpperTorso = 2,
			Head = 4,
			RightUpperArm = 3,
			RightLowerArm = 5,
			RightHand = 6,
			LeftUpperArm = 3,
			LeftLowerArm = 5,
			LeftHand = 7,
		},
	},
}
