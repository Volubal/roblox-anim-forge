--!strict
-- A tiny raster canvas for tool previews: filled convex polygons, thick lines, discs, a 5 x 7 pixel
-- font, saved as a PNG. Pure Luau on Lune (no image library to install).

local fs = require("@lune/fs")
local serde = require("@lune/serde")

export type Color = { number }

export type Canvas = {
	width: number,
	height: number,
	pixels: buffer,
}

local Canvas = {}

function Canvas.new(width: number, height: number, background: Color): Canvas
	local pixels = buffer.create(width * height * 3)
	for index = 0, width * height - 1 do
		buffer.writeu8(pixels, index * 3, background[1])
		buffer.writeu8(pixels, index * 3 + 1, background[2])
		buffer.writeu8(pixels, index * 3 + 2, background[3])
	end
	return { width = width, height = height, pixels = pixels }
end

local function set(canvas: Canvas, x: number, y: number, color: Color)
	if x < 0 or y < 0 or x >= canvas.width or y >= canvas.height then
		return
	end
	local offset = (y * canvas.width + x) * 3
	buffer.writeu8(canvas.pixels, offset, color[1])
	buffer.writeu8(canvas.pixels, offset + 1, color[2])
	buffer.writeu8(canvas.pixels, offset + 2, color[3])
end

-- Fills the rectangle from (x, y), `width` by `height` pixels.
function Canvas.rect(canvas: Canvas, x: number, y: number, width: number, height: number, color: Color)
	for row = math.floor(y), math.floor(y + height) - 1 do
		for column = math.floor(x), math.floor(x + width) - 1 do
			set(canvas, column, row, color)
		end
	end
end

