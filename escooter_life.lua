-- ================================================================
-- ESCOOTER LIFE — Auto Wheelie + Farm
-- Executor: Delta / any UNC executor
-- Game: Escooter Life (Roblox)
-- ================================================================
-- FEATURES:
--   • Auto Wheelie  — continuously holds the wheelie angle
--   • Auto Farm     — collects coins/cash, hits checkpoints, grinds XP
--   • Speed Boost   — walk/scooter speed multiplier
--   • Anti-AFK      — keeps character moving so you don't get kicked
--   • XV-branded UI — XV pink (#FF2E93), dark theme, draggable
-- ================================================================

-- ================================================================
-- SERVICES
-- ================================================================
local Players        = cloneref and cloneref(game:GetService("Players"))          or game:GetService("Players")
local RunService     = cloneref and cloneref(game:GetService("RunService"))        or game:GetService("RunService")
local TweenService   = cloneref and cloneref(game:GetService("TweenService"))      or game:GetService("TweenService")
local HttpService    = cloneref and cloneref(game:GetService("HttpService"))       or game:GetService("HttpService")
local Workspace      = cloneref and cloneref(game:GetService("Workspace"))         or game:GetService("Workspace")
local ReplicatedStorage = cloneref and cloneref(game:GetService("ReplicatedStorage")) or game:GetService("ReplicatedStorage")

local LP     = Players.LocalPlayer
local PGui   = LP:WaitForChild("PlayerGui")
local Char   = LP.Character or LP.CharacterAdded:Wait()
local HRP    = Char:WaitForChild("HumanoidRootPart")
local Hum    = Char:WaitForChild("Humanoid")

LP.CharacterAdded:Connect(function(c)
    Char = c
    HRP  = c:WaitForChild("HumanoidRootPart")
    Hum  = c:WaitForChild("Humanoid")
end)

-- ================================================================
-- CONFIG
-- ================================================================
local cfg = {
    wheelie       = false,
    farm          = false,
    antiAfk       = true,
    speedBoost    = false,
    speedMult     = 2.0,          -- speed multiplier
    wheelieAngle  = 55,           -- degrees to tilt back (45–70 feels real)
    farmRadius    = 120,          -- stud radius to scan for collectibles
    farmDelay     = 0.08,         -- seconds between collect attempts
    afkInterval   = 25,           -- seconds between anti-afk jiggle
}

-- ================================================================
-- WHEELIE LOGIC
-- ================================================================
local wheelieConn = nil

local function startWheelie()
    if wheelieConn then wheelieConn:Disconnect() end
    wheelieConn = RunService.Heartbeat:Connect(function()
        pcall(function()
            local char = LP.Character
            if not char then return end
            local root = char:FindFirstChild("HumanoidRootPart")
            if not root then return end

            -- tilt the HRP backward
            local curCF = root.CFrame
            local goalCF = CFrame.new(curCF.Position)
                * CFrame.fromEulerAnglesXYZ(math.rad(-cfg.wheelieAngle), 0, 0)
                * CFrame.fromEulerAnglesXYZ(0, curCF:ToEulerAnglesYXZ(), 0)

            -- smoothly approach wheelie angle
            root.CFrame = curCF:Lerp(
                CFrame.new(curCF.Position) * CFrame.Angles(
                    math.rad(-cfg.wheelieAngle),
                    select(2, curCF:ToEulerAnglesYXZ()),
                    0
                ),
                0.25
            )

            -- disable gravity pull on front wheel — keep airborne
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.PlatformStand = false -- keep control
            end

            -- spin rear wheel visual if scooter model exists
            local scooter = char:FindFirstChild("Scooter")
                or workspace:FindFirstChild("Scooter")
            if scooter then
                local rearWheel = scooter:FindFirstChild("RearWheel")
                    or scooter:FindFirstChild("BackWheel")
                    or scooter:FindFirstChild("Wheel")
                if rearWheel and rearWheel:IsA("BasePart") then
                    rearWheel.CFrame = rearWheel.CFrame * CFrame.Angles(0, 0, 0.3)
                end
            end
        end)
    end)
end

local function stopWheelie()
    if wheelieConn then
        wheelieConn:Disconnect()
        wheelieConn = nil
    end
end

-- ================================================================
-- SPEED BOOST
-- ================================================================
local function applySpeed()
    pcall(function()
        local char = LP.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = cfg.speedBoost and (16 * cfg.speedMult) or 16
        end
    end)
end

LP.CharacterAdded:Connect(function()
    task.delay(1, applySpeed)
end)

-- ================================================================
-- FARM — collect coins, cash, pickups in radius
-- ================================================================
local farmConn = nil
local collected = {}

local collectNames = {
    "coin", "cash", "money", "xp", "pickup", "collect",
    "token", "reward", "gem", "star", "point", "trick",
}

local function nameMatches(name)
    local lower = name:lower()
    for _, k in ipairs(collectNames) do
        if lower:find(k) then return true end
    end
    return false
end

local function tryFire(obj)
    -- try common remote patterns games use for collecting
    -- 1. ClickDetector
    local cd = obj:FindFirstChildOfClass("ClickDetector")
    if cd then
        pcall(function() fireclickdetector(cd) end)
        return true
    end

    -- 2. ProximityPrompt
    local pp = obj:FindFirstChildOfClass("ProximityPrompt")
    if pp then
        pcall(function() fireproximityprompt(pp) end)
        return true
    end

    -- 3. TouchInterest / touch-based collect
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if root and obj:IsA("BasePart") then
        local dist = (obj.Position - root.Position).Magnitude
        if dist <= 8 then
            -- teleport briefly to trigger touch
            local orig = root.CFrame
            root.CFrame = obj.CFrame + Vector3.new(0, 3, 0)
            task.delay(0.05, function()
                pcall(function() root.CFrame = orig end)
            end)
            return true
        end
    end

    return false
end

local function scanAndCollect()
    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- scan workspace for collectibles
    for _, obj in ipairs(workspace:GetDescendants()) do
        if nameMatches(obj.Name) and obj:IsA("BasePart") then
            local dist = (obj.Position - root.Position).Magnitude
            if dist <= cfg.farmRadius then
                local id = obj:GetDebugId()
                if not collected[id] then
                    collected[id] = true
                    pcall(function() tryFire(obj) end)
                    -- also try RemoteEvents in ReplicatedStorage
                    pcall(function()
                        for _, re in ipairs(ReplicatedStorage:GetDescendants()) do
                            if re:IsA("RemoteEvent") then
                                local rname = re.Name:lower()
                                if rname:find("collect") or rname:find("coin") or rname:find("pickup") then
                                    re:FireServer(obj)
                                end
                            end
                        end
                    end)
                end
            end
        end
    end

    -- clear collected table periodically so respawned coins get picked again
    task.delay(8, function() collected = {} end)
end

local function startFarm()
    if farmConn then farmConn:Disconnect() end
    farmConn = task.spawn(function()
        while cfg.farm do
            pcall(scanAndCollect)
            task.wait(cfg.farmDelay)
        end
    end)
end

local function stopFarm()
    cfg.farm = false
    if farmConn then
        pcall(function() task.cancel(farmConn) end)
        farmConn = nil
    end
end

-- ================================================================
-- ANTI-AFK
-- ================================================================
local function startAntiAfk()
    task.spawn(function()
        while true do
            task.wait(cfg.afkInterval)
            if cfg.antiAfk then
                pcall(function()
                    local vjs = LP:FindFirstChild("VirtualUser")
                        or game:GetService("VirtualUser")
                    if vjs then
                        vjs:CaptureController()
                        vjs:ClickButton2(Vector2.new(), workspace.CurrentCamera.CFrame)
                    end
                end)
                -- backup: tiny move
                pcall(function()
                    local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        root.CFrame = root.CFrame * CFrame.new(0.01, 0, 0)
                    end
                end)
            end
        end
    end)
end

startAntiAfk()

-- ================================================================
-- UI
-- ================================================================
local function makeUI()
    local old = PGui:FindFirstChild("EscooterXvUI")
    if old then old:Destroy() end

    local sg = Instance.new("ScreenGui")
    sg.Name           = "EscooterXvUI"
    sg.ResetOnSpawn   = false
    sg.DisplayOrder   = 999
    sg.IgnoreGuiInset = true
    sg.Parent         = PGui

    -- main frame
    local frame = Instance.new("Frame")
    frame.Name               = "Main"
    frame.Size               = UDim2.fromOffset(230, 220)
    frame.Position           = UDim2.new(0, 10, 0.5, -110)
    frame.BackgroundColor3   = Color3.fromRGB(10, 8, 14)
    frame.BorderSizePixel    = 0
    frame.Active             = true
    frame.Draggable          = true
    frame.Parent             = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", frame)
    stroke.Color     = Color3.fromRGB(255, 46, 147)
    stroke.Thickness = 1.5

    -- title bar
    local titleBar = Instance.new("Frame")
    titleBar.Size            = UDim2.new(1, 0, 0, 32)
    titleBar.BackgroundColor3= Color3.fromRGB(18, 10, 25)
    titleBar.BorderSizePixel = 0
    titleBar.Parent          = frame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)
    local titleCover = Instance.new("Frame")
    titleCover.Size            = UDim2.new(1, 0, 0, 10)
    titleCover.Position        = UDim2.new(0, 0, 1, -10)
    titleCover.BackgroundColor3= Color3.fromRGB(18, 10, 25)
    titleCover.BorderSizePixel = 0
    titleCover.Parent          = titleBar

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size               = UDim2.new(1, 0, 1, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text               = "XV • ESCOOTER LIFE"
    titleLbl.TextColor3         = Color3.fromRGB(255, 46, 147)
    titleLbl.Font               = Enum.Font.GothamBold
    titleLbl.TextSize           = 12
    titleLbl.Parent             = titleBar

    -- pink accent line
    local line = Instance.new("Frame")
    line.Size            = UDim2.new(1, 0, 0, 1)
    line.Position        = UDim2.new(0, 0, 0, 32)
    line.BackgroundColor3= Color3.fromRGB(255, 46, 147)
    line.BorderSizePixel = 0
    line.Parent          = frame

    -- toggle button factory
    local function makeToggle(label, yPos, state)
        local bg = Instance.new("Frame")
        bg.Size            = UDim2.new(1, -16, 0, 32)
        bg.Position        = UDim2.new(0, 8, 0, yPos)
        bg.BackgroundColor3= Color3.fromRGB(18, 12, 26)
        bg.BorderSizePixel = 0
        bg.Parent          = frame
        Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

        local lbl = Instance.new("TextLabel")
        lbl.Size               = UDim2.new(1, -50, 1, 0)
        lbl.Position           = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text               = label
        lbl.TextColor3         = Color3.fromRGB(200, 185, 210)
        lbl.Font               = Enum.Font.GothamMedium
        lbl.TextSize           = 11
        lbl.TextXAlignment     = Enum.TextXAlignment.Left
        lbl.Parent             = bg

        local pill = Instance.new("TextButton")
        pill.Size              = UDim2.fromOffset(44, 22)
        pill.Position          = UDim2.new(1, -50, 0.5, -11)
        pill.BackgroundColor3  = state and Color3.fromRGB(255, 46, 147) or Color3.fromRGB(50, 45, 65)
        pill.Text              = state and "ON" or "OFF"
        pill.TextColor3        = Color3.new(1, 1, 1)
        pill.Font              = Enum.Font.GothamBold
        pill.TextSize          = 10
        pill.AutoButtonColor   = false
        pill.Parent            = bg
        Instance.new("UICorner", pill).CornerRadius = UDim.new(0, 6)

        return pill
    end

    -- speed label
    local speedInfo = Instance.new("TextLabel")
    speedInfo.Size               = UDim2.new(1, -16, 0, 18)
    speedInfo.Position           = UDim2.new(0, 8, 0, 182)
    speedInfo.BackgroundTransparency = 1
    speedInfo.Text               = "speed: 2x  |  radius: 120st  |  anti-afk: ON"
    speedInfo.TextColor3         = Color3.fromRGB(90, 80, 100)
    speedInfo.Font               = Enum.Font.Gotham
    speedInfo.TextSize           = 9
    speedInfo.Parent             = frame

    -- build toggles
    local btnWheelie  = makeToggle("🛴 Auto Wheelie",  40,  cfg.wheelie)
    local btnFarm     = makeToggle("💰 Auto Farm",     82,  cfg.farm)
    local btnSpeed    = makeToggle("⚡ Speed Boost",   124, cfg.speedBoost)
    local btnAfk      = makeToggle("🛡️ Anti-AFK",     165, cfg.antiAfk)

    -- toggle handlers
    local function toggle(btn, key, onFn, offFn)
        btn.MouseButton1Click:Connect(function()
            cfg[key] = not cfg[key]
            btn.BackgroundColor3 = cfg[key]
                and Color3.fromRGB(255, 46, 147)
                or  Color3.fromRGB(50, 45, 65)
            btn.Text = cfg[key] and "ON" or "OFF"
            if cfg[key] then
                pcall(onFn)
            else
                pcall(offFn)
            end
        end)
    end

    toggle(btnWheelie, "wheelie",
        function() startWheelie() end,
        function() stopWheelie() end)

    toggle(btnFarm, "farm",
        function() cfg.farm = true; startFarm() end,
        function() stopFarm() end)

    toggle(btnSpeed, "speedBoost",
        function() applySpeed() end,
        function() applySpeed() end)

    toggle(btnAfk, "antiAfk",
        function() end,
        function() end)

    return sg
end

makeUI()

-- ================================================================
-- TRICK SYSTEM — fires wheelie trick remotes when detected
-- ================================================================
task.spawn(function()
    -- look for trick / wheelie remotes in the game
    task.wait(3) -- let game load
    for _, re in ipairs(ReplicatedStorage:GetDescendants()) do
        if re:IsA("RemoteEvent") or re:IsA("RemoteFunction") then
            local rname = re.Name:lower()
            if rname:find("wheelie") or rname:find("trick") or rname:find("stunt") then
                -- found a trick remote — hook it to our wheelie toggle
                local orig = cfg.wheelie
                RunService.Heartbeat:Connect(function()
                    if cfg.wheelie and re:IsA("RemoteEvent") then
                        pcall(function() re:FireServer("wheelie") end)
                    end
                end)
                break
            end
        end
    end
end)

-- ================================================================
-- CHECKPOINT FARM — hits all checkpoints in the map
-- ================================================================
task.spawn(function()
    task.wait(2)
    if not cfg.farm then return end

    local checkpoints = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name:lower():find("checkpoint") or obj.Name:lower():find("spawn") then
            if obj:IsA("BasePart") then
                table.insert(checkpoints, obj)
            end
        end
    end

    if #checkpoints == 0 then return end

    local i = 1
    RunService.Heartbeat:Connect(function()
        if not cfg.farm then return end
        local root = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local cp = checkpoints[i]
        if cp then
            local dist = (cp.Position - root.Position).Magnitude
            if dist > 20 then
                -- move toward checkpoint
                local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum:MoveTo(cp.Position)
                end
            else
                i = (i % #checkpoints) + 1
            end
        end
    end)
end)

-- ================================================================
-- END ESCOOTER LIFE SCRIPT
-- ================================================================
print("[XV] Escooter Life loaded — wheelie + farm ready")
