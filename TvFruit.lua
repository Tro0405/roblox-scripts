-- TvFruit - Fly + Noclip + Save Position + Speed Slider + Auto Win
-- Auto reconnect after respawn
-- Delta Executor Compatible

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera

-- ============ CONFIG ============
local CFG = {
    FlySpeed    = 120,
    FlySpeedMin = 10,
    FlySpeedMax = 300,
    FlyAccel    = 0.15,
    FlyBrake    = 0.10,
    LoopDelay   = 1.5,
    ArriveRadius = 4,
}
-- ================================

local flyEnabled     = false
local noclipEnabled  = false
local savedPositions = {}
local looping        = false
local loopCount      = 0
local loopThread     = nil
local counterLbl     = nil  -- set after GUI build

local currentVel = Vector3.zero
local bodyVel, bodyGyro
local flyLoop, noclipLoop

-- ==============================
--       CHARACTER GETTERS
-- ==============================
local function getChar()
    return LocalPlayer.Character
end
local function getRootPart()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHumanoid()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ==============================
--          FLY ENGINE (manual)
-- ==============================
local function stopFlyInternal()
    if flyLoop  then flyLoop:Disconnect();  flyLoop  = nil end
    if bodyVel  then bodyVel:Destroy();     bodyVel  = nil end
    if bodyGyro then bodyGyro:Destroy();    bodyGyro = nil end
    currentVel = Vector3.zero
end

local function startFlyInternal()
    stopFlyInternal()
    local rp = getRootPart()
    local hm = getHumanoid()
    if not rp or not hm then return end

    hm.PlatformStand = true

    bodyVel          = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bodyVel.P        = 1e4
    bodyVel.Velocity = Vector3.zero
    bodyVel.Parent   = rp

    bodyGyro           = Instance.new("BodyGyro")
    bodyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    bodyGyro.P         = 5e3
    bodyGyro.D         = 100
    bodyGyro.CFrame    = rp.CFrame
    bodyGyro.Parent    = rp

    flyLoop = RunService.Heartbeat:Connect(function()
        local root = getRootPart()
        if not root or not bodyVel or not bodyVel.Parent then return end

        local camCF = Camera.CFrame
        local move  = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += camCF.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= camCF.LookVector  end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += camCF.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then move += Vector3.yAxis end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.yAxis end

        local speed = CFG.FlySpeed
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then speed *= 2.5 end

        local target = if move.Magnitude > 0 then move.Unit * speed else Vector3.zero
        local alpha  = if move.Magnitude > 0 then CFG.FlyAccel else CFG.FlyBrake
        currentVel   = currentVel:Lerp(target, alpha)
        bodyVel.Velocity = currentVel

        if bodyGyro then
            bodyGyro.CFrame = CFrame.new(Vector3.zero,
                Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z))
        end
    end)
end

-- ==============================
--        NOCLIP ENGINE
-- ==============================
local function stopNoclipInternal()
    if noclipLoop then noclipLoop:Disconnect(); noclipLoop = nil end
    local c = getChar()
    if c then
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = true end
        end
    end
end

