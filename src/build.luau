--!strict
-- Builds an R15 animation from its spec: a KeyframeSequence, ready to save as a .rbxm, insert in
-- Studio and publish. A spec is plain Luau data (see reference/spec.md).
--
-- A spec lists keys at 60 frames per second. Each key gives the rotation of every animated joint,
-- in degrees, in the joint's own frame (every R15 joint used here has no rotation at rest):
--   x: pitch. A shoulder raises the arm forward, an elbow bends the forearm up, a wrist tips the
--      hand up. The waist leans back, the neck looks up.
--   y: turn around the bone. The waist and neck turn toward the character's left; a wrist rolls
--      the held item toward the left.
--   z: roll sideways. A right shoulder lifts the arm outward, a left shoulder needs a negative z.
--      The waist bends sideways, the neck tilts the head.
-- Legs: a hip's x swings the thigh forward, a knee bends with a negative x, an ankle's x lifts the
-- toes. The pelvis (LowerTorso) may also move: py lowers it (in studs, negative) to kneel or sit.
-- `ease` shapes the move from a key to the next one (cubic curves). To keep a movement flowing
-- through a key instead of stopping on it, ease In into the key and Out of it.
-- `flow` replaces those separate curves with one continuous curve through every key: the motion
-- never stops on a key unless asked to (`velocity` "stop": a hold, the start, the end; "impact":
-- it arrives at full speed and leaves along the next move, like a body hitting the ground), and
-- never overshoots a key. The build then writes a keyframe every few frames along that curve.
-- `overlap` delays parts of the body behind the pelvis on the keys after a frame: the torso
-- follows the hips, the arm the torso, the hand the arm. Without it every joint starts and stops
-- at once, which looks mechanical.
-- An item held in the right hand (a wand, a sword) points along the hand's -Z axis: arm hanging,
-- it points forward; arm raised forward, it points up. The report says where it points on each key.

local roblox = require("@lune/roblox")

local Rig = require("./rig")

local Enum = roblox.Enum
local Instance = roblox.Instance

local FRAME_RATE = 60
-- A flowing animation gets a keyframe this often, in frames.
local FLOW_SAMPLE_FRAMES = 2
local COMPONENTS = { "x", "y", "z", "px", "py", "pz" }

-- Rotation in degrees, and for the pelvis an offset in studs (px, py, pz).
export type Rotation = Rig.Rotation
export type Ease = "In" | "Out" | "InOut" | "Linear"
-- How a flowing motion passes through a key: on through it, stopping on it, or slamming into it.
export type Velocity = "flow" | "stop" | "impact"
export type Key = {
	frame: number,
	-- Required unless the spec flows.
	ease: Ease?,
	-- For a flowing spec: "flow" by default, "stop" on the first and last keys.
	velocity: Velocity?,
	pose: { [string]: Rotation },
}
export type Spec = {
	name: string,
	-- Last frame of the animation. A looping animation's last key must repeat its first one.
	length: number,
	loop: boolean?,
	marker: { name: string, frame: number }?,
	keys: { Key },
	-- Keys after `after` (but not the last one) reach each part `lags[part]` frames later.
	overlap: { after: number, lags: { [string]: number } }?,
	-- One continuous curve through every key (see the top of this file).
	flow: boolean?,
	-- Played in the air (a body lifted by the game): the preview does not check its feet against
	-- the ground.
	airborne: boolean?,
}

local Build = {
	FRAME_RATE = FRAME_RATE,
}

-- One part's rotation on a keyframe, and the curve toward its next one.
type PartKey = { rotation: Rotation, ease: Ease }

local PARENT = Rig.PARENT
local rotationOf = Rig.rotationOf

-- Height above the ground of the pelvis and of the head's centre on a key.
local function bodyHeights(key: Key): (number, number)
	local frames = Rig.frames(key.pose)
	return frames.LowerTorso.Position.Y, frames.Head:PointToWorldSpace(Rig.HEAD_CENTER).Y
end

-- Height above the ground of a wrist on a key: an arm lying on the ground should not float.
local function wristHeight(key: Key, prefix: string): number
	return Rig.frames(key.pose)[prefix .. "Hand"].Position.Y
end

-- Height above the ground of a leg's knee and ankle on a key.
local function legHeights(key: Key, prefix: string): (number, number)
	local frames = Rig.frames(key.pose)
	return frames[prefix .. "LowerLeg"].Position.Y, frames[prefix .. "Foot"].Position.Y
end

local function easingOf(ease: Ease): (any, any)
	if ease == "Linear" then
		return Enum.PoseEasingStyle.Linear, Enum.PoseEasingDirection.In
	end
	return Enum.PoseEasingStyle.CubicV2, Enum.PoseEasingDirection[ease]
end

