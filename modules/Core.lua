-- ==========================================================
-- NomNom FTAP / Core module
-- Shared services, state, connection manager, character access,
-- existence-based toy spawn (no fixed delay), and the extreme
-- map-waypoint loop-teleport engine used by Gucci & toys.
-- ----------------------------------------------------------
-- Loaded first. Publishes everything onto a shared table `NN`
-- (also stored at _G.NomNom) so other modules can use it.
-- ==========================================================

local NN = _G.NomNom
if not NN then NN = {}; _G.NomNom = NN end

-- ----- Services -----
NN.Services = {
    Players           = game:GetService("Players"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    RunService        = game:GetService("RunService"),
    UserInputService  = game:GetService("UserInputService"),
    TweenService      = game:GetService("TweenService"),
    Workspace         = game:GetService("Workspace"),
    Debris            = game:GetService("Debris"),
    CoreGui           = game:GetService("CoreGui"),
}

local Players     = NN.Services.Players
local RunService  = NN.Services.RunService
local Workspace   = NN.Services.Workspace

NN.LP = Players.LocalPlayer
NN.rs = NN.Services.ReplicatedStorage
NN.w  = Workspace

local LP = NN.LP
local rs = NN.rs
local w  = NN.w

-- ----- Connection / task manager -----
NN.Connections = NN.Connections or {}
NN.Tasks       = NN.Tasks or {}

function NN.AddConn(name, conn)
    if NN.Connections[name] then pcall(function() NN.Connections[name]:Disconnect() end) end
    NN.Connections[name] = conn
    return conn
end

function NN.RemoveConn(name)
    if NN.Connections[name] then
        pcall(function() NN.Connections[name]:Disconnect() end)
        NN.Connections[name] = nil
    end
end

function NN.DisconnectAll()
    for name, conn in pairs(NN.Connections) do
        pcall(function() conn:Disconnect() end)
        NN.Connections[name] = nil
    end
end

-- ----- Shared state -----
NN.S = NN.S or {
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
    GucciStealSeat = true, GucciExtremeTP = true,
    ExtremeTPRate = 1,   -- multiplier: how many waypoint jumps per frame
    -- Vehicles
    UFOSpin = false, UFOFollow = false, UFOSpinSpeed = 6,
    UFOSpinRadius = 15, UFOHeight = 5,
    -- ESP
    ESP = false, ESPNames = false, ESPRainbow = false,
    ESPColor = Color3.fromRGB(0, 255, 100),
    -- Settings
    Whitelist = {},
    -- runtime
    MarkedTargets = {},
}
local S = NN.S

-- ----- Respawn-safe character access -----
function NN.getChar() return LP.Character end
function NN.getHRP() local c = LP.Character; return c and c:FindFirstChild("HumanoidRootPart") end
function NN.getHum() local c = LP.Character; return c and c:FindFirstChildOfClass("Humanoid") end
function NN.getToyFolder() return w:FindFirstChild(LP.Name .. "SpawnedInToys") end

-- ----- Guarded remote lookup -----
function NN.remote(path)
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
-- EXISTENCE-BASED TOY SPAWN (no fixed delay)
-- Spawns a toy and waits until it actually appears in the toy folder,
-- instead of guessing a cooldown. Returns the spawned Model (or nil).
-- ==========================================
function NN.spawnToyAndWait(toyName, cf, vel, timeout)
    local spawnToy = NN.remote({"MenuToys", "SpawnToyRemoteFunction"})
    if not spawnToy then return nil end
    timeout = timeout or 5

    local folder = NN.getToyFolder()
    -- snapshot existing toys of this name so we can detect the new one
    local before = {}
    if folder then
        for _, c in ipairs(folder:GetChildren()) do
            if c.Name == toyName then before[c] = true end
        end
    end

    pcall(function() spawnToy:InvokeServer(toyName, cf, vel or Vector3.new(0, 0, 0)) end)

    -- poll until a NEW toy of this name shows up (check existence, not delay)
    local t0 = tick()
    repeat
        folder = folder or NN.getToyFolder()
        if folder then
            for _, c in ipairs(folder:GetChildren()) do
                if c.Name == toyName and not before[c] then
                    return c
                end
            end
        end
        RunService.Heartbeat:Wait()
    until tick() - t0 >= timeout
    return nil
end

-- Lightweight version for fire-and-check callers that just need a boolean.
function NN.spawnToy(toyName, cf, vel)
    local spawnToy = NN.remote({"MenuToys", "SpawnToyRemoteFunction"})
    if not spawnToy then return false end
    return (pcall(function() spawnToy:InvokeServer(toyName, cf, vel or Vector3.new(0, 0, 0)) end))
end

-- ==========================================
-- MAP BOUNDS + EXTREME WAYPOINT LOOP-TP ENGINE
-- Computes a rough map bounding box once, then provides a fast
-- random in-bounds waypoint generator. The Gucci module uses this
-- to teleport its toy all over the map every frame (ownership) so
-- no one can lock onto / steal / destroy it.
-- ==========================================
NN.Map = { min = nil, max = nil, center = nil, computed = false }

function NN.computeMapBounds()
    -- Try a few well-known containers, else fall back to a wide default box.
    local minV = Vector3.new(math.huge, math.huge, math.huge)
    local maxV = Vector3.new(-math.huge, -math.huge, -math.huge)
    local found = false
    local map = w:FindFirstChild("Map")
    local scanRoot = map or w
    local count = 0
    for _, p in ipairs(scanRoot:GetDescendants()) do
        if p:IsA("BasePart") and p.Anchored then
            local pos = p.Position
            if pos.Y > -500 and pos.Y < 5000 then
                minV = Vector3.new(math.min(minV.X, pos.X), math.min(minV.Y, pos.Y), math.min(minV.Z, pos.Z))
                maxV = Vector3.new(math.max(maxV.X, pos.X), math.max(maxV.Y, pos.Y), math.max(maxV.Z, pos.Z))
                found = true
                count += 1
                if count >= 4000 then break end  -- bound the scan
            end
        end
    end
    if not found then
        minV = Vector3.new(-1000, 50, -1000)
        maxV = Vector3.new(1000, 800, 1000)
    end
    NN.Map.min = minV
    NN.Map.max = maxV
    NN.Map.center = (minV + maxV) * 0.5
    NN.Map.computed = true
    return NN.Map
end

-- Random waypoint inside map bounds, kept comfortably ABOVE the void floor.
function NN.randomWaypoint()
    if not NN.Map.computed then NN.computeMapBounds() end
    local mn, mx = NN.Map.min, NN.Map.max
    local floorY = math.max(mn.Y + 30, S.AntiVoidY + 200)   -- never near the void
    local x = mn.X + math.random() * (mx.X - mn.X)
    local z = mn.Z + math.random() * (mx.Z - mn.Z)
    local y = math.clamp(mn.Y + math.random() * (mx.Y - mn.Y), floorY, mx.Y + 200)
    return Vector3.new(x, y, z)
end

-- Teleport every BasePart of a model to a CFrame (used for toy looptp).
function NN.moveModelTo(model, cf)
    if not model then return end
    for _, p in ipairs(model:GetDescendants()) do
        if p:IsA("BasePart") then p.CFrame = cf end
    end
end

print("[NomNom] Core module loaded")
return NN