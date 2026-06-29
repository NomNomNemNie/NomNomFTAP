-- ==========================================================
-- NomNom FTAP / Gucci module
-- Invincible invisibility via Tractor/Blobman seat desync, PLUS the
-- extreme map-wide loop-teleport so the toy is never lockable:
--   * Once gucci'd, the toy is teleported to a fresh random map
--     waypoint every frame (ownership) so it can't be steal-seated,
--     grabbed, or destroyed by another tester.
--   * If gucci is lost: drop a waypoint, loop-tp around the map to
--     dodge loopkill, re-acquire (steal enemy/empty seat -> else
--     spawn own) using existence-based spawn, re-sit, verify, then
--     resume protect-by-looptp.
-- ----------------------------------------------------------
-- Depends on Core (_G.NomNom). Builds its UI into the Protection tab.
-- ==========================================================

local NN = _G.NomNom
assert(NN, "[NomNom] Gucci module requires Core loaded first")

local S          = NN.S
local LP         = NN.LP
local w          = NN.w
local RunService = NN.Services.RunService

local Gucci = { model = nil, seat = nil, busy = false }
NN.Gucci = Gucci

-- ----- helpers -----
local function ragdollSpam(hrp, val)
    local r = NN.remote({"CharacterEvents", "RagdollRemote"})
    if r and hrp then pcall(function() r:FireServer(hrp, val) end) end
end

local function ownToyPart(part)
    -- claim network ownership of a toy part (lets us teleport it freely)
    local setowner = NN.remote({"GrabEvents", "SetNetworkOwner"})
    if setowner and part then pcall(function() setowner:FireServer(part, part.CFrame) end) end
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
    local folder = NN.getToyFolder()
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

-- existence-based spawn (no fixed delay): keep firing spawn until the toy exists
local function spawnGucci()
    local toyName = S.GucciMode == "Blobman" and "CreatureBlobman" or "TractorGreen"
    local baseCF = CFrame.new(0, 1e10, 0) * CFrame.Angles(-2.5694754, 0.10936413, 3.0714223)
    local tries = 0
    repeat
        local m = NN.spawnToyAndWait(toyName, baseCF, Vector3.new(0, -49.45, 0), 4)
        if m then
            local seat = m:FindFirstChildWhichIsA("VehicleSeat", true)
            if seat then return m, seat end
        end
        -- maybe it landed via the folder under a different path
        local ft, fs = findMyGucci()
        if ft and fs then return ft, fs end
        tries += 1
    until tries >= 30 or not (S.Gucci and NN.Tasks.Gucci)
    return nil, nil
end

local function findStealableSeat()
    local hum = NN.getHum()
    for _, v in ipairs(w:GetDescendants()) do
        if v:IsA("Model") and (v.Name == "TractorGreen" or v.Name == "CreatureBlobman") then
            local seat = v:FindFirstChildWhichIsA("VehicleSeat", true)
            if seat and seat.Occupant ~= hum then
                return v, seat, (seat.Occupant ~= nil)
            end
        end
    end
    return nil, nil, false
end

-- Sit + ragdoll-desync into a seat (own or stolen)
local function sitGucci(seatObj)
    if not seatObj or not seatObj.Parent then return end
    local hrp, hum = NN.getHRP(), NN.getHum()
    if not hrp or not hum then return end

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
    ragdollSpam(hrp, 0.9)
end

-- Are we currently gucci'd (seated in our tracked seat)?
local function isGucciActive()
    local hum = NN.getHum()
    local m, s = Gucci.model, Gucci.seat
    return m and m.Parent and s and s.Parent and hum and s.Occupant == hum
end
NN.isGucciActive = isGucciActive

-- ==========================================
-- EXTREME LOOP-TP: every frame, move the whole gucci model (incl. seat,
-- so we ride along) to a fresh random map waypoint. Re-claims ownership
-- each jump so no other client can grab/steal/destroy it.
-- ==========================================
local function startExtremeTP()
    NN.AddConn("GucciExtremeTP", RunService.Heartbeat:Connect(function()
        if not (S.Gucci and NN.Tasks.Gucci) or not S.GucciExtremeTP then return end
        local m = Gucci.model
        if not m or not m.Parent then return end
        local jumps = math.max(1, math.floor(S.ExtremeTPRate or 1))
        for _ = 1, jumps do
            local wp = NN.randomWaypoint()
            NN.moveModelTo(m, CFrame.new(wp))
        end
        -- re-claim ownership of the seat/hitbox so it stays ours
        local host = m:FindFirstChild("Hitbox") or Gucci.seat
        if host and host:IsA("BasePart") then ownToyPart(host) end
    end))
end

