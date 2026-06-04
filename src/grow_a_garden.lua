--[[
	Grow a Garden — BizzyBee Hive Manager (TvFruit)
	PlaceId: 126884695634066
	Uses the shared theme library (games/lib/theme.lua) -> unified cyan UI.
]]

local RS=game:GetService("ReplicatedStorage")
local LP=game:GetService("Players").LocalPlayer
local DataService=require(RS.Modules.DataService)
local BizzyBee=RS.GameEvents.BizzyBeeEvent
local PlaceRE,ReplaceRE=BizzyBee.PlaceBeeEggRE,BizzyBee.ReplaceBeeRE
local EnchantRE,ReplaceEnchantRE=BizzyBee.EnchantBeeRE,BizzyBee.ReplaceEnchantRE

-- load shared theme
local BASE="https://raw.githubusercontent.com/Tro0405/roblox-scripts/main/games/"
local Lib=loadstring(game:HttpGet(BASE.."lib/theme.lua",true))()
local C=Lib.Colors

local CFG={DELAY=0.45, MAX_PER_SLOT=400}

-- pool: bee <- egg + weight
local POOL={
 ["Common Bee Egg"]={{"Bee",30},{"Swift Bee",15},{"Pollen Bee",15},{"Clockwork Bee",5},{"Baby Bee",3}},
 ["Rare Bee Egg"]={{"Busy Bee",30},{"Rumble Bee",30},{"Merchant Bee",10},{"Jester Bee",3},{"Panic Bee",1}},
 ["Mythical Bee Egg"]={{"Royal Bee",30},{"Turbo Bee",30},{"Treasure Bee",10},{"Princess Bee",3},{"Illusion Bee",1}},
 ["Transcendent Bee Egg"]={{"Necromancer Bee",35},{"Chaos Bee",20},{"Chrono Bee",20},{"Overlord Bee",3},{"Genesis Bee",1}},
}
local EGGORDER={"Common Bee Egg","Rare Bee Egg","Mythical Bee Egg","Transcendent Bee Egg"}
-- rarity colors (info only, not the main theme color)
local RCOL={["Common Bee Egg"]=Color3.fromRGB(200,200,200),["Rare Bee Egg"]=Color3.fromRGB(90,160,255),["Mythical Bee Egg"]=Color3.fromRGB(255,90,90),["Transcendent Bee Egg"]=Color3.fromRGB(220,120,255)}
local BEE_EGG,BEE_PCT,BEELIST={},{},{}
for _,egg in ipairs(EGGORDER) do
	local tot=0 for _,w in ipairs(POOL[egg]) do tot=tot+w[2] end
	for _,w in ipairs(POOL[egg]) do BEE_EGG[w[1]]=egg; BEE_PCT[w[1]]=math.floor(w[2]/tot*1000)/10; table.insert(BEELIST,w[1]) end
end

-- logic helpers
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
	if inv then for u,e in pairs(inv) do if e.Data and e.Data.Slot==n then return u,e.BeeName,e.Data.Enchantment,e.Data.State end end end
end

-- list bee shard tools in backpack: returns { {prefix,count}, ... }
local function listShards()
	local out,seen={},{}
	for _,c in ipairs(LP.Backpack:GetChildren()) do
		if c:IsA("Tool") then
			local label=c.Name:match("^(Bee Shard %b[])")
			if label and not seen[label] then
				seen[label]=true
				table.insert(out,{label, tonumber(c.Name:match("x(%d+)")) or 1})
			end
		end
	end
	return out
end

-- highlight a hive cell
local HOST=(gethui and gethui()) or game:GetService("CoreGui")
local hl=Instance.new("Highlight"); hl.FillColor=Color3.fromRGB(0,255,80); hl.FillTransparency=0.4; hl.OutlineColor=C.Accent; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=HOST
local hbb=Instance.new("BillboardGui"); hbb.Size=UDim2.new(0,160,0,40); hbb.AlwaysOnTop=true; hbb.StudsOffset=Vector3.new(0,3,0); hbb.Parent=hl
local hbl=Instance.new("TextLabel",hbb); hbl.Size=UDim2.new(1,0,1,0); hbl.BackgroundTransparency=1; hbl.Font=Enum.Font.GothamBold; hbl.TextSize=20; hbl.TextColor3=C.Accent; hbl.TextStrokeTransparency=0
local function highlightSlot(n) local p=slotPart(n); hl.Adornee=p; hbb.Adornee=p; hbl.Text="SLOT "..n end

