--!strict
-- A one-handed strike with the held item (a wand, a sword): drawn back by the right shoulder
-- (frames 0 to 4), thrust ahead in two frames (the hit lands at frame 6, the Release marker the game
-- listens for), held a moment so the strike reads, kicks up with the recoil, then lowers. Upper body
-- only: the character can strike while walking.

local READY = {
	UpperTorso = { x = 0, y = 0 },
	Head = { x = 0, y = 0 },
	RightUpperArm = { x = 35, y = 0, z = 8 },
	RightLowerArm = { x = 30 },
	RightHand = { x = -15, y = 0 },
	LeftUpperArm = { x = 12, z = -8 },
	LeftLowerArm = { x = 25 },
}

return {
	name = "Strike",
	length = 38,
	marker = { name = "Release", frame = 6 },
	keys = {
		{
			-- Starting to draw back.
			frame = 0,
			ease = "Out",
			pose = {
				UpperTorso = { x = 0, y = -4 },
				Head = { x = 0, y = 3 },
				RightUpperArm = { x = 50, y = 0, z = 10 },
				RightLowerArm = { x = 40 },
				RightHand = { x = -25, y = 0 },
				LeftUpperArm = { x = 20, z = -10 },
				LeftLowerArm = { x = 35 },
			},
		},
		{
			-- Drawn back by the shoulder, torso coiled.
			frame = 4,
			ease = "In",
			pose = {
				UpperTorso = { x = 2, y = -12 },
				Head = { x = 0, y = 10 },
				RightUpperArm = { x = 95, y = -10, z = 20 },
				RightLowerArm = { x = 45 },
				RightHand = { x = -40, y = -8 },
				LeftUpperArm = { x = 30, z = -10 },
				LeftLowerArm = { x = 40 },
			},
		},
		{
			-- Thrust: arm straight at the target, torso driving forward.
			frame = 6,
			ease = "Out",
			pose = {
				UpperTorso = { x = -8, y = 8 },
				Head = { x = 5, y = -7 },
				RightUpperArm = { x = 84, y = 0, z = 2 },
				RightLowerArm = { x = 2 },
				RightHand = { x = -72, y = 0 },
				LeftUpperArm = { x = 5, z = -16 },
				LeftLowerArm = { x = 30 },
			},
		},
		{
			-- Held, still drifting forward a little.
			frame = 14,
			ease = "InOut",
			pose = {
				UpperTorso = { x = -9, y = 9 },
				Head = { x = 6, y = -8 },
				RightUpperArm = { x = 85, y = 0, z = 1 },
				RightLowerArm = { x = 1 },
				RightHand = { x = -73, y = 0 },
				LeftUpperArm = { x = 3, z = -17 },
				LeftLowerArm = { x = 30 },
			},
		},
		{
			-- Recoil: the item kicks up.
			frame = 20,
			ease = "InOut",
			pose = {
				UpperTorso = { x = -4, y = 6 },
				Head = { x = 3, y = -5 },
				RightUpperArm = { x = 92, y = 0, z = 4 },
				RightLowerArm = { x = 10 },
				RightHand = { x = -55, y = 0 },
				LeftUpperArm = { x = 8, z = -14 },
				LeftLowerArm = { x = 32 },
			},
		},
		{ frame = 38, ease = "Linear", pose = READY },
	},
}
