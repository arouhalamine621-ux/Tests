-- XV PRIVATE x ELYSIUM — Hybrid
-- Auto steal UI + scanner from XV Private
-- TP engine fully replaced by Elysium carpet system
-- NO grapple hook TP. NO XV tween/boost loop.
-- Elysium's UseItem activation + CFrame/Velocity go method ONLY.
-- Run AFTER both XV and Elysium have loaded.
-- ================================================================

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP                = Players.LocalPlayer
local PlayerGui         = LP:WaitForChild("PlayerGui")

local function getChar() return LP.Character end
local function getHRP()  local c=getChar(); return c and c:FindFirstChild("HumanoidRootPart") end

-- ================================================================
-- CONFIG
-- ================================================================
local CFG = {
    AutoSteal    = true,
    AutoGrabRate = 0.6,
    -- Elysium carpet names (mirrors Elysium source CARPET_NAMES)
    CarpetNames  = {"Flying Carpet","Witch's Broom","Cupid's Wings","Santa's Sleigh","Waverider","Magic Carpet","Carpet"},
    SelectedCarpet = (type(_G.ElysiumCarpetTool)=="string" and _G.ElysiumCarpetTool~="" and _G.ElysiumCarpetTool)
                     or "Flying Carpet",
    -- Elysium go settings
    GoSpeed      = tonumber(_G.ElysiumGoSpeed) or 400,
    GoMethod     = (_G.ElysiumGoMethod=="Velocity") and "Velocity" or "CFrame",
}

-- pull XV AutoSteal config if loaded
if type(_G.XV_Config)=="table" then
    if _G.XV_Config.AutoSteal~=nil then CFG.AutoSteal=_G.XV_Config.AutoSteal end
end

-- ================================================================
-- ELYSIUM REMOTE CACHE (same UUID as Elysium source)
-- ================================================================
local _useItemRE, _uuidRE
local function getRemote(name)
    for _,v in ipairs(ReplicatedStorage:GetDescendants()) do
        if v:IsA("RemoteEvent") and v.Name==name then return v end
    end
end
task.spawn(function() _useItemRE=getRemote("UseItem") end)
task.spawn(function() _uuidRE=getRemote("75c9466d-e4c0-4b02-b26a-c3615fcc1e42") end)

