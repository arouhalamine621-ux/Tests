-- XV HUB v3 — Real AutoStealUI shape | Tween TP | Carpet activation bypass
-- Run AFTER XV loads (_G.tpToBestBrainrot must exist)
-- ================================================================

local Players       = game:GetService("Players")
local RunService    = game:GetService("RunService")
local TweenService  = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP            = Players.LocalPlayer
local PlayerGui     = LP:WaitForChild("PlayerGui")

local function getChar() return LP.Character end
local function getHRP()  local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart") end

-- ================================================================
-- CONFIG — mirrors TpSettings shape from source
-- ================================================================
local CFG = {
    TweenTime    = 0.35,
    TweenStyle   = Enum.EasingStyle.Linear,
    TweenDir     = Enum.EasingDirection.Out,
    AutoGrabRate = 0.6,
    UseItemUUID  = "75c9466d-e4c0-4b02-b26a-c3615fcc1e42",
    UseItemArg   = 0.8,
    -- carpet names from source line 6353
    CarpetNames  = {"Flying Carpet","Witch's Broom","Cupid's Wings","Santa's Sleigh","Waverider","Magic Carpet","Carpet"},
    SelectedCarpet = "Flying Carpet",
    AutoSteal    = true,
    InstaTpBrainrot = true,
}

-- pull from XV config if loaded
if type(_G.XV_Config) == "table" and type(_G.XV_Config.TpSettings) == "table" then
    local T = _G.XV_Config.TpSettings
    if T.Tool then CFG.SelectedCarpet = T.Tool end
    if T.InstaTpBrainrot ~= nil then CFG.InstaTpBrainrot = T.InstaTpBrainrot end
end
if type(_G.XV_Config) == "table" then
    if _G.XV_Config.AutoSteal ~= nil then CFG.AutoSteal = _G.XV_Config.AutoSteal end
end

-- ================================================================
-- REMOTE CACHE
-- ================================================================
local _useItemRE, _uuidRE
local function findRemote(name)
    for _, v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Name == name then return v end
    end
end
task.spawn(function() _useItemRE = findRemote("UseItem") end)
task.spawn(function() _uuidRE    = findRemote(CFG.UseItemUUID) end)

-- ================================================================
-- CARPET
-- ================================================================
local function findCarpet()
    local c = getChar(); local bp = LP:FindFirstChild("Backpack")
    local names = {CFG.SelectedCarpet}
    for _, n in ipairs(CFG.CarpetNames) do names[#names+1] = n end
    for _, n in ipairs(names) do
        if c and c:FindFirstChild(n) then return c:FindFirstChild(n) end
        if bp and bp:FindFirstChild(n) then return bp:FindFirstChild(n) end
    end
end

local function equipCarpet(carpet)
    local c = getChar(); if not c or not carpet then return end
    local hum = c:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:EquipTool(carpet) end) end
end

-- ================================================================
-- ACTIVATION BYPASS — fires UseItem + UUID + firesignal(Activated)
-- mimics active carpet use so server speed-check passes
-- ================================================================
local _spoofConn
local function activationBypass(carpet, duration)
    if _spoofConn then _spoofConn:Disconnect() end
    if not (_useItemRE and _useItemRE.Parent) then _useItemRE = findRemote("UseItem") end
    if not (_uuidRE and _uuidRE.Parent)    then _uuidRE    = findRemote(CFG.UseItemUUID) end
    local t0 = os.clock()
    _spoofConn = RunService.Heartbeat:Connect(function()
        if os.clock() - t0 >= duration then _spoofConn:Disconnect() return end
        if _useItemRE and _useItemRE.Parent then pcall(function() _useItemRE:FireServer(CFG.UseItemArg) end) end
        if _uuidRE    and _uuidRE.Parent    then pcall(function() _uuidRE:FireServer(CFG.UseItemArg) end) end
        if carpet and carpet.Parent then
            if typeof(firesignal) == "function" then pcall(firesignal, carpet.Activated)
            else pcall(function() carpet.Activated:Fire() end) end
        end
    end)
end