local function startNoclipInternal()
    stopNoclipInternal()
    noclipLoop = RunService.Stepped:Connect(function()
        local c = getChar()
        if not c then return end
        for _, p in ipairs(c:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                p.CanCollide = false
            end
        end
    end)
end

-- ==============================
--    AUTO RECONNECT AFTER DEATH
-- ==============================
local function onCharacterAdded(newChar)
    stopFlyInternal()
    stopNoclipInternal()
    currentVel = Vector3.zero

    newChar:WaitForChild("HumanoidRootPart")
    newChar:WaitForChild("Humanoid")
    task.wait(0.35)

    if flyEnabled    then startFlyInternal()    end
    if noclipEnabled then startNoclipInternal() end
end

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
if LocalPlayer.Character then onCharacterAdded(LocalPlayer.Character) end

-- ==============================
--         AUTO WIN ENGINE
-- ==============================
local function findWinBlock()
    local wb = workspace:FindFirstChild("Winblocks")
    if wb then
        local b = wb:FindFirstChild("WinBlock16")
        if b then return b end
    end
    return workspace:FindFirstChild("WinBlock16", true)
end

local function doOneLoop()
    if not looping then return end

    local rp = getRootPart()
    local hm = getHumanoid()
    if not rp or not hm then task.wait(1); return end

    local wb = findWinBlock()
    if not wb then
        task.wait(1)
        return
    end

    local targetPos = wb.Position + Vector3.new(0, 6, 0)

    -- Stop manual fly engine so bodies don't conflict
    stopFlyInternal()

    -- Enable noclip to pass through walls
    startNoclipInternal()
    hm.PlatformStand = true

    -- Create auto-win fly bodies (local, separate from manual fly)
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.P        = 1e4
    bv.Velocity = Vector3.zero
    bv.Parent   = rp

    local bg = Instance.new("BodyGyro")
    bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    bg.P         = 5e3
    bg.D         = 100
    bg.CFrame    = rp.CFrame
    bg.Parent    = rp

    -- Fly toward WinBlock16
    while looping do
        local root = getRootPart()
        if not root then break end
        local dist = (root.Position - targetPos).Magnitude
        if dist < CFG.ArriveRadius then break end
        local dir   = (targetPos - root.Position).Unit
        local speed = math.min(CFG.FlySpeed, dist * 3)
        bv.Velocity = dir * speed
        task.wait()
    end

    -- Destroy auto-fly bodies
    if bv and bv.Parent then bv:Destroy() end
    if bg and bg.Parent then bg:Destroy() end

    if not looping then
        stopNoclipInternal()
        local h = getHumanoid()
        if h then h.PlatformStand = false end
        return
    end

    -- Disable noclip and let character fall naturally onto WinBlock16
    stopNoclipInternal()
    local h = getHumanoid()
    if h then h.PlatformStand = false end

    -- Physics fall triggers server-side Touched → reward granted
    task.wait(0.5)

    -- Update counter
    loopCount += 1
    if counterLbl then
        counterLbl.Text = "Loops: " .. loopCount
    end

    -- Wait before next loop
    task.wait(CFG.LoopDelay)
end

local function startLoop()
    looping   = true
    loopCount = 0
    if counterLbl then counterLbl.Text = "Loops: 0" end
    loopThread = task.spawn(function()
        while looping do
            doOneLoop()
        end
    end)
end

local function stopLoop()
    looping = false
    -- Clean up any leftover bodies
    local rp = getRootPart()
    if rp then
        for _, v in ipairs(rp:GetChildren()) do
            if v:IsA("BodyVelocity") or v:IsA("BodyGyro") then v:Destroy() end
        end
    end
    stopNoclipInternal()
    local hm = getHumanoid()
    if hm then hm.PlatformStand = false end
    -- Restore manual features if they were on
    if flyEnabled    then startFlyInternal()    end
    if noclipEnabled then startNoclipInternal() end
end

-- ==============================
--             GUI
-- ==============================
local old = game:GetService("CoreGui"):FindFirstChild("TvFruitGUI")
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name         = "TvFruitGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent       = game:GetService("CoreGui")

local Main = Instance.new("Frame")
Main.Size             = UDim2.new(0, 260, 0, 640)
Main.Position         = UDim2.new(1, -278, 0.5, -320)
Main.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
Main.BorderSizePixel  = 0
Main.ClipsDescendants = true
Main.Parent           = ScreenGui
Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 14)

local Border = Instance.new("UIStroke")
Border.Color     = Color3.fromRGB(80, 80, 220)
Border.Thickness = 1.5
Border.Parent    = Main

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Size             = UDim2.new(1, 0, 0, 44)
TitleBar.BackgroundColor3 = Color3.fromRGB(50, 50, 180)
TitleBar.BorderSizePixel  = 0
TitleBar.Parent           = Main
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 14)

local TFix = Instance.new("Frame")
TFix.Size             = UDim2.new(1, 0, 0.5, 0)
TFix.Position         = UDim2.new(0, 0, 0.5, 0)
TFix.BackgroundColor3 = Color3.fromRGB(50, 50, 180)
TFix.BorderSizePixel  = 0
TFix.Parent           = TitleBar

