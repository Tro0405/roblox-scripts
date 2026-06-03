-- TvFruit — +1 Speed Keyboard Escape | Delta Executor Compatible
-- PlaceId: 118941584817777
-- GUI dùng thư viện theme chung (games/lib/theme.lua) -> đồng bộ màu cyan với mọi game.

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

local CFG = {
    FlySpeed    = 120,
    FlySpeedMin = 10,
    FlySpeedMax = 300,
    FlyAccel    = 0.15,
    FlyBrake    = 0.10,
    LoopDelay   = 1.5,
    ArriveRadius = 4,
}

local flyEnabled      = false
local noclipEnabled   = false
local autoWalkEnabled = false
local looping         = false
local loopCount       = 0
local savedPositions  = {}

local currentVel    = Vector3.zero
local bodyVel, bodyGyro
local flyLoop, noclipLoop, autoWalkLoop, loopThread
local autoWalkAngle = 0
local counterLbl    = nil

local function getChar()     return LocalPlayer.Character end
local function getRootPart() local c=getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHumanoid() local c=getChar(); return c and c:FindFirstChildOfClass("Humanoid") end

-- ==============================  FLY ENGINE
local function stopFlyInternal()
    if flyLoop  then flyLoop:Disconnect();  flyLoop  = nil end
    if bodyVel  then bodyVel:Destroy();     bodyVel  = nil end
    if bodyGyro then bodyGyro:Destroy();    bodyGyro = nil end
    currentVel = Vector3.zero
end

local function startFlyInternal()
    stopFlyInternal()
    local rp = getRootPart(); local hm = getHumanoid()
    if not rp or not hm then return end
    hm.PlatformStand = true
    bodyVel = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(1e6,1e6,1e6); bodyVel.P = 1e4
    bodyVel.Velocity = Vector3.zero; bodyVel.Parent = rp
    bodyGyro = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e6,1e6,1e6); bodyGyro.P = 5e3
    bodyGyro.D = 100; bodyGyro.CFrame = rp.CFrame; bodyGyro.Parent = rp
    flyLoop = RunService.Heartbeat:Connect(function()
        local root = getRootPart()
        if not root or not bodyVel or not bodyVel.Parent then return end
        local camCF = Camera.CFrame; local move = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += camCF.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= camCF.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then move += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.yAxis end
        local speed = CFG.FlySpeed
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then speed *= 2.5 end
        local target, alpha
        if move.Magnitude > 0 then
            target = move.Unit * speed
            alpha  = CFG.FlyAccel
        else
            target = Vector3.zero
            alpha  = CFG.FlyBrake
        end
        currentVel = currentVel:Lerp(target, alpha)
        bodyVel.Velocity = currentVel
        if bodyGyro then
            bodyGyro.CFrame = CFrame.new(Vector3.zero, Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z))
        end
    end)
end

-- ============================== NOCLIP ENGINE
local function stopNoclipInternal()
    if noclipLoop then noclipLoop:Disconnect(); noclipLoop = nil end
    local c = getChar()
    if c then for _,p in ipairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = true end end end
end

local function startNoclipInternal()
    stopNoclipInternal()
    noclipLoop = RunService.Stepped:Connect(function()
        local c = getChar(); if not c then return end
        for _,p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end)
end

-- ============================== AUTO WALK ENGINE
local function stopAutoWalk()
    autoWalkEnabled = false
    if autoWalkLoop then autoWalkLoop:Disconnect(); autoWalkLoop = nil end
    local hm = getHumanoid(); if hm then hm:Move(Vector3.zero, false) end
end

local function startAutoWalk()
    stopAutoWalk()
    autoWalkEnabled = true; autoWalkAngle = 0
    autoWalkLoop = RunService.Heartbeat:Connect(function(dt)
        autoWalkAngle = (autoWalkAngle + dt * 0.8) % (math.pi * 2)
        local hm = getHumanoid(); if not hm then return end
        hm:Move(Vector3.new(math.sin(autoWalkAngle), 0, math.cos(autoWalkAngle)), false)
    end)
end

-- ============================== AUTO WIN ENGINE
local function findWinBlock()
    local wb = workspace:FindFirstChild("Winblocks")
    if wb then local b = wb:FindFirstChild("WinBlock16"); if b then return b end end
    return workspace:FindFirstChild("WinBlock16", true)
end

