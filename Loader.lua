-- ==========================================================
-- NomNom FTAP / Loader
-- Loads the Core + feature modules from the repo, builds the
-- Rayfield UI, wires death/respawn (anti-loopkill + attack-back),
-- and registers full cleanup.
-- ----------------------------------------------------------
-- Run this in your executor:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/NomNomNemNie/NomNomFTAP/main/Loader.lua"))()
-- For a single-file (no extra fetches) build, use NomNom.lua instead.
-- ==========================================================

-- rerun cleanup
if _G.NomNomFTAP and _G.NomNomFTAP.Cleanup then pcall(_G.NomNomFTAP.Cleanup) end

local BASE = "https://raw.githubusercontent.com/NomNomNemNie/NomNomFTAP/main/modules/"

local function loadModule(name)
    local ok, src = pcall(function() return game:HttpGet(BASE .. name .. ".lua") end)
    if not ok or not src then warn("[NomNom] failed to fetch module " .. name); return false end
    local fn, err = loadstring(src)
    if not fn then warn("[NomNom] compile error in " .. name .. ": " .. tostring(err)); return false end
    local ok2, ret = pcall(fn)
    if not ok2 then warn("[NomNom] runtime error in " .. name .. ": " .. tostring(ret)); return false end
    return true
end

-- Core must load first (publishes _G.NomNom)
if not loadModule("Core") then return end
loadModule("Gucci")
loadModule("Combat")
loadModule("Protection")
loadModule("Misc")

local NN = _G.NomNom
if not NN then warn("[NomNom] Core did not initialize"); return end

local Players = NN.Services.Players
local LP = NN.LP

-- ----- Rayfield UI -----
local okUI, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)
if not okUI or not Rayfield then warn("[NomNom] Failed to load Rayfield UI"); return end
NN.Rayfield = Rayfield

function NN.notify(content, title, dur)
    Rayfield:Notify({ Title = title or "NomNom", Content = content, Duration = dur or 3 })
end

local Window = Rayfield:CreateWindow({
    Name = "NomNom FTAP",
    LoadingTitle = "NomNom FTAP",
    LoadingSubtitle = "Modular Persistent Hub v4",
    Theme = "Amethyst",
    ConfigurationSaving = { Enabled = true, FolderName = "NomNomFTAP", FileName = "NomNomConfig" },
    KeySystem = false,
})

-- ----- Tabs -----
local MainTab     = Window:CreateTab("Main", 4483362458)
local MoveTab     = Window:CreateTab("Movement", 4483362458)
local CombatTab   = Window:CreateTab("Combat", 4483362458)
local ProtTab     = Window:CreateTab("Protection", 4483362458)
local VehicleTab  = Window:CreateTab("Vehicles", 4483362458)
local ESPTab      = Window:CreateTab("ESP", 4483362458)
local ChatTab     = Window:CreateTab("Chat", 4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483362458)

-- ----- Build UIs (each module owns its section) -----
NN.buildMainUI(MainTab)
NN.buildMovementUI(MoveTab)
NN.buildCombatUI(CombatTab)
NN.buildProtectionUI(ProtTab)
NN.buildGucciUI(ProtTab)
NN.buildVehiclesUI(VehicleTab)
NN.buildESPUI(ESPTab)
NN.buildChatUI(ChatTab)
NN.buildSettingsUI(SettingsTab)

-- ----- EndGrabEarly neutralize -----
local function neutralizeEndGrab()
    pcall(function()
        local grabEvents = NN.rs:FindFirstChild("GrabEvents")
        if not grabEvents then return end
        local endGrab = grabEvents:FindFirstChild("EndGrabEarly")
        if endGrab then endGrab:Destroy() end
        local dummy = Instance.new("RemoteEvent")
        dummy.Name = "EndGrabEarly"; dummy.Parent = grabEvents
    end)
end
NN.neutralizeEndGrab = neutralizeEndGrab
neutralizeEndGrab()

-- ----- DEATH / RESPAWN (anti-loopkill + attack-back) -----
local S = NN.S
local RunService = NN.Services.RunService

local function reapplyOnRespawn(char)
    -- Anti-loopkill: BEFORE the character settles, start dodging by
    -- loop-teleporting around the map so a hacker can't immediately pin us.
    task.spawn(function()
        local t0 = tick()
        while tick() - t0 < 1.5 and not NN.isGucciActive() do
            local hrp = NN.getHRP()
            if hrp and S.Gucci then pcall(function() hrp.CFrame = CFrame.new(NN.randomWaypoint()) end) end
            RunService.Heartbeat:Wait()
        end
    end)
    task.wait(0.5)
    neutralizeEndGrab()
    NN.setupDashChar(char)
    if S.Fly and NN.startFly then NN.startFly() end
    -- re-arm gucci recovery so we re-gucci immediately
    if S.Gucci and not NN.Tasks.GucciRecover and NN.enableGucci then
        NN.Tasks.Gucci = false; NN.enableGucci()
    end
    for p in pairs(S.MarkedTargets) do if p.Parent then p:SetAttribute("NomNomTarget", true) end end
end

local function bindHumanoidDeath(char)
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    if hum then NN.AddConn("HumDied", hum.Died:Connect(function()
        -- being killed = we lost gucci -> attack back immediately
        if NN.onDeathAttackBack then NN.onDeathAttackBack() end
    end)) end
end

NN.AddConn("CharAdded", LP.CharacterAdded:Connect(function(char)
    bindHumanoidDeath(char)
    reapplyOnRespawn(char)
end))
if NN.getChar() then bindHumanoidDeath(NN.getChar()) end

-- ----- FULL CLEANUP -----
function NN.Cleanup()
    for k in pairs(NN.Tasks) do NN.Tasks[k] = false end
    S.Fly = false; S.LoopFling = false; S.LoopBring = false
    S.GrabKill = false; S.Gucci = false
    if NN.Fling and NN.Fling.conn then pcall(function() NN.Fling.conn:Disconnect() end) end
    if NN.releaseAllGrabs then pcall(NN.releaseAllGrabs) end
    if NN.stopFly then pcall(NN.stopFly) end
    if NN.disableGucci then pcall(NN.disableGucci) end
    for p in pairs(S.MarkedTargets) do if p.Parent then pcall(function() p:SetAttribute("NomNomTarget", nil) end) end end
    S.MarkedTargets = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            local e = p.Character:FindFirstChild("NomNom_ESP"); if e then e:Destroy() end
            local t = p.Character:FindFirstChild("NomNom_Tag"); if t then t:Destroy() end
        end
        if p ~= LP then pcall(function() p:SetAttribute("NomNomTarget", nil) end) end
    end
    if NN.ChatGui then pcall(function() NN.ChatGui:Destroy() end) end
    NN.DisconnectAll()
    pcall(function() Rayfield:Destroy() end)
    _G.NomNom = nil
    _G.NomNomFTAP = nil
end

_G.NomNomFTAP = { Cleanup = NN.Cleanup, State = S, NN = NN }

NN.notify("v4 modular ready: invincible Gucci + extreme loop-tp, persistent grab-kill.", "NomNom FTAP", 5)
print("[NomNom] FTAP v4 (modular) loaded. _G.NomNomFTAP.Cleanup() to unload.")