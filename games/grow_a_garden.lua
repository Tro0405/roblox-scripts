--[[
	Grow a Garden — BizzyBee Hive Manager (TvFruit)
	PlaceId: 126884695634066
	GUI thống nhất: sidebar điều hướng + thu nhỏ thành cục tròn icon TV.
	Logic: tự map bee->trứng, tự equip, auto re-roll, ESP, highlight, tự dừng khi hết trứng.
]]

local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local LP=game:GetService("Players").LocalPlayer
local DataService=require(RS.Modules.DataService)
local BizzyBee=RS.GameEvents.BizzyBeeEvent
local PlaceRE,ReplaceRE=BizzyBee.PlaceBeeEggRE,BizzyBee.ReplaceBeeRE

-- ========= CONFIG (chỉnh ở Settings tab) =========
local CFG={DELAY=0.45, MAX_PER_SLOT=400}

-- màu chủ đạo
local ACCENT=Color3.fromRGB(255,196,0)      -- amber (bee)
local BG=Color3.fromRGB(18,18,24)
local BG2=Color3.fromRGB(26,26,36)
local BG3=Color3.fromRGB(38,38,52)

-- ========= DATA: pool bee <- trứng =========
local POOL={
 ["Common Bee Egg"]={{"Bee",30},{"Swift Bee",15},{"Pollen Bee",15},{"Clockwork Bee",5},{"Baby Bee",3}},
 ["Rare Bee Egg"]={{"Busy Bee",30},{"Rumble Bee",30},{"Merchant Bee",10},{"Jester Bee",3},{"Panic Bee",1}},
 ["Mythical Bee Egg"]={{"Royal Bee",30},{"Turbo Bee",30},{"Treasure Bee",10},{"Princess Bee",3},{"Illusion Bee",1}},
 ["Transcendent Bee Egg"]={{"Necromancer Bee",35},{"Chaos Bee",20},{"Chrono Bee",20},{"Overlord Bee",3},{"Genesis Bee",1}},
}
local EGGORDER={"Common Bee Egg","Rare Bee Egg","Mythical Bee Egg","Transcendent Bee Egg"}
local RCOL={["Common Bee Egg"]=Color3.fromRGB(200,200,200),["Rare Bee Egg"]=Color3.fromRGB(90,160,255),["Mythical Bee Egg"]=Color3.fromRGB(255,90,90),["Transcendent Bee Egg"]=Color3.fromRGB(220,120,255)}
local BEE_EGG,BEE_PCT,BEELIST={},{},{}
for _,egg in ipairs(EGGORDER) do
	local tot=0 for _,w in ipairs(POOL[egg]) do tot=tot+w[2] end
	for _,w in ipairs(POOL[egg]) do
		BEE_EGG[w[1]]=egg; BEE_PCT[w[1]]=math.floor(w[2]/tot*1000)/10
		table.insert(BEELIST,w[1])
	end
end