local function doOneLoop()
    if not looping then return end
    local rp = getRootPart(); local hm = getHumanoid()
    if not rp or not hm then task.wait(1); return end
    local wb = findWinBlock()
    if not wb then task.wait(1); return end
    local targetPos = wb.Position + Vector3.new(0, 6, 0)
    stopFlyInternal()
    startNoclipInternal()
    hm.PlatformStand = true
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e6,1e6,1e6); bv.P = 1e4; bv.Velocity = Vector3.zero; bv.Parent = rp
    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e6,1e6,1e6); bg.P = 5e3; bg.D = 100; bg.CFrame = rp.CFrame; bg.Parent = rp
    while looping do
        local root = getRootPart(); if not root then break end
        local dist = (root.Position - targetPos).Magnitude
        if dist < CFG.ArriveRadius then break end
        bv.Velocity = (targetPos - root.Position).Unit * math.min(CFG.FlySpeed, dist * 3)
        task.wait()
    end
    if bv and bv.Parent then bv:Destroy() end
    if bg and bg.Parent then bg:Destroy() end
    if not looping then
        stopNoclipInternal(); local h = getHumanoid(); if h then h.PlatformStand = false end; return
    end
    stopNoclipInternal()
    local h = getHumanoid(); if h then h.PlatformStand = false end
    task.wait(0.5)
    loopCount += 1
    if counterLbl then counterLbl.Text = "Loops: " .. loopCount end
    task.wait(CFG.LoopDelay)
end

local function startLoop()
    looping = true; loopCount = 0
    if counterLbl then counterLbl.Text = "Loops: 0" end
    loopThread = task.spawn(function() while looping do doOneLoop() end end)
end

local function stopLoop()
    looping = false
    local rp = getRootPart()
    if rp then for _,v in ipairs(rp:GetChildren()) do if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then v:Destroy() end end end
    stopNoclipInternal()
    local hm = getHumanoid(); if hm then hm.PlatformStand = false end
    if flyEnabled    then startFlyInternal()    end
    if noclipEnabled then startNoclipInternal() end
end

-- ============================== AUTO RECONNECT
local function onCharacterAdded(newChar)
    stopFlyInternal(); stopNoclipInternal(); stopAutoWalk()
    currentVel = Vector3.zero
    newChar:WaitForChild("HumanoidRootPart"); newChar:WaitForChild("Humanoid")
    task.wait(0.35)
    if flyEnabled      then startFlyInternal()    end
    if noclipEnabled   then startNoclipInternal() end
    if autoWalkEnabled then startAutoWalk()        end
end
LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
if LocalPlayer.Character then onCharacterAdded(LocalPlayer.Character) end

-- ============================================================
--          GUI — dùng thư viện theme chung (màu cyan)
-- ============================================================
local BASE="https://raw.githubusercontent.com/Tro0405/roblox-scripts/main/games/"
local Lib=loadstring(game:HttpGet(BASE.."lib/theme.lua",true))()
local C=Lib.Colors

local HOST=(gethui and gethui()) or game:GetService("CoreGui")
local oldg=HOST:FindFirstChild("TvFruitSpeed"); if oldg then oldg:Destroy() end

local win=Lib:Window({Title="+1 Speed Escape", Name="TvFruitSpeed", Icon="📺"})

-- HOME
local home=win:Tab("Home","🏠")
Lib.L(home,16,16,"✈  TvFruit",17,C.Accent)
Lib.L(home,16,44,"Script by Tro0405",11,C.TextDim)
Lib.L(home,16,66,"Game: +1 Speed Keyboard Escape",12,C.Accent)
Lib.L(home,16,86,"PlaceId: "..tostring(game.PlaceId),11,C.TextDim)
Lib.L(home,16,118,"Vào tab Features bật Fly / Noclip. Auto Walk để farm speed tự động.",12,C.TextDim,46)

-- FEATURES
local feat=win:Tab("Features","✈")
Lib.Section(feat,12,"Movement")
Lib.Toggle(feat,{y=34,icon="✈",title="Fly",sub="WASD · Space/Ctrl · Shift x2.5",color=Color3.fromRGB(70,120,255),callback=function(on)
    flyEnabled=on
    if on then startFlyInternal() else stopFlyInternal(); local hm=getHumanoid(); if hm then hm.PlatformStand=false end end
end})
Lib.Toggle(feat,{y=96,icon="👻",title="Noclip",sub="Xuyên mọi bức tường",color=Color3.fromRGB(180,60,220),callback=function(on)
    noclipEnabled=on
    if on then startNoclipInternal() else stopNoclipInternal() end
end})