-- ================================================================
-- TWEEN TP + BYPASS
-- ================================================================
local function tweenTP(targetHRP, onDone)
    local hrp = getHRP()
    if not hrp or not targetHRP then return end
    local carpet = findCarpet()
    if not carpet then
        if type(_G.tpToBestBrainrot) == "function" then pcall(_G.tpToBestBrainrot) end
        return
    end
    equipCarpet(carpet)
    task.wait(0.05)
    activationBypass(carpet, CFG.TweenTime + 0.25)
    local tw = TweenService:Create(hrp,
        TweenInfo.new(CFG.TweenTime, CFG.TweenStyle, CFG.TweenDir),
        { CFrame = targetHRP.CFrame * CFrame.new(0, 0, 3.5) })
    tw:Play()
    if onDone then tw.Completed:Connect(onDone) end
end

-- ================================================================
-- BRAINROT SCANNER — XV cache → workspace fallback
-- ================================================================
local function getBrainrots()
    local list, seen = {}, {}
    local myHRP = getHRP()
    -- XV AllAnimalsCache
    if type(_G.SharedState) == "table" and type(_G.SharedState.AllAnimalsCache) == "table" then
        for _, a in ipairs(_G.SharedState.AllAnimalsCache) do
            if a and a.uid and a.hrp and not seen[a.uid] then
                seen[a.uid] = true
                local d = myHRP and (a.hrp.Position - myHRP.Position).Magnitude or 0
                table.insert(list, { uid=a.uid, name=a.name or "?", genText=a.genText or "", owner=a.owner or "?", mutation=a.mutation, hrp=a.hrp, dist=d, raw=a })
            end
        end
    end
    -- workspace fallback
    if #list == 0 then
        local pNames = {}; for _, p in ipairs(Players:GetPlayers()) do pNames[p.Name] = true end
        for _, obj in ipairs(game:GetService("Workspace"):GetDescendants()) do
            if obj:IsA("Model") and not pNames[obj.Name] then
                local hrp = obj:FindFirstChild("HumanoidRootPart")
                local hum = obj:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health > 0 and not seen[obj.Name] then
                    seen[obj.Name] = true
                    local d = myHRP and (hrp.Position - myHRP.Position).Magnitude or 0
                    table.insert(list, { uid=obj.Name, name=obj.Name, genText="", owner="?", hrp=hrp, dist=d })
                end
            end
        end
    end
    table.sort(list, function(a,b) return a.dist < b.dist end)
    return list
end

-- ================================================================
-- AUTO STEAL
-- ================================================================
local autoOn, autoTarget, _autoConn = false, nil, nil
local function startAuto()
    if _autoConn then _autoConn:Disconnect() end
    local last = 0
    _autoConn = RunService.Heartbeat:Connect(function()
        if not autoOn then return end
        if os.clock() - last < CFG.AutoGrabRate then return end
        last = os.clock()
        if _G.JAF_TpActive then return end
        local tgt = autoTarget or getBrainrots()[1]
        if tgt and tgt.hrp and tgt.hrp.Parent then tweenTP(tgt.hrp) end
    end)
end
local function stopAuto() autoOn=false; if _autoConn then _autoConn:Disconnect() end end

-- ================================================================
-- THEME
-- ================================================================
local T = {
    bg      = Color3.fromRGB(11,11,13),
    surf    = Color3.fromRGB(22,22,27),
    surfHi  = Color3.fromRGB(32,32,40),
    acc     = Color3.fromRGB(255,46,147),
    green   = Color3.fromRGB(50,220,100),
    text    = Color3.fromRGB(240,240,245),
    muted   = Color3.fromRGB(120,120,130),
    err     = Color3.fromRGB(235,80,80),
    rowSel  = Color3.fromRGB(50,20,35),
}

-- ================================================================
-- UI HELPERS
-- ================================================================
local function mk(cls, parent, props)
    local o = Instance.new(cls)
    if props then for k,v in pairs(props) do o[k]=v end end
    o.Parent = parent; return o
