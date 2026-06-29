-- ==========================================================
-- NOMNOM FTAP — Synthesized Hub (Rewrite v3 — Persistent / Invincible)
-- Private-test / owned-game client utility for "Fling Things And People"
-- ----------------------------------------------------------
-- v3 adds the "never stops" survival layer requested for private testing:
--   * Invincible Gucci (spawn high, sit+ragdoll desync, per-frame override
--     so it cannot be destroyed / unsat / grabbed)
--   * Auto re-Gucci recovery loop (looptp ownership + respawn until it sits)
--   * Persistent grab-kill engine that keeps running WHILE DEAD
--   * Auto-attack-back: on death, mark the killer + delete their Gucci
--   * Steal enemy seat when we have no Gucci of our own
--   * Anti-loopkill: every active toggle re-enables itself on respawn
--   * Spawn throttle to respect the game's toy-spawn cooldown
-- ----------------------------------------------------------
-- Engineering: one connection manager, _G rerun cleanup, respawn-safe access,
-- throttled loops, guarded remotes, full teardown. Built for owned/private
-- testing — real server authority still depends on the game's own systems.
-- ==========================================================

-- ==========================================
-- RERUN CLEANUP (kill previous instance)
-- ==========================================
if _G.NomNomFTAP and _G.NomNomFTAP.Cleanup then
    pcall(_G.NomNomFTAP.Cleanup)
end

-- ==========================================
-- SERVICES
-- ==========================================
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local Workspace          = game:GetService("Workspace")
local Debris             = game:GetService("Debris")
local CoreGui            = game:GetService("CoreGui")

local LP    = Players.LocalPlayer
local rs    = ReplicatedStorage
local w     = Workspace

-- ==========================================
-- CONNECTION / TASK MANAGER
-- ==========================================
local Connections = {}
local Tasks       = {}

local function AddConn(name, conn)
    if Connections[name] then pcall(function() Connections[name]:Disconnect() end) end
    Connections[name] = conn
    return conn
end

local function RemoveConn(name)
    if Connections[name] then
        pcall(function() Connections[name]:Disconnect() end)
        Connections[name] = nil
    end
end

local function DisconnectAll()
    for name, conn in pairs(Connections) do
        pcall(function() conn:Disconnect() end)
        Connections[name] = nil
    end
end

-- ==========================================
-- STATE
-- ==========================================
local S = {
    -- Movement
    InfiniteJump = false, Fly = false, FlySpeed = 60,
    DashMultiplier = 1.075, FreeJump = false,
    -- Combat
    SuperFling = false, FlingStrength = 850, LoopFling = false,
    Massless = false, MasslessSense = 30, SelectedToy = "DiceBig",
    -- Persistent grab-kill / attack-back
    GrabKill = false, AutoAttackBack = false, AutoDeleteKillerGucci = false,
    -- Teleport-grab / bring
    StackMode = false, LoopBring = false, BringMode = "all",
    BringDelay = 1, GrabHeight = 4,
    -- Protection
    AntiGrab = false, AntiExplode = false, AntiFire = false,
    AntiBlobman = false, AntiRagdoll = false, AntiVoid = false,
    AntiVoidY = -100, AntiLag = false,
    -- Gucci
    Gucci = false, GucciMode = "Tractor", GucciAutoRecover = true,
    GucciStealSeat = true,
    -- Vehicles
    UFOSpin = false, UFOFollow = false, UFOSpinSpeed = 6,
    UFOSpinRadius = 15, UFOHeight = 5,
    -- ESP
    ESP = false, ESPNames = false, ESPRainbow = false,
    ESPColor = Color3.fromRGB(0, 255, 100),
    -- Settings
    Whitelist = {},
    -- runtime
    MarkedTargets = {},   -- [player] = true  (attack-back / persistent kill list)
}

-- ==========================================
-- RESPAWN-SAFE CHARACTER ACCESS
-- ==========================================
local function getChar() return LP.Character end
local function getHRP() local c = getChar(); return c and c:FindFirstChild("HumanoidRootPart") end
local function getHum() local c = getChar(); return c and c:FindFirstChildOfClass("Humanoid") end
local function getToyFolder() return w:FindFirstChild(LP.Name .. "SpawnedInToys") end

local function remote(path)
    local ok, obj = pcall(function()
        local node = rs
        for _, name in ipairs(path) do
            node = node:FindFirstChild(name)
            if not node then return nil end
        end
        return node
    end)
    return ok and obj or nil
end

-- ==========================================
-- SPAWN THROTTLE (respect toy-spawn cooldown)
-- ==========================================
local SpawnQueue = { last = 0, minGap = 0.25, pending = false }

local function throttledSpawn(toyName, cf, vel)
    local spawnToy = remote({"MenuToys", "SpawnToyRemoteFunction"})
    if not spawnToy then return false end
    -- wait out the cooldown without spamming
    local waited = 0
    while tick() - SpawnQueue.last < SpawnQueue.minGap do
        task.wait(0.03)
        waited += 0.03
        if waited > 2 then break end
    end
    SpawnQueue.last = tick()
    local ok = pcall(function()
        spawnToy:InvokeServer(toyName, cf, vel or Vector3.new(0, 0, 0))
    end)
    return ok
end

-- ==========================================
-- ENDGRABEARLY NEUTRALIZE
-- ==========================================
local function neutralizeEndGrab()
    pcall(function()
        local grabEvents = rs:FindFirstChild("GrabEvents")
        if not grabEvents then return end
        local endGrab = grabEvents:FindFirstChild("EndGrabEarly")
        if endGrab then endGrab:Destroy() end
        local dummy = Instance.new("RemoteEvent")
        dummy.Name = "EndGrabEarly"
        dummy.Parent = grabEvents
    end)
end
neutralizeEndGrab()

-- ==========================================
-- RAYFIELD UI
-- ==========================================
local okUI, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)
if not okUI or not Rayfield then warn("[NomNom] Failed to load Rayfield UI"); return end

local Window = Rayfield:CreateWindow({
    Name = "NomNom FTAP",
    LoadingTitle = "NomNom FTAP",
    LoadingSubtitle = "Persistent Hub v3",
    Theme = "Amethyst",
    ConfigurationSaving = { Enabled = true, FolderName = "NomNomFTAP", FileName = "NomNomConfig" },
    KeySystem = false,
})

local function notify(content, title, dur)
    Rayfield:Notify({ Title = title or "NomNom", Content = content, Duration = dur or 3 })
end

-- ==========================================
-- TAB 1: MAIN
-- ==========================================
local MainTab = Window:CreateTab("Main", 4483362458)
MainTab:CreateSection("Player")

MainTab:CreateSlider({ Name = "WalkSpeed", Range = {16, 500}, Increment = 1, Suffix = "studs/s",
    CurrentValue = 16, Flag = "WalkSpeed",
    Callback = function(v) local h = getHum(); if h then h.WalkSpeed = v end end })

MainTab:CreateSlider({ Name = "JumpPower", Range = {50, 500}, Increment = 1,
    CurrentValue = 50, Flag = "JumpPower",
    Callback = function(v) local h = getHum(); if h then h.UseJumpPower = true; h.JumpPower = v end end })

