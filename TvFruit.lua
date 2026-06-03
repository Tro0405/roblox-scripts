--[[
	TvFruit — Multi-Game Loader (router)
	Loadstring giữ nguyên:
	loadstring(game:HttpGet("https://raw.githubusercontent.com/Tro0405/roblox-scripts/main/TvFruit.lua", true))()

	Tự nhận PlaceId và load script tương ứng trong thư mục games/.
	Thêm game mới: tạo games/<ten>.lua rồi thêm 1 dòng vào bảng GAMES bên dưới.
]]

local BASE = "https://raw.githubusercontent.com/Tro0405/roblox-scripts/main/games/"

-- [PlaceId] = "tên file trong games/"
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
	notify("Game này chưa được hỗ trợ.\nPlaceId: " .. tostring(placeId), 8)
	warn("[TvFruit] Chưa hỗ trợ PlaceId " .. tostring(placeId))
	return
end

local url = BASE .. file
local ok, src = pcall(function()
	return game:HttpGet(url, true)
end)

if not ok or not src or src == "" then
	notify("Không tải được script: " .. file, 8)
	warn("[TvFruit] HttpGet lỗi: " .. tostring(src))
	return
end

local fn, err = loadstring(src)
if not fn then
	notify("loadstring lỗi ở " .. file, 8)
	warn("[TvFruit] loadstring lỗi: " .. tostring(err))
	return
end

notify("Đã nạp " .. file .. " ✓", 4)
fn()
