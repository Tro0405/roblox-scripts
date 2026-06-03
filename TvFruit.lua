--[[
	TvFruit — Multi-Game Loader (router)
	Loadstring (unchanged):
	loadstring(game:HttpGet("https://raw.githubusercontent.com/Tro0405/roblox-scripts/main/TvFruit.lua", true))()

	Detects the PlaceId and loads the matching script from games/.
	Add a new game: create games/<name>.lua and add a line to the GAMES table below.
]]

local BASE = "https://raw.githubusercontent.com/Tro0405/roblox-scripts/main/games/"

-- [PlaceId] = "file name in games/"
local GAMES = {
	[118941584817777] = "speed_escape.lua",    -- +1 Speed Keyboard Escape
	[126884695634066] = "grow_a_garden.lua",   -- Grow a Garden (BizzyBee)
}

local function notify(text, dur)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "TvFruit Loader", Text = text, Duration = dur or 5,
		})
	end)
end

local placeId = game.PlaceId
local file = GAMES[placeId]

if not file then
	notify("This game is not supported.\nPlaceId: " .. tostring(placeId), 8)
	warn("[TvFruit] Unsupported PlaceId " .. tostring(placeId))
	return
end

local url = BASE .. file
local ok, src = pcall(function()
	return game:HttpGet(url, true)
end)

if not ok or not src or src == "" then
	notify("Failed to load script: " .. file, 8)
	warn("[TvFruit] HttpGet error: " .. tostring(src))
	return
end

local fn, err = loadstring(src)
if not fn then
	notify("loadstring error in " .. file, 8)
	warn("[TvFruit] loadstring error: " .. tostring(err))
	return
end

notify("Loaded successfully ✓", 4)
fn()