end
local function corner(p, r) mk("UICorner",p,{CornerRadius=UDim.new(0,r or 10)}) end
local function stroke(p, col, th, tr)
    local s=mk("UIStroke",p); s.Color=col; s.Thickness=th or 1; s.Transparency=tr or 0; return s
end
local function lbl(parent, props)
    local l = mk("TextLabel", parent, {
        BackgroundTransparency=1, Font=Enum.Font.GothamMedium,
        TextSize=13, TextColor3=T.text,
        TextXAlignment=Enum.TextXAlignment.Left,
    })
    if props then for k,v in pairs(props) do l[k]=v end end
    return l
end
local function ibtn(parent, props)
    local b = mk("TextButton", parent, {
        BackgroundTransparency=1, Font=Enum.Font.GothamBold,
        TextSize=13, TextColor3=T.text, BorderSizePixel=0,
    })
    if props then for k,v in pairs(props) do b[k]=v end end
    return b
end

-- ================================================================
-- BUILD GUI
-- ================================================================
local old = PlayerGui:FindFirstChild("XV_Hub_v3")
if old then old:Destroy() end

local sg = mk("ScreenGui", PlayerGui, {
    Name="XV_Hub_v3", ResetOnSpawn=false,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset=true, DisplayOrder=9999
})

-- MAIN PANEL — matches source 258×430 at left side
local panel = mk("Frame", sg, {
    Name="panel",
    Size=UDim2.fromOffset(258,430),
    Position=UDim2.new(0,16,0,100),
    BackgroundColor3=T.bg,
    BackgroundTransparency=0.08,
    BorderSizePixel=0,
    ClipsDescendants=true,
    Active=true, Draggable=true,
})
corner(panel,14)
local pstroke = stroke(panel, T.acc, 1.5, 0.3)

-- HEADER
local hdr = mk("Frame", panel, {
    Size=UDim2.new(1,0,0,50),
    BackgroundTransparency=1, BorderSizePixel=0,
})
lbl(hdr, {
    Size=UDim2.new(1,-90,0,20), Position=UDim2.new(0,14,0,7),
    Text="XV PRIVATE", Font=Enum.Font.GothamBold,
    TextSize=15, TextColor3=T.text,
})
lbl(hdr, {
    Size=UDim2.new(1,-90,0,14), Position=UDim2.new(0,14,0,28),
    Text="Steal target", TextSize=12, TextColor3=T.muted,
})

-- count pill
local countPill = mk("TextLabel", hdr, {
    Size=UDim2.fromOffset(66,22), Position=UDim2.new(1,-78,0,14),
    BackgroundColor3=Color3.fromRGB(28,28,34), BorderSizePixel=0,
    Text="0 found", Font=Enum.Font.GothamMedium,
    TextSize=11, TextColor3=T.muted,
    TextXAlignment=Enum.TextXAlignment.Center,
})
corner(countPill,8)

-- settings gear button (small, top right)
local gearBtn = mk("TextButton", hdr, {
    Size=UDim2.fromOffset(28,28), Position=UDim2.new(1,-112,0,11),
    BackgroundColor3=T.surfHi, BorderSizePixel=0,
    Text="⚙", Font=Enum.Font.GothamBold,
    TextSize=14, TextColor3=T.muted,
})
corner(gearBtn,8)

-- header divider
mk("Frame", panel, {
    Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,0,50),
    BackgroundColor3=T.acc, BackgroundTransparency=0.6, BorderSizePixel=0,
})

-- SCROLL LIST — brainrot rows
local scroll = mk("ScrollingFrame", panel, {
    Size=UDim2.new(1,-10,1,-106),
    Position=UDim2.new(0,5,0,56),
    BackgroundTransparency=1, BorderSizePixel=0,
    ScrollBarImageTransparency=0.6, ScrollBarThickness=3,
    ScrollingDirection=Enum.ScrollingDirection.Y,
    CanvasSize=UDim2.new(0,0,0,0),
})
local uiList = mk("UIListLayout", scroll, {Padding=UDim.new(0,4), SortOrder=Enum.SortOrder.LayoutOrder})
mk("UIPadding", scroll, {PaddingTop=UDim.new(0,2), PaddingBottom=UDim.new(0,2)})
uiList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scroll.CanvasSize = UDim2.new(0,0,0,uiList.AbsoluteContentSize.Y+6)
end)

