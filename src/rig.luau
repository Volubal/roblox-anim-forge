--!strict
-- The R15 rig the generated animations are made for: where each joint sits on its parent part,
-- the size of each part, and where every part is for a pose (forward kinematics). Shared by the
-- build (its checks: heights, where the held item points) and the preview (its drawings), so both
-- see the same body. Rough R15 proportions in studs: avatars differ, this is a guide.
--
-- Every joint has no rotation at rest. A pose gives each animated joint a rotation in degrees in
-- its own frame (see build.luau), and for the pelvis an offset in studs. The right hand may hold an
-- item (a wand, a sword, a tool): it is held at HELD_GRIP and points along the hand's -Z axis.

local roblox = require("@lune/roblox")

local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

export type Rotation = { x: number?, y: number?, z: number?, px: number?, py: number?, pz: number? }
-- A joint's rotation in degrees, or straight as a CFrame (a pose interpolated between two keys).
export type Pose = { [string]: Rotation | any }

-- A part: its parent, where its joint sits in the parent's joint frame, and its box (centre in its
-- own joint frame, size).
type Part = {
	parent: string?,
	joint: any,
	center: any,
	size: any,
}

local Rig = {}

-- The pelvis (the root joint) stands this high when the feet are flat on the ground.
Rig.PELVIS_HEIGHT = 2.45
-- From the neck to the head's centre.
Rig.HEAD_CENTER = Vector3.new(0, 0.6, 0)
-- Where an item is held in the right hand's frame, which way it points (the hand's -Z) and how long
-- it is drawn in previews.
Rig.HELD_GRIP = Vector3.new(0, -0.25, 0)
Rig.HELD_LENGTH = 1.4

local PARTS: { [string]: Part } = {
	LowerTorso = {
		parent = nil,
		joint = CFrame.new(0, Rig.PELVIS_HEIGHT, 0),
		center = Vector3.new(0, 0, 0),
		size = Vector3.new(2, 0.4, 1),
	},
	UpperTorso = {
		parent = "LowerTorso",
		joint = CFrame.new(0, 0.2, 0),
		center = Vector3.new(0, 0.8, 0),
		size = Vector3.new(2, 1.6, 1),
	},
	Head = {
		parent = "UpperTorso",
		joint = CFrame.new(0, 1.6, 0),
		center = Rig.HEAD_CENTER,
		size = Vector3.new(1.2, 1.2, 1.2),
	},
	RightUpperArm = {
		parent = "UpperTorso",
		joint = CFrame.new(1.5, 1.25, 0),
		center = Vector3.new(0, -0.42, 0),
		size = Vector3.new(0.95, 1.15, 0.95),
	},
	RightLowerArm = {
		parent = "RightUpperArm",
		joint = CFrame.new(0, -1, 0),
		center = Vector3.new(0, -0.5, 0),
		size = Vector3.new(0.9, 1, 0.9),
	},
	RightHand = {
		parent = "RightLowerArm",
		joint = CFrame.new(0, -1, 0),
		center = Vector3.new(0, -0.2, 0),
		size = Vector3.new(0.85, 0.4, 0.85),
	},
	LeftUpperArm = {
		parent = "UpperTorso",
		joint = CFrame.new(-1.5, 1.25, 0),
		center = Vector3.new(0, -0.42, 0),
		size = Vector3.new(0.95, 1.15, 0.95),
	},
	LeftLowerArm = {
		parent = "LeftUpperArm",
		joint = CFrame.new(0, -1, 0),
		center = Vector3.new(0, -0.5, 0),
		size = Vector3.new(0.9, 1, 0.9),
	},
	LeftHand = {
		parent = "LeftLowerArm",
		joint = CFrame.new(0, -1, 0),
		center = Vector3.new(0, -0.2, 0),
		size = Vector3.new(0.85, 0.4, 0.85),
	},
	RightUpperLeg = {
		parent = "LowerTorso",
		joint = CFrame.new(0.5, -0.2, 0),
		center = Vector3.new(0, -0.5, 0),
		size = Vector3.new(0.95, 1.05, 0.95),
	},
	RightLowerLeg = {
		parent = "RightUpperLeg",
		joint = CFrame.new(0, -1, 0),
		center = Vector3.new(0, -0.5, 0),
		size = Vector3.new(0.9, 1, 0.9),
	},
	RightFoot = {
		parent = "RightLowerLeg",
		joint = CFrame.new(0, -1, 0),
		center = Vector3.new(0, -0.125, -0.15),
		size = Vector3.new(0.9, 0.25, 1.2),
	},
	LeftUpperLeg = {
		parent = "LowerTorso",
		joint = CFrame.new(-0.5, -0.2, 0),
		center = Vector3.new(0, -0.5, 0),
		size = Vector3.new(0.95, 1.05, 0.95),
	},
	LeftLowerLeg = {
		parent = "LeftUpperLeg",
		joint = CFrame.new(0, -1, 0),
		center = Vector3.new(0, -0.5, 0),
		size = Vector3.new(0.9, 1, 0.9),
	},
	LeftFoot = {
		parent = "LeftLowerLeg",
		joint = CFrame.new(0, -1, 0),
		center = Vector3.new(0, -0.125, -0.15),
		size = Vector3.new(0.9, 0.25, 1.2),
	},
}

-- Every part, parents before children.
Rig.ORDER = {
	"LowerTorso",
	"UpperTorso",
	"Head",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
}

-- Parent of each part, up to the root (HumanoidRootPart, which no pose moves).
Rig.PARENT = {
	LowerTorso = "HumanoidRootPart",
} :: { [string]: string }
for name, part in PARTS do
	if part.parent then
		Rig.PARENT[name] = part.parent
	end
end

-- A joint's rotation (and the pelvis's offset) as a CFrame.
function Rig.rotationOf(rotation: (Rotation | any)?): any
	if typeof(rotation) == "CFrame" then
		return rotation
	end
	local r = rotation or {}
	return CFrame.new(r.px or 0, r.py or 0, r.pz or 0)
		* CFrame.Angles(math.rad(r.x or 0), math.rad(r.y or 0), math.rad(r.z or 0))
end

-- Every part's joint frame for `pose`, in character space: X to the character's right, Y up, -Z
-- ahead, the ground at Y = 0 under the feet at rest.
function Rig.frames(pose: Pose): { [string]: any }
	local frames: { [string]: any } = {}
	for _, name in Rig.ORDER do
		local part = PARTS[name]
		local parentFrame = if part.parent then frames[part.parent] else CFrame.new()
		frames[name] = parentFrame * part.joint * Rig.rotationOf(pose[name])
	end
	return frames
end

-- Each part's box for `pose`: its frame (at the box's centre) and its size.
function Rig.boxes(pose: Pose): { [string]: { cframe: any, size: any } }
	local boxes = {}
	for name, frame in Rig.frames(pose) do
		local part = PARTS[name]
		boxes[name] = { cframe = frame * CFrame.new(part.center), size = part.size }
	end
	return boxes
end

-- Where the right hand's item is held, and which way it points (unit vector), for `pose`.
function Rig.held(pose: Pose): (any, any)
	local hand = Rig.frames(pose).RightHand
	return hand:PointToWorldSpace(Rig.HELD_GRIP), hand:VectorToWorldSpace(Vector3.new(0, 0, -1))
end

return Rig
