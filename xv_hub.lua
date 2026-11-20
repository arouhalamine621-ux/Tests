-- XV HUB — Mobile UI | Scanner | Steal | Auto Grab | Tween TP + Carpet Spoof
-- Luau | client script | Roblox executor
-- ================================================================

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local TweenService  = game:GetService("TweenService")
local UIS           = game:GetService("UserInputService")
local LP            = Players.LocalPlayer
local PlayerGui     = LP:WaitForChild("PlayerGui")

local function getChar() return LP.Character end
local function getHRP()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end

-- ================================================================
-- CONFIG
-- ================================================================
local CFG = {
    ScanRadius   = 300,
    TweenTime    = 0.35,
    TweenStyle   = Enum.EasingStyle.Linear,
    TweenDir     = Enum.EasingDirection.Out,
    AutoGrabRate = 0.5,   -- seconds between auto grab attempts
    CarpetName   = "carpet", -- lowercase match
}

-- ================================================================
-- CARPET
-- ================================================================
local function findCarpet()
    for _, t in ipairs(LP.Backpack:GetChildren()) do
        if t:IsA("Tool") and t.Name:lower():find(CFG.CarpetName) then return t end
    end
    local c = getChar()
    if c then
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") and t.Name:lower():find(CFG.CarpetName) then return t end
        end
    end
end

local function equipCarpet(carpet)
    local c = getChar()
    if not c then return end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:EquipTool(carpet) end) end
end

local _spoofConn
local function spoofCarpetActive(carpet, duration)
    if _spoofConn then _spoofConn:Disconnect() end
    local t0 = os.clock()
    _spoofConn = RunService.Heartbeat:Connect(function()
        if os.clock() - t0 >= duration then
            _spoofConn:Disconnect()
            return
        end
        pcall(function()
            for _, obj in ipairs(carpet:GetDescendants()) do
                if obj:IsA("RemoteEvent") then pcall(function() obj:FireServer() end) end
            end
            pcall(function() carpet.Activated:Fire() end)
        end)
    end)
end

-- ================================================================
-- TWEEN TP
-- ================================================================
local function tweenTP(targetHRP, onDone)
    local hrp = getHRP()
    if not hrp or not targetHRP then return end
    local carpet = findCarpet()
    if not carpet then warn("[XV] no carpet") return end
    equipCarpet(carpet)
    task.wait(0.05)
    local goal = { CFrame = targetHRP.CFrame * CFrame.new(0, 0, 3.5) }
    local ti   = TweenInfo.new(CFG.TweenTime, CFG.TweenStyle, CFG.TweenDir)
    local tw   = TweenService:Create(hrp, ti, goal)
    spoofCarpetActive(carpet, CFG.TweenTime + 0.2)
    tw:Play()
    tw.Completed:Connect(function()
        if onDone then onDone() end
    end)
end

-- ================================================================
-- SCANNER
-- ================================================================
local function getPlayers()
    local hrp = getHRP()
    local list = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local h = plr.Character:FindFirstChild("HumanoidRootPart")
            if h then
                local dist = hrp and math.floor((h.Position - hrp.Position).Magnitude) or 0
                table.insert(list, { plr = plr, hrp = h, dist = dist })
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

-- ================================================================
-- AUTO GRAB
-- ================================================================
local autoGrabOn  = false
local autoGrabTarget = nil
local _autoConn

local function startAutoGrab()
    if _autoConn then _autoConn:Disconnect() end
    local last = 0
    _autoConn = RunService.Heartbeat:Connect(function()
        if not autoGrabOn then return end
        if os.clock() - last < CFG.AutoGrabRate then return end
        last = os.clock()
        if autoGrabTarget and autoGrabTarget.Character then
            local h = autoGrabTarget.Character:FindFirstChild("HumanoidRootPart")
            if h then tweenTP(h) end
        else
            -- nearest if no target pinned
            local list = getPlayers()
            if list[1] then tweenTP(list[1].hrp) end
        end
    end)
end

local function stopAutoGrab()
    autoGrabOn = false
    if _autoConn then _autoConn:Disconnect() end
end

-- ================================================================
-- UI
-- ================================================================
local PINK  = Color3.fromRGB(255, 46, 147)
local DARK  = Color3.fromRGB(11, 11, 13)
local GRAY  = Color3.fromRGB(30, 30, 35)
local WHITE = Color3.fromRGB(220, 220, 225)
local GREEN = Color3.fromRGB(50, 220, 100)
local RED   = Color3.fromRGB(220, 60, 60)

local sg = Instance.new("ScreenGui")
sg.Name = "XV_Hub"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.DisplayOrder = 9999
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.Parent = PlayerGui

-- main frame
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(280, 420)
main.Position = UDim2.new(0.5, -140, 0.5, -210)
main.BackgroundColor3 = DARK
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = sg
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)
local stroke = Instance.new("UIStroke", main)
stroke.Color = PINK; stroke.Thickness = 1.2; stroke.Transparency = 0.3

