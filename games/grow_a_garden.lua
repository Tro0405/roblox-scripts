--[[
	Grow a Garden — BizzyBee Hive Manager
	PlaceId: 126884695634066
	Nạp qua router TvFruit.lua. Chức năng:
	- Menu chọn slot (1-21) + chọn bee, highlight ô vật lý trong game
	- Tự map bee -> loại trứng, tự equip trứng từ Backpack
	- Auto re-roll tới khi ra bee mong muốn, hiện tỉ lệ % + số trứng còn lại
	- ESP tên bee nổi trên từng ô (bật/tắt)
	- Tự dừng khi trúng bee hoặc hết trứng
]]

local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local LP=game:GetService("Players").LocalPlayer
local DataService=require(RS.Modules.DataService)
local BizzyBee=RS.GameEvents.BizzyBeeEvent
local PlaceRE,ReplaceRE=BizzyBee.PlaceBeeEggRE,BizzyBee.ReplaceBeeRE
local DELAY,MAX_PER_SLOT=0.45,400

-- pool: bee <- trứng + weight
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

-- equip + đếm trứng theo tiền tố tên
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
			if c:IsA("Tool") and c.Name:sub(1,#egg)==egg then
				return tonumber(c.Name:match("x(%d+)")) or 1
			end
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

-- highlight ô
local hl=Instance.new("Highlight"); hl.FillColor=Color3.fromRGB(0,255,80); hl.FillTransparency=0.4; hl.OutlineColor=Color3.fromRGB(255,255,0); hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
hl.Parent=(gethui and gethui()) or game:GetService("CoreGui")
local hbb=Instance.new("BillboardGui"); hbb.Size=UDim2.new(0,160,0,40); hbb.AlwaysOnTop=true; hbb.StudsOffset=Vector3.new(0,3,0); hbb.Parent=hl
local hbl=Instance.new("TextLabel",hbb); hbl.Size=UDim2.new(1,0,1,0); hbl.BackgroundTransparency=1; hbl.Font=Enum.Font.GothamBold; hbl.TextSize=20; hbl.TextColor3=Color3.fromRGB(0,255,80); hbl.TextStrokeTransparency=0
local function highlightSlot(n) local p=slotPart(n); hl.Adornee=p; hbb.Adornee=p; hbl.Text="SLOT "..n end

-- GUI
local gui=Instance.new("ScreenGui"); gui.Name="BeeMenu"; gui.ResetOnSpawn=false
gui.Parent=(gethui and gethui()) or game:GetService("CoreGui")
local main=Instance.new("Frame",gui); main.Size=UDim2.new(0,560,0,410); main.Position=UDim2.new(0.5,-280,0.5,-205); main.BackgroundColor3=Color3.fromRGB(20,20,28); main.BorderSizePixel=0
Instance.new("UICorner",main).CornerRadius=UDim.new(0,10)
local barF=Instance.new("Frame",main); barF.Size=UDim2.new(1,0,0,34); barF.BackgroundColor3=Color3.fromRGB(30,30,42); barF.BorderSizePixel=0
Instance.new("UICorner",barF).CornerRadius=UDim.new(0,10)
local title=Instance.new("TextLabel",barF); title.Size=UDim2.new(1,-20,1,0); title.Position=UDim2.new(0,12,0,0); title.BackgroundTransparency=1; title.Font=Enum.Font.GothamBold; title.TextSize=14; title.TextColor3=Color3.fromRGB(255,210,60); title.TextXAlignment=Enum.TextXAlignment.Left; title.Text="🐝 BizzyBee Manager — chọn slot → chọn bee (tự equip trứng)"

local function scroll(x,w)
	local s=Instance.new("ScrollingFrame",main); s.Position=UDim2.new(0,x,0,40); s.Size=UDim2.new(0,w,1,-90); s.BackgroundColor3=Color3.fromRGB(26,26,36); s.BorderSizePixel=0; s.ScrollBarThickness=5; s.AutomaticCanvasSize=Enum.AutomaticSize.Y; s.CanvasSize=UDim2.new(0,0,0,0)
	Instance.new("UICorner",s).CornerRadius=UDim.new(0,6)
	local l=Instance.new("UIListLayout",s); l.Padding=UDim.new(0,3)
	local p=Instance.new("UIPadding",s); p.PaddingTop=UDim.new(0,4); p.PaddingLeft=UDim.new(0,4); p.PaddingRight=UDim.new(0,4)
	return s
end
local slotList=scroll(10,250); local beeList=scroll(280,270)

local selectedSlot,slotBtns,targets=nil,{},{}
for n=1,21 do
	local b=Instance.new("TextButton",slotList); b.Size=UDim2.new(1,-8,0,30); b.BackgroundColor3=Color3.fromRGB(38,38,52); b.BorderSizePixel=0; b.Font=Enum.Font.GothamMedium; b.TextSize=12; b.TextColor3=Color3.new(1,1,1); b.TextXAlignment=Enum.TextXAlignment.Left; b.Text="  Slot "..n
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,5); slotBtns[n]=b
	b.MouseButton1Click:Connect(function()
		selectedSlot=n; highlightSlot(n)
		for i,bt in pairs(slotBtns) do bt.BackgroundColor3=(i==n) and Color3.fromRGB(60,90,150) or Color3.fromRGB(38,38,52) end
		title.Text="🐝 Đang chọn SLOT "..n.." — bấm 1 bee bên phải"
	end)