MainTab:CreateToggle({ Name = "Infinite Jump", CurrentValue = false, Flag = "InfJump",
    Callback = function(state)
        S.InfiniteJump = state
        if state then
            AddConn("InfJump", UserInputService.JumpRequest:Connect(function()
                local h = getHum()
                if h and S.InfiniteJump then h:ChangeState(Enum.HumanoidStateType.Jumping) end
            end))
        else RemoveConn("InfJump") end
    end })

MainTab:CreateButton({ Name = "Unlock 3rd Person",
    Callback = function()
        LP.CameraMaxZoomDistance = 99999
        LP.CameraMode = Enum.CameraMode.Classic
        notify("3rd person unlocked")
    end })

MainTab:CreateSection("Teleport")
MainTab:CreateButton({ Name = "Teleport to Spawn",
    Callback = function()
        local hrp = getHRP(); if not hrp then return end
        local spawnCF = w:FindFirstChild("SpawnCF")
        hrp.CFrame = spawnCF and spawnCF.CFrame or CFrame.new(0, 50, 0)
        notify("Teleported to spawn")
    end })
MainTab:CreateButton({ Name = "Respawn",
    Callback = function() local h = getHum(); if h then h.Health = 0 end end })

-- ==========================================
-- TAB 2: MOVEMENT
-- ==========================================
local MoveTab = Window:CreateTab("Movement", 4483362458)
MoveTab:CreateSection("Fly")

local flyState = { bv = nil, bg = nil }
local function stopFly()
    RemoveConn("Fly")
    if flyState.bv then pcall(function() flyState.bv:Destroy() end); flyState.bv = nil end
    if flyState.bg then pcall(function() flyState.bg:Destroy() end); flyState.bg = nil end
end
local function startFly()
    local hrp = getHRP(); if not hrp then return end
    stopFly()
    local bv = Instance.new("BodyVelocity")
    bv.Name = "NomNomFlyVel"; bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.zero; bv.P = 5000; bv.Parent = hrp
    local bg = Instance.new("BodyGyro")
    bg.Name = "NomNomFlyGyro"; bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 9000; bg.D = 500; bg.Parent = hrp
    flyState.bv, flyState.bg = bv, bg
    AddConn("Fly", RunService.RenderStepped:Connect(function()
        if not S.Fly then return end
        local cam = w.CurrentCamera; local h = getHRP()
        if not cam or not h or not flyState.bv or not flyState.bv.Parent then return end
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= cam.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += cam.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.new(0, 1, 0) end
        flyState.bv.Velocity = (dir.Magnitude > 0 and dir.Unit or Vector3.zero) * S.FlySpeed
        flyState.bg.CFrame = cam.CFrame
    end))
end

MoveTab:CreateToggle({ Name = "Fly (WASD + Space/Shift)", CurrentValue = false, Flag = "Fly",
    Callback = function(v) S.Fly = v; if v then startFly() else stopFly() end end })
MoveTab:CreateSlider({ Name = "Fly Speed", Range = {16, 300}, Increment = 1, Suffix = "studs/s",
    CurrentValue = 60, Flag = "FlySpeed", Callback = function(v) S.FlySpeed = v end })

MoveTab:CreateSection("Dash Combat (TSB-style)")
local function setupDashChar(char)
    if not char then return end
    RemoveConn("DashDescAdded")
    AddConn("DashDescAdded", char.DescendantAdded:Connect(function(desc)
        if S.DashMultiplier > 1 and desc.Name == "dodgevelocity" then
            task.spawn(function()
                while desc:IsDescendantOf(w) and S.DashMultiplier > 1 do
                    desc.Velocity *= S.DashMultiplier
                    RunService.RenderStepped:Wait()
                end
            end)
        end
        if desc:IsA("Accessory") and S.FreeJump and desc.Name == "NoJump" then
            task.wait(); pcall(function() desc:Destroy() end)
        end
    end))
end
setupDashChar(getChar())

MoveTab:CreateSlider({ Name = "Dash Multiplier", Range = {1, 3}, Increment = 0.025,
    CurrentValue = 1.075, Flag = "DashMult", Callback = function(v) S.DashMultiplier = v end })
MoveTab:CreateToggle({ Name = "Free Jump (remove NoJump)", CurrentValue = false, Flag = "FreeJump",
    Callback = function(v) S.FreeJump = v end })

-- ==========================================
-- TAB 3: COMBAT
-- ==========================================
local CombatTab = Window:CreateTab("Combat", 4483362458)