-- Fails with what is wrong in `spec`: a part the rig does not know, keys out of order or posing
-- different parts, a last key off the last frame, a marker outside the animation, an overlap
-- running a part past its next key, a loop not ending on its first pose.
function Build.validate(spec: Spec)
	local animated: { [string]: boolean } = {}
	for _, key in spec.keys do
		for part in key.pose do
			assert(PARENT[part], `{spec.name}: unknown part {part}`)
			animated[part] = true
		end
	end
	local previous = -1
	for _, key in spec.keys do
		assert(spec.flow or key.ease, `{spec.name}: frame {key.frame} needs an ease (or the spec must flow)`)
		assert(key.frame > previous, `{spec.name}: keys must be in frame order`)
		previous = key.frame
		for part in animated do
			assert(key.pose[part], `{spec.name}: frame {key.frame} does not pose {part}`)
		end
	end
	assert(spec.keys[#spec.keys].frame == spec.length, `{spec.name}: the last key must sit on the last frame`)
	local marker = spec.marker
	if marker then
		assert(marker.frame >= 0 and marker.frame <= spec.length, `{spec.name}: marker outside the animation`)
	end
	local overlap = spec.overlap
	if overlap then
		for part in animated do
			local last = -1
			for _, key in spec.keys do
				local frame = key.frame
				if frame > overlap.after and frame < spec.length then
					frame += overlap.lags[part] or 0
				end
				assert(frame > last, `{spec.name}: the overlap of {part} runs past its next key`)
				last = frame
			end
		end
	end
	if spec.loop then
		local first, last = spec.keys[1].pose, spec.keys[#spec.keys].pose
		for part, rotation in first do
			local other = last[part]
			assert(
				other.x == rotation.x and other.y == rotation.y and other.z == rotation.z and other.py == rotation.py,
				`{spec.name}: a loop must end on its first pose ({part} differs)`
			)
		end
	end
end

-- Every keyframe of the animation: the parts keyed on each frame, once the overlap has delayed
-- some of them.
local function keyedFrames(spec: Spec): { [number]: { [string]: PartKey } }
	local frames: { [number]: { [string]: PartKey } } = {}
	local overlap = spec.overlap
	for _, key in spec.keys do
		for part, rotation in key.pose do
			local frame = key.frame
			if overlap and frame > overlap.after and frame < spec.length then
				frame += overlap.lags[part] or 0
			end
			local parts = frames[frame]
			if parts == nil then
				parts = {}
				frames[frame] = parts
			end
			parts[part] = { rotation = rotation, ease = key.ease or "Linear" }
		end
	end
	local marker = spec.marker
	if marker and frames[marker.frame] == nil then
		frames[marker.frame] = {}
	end
	return frames
end

-- One part's keys on its own timeline (the overlap delays some of them), for a flowing spec.
type Track = { frames: { number }, rotations: { Rotation }, velocities: { Velocity } }

local function tracksOf(spec: Spec): { [string]: Track }
	local tracks: { [string]: Track } = {}
	local overlap = spec.overlap
	for index, key in spec.keys do
		local velocity: Velocity = key.velocity or (if index == 1 or index == #spec.keys then "stop" else "flow")
		for part, rotation in key.pose do
			local frame = key.frame
			if overlap and frame > overlap.after and frame < spec.length then
				frame += overlap.lags[part] or 0
			end
			local track = tracks[part]
			if track == nil then
				track = { frames = {}, rotations = {}, velocities = {} }
				tracks[part] = track
			end
			table.insert(track.frames, frame)
			table.insert(track.rotations, rotation)
			table.insert(track.velocities, velocity)
		end
	end
	return tracks
end

-- How fast one component moves into and out of key `index` of a track (per frame). A flowing key
-- takes the harmonic mean of the moves on both sides, and stops where the motion turns back:
-- the curve never overshoots a key (no foot through the floor between two keys that are fine).
local function slopes(track: Track, index: number, component: string): (number, number)
	local frames = track.frames
	local velocity = track.velocities[index]
	if velocity == "stop" or #frames == 1 then
		return 0, 0
	end
	local function value(at: number): number
		return (track.rotations[at] :: any)[component] or 0
	end
	local before = if index > 1 then (value(index) - value(index - 1)) / (frames[index] - frames[index - 1]) else 0
	local after = if index < #frames then (value(index + 1) - value(index)) / (frames[index + 1] - frames[index]) else 0
	if velocity == "impact" then
		return before, after
	end
	if before * after <= 0 then
		return 0, 0
	end
	local through = 2 * before * after / (before + after)
	return through, through
end

-- The rotation of a track's part at `frame`, along its continuous curve (cubic Hermite).
local function sampleTrack(track: Track, frame: number): Rotation
	local frames = track.frames
	if frame <= frames[1] then
		return track.rotations[1]
	elseif frame >= frames[#frames] then
		return track.rotations[#frames]
	end
	local index = 1
	while frames[index + 1] < frame do
		index += 1
	end
	local span = frames[index + 1] - frames[index]
	local t = (frame - frames[index]) / span
	local t2, t3 = t * t, t * t * t
	local h00, h10 = 2 * t3 - 3 * t2 + 1, t3 - 2 * t2 + t
	local h01, h11 = -2 * t3 + 3 * t2, t3 - t2
	local from = track.rotations[index] :: any
	local to = track.rotations[index + 1] :: any
	local rotation: any = {}
	for _, component in COMPONENTS do
		if from[component] == nil and to[component] == nil then
			continue
		end
		local _, leaving = slopes(track, index, component)
		local arriving = slopes(track, index + 1, component)
		local a, b = from[component] or 0, to[component] or 0
		-- Through a local, never straight into the table (a Lune 0.10 quirk).
		local value = h00 * a + h10 * span * leaving + h01 * b + h11 * span * arriving
		rotation[component] = value
	end
	return rotation
end

-- Every keyframe of a flowing animation: one every FLOW_SAMPLE_FRAMES along the curves, plus the
-- last frame and the marker's.
local function flowingFrames(spec: Spec): { [number]: { [string]: PartKey } }
	local tracks = tracksOf(spec)
	local frames: { [number]: { [string]: PartKey } } = {}
	local function sampleAt(frame: number)
		local parts: { [string]: PartKey } = {}
		for part, track in tracks do
			parts[part] = { rotation = sampleTrack(track, frame), ease = "Linear" }
		end
		frames[frame] = parts
	end
	for frame = 0, spec.length, FLOW_SAMPLE_FRAMES do
		sampleAt(frame)
	end
	sampleAt(spec.length)
	local marker = spec.marker
	if marker then
		sampleAt(marker.frame)
	end
	return frames
end

-- A keyframe posing `parts`. Their parents not keyed on this frame get a placeholder pose
-- (weight 0) that only holds the hierarchy.
local function buildKeyframe(spec: Spec, frame: number, parts: { [string]: PartKey }): any
	local keyframe = Instance.new("Keyframe")
	keyframe.Time = frame / FRAME_RATE

	local poses: { [string]: any } = {}
	local function poseFor(part: string): any
		local existing = poses[part]
		if existing then
			return existing
		end
		local pose = Instance.new("Pose")
		pose.Name = part
		local keyed = parts[part]
		pose.CFrame = rotationOf(if keyed then keyed.rotation else nil)
		pose.Weight = if keyed then 1 else 0
		local style, direction = easingOf(if keyed then keyed.ease else "Linear")
		pose.EasingStyle = style
		pose.EasingDirection = direction
		local parent = PARENT[part]
		pose.Parent = if parent then poseFor(parent) else keyframe
		poses[part] = pose
		return pose
	end
	for part in parts do
		poseFor(part)
	end

	local marker = spec.marker
	if marker and marker.frame == frame then
		local instance = Instance.new("KeyframeMarker")
		instance.Name = marker.name
		instance.Parent = keyframe
	end
	return keyframe
end

-- Direction of the right hand's item (character space: -Z ahead, +Y up, -X left) on a key.
local function heldDirection(key: Key): any
	local _, direction = Rig.held(key.pose)
	return direction
end

-- "ahead 0.90 left 0.30 up 0.31": how much the item points ahead, to the left and up (unit vector).
local function describe(direction: any): string
	return string.format("ahead %+.2f left %+.2f up %+.2f", -direction.Z, -direction.X, direction.Y)
end

-- The animation of `spec`, checked first: a KeyframeSequence named after it.
function Build.sequence(spec: Spec): any
	Build.validate(spec)
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = spec.name
	sequence.Loop = spec.loop == true
	sequence.Priority = Enum.AnimationPriority.Action
	local frames = if spec.flow then flowingFrames(spec) else keyedFrames(spec)
	local order: { number } = {}
	for frame in frames do
		table.insert(order, frame)
	end
	table.sort(order)
	for _, frame in order do
		buildKeyframe(spec, frame, frames[frame]).Parent = sequence
	end
	return sequence
end

-- What to check by eye on each key of `spec`, one line per key after a summary: where the held item
-- points (upper body), the heights of the pelvis, head, knees, ankles and wrists (full body).
function Build.report(spec: Spec, keyframes: number): { string }
	local lines =
		{ `{spec.name}: {#spec.keys} keys, {keyframes} keyframes, {spec.length} frames ({spec.length / FRAME_RATE} s)` }
	local first = spec.keys[1].pose
	for _, key in spec.keys do
		local isMarker = spec.marker ~= nil and spec.marker.frame == key.frame
		local line = `  frame {key.frame}{if isMarker then " [marker]" else ""}:`
		if first.RightHand then
			line ..= ` item {describe(heldDirection(key))}`
		end
		if first.RightUpperLeg then
			local rightKnee, rightAnkle = legHeights(key, "Right")
			local leftKnee, leftAnkle = legHeights(key, "Left")
			local pelvis, head = bodyHeights(key)
			line ..= string.format(
				"  pelvis %.2f head %.2f, knees R %.2f L %.2f, ankles R %.2f L %.2f, wrists R %.2f L %.2f",
				pelvis,
				head,
				rightKnee,
				leftKnee,
				rightAnkle,
				leftAnkle,
				wristHeight(key, "Right"),
				wristHeight(key, "Left")
			)
		end
		table.insert(lines, line)
	end
	return lines
end

return table.freeze(Build)