-- Fills a convex polygon (points in pixels, { x, y }), scanline by scanline.
function Canvas.polygon(canvas: Canvas, points: { { number } }, color: Color)
	local top, bottom = math.huge, -math.huge
	for _, point in points do
		top = math.min(top, point[2])
		bottom = math.max(bottom, point[2])
	end
	for row = math.max(0, math.ceil(top - 0.5)), math.min(canvas.height - 1, math.floor(bottom - 0.5)) do
		local y = row + 0.5
		local left, right = math.huge, -math.huge
		for index, a in points do
			local b = points[index % #points + 1]
			if (a[2] <= y and b[2] > y) or (b[2] <= y and a[2] > y) then
				local x = a[1] + (y - a[2]) / (b[2] - a[2]) * (b[1] - a[1])
				left = math.min(left, x)
				right = math.max(right, x)
			end
		end
		if left <= right then
			for column = math.max(0, math.ceil(left - 0.5)), math.min(canvas.width - 1, math.floor(right - 0.5)) do
				set(canvas, column, row, color)
			end
		end
	end
end

-- A disc of `radius` pixels around (x, y).
function Canvas.disc(canvas: Canvas, x: number, y: number, radius: number, color: Color)
	for row = math.floor(y - radius), math.ceil(y + radius) do
		for column = math.floor(x - radius), math.ceil(x + radius) do
			if (column - x) ^ 2 + (row - y) ^ 2 <= radius * radius then
				set(canvas, column, row, color)
			end
		end
	end
end

-- A line `width` pixels thick from (x1, y1) to (x2, y2).
function Canvas.line(canvas: Canvas, x1: number, y1: number, x2: number, y2: number, width: number, color: Color)
	local length = math.max(math.abs(x2 - x1), math.abs(y2 - y1))
	local steps = math.max(1, math.ceil(length))
	for step = 0, steps do
		local t = step / steps
		Canvas.disc(canvas, x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, width / 2, color)
	end
end

-- 5 x 7 glyphs, one string of five characters per row ("#" lit).
local GLYPHS: { [string]: { string } } = {
	["0"] = { ".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###." },
	["1"] = { "..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###." },
	["2"] = { ".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####" },
	["3"] = { "####.", "....#", "....#", ".###.", "....#", "....#", "####." },
	["4"] = { "...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#." },
	["5"] = { "#####", "#....", "####.", "....#", "....#", "#...#", ".###." },
	["6"] = { "..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###." },
	["7"] = { "#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..." },
	["8"] = { ".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###." },
	["9"] = { ".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.." },
	A = { ".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#" },
	B = { "####.", "#...#", "#...#", "####.", "#...#", "#...#", "####." },
	C = { ".###.", "#...#", "#....", "#....", "#....", "#...#", ".###." },
	D = { "####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####." },
	E = { "#####", "#....", "#....", "####.", "#....", "#....", "#####" },
	F = { "#####", "#....", "#....", "####.", "#....", "#....", "#...." },
	G = { ".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####" },
	H = { "#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#" },
	I = { ".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###." },
	J = { "..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.." },
	K = { "#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#" },
	L = { "#....", "#....", "#....", "#....", "#....", "#....", "#####" },
	M = { "#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#" },
	N = { "#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#" },
	O = { ".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###." },
	P = { "####.", "#...#", "#...#", "####.", "#....", "#....", "#...." },
	Q = { ".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#" },
	R = { "####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#" },
	S = { ".####", "#....", "#....", ".###.", "....#", "....#", "####." },
	T = { "#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.." },
	U = { "#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###." },
	V = { "#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.." },
	W = { "#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#." },
	X = { "#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#" },
	Y = { "#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.." },
	Z = { "#####", "....#", "...#.", "..#..", ".#...", "#....", "#####" },
	["/"] = { "....#", "....#", "...#.", "..#..", ".#...", "#....", "#...." },
	[":"] = { ".....", "..#..", "..#..", ".....", "..#..", "..#..", "....." },
	["-"] = { ".....", ".....", ".....", "#####", ".....", ".....", "....." },
	["+"] = { ".....", "..#..", "..#..", "#####", "..#..", "..#..", "....." },
	["."] = { ".....", ".....", ".....", ".....", ".....", ".##..", ".##.." },
	["="] = { ".....", ".....", "#####", ".....", "#####", ".....", "....." },
	["~"] = { ".....", ".....", ".#..#", "#.##.", ".....", ".....", "....." },
	[" "] = { ".....", ".....", ".....", ".....", ".....", ".....", "....." },
}

-- Writes `text` (upper case, digits and a few signs) from (x, y), each pixel of the font `scale`
-- pixels wide. Returns the width written.
function Canvas.text(canvas: Canvas, x: number, y: number, text: string, scale: number, color: Color): number
	local cursor = x
	for index = 1, #text do
		local glyph = GLYPHS[string.upper(string.sub(text, index, index))] or GLYPHS["."]
		for row, line in glyph do
			for column = 1, 5 do
				if string.sub(line, column, column) == "#" then
					Canvas.rect(canvas, cursor + (column - 1) * scale, y + (row - 1) * scale, scale, scale, color)
				end
			end
		end
		cursor += 6 * scale
	end
	return cursor - x
end

-- PNG chunks carry a CRC-32 of their type and data.
local crcTable: { number } = {}
for n = 0, 255 do
	local c = n
	for _ = 1, 8 do
		c = if bit32.band(c, 1) ~= 0 then bit32.bxor(0xEDB88320, bit32.rshift(c, 1)) else bit32.rshift(c, 1)
	end
	crcTable[n] = c
end

local function crc32(data: string): number
	local c = 0xFFFFFFFF
	for index = 1, #data do
		c = bit32.bxor(crcTable[bit32.band(bit32.bxor(c, string.byte(data, index)), 0xFF)], bit32.rshift(c, 8))
	end
	return bit32.bxor(c, 0xFFFFFFFF)
end

local function chunk(kind: string, data: string): string
	return string.pack(">I4", #data) .. kind .. data .. string.pack(">I4", crc32(kind .. data))
end

-- Saves the canvas as an RGB PNG at `path`.
function Canvas.save(canvas: Canvas, path: string)
	local rows = table.create(canvas.height)
	local rowBytes = canvas.width * 3
	for row = 0, canvas.height - 1 do
		-- Filter type 0 (none) before each row.
		rows[row + 1] = "\0" .. buffer.readstring(canvas.pixels, row * rowBytes, rowBytes)
	end
	local header = string.pack(">I4I4BBBBB", canvas.width, canvas.height, 8, 2, 0, 0, 0)
	local png = "\137PNG\r\n\26\n"
		.. chunk("IHDR", header)
		.. chunk("IDAT", serde.compress("zlib", table.concat(rows)))
		.. chunk("IEND", "")
	fs.writeFile(path, png)
end

return Canvas