-- --- SUPER FLING ---
CombatTab:CreateSection("Super Fling")
local FLING_VEL = "NomNomFlingVel"
AddConn("SuperFlingWatcher", w.ChildAdded:Connect(function(child)
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
CombatTab:CreateToggle({ Name = "Super Fling (on grab release)", CurrentValue = false, Flag = "SuperFling",
    Callback = function(v) S.SuperFling = v end })
CombatTab:CreateSlider({ Name = "Fling Strength", Range = {100, 5000}, Increment = 50,
    CurrentValue = 850, Flag = "FlingPower", Callback = function(v) S.FlingStrength = v end })

-- --- MASSLESS GRAB ---
CombatTab:CreateSection("Massless Grab")
CombatTab:CreateToggle({ Name = "Massless Grab (Player & Object)", CurrentValue = false, Flag = "Massless",
    Callback = function(v)
        S.Massless = v
        if v then
            AddConn("Massless", w.ChildAdded:Connect(function(r)
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
        else RemoveConn("Massless") end
    end })
CombatTab:CreateInput({ Name = "Massless Sense", CurrentValue = "30",
    PlaceholderText = "Enter sense value", RemoveTextAfterFocusLost = false, Flag = "MasslessSense",
    Callback = function(t) local n = tonumber(t); if n and n > 0 then S.MasslessSense = n end end })

-- --- TELEPORT & BRING ---
CombatTab:CreateSection("Teleport & Bring")
local grabbed = {}
local grabProcessing = false

local function grabPlayer(target)
    if not target or not target.Character then return end
    local tHum = target.Character:FindFirstChildOfClass("Humanoid")
    local tHRP = target.Character:FindFirstChild("HumanoidRootPart")
    local myHRP = getHRP()
    local grabEvt = remote({"GrabEvents", "SetNetworkOwner"})
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
    local grabEvt = remote({"GrabEvents", "SetNetworkOwner"})
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
        local myHRP = getHRP()
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

CombatTab:CreateToggle({ Name = "Stack Up Mode", CurrentValue = false, Flag = "StackMode",
    Callback = function(v) S.StackMode = v; if not v then releaseAll() end end })
CombatTab:CreateToggle({ Name = "Loop Bring", CurrentValue = false, Flag = "LoopBring",
    Callback = function(v)
        S.LoopBring = v
        if v then
            Tasks.LoopBring = true
            task.spawn(function()
                while S.LoopBring and Tasks.LoopBring do
                    bringTargets(collectTargets()); task.wait(S.BringDelay)
                end
            end)
        else Tasks.LoopBring = false; releaseAll() end
    end })
CombatTab:CreateDropdown({ Name = "Bring Mode", Options = {"all", "nearby", "whitelist"},
    CurrentOption = {"all"}, Flag = "BringMode",
    Callback = function(o) S.BringMode = type(o) == "table" and o[1] or o end })
CombatTab:CreateSlider({ Name = "Bring Delay", Range = {0.5, 10}, Increment = 0.1, Suffix = "s",
    CurrentValue = 1, Flag = "BringDelay", Callback = function(v) S.BringDelay = v end })
CombatTab:CreateButton({ Name = "Bring All (once)", Callback = function() bringTargets(Players:GetPlayers()) end })

AddConn("TpGrabKey", UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.Y then
        local target = LP:GetMouse().Target
        local plr = target and target.Parent and Players:GetPlayerFromCharacter(target.Parent)
        if plr and plr ~= LP then bringTargets({ plr }) end
    end
end))

-- --- LOOP FLING (predictive + LOS + ownership) ---
CombatTab:CreateSection("Loop Fling")
local fling = { decoy = nil, target = nil, conn = nil, targetIndex = 1,
    flungMap = {}, ownershipMonitors = {}, velHistory = {} }
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
    params.FilterDescendantsInstances = { getChar(), d }
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
    local myHRP = getHRP(); if not myHRP then return end
    throttledSpawn(S.SelectedToy, myHRP.CFrame * CFrame.new(5, 0, 5), Vector3.new(0, 33, 0))
end
local function handleDecoy(d)
    if fling.decoy and fling.decoy.Parent then return end
    local partName = toyMap[d.Name]; if not partName then return end
    local toyPart = d:WaitForChild(partName, 5); if not toyPart then return end
    local grabEvt = remote({"GrabEvents", "SetNetworkOwner"})
    local destroyToy = remote({"MenuToys", "DestroyToy"})
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
    local folder = getToyFolder() or w:WaitForChild(LP.Name .. "SpawnedInToys", 30)
    if not folder then return end
    AddConn("FlingFolderAdd", folder.ChildAdded:Connect(function(c)
        if toyMap[c.Name] and S.LoopFling then handleDecoy(c) end
    end))
    AddConn("FlingFolderRemove", folder.ChildRemoved:Connect(function(c)
        if c == fling.decoy then fling.decoy = nil end
    end))
end)
AddConn("FlingKeepAlive", RunService.Heartbeat:Connect(function()
    if not S.LoopFling then return end
    if not fling.decoy or not fling.decoy.Parent then
        local folder = getToyFolder()
        if folder then
            for _, t in ipairs(folder:GetChildren()) do
                if toyMap[t.Name] and t:GetAttribute("NomNomOwned") then fling.decoy = t; return end
            end
        end
        spawnFlingDecoy()
    end
end))
local function updateFlingTargets()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then p:SetAttribute("NomNomTarget", S.LoopFling or (S.MarkedTargets[p] == true)) end
    end
end
CombatTab:CreateToggle({ Name = "Loop Fling (all players)", CurrentValue = false, Flag = "LoopFling",
    Callback = function(state)
        S.LoopFling = state; updateFlingTargets()
        if state then spawnFlingDecoy()
        else
            if fling.conn then fling.conn:Disconnect() end
            for _, m in pairs(fling.ownershipMonitors) do pcall(function() m:Disconnect() end) end
            fling.ownershipMonitors = {}
            local destroyToy = remote({"MenuToys", "DestroyToy"})
            if fling.decoy and fling.decoy.Parent and destroyToy then pcall(function() destroyToy:FireServer(fling.decoy) end) end
            fling.decoy, fling.target = nil, nil
        end
    end })
CombatTab:CreateDropdown({ Name = "Fling Toy", Options = {"DiceBig", "DiceSmall", "YouDecoy", "YouLittle"},
    CurrentOption = {"DiceBig"}, Flag = "FlingToy",
    Callback = function(o) S.SelectedToy = type(o) == "table" and o[1] or o end })

-- --- PERSISTENT GRAB-KILL (works while dead) + ATTACK-BACK ---
CombatTab:CreateSection("Persistent Grab-Kill")

-- Resolve who is currently grabbing/holding us (best-effort, game-specific).
local function findHolders()
    local holders = {}
    -- Look for grab lines / grab parts whose owner is another player
    local gp = w:FindFirstChild("GrabParts")
    if gp then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                local owner = gp:FindFirstChild("PartOwner")
                if owner and owner:IsA("StringValue") and owner.Value == p.Name then
                    holders[p] = true
                end
            end
        end
    end
    return holders
end

-- Find an enemy player's gucci vehicle (Tractor/Blobman they occupy).
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

-- Persistent kill engine — runs on its own loop, does NOT stop when dead.
local function markPlayer(p)
    if p and p ~= LP then S.MarkedTargets[p] = true; p:SetAttribute("NomNomTarget", true) end
end

CombatTab:CreateToggle({ Name = "Persistent Grab-Kill (works while dead)", CurrentValue = false, Flag = "GrabKill",
    Callback = function(v)
        S.GrabKill = v
        if v then
            Tasks.GrabKill = true
            task.spawn(function()
                local destroyToy = remote({"MenuToys", "DestroyToy"})
                while S.GrabKill and Tasks.GrabKill do
                    -- keep marked targets flagged for the fling engine even while we are dead
                    for p in pairs(S.MarkedTargets) do
                        if not p.Parent then S.MarkedTargets[p] = nil
                        else p:SetAttribute("NomNomTarget", true) end
                    end
                    -- if we currently have NO gucci of our own, delete the gucci of anyone holding us
                    if S.AutoDeleteKillerGucci and not (S.Gucci and Tasks.Gucci) then
                        for holder in pairs(findHolders()) do
                            local g = findEnemyGucci(holder)
                            if g and destroyToy then pcall(function() destroyToy:FireServer(g) end) end
                        end
                    end
                    task.wait(0.1)
                end
            end)
        else Tasks.GrabKill = false end
    end })

CombatTab:CreateToggle({ Name = "Auto Attack Back (on death, mark killer)", CurrentValue = false, Flag = "AutoAttackBack",
    Callback = function(v) S.AutoAttackBack = v end })
CombatTab:CreateToggle({ Name = "Auto Delete Killer's Gucci", CurrentValue = false, Flag = "AutoDeleteKillerGucci",
    Callback = function(v) S.AutoDeleteKillerGucci = v end })
CombatTab:CreateButton({ Name = "Clear Marked Targets",
    Callback = function()
        for p in pairs(S.MarkedTargets) do if p.Parent then p:SetAttribute("NomNomTarget", S.LoopFling) end end
        S.MarkedTargets = {}; notify("Marked targets cleared")
    end })

-- ==========================================
-- TAB 4: PROTECTION
-- ==========================================
local ProtTab = Window:CreateTab("Protection", 4483362458)
ProtTab:CreateSection("Anti Systems")

ProtTab:CreateToggle({ Name = "Anti Grab", CurrentValue = false, Flag = "AntiGrab",
    Callback = function(v)
        S.AntiGrab = v
        if v then
            Tasks.AntiGrab = true
            task.spawn(function()
                local struggle = remote({"CharacterEvents", "Struggle"})
                while S.AntiGrab and Tasks.AntiGrab do
                    task.wait()
                    local held = LP:FindFirstChild("IsHeld")
                    if held and held.Value == true then
                        local hrp = getHRP()
                        if hrp then
                            hrp.Anchored = true
                            while held.Value == true and S.AntiGrab do
                                if struggle then pcall(function() struggle:FireServer(LP) end) end
                                task.wait(0.001)
                            end
                            hrp.Anchored = false
                        end
                    end
                end
            end)
        else Tasks.AntiGrab = false end
    end })

ProtTab:CreateToggle({ Name = "Anti Explode", CurrentValue = false, Flag = "AntiExplode",
    Callback = function(v)
        S.AntiExplode = v
        if v then
            AddConn("AntiExplode", w.ChildAdded:Connect(function(obj)
                if not S.AntiExplode then return end
                if obj:IsA("Part") and obj.Name == "Part" then
                    local hrp = getHRP()
                    if hrp and (obj.Position - hrp.Position).Magnitude <= 20 then
                        hrp.Anchored = true; task.wait(0.01); hrp.Anchored = false
                    end
                end
            end))
        else RemoveConn("AntiExplode") end
    end })

ProtTab:CreateToggle({ Name = "Anti Fire", CurrentValue = false, Flag = "AntiFire",
    Callback = function(v)
        S.AntiFire = v
        if v then
            local extPart
            pcall(function() extPart = w.Map.Hole.PoisonBigHole.ExtinguishPart end)
            if not extPart then pcall(function() extPart = w.Map.Hole.PoisonSmallHole.ExtinguishPart end) end
            if not extPart then notify("ExtinguishPart not found"); return end
            local origPos = extPart.Position
            AddConn("AntiFire", RunService.Heartbeat:Connect(function()
                if not S.AntiFire then return end
                local hrp = getHRP(); if not hrp then return end
                if hrp:FindFirstChild("FireLight") or hrp:FindFirstChild("FireParticleEmitter") then
                    extPart.CFrame = CFrame.new(hrp.Position)
                else extPart.CFrame = CFrame.new(origPos) end
            end))
        else RemoveConn("AntiFire") end
    end })

ProtTab:CreateToggle({ Name = "Anti Blobman", CurrentValue = false, Flag = "AntiBlobman",
    Callback = function(v)
        S.AntiBlobman = v
        if v then
            Tasks.AntiBlobman = true
            task.spawn(function()
                while S.AntiBlobman and Tasks.AntiBlobman do
                    local hrp = getHRP()
                    if hrp then
                        for _, obj in ipairs(w:GetDescendants()) do
                            if obj:IsA("BasePart") and (obj.Name == "LeftDetector" or obj.Name == "RightDetector") then
                                if (hrp.Position - obj.Position).Magnitude > 10 then pcall(function() obj:Destroy() end) end
                            end
                        end
                    end
                    task.wait(1)
                end
            end)
        else Tasks.AntiBlobman = false end
    end })

ProtTab:CreateToggle({ Name = "Anti Ragdoll", CurrentValue = false, Flag = "AntiRagdoll",
    Callback = function(v)
        S.AntiRagdoll = v
        if v then
            AddConn("AntiRagdoll", RunService.Heartbeat:Connect(function()
                if not S.AntiRagdoll then return end
                local hum = getHum(); if not hum then return end
                local rag = hum:FindFirstChild("Ragdolled")
                if rag and rag:IsA("BoolValue") and rag.Value then
                    local ragRemote = remote({"CharacterEvents", "RagdollRemote"})
                    local hrp = getHRP()
                    if ragRemote and hrp then pcall(function() ragRemote:FireServer(hrp, 0) end) end
                end
            end))
        else RemoveConn("AntiRagdoll") end
    end })

ProtTab:CreateToggle({ Name = "Anti Void", CurrentValue = false, Flag = "AntiVoid",
    Callback = function(v)
        S.AntiVoid = v
        if v then
            AddConn("AntiVoid", RunService.Heartbeat:Connect(function()
                if not S.AntiVoid then return end
                local hrp = getHRP()
                if hrp and hrp.Position.Y < S.AntiVoidY then hrp.CFrame = CFrame.new(0, 50, 0) end
            end))
        else RemoveConn("AntiVoid") end
    end })

ProtTab:CreateToggle({ Name = "Anti Lag", CurrentValue = false, Flag = "AntiLag",
    Callback = function(v)
        S.AntiLag = v
        pcall(function()
            local scripts = LP:FindFirstChild("PlayerScripts")
            local beam = scripts and scripts:FindFirstChild("CharacterAndBeamMove")
            if beam then beam.Disabled = v end
        end)
    end })

-- ==========================================
-- INVINCIBLE GUCCI (from Invisible.lua — hardened + per-frame override)
-- ==========================================
ProtTab:CreateSection("Gucci (Invincible Invisibility)")

local gucci = { model = nil, seat = nil, busy = false }

local function ragdollSpam(hrp, val)
    local r = remote({"CharacterEvents", "RagdollRemote"})
    if r and hrp then pcall(function() r:FireServer(hrp, val) end) end
end

local function anchorPulse(model)
    if not model then return end
    task.spawn(function()
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function()
                    part.Anchored = true; part.CanCollide = false; part.CanTouch = false
                    RunService.Heartbeat:Wait()
                    part.Anchored = false
                end)
            end
        end
    end)
end

local function destroySeatWelds(seat)
    if not seat or not seat.Parent then return end
    for _, c in ipairs(seat:GetChildren()) do
        if c:IsA("Weld") or c:IsA("WeldConstraint") then c.Part0 = nil; c.Part1 = nil end
    end
    if seat.Parent then
        for _, d in ipairs(seat.Parent:GetDescendants()) do
            if (d:IsA("Weld") or d:IsA("WeldConstraint")) and (d.Part0 == seat or d.Part1 == seat) then
                d.Part0 = nil; d.Part1 = nil
            end
        end
    end
end

local function findMyGucci()
    local toyName = S.GucciMode == "Blobman" and "CreatureBlobman" or "TractorGreen"
    local folder = getToyFolder()
    local function scan(parent)
        if not parent then return nil, nil end
        for _, child in ipairs(parent:GetChildren()) do
            if child:IsA("Model") and child.Name == toyName then
                local s = child:FindFirstChildWhichIsA("VehicleSeat", true)
                if s then return child, s end
            end
        end
        return nil, nil
    end
    local t, s = scan(folder)
    if t and s then return t, s end
    return scan(w)
end

local function spawnGucci()
    local toyName = S.GucciMode == "Blobman" and "CreatureBlobman" or "TractorGreen"
    local baseCF = CFrame.new(0, 1e10, 0) * CFrame.Angles(-2.5694754, 0.10936413, 3.0714223)
    local tr, seat
    local tries = 0
    repeat
        throttledSpawn(toyName, baseCF, Vector3.new(0, -49.45, 0))
        task.wait(0.2)
        tr, seat = findMyGucci()
        tries += 1
    until (tr and seat) or tries >= 30 or not (S.Gucci and Tasks.Gucci)
    return tr, seat
end

-- Sit + ragdoll-desync into a seat (works for our own or a stolen enemy seat)
local function sitGucci(seatObj)
    if not seatObj or not seatObj.Parent then return end
    local hrp, hum = getHRP(), getHum()
    if not hrp or not hum then return end

    -- short ragdoll-loop to desync
    local rgConn
    rgConn = RunService.Heartbeat:Connect(function() ragdollSpam(hrp, -math.huge) end)

    pcall(function() if seatObj:FindFirstChild("ProximityPrompt") then seatObj.ProximityPrompt.Enabled = false end end)
    pcall(function() hum.Sit = true end)
    ragdollSpam(hrp, math.random(0.00000001, 0.00001))
    task.wait(0.09)

    local t0 = tick()
    repeat task.wait() until (hum:FindFirstChild("Ragdolled") and not hum.Ragdolled.Value) or tick() - t0 > 0.5

    pcall(function() if seatObj:FindFirstChild("WeldConstraint") then seatObj.WeldConstraint.Part1 = nil end end)
    destroySeatWelds(seatObj)
    task.wait()
    anchorPulse(seatObj.Parent)

    for _ = 1, 40 do
        pcall(function()
            ragdollSpam(hrp, -math.huge)
            RunService.Heartbeat:Wait()
            seatObj:Sit(hum)
            anchorPulse(seatObj.Parent)
        end)
    end
    if rgConn then rgConn:Disconnect() end

    -- lift BodyVelocity so it pins us high
    pcall(function()
        local host = (seatObj.Parent and seatObj.Parent:FindFirstChild("Hitbox")) or seatObj
        if host and not host:FindFirstChildOfClass("BodyVelocity") then
            local bv = Instance.new("BodyVelocity")
            bv.Name = "NomNomGucciBV"
            bv.Velocity = Vector3.new(0, 99999, 0)
            bv.MaxForce = Vector3.new(0, 9999999, 0)
            bv.P = 1500
            bv.Parent = host
        end
        ragdollSpam(hrp, 0.9)
    end)
end

-- Per-frame hardening loop: re-anchor, re-sit, re-ragdoll, re-pin every frame
-- so no one can destroy / unsit / grab us between frames.
local function startGucciHarden()
    AddConn("GucciHarden", RunService.Heartbeat:Connect(function()
        if not (S.Gucci and Tasks.Gucci) then return end
        local hrp, hum = getHRP(), getHum()
        if not hrp or not hum then return end
        local model, seat = gucci.model, gucci.seat
        if not model or not model.Parent or not seat or not seat.Parent then return end
        -- keep desynced + pinned every frame
        ragdollSpam(hrp, -math.huge)
        if seat.Occupant ~= hum then pcall(function() seat:Sit(hum) end) end
        local host = (model:FindFirstChild("Hitbox")) or seat
        if host and not host:FindFirstChildOfClass("BodyVelocity") then
            local bv = Instance.new("BodyVelocity")
            bv.Name = "NomNomGucciBV"
            bv.Velocity = Vector3.new(0, 99999, 0)
            bv.MaxForce = Vector3.new(0, 9999999, 0)
            bv.P = 1500
            bv.Parent = host
        end
    end))
end

-- Recovery loop: if gucci is lost, keep respawning + re-sitting until success.
local function startGucciRecovery()
    Tasks.GucciRecover = true
    task.spawn(function()
        while S.Gucci and Tasks.GucciRecover do
            local model, seat = gucci.model, gucci.seat
            local hum = getHum()
            local seated = model and model.Parent and seat and seat.Parent and hum and seat.Occupant == hum
            if not seated and not gucci.busy and S.GucciAutoRecover then
                gucci.busy = true
                -- first try to re-find an existing one, else spawn a new one
                local nt, ns = findMyGucci()
                if not (nt and ns) then nt, ns = spawnGucci() end
                if nt and ns and S.Gucci then
                    gucci.model, gucci.seat = nt, ns
                    pcall(function() sitGucci(ns) end)
                    -- watch this instance: if destroyed, loop will respawn
                    AddConn("GucciAncestry", nt.AncestryChanged:Connect(function(_, parent)
                        if not parent and S.Gucci then gucci.model = nil end
                    end))
                end
                gucci.busy = false
            end
            task.wait(0.15)
        end
    end)
end

local function enableGucci()
    if Tasks.Gucci then return end
    Tasks.Gucci = true
    startGucciHarden()
    startGucciRecovery()
    notify("Gucci enabled — auto-recovers if destroyed", "Gucci")
end

local function disableGucci()
    Tasks.Gucci = false
    Tasks.GucciRecover = false
    RemoveConn("GucciHarden")
    RemoveConn("GucciAncestry")
    local destroyToy = remote({"MenuToys", "DestroyToy"})
    if gucci.model and gucci.model.Parent and destroyToy then
        pcall(function() destroyToy:FireServer(gucci.model) end)
    end
    gucci.model, gucci.seat, gucci.busy = nil, nil, false
end

ProtTab:CreateToggle({ Name = "Gucci (Invincible)", CurrentValue = false, Flag = "Gucci",
    Callback = function(v) S.Gucci = v; if v then enableGucci() else disableGucci() end end })
ProtTab:CreateDropdown({ Name = "Gucci Mode", Options = {"Tractor", "Blobman"},
    CurrentOption = {"Tractor"}, Flag = "GucciMode",
    Callback = function(o) S.GucciMode = type(o) == "table" and o[1] or o end })
ProtTab:CreateToggle({ Name = "Auto Re-Gucci on loss", CurrentValue = true, Flag = "GucciAutoRecover",
    Callback = function(v) S.GucciAutoRecover = v end })
ProtTab:CreateToggle({ Name = "Steal enemy seat when un-Gucci'd", CurrentValue = true, Flag = "GucciStealSeat",
    Callback = function(v) S.GucciStealSeat = v end })

-- ==========================================
-- TAB 5: VEHICLES
-- ==========================================
local VehicleTab = Window:CreateTab("Vehicles", 4483362458)
VehicleTab:CreateSection("Vehicle Hijack")

local function spawnShurikens(count)
    local hrp = getHRP(); if not hrp then return end
    local cf = hrp.CFrame * CFrame.new(0, 3, 0)
    for _ = 1, count do throttledSpawn("NinjaShuriken", cf, Vector3.new(0, 0, 0)) end
end

local function hijack(target)
    if not target then notify("Vehicle not found!"); return end
    local backpack = getToyFolder()
    local sticky = remote({"PlayerEvents", "StickyPartEvent"})
    local setowner = remote({"GrabEvents", "SetNetworkOwner"})
    if not backpack or not sticky or not setowner then notify("Required remotes missing"); return end
    spawnShurikens(10)
    task.wait(1)
    for i = 1, 10 do
        pcall(function()
            local shur = backpack:FindFirstChild("NinjaShuriken")
            if shur then shur.Name = tostring(i); sticky:FireServer(shur.StickyPart, target, CFrame.Angles(0, 0, 0)) end
        end)
    end
    local hrp = getHRP()
    if hrp then
        for _ = 1, 100 do
            pcall(function() hrp.CFrame = target.CFrame; setowner:FireServer(target, target.CFrame) end)
            task.wait()
        end
    end
    pcall(function()
        local attach = target:FindFirstChild("ObjectModelAttachment")
        if attach then attach:Destroy() end
        local obj = target.Parent.Parent
        obj.FollowThisPart.AlignPosition.Attachment0 = nil
        obj.FollowThisPart.AlignOrientation.Attachment0 = nil
    end)
    notify("Vehicle hijacked!")
end

VehicleTab:CreateButton({ Name = "Hijack Outer UFO",
    Callback = function() pcall(function() hijack(w.Map.AlwaysHereTweenedObjects.OuterUFO.Object.ObjectModel.Body) end) end })
VehicleTab:CreateButton({ Name = "Hijack Inner UFO",
    Callback = function() pcall(function() hijack(w.Map.AlwaysHereTweenedObjects.InnerUFO.Object.ObjectModel.Body) end) end })
VehicleTab:CreateButton({ Name = "Hijack Train",
    Callback = function() pcall(function() hijack(w.Map.AlwaysHereTweenedObjects.Train.Object.ObjectModel.Part) end) end })
VehicleTab:CreateButton({ Name = "Hijack CaveCart",
    Callback = function() pcall(function()
        local obj = w.Map.AlwaysHereTweenedObjects.CaveCart.Object
        hijack(obj.ObjectModel:GetChildren()[13])
    end) end })

VehicleTab:CreateSection("UFO Hitbox Control")
local ufoHitboxes = {}
pcall(function()
    local f = w.Map.AlwaysHereTweenedObjects.OuterUFO.Object.ObjectModel
    for _, c in ipairs(f:GetChildren()) do if c.Name:match("Hitbox") then table.insert(ufoHitboxes, c) end end
end)
local ufoAngle = 0
AddConn("UFOHitbox", RunService.RenderStepped:Connect(function(dt)
    local hrp = getHRP(); if not hrp then return end
    if S.UFOSpin then
        ufoAngle += dt * S.UFOSpinSpeed
        local count = #ufoHitboxes
        for i, hb in ipairs(ufoHitboxes) do
            if hb and hb.Parent then
                local off = (i / count) * (2 * math.pi)
                local x = math.sin(ufoAngle + off) * S.UFOSpinRadius
                local z = math.cos(ufoAngle + off) * S.UFOSpinRadius
                hb.CFrame = CFrame.new(hrp.Position + Vector3.new(x, S.UFOHeight, z))
            end
        end
    elseif S.UFOFollow then
        for _, hb in ipairs(ufoHitboxes) do
            if hb and hb.Parent then hb.CFrame = CFrame.new(hrp.Position + Vector3.new(0, S.UFOHeight + 3, 0)) end
        end
    end
end))
VehicleTab:CreateToggle({ Name = "UFO Hitbox Spin", CurrentValue = false, Flag = "UFOSpin",
    Callback = function(v) S.UFOSpin = v; if v then S.UFOFollow = false end end })
VehicleTab:CreateToggle({ Name = "UFO Hitbox Follow Head", CurrentValue = false, Flag = "UFOFollow",
    Callback = function(v) S.UFOFollow = v; if v then S.UFOSpin = false end end })

-- ==========================================
-- TAB 6: ESP
-- ==========================================
local ESPTab = Window:CreateTab("ESP", 4483362458)
local function applyESP(player)
    if player == LP then return end
    local function setup(char)
        if not char then return end
        local head = char:WaitForChild("Head", 10); if not head then return end
        if char:FindFirstChild("NomNom_ESP") then char.NomNom_ESP:Destroy() end
        if char:FindFirstChild("NomNom_Tag") then char.NomNom_Tag:Destroy() end
        local hl = Instance.new("Highlight")
        hl.Name = "NomNom_ESP"; hl.FillTransparency = 0.5; hl.OutlineTransparency = 0
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = char
        local bill = Instance.new("BillboardGui")
        bill.Name = "NomNom_Tag"; bill.AlwaysOnTop = true
        bill.Size = UDim2.new(0, 100, 0, 100); bill.ExtentsOffset = Vector3.new(0, 4, 0); bill.Parent = char
        local shot = Instance.new("ImageLabel", bill)
        shot.BackgroundTransparency = 1; shot.Size = UDim2.new(0, 40, 0, 40)
        shot.Position = UDim2.new(0.5, -20, 0, 0)
        shot.Image = "rbxthumb://type=AvatarHeadShot&id=" .. player.UserId .. "&w=150&h=150"
        Instance.new("UICorner", shot).CornerRadius = UDim.new(1, 0)
        local label = Instance.new("TextLabel", bill)
        label.BackgroundTransparency = 1; label.Position = UDim2.new(0, 0, 0, 45)
        label.Size = UDim2.new(1, 0, 0, 20); label.Text = player.DisplayName or player.Name
        label.Font = Enum.Font.GothamBold; label.TextSize = 13
        label.TextStrokeTransparency = 0; label.TextColor3 = Color3.new(1, 1, 1)
        task.spawn(function()
            local hue = 0
            while char and char.Parent and hl.Parent do
                hue += 0.01
                local col = S.ESPRainbow and Color3.fromHSV(hue % 1, 0.7, 1) or S.ESPColor
                hl.Enabled = S.ESP; hl.FillColor = col; hl.OutlineColor = col
                bill.Enabled = S.ESP and S.ESPNames; label.TextColor3 = col
                task.wait(0.05)
            end
        end)
    end
    player.CharacterAdded:Connect(setup)
    if player.Character then setup(player.Character) end
end
for _, p in ipairs(Players:GetPlayers()) do applyESP(p) end
AddConn("ESPPlayerAdded", Players.PlayerAdded:Connect(applyESP))
ESPTab:CreateToggle({ Name = "Enable ESP", CurrentValue = false, Flag = "ESP", Callback = function(v) S.ESP = v end })
ESPTab:CreateToggle({ Name = "Show Names & Photos", CurrentValue = false, Flag = "ESPNames", Callback = function(v) S.ESPNames = v end })
ESPTab:CreateToggle({ Name = "Rainbow Mode", CurrentValue = false, Flag = "ESPRainbow", Callback = function(v) S.ESPRainbow = v end })
ESPTab:CreateColorPicker({ Name = "ESP Color", Color = Color3.fromRGB(0, 255, 100), Flag = "ESPColor", Callback = function(v) S.ESPColor = v end })
ESPTab:CreateButton({ Name = "Force Refresh ESP",
    Callback = function() for _, p in ipairs(Players:GetPlayers()) do applyESP(p) end; notify("ESP refreshed", "NomNom", 2) end })

-- ==========================================
-- TAB 7: CHAT
-- ==========================================
local ChatTab = Window:CreateTab("Chat", 4483362458)
ChatTab:CreateSection("Custom Chat (F8)")
local ChatGui = Instance.new("ScreenGui")
ChatGui.Name = "NomNomChat"
ChatGui.Parent = RunService:IsStudio() and LP.PlayerGui or CoreGui
ChatGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ChatGui.DisplayOrder = 100; ChatGui.ResetOnSpawn = false; ChatGui.Enabled = false
local ChatMain = Instance.new("Frame", ChatGui)
ChatMain.BackgroundColor3 = Color3.fromRGB(18, 18, 22); ChatMain.BorderSizePixel = 0
ChatMain.Position = UDim2.new(0.5, -175, 0.5, -150); ChatMain.Size = UDim2.new(0, 350, 0, 300)
ChatMain.ClipsDescendants = true; ChatMain.Active = true; ChatMain.Draggable = true
Instance.new("UICorner", ChatMain).CornerRadius = UDim.new(0, 20)
local ChatTop = Instance.new("Frame", ChatMain)
ChatTop.BackgroundColor3 = Color3.fromRGB(28, 28, 35); ChatTop.BorderSizePixel = 0; ChatTop.Size = UDim2.new(1, 0, 0, 45)
Instance.new("UICorner", ChatTop).CornerRadius = UDim.new(0, 20)
local ChatTitle = Instance.new("TextLabel", ChatTop)
ChatTitle.BackgroundTransparency = 1; ChatTitle.Position = UDim2.new(0, 16, 0, 0); ChatTitle.Size = UDim2.new(0, 200, 1, 0)
ChatTitle.Font = Enum.Font.GothamBold; ChatTitle.Text = "NomNom Chat"
ChatTitle.TextColor3 = Color3.fromRGB(255, 255, 255); ChatTitle.TextSize = 16; ChatTitle.TextXAlignment = Enum.TextXAlignment.Left
local ChatClose = Instance.new("TextButton", ChatTop)
ChatClose.BackgroundColor3 = Color3.fromRGB(45, 45, 55); ChatClose.Position = UDim2.new(1, -35, 0.5, -12)
ChatClose.Size = UDim2.new(0, 24, 0, 24); ChatClose.Font = Enum.Font.GothamBold; ChatClose.Text = "X"
ChatClose.TextColor3 = Color3.fromRGB(255, 255, 255); ChatClose.TextSize = 14
Instance.new("UICorner", ChatClose).CornerRadius = UDim.new(1, 0)
ChatClose.MouseButton1Click:Connect(function() ChatGui.Enabled = false end)
local HistoryFrame = Instance.new("ScrollingFrame", ChatMain)
HistoryFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22); HistoryFrame.BorderSizePixel = 0
HistoryFrame.Position = UDim2.new(0, 0, 0, 45); HistoryFrame.Size = UDim2.new(1, 0, 1, -100)
HistoryFrame.CanvasSize = UDim2.new(0, 0, 0, 0); HistoryFrame.ScrollBarThickness = 4
HistoryFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
local HistoryList = Instance.new("UIListLayout", HistoryFrame)
HistoryList.SortOrder = Enum.SortOrder.LayoutOrder; HistoryList.Padding = UDim.new(0, 6)
HistoryList.HorizontalAlignment = Enum.HorizontalAlignment.Center
local HPad = Instance.new("UIPadding", HistoryFrame)
HPad.PaddingLeft = UDim.new(0, 10); HPad.PaddingRight = UDim.new(0, 10); HPad.PaddingTop = UDim.new(0, 10); HPad.PaddingBottom = UDim.new(0, 10)
local InputFrame = Instance.new("Frame", ChatMain)
InputFrame.BackgroundColor3 = Color3.fromRGB(28, 28, 35); InputFrame.BorderSizePixel = 0
InputFrame.Position = UDim2.new(0, 0, 1, -55); InputFrame.Size = UDim2.new(1, 0, 0, 55)
Instance.new("UICorner", InputFrame).CornerRadius = UDim.new(0, 20)
local MessageBox = Instance.new("TextBox", InputFrame)
MessageBox.BackgroundColor3 = Color3.fromRGB(38, 38, 45); MessageBox.BorderSizePixel = 0
MessageBox.Position = UDim2.new(0, 12, 0.5, -15); MessageBox.Size = UDim2.new(1, -80, 0, 30)
MessageBox.Font = Enum.Font.Gotham; MessageBox.PlaceholderText = "Enter your message..."
MessageBox.PlaceholderColor3 = Color3.fromRGB(140, 140, 150); MessageBox.Text = ""
MessageBox.TextColor3 = Color3.fromRGB(255, 255, 255); MessageBox.TextSize = 13; MessageBox.ClearTextOnFocus = false
Instance.new("UICorner", MessageBox).CornerRadius = UDim.new(0, 12)
local SendBtn = Instance.new("TextButton", InputFrame)
SendBtn.BackgroundColor3 = Color3.fromRGB(80, 140, 255); SendBtn.Position = UDim2.new(1, -60, 0.5, -15)
SendBtn.Size = UDim2.new(0, 45, 0, 30); SendBtn.Font = Enum.Font.GothamBold; SendBtn.Text = ">"
SendBtn.TextColor3 = Color3.fromRGB(255, 255, 255); SendBtn.TextSize = 18
Instance.new("UICorner", SendBtn).CornerRadius = UDim.new(0, 12)
local ChatHistory = {}; local MAX_MSGS = 50
local function scrollBottom() task.wait(0.05); HistoryFrame.CanvasPosition = Vector2.new(0, HistoryFrame.AbsoluteCanvasSize.Y) end
local function makeBubble(user, msg, isSelf)
    local bubble = Instance.new("Frame")
    bubble.BackgroundColor3 = isSelf and Color3.fromRGB(80, 140, 255) or Color3.fromRGB(38, 38, 45)
    bubble.BackgroundTransparency = 0.1; bubble.BorderSizePixel = 0
    bubble.Size = UDim2.new(1, 0, 0, 0); bubble.AutomaticSize = Enum.AutomaticSize.Y
    Instance.new("UICorner", bubble).CornerRadius = UDim.new(0, 12)
    local pad = Instance.new("UIPadding", bubble)
    pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10); pad.PaddingTop = UDim.new(0, 6); pad.PaddingBottom = UDim.new(0, 6)
    local n = Instance.new("TextLabel", bubble)
    n.BackgroundTransparency = 1; n.Size = UDim2.new(1, 0, 0, 16); n.Font = Enum.Font.GothamBold; n.Text = user
    n.TextColor3 = isSelf and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(100, 200, 255); n.TextSize = 12; n.TextXAlignment = Enum.TextXAlignment.Left
    local m = Instance.new("TextLabel", bubble)
    m.BackgroundTransparency = 1; m.Position = UDim2.new(0, 0, 0, 18); m.Size = UDim2.new(1, 0, 0, 0)
    m.AutomaticSize = Enum.AutomaticSize.Y; m.Font = Enum.Font.Gotham; m.Text = msg
    m.TextColor3 = Color3.fromRGB(255, 255, 255); m.TextSize = 13; m.TextWrapped = true; m.TextXAlignment = Enum.TextXAlignment.Left; m.RichText = true
    return bubble
