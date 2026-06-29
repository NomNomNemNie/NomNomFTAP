-- ==========================================================
-- NomNom FTAP / Combat module
-- Super Fling, Massless Grab, Teleport & Bring (stack/loop), the
-- predictive Loop Fling engine, and the persistent grab-kill /
-- attack-back layer:
--   * Persistent grab-kill loop runs WHILE DEAD.
--   * On death (= we lost gucci) we immediately mark the killer,
--     delete the killer's gucci, and kill back.
-- ----------------------------------------------------------
-- Depends on Core (_G.NomNom). Builds UI into the Combat tab.
-- ==========================================================

local NN = _G.NomNom
assert(NN, "[NomNom] Combat module requires Core loaded first")

local S          = NN.S
local LP         = NN.LP
local w          = NN.w
local Players    = NN.Services.Players
local RunService = NN.Services.RunService
local Debris     = NN.Services.Debris
local UserInputService = NN.Services.UserInputService

-- ==========================================
-- SUPER FLING
-- ==========================================
local FLING_VEL = "NomNomFlingVel"
NN.AddConn("SuperFlingWatcher", w.ChildAdded:Connect(function(child)
    if not S.SuperFling or child.Name ~= "GrabParts" then return end
    local ok, grabPart = pcall(function()
        return child:WaitForChild("GrabPart", 2):WaitForChild("WeldConstraint", 2).Part1
    end)
    if not ok or not grabPart then return end
    local bv = Instance.new("BodyVelocity"); bv.Name = FLING_VEL; bv.Parent = grabPart
    local conn
    conn = child:GetPropertyChangedSignal("Parent"):Connect(function()
        if child.Parent == nil then
            if S.SuperFling then
                bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                bv.Velocity = w.CurrentCamera.CFrame.LookVector * S.FlingStrength
            else bv.MaxForce = Vector3.zero end
            Debris:AddItem(bv, 1)
            if conn then conn:Disconnect() end
        end
    end)
end))

-- ==========================================
-- TELEPORT & BRING
-- ==========================================
local grabbed = {}
local grabProcessing = false

