--!strict
-- Hit: the chest and head jolt back, stay there a moment so the hit reads, then rebound. Torso and
-- head only, so the arms keep doing what they were doing.

return {
	name = "HitReact",
	length = 18,
	keys = {
		{ frame = 0, ease = "Out", pose = { UpperTorso = { x = 0, y = 0 }, Head = { x = 0, y = 0 } } },
		{ frame = 2, ease = "InOut", pose = { UpperTorso = { x = 10, y = -5 }, Head = { x = 10, y = 4 } } },
		{ frame = 7, ease = "InOut", pose = { UpperTorso = { x = 11, y = -6 }, Head = { x = 9, y = 5 } } },
		{ frame = 12, ease = "InOut", pose = { UpperTorso = { x = -3, y = 1 }, Head = { x = -4, y = 0 } } },
		{ frame = 18, ease = "Linear", pose = { UpperTorso = { x = 0, y = 0 }, Head = { x = 0, y = 0 } } },
	},
}
