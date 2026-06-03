--[[
	Grow a Garden — BizzyBee Hive Manager (TvFruit)
	PlaceId: 126884695634066
	Dùng thư viện theme chung (games/lib/theme.lua) -> GUI thống nhất, màu cyan.
]]

local RS=game:GetService("ReplicatedStorage")
local LP=game:GetService("Players").LocalPlayer
local DataService=require(RS.Modules.DataService)
local BizzyBee=RS.GameEvents.BizzyBeeEvent
local PlaceRE,ReplaceRE=BizzyBee.PlaceBeeEggRE,BizzyBee.ReplaceBeeRE

-- nạp theme chung
local BASE="https://raw.githubusercontent.com/Tro0405/roblox-scripts/main/games/"
local Lib=loadstring(game:HttpGet(BASE.."lib/theme.lua",true))()
local C=Lib.Colors

local CFG={DELAY=0.45, MAX_PER_SLOT=400}

-- pool bee <- trứng
local POOL={
 ["Common Bee Egg"]={{"Bee",30},{"Swift Bee",15},{"Pollen Bee",15},{"Clockwork Bee",5},{"Baby Bee",3}},
 ["Rare Bee Egg"]={{"Busy Bee",30},{"Rumble Bee",30},{"Merchant Bee",10},{"Jester Bee",3},{"Panic Bee",1}},
 ["Mythical Bee Egg"]={{"Royal Bee",30},{"Turbo Bee",30},{"Treasure Bee",10},{"Princess Bee",3},{"Illusion Bee",1}},
 ["Transcendent Bee Egg"]={{"Necromancer Bee",35},{"Chaos Bee",20},{"Chrono Bee",20},{"Overlord Bee",3},{"Genesis Bee",1}},
}
local EGGORDER={"Common Bee Egg","Rare Bee Egg","Mythical Bee Egg","Transcendent Bee Egg"}
-- màu độ hiếm (giữ để phân biệt info, không phải màu chủ đạo)
local RCOL={["Common Bee Egg"]=Color3.fromRGB(200,200,200),["Rare Bee Egg"]=Color3.fromRGB(90,160,255),["Mythical Bee Egg"]=Color3.fromRGB(255,90,90),["Transcendent Bee Egg"]=Color3.fromRGB(220,120,255)}
local BEE_EGG,BEE_PCT,BEELIST={},{},{}
for _,egg in ipairs(EGGORDER) do
	local tot=0 for _,w in ipairs(POOL[egg]) do tot=tot+w[2] end
	for _,w in ipairs(POOL[egg]) do BEE_EGG[w[1]]=egg; BEE_PCT[w[1]]=math.floor(w[2]/tot*1000)/10; table.insert(BEELIST,w[1]) end
end

