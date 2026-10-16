--!strict
-- This project's animations, built by roblox-anim-forge. Copy this file next to a `specs` folder
-- (one spec per file, named after it), set the paths below, then from the project root:
--   lune run <path to this file> build [name]
--   lune run <path to this file> preview <name> [frame ...] | --sweep
--   lune run <path to this file> publish <name> ...
--   lune run <path to this file> list

local process = require("@lune/process")

-- Where roblox-anim-forge lies, relative to this file (a git submodule, for instance).
local Forge = require("../anim-forge/src/forge")

Forge.run({
	-- The specs folder, relative to the project root (where lune runs).
	specs = Forge.loadSpecs("tools/animations/specs", function(name)
		-- Relative to this file: a require only takes paths from the file it is written in.
		return (require)(`./specs/{name}`)
	end),
	output = "assets/animations",
	previews = "build/previews",
	bundle = "Animations",
}, process.args)
