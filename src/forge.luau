--!strict
-- The command line of roblox-anim-forge, run from a project's own runner (templates/anim.luau),
-- which hands it the project's specs and where to write. Commands:
--   build [name]                 every spec (or one) into <output>/<name>.rbxm, plus every one
--                                together in <output>/<bundle>.rbxm; prints each key's check line
--   preview <name> [frame ...]   a PNG contact sheet in <previews>/<name>.png (the keys by default)
--   preview <name> --sweep       checks every frame, prints only the wrong ones
--   publish <name> [name ...]    uploads the built .rbxm through Open Cloud, prints each asset id
--   list                         the specs it knows

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local Build = require("./build")
local Canvas = require("./canvas")
local Preview = require("./preview")
local Publish = require("./publish")

export type Spec = Build.Spec

export type Project = {
	-- Every spec, by name (its `name` field).
	specs: { [string]: Spec },
	-- Where the .rbxm files go (e.g. "assets/animations").
	output: string,
	-- Where the PNG previews go (e.g. "build/previews").
	previews: string,
	-- The file holding every animation in one folder, to insert them all in Studio at once.
	bundle: string,
}

local Forge = {}

local function fail(message: string): never
	print(`[anim-forge] {message}`)
	process.exit(1)
	error("unreachable")
end

local function ensureDir(path: string)
	if not fs.isDir(path) then
		fs.writeDir(path)
	end
end

local function specNamed(project: Project, name: string?): Spec
	if name == nil then
		return fail("missing the name of a spec (try: list)")
	end
	local spec = project.specs[name]
	if spec == nil then
		return fail(`no spec named {name} (try: list)`)
	end
	return spec
end

local function sortedNames(project: Project): { string }
	local names: { string } = {}
	for name in project.specs do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

local function build(project: Project, only: string?)
	ensureDir(project.output)
	local bundle = roblox.Instance.new("Folder")
	bundle.Name = project.bundle
	for _, name in sortedNames(project) do
		if only == nil or only == name then
			local spec = project.specs[name]
			local sequence = Build.sequence(spec)
			fs.writeFile(`{project.output}/{spec.name}.rbxm`, roblox.serializeModel({ sequence }))
			for _, line in Build.report(spec, #sequence:GetChildren()) do
				print(line)
			end
			sequence.Parent = bundle
		end
	end
	if only == nil then
		fs.writeFile(`{project.output}/{project.bundle}.rbxm`, roblox.serializeModel({ bundle }))
		print(`{project.bundle}.rbxm: {#bundle:GetChildren()} animations in one folder`)
	elseif #bundle:GetChildren() == 0 then
		fail(`no spec named {only} (try: list)`)
	end
end

local function preview(project: Project, args: { string })
	local spec = specNamed(project, args[2])
	local sequence = Build.sequence(spec)
	if args[3] == "--sweep" then
		local lines = Preview.sweep(spec, sequence)
		for _, line in lines do
			print(line)
		end
		print(
			if #lines == 0
				then `[anim-forge] {spec.name}: every frame clean`
				else `[anim-forge] {spec.name}: see the frames above`
		)
		return
	end
	local frames: { number } = {}
	for index = 3, #args do
		table.insert(frames, tonumber(args[index]) or fail(`not a frame: {args[index]}`))
	end
	local canvas, lines = Preview.sheet(spec, sequence, frames)
	for _, line in lines do
		print(line)
	end
	ensureDir(project.previews)
	local path = `{project.previews}/{spec.name}.png`
	Canvas.save(canvas, path)
	print(`[anim-forge] {path}`)
end

local function publish(project: Project, args: { string })
	if #args < 2 then
		fail("missing the names of the animations to publish")
	end
	for index = 2, #args do
		local name = args[index]
		specNamed(project, name)
		local ok, result = pcall(Publish.animation, `{project.output}/{name}.rbxm`, name)
		if not ok then
			fail(tostring(result))
		end
		print(`{name} = "rbxassetid://{result}"`)
	end
end

-- Runs the command in `args` (process.args of the runner) on `project`.
function Forge.run(project: Project, args: { string })
	local command = args[1]
	if command == "build" then
		build(project, args[2])
	elseif command == "preview" then
		preview(project, args)
	elseif command == "publish" then
		publish(project, args)
	elseif command == "list" then
		for _, name in sortedNames(project) do
			print(name)
		end
	else
		fail("usage: build [name] | preview <name> [frame ...] | preview <name> --sweep | publish <name> ... | list")
	end
end

-- Every spec in `directory` (one module per file, named after it), loaded by `load` (the runner's
-- own require, so the paths stay relative to the project).
function Forge.loadSpecs(directory: string, load: (name: string) -> Spec): { [string]: Spec }
	local specs: { [string]: Spec } = {}
	for _, file in fs.readDir(directory) do
		local name = string.match(file, "^(.+)%.luau$")
		if name then
			local spec = load(name)
			if spec.name ~= name then
				fail(`{directory}/{file}: its name field is "{spec.name}", not "{name}"`)
			end
			specs[name] = spec
		end
	end
	return specs
end

return table.freeze(Forge)