-- title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = GRAY
titleBar.BorderSizePixel = 0
titleBar.Parent = main
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 14)

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.fromScale(1, 1)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "XV HUB"
titleLbl.Font = Enum.Font.GothamBlack
titleLbl.TextSize = 15
titleLbl.TextColor3 = PINK
titleLbl.Parent = titleBar

-- close btn
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(30, 30)
closeBtn.Position = UDim2.new(1, -35, 0, 5)
closeBtn.BackgroundColor3 = RED
closeBtn.Text = "✕"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 13
closeBtn.TextColor3 = WHITE
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

-- helper: make a button
local function makeBtn(parent, text, yOff, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 38)
    btn.Position = UDim2.new(0, 10, 0, yOff)
    btn.BackgroundColor3 = color or GRAY
    btn.Text = text
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.TextColor3 = WHITE
    btn.BorderSizePixel = 0
    btn.Parent = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    return btn
end

-- helper: label
local function makeLbl(parent, text, yOff, size)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, -20, 0, size or 20)
    l.Position = UDim2.new(0, 10, 0, yOff)
    l.BackgroundTransparency = 1
    l.Text = text
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 12
    l.TextColor3 = Color3.fromRGB(160, 160, 170)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = parent
    return l
end

-- ── QUICK ACTIONS ──
makeLbl(main, "QUICK ACTIONS", 48, 18)

local stealBtn = makeBtn(main, "🎯  STEAL TARGET", 70, PINK)
local autoBtn  = makeBtn(main, "🔄  AUTO GRAB: OFF", 116, GRAY)
local scanBtn  = makeBtn(main, "🔍  REFRESH SCAN", 162, GRAY)

-- ── SCANNER LIST ──
makeLbl(main, "SCANNER", 208, 18)

local listFrame = Instance.new("ScrollingFrame")
listFrame.Size = UDim2.new(1, -20, 0, 185)
listFrame.Position = UDim2.new(0, 10, 0, 228)
listFrame.BackgroundColor3 = GRAY
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 3
listFrame.ScrollBarImageColor3 = PINK
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.Parent = main
Instance.new("UICorner", listFrame).CornerRadius = UDim.new(0, 10)

local listLayout = Instance.new("UIListLayout", listFrame)
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder

local selectedTarget = nil
local selectedBtn    = nil

local function colorBtn(btn, on)
    btn.BackgroundColor3 = on and PINK or GRAY
end

local function buildList()
    for _, c in ipairs(listFrame:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local list = getPlayers()
    if #list == 0 then
        local none = Instance.new("TextLabel")
        none.Size = UDim2.new(1, 0, 0, 36)
        none.BackgroundTransparency = 1
        none.Text = "no players nearby"
        none.Font = Enum.Font.Gotham
        none.TextSize = 12
        none.TextColor3 = Color3.fromRGB(100,100,110)
        none.Parent = listFrame
        listFrame.CanvasSize = UDim2.new(0,0,0,36)
        return
    end
    for i, entry in ipairs(list) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -8, 0, 38)
        btn.BackgroundColor3 = GRAY
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamMedium
        btn.TextSize = 12
        btn.TextColor3 = WHITE
        btn.Text = ("  %s  |  %d studs"):format(entry.plr.Name, entry.dist)
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.LayoutOrder = i
        btn.Parent = listFrame
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

        btn.MouseButton1Click:Connect(function()
            -- select
            if selectedBtn then colorBtn(selectedBtn, false) end
            selectedTarget = entry.plr
            autoGrabTarget = entry.plr
            selectedBtn = btn
            colorBtn(btn, true)
            -- tween TP immediately on tap
            local h = entry.plr.Character and entry.plr.Character:FindFirstChild("HumanoidRootPart")
            if h then tweenTP(h) end
        end)
    end
    listFrame.CanvasSize = UDim2.new(0, 0, 0, #list * 42)
end

buildList()

-- ── BUTTON LOGIC ──

stealBtn.MouseButton1Click:Connect(function()
    if selectedTarget and selectedTarget.Character then
        local h = selectedTarget.Character:FindFirstChild("HumanoidRootPart")
        if h then tweenTP(h) end
    else
        local list = getPlayers()
        if list[1] then
            tweenTP(list[1].hrp)
        end
    end
end)

autoBtn.MouseButton1Click:Connect(function()
    autoGrabOn = not autoGrabOn
    if autoGrabOn then
        autoBtn.Text = "🔄  AUTO GRAB: ON"
        autoBtn.BackgroundColor3 = GREEN
        startAutoGrab()
    else
        autoBtn.Text = "🔄  AUTO GRAB: OFF"
        autoBtn.BackgroundColor3 = GRAY
        stopAutoGrab()
    end
end)

scanBtn.MouseButton1Click:Connect(function()
    buildList()
end)

-- auto refresh scanner every 3s
task.spawn(function()
    while sg.Parent do
        task.wait(3)
        buildList()
    end
end)

print("[XV HUB] loaded")
