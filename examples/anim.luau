--!strict
-- The examples, built by roblox-anim-forge. From the repository root:
--   lune run examples/anim build
--   lune run examples/anim preview Strike
--   lune run examples/anim preview Gather --sweep

local process = require("@lune/process")

-- Where roblox-anim-forge lies, relative to this file (a git submodule, for instance).
local Forge = require("../src/forge")

Forge.run({
	-- The specs folder, relative to the project root (where lune runs).
	specs = Forge.loadSpecs("examples/specs", function(name)
		-- Relative to this file: a require only takes paths from the file it is written in.
		return (require)(`./specs/{name}`)
	end),
	output = "build/animations",
	previews = "build/previews",
	bundle = "ExampleAnimations",
}, process.args)