end
for _,bee in ipairs(BEELIST) do
	local egg=BEE_EGG[bee]
	local b=Instance.new("TextButton",beeList); b.Size=UDim2.new(1,-8,0,28); b.BackgroundColor3=Color3.fromRGB(38,38,52); b.BorderSizePixel=0; b.Font=Enum.Font.GothamMedium; b.TextSize=11; b.TextColor3=RCOL[egg]; b.TextXAlignment=Enum.TextXAlignment.Left
	b.Text="  "..bee.."  ("..BEE_PCT[bee].."%)"
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,5)
	b.MouseButton1Click:Connect(function()
		if not selectedSlot then title.Text="⚠️ Chọn SLOT trước!"; return end
		targets[selectedSlot]=bee
		slotBtns[selectedSlot].Text="  Slot "..selectedSlot.." → "..bee
		slotBtns[selectedSlot].TextColor3=RCOL[egg]
		title.Text="✅ Slot "..selectedSlot.." = "..bee.." ["..egg.."]"
	end)
end

-- ESP tên bee trên mỗi ô
local espOn,espLabels=false,{}
local espHost=Instance.new("Folder"); espHost.Name="BeeESPHost"; espHost.Parent=gui
for n=1,21 do
	local bbg=Instance.new("BillboardGui",espHost); bbg.Size=UDim2.new(0,200,0,34); bbg.AlwaysOnTop=true; bbg.StudsOffset=Vector3.new(0,2.4,0); bbg.Enabled=false
	local t=Instance.new("TextLabel",bbg); t.Size=UDim2.new(1,0,1,0); t.BackgroundTransparency=1; t.Font=Enum.Font.GothamBold; t.TextSize=16; t.TextStrokeTransparency=0.25
	espLabels[n]={bbg,t}
end
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

-- nút dưới
local function mkBtn(x,w,txt,col)
	local b=Instance.new("TextButton",main); b.Size=UDim2.new(0,w,0,32); b.Position=UDim2.new(0,x,1,-40); b.BackgroundColor3=col; b.BorderSizePixel=0; b.Font=Enum.Font.GothamBold; b.TextSize=13; b.TextColor3=Color3.new(1,1,1); b.Text=txt
	Instance.new("UICorner",b).CornerRadius=UDim.new(0,6); return b
end
local startB=mkBtn(10,95,"▶ START",Color3.fromRGB(50,150,70))
local stopB=mkBtn(110,95,"■ STOP",Color3.fromRGB(160,55,55))
local espB=mkBtn(210,95,"ESP: OFF",Color3.fromRGB(70,70,90))
espB.MouseButton1Click:Connect(function() espOn=not espOn; espB.Text="ESP: "..(espOn and "ON" or "OFF"); espB.BackgroundColor3=espOn and Color3.fromRGB(60,120,160) or Color3.fromRGB(70,70,90) end)
local prog=Instance.new("TextLabel",main); prog.Position=UDim2.new(0,315,1,-40); prog.Size=UDim2.new(0,235,0,32); prog.BackgroundTransparency=1; prog.Font=Enum.Font.GothamMedium; prog.TextSize=11; prog.TextColor3=Color3.fromRGB(190,190,190); prog.TextXAlignment=Enum.TextXAlignment.Left; prog.Text="Sẵn sàng"

-- live update bee hiện tại lên nút slot
task.spawn(function()
	while gui.Parent do
		for n=1,21 do local _,cur=getSlot(n)
			if not targets[n] and slotBtns[n] then slotBtns[n].Text="  Slot "..n..(cur and (" ["..cur.."]") or "") end
		end
		task.wait(1.5)
	end
end)

-- START
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
					prog.Text="⛔ HẾT "..egg.."! Xong "..done.."/"..#list.." slot"
					stoppedNoEgg=true; getgenv().BeeRunning=false
					pcall(function() game.StarterGui:SetCore("SendNotification",{Title="BizzyBee",Text="Hết "..egg..", đã dừng!",Duration=6}) end)
					break
				end
				if not equipEgg(egg) then prog.Text="⛔ Không cầm được "..egg; getgenv().BeeRunning=false; break end
				if not uuid then PlaceRE:FireServer(n); task.wait(DELAY)
				else
					ReplaceRE:FireServer(n,uuid); att=att+1
					local t0=tick(); repeat task.wait(0.05) until (getSlot(n))~=uuid or tick()-t0>2
					task.wait(DELAY)
					if att>=MAX_PER_SLOT then break end
				end
			end
			if stoppedNoEgg then break end
		end
		getgenv().BeeRunning=false
		if not stoppedNoEgg then prog.Text="✅ Xong "..done.."/"..#list.." slot" end
	end)
end)
stopB.MouseButton1Click:Connect(function() getgenv().BeeRunning=false; prog.Text="■ Đã dừng" end)

-- kéo thả
local drag,ds,sp
barF.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=true;ds=i.Position;sp=main.Position end end)
barF.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then drag=false end end)
UIS.InputChanged:Connect(function(i) if drag and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then local d=i.Position-ds; main.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end)