-- AUTO STEAL TOGGLE ROW — bottom of panel
local toggleRow = mk("Frame", panel, {
    Size=UDim2.new(1,-16,0,36), Position=UDim2.new(0,8,1,-44),
    BackgroundColor3=T.surf, BackgroundTransparency=0.1, BorderSizePixel=0,
})
corner(toggleRow,8)
local tgStroke = stroke(toggleRow, CFG.AutoSteal and T.green or T.muted, 1.2, 0.2)

local toggleLbl = lbl(toggleRow, {
    Size=UDim2.new(1,-56,1,0), Position=UDim2.new(0,12,0,0),
    Text=CFG.AutoSteal and "Auto Stealing" or "Stealing Off",
    Font=Enum.Font.GothamBold, TextSize=14,
})

local pillBg = mk("Frame", toggleRow, {
    Size=UDim2.fromOffset(42,22), Position=UDim2.new(1,-50,0.5,-11),
    BackgroundColor3=CFG.AutoSteal and T.green or T.muted, BorderSizePixel=0,
})
corner(pillBg,20)
local pillKnob = mk("Frame", pillBg, {
    Size=UDim2.fromOffset(16,16),
    Position=CFG.AutoSteal and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8),
    BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0,
})
corner(pillKnob,20)

local toggleBtn = mk("TextButton", toggleRow, {
    Size=UDim2.fromScale(1,1), BackgroundTransparency=1, Text="", BorderSizePixel=0,
})
local function updateToggle()
    local on = CFG.AutoSteal
    toggleLbl.Text = on and "Auto Stealing" or "Stealing Off"
    pillBg.BackgroundColor3 = on and T.green or T.muted
    pillKnob.Position = on and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
    tgStroke.Color = on and T.green or T.muted
    if type(_G.XV_Config) == "table" then _G.XV_Config.AutoSteal = on end
end
toggleBtn.MouseButton1Click:Connect(function()
    CFG.AutoSteal = not CFG.AutoSteal
    updateToggle()
    if CFG.AutoSteal then startAuto() else stopAuto() end
end)

-- ================================================================
-- STEAL BAR PILL — bottom floating bar
-- ================================================================
local stealBar = mk("Frame", sg, {
    Name="StealBarPill",
    Size=UDim2.fromOffset(258,50),
    Position=UDim2.new(0,16,0,544),
    BackgroundColor3=T.bg,
    BackgroundTransparency=0.05,
    BorderSizePixel=0,
    ClipsDescendants=true,
    Active=true, Draggable=true,
})
corner(stealBar,12)
stroke(stealBar, T.acc, 1.5, 0.3)

local nameLbl = lbl(stealBar, {
    Size=UDim2.new(1,-96,0,16), Position=UDim2.new(0,12,0,5),
    Text="No Target", Font=Enum.Font.GothamBold, TextSize=14,
    TextColor3=T.muted, TextTruncate=Enum.TextTruncate.AtEnd,
})
local genLbl = lbl(stealBar, {
    Size=UDim2.fromOffset(82,16), Position=UDim2.new(1,-90,0,5),
    Text="", Font=Enum.Font.GothamBold, TextSize=13,
    TextColor3=Color3.fromRGB(255,120,190),
    TextXAlignment=Enum.TextXAlignment.Right,
    RichText=true,
})
local pctLbl = lbl(stealBar, {
    Size=UDim2.fromOffset(150,13), Position=UDim2.new(0,12,0,24),
    Text="", Font=Enum.Font.GothamBold, TextSize=12,
    TextColor3=T.acc,
})
local track = mk("Frame", stealBar, {
    Size=UDim2.new(1,-32,0,8), Position=UDim2.new(0,16,1,-14),
    BackgroundColor3=Color3.fromRGB(28,28,32), BorderSizePixel=0,
})
corner(track,20)
local fill = mk("Frame", track, {
    Size=UDim2.new(0,0,1,0),
    BackgroundColor3=T.acc, BorderSizePixel=0,
})
corner(fill,20)