local function grabPlayer(target)
    if not target or not target.Character then return end
    local tHum = target.Character:FindFirstChildOfClass("Humanoid")
    local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
    local myHRP = NN.getHRP()
    local grabEvt = NN.remote({"GrabEvents", "SetNetworkOwner"})
    if not tHum or not tHRP or not myHRP or not grabEvt then return end
    local origCF = myHRP.CFrame
    myHRP.CFrame = tHRP.CFrame * CFrame.new(0, 3, 0)
    task.wait(0.2)
    grabEvt:FireServer(tHRP, tHRP.CFrame)
    tHum.Sit = true; tHum.WalkSpeed = 0
    task.wait(0.1)
    local destCF
    if S.StackMode then destCF = origCF * CFrame.new(0, S.GrabHeight * (#grabbed + 1), 0)
    else destCF = origCF * CFrame.new(math.random(-5, 5), S.GrabHeight, math.random(-5, 5)) end
    tHRP.CFrame = destCF
    local hold
    hold = RunService.Heartbeat:Connect(function()
        if tHum.Parent and (S.LoopBring or S.StackMode) then
            tHRP.Velocity = Vector3.zero; tHRP.CFrame = destCF
        elseif hold then hold:Disconnect() end
    end)
    table.insert(grabbed, { root = tHRP, connection = hold, humanoid = tHum })
    task.wait(0.1)
    myHRP.CFrame = origCF
end

local function releaseAll()
    local grabEvt = NN.remote({"GrabEvents", "SetNetworkOwner"})
    for _, d in ipairs(grabbed) do
        if d.connection then pcall(function() d.connection:Disconnect() end) end
        if d.root and d.humanoid then
            pcall(function()
                if grabEvt then grabEvt:FireServer(d.root, d.root.CFrame) end
                d.humanoid.Sit = false; d.humanoid.WalkSpeed = 16
                d.root.Velocity = Vector3.new(0, 50, 0)
            end)
        end
    end
    grabbed = {}
end
NN.releaseAllGrabs = releaseAll

local function bringTargets(targets)
    if grabProcessing then return end
    grabProcessing = true
    for _, d in ipairs(grabbed) do if d.connection then pcall(function() d.connection:Disconnect() end) end end
    grabbed = {}
    for _, plr in ipairs(targets) do if plr ~= LP and plr.Character then grabPlayer(plr) end end
    grabProcessing = false
end

local function collectTargets()
    local targets = {}
    if S.BringMode == "all" then targets = Players:GetPlayers()
    elseif S.BringMode == "nearby" then
        local myHRP = NN.getHRP()
        if myHRP then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LP and plr.Character then
                    local tHRP = plr.Character:FindFirstChild("HumanoidRootPart")
                    if tHRP and (myHRP.Position - tHRP.Position).Magnitude <= 70 then table.insert(targets, plr) end
                end
            end
        end
    elseif S.BringMode == "whitelist" then
        for _, name in ipairs(S.Whitelist) do
            local plr = Players:FindFirstChild(name)
            if plr then table.insert(targets, plr) end
        end
    end
    return targets
end

-- ==========================================
-- LOOP FLING (predictive + LOS + ownership)
-- ==========================================
local fling = { decoy = nil, target = nil, conn = nil, targetIndex = 1,
    flungMap = {}, velHistory = {} }
NN.Fling = fling
local toyMap = { YouLittle = "Head", YouDecoy = "Head", DiceSmall = "SoundPart", DiceBig = "SoundPart" }

local function isFlung(p)
    local h = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    if not h then return true end
    local v = h.Velocity
    fling.velHistory[p] = fling.velHistory[p] or {}
    local hist = fling.velHistory[p]
    table.insert(hist, { v, h.Position.Y })
    if #hist > 15 then table.remove(hist, 1) end
    local bad = 0
    for _, d in ipairs(hist) do
        local vel, y = d[1], d[2]
        if y > 3000 or y < -150 then bad += 1
        elseif math.abs(vel.Y) > 220 or Vector3.new(vel.X, 0, vel.Z).Magnitude > 300 then bad += 1 end
    end
    return bad / #hist >= 0.4
end
local function isGrounded(p)
    local h = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
    return h and h.Position.Y < 100 and math.abs(h.Velocity.Y) < 10
end
local function getFlingTargets()
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p:GetAttribute("NomNomTarget")
           and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            table.insert(list, p)
        end
    end
    return list
end
local function pickNext(targets)
    local c = #targets
    if c == 0 then return nil end
    for i = 1, c do
        fling.targetIndex = ((fling.targetIndex + i - 1) % c) + 1
        local t = targets[fling.targetIndex]
        if not fling.flungMap[t] or isGrounded(t) then return t end
    end
    return nil
end
local function setupFling(d)
    local partName = toyMap[d.Name]; if not partName then return end
    local hrp = d:FindFirstChild(partName); if not hrp then return end
    hrp.CanCollide = false
    local bt = Instance.new("BodyThrust"); bt.Force = Vector3.zero; bt.Parent = hrp
    local bav = Instance.new("BodyAngularVelocity")
    bav.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bav.AngularVelocity = Vector3.new(-1e6, -1e6, -1e6); bav.Parent = hrp
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { NN.getChar(), d }
    params.IgnoreWater = true
    fling.conn = RunService.Heartbeat:Connect(function()
        if not d or not d.Parent or not S.LoopFling then
            if fling.conn then fling.conn:Disconnect() end
            pcall(function() bt:Destroy() end); pcall(function() bav:Destroy() end)
            return
        end
        pcall(function() w.FallenPartsDestroyHeight = 0/0 end)
        local tList = getFlingTargets()
        for p in pairs(fling.flungMap) do
            if not table.find(tList, p) or not p.Character or isGrounded(p) then fling.flungMap[p] = nil end
        end
        if fling.target and (not fling.target.Character or isFlung(fling.target)) then
            fling.flungMap[fling.target] = true; fling.target = nil
        end
        if not fling.target then fling.target = pickNext(tList) end
        local destCF
        if fling.target and fling.target.Character then
            local tHRP = fling.target.Character:FindFirstChild("HumanoidRootPart")
            if tHRP then
                local vel = tHRP.Velocity
                local tm = math.clamp(vel.Magnitude / 40, 0.25, 0.6)
                local predicted = tHRP.Position + vel * tm + Vector3.new(0, 2, 0)
                local result = w:Raycast(hrp.Position, (predicted - hrp.Position), params)
                if result and result.Instance and result.Instance:IsDescendantOf(fling.target.Character) then
                    destCF = CFrame.new(result.Position)
                else destCF = CFrame.new(predicted) end
            end
        end
        if not destCF then destCF = CFrame.new(0, 5000, 0) end
        for _, p in ipairs(d:GetDescendants()) do if p:IsA("BasePart") then p.CFrame = destCF end end
        if bt.Parent then bt.Force = (destCF.Position - hrp.Position).Unit * 500 end
    end)
end
local function spawnFlingDecoy()
    if fling.decoy and fling.decoy.Parent then return end
    local myHRP = NN.getHRP(); if not myHRP then return end
    -- existence-based: wait for the toy to actually exist
    local m = NN.spawnToyAndWait(S.SelectedToy, myHRP.CFrame * CFrame.new(5, 0, 5), Vector3.new(0, 33, 0), 4)
    if m then NN.handleFlingDecoy(m) end
end
function NN.handleFlingDecoy(d)
    if fling.decoy and fling.decoy.Parent then return end
    local partName = toyMap[d.Name]; if not partName then return end
    local toyPart = d:WaitForChild(partName, 5); if not toyPart then return end
    local grabEvt = NN.remote({"GrabEvents", "SetNetworkOwner"})
    local destroyToy = NN.remote({"MenuToys", "DestroyToy"})
    if not grabEvt then return end
    grabEvt:FireServer(toyPart, d:GetPivot())
    task.wait(0.09)
    local startT, success = tick(), false
    local conn
    conn = RunService.Heartbeat:Connect(function()
        local tag = toyPart:FindFirstChild("PartOwner")
        if tag and tag:IsA("StringValue") and tag.Value == LP.Name then
            success = true; conn:Disconnect()
            d:SetAttribute("NomNomOwned", true); fling.decoy = d
            if S.LoopFling then setupFling(d) end
        end
        if tick() - startT >= 3 and not success then
            if destroyToy then pcall(function() destroyToy:FireServer(d) end) end
            conn:Disconnect()
        end
    end)
end
task.spawn(function()
    local folder = NN.getToyFolder() or w:WaitForChild(LP.Name .. "SpawnedInToys", 30)
    if not folder then return end
    NN.AddConn("FlingFolderAdd", folder.ChildAdded:Connect(function(c)
        if toyMap[c.Name] and S.LoopFling then NN.handleFlingDecoy(c) end
    end))
    NN.AddConn("FlingFolderRemove", folder.ChildRemoved:Connect(function(c)
        if c == fling.decoy then fling.decoy = nil end
    end))
end)
NN.AddConn("FlingKeepAlive", RunService.Heartbeat:Connect(function()
    if not S.LoopFling then return end
    if not fling.decoy or not fling.decoy.Parent then
        local folder = NN.getToyFolder()
        if folder then
            for _, t in ipairs(folder:GetChildren()) do
                if toyMap[t.Name] and t:GetAttribute("NomNomOwned") then fling.decoy = t; return end
            end
        end
        spawnFlingDecoy()
    end
end))
function NN.updateFlingTargets()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then p:SetAttribute("NomNomTarget", S.LoopFling or (S.MarkedTargets[p] == true)) end
    end
end

-- ==========================================
-- PERSISTENT GRAB-KILL + ATTACK-BACK
-- ==========================================
local function findHolders()
    local holders = {}
    local gp = w:FindFirstChild("GrabParts")
    if gp then
        local owner = gp:FindFirstChild("PartOwner")
        if owner and owner:IsA("StringValue") and owner.Value ~= "" and owner.Value ~= LP.Name then
            local p = Players:FindFirstChild(owner.Value)
            if p then holders[p] = true end
        end
    end
    return holders
end
NN.findHolders = findHolders

local function findEnemyGucci(player)
    if not player or not player.Character then return nil end
    local hum = player.Character:FindFirstChildOfClass("Humanoid")
    for _, v in ipairs(w:GetDescendants()) do
        if v:IsA("Model") and (v.Name == "TractorGreen" or v.Name == "CreatureBlobman") then
            local seat = v:FindFirstChildWhichIsA("VehicleSeat", true)
            if seat and hum and seat.Occupant == hum then return v, seat end
        end
    end
    return nil
end
NN.findEnemyGucci = findEnemyGucci

function NN.markPlayer(p)
    if p and p ~= LP then S.MarkedTargets[p] = true; p:SetAttribute("NomNomTarget", true) end
end

-- on-death handler used by Core's respawn binding:
-- being killed means we lost gucci, so immediately delete the killer's
-- gucci and kill back.
function NN.onDeathAttackBack()
    if not S.AutoAttackBack then return end
    local holders = findHolders()
    local destroyToy = NN.remote({"MenuToys", "DestroyToy"})
    for holder in pairs(holders) do
        NN.markPlayer(holder)
        if S.AutoDeleteKillerGucci then
            local g = findEnemyGucci(holder)
            if g and destroyToy then pcall(function() destroyToy:FireServer(g) end) end
        end
    end
end

-- ==========================================
-- UI
-- ==========================================
function NN.buildCombatUI(CombatTab)
    CombatTab:CreateSection("Super Fling")
    CombatTab:CreateToggle({ Name = "Super Fling (on grab release)", CurrentValue = false, Flag = "SuperFling",
        Callback = function(v) S.SuperFling = v end })
    CombatTab:CreateSlider({ Name = "Fling Strength", Range = {100, 5000}, Increment = 50,
        CurrentValue = 850, Flag = "FlingPower", Callback = function(v) S.FlingStrength = v end })

    CombatTab:CreateSection("Massless Grab")
    CombatTab:CreateToggle({ Name = "Massless Grab (Player & Object)", CurrentValue = false, Flag = "Massless",
        Callback = function(v)
            S.Massless = v
            if v then
                NN.AddConn("Massless", w.ChildAdded:Connect(function(r)
                    if r.Name ~= "GrabParts" then return end
                    while w:FindFirstChild("GrabParts") and S.Massless do
                        task.wait()
                        local dp = r:FindFirstChild("DragPart")
                        if dp then
                            local ap = dp:FindFirstChild("AlignPosition")
                            local ao = dp:FindFirstChild("AlignOrientation")
                            if ap then ap.Responsiveness = S.MasslessSense; ap.MaxForce = math.huge; ap.MaxVelocity = math.huge end
                            if ao then ao.Responsiveness = S.MasslessSense; ao.MaxTorque = math.huge end
                        end
                    end
                end))
            else NN.RemoveConn("Massless") end
        end })
    CombatTab:CreateInput({ Name = "Massless Sense", CurrentValue = "30",
        PlaceholderText = "Enter sense value", RemoveTextAfterFocusLost = false, Flag = "MasslessSense",
        Callback = function(t) local n = tonumber(t); if n and n > 0 then S.MasslessSense = n end end })

    CombatTab:CreateSection("Teleport & Bring")
    CombatTab:CreateToggle({ Name = "Stack Up Mode", CurrentValue = false, Flag = "StackMode",
        Callback = function(v) S.StackMode = v; if not v then releaseAll() end end })
    CombatTab:CreateToggle({ Name = "Loop Bring", CurrentValue = false, Flag = "LoopBring",
        Callback = function(v)
            S.LoopBring = v
            if v then
                NN.Tasks.LoopBring = true
                task.spawn(function()
                    while S.LoopBring and NN.Tasks.LoopBring do
                        bringTargets(collectTargets()); task.wait(S.BringDelay)
                    end
                end)
            else NN.Tasks.LoopBring = false; releaseAll() end
        end })
    CombatTab:CreateDropdown({ Name = "Bring Mode", Options = {"all", "nearby", "whitelist"},
        CurrentOption = {"all"}, Flag = "BringMode",
        Callback = function(o) S.BringMode = type(o) == "table" and o[1] or o end })
    CombatTab:CreateSlider({ Name = "Bring Delay", Range = {0.5, 10}, Increment = 0.1, Suffix = "s",
        CurrentValue = 1, Flag = "BringDelay", Callback = function(v) S.BringDelay = v end })
    CombatTab:CreateButton({ Name = "Bring All (once)", Callback = function() bringTargets(Players:GetPlayers()) end })

    NN.AddConn("TpGrabKey", UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.Y then
            local target = LP:GetMouse().Target
            local plr = target and target.Parent and Players:GetPlayerFromCharacter(target.Parent)
            if plr and plr ~= LP then bringTargets({ plr }) end
        end
    end))

    CombatTab:CreateSection("Loop Fling")
    CombatTab:CreateToggle({ Name = "Loop Fling (all players)", CurrentValue = false, Flag = "LoopFling",
        Callback = function(state)
            S.LoopFling = state; NN.updateFlingTargets()
            if state then spawnFlingDecoy()
            else
                if fling.conn then fling.conn:Disconnect() end
                local destroyToy = NN.remote({"MenuToys", "DestroyToy"})
                if fling.decoy and fling.decoy.Parent and destroyToy then pcall(function() destroyToy:FireServer(fling.decoy) end) end
                fling.decoy, fling.target = nil, nil
            end
        end })
    CombatTab:CreateDropdown({ Name = "Fling Toy", Options = {"DiceBig", "DiceSmall", "YouDecoy", "YouLittle"},
        CurrentOption = {"DiceBig"}, Flag = "FlingToy",
        Callback = function(o) S.SelectedToy = type(o) == "table" and o[1] or o end })

    CombatTab:CreateSection("Persistent Grab-Kill")
    CombatTab:CreateToggle({ Name = "Persistent Grab-Kill (works while dead)", CurrentValue = false, Flag = "GrabKill",
        Callback = function(v)
            S.GrabKill = v
            if v then
                NN.Tasks.GrabKill = true
                task.spawn(function()
                    local destroyToy = NN.remote({"MenuToys", "DestroyToy"})
                    while S.GrabKill and NN.Tasks.GrabKill do
                        for p in pairs(S.MarkedTargets) do
                            if not p.Parent then S.MarkedTargets[p] = nil
                            else p:SetAttribute("NomNomTarget", true) end
                        end
                        -- only delete enemy gucci when WE have no gucci (so we can steal their seat)
                        if S.AutoDeleteKillerGucci and not NN.isGucciActive() then
                            for holder in pairs(findHolders()) do
                                local g = findEnemyGucci(holder)
                                if g and destroyToy then pcall(function() destroyToy:FireServer(g) end) end
                            end
                        end
                        task.wait(0.1)
                    end
                end)
            else NN.Tasks.GrabKill = false end
        end })
    CombatTab:CreateToggle({ Name = "Auto Attack Back (on death)", CurrentValue = false, Flag = "AutoAttackBack",
        Callback = function(v) S.AutoAttackBack = v end })
    CombatTab:CreateToggle({ Name = "Auto Delete Killer's Gucci", CurrentValue = false, Flag = "AutoDeleteKillerGucci",
        Callback = function(v) S.AutoDeleteKillerGucci = v end })
    CombatTab:CreateButton({ Name = "Clear Marked Targets",
        Callback = function()
            for p in pairs(S.MarkedTargets) do if p.Parent then p:SetAttribute("NomNomTarget", S.LoopFling) end end
            S.MarkedTargets = {}; if NN.notify then NN.notify("Marked targets cleared") end
        end })
end

print("[NomNom] Combat module loaded")
return NN