-- helpers logic
local function equipEgg(egg)
	local char=LP.Character; local hum=char and char:FindFirstChildOfClass("Humanoid"); if not hum then return false end
	for _,c in ipairs(char:GetChildren()) do if c:IsA("Tool") and c.Name:sub(1,#egg)==egg then return true end end
	for _,c in ipairs(LP.Backpack:GetChildren()) do if c:IsA("Tool") and c.Name:sub(1,#egg)==egg then hum:EquipTool(c); task.wait(0.25); return true end end
	return false
end
local function eggCount(egg)
	local function scan(cont) for _,c in ipairs(cont:GetChildren()) do if c:IsA("Tool") and c.Name:sub(1,#egg)==egg then return tonumber(c.Name:match("x(%d+)")) or 1 end end end
	return scan(LP.Backpack) or (LP.Character and scan(LP.Character)) or 0
end
local function slotPart(n) for _,p in ipairs(workspace:GetChildren()) do if p.Name=="BeeNestHover" and p:GetAttribute("Slot")==n then return p end end end
local function getSlot(n)
	local d=DataService:GetData(); local inv=d and d.BeeEventData and d.BeeEventData.BeeInventoryData
	if inv then for u,e in pairs(inv) do if e.Data and e.Data.Slot==n then return u,e.BeeName end end end
end

-- highlight ô
local HOST=(gethui and gethui()) or game:GetService("CoreGui")
local hl=Instance.new("Highlight"); hl.FillColor=Color3.fromRGB(0,255,80); hl.FillTransparency=0.4; hl.OutlineColor=C.Accent; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=HOST
local hbb=Instance.new("BillboardGui"); hbb.Size=UDim2.new(0,160,0,40); hbb.AlwaysOnTop=true; hbb.StudsOffset=Vector3.new(0,3,0); hbb.Parent=hl
local hbl=Instance.new("TextLabel",hbb); hbl.Size=UDim2.new(1,0,1,0); hbl.BackgroundTransparency=1; hbl.Font=Enum.Font.GothamBold; hbl.TextSize=20; hbl.TextColor3=C.Accent; hbl.TextStrokeTransparency=0
local function highlightSlot(n) local p=slotPart(n); hl.Adornee=p; hbb.Adornee=p; hbl.Text="SLOT "..n end

-- ===== Cửa sổ từ thư viện chung =====
local win=Lib:Window({Title="Grow a Garden", Name="TvFruitGAG", Icon="📺"})
local gui=win.Gui

-- PAGE: Home
local home=win:Tab("Home","🏠")
Lib.L(home,14,14,"🐝 BizzyBee Hive Manager",18,C.Accent)
Lib.L(home,14,46,"Tự re-roll trứng để săn bee mong muốn cho từng ô tổ ong.",12,C.TextDim,40)
Lib.L(home,14,96,"Cách dùng:",13,C.Accent)
Lib.L(home,14,118,"1) Tab Hive → bấm 1 Slot (ô sẽ sáng trong game)",12,C.TextDim)
Lib.L(home,14,138,"2) Bấm bee muốn → gán cho slot",12,C.TextDim)
Lib.L(home,14,158,"3) START — tự cầm trứng & roll, tự dừng khi trúng",12,C.TextDim)
Lib.L(home,14,186,"⚠ Mỗi lần roll tốn 1 trứng. Illusion ~1.4% (~70 trứng).",12,Color3.fromRGB(255,150,150),40)
Lib.L(home,14,236,"Made by TvFruit",12,Color3.fromRGB(110,116,128))

-- PAGE: Hive
local hive=win:Tab("Hive","🐝")
local hint=Lib.L(hive,12,6,"Chọn slot rồi chọn bee:",12,C.Accent)
local slotList=Lib.Scroll(hive,UDim2.new(0,12,0,28),UDim2.new(0,195,0,278))
local beeList=Lib.Scroll(hive,UDim2.new(0,215,0,28),UDim2.new(0,215,0,278))

local selectedSlot,slotBtns,targets=nil,{},{}
for n=1,21 do
	local b=Lib.Btn(slotList,{Size=UDim2.new(1,-8,0,28),Text="",Color=C.Bg3,Radius=5}); b.AutoButtonColor=true; b.TextXAlignment=Enum.TextXAlignment.Left; b.Font=Enum.Font.GothamMedium; b.TextSize=12; b.Text="  Slot "..n; slotBtns[n]=b
	b.MouseButton1Click:Connect(function()
		selectedSlot=n; highlightSlot(n)
		for i,bt in pairs(slotBtns) do bt.BackgroundColor3=(i==n) and Color3.fromRGB(20,90,110) or C.Bg3 end
		hint.Text="🐝 Đang chọn SLOT "..n.." — bấm 1 bee →"
	end)
end
for _,bee in ipairs(BEELIST) do
	local egg=BEE_EGG[bee]
	local b=Lib.Btn(beeList,{Size=UDim2.new(1,-8,0,26),Color=C.Bg3,Radius=5}); b.AutoButtonColor=true; b.TextXAlignment=Enum.TextXAlignment.Left; b.Font=Enum.Font.GothamMedium; b.TextSize=11; b.TextColor3=RCOL[egg]; b.Text="  "..bee.."  ("..BEE_PCT[bee].."%)"
	b.MouseButton1Click:Connect(function()
		if not selectedSlot then hint.Text="⚠️ Chọn SLOT trước!"; return end
		targets[selectedSlot]=bee
		slotBtns[selectedSlot].Text="  Slot "..selectedSlot.." → "..bee
		slotBtns[selectedSlot].TextColor3=RCOL[egg]
		hint.Text="✅ Slot "..selectedSlot.." = "..bee.." ["..egg.."]"
	end)
end
local startB=Lib.Btn(hive,{Pos=UDim2.new(0,12,0,314),Size=UDim2.new(0,100,0,30),Text="▶ START",Color=C.Good})
local stopB=Lib.Btn(hive,{Pos=UDim2.new(0,118,0,314),Size=UDim2.new(0,100,0,30),Text="■ STOP",Color=C.Danger})
local prog=Lib.L(hive,228,320,"Sẵn sàng",11,C.TextDim)

-- PAGE: ESP
local espPage=win:Tab("ESP","👁")
Lib.L(espPage,14,14,"ESP tên bee",18,C.Accent)
Lib.L(espPage,14,46,"Hiện tên con bee nổi trên mỗi ô (đổi màu theo độ hiếm).",12,C.TextDim,40)
local espToggle=Lib.Btn(espPage,{Pos=UDim2.new(0,14,0,100),Size=UDim2.new(0,140,0,32),Text="ESP: OFF",Color=C.Bg3})
local espOn,espLabels=false,{}
local espHost=Instance.new("Folder"); espHost.Name="BeeESPHost"; espHost.Parent=gui
for n=1,21 do
	local bbg=Instance.new("BillboardGui",espHost); bbg.Size=UDim2.new(0,200,0,34); bbg.AlwaysOnTop=true; bbg.StudsOffset=Vector3.new(0,2.4,0); bbg.Enabled=false
	local t=Instance.new("TextLabel",bbg); t.Size=UDim2.new(1,0,1,0); t.BackgroundTransparency=1; t.Font=Enum.Font.GothamBold; t.TextSize=16; t.TextStrokeTransparency=0.25
	espLabels[n]={bbg,t}
end
espToggle.MouseButton1Click:Connect(function() espOn=not espOn; espToggle.Text="ESP: "..(espOn and "ON" or "OFF"); espToggle.BackgroundColor3=espOn and C.Accent or C.Bg3; espToggle.TextColor3=espOn and Color3.fromRGB(10,20,24) or C.Text end)
task.spawn(function()
	while gui.Parent do
		if espOn then
			for n=1,21 do local p=slotPart(n); local _,bee=getSlot(n); local L=espLabels[n]
				if p and bee then L[1].Adornee=p; L[1].Enabled=true; L[2].Text=bee; L[2].TextColor3=RCOL[BEE_EGG[bee] or ""] or Color3.new(1,1,1) else L[1].Enabled=false end
			end
		else for n=1,21 do espLabels[n][1].Enabled=false end end
		task.wait(1)
	end
end)

-- PAGE: Settings
local setPage=win:Tab("Settings","⚙")
Lib.L(setPage,14,14,"Cài đặt",18,C.Accent)
local function numInput(y,label,val,onset)
	Lib.L(setPage,14,y,label,12,C.TextDim)
	local box=Instance.new("TextBox",setPage); box.Position=UDim2.new(0,200,0,y-2); box.Size=UDim2.new(0,90,0,26); box.BackgroundColor3=C.Bg3; box.BorderSizePixel=0; box.Font=Enum.Font.GothamMedium; box.TextSize=13; box.TextColor3=C.Text; box.Text=tostring(val); Lib.Corner(box,5)
	box.FocusLost:Connect(function() local v=tonumber(box.Text); if v then onset(v) else box.Text=tostring(val) end end)
end
numInput(56,"Delay mỗi roll (giây):",CFG.DELAY,function(v) CFG.DELAY=v end)
numInput(94,"Max roll / slot:",CFG.MAX_PER_SLOT,function(v) CFG.MAX_PER_SLOT=math.floor(v) end)
Lib.L(setPage,14,140,"Delay thấp = roll nhanh nhưng dễ bị kick. Khuyên ≥ 0.3.",11,Color3.fromRGB(255,150,150),40)

-- live update bee hiện tại
task.spawn(function()
	while gui.Parent do
		for n=1,21 do local _,cur=getSlot(n)
			if not targets[n] and slotBtns[n] then slotBtns[n].Text="  Slot "..n..(cur and (" ["..cur.."]") or "") end
		end
		task.wait(1.5)
	end
end)

-- START / STOP
getgenv().BeeRunning=false
startB.MouseButton1Click:Connect(function()
	if getgenv().BeeRunning then return end
	getgenv().BeeRunning=true
	task.spawn(function()
		local list={} for n=1,21 do if targets[n] then table.insert(list,n) end end
		local done,stoppedNoEgg=0,false
		for _,n in ipairs(list) do
			if not getgenv().BeeRunning then break end
			local tgt=targets[n]; local egg=BEE_EGG[tgt]; highlightSlot(n)
			local att=0
			while getgenv().BeeRunning do
				local uuid,cur=getSlot(n)
				local left=eggCount(egg)
				prog.Text="Slot "..n.." | "..tostring(cur).." | roll "..att.." | "..egg:gsub(" Bee Egg","").." x"..left
				if cur==tgt then done=done+1; break end
				if left<=0 then prog.Text="⛔ HẾT "..egg.."! Xong "..done.."/"..#list; stoppedNoEgg=true; getgenv().BeeRunning=false; pcall(function() game.StarterGui:SetCore("SendNotification",{Title="BizzyBee",Text="Hết "..egg..", đã dừng!",Duration=6}) end); break end
				if not equipEgg(egg) then prog.Text="⛔ Không cầm được "..egg; getgenv().BeeRunning=false; break end
				if not uuid then PlaceRE:FireServer(n); task.wait(CFG.DELAY)
				else
					ReplaceRE:FireServer(n,uuid); att=att+1
					local t0=tick(); repeat task.wait(0.05) until (getSlot(n))~=uuid or tick()-t0>2
					task.wait(CFG.DELAY)
					if att>=CFG.MAX_PER_SLOT then break end
				end
			end
			if stoppedNoEgg then break end
		end
		getgenv().BeeRunning=false
		if not stoppedNoEgg then prog.Text="✅ Xong "..done.."/"..#list.." slot" end
	end)
end)
stopB.MouseButton1Click:Connect(function() getgenv().BeeRunning=false; prog.Text="■ Đã dừng" end)

win:OnClose(function() getgenv().BeeRunning=false; pcall(function() hl:Destroy() end); pcall(function() espHost:Destroy() end) end)
win:Show("Home")