local TLbl = Instance.new("TextLabel")
TLbl.Size                 = UDim2.new(1, -50, 1, 0)
TLbl.Position             = UDim2.new(0, 12, 0, 0)
TLbl.BackgroundTransparency = 1
TLbl.Text                 = "✈  TvFruit"
TLbl.Font                 = Enum.Font.GothamBold
TLbl.TextSize             = 15
TLbl.TextColor3           = Color3.new(1, 1, 1)
TLbl.TextXAlignment       = Enum.TextXAlignment.Left
TLbl.ZIndex               = 2
TLbl.Parent               = TitleBar

-- ---- Helpers ----
local function section(y, title)
    local lbl = Instance.new("TextLabel")
    lbl.Size                 = UDim2.new(1, -20, 0, 18)
    lbl.Position             = UDim2.new(0, 10, 0, y)
    lbl.BackgroundTransparency = 1
    lbl.Text                 = title
    lbl.Font                 = Enum.Font.GothamBold
    lbl.TextSize             = 10
    lbl.TextColor3           = Color3.fromRGB(100, 100, 255)
    lbl.TextXAlignment       = Enum.TextXAlignment.Left
    lbl.Parent               = Main
end

local function makePill(y, icon, label, color, onToggle)
    local card = Instance.new("Frame")
    card.Size             = UDim2.new(1, -20, 0, 52)
    card.Position         = UDim2.new(0, 10, 0, y)
    card.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    card.BorderSizePixel  = 0
    card.Parent           = Main
    Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

    local iconB = Instance.new("Frame")
    iconB.Size             = UDim2.new(0, 38, 0, 38)
    iconB.Position         = UDim2.new(0, 7, 0.5, -19)
    iconB.BackgroundColor3 = color
    iconB.BorderSizePixel  = 0
    iconB.Parent           = card
    Instance.new("UICorner", iconB).CornerRadius = UDim.new(0, 8)

    local iLbl = Instance.new("TextLabel")
    iLbl.Size                 = UDim2.new(1, 0, 1, 0)
    iLbl.BackgroundTransparency = 1
    iLbl.Text                 = icon
    iLbl.Font                 = Enum.Font.GothamBold
    iLbl.TextSize             = 20
    iLbl.TextColor3           = Color3.new(1, 1, 1)
    iLbl.Parent               = iconB

    local badge = Instance.new("TextLabel")
    badge.Size                = UDim2.new(0, 62, 0, 14)
    badge.Position            = UDim2.new(0, 54, 0, 10)
    badge.BackgroundColor3    = color
    badge.BackgroundTransparency = 0.75
    badge.Text                = "Auto re-enable"
    badge.Font                = Enum.Font.Gotham
    badge.TextSize            = 8
    badge.TextColor3          = Color3.new(1, 1, 1)
    badge.Visible             = false
    badge.Parent              = card
    Instance.new("UICorner", badge).CornerRadius = UDim.new(0, 3)

    local nLbl = Instance.new("TextLabel")
    nLbl.Size                 = UDim2.new(0, 110, 0, 18)
    nLbl.Position             = UDim2.new(0, 54, 0, 9)
    nLbl.BackgroundTransparency = 1
    nLbl.Text                 = label
    nLbl.Font                 = Enum.Font.GothamBold
    nLbl.TextSize             = 13
    nLbl.TextColor3           = Color3.new(1, 1, 1)
    nLbl.TextXAlignment       = Enum.TextXAlignment.Left
    nLbl.Parent               = card

    local sLbl = Instance.new("TextLabel")
    sLbl.Size                 = UDim2.new(0, 110, 0, 14)
    sLbl.Position             = UDim2.new(0, 54, 0, 30)
    sLbl.BackgroundTransparency = 1
    sLbl.Text                 = "OFF"
    sLbl.Font                 = Enum.Font.Gotham
    sLbl.TextSize             = 10
    sLbl.TextColor3           = Color3.fromRGB(130, 130, 130)
    sLbl.TextXAlignment       = Enum.TextXAlignment.Left
    sLbl.Parent               = card

    local pill = Instance.new("Frame")
    pill.Size             = UDim2.new(0, 50, 0, 24)
    pill.Position         = UDim2.new(1, -58, 0.5, -12)
    pill.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
    pill.BorderSizePixel  = 0
    pill.Parent           = card
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local dot = Instance.new("Frame")
    dot.Size             = UDim2.new(0, 18, 0, 18)
    dot.Position         = UDim2.new(0, 3, 0.5, -9)
    dot.BackgroundColor3 = Color3.new(1, 1, 1)
    dot.BorderSizePixel  = 0
    dot.Parent           = pill
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local state = false
    local btn = Instance.new("TextButton")
    btn.Size                 = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text                 = ""
    btn.Parent               = card

    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(pill, TweenInfo.new(0.22),
            {BackgroundColor3 = state and color or Color3.fromRGB(55, 55, 55)}):Play()
        TweenService:Create(dot, TweenInfo.new(0.22),
            {Position = state
                and UDim2.new(1, -21, 0.5, -9)
                or  UDim2.new(0, 3,   0.5, -9)}):Play()
        sLbl.Text       = state and "RUNNING" or "OFF"
        sLbl.TextColor3 = state and color or Color3.fromRGB(130, 130, 130)
        badge.Visible   = state
        onToggle(state)
    end)