-- ================================================================
-- TP SETTINGS PANEL (gear opens this)
-- ================================================================
local tpPanel = mk("Frame", sg, {
    Size=UDim2.fromOffset(230,260),
    Position=UDim2.new(0,282,0,100),
    BackgroundColor3=T.bg,
    BackgroundTransparency=0.08,
    BorderSizePixel=0,
    ClipsDescendants=true,
    Visible=false,
    Active=true, Draggable=true,
})
corner(tpPanel,14)
stroke(tpPanel, T.acc, 1.5, 0.4)

lbl(tpPanel, {
    Size=UDim2.new(1,0,0,20), Position=UDim2.new(0,12,0,10),
    Text="TP SETTINGS", Font=Enum.Font.GothamBold,
    TextSize=13, TextColor3=T.acc,
})
mk("Frame", tpPanel, {
    Size=UDim2.new(1,0,0,1), Position=UDim2.new(0,0,0,34),
    BackgroundColor3=T.acc, BackgroundTransparency=0.6, BorderSizePixel=0,
})

-- carpet selector
lbl(tpPanel, {
    Size=UDim2.new(1,-20,0,16), Position=UDim2.new(0,12,0,42),
    Text="Carpet Tool", TextSize=12, TextColor3=T.muted,
})
local carpetBtns = {}
local carpetScroll = mk("ScrollingFrame", tpPanel, {
    Size=UDim2.new(1,-16,0,90), Position=UDim2.new(0,8,0,60),
    BackgroundTransparency=1, BorderSizePixel=0,
    ScrollBarThickness=2, ScrollBarImageTransparency=0.5,
    CanvasSize=UDim2.new(0,0,0,0),
})
local carpLL = mk("UIListLayout", carpetScroll, {Padding=UDim.new(0,4)})
carpLL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    carpetScroll.CanvasSize = UDim2.new(0,0,0,carpLL.AbsoluteContentSize.Y+4)
end)

local function selectCarpet(name)
    CFG.SelectedCarpet = name
    if type(_G.XV_Config)=="table" and type(_G.XV_Config.TpSettings)=="table" then
        _G.XV_Config.TpSettings.Tool = name
    end
    for n, b in pairs(carpetBtns) do
        b.BackgroundColor3 = (n == name) and T.acc or T.surfHi
        b.TextColor3 = (n == name) and Color3.new(1,1,1) or T.muted
    end
end

for _, name in ipairs(CFG.CarpetNames) do
    local cb = mk("TextButton", carpetScroll, {
        Size=UDim2.new(1,-4,0,28),
        BackgroundColor3=(name==CFG.SelectedCarpet) and T.acc or T.surfHi,
        BorderSizePixel=0,
        Text=name, Font=Enum.Font.GothamMedium,
        TextSize=12,
        TextColor3=(name==CFG.SelectedCarpet) and Color3.new(1,1,1) or T.muted,
        TextXAlignment=Enum.TextXAlignment.Left,
    })
    mk("UIPadding",cb,{PaddingLeft=UDim.new(0,10)})
    corner(cb,8)
    carpetBtns[name] = cb
    cb.MouseButton1Click:Connect(function() selectCarpet(name) end)
end

-- tween time slider label
lbl(tpPanel, {
    Size=UDim2.new(1,-20,0,16), Position=UDim2.new(0,12,0,158),
    Text="Tween Time", TextSize=12, TextColor3=T.muted,
})
local tweenValLbl = lbl(tpPanel, {
    Size=UDim2.fromOffset(50,16), Position=UDim2.new(1,-58,0,158),
    Text="0.35s", TextSize=12, TextColor3=T.acc,
    TextXAlignment=Enum.TextXAlignment.Right,
})
local tweenSlider = mk("Frame", tpPanel, {
    Size=UDim2.new(1,-24,0,6), Position=UDim2.new(0,12,0,180),
    BackgroundColor3=T.surfHi, BorderSizePixel=0,
})
corner(tweenSlider,20)
local tweenFill = mk("Frame", tweenSlider, {
    Size=UDim2.new(CFG.TweenTime/2,0,1,0),
    BackgroundColor3=T.acc, BorderSizePixel=0,
})
corner(tweenFill,20)
local tweenKnob = mk("TextButton", tweenSlider, {
    Size=UDim2.fromOffset(16,16),
    Position=UDim2.new(CFG.TweenTime/2,-8,0.5,-8),
    BackgroundColor3=Color3.new(1,1,1), BorderSizePixel=0,
    Text="", ZIndex=5,
})
corner(tweenKnob,20)
-- slider drag
local sliderDrag = false
tweenKnob.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
        sliderDrag=true
    end