-- ==========================================
-- HARDENING: keep us seated + desynced every frame (independent of TP).
-- ==========================================
local function startHarden()
    NN.AddConn("GucciHarden", RunService.Heartbeat:Connect(function()
        if not (S.Gucci and NN.Tasks.Gucci) then return end
        local hrp, hum = NN.getHRP(), NN.getHum()
        if not hrp or not hum then return end
        local m, s = Gucci.model, Gucci.seat
        if not m or not m.Parent or not s or not s.Parent then return end
        ragdollSpam(hrp, -math.huge)
        if s.Occupant ~= hum then pcall(function() s:Sit(hum) end) end
    end))
end

-- ==========================================
-- RECOVERY: lost-gucci → waypoint dodge looptp → re-acquire → sit → verify
-- → protect. Runs faster + more aggressively than v3.
-- ==========================================
local function startRecovery()
    NN.Tasks.GucciRecover = true
    task.spawn(function()
        while S.Gucci and NN.Tasks.GucciRecover do
            if not isGucciActive() and not Gucci.busy and S.GucciAutoRecover then
                Gucci.busy = true

                -- (a) immediate dodge: while we have no seat, keep teleporting our
                -- own character around the map via a temporary owned waypoint so a
                -- hacker can't pin + loopkill us during the re-acquire window.
                local hrp = NN.getHRP()
                if hrp then
                    pcall(function() hrp.CFrame = CFrame.new(NN.randomWaypoint()) end)
                end

                -- (b) re-acquire: prefer existing own, then steal enemy/empty, else spawn
                local nt, ns = findMyGucci()
                if not (nt and ns) and S.GucciStealSeat then
                    local st, ss, occupied = findStealableSeat()
                    if st and ss then
                        if occupied then
                            local destroyToy = NN.remote({"MenuToys", "DestroyToy"})
                            if destroyToy then pcall(function() destroyToy:FireServer(st) end) end
                            task.wait(0.05)
                            st, ss = findStealableSeat()
                        end
                        if st and ss then nt, ns = st, ss end
                    end
                end
                if not (nt and ns) then nt, ns = spawnGucci() end

                -- (c) sit + verify + protect
                if nt and ns and S.Gucci then
                    Gucci.model, Gucci.seat = nt, ns
                    pcall(function() sitGucci(ns) end)
                    NN.AddConn("GucciAncestry", nt.AncestryChanged:Connect(function(_, parent)
                        if not parent and S.Gucci then Gucci.model = nil end  -- triggers recovery
                    end))
                end
                Gucci.busy = false
            end
            -- fast + extreme check cadence
            task.wait(0.05)
        end
    end)
end

NN.enableGucci = function()
    if NN.Tasks.Gucci then return end
    NN.Tasks.Gucci = true
    NN.computeMapBounds()
    startHarden()
    startExtremeTP()
    startRecovery()
    if NN.notify then NN.notify("Gucci ON — invincible + extreme map loop-tp", "Gucci") end
end

NN.disableGucci = function()
    NN.Tasks.Gucci = false
    NN.Tasks.GucciRecover = false
    NN.RemoveConn("GucciHarden")
    NN.RemoveConn("GucciExtremeTP")
    NN.RemoveConn("GucciAncestry")
    local destroyToy = NN.remote({"MenuToys", "DestroyToy"})
    if Gucci.model and Gucci.model.Parent and destroyToy then
        pcall(function() destroyToy:FireServer(Gucci.model) end)
    end
    Gucci.model, Gucci.seat, Gucci.busy = nil, nil, false
end

-- ----- UI (built into Protection tab provided by loader) -----
function NN.buildGucciUI(ProtTab)
    ProtTab:CreateSection("Gucci (Invincible + Extreme Loop-TP)")
    ProtTab:CreateToggle({ Name = "Gucci (Invincible)", CurrentValue = false, Flag = "Gucci",
        Callback = function(v) S.Gucci = v; if v then NN.enableGucci() else NN.disableGucci() end end })
    ProtTab:CreateDropdown({ Name = "Gucci Mode", Options = {"Tractor", "Blobman"},
        CurrentOption = {"Tractor"}, Flag = "GucciMode",
        Callback = function(o) S.GucciMode = type(o) == "table" and o[1] or o end })
    ProtTab:CreateToggle({ Name = "Extreme Map Loop-TP (toy)", CurrentValue = true, Flag = "GucciExtremeTP",
        Callback = function(v) S.GucciExtremeTP = v end })
    ProtTab:CreateSlider({ Name = "Loop-TP Rate (jumps/frame)", Range = {1, 20}, Increment = 1,
        CurrentValue = 1, Flag = "ExtremeTPRate", Callback = function(v) S.ExtremeTPRate = v end })
    ProtTab:CreateToggle({ Name = "Auto Re-Gucci on loss", CurrentValue = true, Flag = "GucciAutoRecover",
        Callback = function(v) S.GucciAutoRecover = v end })
    ProtTab:CreateToggle({ Name = "Steal enemy seat when un-Gucci'd", CurrentValue = true, Flag = "GucciStealSeat",
        Callback = function(v) S.GucciStealSeat = v end })
end

print("[NomNom] Gucci module loaded")
return NN