end

-- ==============================
--      LOOP COUNTER ROW
-- ==============================
local function makeCounterRow(y)
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1, -20, 0, 30)
    row.Position         = UDim2.new(0, 10, 0, y)
    row.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    row.BorderSizePixel  = 0
    row.Parent           = Main
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

    local lbl = Instance.new("TextLabel")
    lbl.Size                 = UDim2.new(0.55, 0, 1, 0)
    lbl.Position             = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                 = "Loops: 0"
    lbl.Font                 = Enum.Font.GothamBold
    lbl.TextSize             = 12
    lbl.TextColor3           = Color3.fromRGB(100, 220, 100)
    lbl.TextXAlignment       = Enum.TextXAlignment.Left
    lbl.Parent               = row

    counterLbl = lbl  -- global reference for doOneLoop

    local resetBtn = Instance.new("TextButton")
    resetBtn.Size             = UDim2.new(0, 70, 0, 20)
    resetBtn.Position         = UDim2.new(1, -76, 0.5, -10)
    resetBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    resetBtn.Text             = "Reset"
    resetBtn.TextColor3       = Color3.new(1, 1, 1)
    resetBtn.Font             = Enum.Font.GothamBold
    resetBtn.TextSize         = 10
    resetBtn.BorderSizePixel  = 0
    resetBtn.Parent           = row
    Instance.new("UICorner", resetBtn).CornerRadius = UDim.new(0, 4)

    resetBtn.MouseButton1Click:Connect(function()
        loopCount  = 0
        lbl.Text   = "Loops: 0"
    end)
end

