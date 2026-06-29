-- ==========================================================
-- NomNom FTAP / Protection module
-- Anti Grab / Explode / Fire / Blobman / Ragdoll / Void / Lag.
-- Gucci lives in its own module (Gucci.lua); this is the lighter
-- anti-suite that runs alongside it.
-- ----------------------------------------------------------
-- Depends on Core (_G.NomNom). Builds UI into the Protection tab.
-- ==========================================================

local NN = _G.NomNom
assert(NN, "[NomNom] Protection module requires Core loaded first")

local S          = NN.S
local LP         = NN.LP
local w          = NN.w
local RunService = NN.Services.RunService

function NN.buildProtectionUI(ProtTab)
    ProtTab:CreateSection("Anti Systems")

    ProtTab:CreateToggle({ Name = "Anti Grab", CurrentValue = false, Flag = "AntiGrab",
        Callback = function(v)
            S.AntiGrab = v
            if v then
                NN.Tasks.AntiGrab = true
                task.spawn(function()
                    local struggle = NN.remote({"CharacterEvents", "Struggle"})
                    while S.AntiGrab and NN.Tasks.AntiGrab do
                        task.wait()
                        local held = LP:FindFirstChild("IsHeld")
                        if held and held.Value == true then
                            local hrp = NN.getHRP()
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
            else NN.Tasks.AntiGrab = false end
        end })

    ProtTab:CreateToggle({ Name = "Anti Explode", CurrentValue = false, Flag = "AntiExplode",
        Callback = function(v)
            S.AntiExplode = v
            if v then
                NN.AddConn("AntiExplode", w.ChildAdded:Connect(function(obj)
                    if not S.AntiExplode then return end
                    if obj:IsA("Part") and obj.Name == "Part" then
                        local hrp = NN.getHRP()
                        if hrp and (obj.Position - hrp.Position).Magnitude <= 20 then
                            hrp.Anchored = true; task.wait(0.01); hrp.Anchored = false
                        end
                    end
                end))
            else NN.RemoveConn("AntiExplode") end
        end })

    ProtTab:CreateToggle({ Name = "Anti Fire", CurrentValue = false, Flag = "AntiFire",
        Callback = function(v)
            S.AntiFire = v
            if v then
                local extPart
                pcall(function() extPart = w.Map.Hole.PoisonBigHole.ExtinguishPart end)
                if not extPart then pcall(function() extPart = w.Map.Hole.PoisonSmallHole.ExtinguishPart end) end
                if not extPart then if NN.notify then NN.notify("ExtinguishPart not found") end; return end
                local origPos = extPart.Position
                NN.AddConn("AntiFire", RunService.Heartbeat:Connect(function()
                    if not S.AntiFire then return end
                    local hrp = NN.getHRP(); if not hrp then return end
                    if hrp:FindFirstChild("FireLight") or hrp:FindFirstChild("FireParticleEmitter") then
                        extPart.CFrame = CFrame.new(hrp.Position)
                    else extPart.CFrame = CFrame.new(origPos) end
                end))
            else NN.RemoveConn("AntiFire") end
        end })

    ProtTab:CreateToggle({ Name = "Anti Blobman", CurrentValue = false, Flag = "AntiBlobman",
        Callback = function(v)
            S.AntiBlobman = v
            if v then
                NN.Tasks.AntiBlobman = true
                task.spawn(function()
                    while S.AntiBlobman and NN.Tasks.AntiBlobman do
                        local hrp = NN.getHRP()
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
            else NN.Tasks.AntiBlobman = false end
        end })

    ProtTab:CreateToggle({ Name = "Anti Ragdoll", CurrentValue = false, Flag = "AntiRagdoll",
        Callback = function(v)
            S.AntiRagdoll = v
            if v then
                NN.AddConn("AntiRagdoll", RunService.Heartbeat:Connect(function()
                    if not S.AntiRagdoll then return end
                    local hum = NN.getHum(); if not hum then return end
                    local rag = hum:FindFirstChild("Ragdolled")
                    if rag and rag:IsA("BoolValue") and rag.Value then
                        local ragRemote = NN.remote({"CharacterEvents", "RagdollRemote"})
                        local hrp = NN.getHRP()
                        if ragRemote and hrp then pcall(function() ragRemote:FireServer(hrp, 0) end) end
                    end
                end))
            else NN.RemoveConn("AntiRagdoll") end
        end })

    ProtTab:CreateToggle({ Name = "Anti Void", CurrentValue = false, Flag = "AntiVoid",
        Callback = function(v)
            S.AntiVoid = v
            if v then
                NN.AddConn("AntiVoid", RunService.Heartbeat:Connect(function()
                    if not S.AntiVoid then return end
                    local hrp = NN.getHRP()
                    if hrp and hrp.Position.Y < S.AntiVoidY then hrp.CFrame = CFrame.new(0, 50, 0) end
                end))
            else NN.RemoveConn("AntiVoid") end
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
end

print("[NomNom] Protection module loaded")
return NN