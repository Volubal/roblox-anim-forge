--!strict
-- Draws an animation's poses on the R15 rig (rig.luau) into a PNG contact sheet, to check a pose by
-- eye before publishing it: one column per frame (its keys by default), four views per frame (front,
-- the character's right side, top, three-quarter), the right limbs red and orange, the left ones
-- blue and cyan, the front of the head and torso lighter with eyes on the face, the right hand's item
-- a yellow stroke with a white tip, the ground a grey ring. Each frame also gets a line: where the
-- item points, the heights of the pelvis, head, wrists and ankles, and what looks wrong (a part sunk
-- into another, a part under the ground), also written in red on the sheet. It draws the built
-- animation itself (flowing curves and overlap included), each joint blended between its keyframes
-- as Roblox does; a frame that is not one of the spec's keys is marked "~".

local roblox = require("@lune/roblox")

local Build = require("./build")
local Canvas = require("./canvas")
local Rig = require("./rig")

local Vector3 = roblox.Vector3

type Pose = Rig.Pose
type Spec = Build.Spec
type View = { name: string, direction: any, up: any, ground: boolean }

local FRAME_RATE = 60
-- Each view's cell, in pixels, and how many pixels a stud is.
local CELL_WIDTH = 230
local CELL_HEIGHT = 300
local SCALE = 30
local HEADER = 26
-- The ground line sits this far above the bottom of a cell.
local BASELINE = 30

local BACKGROUND = { 246, 246, 242 }
local GRID = { 205, 205, 200 }
local INK = { 40, 40, 45 }
local HELD = { 245, 200, 30 }
local TIP = { 255, 255, 255 }

local COLORS: { [string]: { number } } = {
	LowerTorso = { 150, 150, 160 },
	UpperTorso = { 185, 185, 195 },
	Head = { 235, 220, 195 },
	RightUpperArm = { 225, 70, 60 },
	RightLowerArm = { 205, 55, 50 },
	RightHand = { 150, 35, 30 },
	LeftUpperArm = { 60, 110, 225 },
	LeftLowerArm = { 50, 90, 200 },
	LeftHand = { 30, 60, 150 },
	RightUpperLeg = { 240, 145, 60 },
	RightLowerLeg = { 220, 125, 45 },
	RightFoot = { 160, 85, 30 },
	LeftUpperLeg = { 60, 185, 205 },
	LeftLowerLeg = { 45, 160, 185 },
	LeftFoot = { 30, 110, 130 },
}

-- Parts whose front (-Z) face is drawn lighter: which way the body and the face look.
local SHOWS_FRONT: { [string]: boolean } = { Head = true, UpperTorso = true, LowerTorso = true }

local function view(name: string, direction: any, ground: boolean): View
	local d = direction.Unit
	local up = if math.abs(d.Y) > 0.99 then Vector3.new(0, 0, -1) else (Vector3.yAxis - d * d.Y).Unit
	return { name = name, direction = d, up = up, ground = ground }
end

-- Looking at the character from its front, from its right side, from above (its front up), and
-- from its front right, a little above.
local VIEWS: { View } = {
	view("FRONT", Vector3.new(0, 0, 1), true),
	view("RIGHT SIDE", Vector3.new(-1, 0, 0), true),
	view("TOP", Vector3.new(0, -1, 0), false),
	view("3/4", Vector3.new(-1, -0.45, 1), true),
}

local FACES = {
	{ normal = Vector3.new(1, 0, 0), axes = { "Y", "Z" } },
	{ normal = Vector3.new(-1, 0, 0), axes = { "Y", "Z" } },
	{ normal = Vector3.new(0, 1, 0), axes = { "X", "Z" } },
	{ normal = Vector3.new(0, -1, 0), axes = { "X", "Z" } },
	{ normal = Vector3.new(0, 0, 1), axes = { "X", "Y" } },
	{ normal = Vector3.new(0, 0, -1), axes = { "X", "Y" } },
}

-- One part's keyframes in the built animation: when (in frames) and its rotation.
type Track = { { frame: number, cframe: any } }

-- The built animation, part by part: exactly what gets saved and published, with the build's
-- flowing curves and overlap.
local function tracksOf(sequence: any): { [string]: Track }
	local tracks: { [string]: Track } = {}
	for _, keyframe in sequence:GetChildren() do
		for _, pose in keyframe:GetDescendants() do
			if pose:IsA("Pose") and pose.Weight > 0 then
				local track = tracks[pose.Name]
				if track == nil then
					track = {}
					tracks[pose.Name] = track
				end
				table.insert(track, { frame = keyframe.Time * FRAME_RATE, cframe = pose.CFrame })
			end
		end
	end
	for _, track in tracks do
		table.sort(track, function(a, b)
			return a.frame < b.frame
		end)
	end
	return tracks
end

-- The pose at `frame` in the built animation: each joint between its two keyframes around it, as
-- Roblox blends them (the shortest turn from one rotation to the next), at an even pace. Whether
-- `frame` is one of the spec's keys.
local function poseAt(spec: Spec, tracks: { [string]: Track }, frame: number): (Pose, boolean)
	local pose: Pose = {}
	for part, track in tracks do
		local before, after = track[1], track[#track]
		for index = 1, #track - 1 do
			if track[index].frame <= frame and track[index + 1].frame >= frame then
				before, after = track[index], track[index + 1]
				break
			end
		end
		local span = after.frame - before.frame
		local t = if span > 0 then math.clamp((frame - before.frame) / span, 0, 1) else 0
		pose[part] = before.cframe:Lerp(after.cframe, t)
	end
	local exact = false
	for _, key in spec.keys do
		if key.frame == frame then
			exact = true
		end
	end
	return pose, exact
end

type Face = { points: { { number } }, depth: number, color: { number } }

local function shade(color: { number }, light: number): { number }
	return {
		math.clamp(math.floor(color[1] * light), 0, 255),
		math.clamp(math.floor(color[2] * light), 0, 255),
		math.clamp(math.floor(color[3] * light), 0, 255),
	}
end

-- Draws `pose` seen through `v` into the cell whose top left corner is (left, top).
local function drawCell(canvas: Canvas.Canvas, pose: Pose, v: View, left: number, top: number)
	local right = v.direction:Cross(v.up)
	local originX = left + CELL_WIDTH / 2
	local originY = if v.ground then top + CELL_HEIGHT - BASELINE else top + CELL_HEIGHT / 2
	local function project(point: any): { number }
		return { originX + point:Dot(right) * SCALE, originY - point:Dot(v.up) * SCALE }
	end

	if v.ground then
		-- The ground: a ring around the feet (a line seen edge on).
		local previous = project(Vector3.new(2.5, 0, 0))
		for step = 1, 48 do
			local angle = step / 48 * 2 * math.pi
			local point = project(Vector3.new(math.cos(angle) * 2.5, 0, math.sin(angle) * 2.5))
			Canvas.line(canvas, previous[1], previous[2], point[1], point[2], 2, GRID)
			previous = point
		end
	else
		-- From above: a cross where the character stands, its front pointing up.
		local center = project(Vector3.zero)
		Canvas.line(canvas, center[1] - 40, center[2], center[1] + 40, center[2], 1, GRID)
		Canvas.line(canvas, center[1], center[2] - 60, center[1], center[2] + 40, 1, GRID)
		Canvas.text(canvas, center[1] - 8, center[2] - 74, "FWD", 1, GRID)
	end

	local faces: { Face } = {}
	for part, box in Rig.boxes(pose) do
		local frame = box.cframe
		local half = box.size / 2
		for _, face in FACES do
			local normal = frame:VectorToWorldSpace(face.normal)
			local facing = -normal:Dot(v.direction)
			if facing <= 0 then
				continue
			end
			local offset = face.normal * half
			local axisA = if face.axes[1] == "X" then Vector3.new(half.X, 0, 0) else Vector3.new(0, half.Y, 0)
			local axisB = if face.axes[2] == "Z" then Vector3.new(0, 0, half.Z) else Vector3.new(0, half.Y, 0)
			local corners = {
				offset + axisA + axisB,
				offset - axisA + axisB,
				offset - axisA - axisB,
				offset + axisA - axisB,
			}
			local points = {}
			for index, corner in corners do
				points[index] = project(frame:PointToWorldSpace(corner))
			end
			local isFront = SHOWS_FRONT[part] and face.normal.Z < 0
			local base = COLORS[part] or { 200, 200, 200 }
			if isFront then
				base = shade(base, 1.18)
			end
			table.insert(faces, {
				points = points,
				depth = frame:PointToWorldSpace(offset):Dot(v.direction),
				color = shade(base, 0.6 + 0.4 * facing),
			})
			if isFront and part == "Head" then
				-- The eyes, on the face.
				for _, side in { -0.25, 0.25 } do
					local eye = project(frame:PointToWorldSpace(Vector3.new(side, 0.12, -half.Z)))
					table.insert(faces, {
						points = { eye },
						depth = frame:PointToWorldSpace(offset):Dot(v.direction) - 0.01,
						color = INK,
					})
				end
			end
		end
	end
	-- Far to near.
	table.sort(faces, function(a: Face, b: Face): boolean
		return a.depth > b.depth
	end)
	for _, face in faces do
		if #face.points == 1 then
			Canvas.disc(canvas, face.points[1][1], face.points[1][2], 2.5, face.color)
			continue
		end
		Canvas.polygon(canvas, face.points, face.color)
		for index, a in face.points do
			local b = face.points[index % #face.points + 1]
			Canvas.line(canvas, a[1], a[2], b[1], b[2], 1, shade(face.color, 0.55))
		end
	end

	-- The right hand's item, over everything.
	local grip, direction = Rig.held(pose)
	local from = project(grip)
	local to = project(grip + direction * Rig.HELD_LENGTH)
	Canvas.line(canvas, from[1], from[2], to[1], to[2], 3, HELD)
	Canvas.disc(canvas, to[1], to[2], 3.5, TIP)
	Canvas.disc(canvas, to[1], to[2], 2, HELD)
	Canvas.text(canvas, left + 6, top + 6, v.name, 1, INK)
end

-- Parts that may touch: a part and its parent (they share a joint), and the parts of the trunk.
local function mayTouch(a: string, b: string): boolean
	return Rig.PARENT[a] == b
		or Rig.PARENT[b] == a
		or (Rig.PARENT[a] == Rig.PARENT[b] and Rig.PARENT[a] ~= "UpperTorso")
end

-- Whether `point` lies inside `box`, shrunk by `margin` studs on every side.
local function inside(point: any, box: { cframe: any, size: any }, margin: number): boolean
	local localPoint = box.cframe:PointToObjectSpace(point)
	local half = box.size / 2 - Vector3.one * margin
	return math.abs(localPoint.X) < half.X and math.abs(localPoint.Y) < half.Y and math.abs(localPoint.Z) < half.Z
end

-- What looks wrong in `pose`: a part sunk into another one (an arm through the chest, a hand in the
-- head), a part sunk into the ground. Points of a part's box well inside another box count.
local function problems(pose: Pose, airborne: boolean): { string }
	local found: { string } = {}
	local boxes = Rig.boxes(pose)
	for _, a in Rig.ORDER do
		for _, b in Rig.ORDER do
			if a == b or mayTouch(a, b) then
				continue
			end
			local boxA = boxes[a]
			local half = boxA.size / 2
			local sunk = 0
			for _, x in { -0.6, 0, 0.6 } do
				for _, y in { -0.6, 0, 0.6 } do
					for _, z in { -0.6, 0, 0.6 } do
						local point = boxA.cframe:PointToWorldSpace(Vector3.new(half.X * x, half.Y * y, half.Z * z))
						if inside(point, boxes[b], 0.12) then
							sunk += 1
						end
					end
				end
			end
			if sunk >= 3 then
				table.insert(found, `{a} IN {b}`)
			end
		end
	end
	for _, part in if airborne then {} else Rig.ORDER do
		local box = boxes[part]
		local lowest = math.huge
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					lowest = math.min(lowest, box.cframe:PointToWorldSpace(box.size / 2 * Vector3.new(x, y, z)).Y)
				end
			end
		end
		if lowest < -0.12 then
			table.insert(found, string.format("%s %.2f UNDER GROUND", part, -lowest))
		end
	end
	return found
end

-- "UP 0.97": the strongest way the held item points (ahead, back, left, right, up, down).
local function describeHeld(direction: any): string
	local options = {
		{ "AHEAD", -direction.Z },
		{ "BACK", direction.Z },
		{ "LEFT", -direction.X },
		{ "RIGHT", direction.X },
		{ "UP", direction.Y },
		{ "DOWN", -direction.Y },
	}
	table.sort(options, function(a, b)
		return a[2] > b[2]
	end)
	return string.format("%s %.2f", options[1][1], options[1][2])
end

local Preview = {}

-- The contact sheet of `spec` at `frames` (its keys when nil or empty), from its built `sequence`,
-- and one line per frame to read in the terminal.
function Preview.sheet(spec: Spec, sequence: any, frames: { number }?): (Canvas.Canvas, { string })
	local tracks = tracksOf(sequence)
	local shown: { number } = {}
	if frames and #frames > 0 then
		shown = frames
	else
		for _, key in spec.keys do
			table.insert(shown, key.frame)
		end
	end
	local lines: { string } = {}
	local canvas = Canvas.new(#shown * CELL_WIDTH, HEADER + #VIEWS * CELL_HEIGHT, BACKGROUND)
	for column, frame in shown do
		local pose, exact = poseAt(spec, tracks, frame)
		local left = (column - 1) * CELL_WIDTH
		local marker = spec.marker
		local isMarker = marker ~= nil and marker.frame == frame
		local header =
			`F{frame}{if exact then "" else " ~"}{if marker and isMarker then " " .. string.upper(marker.name) else ""}`
		Canvas.text(canvas, left + 6, 6, header, 2, INK)
		for row, v in VIEWS do
			local top = HEADER + (row - 1) * CELL_HEIGHT
			drawCell(canvas, pose, v, left, top)
			-- The cell's borders.
			Canvas.rect(canvas, left, top, CELL_WIDTH, 1, GRID)
			Canvas.rect(canvas, left, top, 1, CELL_HEIGHT, GRID)
		end

		local found = problems(pose, spec.airborne == true)
		for index, problem in found do
			Canvas.text(canvas, left + 6, HEADER + index * 10 - 2, problem, 1, { 200, 30, 30 })
		end

		local framesOf = Rig.frames(pose)
		local _, direction = Rig.held(pose)
		table.insert(
			lines,
			string.format(
				"%s  item %s  pelvis %.2f  head %.2f  wrists R %.2f L %.2f  ankles R %.2f L %.2f",
				header,
				describeHeld(direction),
				framesOf.LowerTorso.Position.Y,
				framesOf.Head:PointToWorldSpace(Rig.HEAD_CENTER).Y,
				framesOf.RightHand.Position.Y,
				framesOf.LeftHand.Position.Y,
				framesOf.RightFoot.Position.Y,
				framesOf.LeftFoot.Position.Y
			)
		)
		for _, problem in found do
			table.insert(lines, `    ! {problem}`)
		end
	end
	return canvas, lines
end

-- Every frame of `spec` (between the keys too) checked without drawing, from its built `sequence`:
-- one line per frame where something looks wrong (a part going through another or into the ground on
-- the way from one key to the next). Empty when every frame is clean.
function Preview.sweep(spec: Spec, sequence: any): { string }
	local tracks = tracksOf(sequence)
	local lines: { string } = {}
	for frame = 0, spec.length do
		local pose, exact = poseAt(spec, tracks, frame)
		local found = problems(pose, spec.airborne == true)
		if #found > 0 then
			table.insert(lines, `F{frame}{if exact then "" else " ~"}  {table.concat(found, ", ")}`)
		end
	end
	return lines
end

return table.freeze(Preview)