-- anti-AFK (avoid the 20-minute idle kick)
local VirtualUser=game:GetService("VirtualUser")
local antiAfkConn
local function setAntiAfk(on)
	if on and not antiAfkConn then
		antiAfkConn=LP.Idled:Connect(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	elseif (not on) and antiAfkConn then
		antiAfkConn:Disconnect(); antiAfkConn=nil
	end
end

-- window from shared library
local win=Lib:Window({Title="Grow a Garden", Name="TvFruitGAG", Icon="📺"})
local gui=win.Gui

-- PAGE: Home
local home=win:Tab("Home","🏠")
Lib.L(home,16,16,"🐝 BizzyBee Hive Manager",18,C.Accent)
Lib.L(home,16,46,"Auto re-roll eggs to hunt the bee you want for each hive slot.",12,C.TextDim,40)
Lib.L(home,16,96,"How to use:",13,C.Accent)
Lib.L(home,16,118,"1) Open the Hive tab, click a Slot (it lights up in-game)",12,C.TextDim)
Lib.L(home,16,138,"2) Click the bee you want to assign it to that slot",12,C.TextDim)
Lib.L(home,16,158,"3) Press START — auto-equips eggs, rolls, stops on match",12,C.TextDim)
Lib.L(home,16,186,"Note: each roll uses 1 egg. Illusion ~1.4% (~70 eggs avg).",12,Color3.fromRGB(255,150,150),40)

-- PAGE: Hive
local hive=win:Tab("Hive","🐝")
local hint=Lib.L(hive,12,6,"Select a slot, then a bee:",12,C.Accent)
local slotList=Lib.Scroll(hive,UDim2.new(0,12,0,28),UDim2.new(0,195,0,278))
local beeList=Lib.Scroll(hive,UDim2.new(0,215,0,28),UDim2.new(0,215,0,278))

local selectedSlot,slotBtns,targets=nil,{},{}
for n=1,21 do
	local b=Lib.Btn(slotList,{Size=UDim2.new(1,-8,0,28),Text="",Color=C.Bg3,Radius=5}); b.AutoButtonColor=true; b.TextXAlignment=Enum.TextXAlignment.Left; b.Font=Enum.Font.GothamMedium; b.TextSize=12; b.Text="  Slot "..n; slotBtns[n]=b
	b.MouseButton1Click:Connect(function()
		selectedSlot=n; highlightSlot(n)
		for i,bt in pairs(slotBtns) do bt.BackgroundColor3=(i==n) and Color3.fromRGB(20,90,110) or C.Bg3 end
		hint.Text="Selected SLOT "..n.." — pick a bee on the right"
	end)
end
for _,bee in ipairs(BEELIST) do
	local egg=BEE_EGG[bee]
	local b=Lib.Btn(beeList,{Size=UDim2.new(1,-8,0,26),Color=C.Bg3,Radius=5}); b.AutoButtonColor=true; b.TextXAlignment=Enum.TextXAlignment.Left; b.Font=Enum.Font.GothamMedium; b.TextSize=11; b.TextColor3=RCOL[egg]; b.Text="  "..bee.."  ("..BEE_PCT[bee].."%)"
	b.MouseButton1Click:Connect(function()
		if not selectedSlot then hint.Text="Select a SLOT first!"; return end
		targets[selectedSlot]=bee
		slotBtns[selectedSlot].Text="  Slot "..selectedSlot.." -> "..bee
		slotBtns[selectedSlot].TextColor3=RCOL[egg]
		hint.Text="Slot "..selectedSlot.." = "..bee.." ["..egg.."]"
	end)
end
local startB=Lib.Btn(hive,{Pos=UDim2.new(0,12,0,314),Size=UDim2.new(0,100,0,30),Text="▶ START",Color=C.Good})
local stopB=Lib.Btn(hive,{Pos=UDim2.new(0,118,0,314),Size=UDim2.new(0,100,0,30),Text="■ STOP",Color=C.Danger})
local prog=Lib.L(hive,228,320,"Ready",11,C.TextDim)

-- PAGE: ESP
local espPage=win:Tab("ESP","👁")
Lib.L(espPage,16,16,"Bee Name ESP",18,C.Accent)
Lib.L(espPage,16,46,"Shows the bee name floating above each hive slot (colored by rarity).",12,C.TextDim,40)
local espToggle=Lib.Btn(espPage,{Pos=UDim2.new(0,16,0,100),Size=UDim2.new(0,140,0,32),Text="ESP: OFF",Color=C.Bg3})
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
Lib.L(setPage,16,16,"Settings",18,C.Accent)
local function numInput(y,label,val,onset)
	Lib.L(setPage,16,y,label,12,C.TextDim)
	local box=Instance.new("TextBox",setPage); box.Position=UDim2.new(0,210,0,y-2); box.Size=UDim2.new(0,90,0,26); box.BackgroundColor3=C.Bg3; box.BorderSizePixel=0; box.Font=Enum.Font.GothamMedium; box.TextSize=13; box.TextColor3=C.Text; box.Text=tostring(val); Lib.Corner(box,5)
	box.FocusLost:Connect(function() local v=tonumber(box.Text); if v then onset(v) else box.Text=tostring(val) end end)
end
numInput(56,"Delay per roll (sec):",CFG.DELAY,function(v) CFG.DELAY=v end)
numInput(94,"Max rolls / slot:",CFG.MAX_PER_SLOT,function(v) CFG.MAX_PER_SLOT=math.floor(v) end)
Lib.L(setPage,16,140,"Low delay = faster rolls but higher kick risk. Keep >= 0.3.",11,Color3.fromRGB(255,150,150),40)

-- PAGE: Misc
local misc=win:Tab("Misc","🛡")
Lib.Section(misc,12,"Anti-AFK")
Lib.Toggle(misc,{y=34,icon="🛡",title="Anti-AFK",sub="Prevent the 20-minute idle kick",color=C.Accent,callback=setAntiAfk})

Lib.Section(misc,96,"Auto Bee Shard (all 21 bees)")
local shardHint=Lib.L(misc,16,114,"Pick a shard type:",11,C.TextDim)
local shardList=Lib.Scroll(misc,UDim2.new(0,12,0,134),UDim2.new(1,-24,0,104))
local selectedShard,shardBtns=nil,{}
for _,sh in ipairs(listShards()) do
	local label,cnt=sh[1],sh[2]
	local b=Lib.Btn(shardList,{Size=UDim2.new(1,-8,0,26),Color=C.Bg3,Radius=5}); b.AutoButtonColor=true; b.Font=Enum.Font.GothamMedium; b.TextSize=11; b.TextXAlignment=Enum.TextXAlignment.Left; b.Text="  "..label.."  (x"..cnt..")"
	shardBtns[label]=b
	b.MouseButton1Click:Connect(function()
		selectedShard=label
		for l,bt in pairs(shardBtns) do bt.BackgroundColor3=(l==label) and Color3.fromRGB(20,90,110) or C.Bg3 end
		shardHint.Text="Selected: "..label
	end)
end
if not next(shardBtns) then shardHint.Text="No Bee Shard found in backpack" end

local overwrite=false
local owBtn=Lib.Btn(misc,{Pos=UDim2.new(0,12,0,246),Size=UDim2.new(0,170,0,26),Text="Overwrite existing: OFF",Color=C.Bg3,TextSize=11})
owBtn.MouseButton1Click:Connect(function() overwrite=not overwrite; owBtn.Text="Overwrite existing: "..(overwrite and "ON" or "OFF"); owBtn.BackgroundColor3=overwrite and C.Accent or C.Bg3; owBtn.TextColor3=overwrite and Color3.fromRGB(10,20,24) or C.Text end)

local shStart=Lib.Btn(misc,{Pos=UDim2.new(0,12,0,280),Size=UDim2.new(0,90,0,28),Text="▶ START",Color=C.Good,TextSize=12})
local shStop=Lib.Btn(misc,{Pos=UDim2.new(0,108,0,280),Size=UDim2.new(0,90,0,28),Text="■ STOP",Color=C.Danger,TextSize=12})
local shProg=Lib.L(misc,208,286,"Ready",11,C.TextDim)

getgenv().ShardRunning=false
shStart.MouseButton1Click:Connect(function()
	if getgenv().ShardRunning then return end
	if not selectedShard then shProg.Text="Pick a shard type first!"; return end
	getgenv().ShardRunning=true
	task.spawn(function()
		local applied,outOfShard=0,false
		for n=1,21 do
			if not getgenv().ShardRunning then break end
			local _,bee,ench,state=getSlot(n)
			if bee and state~="Hatching" then
				if ench and not overwrite then
					shProg.Text="Slot "..n..": already enchanted (skip)"
				else
					if eggCount(selectedShard)<=0 then shProg.Text="Out of "..selectedShard; outOfShard=true; getgenv().ShardRunning=false; break end
					if not equipEgg(selectedShard) then shProg.Text="Can't equip shard"; getgenv().ShardRunning=false; break end
					if ench then ReplaceEnchantRE:FireServer(n) else EnchantRE:FireServer(n) end
					applied=applied+1; shProg.Text="Slot "..n.." enchanted ("..applied..")"
					task.wait(CFG.DELAY)
				end
			end
		end
		getgenv().ShardRunning=false
		if not outOfShard then shProg.Text="Done — enchanted "..applied.." bees" end
	end)
end)
shStop.MouseButton1Click:Connect(function() getgenv().ShardRunning=false; shProg.Text="Stopped" end)

-- live update current bee on slot buttons
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
				if left<=0 then prog.Text="Out of "..egg.."! Done "..done.."/"..#list; stoppedNoEgg=true; getgenv().BeeRunning=false; pcall(function() game.StarterGui:SetCore("SendNotification",{Title="BizzyBee",Text="Out of "..egg..", stopped!",Duration=6}) end); break end
				if not equipEgg(egg) then prog.Text="Can't equip "..egg; getgenv().BeeRunning=false; break end
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
		if not stoppedNoEgg then prog.Text="Done "..done.."/"..#list.." slots" end
	end)
end)
stopB.MouseButton1Click:Connect(function() getgenv().BeeRunning=false; prog.Text="Stopped" end)

win:OnClose(function() getgenv().BeeRunning=false; getgenv().ShardRunning=false; setAntiAfk(false); pcall(function() hl:Destroy() end); pcall(function() espHost:Destroy() end) end)
win:Show("Home")
