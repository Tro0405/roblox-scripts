-- TvFruit v2.0 by Tro0405
-- +1 Speed Keyboard Escape | Delta Executor Compatible

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
--                          GUI
-- ============================================================
local guiParent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")

local old = guiParent:FindFirstChild("TvFruitGUI")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "TvFruitGUI"; ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = guiParent

-- Main window (520 x 400)
local Main = Instance.new("Frame")
Main.Size = UDim2.new(0, 520, 0, 400)
Main.Position = UDim2.new(0.5, -260, 0.5, -200)
Main.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
local wborder = Instance.new("UIStroke")
wborder.Color = Color3.fromRGB(45, 45, 45); wborder.Thickness = 1; wborder.Parent = Main

-- ---- SIDEBAR (160px) ----
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 160, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Sidebar.BorderSizePixel = 0; Sidebar.Parent = Main

-- Vertical separator
local Sep = Instance.new("Frame")
Sep.Size = UDim2.new(0, 1, 1, 0); Sep.Position = UDim2.new(0, 160, 0, 0)
Sep.BackgroundColor3 = Color3.fromRGB(38, 38, 38); Sep.BorderSizePixel = 0; Sep.Parent = Main

-- Sidebar title block (draggable)
local SideTitle = Instance.new("Frame")
SideTitle.Size = UDim2.new(1, 0, 0, 58)
SideTitle.BackgroundColor3 = Color3.fromRGB(26, 26, 26)
SideTitle.BorderSizePixel = 0; SideTitle.Parent = Sidebar

local STitleSep = Instance.new("Frame")
STitleSep.Size = UDim2.new(1, 0, 0, 1); STitleSep.Position = UDim2.new(0, 0, 1, -1)
STitleSep.BackgroundColor3 = Color3.fromRGB(38, 38, 38); STitleSep.BorderSizePixel = 0; STitleSep.Parent = SideTitle

local STLbl = Instance.new("TextLabel")
STLbl.Size = UDim2.new(1, -12, 0, 26); STLbl.Position = UDim2.new(0, 12, 0, 8)
STLbl.BackgroundTransparency = 1; STLbl.Text = "✈  TvFruit"
STLbl.Font = Enum.Font.GothamBold; STLbl.TextSize = 16
STLbl.TextColor3 = Color3.new(1, 1, 1); STLbl.TextXAlignment = Enum.TextXAlignment.Left
STLbl.Parent = SideTitle

local SVLbl = Instance.new("TextLabel")
SVLbl.Size = UDim2.new(1, -12, 0, 14); SVLbl.Position = UDim2.new(0, 12, 0, 36)
SVLbl.BackgroundTransparency = 1; SVLbl.Text = "v2.0  ·  by Tro0405"
SVLbl.Font = Enum.Font.Gotham; SVLbl.TextSize = 10
SVLbl.TextColor3 = Color3.fromRGB(90, 90, 90); SVLbl.TextXAlignment = Enum.TextXAlignment.Left
SVLbl.Parent = SideTitle

-- ---- CONTENT AREA ----
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -161, 1, 0); ContentArea.Position = UDim2.new(0, 161, 0, 0)
ContentArea.BackgroundTransparency = 1; ContentArea.ClipsDescendants = true
ContentArea.Parent = Main

-- ---- NAV SYSTEM ----
local pages    = {}
local navBtns  = {}
local ACCENT   = Color3.fromRGB(85, 85, 210)
local navY     = 66

local function selectPage(name)
    for n, frame in pairs(pages)   do frame.Visible = (n == name) end
    for n, btn   in pairs(navBtns) do
        local bar = btn:FindFirstChild("Bar")
        local lbl = btn:FindFirstChild("Lbl")
        local ico = btn:FindFirstChild("Ico")
        if n == name then
            btn.BackgroundTransparency = 0
            if bar then bar.Visible = true end
            if lbl then lbl.TextColor3 = Color3.new(1,1,1) end
            if ico then ico.TextColor3 = Color3.new(1,1,1) end
        else
            btn.BackgroundTransparency = 1
            if bar then bar.Visible = false end
            if lbl then lbl.TextColor3 = Color3.fromRGB(110,110,110) end
            if ico then ico.TextColor3 = Color3.fromRGB(110,110,110) end
        end
    end
end