-- ==============================
--         SPEED SLIDER
-- ==============================
local function makeSlider(yPos)
    local bg = Instance.new("Frame")
    bg.Size             = UDim2.new(1, -20, 0, 72)
    bg.Position         = UDim2.new(0, 10, 0, yPos)
    bg.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
    bg.BorderSizePixel  = 0
    bg.Parent           = Main
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

    local topRow = Instance.new("Frame")
    topRow.Size                 = UDim2.new(1, -16, 0, 24)
    topRow.Position             = UDim2.new(0, 8, 0, 8)
    topRow.BackgroundTransparency = 1
    topRow.Parent               = bg

    local icoLbl = Instance.new("TextLabel")
    icoLbl.Size                 = UDim2.new(0, 22, 1, 0)
    icoLbl.BackgroundTransparency = 1
    icoLbl.Text                 = "✈"
    icoLbl.Font                 = Enum.Font.GothamBold
    icoLbl.TextSize             = 16
    icoLbl.TextColor3           = Color3.fromRGB(100, 100, 255)
    icoLbl.Parent               = topRow

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size               = UDim2.new(0, 90, 1, 0)
    titleLbl.Position           = UDim2.new(0, 24, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text               = "Fly Speed"
    titleLbl.Font               = Enum.Font.GothamBold
    titleLbl.TextSize           = 12
    titleLbl.TextColor3         = Color3.new(1, 1, 1)
    titleLbl.TextXAlignment     = Enum.TextXAlignment.Left
    titleLbl.Parent             = topRow

    local valLbl = Instance.new("TextLabel")
    valLbl.Size                 = UDim2.new(0, 60, 1, 0)
    valLbl.Position             = UDim2.new(1, -60, 0, 0)
    valLbl.BackgroundTransparency = 1
    valLbl.Text                 = tostring(CFG.FlySpeed)
    valLbl.Font                 = Enum.Font.GothamBold
    valLbl.TextSize             = 13
    valLbl.TextColor3           = Color3.fromRGB(100, 180, 255)
    valLbl.TextXAlignment       = Enum.TextXAlignment.Right
    valLbl.Parent               = topRow

    local minLbl = Instance.new("TextLabel")
    minLbl.Size                 = UDim2.new(0, 30, 0, 12)
    minLbl.Position             = UDim2.new(0, 8, 0, 34)
    minLbl.BackgroundTransparency = 1
    minLbl.Text                 = tostring(CFG.FlySpeedMin)
    minLbl.Font                 = Enum.Font.Gotham
    minLbl.TextSize             = 9
    minLbl.TextColor3           = Color3.fromRGB(80, 80, 80)
    minLbl.TextXAlignment       = Enum.TextXAlignment.Left
    minLbl.Parent               = bg

    local maxLbl = Instance.new("TextLabel")
    maxLbl.Size                 = UDim2.new(0, 30, 0, 12)
    maxLbl.Position             = UDim2.new(1, -38, 0, 34)
    maxLbl.BackgroundTransparency = 1
    maxLbl.Text                 = tostring(CFG.FlySpeedMax)
    maxLbl.Font                 = Enum.Font.Gotham
    maxLbl.TextSize             = 9
    maxLbl.TextColor3           = Color3.fromRGB(80, 80, 80)
    maxLbl.TextXAlignment       = Enum.TextXAlignment.Right
    maxLbl.Parent               = bg

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1, -56, 0, 6)
    track.Position         = UDim2.new(0, 36, 0, 50)
    track.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    track.BorderSizePixel  = 0
    track.Parent           = bg
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local initPct = (CFG.FlySpeed - CFG.FlySpeedMin) / (CFG.FlySpeedMax - CFG.FlySpeedMin)

    local fill = Instance.new("Frame")
    fill.Size             = UDim2.new(initPct, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(80, 120, 255)
    fill.BorderSizePixel  = 0
    fill.Parent           = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local thumb = Instance.new("Frame")
    thumb.Size             = UDim2.new(0, 18, 0, 18)
    thumb.Position         = UDim2.new(initPct, -9, 0.5, -9)
    thumb.BackgroundColor3 = Color3.new(1, 1, 1)
    thumb.BorderSizePixel  = 0
    thumb.ZIndex           = 3
    thumb.Parent           = track
    Instance.new("UICorner", thumb).CornerRadius = UDim.new(1, 0)

    local ts = Instance.new("UIStroke")
    ts.Color     = Color3.fromRGB(80, 120, 255)
    ts.Thickness = 2
    ts.Parent    = thumb

    local draggingSlider = false
    local function updateSlider(absX)
        local tAbs  = track.AbsolutePosition.X
        local tSize = track.AbsoluteSize.X
        local pct   = math.clamp((absX - tAbs) / tSize, 0, 1)
        fill.Size      = UDim2.new(pct, 0, 1, 0)
        thumb.Position = UDim2.new(pct, -9, 0.5, -9)
        CFG.FlySpeed   = math.floor(CFG.FlySpeedMin + pct * (CFG.FlySpeedMax - CFG.FlySpeedMin))
        valLbl.Text    = tostring(CFG.FlySpeed)
    end

    thumb.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingSlider = true end
    end)
    track.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            draggingSlider = true; updateSlider(i.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if draggingSlider and i.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(i.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then draggingSlider = false end
    end)
end

-- ==============================
--       SAVE POSITION UI
-- ==============================
local function makePositionSection(startY)
    local hdr = Instance.new("Frame")
    hdr.Size                 = UDim2.new(1, -20, 0, 30)
    hdr.Position             = UDim2.new(0, 10, 0, startY)
    hdr.BackgroundTransparency = 1
    hdr.Parent               = Main

    local hLbl = Instance.new("TextLabel")
    hLbl.Size                 = UDim2.new(0.55, 0, 1, 0)
    hLbl.BackgroundTransparency = 1
    hLbl.Text                 = "SAVE POSITION"
    hLbl.Font                 = Enum.Font.GothamBold
    hLbl.TextSize             = 10
    hLbl.TextColor3           = Color3.fromRGB(100, 100, 255)
    hLbl.TextXAlignment       = Enum.TextXAlignment.Left
    hLbl.Parent               = hdr

    local saveBtn = Instance.new("TextButton")
    saveBtn.Size             = UDim2.new(0, 104, 0, 26)
    saveBtn.Position         = UDim2.new(1, -104, 0.5, -13)
    saveBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 80)
    saveBtn.Text             = "+ Save Position"
    saveBtn.TextColor3       = Color3.new(1, 1, 1)
    saveBtn.Font             = Enum.Font.GothamBold
    saveBtn.TextSize         = 11
    saveBtn.BorderSizePixel  = 0
    saveBtn.Parent           = hdr
    Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 6)

    local listFrame = Instance.new("ScrollingFrame")
    listFrame.Size                 = UDim2.new(1, -20, 0, 120)
    listFrame.Position             = UDim2.new(0, 10, 0, startY + 34)
    listFrame.BackgroundColor3     = Color3.fromRGB(20, 20, 20)
    listFrame.BorderSizePixel      = 0
    listFrame.ScrollBarThickness   = 4
    listFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 80, 200)
    listFrame.CanvasSize           = UDim2.new(0, 0, 0, 0)
    listFrame.Parent               = Main
    Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 8)

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding   = UDim.new(0, 4)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent    = listFrame

    local listPad = Instance.new("UIPadding")
    listPad.PaddingTop  = UDim.new(0, 4)
    listPad.PaddingLeft = UDim.new(0, 4)
    listPad.Parent      = listFrame

    local emptyLbl = Instance.new("TextLabel")
    emptyLbl.Size                 = UDim2.new(1, -8, 0, 40)
    emptyLbl.BackgroundTransparency = 1
    emptyLbl.Text                 = "No saved positions yet"
    emptyLbl.Font                 = Enum.Font.Gotham
    emptyLbl.TextSize             = 11
    emptyLbl.TextColor3           = Color3.fromRGB(80, 80, 80)
    emptyLbl.Parent               = listFrame

    local function refreshCanvas()
        listFrame.CanvasSize = UDim2.new(0, 0, 0,
            listLayout.AbsoluteContentSize.Y + 8)
    end

    local function addEntry(idx, name, cf)
        emptyLbl.Visible = false

        local row = Instance.new("Frame")
        row.Size             = UDim2.new(1, -8, 0, 30)
        row.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        row.BorderSizePixel  = 0
        row.LayoutOrder      = idx
        row.Parent           = listFrame
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

        local dot = Instance.new("Frame")
        dot.Size             = UDim2.new(0, 8, 0, 8)
        dot.Position         = UDim2.new(0, 6, 0.5, -4)
        dot.BackgroundColor3 = Color3.fromRGB(80, 120, 255)
        dot.BorderSizePixel  = 0
        dot.Parent           = row
        Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size                 = UDim2.new(0, 115, 1, 0)
        nameLbl.Position             = UDim2.new(0, 20, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text                 = name
        nameLbl.Font                 = Enum.Font.Gotham
        nameLbl.TextSize             = 11
        nameLbl.TextColor3           = Color3.new(1, 1, 1)
        nameLbl.TextXAlignment       = Enum.TextXAlignment.Left
        nameLbl.Parent               = row

        local tpBtn = Instance.new("TextButton")
        tpBtn.Size             = UDim2.new(0, 60, 0, 22)
        tpBtn.Position         = UDim2.new(1, -130, 0.5, -11)
        tpBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 220)
        tpBtn.Text             = "Teleport"
        tpBtn.TextColor3       = Color3.new(1, 1, 1)
        tpBtn.Font             = Enum.Font.GothamBold
        tpBtn.TextSize         = 10
        tpBtn.BorderSizePixel  = 0
        tpBtn.Parent           = row
        Instance.new("UICorner", tpBtn).CornerRadius = UDim.new(0, 5)

        tpBtn.MouseButton1Click:Connect(function()
            local rp = getRootPart()
            if rp then
                rp.CFrame = cf
                TweenService:Create(tpBtn, TweenInfo.new(0.15),
                    {BackgroundColor3 = Color3.fromRGB(80, 220, 80)}):Play()
                task.delay(0.35, function()
                    TweenService:Create(tpBtn, TweenInfo.new(0.15),
                        {BackgroundColor3 = Color3.fromRGB(60, 120, 220)}):Play()
                end)
            end
        end)

        local delBtn = Instance.new("TextButton")
        delBtn.Size             = UDim2.new(0, 26, 0, 22)
        delBtn.Position         = UDim2.new(1, -32, 0.5, -11)
        delBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
        delBtn.Text             = "X"
        delBtn.TextColor3       = Color3.new(1, 1, 1)
        delBtn.Font             = Enum.Font.GothamBold
        delBtn.TextSize         = 11
        delBtn.BorderSizePixel  = 0
        delBtn.Parent           = row
        Instance.new("UICorner", delBtn).CornerRadius = UDim.new(0, 5)

        delBtn.MouseButton1Click:Connect(function()
            for i, v in ipairs(savedPositions) do
                if v[1] == name then table.remove(savedPositions, i); break end
            end
            row:Destroy()
            if #savedPositions == 0 then emptyLbl.Visible = true end
            refreshCanvas()
        end)

        task.defer(refreshCanvas)
    end

    saveBtn.MouseButton1Click:Connect(function()
        local rp = getRootPart()
        if not rp then return end
        local idx  = #savedPositions + 1
        local name = "Position " .. idx
        local cf   = rp.CFrame
        table.insert(savedPositions, {name, cf})
        addEntry(idx, name, cf)
        TweenService:Create(saveBtn, TweenInfo.new(0.15),
            {BackgroundColor3 = Color3.fromRGB(80, 220, 100)}):Play()
        task.delay(0.35, function()
            TweenService:Create(saveBtn, TweenInfo.new(0.15),
                {BackgroundColor3 = Color3.fromRGB(50, 180, 80)}):Play()
        end)
    end)