-- ========= helpers =========
local function equipEgg(egg)
	local char=LP.Character; local hum=char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return false end
	for _,c in ipairs(char:GetChildren()) do
		if c:IsA("Tool") and c.Name:sub(1,#egg)==egg then return true end
	end
	for _,c in ipairs(LP.Backpack:GetChildren()) do
		if c:IsA("Tool") and c.Name:sub(1,#egg)==egg then hum:EquipTool(c); task.wait(0.25); return true end
	end
	return false
end
local function eggCount(egg)
	local function scan(cont)
		for _,c in ipairs(cont:GetChildren()) do
			if c:IsA("Tool") and c.Name:sub(1,#egg)==egg then return tonumber(c.Name:match("x(%d+)")) or 1 end
		end
	end
	return scan(LP.Backpack) or (LP.Character and scan(LP.Character)) or 0
end
local function slotPart(n)
	for _,p in ipairs(workspace:GetChildren()) do
		if p.Name=="BeeNestHover" and p:GetAttribute("Slot")==n then return p end end
end
local function getSlot(n)
	local d=DataService:GetData(); local inv=d and d.BeeEventData and d.BeeEventData.BeeInventoryData
	if inv then for u,e in pairs(inv) do if e.Data and e.Data.Slot==n then return u,e.BeeName end end end
end
local function corner(o,r) local c=Instance.new("UICorner",o); c.CornerRadius=UDim.new(0,r or 6); return c end

-- ========= highlight ô =========
local HOST=(gethui and gethui()) or game:GetService("CoreGui")
local hl=Instance.new("Highlight"); hl.FillColor=Color3.fromRGB(0,255,80); hl.FillTransparency=0.4; hl.OutlineColor=ACCENT; hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent=HOST
local hbb=Instance.new("BillboardGui"); hbb.Size=UDim2.new(0,160,0,40); hbb.AlwaysOnTop=true; hbb.StudsOffset=Vector3.new(0,3,0); hbb.Parent=hl
local hbl=Instance.new("TextLabel",hbb); hbl.Size=UDim2.new(1,0,1,0); hbl.BackgroundTransparency=1; hbl.Font=Enum.Font.GothamBold; hbl.TextSize=20; hbl.TextColor3=Color3.fromRGB(0,255,80); hbl.TextStrokeTransparency=0
local function highlightSlot(n) local p=slotPart(n); hl.Adornee=p; hbb.Adornee=p; hbl.Text="SLOT "..n end

-- ========= ROOT GUI =========
local gui=Instance.new("ScreenGui"); gui.Name="TvFruitGAG"; gui.ResetOnSpawn=false; gui.Parent=HOST

-- cục tròn icon TV (khi thu nhỏ)
local orb=Instance.new("TextButton"); orb.Size=UDim2.new(0,58,0,58); orb.Position=UDim2.new(0,18,0.45,0); orb.BackgroundColor3=BG2; orb.AutoButtonColor=false; orb.Text="📺"; orb.TextSize=30; orb.Font=Enum.Font.GothamBold; orb.TextColor3=ACCENT; orb.Visible=false; orb.Parent=gui
corner(orb,29); local orbStroke=Instance.new("UIStroke",orb); orbStroke.Color=ACCENT; orbStroke.Thickness=2

-- cửa sổ chính
local win=Instance.new("Frame"); win.Size=UDim2.new(0,620,0,430); win.Position=UDim2.new(0.5,-310,0.5,-215); win.BackgroundColor3=BG; win.BorderSizePixel=0; win.Parent=gui
corner(win,10)

-- top bar
local top=Instance.new("Frame",win); top.Size=UDim2.new(1,0,0,36); top.BackgroundColor3=Color3.fromRGB(30,30,42); top.BorderSizePixel=0; corner(top,10)
local titl=Instance.new("TextLabel",top); titl.Size=UDim2.new(1,-90,1,0); titl.Position=UDim2.new(0,14,0,0); titl.BackgroundTransparency=1; titl.Font=Enum.Font.GothamBold; titl.TextSize=14; titl.TextColor3=ACCENT; titl.TextXAlignment=Enum.TextXAlignment.Left; titl.Text="📺 TvFruit  |  Grow a Garden"
local function topBtn(x,txt,col)
	local b=Instance.new("TextButton",top); b.Size=UDim2.new(0,32,0,24); b.Position=UDim2.new(1,x,0.5,-12); b.BackgroundColor3=col; b.BorderSizePixel=0; b.Font=Enum.Font.GothamBold; b.TextSize=16; b.TextColor3=Color3.new(1,1,1); b.Text=txt; corner(b,5); return b
end
local minB=topBtn(-72,"–",Color3.fromRGB(70,70,90))
local closeB=topBtn(-36,"✕",Color3.fromRGB(170,55,55))

-- sidebar
local side=Instance.new("Frame",win); side.Size=UDim2.new(0,138,1,-46); side.Position=UDim2.new(0,8,0,42); side.BackgroundColor3=BG2; side.BorderSizePixel=0; corner(side,8)
local sl=Instance.new("UIListLayout",side); sl.Padding=UDim.new(0,4); local sp=Instance.new("UIPadding",side); sp.PaddingTop=UDim.new(0,8); sp.PaddingLeft=UDim.new(0,8); sp.PaddingRight=UDim.new(0,8)

-- content area
local content=Instance.new("Frame",win); content.Size=UDim2.new(1,-160,1,-46); content.Position=UDim2.new(0,152,0,42); content.BackgroundColor3=BG2; content.BorderSizePixel=0; corner(content,8)

local pages,navBtns={},{}
local function showPage(name)
	for n,pg in pairs(pages) do pg.Visible=(n==name) end
	for n,bt in pairs(navBtns) do
		bt.BackgroundColor3=(n==name) and BG3 or BG2
		bt.TextColor3=(n==name) and ACCENT or Color3.fromRGB(200,200,200)
	end
end
local function addNav(name,icon)
	local b=Instance.new("TextButton",side); b.Size=UDim2.new(1,0,0,34); b.BackgroundColor3=BG2; b.BorderSizePixel=0; b.Font=Enum.Font.GothamMedium; b.TextSize=13; b.TextColor3=Color3.fromRGB(200,200,200); b.TextXAlignment=Enum.TextXAlignment.Left; b.Text="  "..icon.."  "..name; corner(b,6)
	navBtns[name]=b; b.MouseButton1Click:Connect(function() showPage(name) end)
	local pg=Instance.new("Frame",content); pg.Size=UDim2.new(1,0,1,0); pg.BackgroundTransparency=1; pg.Visible=false; pages[name]=pg
	return pg
end

-- ====== PAGE: Home ======
local home=addNav("Home","🏠")
local function lbl(parent,y,t,size,col,wrap)
	local l=Instance.new("TextLabel",parent); l.Position=UDim2.new(0,14,0,y); l.Size=UDim2.new(1,-28,0,size+6); l.BackgroundTransparency=1; l.Font=Enum.Font.GothamMedium; l.TextSize=size; l.TextColor3=col or Color3.new(1,1,1); l.TextXAlignment=Enum.TextXAlignment.Left; l.Text=t
	if wrap then l.TextWrapped=true; l.Size=UDim2.new(1,-28,0,60); l.TextYAlignment=Enum.TextYAlignment.Top end
	return l
end
lbl(home,14,"🐝 BizzyBee Hive Manager",18,ACCENT)
lbl(home,46,"Tự re-roll trứng để săn bee mong muốn cho từng ô tổ ong.",12,Color3.fromRGB(200,200,200),true)
lbl(home,96,"Cách dùng:",13,ACCENT)
lbl(home,118,"1) Vào tab Hive → bấm 1 Slot (ô sẽ sáng trong game)",12,Color3.fromRGB(190,190,190))
lbl(home,138,"2) Bấm bee muốn → gán cho slot đó",12,Color3.fromRGB(190,190,190))
lbl(home,158,"3) Bấm START — tự cầm trứng & roll, tự dừng khi trúng",12,Color3.fromRGB(190,190,190))
lbl(home,186,"⚠ Mỗi lần roll tốn 1 trứng. Illusion ~1.4% (~70 trứng/con).",12,Color3.fromRGB(255,150,150),true)
lbl(home,236,"Made by TvFruit",12,Color3.fromRGB(120,120,140))

-- ====== PAGE: Hive ======
local hive=addNav("Hive","🐝")
local function scroll(parent,x,y,w,h)
	local s=Instance.new("ScrollingFrame",parent); s.Position=UDim2.new(0,x,0,y); s.Size=UDim2.new(0,w,0,h); s.BackgroundColor3=BG; s.BorderSizePixel=0; s.ScrollBarThickness=5; s.AutomaticCanvasSize=Enum.AutomaticSize.Y; s.CanvasSize=UDim2.new(0,0,0,0); corner(s,6)
	local l=Instance.new("UIListLayout",s); l.Padding=UDim.new(0,3); local p=Instance.new("UIPadding",s); p.PaddingTop=UDim.new(0,4); p.PaddingLeft=UDim.new(0,4); p.PaddingRight=UDim.new(0,4)
	return s
end
local hint=Instance.new("TextLabel",hive); hint.Position=UDim2.new(0,12,0,6); hint.Size=UDim2.new(1,-24,0,18); hint.BackgroundTransparency=1; hint.Font=Enum.Font.GothamMedium; hint.TextSize=12; hint.TextColor3=ACCENT; hint.TextXAlignment=Enum.TextXAlignment.Left; hint.Text="Chọn slot rồi chọn bee:"
local slotList=scroll(hive,12,28,195,278)
local beeList=scroll(hive,215,28,215,278)

local selectedSlot,slotBtns,targets=nil,{},{}
for n=1,21 do
	local b=Instance.new("TextButton",slotList); b.Size=UDim2.new(1,-8,0,28); b.BackgroundColor3=BG3; b.BorderSizePixel=0; b.Font=Enum.Font.GothamMedium; b.TextSize=12; b.TextColor3=Color3.new(1,1,1); b.TextXAlignment=Enum.TextXAlignment.Left; b.Text="  Slot "..n; corner(b,5); slotBtns[n]=b
	b.MouseButton1Click:Connect(function()
		selectedSlot=n; highlightSlot(n)
		for i,bt in pairs(slotBtns) do bt.BackgroundColor3=(i==n) and Color3.fromRGB(60,90,150) or BG3 end
		hint.Text="🐝 Đang chọn SLOT "..n.." — bấm 1 bee →"
	end)
end
for _,bee in ipairs(BEELIST) do
	local egg=BEE_EGG[bee]
	local b=Instance.new("TextButton",beeList); b.Size=UDim2.new(1,-8,0,26); b.BackgroundColor3=BG3; b.BorderSizePixel=0; b.Font=Enum.Font.GothamMedium; b.TextSize=11; b.TextColor3=RCOL[egg]; b.TextXAlignment=Enum.TextXAlignment.Left; b.Text="  "..bee.."  ("..BEE_PCT[bee].."%)"; corner(b,5)
	b.MouseButton1Click:Connect(function()
		if not selectedSlot then hint.Text="⚠️ Chọn SLOT trước!"; return end
		targets[selectedSlot]=bee
		slotBtns[selectedSlot].Text="  Slot "..selectedSlot.." → "..bee
		slotBtns[selectedSlot].TextColor3=RCOL[egg]
		hint.Text="✅ Slot "..selectedSlot.." = "..bee.." ["..egg.."]"
	end)
end
-- nút Hive
local function actBtn(parent,x,y,w,txt,col)
	local b=Instance.new("TextButton",parent); b.Position=UDim2.new(0,x,0,y); b.Size=UDim2.new(0,w,0,30); b.BackgroundColor3=col; b.BorderSizePixel=0; b.Font=Enum.Font.GothamBold; b.TextSize=13; b.TextColor3=Color3.new(1,1,1); b.Text=txt; corner(b,6); return b
end
local startB=actBtn(hive,12,314,100,"▶ START",Color3.fromRGB(50,150,70))
local stopB=actBtn(hive,118,314,100,"■ STOP",Color3.fromRGB(160,55,55))
local prog=Instance.new("TextLabel",hive); prog.Position=UDim2.new(0,228,0,314); prog.Size=UDim2.new(0,202,0,30); prog.BackgroundTransparency=1; prog.Font=Enum.Font.GothamMedium; prog.TextSize=11; prog.TextColor3=Color3.fromRGB(190,190,190); prog.TextXAlignment=Enum.TextXAlignment.Left; prog.Text="Sẵn sàng"

-- ====== PAGE: ESP ======
local espPage=addNav("ESP","👁")
lbl(espPage,14,"ESP tên bee",18,ACCENT)
lbl(espPage,46,"Hiện tên con bee nổi trên mỗi ô tổ ong (đổi màu theo độ hiếm).",12,Color3.fromRGB(200,200,200),true)
local espToggle=actBtn(espPage,14,100,140,"ESP: OFF",Color3.fromRGB(70,70,90))
local espOn,espLabels=false,{}
local espHost=Instance.new("Folder"); espHost.Name="BeeESPHost"; espHost.Parent=gui
for n=1,21 do
	local bbg=Instance.new("BillboardGui",espHost); bbg.Size=UDim2.new(0,200,0,34); bbg.AlwaysOnTop=true; bbg.StudsOffset=Vector3.new(0,2.4,0); bbg.Enabled=false
	local t=Instance.new("TextLabel",bbg); t.Size=UDim2.new(1,0,1,0); t.BackgroundTransparency=1; t.Font=Enum.Font.GothamBold; t.TextSize=16; t.TextStrokeTransparency=0.25
	espLabels[n]={bbg,t}
end
espToggle.MouseButton1Click:Connect(function()
	espOn=not espOn; espToggle.Text="ESP: "..(espOn and "ON" or "OFF"); espToggle.BackgroundColor3=espOn and Color3.fromRGB(60,120,160) or Color3.fromRGB(70,70,90)
end)
task.spawn(function()
	while gui.Parent do
		if espOn then
			for n=1,21 do
				local p=slotPart(n); local _,bee=getSlot(n); local L=espLabels[n]
				if p and bee then L[1].Adornee=p; L[1].Enabled=true; L[2].Text=bee; L[2].TextColor3=RCOL[BEE_EGG[bee] or ""] or Color3.new(1,1,1)
				else L[1].Enabled=false end
			end
		else for n=1,21 do espLabels[n][1].Enabled=false end end
		task.wait(1)
	end
end)

-- ====== PAGE: Settings ======
local setPage=addNav("Settings","⚙")
lbl(setPage,14,"Cài đặt",18,ACCENT)
local function numInput(y,label,val,onset)
	lbl(setPage,y,label,12,Color3.fromRGB(200,200,200))
	local box=Instance.new("TextBox",setPage); box.Position=UDim2.new(0,180,0,y-2); box.Size=UDim2.new(0,90,0,26); box.BackgroundColor3=BG3; box.BorderSizePixel=0; box.Font=Enum.Font.GothamMedium; box.TextSize=13; box.TextColor3=Color3.new(1,1,1); box.Text=tostring(val); corner(box,5)
	box.FocusLost:Connect(function() local v=tonumber(box.Text); if v then onset(v) else box.Text=tostring(val) end end)
end
numInput(56,"Delay mỗi roll (giây):",CFG.DELAY,function(v) CFG.DELAY=v end)
numInput(94,"Max roll / slot:",CFG.MAX_PER_SLOT,function(v) CFG.MAX_PER_SLOT=math.floor(v) end)
lbl(setPage,140,"Delay thấp = roll nhanh nhưng dễ bị kick. Khuyên ≥ 0.3.",11,Color3.fromRGB(255,150,150),true)

-- ====== live update bee hiện tại lên nút slot ======
task.spawn(function()
	while gui.Parent do
		for n=1,21 do local _,cur=getSlot(n)
			if not targets[n] and slotBtns[n] then slotBtns[n].Text="  Slot "..n..(cur and (" ["..cur.."]") or "") end
		end
		task.wait(1.5)
	end
end)

-- ====== START / STOP ======
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
				if left<=0 then
					prog.Text="⛔ HẾT "..egg.."! Xong "..done.."/"..#list
					stoppedNoEgg=true; getgenv().BeeRunning=false
					pcall(function() game.StarterGui:SetCore("SendNotification",{Title="BizzyBee",Text="Hết "..egg..", đã dừng!",Duration=6}) end)
					break
				end
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

-- ====== minimize / close / drag ======
local function dragify(handle, target, onClickMaybe)
	local dragging,moved,ds,sp=false,false
	handle.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
			dragging=true; moved=false; ds=i.Position; sp=target.Position
		end
	end)
	handle.InputEnded:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
			dragging=false
			if not moved and onClickMaybe then onClickMaybe() end
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
			local d=i.Position-ds
			if math.abs(d.X)>4 or math.abs(d.Y)>4 then moved=true end
			target.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
		end
	end)
end
dragify(top, win)
dragify(orb, orb, function() win.Visible=true; orb.Visible=false end)  -- bấm orb (không kéo) -> bung ra

minB.MouseButton1Click:Connect(function() win.Visible=false; orb.Visible=true end)
closeB.MouseButton1Click:Connect(function()
	getgenv().BeeRunning=false
	pcall(function() hl:Destroy() end)
	pcall(function() espHost:Destroy() end)
	gui:Destroy()
end)

showPage("Home")