local function addNav(icon, label, pageName)
    local btn = Instance.new("TextButton")
    btn.Name = pageName
    btn.Size = UDim2.new(1, 0, 0, 40); btn.Position = UDim2.new(0, 0, 0, navY)
    btn.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    btn.BackgroundTransparency = 1; btn.BorderSizePixel = 0
    btn.Text = ""; btn.AutoButtonColor = false; btn.Parent = Sidebar

    -- left accent bar
    local bar = Instance.new("Frame"); bar.Name = "Bar"
    bar.Size = UDim2.new(0, 3, 0.55, 0); bar.Position = UDim2.new(0, 0, 0.225, 0)
    bar.BackgroundColor3 = ACCENT; bar.BorderSizePixel = 0; bar.Visible = false; bar.Parent = btn
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local ico = Instance.new("TextLabel"); ico.Name = "Ico"
    ico.Size = UDim2.new(0, 22, 1, 0); ico.Position = UDim2.new(0, 14, 0, 0)
    ico.BackgroundTransparency = 1; ico.Text = icon
    ico.Font = Enum.Font.GothamBold; ico.TextSize = 14
    ico.TextColor3 = Color3.fromRGB(110,110,110); ico.Parent = btn

    local lbl = Instance.new("TextLabel"); lbl.Name = "Lbl"
    lbl.Size = UDim2.new(1, -42, 1, 0); lbl.Position = UDim2.new(0, 40, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = label
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 12
    lbl.TextColor3 = Color3.fromRGB(110,110,110)
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = btn

    btn.MouseButton1Click:Connect(function() selectPage(pageName) end)
    btn.MouseEnter:Connect(function()
        if navBtns[pageName] and pageName ~= (function() for n,_ in pairs(navBtns) do if navBtns[n] == btn and pages[n] and pages[n].Visible then return n end end end)() then
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundTransparency = 0.7}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if not pages[pageName].Visible then
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundTransparency = 1}):Play()
        end
    end)

    navBtns[pageName] = btn
    navY = navY + 40

    -- Page (ScrollingFrame inside content area)
    local page = Instance.new("ScrollingFrame"); page.Name = pageName
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1; page.BorderSizePixel = 0
    page.ScrollBarThickness = 3; page.ScrollBarImageColor3 = Color3.fromRGB(60,60,60)
    page.CanvasSize = UDim2.new(0,0,0,0); page.Visible = false; page.Parent = ContentArea
    pages[pageName] = page
    return page
end

-- ---- SHARED UI HELPERS ----
local function pageTitle(parent, text)
    local hdr = Instance.new("Frame")
    hdr.Size = UDim2.new(1, 0, 0, 50); hdr.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    hdr.BorderSizePixel = 0; hdr.Parent = parent
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(1, 0, 0, 1); sep.Position = UDim2.new(0, 0, 1, -1)
    sep.BackgroundColor3 = Color3.fromRGB(38, 38, 38); sep.BorderSizePixel = 0; sep.Parent = hdr
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -16, 1, 0); lbl.Position = UDim2.new(0, 16, 0, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = text
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 15
    lbl.TextColor3 = Color3.new(1,1,1); lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = hdr
end

local function sectionLbl(parent, y, text)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -20, 0, 18); lbl.Position = UDim2.new(0, 16, 0, y)
    lbl.BackgroundTransparency = 1; lbl.Text = text
    lbl.Font = Enum.Font.GothamBold; lbl.TextSize = 10
    lbl.TextColor3 = Color3.fromRGB(75, 75, 190)
    lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.Parent = parent
end