-- ================================================================
-- ELYSIUM CARPET EQUIP (mirrors ElysiumEquipCarpetOnly)
-- ================================================================
local function findCarpet()
    local c=getChar(); local bp=LP:FindFirstChild("Backpack")
    local names={CFG.SelectedCarpet}
    for _,n in ipairs(CFG.CarpetNames) do names[#names+1]=n end
    for _,n in ipairs(names) do
        if c and c:FindFirstChild(n) then return c:FindFirstChild(n) end
        if bp and bp:FindFirstChild(n) then return bp:FindFirstChild(n) end
    end
end

local function equipCarpet()
    -- use Elysium's equip if available
    if type(_G.ElysiumEquipCarpet)=="function" then
        pcall(_G.ElysiumEquipCarpet)
        return
    end
    local carpet=findCarpet()
    if not carpet then return end
    local c=getChar(); if not c then return end
    local hum=c:FindFirstChildOfClass("Humanoid")
    if hum then pcall(function() hum:EquipTool(carpet) end) end
end

-- ================================================================
-- ELYSIUM ACTIVATION BYPASS
-- fires UseItem + UUID remote on heartbeat — same path Elysium uses
-- makes server think carpet is ACTIVELY USED (not just held)
-- this is the patch for sammy's lagback detection
-- ================================================================
local _spoofConn
local function activationBypass(carpet, duration)
    if _spoofConn then _spoofConn:Disconnect() end
    if not(_useItemRE and _useItemRE.Parent) then _useItemRE=getRemote("UseItem") end
    if not(_uuidRE and _uuidRE.Parent) then _uuidRE=getRemote("75c9466d-e4c0-4b02-b26a-c3615fcc1e42") end
    local t0=os.clock()
    _spoofConn=RunService.Heartbeat:Connect(function()
        if os.clock()-t0>=duration then _spoofConn:Disconnect(); return end
        -- Elysium legacy fire path (GRAPPLE_ARG=0.8 from source)
        if _useItemRE and _useItemRE.Parent then
            pcall(function() _useItemRE:FireServer(0.8) end)
        end
        if _uuidRE and _uuidRE.Parent then
            pcall(function() _uuidRE:FireServer(0.8) end)
        end
        -- also firesignal Activated directly on the tool
        if carpet and carpet.Parent then
            if typeof(firesignal)=="function" then
                pcall(firesignal, carpet.Activated)
            else
                pcall(function() carpet.Activated:Fire() end)
            end
        end
    end)
end

-- ================================================================
-- ELYSIUM TP ENGINE — replaces ALL of XV's TP code
-- tries ElysiumGoToDestination first (native Elysium path)
-- falls back to CFrame walk with carpet activation bypass
-- ================================================================
local function elysiumTP(targetHRP, onDone)
    if not targetHRP or not targetHRP.Parent then return end

    -- PRIMARY: use Elysium's native go engine if loaded
    if type(_G.ElysiumGoToDestination)=="function" then
        task.spawn(function()
            pcall(_G.ElysiumGoToDestination, targetHRP.Parent, {
                speed  = CFG.GoSpeed,
                method = CFG.GoMethod,
            })
            if onDone then onDone() end
        end)
        return
    end

    -- SECONDARY: Elysium-style carpet CFrame walk with activation bypass
    local hrp=getHRP()
    if not hrp then return end

    equipCarpet()
    task.wait(0.05)

    local carpet=findCarpet()
    local goal=targetHRP.CFrame * CFrame.new(0,0,3.5)
    local dist=(goal.Position-hrp.Position).Magnitude
    local duration=math.clamp(dist/CFG.GoSpeed, 0.15, 2.0)

    -- activation bypass runs the full move duration
    if carpet then activationBypass(carpet, duration+0.25) end

    -- CFrame method: step toward target using ElysiumGoSpeed
    task.spawn(function()
        local t0=os.clock()
        while os.clock()-t0 < duration do
            local hrpNow=getHRP()
            if not hrpNow then break end
            local elapsed=os.clock()-t0
            local alpha=math.clamp(elapsed/duration, 0, 1)
            local stepped=hrpNow.CFrame:Lerp(goal, math.min(alpha+0.08, 1))
            hrpNow.CFrame=stepped
            RunService.Heartbeat:Wait()
        end
        -- snap to final position
        local hrpFinal=getHRP()
        if hrpFinal then hrpFinal.CFrame=goal end
        if onDone then onDone() end
    end)
end

-- ================================================================
-- BRAINROT SCANNER
-- reads XV AllAnimalsCache → Elysium scan cache → workspace fallback
-- ================================================================
local function getBrainrots()
    local list,seen={},{}
    local myHRP=getHRP()

    -- XV cache
    if type(_G.SharedState)=="table" and type(_G.SharedState.AllAnimalsCache)=="table" then
        for _,a in ipairs(_G.SharedState.AllAnimalsCache) do
            if a and a.uid and a.hrp and not seen[a.uid] then
                seen[a.uid]=true
                local d=myHRP and (a.hrp.Position-myHRP.Position).Magnitude or 0
                table.insert(list,{uid=a.uid,name=a.name or "?",genText=a.genText or "",owner=a.owner or "?",mutation=a.mutation,hrp=a.hrp,dist=d,raw=a})
            end
        end
    end

    -- Elysium scan cache fallback
    if #list==0 and type(_G.ElysiumScanCache)=="table" then
        for uid,entry in pairs(_G.ElysiumScanCache) do
            if entry and entry.hrp and not seen[uid] then
                seen[uid]=true
                local d=myHRP and (entry.hrp.Position-myHRP.Position).Magnitude or 0
                table.insert(list,{uid=uid,name=entry.name or tostring(uid),genText=entry.gen or "",owner=entry.owner or "?",hrp=entry.hrp,dist=d})
            end
        end
    end

    -- workspace fallback
    if #list==0 then
        local pNames={}
        for _,p in ipairs(Players:GetPlayers()) do pNames[p.Name]=true end
        for _,obj in ipairs(game:GetService("Workspace"):GetDescendants()) do
            if obj:IsA("Model") and not pNames[obj.Name] then
                local hrp=obj:FindFirstChild("HumanoidRootPart")
                local hum=obj:FindFirstChildOfClass("Humanoid")
                if hrp and hum and hum.Health>0 and not seen[obj.Name] then
                    seen[obj.Name]=true
                    local d=myHRP and (hrp.Position-myHRP.Position).Magnitude or 0
                    table.insert(list,{uid=obj.Name,name=obj.Name,genText="",owner="?",hrp=hrp,dist=d})
                end
            end
        end
    end

    table.sort(list,function(a,b) return a.dist<b.dist end)
    return list
end

-- ================================================================
-- AUTO STEAL
-- ================================================================
local autoOn,autoTarget,_autoConn=false,nil,nil
local function startAuto()
    if _autoConn then _autoConn:Disconnect() end
    local last=0
    _autoConn=RunService.Heartbeat:Connect(function()
        if not autoOn then return end
        if os.clock()-last<CFG.AutoGrabRate then return end
        last=os.clock()
        -- don't fight Elysium if it's already moving
        if _G.ElysiumTPActive or _G.ElysiumGoToStatus=="moving" then return end
        local tgt=autoTarget or getBrainrots()[1]
        if tgt and tgt.hrp and tgt.hrp.Parent then elysiumTP(tgt.hrp) end
    end)
end
local function stopAuto() autoOn=false; if _autoConn then _autoConn:Disconnect() end end

-- ================================================================
-- THEME — exact XV Private palette
-- ================================================================
local T={
    bg     =Color3.fromRGB(11,11,13),
    surf   =Color3.fromRGB(22,22,27),
    surfHi =Color3.fromRGB(32,32,40),
    acc    =Color3.fromRGB(255,46,147),
    green  =Color3.fromRGB(50,220,100),
    text   =Color3.fromRGB(240,240,245),
    muted  =Color3.fromRGB(120,120,130),
    err    =Color3.fromRGB(235,80,80),
    rowSel =Color3.fromRGB(50,20,35),
}

-- ================================================================
-- UI HELPERS
-- ================================================================
local function mk(cls,parent,props)
    local o=Instance.new(cls)
    if props then for k,v in pairs(props) do o[k]=v end end
    o.Parent=parent; return o
end
local function corner(p,r) mk("UICorner",p,{CornerRadius=UDim.new(0,r or 5)}) end
local function stroke(p,col,th,tr)
    local s=mk("UIStroke",p); s.Color=col; s.Thickness=th or 0.8; s.Transparency=tr or 0; return s
end
local function lbl(parent,props)
    local l=mk("TextLabel",parent,{BackgroundTransparency=1,Font=Enum.Font.GothamMedium,TextSize=7,TextColor3=T.text,TextXAlignment=Enum.TextXAlignment.Left})
    if props then for k,v in pairs(props) do l[k]=v end end; return l
end

-- ================================================================
-- BUILD GUI — XV Private shape, 50% scaled
-- ================================================================
local old=PlayerGui:FindFirstChild("XV_Elysium")
if old then old:Destroy() end

local sg=mk("ScreenGui",PlayerGui,{
    Name="XV_Elysium",ResetOnSpawn=false,
    ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
    IgnoreGuiInset=true,DisplayOrder=9999,
})

-- MAIN PANEL 129×215
local panel=mk("Frame",sg,{
    Name="panel",
    Size=UDim2.fromOffset(129,215),
    Position=UDim2.new(0,8,0,50),
    BackgroundColor3=T.bg,BackgroundTransparency=0.08,
    BorderSizePixel=0,ClipsDescendants=true,
    Active=true,Draggable=true,
})
corner(panel,7)
stroke(panel,T.acc,0.8,0.3)

-- header
local hdr=mk("Frame",panel,{Size=UDim2.new(1,0,0,25),BackgroundTransparency=1,BorderSizePixel=0})
lbl(hdr,{Size=UDim2.new(1,-45,0,10),Position=UDim2.new(0,7,0,4),Text="XV PRIVATE",Font=Enum.Font.GothamBold,TextSize=8,TextColor3=T.text})
lbl(hdr,{Size=UDim2.new(1,-45,0,7),Position=UDim2.new(0,7,0,14),Text="Steal target",TextSize=6,TextColor3=T.muted})

local countPill=mk("TextLabel",hdr,{
    Size=UDim2.fromOffset(33,11),Position=UDim2.new(1,-39,0,7),
    BackgroundColor3=Color3.fromRGB(28,28,34),BorderSizePixel=0,
    Text="0 found",Font=Enum.Font.GothamMedium,TextSize=6,TextColor3=T.muted,
    TextXAlignment=Enum.TextXAlignment.Center,
})
corner(countPill,4)

-- gear btn (opens TP settings)
local gearBtn=mk("TextButton",hdr,{
    Size=UDim2.fromOffset(14,14),Position=UDim2.new(1,-56,0,6),
    BackgroundColor3=T.surfHi,BorderSizePixel=0,
    Text="⚙",Font=Enum.Font.GothamBold,TextSize=7,TextColor3=T.muted,
})
corner(gearBtn,4)

mk("Frame",panel,{Size=UDim2.new(1,0,0,0.5),Position=UDim2.new(0,0,0,25),BackgroundColor3=T.acc,BackgroundTransparency=0.6,BorderSizePixel=0})

-- scroll list
local scroll=mk("ScrollingFrame",panel,{
    Size=UDim2.new(1,-5,1,-53),Position=UDim2.new(0,2,0,28),
    BackgroundTransparency=1,BorderSizePixel=0,
    ScrollBarImageTransparency=0.6,ScrollBarThickness=2,
    ScrollingDirection=Enum.ScrollingDirection.Y,CanvasSize=UDim2.new(0,0,0,0),
})
local uiList=mk("UIListLayout",scroll,{Padding=UDim.new(0,2),SortOrder=Enum.SortOrder.LayoutOrder})
mk("UIPadding",scroll,{PaddingTop=UDim.new(0,1),PaddingBottom=UDim.new(0,1)})
uiList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scroll.CanvasSize=UDim2.new(0,0,0,uiList.AbsoluteContentSize.Y+4)
end)