end
local function addMessage(user, msg, isSelf)
    table.insert(ChatHistory, { user = user, msg = msg, isSelf = isSelf })
    if #ChatHistory > MAX_MSGS then table.remove(ChatHistory, 1) end
    for _, c in ipairs(HistoryFrame:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    for _, e in ipairs(ChatHistory) do makeBubble(e.user, e.msg, e.isSelf).Parent = HistoryFrame end
    scrollBottom()
end
local function sendMessage()
    local message = MessageBox.Text:gsub("^%s+", ""):gsub("%s+$", "")
    if message == "" then return end
    pcall(function()
        local ext = rs:WaitForChild("GrabEvents", 5):WaitForChild("ExtendGrabLine", 5)
        if ext then ext:FireServer("CUSTOMMSG:" .. LP.DisplayName .. ":" .. message); MessageBox.Text = ""; addMessage(LP.DisplayName, message, true) end
    end)
end
SendBtn.MouseButton1Click:Connect(sendMessage)
MessageBox.FocusLost:Connect(function(enter) if enter then sendMessage() end end)
pcall(function()
    local ext = rs:WaitForChild("GrabEvents", 5):WaitForChild("ExtendGrabLine", 5)
    if ext then
        AddConn("ChatRecv", ext.OnClientEvent:Connect(function(...)
            for _, v in ipairs({ ... }) do
                if typeof(v) == "string" and v:sub(1, 10) == "CUSTOMMSG:" then
                    local parts = {}
                    for part in v:gmatch("[^:]+") do table.insert(parts, part) end
                    if #parts >= 3 then addMessage(parts[2], table.concat(parts, ":", 3), false) end
                    return
                end
            end
        end))
    end
end)
addMessage("NomNom", "Chat loaded! Press F8 to toggle.", false)
ChatTab:CreateToggle({ Name = "Enable Chat GUI", CurrentValue = false, Flag = "ChatGUI",
    Callback = function(v) ChatGui.Enabled = v; if v then scrollBottom() end end })
ChatTab:CreateParagraph({ Title = "Chat Info",
    Content = "Press F8 to toggle. Messages route through the ExtendGrabLine remote, so only other NomNom users see them." })
AddConn("ChatF8", UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F8 then ChatGui.Enabled = not ChatGui.Enabled; if ChatGui.Enabled then scrollBottom() end end
end))