-- Toggle row — matches Speed Hub X style
local function makeToggle(parent, y, icon, title, subtitle, color, callback)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -20, 0, 56); row.Position = UDim2.new(0, 10, 0, y)
    row.BackgroundColor3 = Color3.fromRGB(22, 22, 22); row.BorderSizePixel = 0; row.Parent = parent
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local icoBox = Instance.new("Frame")
    icoBox.Size = UDim2.new(0, 34, 0, 34); icoBox.Position = UDim2.new(0, 10, 0.5, -17)
    icoBox.BackgroundColor3 = color; icoBox.BorderSizePixel = 0; icoBox.Parent = row
    Instance.new("UICorner", icoBox).CornerRadius = UDim.new(0, 7)
    local icoLbl = Instance.new("TextLabel")
    icoLbl.Size = UDim2.new(1,0,1,0); icoLbl.BackgroundTransparency = 1
    icoLbl.Text = icon; icoLbl.Font = Enum.Font.GothamBold; icoLbl.TextSize = 16
    icoLbl.TextColor3 = Color3.new(1,1,1); icoLbl.Parent = icoBox

    local tLbl = Instance.new("TextLabel")
    tLbl.Size = UDim2.new(1, -116, 0, 19); tLbl.Position = UDim2.new(0, 54, 0, 10)
    tLbl.BackgroundTransparency = 1; tLbl.Text = title
    tLbl.Font = Enum.Font.GothamBold; tLbl.TextSize = 13
    tLbl.TextColor3 = Color3.new(1,1,1); tLbl.TextXAlignment = Enum.TextXAlignment.Left; tLbl.Parent = row

    local sLbl = Instance.new("TextLabel")
    sLbl.Size = UDim2.new(1, -116, 0, 14); sLbl.Position = UDim2.new(0, 54, 0, 31)
    sLbl.BackgroundTransparency = 1; sLbl.Text = subtitle
    sLbl.Font = Enum.Font.Gotham; sLbl.TextSize = 10
    sLbl.TextColor3 = Color3.fromRGB(95,95,95); sLbl.TextXAlignment = Enum.TextXAlignment.Left; sLbl.Parent = row

    local pill = Instance.new("Frame")
    pill.Size = UDim2.new(0, 44, 0, 22); pill.Position = UDim2.new(1, -54, 0.5, -11)
    pill.BackgroundColor3 = Color3.fromRGB(48,48,48); pill.BorderSizePixel = 0; pill.Parent = row
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 16, 0, 16); dot.Position = UDim2.new(0, 3, 0.5, -8)
    dot.BackgroundColor3 = Color3.new(1,1,1); dot.BorderSizePixel = 0; dot.Parent = pill
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local state = false
    local clickBtn = Instance.new("TextButton")
    clickBtn.Size = UDim2.new(1,0,1,0); clickBtn.BackgroundTransparency = 1
    clickBtn.Text = ""; clickBtn.Parent = row
    clickBtn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(pill, TweenInfo.new(0.2), {BackgroundColor3 = state and color or Color3.fromRGB(48,48,48)}):Play()
        TweenService:Create(dot,  TweenInfo.new(0.2), {Position = state and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)}):Play()
        callback(state)
    end)
    return row
end

-- ============================================================
--                       BUILD PAGES
-- ============================================================

-- ===== HOME =====
do
    local p = addNav("🏠", "Home", "Home")
    pageTitle(p, "Home")
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1,-20,0,108); card.Position = UDim2.new(0,10,0,60)
    card.BackgroundColor3 = Color3.fromRGB(22,22,22); card.BorderSizePixel = 0; card.Parent = p
    Instance.new("UICorner", card).CornerRadius = UDim.new(0,8)

    local info = {
        {"✈  TvFruit", Enum.Font.GothamBold, 15, Color3.new(1,1,1)},
        {"Script by Tro0405", Enum.Font.Gotham, 11, Color3.fromRGB(130,130,130)},
        {"Game: +1 Speed Keyboard Escape", Enum.Font.Gotham, 10, Color3.fromRGB(100,100,200)},
        {"PlaceId: "..tostring(game.PlaceId), Enum.Font.Gotham, 10, Color3.fromRGB(70,70,70)},
    }
    for i, v in ipairs(info) do
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1,-16,0,20); l.Position = UDim2.new(0,12,0,8+(i-1)*24)
        l.BackgroundTransparency = 1; l.Text = v[1]
        l.Font = v[2]; l.TextSize = v[3]; l.TextColor3 = v[4]
        l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = card
    end
    p.CanvasSize = UDim2.new(0,0,0,190)
end

-- ===== FEATURES (Fly & Noclip) =====
do
    local p = addNav("✈", "Features", "Features")
    pageTitle(p, "Features")
    sectionLbl(p, 58, "MOVEMENT")
    makeToggle(p, 78, "✈", "Fly", "WASD · Space/Ctrl · Shift boost x2.5",
        Color3.fromRGB(70,120,255), function(on)
            flyEnabled = on
            if on then startFlyInternal() else
                stopFlyInternal()
                local hm = getHumanoid(); if hm then hm.PlatformStand = false end
            end
        end)
    makeToggle(p, 144, "👻", "Noclip", "Pass through all walls",
        Color3.fromRGB(180,60,220), function(on)
            noclipEnabled = on
            if on then startNoclipInternal() else stopNoclipInternal() end
        end)
    p.CanvasSize = UDim2.new(0,0,0,220)
end