end

-- ==============================
--         BUILD LAYOUT
-- ==============================
-- y=50  FEATURES
section(50, "FEATURES")
makePill(66, "✈", "FLY", Color3.fromRGB(70, 120, 255), function(on)
    flyEnabled = on
    if on then startFlyInternal() else
        stopFlyInternal()
        local hm = getHumanoid()
        if hm then hm.PlatformStand = false; hm.WalkSpeed = 100 end
    end
end)
makePill(124, "👻", "NOCLIP", Color3.fromRGB(180, 60, 220), function(on)
    noclipEnabled = on
    if on then startNoclipInternal() else stopNoclipInternal() end
end)

-- y=187  AUTO WIN
section(187, "AUTO WIN")
makePill(203, "🏆", "AUTO WIN (WinBlock16)", Color3.fromRGB(220, 160, 20), function(on)
    if on then
        startLoop()
    else
        stopLoop()
    end
end)
makeCounterRow(261)

-- y=302  FLY SPEED
section(302, "FLY SPEED")
makeSlider(318)

-- y=402  SAVE POSITION
section(402, "SAVE POSITION & TELEPORT")
makePositionSection(418)

-- Key hint
local hint = Instance.new("TextLabel")
hint.Size                 = UDim2.new(1, -20, 0, 18)
hint.Position             = UDim2.new(0, 10, 0, 616)
hint.BackgroundTransparency = 1
hint.Text                 = "WASD | Space = up | Ctrl = down | Shift = boost x2.5"
hint.Font                 = Enum.Font.Gotham
hint.TextSize             = 9
hint.TextColor3           = Color3.fromRGB(65, 65, 65)
hint.Parent               = Main

-- ==============================
--         DRAG WINDOW
-- ==============================
local drag, dS, dP
TitleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then
        drag = true; dS = i.Position; dP = Main.Position
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if drag and i.UserInputType == Enum.UserInputType.MouseMovement then
        local d = i.Position - dS
        Main.Position = UDim2.new(dP.X.Scale, dP.X.Offset + d.X,
                                   dP.Y.Scale, dP.Y.Offset + d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
end)

print("[TvFruit] Loaded! Auto re-enable after death.")