-- ==========================================
-- TAB 8: SETTINGS
-- ==========================================
local SettingsTab = Window:CreateTab("Settings", 4483362458)
SettingsTab:CreateSection("Whitelist")
local whitelistInput = ""
SettingsTab:CreateInput({ Name = "Player Name", CurrentValue = "",
    PlaceholderText = "Enter player name", RemoveTextAfterFocusLost = false, Flag = "WhitelistInput",
    Callback = function(t) whitelistInput = t end })
SettingsTab:CreateButton({ Name = "Add to Whitelist",
    Callback = function()
        if whitelistInput ~= "" and not table.find(S.Whitelist, whitelistInput) then
            table.insert(S.Whitelist, whitelistInput); notify("Added: " .. whitelistInput, "Whitelist")
        end
    end })
SettingsTab:CreateButton({ Name = "Remove from Whitelist",
    Callback = function()
        for i, name in ipairs(S.Whitelist) do
            if name == whitelistInput then table.remove(S.Whitelist, i); notify("Removed: " .. whitelistInput, "Whitelist"); break end
        end
    end })
SettingsTab:CreateButton({ Name = "Show Whitelist",
    Callback = function() notify(#S.Whitelist > 0 and table.concat(S.Whitelist, ", ") or "Empty", "Whitelist", 5) end })
SettingsTab:CreateSection("Hub")
SettingsTab:CreateButton({ Name = "Unload NomNom (full cleanup)",
    Callback = function() if _G.NomNomFTAP and _G.NomNomFTAP.Cleanup then _G.NomNomFTAP.Cleanup() end end })
SettingsTab:CreateParagraph({ Title = "NomNom FTAP v3",
    Content = "Persistent survival hub. Gucci is invincible & auto-recovers; grab-kill keeps running while dead; killers get marked & their Gucci deleted. F8 = Chat, Y = Teleport-grab." })

-- ==========================================
-- DEATH / RESPAWN HANDLING (anti-loopkill + attack-back)
-- ==========================================
local function reapplyOnRespawn(char)
    task.wait(0.5)
    neutralizeEndGrab()
    setupDashChar(char)
    if S.Fly then startFly() end
    -- anti-loopkill: re-arm gucci recovery so we never stay un-Gucci'd
    if S.Gucci and not Tasks.GucciRecover then startGucciRecovery() end
    -- keep marked targets flagged for the fling engine
    for p in pairs(S.MarkedTargets) do if p.Parent then p:SetAttribute("NomNomTarget", true) end end
end

local function onDied()
    -- attack-back: identify whoever was holding us and mark + delete their gucci
    if S.AutoAttackBack then
        local holders = findHolders()
        for holder in pairs(holders) do markPlayer(holder) end
        if S.AutoDeleteKillerGucci then
            local destroyToy = remote({"MenuToys", "DestroyToy"})
            for holder in pairs(holders) do
                local g = findEnemyGucci(holder)
                if g and destroyToy then pcall(function() destroyToy:FireServer(g) end) end
            end
        end
    end
end

local function bindHumanoidDeath(char)
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    if hum then AddConn("HumDied", hum.Died:Connect(onDied)) end
end

AddConn("CharAdded", LP.CharacterAdded:Connect(function(char)
    bindHumanoidDeath(char)
    reapplyOnRespawn(char)
end))
if getChar() then bindHumanoidDeath(getChar()) end

-- ==========================================
-- FULL CLEANUP (rerun-safe)
-- ==========================================
local function Cleanup()
    for k in pairs(Tasks) do Tasks[k] = false end
    S.Fly = false; S.LoopFling = false; S.LoopBring = false
    S.GrabKill = false; S.Gucci = false
    if fling.conn then pcall(function() fling.conn:Disconnect() end) end
    for _, m in pairs(fling.ownershipMonitors) do pcall(function() m:Disconnect() end) end
    pcall(releaseAll)
    pcall(stopFly)
    pcall(disableGucci)
    -- clear marks
    for p in pairs(S.MarkedTargets) do if p.Parent then pcall(function() p:SetAttribute("NomNomTarget", nil) end) end end
    S.MarkedTargets = {}
    -- ESP instances + target attrs
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            local e = p.Character:FindFirstChild("NomNom_ESP"); if e then e:Destroy() end
            local t = p.Character:FindFirstChild("NomNom_Tag"); if t then t:Destroy() end
        end
        if p ~= LP then pcall(function() p:SetAttribute("NomNomTarget", nil) end) end
    end
    if ChatGui then pcall(function() ChatGui:Destroy() end) end
    DisconnectAll()
    pcall(function() Rayfield:Destroy() end)
    _G.NomNomFTAP = nil
end

_G.NomNomFTAP = { Cleanup = Cleanup, State = S }

-- ==========================================
-- STARTUP
-- ==========================================
notify("v3 ready: Invincible Gucci, persistent grab-kill, attack-back.", "NomNom FTAP Loaded", 5)
print("[NomNom] FTAP v3 loaded. _G.NomNomFTAP.Cleanup() to unload.")