-- ===== AUTO WALK =====
do
    local p = addNav("🚶", "Auto Walk", "AutoWalk")
    pageTitle(p, "Auto Walk")
    sectionLbl(p, 58, "SPEED FARMING")
    makeToggle(p, 78, "🚶", "Auto Walk", "Move in circles to earn speed — no keyboard needed",
        Color3.fromRGB(50,180,100), function(on)
            autoWalkEnabled = on
            if on then startAutoWalk() else stopAutoWalk() end
        end)

    -- Info box
    local infoBox = Instance.new("Frame")
    infoBox.Size = UDim2.new(1,-20,0,44); infoBox.Position = UDim2.new(0,10,0,144)
    infoBox.BackgroundColor3 = Color3.fromRGB(22,22,22); infoBox.BorderSizePixel = 0; infoBox.Parent = p
    Instance.new("UICorner", infoBox).CornerRadius = UDim.new(0,8)
    local iLbl = Instance.new("TextLabel")
    iLbl.Size = UDim2.new(1,-16,1,0); iLbl.Position = UDim2.new(0,10,0,0)
    iLbl.BackgroundTransparency = 1
    iLbl.Text = "Character walks in a slow circle automatically.\nAuto re-enables after death."
    iLbl.Font = Enum.Font.Gotham; iLbl.TextSize = 11
    iLbl.TextColor3 = Color3.fromRGB(90,90,90); iLbl.TextXAlignment = Enum.TextXAlignment.Left
    iLbl.TextYAlignment = Enum.TextYAlignment.Center; iLbl.Parent = infoBox
    p.CanvasSize = UDim2.new(0,0,0,210)
end

-- ===== AUTO WIN =====
do
    local p = addNav("🏆", "Auto Win", "AutoWin")
    pageTitle(p, "Auto Win")
    sectionLbl(p, 58, "WINBLOCK16")
    makeToggle(p, 78, "🏆", "Auto Win", "Fly to WinBlock16 and land naturally for reward",
        Color3.fromRGB(210,150,20), function(on)
            if on then startLoop() else stopLoop() end
        end)

    -- Counter row
    local cRow = Instance.new("Frame")
    cRow.Size = UDim2.new(1,-20,0,38); cRow.Position = UDim2.new(0,10,0,144)
    cRow.BackgroundColor3 = Color3.fromRGB(22,22,22); cRow.BorderSizePixel = 0; cRow.Parent = p
    Instance.new("UICorner", cRow).CornerRadius = UDim.new(0,8)

    local cLbl = Instance.new("TextLabel")
    cLbl.Size = UDim2.new(0.5,0,1,0); cLbl.Position = UDim2.new(0,12,0,0)
    cLbl.BackgroundTransparency = 1; cLbl.Text = "Loops: 0"
    cLbl.Font = Enum.Font.GothamBold; cLbl.TextSize = 13
    cLbl.TextColor3 = Color3.fromRGB(100,220,100)
    cLbl.TextXAlignment = Enum.TextXAlignment.Left; cLbl.Parent = cRow
    counterLbl = cLbl

    local rBtn = Instance.new("TextButton")
    rBtn.Size = UDim2.new(0,68,0,24); rBtn.Position = UDim2.new(1,-76,0.5,-12)
    rBtn.BackgroundColor3 = Color3.fromRGB(48,48,48); rBtn.Text = "Reset"
    rBtn.TextColor3 = Color3.new(1,1,1); rBtn.Font = Enum.Font.GothamBold
    rBtn.TextSize = 11; rBtn.BorderSizePixel = 0; rBtn.Parent = cRow
    Instance.new("UICorner", rBtn).CornerRadius = UDim.new(0,5)
    rBtn.MouseButton1Click:Connect(function()
        loopCount = 0; cLbl.Text = "Loops: 0"
    end)
    p.CanvasSize = UDim2.new(0,0,0,210)
end