end)
game:GetService("UserInputService").InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.Touch or i.UserInputType==Enum.UserInputType.MouseButton1 then
        sliderDrag=false
    end
end)
game:GetService("UserInputService").InputChanged:Connect(function(i)
    if not sliderDrag then return end
    if i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch then
        local abs = tweenSlider.AbsolutePosition; local sz = tweenSlider.AbsoluteSize
        local t = math.clamp((i.Position.X - abs.X)/sz.X, 0, 1)
        CFG.TweenTime = math.floor(t*20+0.5)/10 -- 0.0 to 2.0 step 0.1
        tweenFill.Size = UDim2.new(t,0,1,0)
        tweenKnob.Position = UDim2.new(t,-8,0.5,-8)
        tweenValLbl.Text = string.format("%.1fs", CFG.TweenTime)
    end
end)

-- insta tp toggle
local instaTog = mk("TextButton", tpPanel, {
    Size=UDim2.new(1,-16,0,32), Position=UDim2.new(0,8,0,200),
    BackgroundColor3=CFG.InstaTpBrainrot and T.acc or T.surfHi,
    BorderSizePixel=0,
    Text=CFG.InstaTpBrainrot and "Insta TP: ON" or "Insta TP: OFF",
    Font=Enum.Font.GothamBold, TextSize=13,
    TextColor3=Color3.new(1,1,1),
})
corner(instaTog,10)
instaTog.MouseButton1Click:Connect(function()
    CFG.InstaTpBrainrot = not CFG.InstaTpBrainrot
    if type(_G.XV_Config)=="table" and type(_G.XV_Config.TpSettings)=="table" then
        _G.XV_Config.TpSettings.InstaTpBrainrot = CFG.InstaTpBrainrot
        _G.JAF_BrainrotSimpleTp = CFG.InstaTpBrainrot
    end
    instaTog.BackgroundColor3 = CFG.InstaTpBrainrot and T.acc or T.surfHi
    instaTog.Text = CFG.InstaTpBrainrot and "Insta TP: ON" or "Insta TP: OFF"
end)

-- close tp panel
local tpClose = mk("TextButton", tpPanel, {
    Size=UDim2.fromOffset(24,24), Position=UDim2.new(1,-30,0,8),
    BackgroundColor3=Color3.fromRGB(50,20,30), BorderSizePixel=0,
    Text="✕", Font=Enum.Font.GothamBold, TextSize=11, TextColor3=T.muted,
})
corner(tpClose,8)
tpClose.MouseButton1Click:Connect(function() tpPanel.Visible=false end)
gearBtn.MouseButton1Click:Connect(function() tpPanel.Visible=not tpPanel.Visible end)

-- ================================================================
-- ROW BUILDER
-- ================================================================
local selectedUID = nil