-- auto steal toggle row
local toggleRow=mk("Frame",panel,{
    Size=UDim2.new(1,-8,0,18),Position=UDim2.new(0,4,1,-22),
    BackgroundColor3=T.surf,BackgroundTransparency=0.1,BorderSizePixel=0,
})
corner(toggleRow,5)
local tgStroke=stroke(toggleRow,CFG.AutoSteal and T.green or T.muted,0.6,0.2)
local toggleLbl=lbl(toggleRow,{
    Size=UDim2.new(1,-28,1,0),Position=UDim2.new(0,6,0,0),
    Text=CFG.AutoSteal and "Auto Stealing" or "Stealing Off",
    Font=Enum.Font.GothamBold,TextSize=7,
})
local pillBg=mk("Frame",toggleRow,{
    Size=UDim2.fromOffset(21,11),Position=UDim2.new(1,-25,0.5,-5.5),
    BackgroundColor3=CFG.AutoSteal and T.green or T.muted,BorderSizePixel=0,
})
corner(pillBg,10)
local pillKnob=mk("Frame",pillBg,{
    Size=UDim2.fromOffset(8,8),
    Position=CFG.AutoSteal and UDim2.new(1,-9.5,0.5,-4) or UDim2.new(0,1.5,0.5,-4),
    BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,
})
corner(pillKnob,10)
local toggleBtn=mk("TextButton",toggleRow,{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",BorderSizePixel=0})
local function updateToggle()
    local on=CFG.AutoSteal
    toggleLbl.Text=on and "Auto Stealing" or "Stealing Off"
    pillBg.BackgroundColor3=on and T.green or T.muted
    pillKnob.Position=on and UDim2.new(1,-9.5,0.5,-4) or UDim2.new(0,1.5,0.5,-4)
    tgStroke.Color=on and T.green or T.muted
    if type(_G.XV_Config)=="table" then _G.XV_Config.AutoSteal=on end
    if type(_G.ElysiumAutoTP)~="nil" then _G.ElysiumAutoTP=on end
end
toggleBtn.MouseButton1Click:Connect(function()
    CFG.AutoSteal=not CFG.AutoSteal
    updateToggle()
    if CFG.AutoSteal then startAuto() else stopAuto() end
end)

-- ================================================================
-- STEAL BAR PILL
-- ================================================================
local stealBar=mk("Frame",sg,{
    Name="StealBarPill",
    Size=UDim2.fromOffset(129,25),
    Position=UDim2.new(0,8,0,272),
    BackgroundColor3=T.bg,BackgroundTransparency=0.05,
    BorderSizePixel=0,ClipsDescendants=true,
    Active=true,Draggable=true,
})
corner(stealBar,6)
stroke(stealBar,T.acc,0.8,0.3)
local nameLbl=lbl(stealBar,{Size=UDim2.new(1,-48,0,8),Position=UDim2.new(0,6,0,3),Text="No Target",Font=Enum.Font.GothamBold,TextSize=7,TextColor3=T.muted,TextTruncate=Enum.TextTruncate.AtEnd})
local genLbl=lbl(stealBar,{Size=UDim2.fromOffset(41,8),Position=UDim2.new(1,-45,0,3),Text="",Font=Enum.Font.GothamBold,TextSize=6,TextColor3=Color3.fromRGB(255,120,190),TextXAlignment=Enum.TextXAlignment.Right,RichText=true})
local pctLbl=lbl(stealBar,{Size=UDim2.fromOffset(75,7),Position=UDim2.new(0,6,0,12),Text="",Font=Enum.Font.GothamBold,TextSize=6,TextColor3=T.acc})
local track=mk("Frame",stealBar,{Size=UDim2.new(1,-16,0,4),Position=UDim2.new(0,8,1,-7),BackgroundColor3=Color3.fromRGB(28,28,32),BorderSizePixel=0})
corner(track,10)
local fill=mk("Frame",track,{Size=UDim2.new(0,0,1,0),BackgroundColor3=T.acc,BorderSizePixel=0})
corner(fill,10)

-- ================================================================
-- TP SETTINGS PANEL (gear opens this)
-- ================================================================
local tpPanel=mk("Frame",sg,{
    Size=UDim2.fromOffset(115,130),
    Position=UDim2.new(0,141,0,50),
    BackgroundColor3=T.bg,BackgroundTransparency=0.08,
    BorderSizePixel=0,ClipsDescendants=true,
    Visible=false,Active=true,Draggable=true,
})
corner(tpPanel,7)
stroke(tpPanel,T.acc,0.8,0.4)

local tpClose=mk("TextButton",tpPanel,{
    Size=UDim2.fromOffset(12,12),Position=UDim2.new(1,-15,0,4),
    BackgroundColor3=Color3.fromRGB(50,20,30),BorderSizePixel=0,
    Text="✕",Font=Enum.Font.GothamBold,TextSize=6,TextColor3=T.muted,
})
corner(tpClose,3)
tpClose.MouseButton1Click:Connect(function() tpPanel.Visible=false end)
gearBtn.MouseButton1Click:Connect(function() tpPanel.Visible=not tpPanel.Visible end)

lbl(tpPanel,{Size=UDim2.new(1,0,0,10),Position=UDim2.new(0,6,0,5),Text="TP SETTINGS",Font=Enum.Font.GothamBold,TextSize=7,TextColor3=T.acc})
mk("Frame",tpPanel,{Size=UDim2.new(1,0,0,0.5),Position=UDim2.new(0,0,0,17),BackgroundColor3=T.acc,BackgroundTransparency=0.6,BorderSizePixel=0})
lbl(tpPanel,{Size=UDim2.new(1,-12,0,8),Position=UDim2.new(0,6,0,20),Text="Carpet Tool",TextSize=6,TextColor3=T.muted})

-- carpet scroll
local carpetScroll=mk("ScrollingFrame",tpPanel,{
    Size=UDim2.new(1,-8,0,60),Position=UDim2.new(0,4,0,30),
    BackgroundTransparency=1,BorderSizePixel=0,
    ScrollBarThickness=1,ScrollBarImageTransparency=0.5,CanvasSize=UDim2.new(0,0,0,0),
})
local carpLL=mk("UIListLayout",carpetScroll,{Padding=UDim.new(0,2)})
carpLL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    carpetScroll.CanvasSize=UDim2.new(0,0,0,carpLL.AbsoluteContentSize.Y+2)
end)

local carpetBtns={}
local function selectCarpet(name)
    CFG.SelectedCarpet=name
    _G.ElysiumCarpetTool=name
    if type(_G.ElysiumSetCarpetTool)=="function" then pcall(_G.ElysiumSetCarpetTool,name) end
    if type(_G.XV_Config)=="table" and type(_G.XV_Config.TpSettings)=="table" then
        _G.XV_Config.TpSettings.Tool=name
    end
    for n,b in pairs(carpetBtns) do
        b.BackgroundColor3=(n==name) and T.acc or T.surfHi
        b.TextColor3=(n==name) and Color3.new(1,1,1) or T.muted
    end
end

for _,name in ipairs(CFG.CarpetNames) do
    local cb=mk("TextButton",carpetScroll,{
        Size=UDim2.new(1,-2,0,14),
        BackgroundColor3=(name==CFG.SelectedCarpet) and T.acc or T.surfHi,
        BorderSizePixel=0,Text=name,Font=Enum.Font.GothamMedium,
        TextSize=6,TextColor3=(name==CFG.SelectedCarpet) and Color3.new(1,1,1) or T.muted,
        TextXAlignment=Enum.TextXAlignment.Left,
    })
    mk("UIPadding",cb,{PaddingLeft=UDim.new(0,5)})
    corner(cb,4)
    carpetBtns[name]=cb
    cb.MouseButton1Click:Connect(function() selectCarpet(name) end)
end

-- go method toggle
mk("Frame",tpPanel,{Size=UDim2.new(1,0,0,0.5),Position=UDim2.new(0,0,0,94),BackgroundColor3=T.acc,BackgroundTransparency=0.7,BorderSizePixel=0})
lbl(tpPanel,{Size=UDim2.new(1,-12,0,8),Position=UDim2.new(0,6,0,97),Text="Go Method",TextSize=6,TextColor3=T.muted})
local methodBtn=mk("TextButton",tpPanel,{
    Size=UDim2.new(1,-8,0,14),Position=UDim2.new(0,4,0,107),
    BackgroundColor3=T.surfHi,BorderSizePixel=0,
    Text="Method: "..CFG.GoMethod,Font=Enum.Font.GothamBold,
    TextSize=6,TextColor3=T.text,
})
corner(methodBtn,4)
methodBtn.MouseButton1Click:Connect(function()
    CFG.GoMethod=CFG.GoMethod=="CFrame" and "Velocity" or "CFrame"
    _G.ElysiumGoMethod=CFG.GoMethod
    methodBtn.Text="Method: "..CFG.GoMethod
end)

-- ================================================================
-- ROW BUILDER — exact XV Private shape
-- ================================================================
local selectedUID=nil

local function buildList()
    for _,c in ipairs(scroll:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
    end
    local list=getBrainrots()
    countPill.Text=tostring(#list).." found"
    if #list==0 then
        lbl(scroll,{Size=UDim2.new(1,0,0,18),Text="  no brainrots found",TextColor3=T.muted,TextSize=6})
        scroll.CanvasSize=UDim2.new(0,0,0,18); return
    end
    for i,a in ipairs(list) do
        local isSel=(selectedUID==a.uid)
        local row=mk("TextButton",scroll,{
            Size=UDim2.new(1,-2,0,24),LayoutOrder=i,
            BackgroundColor3=isSel and T.rowSel or T.surf,
            BackgroundTransparency=isSel and 0 or 0.15,
            BorderSizePixel=0,Text="",
        })
        corner(row,5)
        stroke(row,isSel and T.acc or Color3.fromRGB(60,60,70),isSel and 0.8 or 0.5,isSel and 0 or 0.4)

        -- rank
        lbl(row,{Size=UDim2.fromOffset(12,24),Position=UDim2.new(0,4,0,0),Text=tostring(i),Font=Enum.Font.GothamBold,TextSize=6,TextColor3=isSel and T.acc or T.muted,TextXAlignment=Enum.TextXAlignment.Center})

        -- name + mutation
        local dispName=a.name
        if a.mutation and a.mutation~="" and a.mutation~="None" then dispName=a.mutation.."  "..a.name end
        lbl(row,{Size=UDim2.new(1,-55,0,10),Position=UDim2.new(0,17,0,2),Text=dispName,Font=Enum.Font.GothamBold,TextSize=6,TextTruncate=Enum.TextTruncate.AtEnd})

        -- gen + owner
        mk("TextLabel",row,{
            Size=UDim2.new(1,-55,0,7),Position=UDim2.new(0,17,0,13),
            BackgroundTransparency=1,BorderSizePixel=0,
            Font=Enum.Font.GothamMedium,TextSize=5,
            TextColor3=T.muted,TextXAlignment=Enum.TextXAlignment.Left,
            RichText=true,
            Text=string.format('<font color="rgb(61,220,132)">%s</font><font color="rgb(110,110,120)">  ·  @%s</font>',tostring(a.genText),tostring(a.owner)),
        })

        -- select/target tag
        local tagLbl=mk("TextLabel",row,{
            Size=UDim2.fromOffset(29,13),Position=UDim2.new(1,-33,0.5,-6.5),
            BackgroundTransparency=1,BorderSizePixel=0,
            Text=isSel and "Target" or "Select",Font=Enum.Font.GothamBold,
            TextSize=5,TextColor3=T.acc,TextXAlignment=Enum.TextXAlignment.Center,
        })
        corner(tagLbl,4)
        stroke(tagLbl,T.acc,0.6)

        -- click: select + Elysium TP
        local ca=a
        row.MouseButton1Click:Connect(function()
            selectedUID=ca.uid
            autoTarget=ca
            nameLbl.Text=ca.name; nameLbl.TextColor3=T.text
            genLbl.Text=ca.genText or ""
            pctLbl.Text="moving..."
            fill.Size=UDim2.new(0,0,1,0)
            if ca.hrp and ca.hrp.Parent then
                elysiumTP(ca.hrp, function()
                    pctLbl.Text="arrived"
                    -- trigger XV steal after arriving
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

-- steal bar update from Elysium/XV steal state
RunService.Heartbeat:Connect(function()
    -- Elysium progress
    local prog=tonumber(_G.ElysiumStealProgress) or tonumber(_G.JAF_StealProgress) or 0
    local tgt=_G.ElysiumStealTarget or _G.JAF_StealTgt
    if tgt then
        fill.Size=UDim2.new(math.clamp(prog,0,1),0,1,0)
        pctLbl.Text=string.format("%.0f%%",prog*100)
        if tgt.name then nameLbl.Text=tgt.name; nameLbl.TextColor3=T.text end
        if tgt.genText then genLbl.Text=tgt.genText end
    else
        if selectedUID==nil then
            nameLbl.Text="No Target"; nameLbl.TextColor3=T.muted
            genLbl.Text=""; pctLbl.Text=""
            fill.Size=UDim2.new(0,0,1,0)
        end
    end
end)

-- auto refresh every 3s
task.spawn(function()
    while sg.Parent do task.wait(3); buildList() end
end)

-- start auto if on
if CFG.AutoSteal then startAuto() end

print("[XV x Elysium] loaded — Elysium TP engine active, XV UI intact")