-- AUTO WALK
local aw=win:Tab("Auto Walk","🚶")
Lib.Section(aw,12,"Speed Farming")
Lib.Toggle(aw,{y=34,icon="🚶",title="Auto Walk",sub="Đi vòng tròn farm speed — không cần bàn phím",color=Color3.fromRGB(50,180,100),callback=function(on)
    if on then startAutoWalk() else stopAutoWalk() end
end})
local awInfo=Lib.Card(aw,100,46)
Lib.L(awInfo,10,6,"Nhân vật tự đi vòng tròn chậm. Tự bật lại sau khi chết.",11,C.TextDim,36)

-- AUTO WIN
local awin=win:Tab("Auto Win","🏆")
Lib.Section(awin,12,"WinBlock16")
Lib.Toggle(awin,{y=34,icon="🏆",title="Auto Win",sub="Bay tới WinBlock16 & đáp xuống nhận thưởng",color=Color3.fromRGB(210,150,20),callback=function(on)
    if on then startLoop() else stopLoop() end
end})
local cRow=Lib.Card(awin,100,38)
counterLbl=Lib.L(cRow,12,10,"Loops: 0",13,C.Good)
local rBtn=Lib.Btn(cRow,{Pos=UDim2.new(1,-78,0.5,-12),Size=UDim2.new(0,68,0,24),Text="Reset",Color=Color3.fromRGB(60,60,70),TextSize=11,Radius=5})
rBtn.MouseButton1Click:Connect(function() loopCount=0; counterLbl.Text="Loops: 0" end)

-- SETTINGS
local setp=win:Tab("Settings","⚙")
Lib.Section(setp,12,"Fly Speed")
Lib.Slider(setp,{y=34,label="✈ Fly Speed",min=CFG.FlySpeedMin,max=CFG.FlySpeedMax,default=CFG.FlySpeed,callback=function(v) CFG.FlySpeed=v end})
Lib.Section(setp,108,"Save Position & Teleport")
local saveBtn=Lib.Btn(setp,{Pos=UDim2.new(0,12,0,128),Size=UDim2.new(0,128,0,28),Text="+ Save Position",Color=C.Good,TextSize=12})
local listF=Lib.Scroll(setp,UDim2.new(0,12,0,164),UDim2.new(1,-24,0,150))
local emptyL=Lib.L(listF,6,8,"Chưa lưu vị trí nào",11,Color3.fromRGB(110,116,128))
local function addEntry(idx,name,cf)
    emptyL.Visible=false
    local row=Instance.new("Frame",listF); row.Size=UDim2.new(1,-8,0,30); row.BackgroundColor3=C.Bg3; row.BorderSizePixel=0; row.LayoutOrder=idx; Lib.Corner(row,6)
    local nL=Lib.L(row,12,0,name,11,C.Text); nL.Size=UDim2.new(0,120,1,0)
    local tpB=Lib.Btn(row,{Pos=UDim2.new(1,-128,0.5,-11),Size=UDim2.new(0,58,0,22),Text="Teleport",Color=Color3.fromRGB(40,120,160),TextSize=10,Radius=5})
    tpB.MouseButton1Click:Connect(function() local rp=getRootPart(); if rp then rp.CFrame=cf end end)
    local dB=Lib.Btn(row,{Pos=UDim2.new(1,-30,0.5,-11),Size=UDim2.new(0,24,0,22),Text="X",Color=Color3.fromRGB(170,55,55),TextSize=11,Radius=5})
    dB.MouseButton1Click:Connect(function()
        for i,v in ipairs(savedPositions) do if v[1]==name then table.remove(savedPositions,i); break end end
        row:Destroy(); if #savedPositions==0 then emptyL.Visible=true end
    end)
end
saveBtn.MouseButton1Click:Connect(function()
    local rp=getRootPart(); if not rp then return end
    local idx=#savedPositions+1; local name="Position "..idx; local cf=rp.CFrame
    table.insert(savedPositions,{name,cf}); addEntry(idx,name,cf)
end)

win:OnClose(function()
    flyEnabled=false; noclipEnabled=false
    stopFlyInternal(); stopNoclipInternal(); stopAutoWalk(); stopLoop()
end)
win:Show("Home")
print("[TvFruit] +1 Speed Escape loaded (cyan theme)")