local function buildList()
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
    end
    local list = getBrainrots()
    countPill.Text = tostring(#list) .. " found"

    if #list == 0 then
        local none = lbl(scroll, {
            Size=UDim2.new(1,0,0,36),
            Text="  no brainrots found",
            TextColor3=T.muted, TextSize=12,
        })
        scroll.CanvasSize = UDim2.new(0,0,0,36)
        return
    end

    for i, a in ipairs(list) do
        local isSel = (selectedUID == a.uid)
        -- row
        local row = mk("TextButton", scroll, {
            Size=UDim2.new(1,-4,0,48),
            LayoutOrder=i,
            BackgroundColor3=isSel and T.rowSel or T.surf,
            BackgroundTransparency=isSel and 0 or 0.15,
            BorderSizePixel=0,
            Text="",
        })
        corner(row,10)
        local rs = stroke(row,
            isSel and T.acc or Color3.fromRGB(60,60,70),
            isSel and 1.5 or 1,
            isSel and 0 or 0.3)

        -- rank number
        lbl(row, {
            Size=UDim2.fromOffset(24,48), Position=UDim2.new(0,8,0,0),
            Text=tostring(i), Font=Enum.Font.GothamBold, TextSize=13,
            TextColor3=isSel and T.acc or T.muted,
            TextXAlignment=Enum.TextXAlignment.Center,
        })

        -- name + mutation
        local dispName = a.name
        if a.mutation and a.mutation ~= "" and a.mutation ~= "None" then
            dispName = a.mutation .. "  " .. a.name
        end
        lbl(row, {
            Size=UDim2.new(1,-110,0,20), Position=UDim2.new(0,34,0,4),
            Text=dispName, Font=Enum.Font.GothamBold, TextSize=13,
            TextTruncate=Enum.TextTruncate.AtEnd,
        })

        -- gen + owner
        local infoLbl = mk("TextLabel", row, {
            Size=UDim2.new(1,-110,0,14), Position=UDim2.new(0,34,0,26),
            BackgroundTransparency=1, BorderSizePixel=0,
            Font=Enum.Font.GothamMedium, TextSize=11,
            TextColor3=T.muted, TextXAlignment=Enum.TextXAlignment.Left,
            RichText=true,
            Text=string.format('<font color="rgb(61,220,132)">%s</font><font color="rgb(120,120,130)">  ·  @%s</font>',
                tostring(a.genText), tostring(a.owner)),
        })

        -- select/target tag
        local tagLbl = mk("TextLabel", row, {
            Size=UDim2.fromOffset(58,26), Position=UDim2.new(1,-66,0.5,-13),
            BackgroundTransparency=1, BorderSizePixel=0,
            Text=isSel and "Target" or "Select",
            Font=Enum.Font.GothamBold, TextSize=12,
            TextColor3=T.acc,
            TextXAlignment=Enum.TextXAlignment.Center,
        })
        corner(tagLbl,8)
        stroke(tagLbl, T.acc, 1.2)

        -- click handler
        local ca = a
        row.MouseButton1Click:Connect(function()
            selectedUID = ca.uid
            autoTarget = ca
            -- update steal bar
            nameLbl.Text = ca.name; nameLbl.TextColor3 = T.text
            genLbl.Text = ca.genText or ""
            pctLbl.Text = "targeting..."
            -- tween TP immediately
            if ca.hrp and ca.hrp.Parent then
                tweenTP(ca.hrp, function()
                    pctLbl.Text = "arrived"
                    if type(_G.tpToBestBrainrot)=="function" then
                        task.wait(0.05); pcall(_G.tpToBestBrainrot)
                    end
                end)
            end
            buildList()
        end)
    end
end

buildList()

-- steal bar heartbeat update
RunService.Heartbeat:Connect(function()
    local tgt = _G.JAF_StealTgt
    if not tgt then
        if nameLbl.Text ~= "No Target" and selectedUID == nil then
            nameLbl.Text="No Target"; nameLbl.TextColor3=T.muted
            genLbl.Text=""; pctLbl.Text=""
            fill.Size=UDim2.new(0,0,1,0)
        end
        return
    end
    local prog = tonumber(_G.JAF_StealProgress) or 0
    fill.Size = UDim2.new(math.clamp(prog,0,1),0,1,0)
    pctLbl.Text = string.format("%.0f%%", prog*100)
    if tgt.name then nameLbl.Text=tgt.name; nameLbl.TextColor3=T.text end
    if tgt.genText then genLbl.Text=tgt.genText end
end)

-- auto refresh list every 3s
task.spawn(function()
    while sg.Parent do task.wait(3); buildList() end
end)

-- start auto if on
if CFG.AutoSteal then startAuto() end

print("[XV HUB v3] loaded")
