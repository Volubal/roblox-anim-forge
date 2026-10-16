--!strict
-- Publishes a built animation (.rbxm) to Roblox through Open Cloud (Assets API) and waits for its
-- asset id. The creator is a group (ROBLOX_GROUP_ID) or a user (ROBLOX_USER_ID).
--
-- Environment: ROBLOX_API_KEY, and ROBLOX_GROUP_ID or ROBLOX_USER_ID.
-- The API key needs the Assets API scopes asset:read and asset:write; for a group, its owner needs
-- the right to create assets for the group.

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local API_ROOT = "https://apis.roblox.com/assets/v1"
local POLL_INTERVAL_SECONDS = 2
local MAX_POLLS = 30
local BOUNDARY = "RobloxAnimForgeBoundary"

local Publish = {}

local function env(name: string): string?
	local value = process.env[name]
	return if value == nil or value == "" then nil else value
end

local function decode(response: net.FetchResponse, what: string): any
	if not response.ok then
		error(`{what} failed ({response.statusCode}): {response.body}`, 0)
	end
	return serde.decode("json", response.body)
end

-- Uploads the animation at `path` as `displayName`, then polls until Roblox gives its asset id.
function Publish.animation(path: string, displayName: string): string
	local apiKey = env("ROBLOX_API_KEY") or error("missing environment variable ROBLOX_API_KEY", 0)
	local groupId, userId = env("ROBLOX_GROUP_ID"), env("ROBLOX_USER_ID")
	local creator = if groupId then { groupId = groupId } elseif userId then { userId = userId } else nil
	if creator == nil then
		error("missing environment variable ROBLOX_GROUP_ID or ROBLOX_USER_ID (who owns the animation)", 0)
	end
	if not fs.isFile(path) then
		error(`{path} not found: build it first`, 0)
	end
	local metadata = serde.encode("json", {
		assetType = "Animation",
		displayName = displayName,
		description = displayName,
		creationContext = { creator = creator },
	})
	local fileName = string.match(path, "[^/]+$") or path
	local body = table.concat({
		`--{BOUNDARY}`,
		'Content-Disposition: form-data; name="request"',
		"Content-Type: application/json",
		"",
		metadata,
		`--{BOUNDARY}`,
		`Content-Disposition: form-data; name="fileContent"; filename="{fileName}"`,
		"Content-Type: model/x-rbxm",
		"",
		fs.readFile(path),
		`--{BOUNDARY}--`,
		"",
	}, "\r\n")
	local operation = decode(
		net.request({
			url = `{API_ROOT}/assets`,
			method = "POST",
			headers = { ["x-api-key"] = apiKey, ["Content-Type"] = `multipart/form-data; boundary={BOUNDARY}` },
			body = body,
		}),
		`uploading {displayName}`
	)
	for _ = 1, MAX_POLLS do
		if operation.done then
			local response = operation.response
			if response == nil or response.assetId == nil then
				error(`{displayName}: Roblox refused it: {serde.encode("json", operation)}`, 0)
			end
			return tostring(response.assetId)
		end
		task.wait(POLL_INTERVAL_SECONDS)
		operation = decode(
			net.request({ url = `{API_ROOT}/{operation.path}`, method = "GET", headers = { ["x-api-key"] = apiKey } }),
			`checking {displayName}`
		)
	end
	error(`{displayName}: still processing after {MAX_POLLS * POLL_INTERVAL_SECONDS} s`, 0)
end

return table.freeze(Publish)