-- ===== SETTINGS (Fly Speed + Save Position) =====
do
    local p = addNav("⚙", "Settings", "Settings")
    pageTitle(p, "Settings")

    -- Fly speed slider
    sectionLbl(p, 58, "FLY SPEED")
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1,-20,0,68); bg.Position = UDim2.new(0,10,0,78)
    bg.BackgroundColor3 = Color3.fromRGB(22,22,22); bg.BorderSizePixel = 0; bg.Parent = p
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0,8)

    local topR = Instance.new("Frame")
    topR.Size = UDim2.new(1,-16,0,22); topR.Position = UDim2.new(0,8,0,8)
    topR.BackgroundTransparency = 1; topR.Parent = bg
    local sTL = Instance.new("TextLabel")
    sTL.Size = UDim2.new(0.6,0,1,0); sTL.BackgroundTransparency = 1; sTL.Text = "✈  Fly Speed"
    sTL.Font = Enum.Font.GothamBold; sTL.TextSize = 12; sTL.TextColor3 = Color3.new(1,1,1)
    sTL.TextXAlignment = Enum.TextXAlignment.Left; sTL.Parent = topR
    local sVL = Instance.new("TextLabel")
    sVL.Size = UDim2.new(0.4,0,1,0); sVL.Position = UDim2.new(0.6,0,0,0)
    sVL.BackgroundTransparency = 1; sVL.Text = tostring(CFG.FlySpeed)
    sVL.Font = Enum.Font.GothamBold; sVL.TextSize = 13
    sVL.TextColor3 = Color3.fromRGB(100,180,255)
    sVL.TextXAlignment = Enum.TextXAlignment.Right; sVL.Parent = topR

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1,-16,0,6); track.Position = UDim2.new(0,8,0,46)
    track.BackgroundColor3 = Color3.fromRGB(40,40,40); track.BorderSizePixel = 0; track.Parent = bg
    Instance.new("UICorner", track).CornerRadius = UDim.new(1,0)
    local initPct = (CFG.FlySpeed-CFG.FlySpeedMin)/(CFG.FlySpeedMax-CFG.FlySpeedMin)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(initPct,0,1,0); fill.BackgroundColor3 = Color3.fromRGB(80,120,255)
    fill.BorderSizePixel = 0; fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
    local thumb = Instance.new("Frame")
    thumb.Size = UDim2.new(0,16,0,16); thumb.Position = UDim2.new(initPct,-8,0.5,-8)
    thumb.BackgroundColor3 = Color3.new(1,1,1); thumb.BorderSizePixel = 0; thumb.ZIndex = 3; thumb.Parent = track
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1,0)
    local ts = Instance.new("UIStroke"); ts.Color = Color3.fromRGB(80,120,255); ts.Thickness = 2; ts.Parent = thumb

    local dragging = false
    local function updateSlider(absX)
        local pct = math.clamp((absX-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        fill.Size = UDim2.new(pct,0,1,0); thumb.Position = UDim2.new(pct,-8,0.5,-8)
        CFG.FlySpeed = math.floor(CFG.FlySpeedMin + pct*(CFG.FlySpeedMax-CFG.FlySpeedMin))
        sVL.Text = tostring(CFG.FlySpeed)
    end
    thumb.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true end end)
    track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true; updateSlider(i.Position.X) end end)
    UserInputService.InputChanged:Connect(function(i) if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then updateSlider(i.Position.X) end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end end)

    -- Save Position
    sectionLbl(p, 156, "SAVE POSITION & TELEPORT")
    local sHdr = Instance.new("Frame")
    sHdr.Size = UDim2.new(1,-20,0,30); sHdr.Position = UDim2.new(0,10,0,176)
    sHdr.BackgroundTransparency = 1; sHdr.Parent = p

    local saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(0,120,0,28); saveBtn.Position = UDim2.new(0,0,0,0)
    saveBtn.BackgroundColor3 = Color3.fromRGB(50,180,80); saveBtn.Text = "+ Save Position"
    saveBtn.TextColor3 = Color3.new(1,1,1); saveBtn.Font = Enum.Font.GothamBold
    saveBtn.TextSize = 11; saveBtn.BorderSizePixel = 0; saveBtn.Parent = sHdr
    Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0,6)

    local listF = Instance.new("ScrollingFrame")
    listF.Size = UDim2.new(1,-20,0,118); listF.Position = UDim2.new(0,10,0,214)
    listF.BackgroundColor3 = Color3.fromRGB(20,20,20); listF.BorderSizePixel = 0
    listF.ScrollBarThickness = 3; listF.ScrollBarImageColor3 = Color3.fromRGB(70,70,70)
    listF.CanvasSize = UDim2.new(0,0,0,0); listF.Parent = p
    Instance.new("UICorner", listF).CornerRadius = UDim.new(0,8)
    local ll = Instance.new("UIListLayout"); ll.Padding = UDim.new(0,4)
    ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Parent = listF
    local lp = Instance.new("UIPadding"); lp.PaddingTop = UDim.new(0,4); lp.PaddingLeft = UDim.new(0,4); lp.Parent = listF

    local emptyL = Instance.new("TextLabel")
    emptyL.Size = UDim2.new(1,-8,0,40); emptyL.BackgroundTransparency = 1
    emptyL.Text = "No saved positions yet"; emptyL.Font = Enum.Font.Gotham
    emptyL.TextSize = 11; emptyL.TextColor3 = Color3.fromRGB(75,75,75); emptyL.Parent = listF

    local function refreshCanvas() listF.CanvasSize = UDim2.new(0,0,0, ll.AbsoluteContentSize.Y + 8) end

    local function addEntry(idx, name, cf)
        emptyL.Visible = false
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1,-8,0,30); row.BackgroundColor3 = Color3.fromRGB(28,28,28)
        row.BorderSizePixel = 0; row.LayoutOrder = idx; row.Parent = listF
        Instance.new("UICorner", row).CornerRadius = UDim.new(0,6)
        local dotF = Instance.new("Frame")
        dotF.Size = UDim2.new(0,7,0,7); dotF.Position = UDim2.new(0,7,0.5,-3.5)
        dotF.BackgroundColor3 = Color3.fromRGB(80,120,255); dotF.BorderSizePixel = 0; dotF.Parent = row
        Instance.new("UICorner", dotF).CornerRadius = UDim.new(1,0)
        local nL = Instance.new("TextLabel")
        nL.Size = UDim2.new(0,110,1,0); nL.Position = UDim2.new(0,20,0,0)
        nL.BackgroundTransparency = 1; nL.Text = name; nL.Font = Enum.Font.Gotham
        nL.TextSize = 11; nL.TextColor3 = Color3.new(1,1,1)
        nL.TextXAlignment = Enum.TextXAlignment.Left; nL.Parent = row
        local tpB = Instance.new("TextButton")
        tpB.Size = UDim2.new(0,58,0,22); tpB.Position = UDim2.new(1,-128,0.5,-11)
        tpB.BackgroundColor3 = Color3.fromRGB(60,120,220); tpB.Text = "Teleport"
        tpB.TextColor3 = Color3.new(1,1,1); tpB.Font = Enum.Font.GothamBold
        tpB.TextSize = 10; tpB.BorderSizePixel = 0; tpB.Parent = row
        Instance.new("UICorner", tpB).CornerRadius = UDim.new(0,5)
        tpB.MouseButton1Click:Connect(function()
            local rp = getRootPart(); if rp then rp.CFrame = cf end
        end)
        local dB = Instance.new("TextButton")
        dB.Size = UDim2.new(0,24,0,22); dB.Position = UDim2.new(1,-30,0.5,-11)
        dB.BackgroundColor3 = Color3.fromRGB(180,50,50); dB.Text = "X"
        dB.TextColor3 = Color3.new(1,1,1); dB.Font = Enum.Font.GothamBold
        dB.TextSize = 11; dB.BorderSizePixel = 0; dB.Parent = row
        Instance.new("UICorner", dB).CornerRadius = UDim.new(0,5)
        dB.MouseButton1Click:Connect(function()
            for i,v in ipairs(savedPositions) do if v[1]==name then table.remove(savedPositions,i); break end end
            row:Destroy(); if #savedPositions==0 then emptyL.Visible=true end; refreshCanvas()
        end)
        task.defer(refreshCanvas)
    end

    saveBtn.MouseButton1Click:Connect(function()
        local rp = getRootPart(); if not rp then return end
        local idx = #savedPositions+1; local name = "Position "..idx; local cf = rp.CFrame
        table.insert(savedPositions, {name, cf}); addEntry(idx, name, cf)
        TweenService:Create(saveBtn,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(80,220,100)}):Play()
        task.delay(0.35,function() TweenService:Create(saveBtn,TweenInfo.new(0.15),{BackgroundColor3=Color3.fromRGB(50,180,80)}):Play() end)
    end)
    p.CanvasSize = UDim2.new(0,0,0,360)
end

-- ==============================  DRAG WINDOW (drag via sidebar title)
local drag, dS, dP
SideTitle.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then drag=true; dS=i.Position; dP=Main.Position end
end)
UserInputService.InputChanged:Connect(function(i)
    if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dS
        Main.Position = UDim2.new(dP.X.Scale, dP.X.Offset+d.X, dP.Y.Scale, dP.Y.Offset+d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then drag=false end
end)

selectPage("Home")
print("[TvFruit v2.0] Loaded!")
