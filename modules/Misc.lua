-- ==========================================================
-- NomNom FTAP / Misc module
-- Main (player), Movement (fly + dash), Vehicles (hijack + UFO hitbox),
-- ESP, Chat (ExtendGrabLine), and Settings (whitelist + unload).
-- ----------------------------------------------------------
-- Depends on Core (_G.NomNom). Builds UI into tabs passed by the loader.
-- ==========================================================

local NN = _G.NomNom
assert(NN, "[NomNom] Misc module requires Core loaded first")

local S          = NN.S
local LP         = NN.LP
local rs         = NN.rs
local w          = NN.w
local Players    = NN.Services.Players
local RunService = NN.Services.RunService
local UserInputService = NN.Services.UserInputService
local CoreGui    = NN.Services.CoreGui

-- ==========================================
-- MAIN
-- ==========================================
function NN.buildMainUI(MainTab)
    MainTab:CreateSection("Player")
    MainTab:CreateSlider({ Name = "WalkSpeed", Range = {16, 500}, Increment = 1, Suffix = "studs/s",
        CurrentValue = 16, Flag = "WalkSpeed",
        Callback = function(v) local h = NN.getHum(); if h then h.WalkSpeed = v end end })
    MainTab:CreateSlider({ Name = "JumpPower", Range = {50, 500}, Increment = 1,
        CurrentValue = 50, Flag = "JumpPower",
        Callback = function(v) local h = NN.getHum(); if h then h.UseJumpPower = true; h.JumpPower = v end end })
    MainTab:CreateToggle({ Name = "Infinite Jump", CurrentValue = false, Flag = "InfJump",
        Callback = function(state)
            S.InfiniteJump = state
            if state then
                NN.AddConn("InfJump", UserInputService.JumpRequest:Connect(function()
                    local h = NN.getHum()
                    if h and S.InfiniteJump then h:ChangeState(Enum.HumanoidStateType.Jumping) end
                end))
            else NN.RemoveConn("InfJump") end
        end })
    MainTab:CreateButton({ Name = "Unlock 3rd Person",
        Callback = function()
            LP.CameraMaxZoomDistance = 99999; LP.CameraMode = Enum.CameraMode.Classic
            if NN.notify then NN.notify("3rd person unlocked") end
        end })
    MainTab:CreateSection("Teleport")
    MainTab:CreateButton({ Name = "Teleport to Spawn",
        Callback = function()
            local hrp = NN.getHRP(); if not hrp then return end
            local spawnCF = w:FindFirstChild("SpawnCF")
            hrp.CFrame = spawnCF and spawnCF.CFrame or CFrame.new(0, 50, 0)
            if NN.notify then NN.notify("Teleported to spawn") end
        end })
    MainTab:CreateButton({ Name = "Respawn",
        Callback = function() local h = NN.getHum(); if h then h.Health = 0 end end })
end

-- ==========================================
-- MOVEMENT (fly + dash)
-- ==========================================
local flyState = { bv = nil, bg = nil }
function NN.stopFly()
    NN.RemoveConn("Fly")
    if flyState.bv then pcall(function() flyState.bv:Destroy() end); flyState.bv = nil end
    if flyState.bg then pcall(function() flyState.bg:Destroy() end); flyState.bg = nil end
end
function NN.startFly()
    local hrp = NN.getHRP(); if not hrp then return end
    NN.stopFly()
    local bv = Instance.new("BodyVelocity")
    bv.Name = "NomNomFlyVel"; bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bv.Velocity = Vector3.zero; bv.P = 5000; bv.Parent = hrp
    local bg = Instance.new("BodyGyro")
    bg.Name = "NomNomFlyGyro"; bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    bg.P = 9000; bg.D = 500; bg.Parent = hrp
    flyState.bv, flyState.bg = bv, bg
    NN.AddConn("Fly", RunService.RenderStepped:Connect(function()
        if not S.Fly then return end
        local cam = w.CurrentCamera; local h = NN.getHRP()
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

function NN.setupDashChar(char)
    if not char then return end
    NN.RemoveConn("DashDescAdded")
    NN.AddConn("DashDescAdded", char.DescendantAdded:Connect(function(desc)
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

function NN.buildMovementUI(MoveTab)
    MoveTab:CreateSection("Fly")
    MoveTab:CreateToggle({ Name = "Fly (WASD + Space/Shift)", CurrentValue = false, Flag = "Fly",
        Callback = function(v) S.Fly = v; if v then NN.startFly() else NN.stopFly() end end })
    MoveTab:CreateSlider({ Name = "Fly Speed", Range = {16, 300}, Increment = 1, Suffix = "studs/s",
        CurrentValue = 60, Flag = "FlySpeed", Callback = function(v) S.FlySpeed = v end })
    MoveTab:CreateSection("Dash Combat (TSB-style)")
    MoveTab:CreateSlider({ Name = "Dash Multiplier", Range = {1, 3}, Increment = 0.025,
        CurrentValue = 1.075, Flag = "DashMult", Callback = function(v) S.DashMultiplier = v end })
    MoveTab:CreateToggle({ Name = "Free Jump (remove NoJump)", CurrentValue = false, Flag = "FreeJump",
        Callback = function(v) S.FreeJump = v end })
    NN.setupDashChar(NN.getChar())
end

-- ==========================================
-- VEHICLES
-- ==========================================
local function hijack(target)
    if not target then if NN.notify then NN.notify("Vehicle not found!") end; return end
    local backpack = NN.getToyFolder()
    local sticky = NN.remote({"PlayerEvents", "StickyPartEvent"})
    local setowner = NN.remote({"GrabEvents", "SetNetworkOwner"})
    if not backpack or not sticky or not setowner then if NN.notify then NN.notify("Required remotes missing") end; return end
    local hrp = NN.getHRP(); if not hrp then return end
    -- existence-based: spawn shurikens, waiting for each to actually appear
    for _ = 1, 10 do NN.spawnToyAndWait("NinjaShuriken", hrp.CFrame * CFrame.new(0, 3, 0), Vector3.new(0,0,0), 2) end
    for i = 1, 10 do
        pcall(function()
            local shur = backpack:FindFirstChild("NinjaShuriken")
            if shur then shur.Name = tostring(i); sticky:FireServer(shur.StickyPart, target, CFrame.Angles(0, 0, 0)) end
        end)
    end
    for _ = 1, 100 do
        pcall(function() hrp.CFrame = target.CFrame; setowner:FireServer(target, target.CFrame) end)
        task.wait()
    end
    pcall(function()
        local attach = target:FindFirstChild("ObjectModelAttachment")
        if attach then attach:Destroy() end
        local obj = target.Parent.Parent
        obj.FollowThisPart.AlignPosition.Attachment0 = nil
        obj.FollowThisPart.AlignOrientation.Attachment0 = nil
    end)
    if NN.notify then NN.notify("Vehicle hijacked!") end
end

function NN.buildVehiclesUI(VehicleTab)
    VehicleTab:CreateSection("Vehicle Hijack")
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
    NN.AddConn("UFOHitbox", RunService.RenderStepped:Connect(function(dt)
        local hrp = NN.getHRP(); if not hrp then return end
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
end

-- ==========================================
-- ESP
-- ==========================================
function NN.applyESP(player)
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

function NN.buildESPUI(ESPTab)
    for _, p in ipairs(Players:GetPlayers()) do NN.applyESP(p) end
    NN.AddConn("ESPPlayerAdded", Players.PlayerAdded:Connect(NN.applyESP))
    ESPTab:CreateToggle({ Name = "Enable ESP", CurrentValue = false, Flag = "ESP", Callback = function(v) S.ESP = v end })
    ESPTab:CreateToggle({ Name = "Show Names & Photos", CurrentValue = false, Flag = "ESPNames", Callback = function(v) S.ESPNames = v end })
    ESPTab:CreateToggle({ Name = "Rainbow Mode", CurrentValue = false, Flag = "ESPRainbow", Callback = function(v) S.ESPRainbow = v end })
    ESPTab:CreateColorPicker({ Name = "ESP Color", Color = Color3.fromRGB(0, 255, 100), Flag = "ESPColor", Callback = function(v) S.ESPColor = v end })
    ESPTab:CreateButton({ Name = "Force Refresh ESP",
        Callback = function() for _, p in ipairs(Players:GetPlayers()) do NN.applyESP(p) end; if NN.notify then NN.notify("ESP refreshed", "NomNom", 2) end end })
end

-- ==========================================
-- CHAT (ExtendGrabLine)
-- ==========================================
function NN.buildChatUI(ChatTab)
    ChatTab:CreateSection("Custom Chat (F8)")
    local ChatGui = Instance.new("ScreenGui")
    ChatGui.Name = "NomNomChat"
    ChatGui.Parent = RunService:IsStudio() and LP.PlayerGui or CoreGui
    ChatGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ChatGui.DisplayOrder = 100; ChatGui.ResetOnSpawn = false; ChatGui.Enabled = false
    NN.ChatGui = ChatGui

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
            NN.AddConn("ChatRecv", ext.OnClientEvent:Connect(function(...)
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
    NN.AddConn("ChatF8", UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.F8 then ChatGui.Enabled = not ChatGui.Enabled; if ChatGui.Enabled then scrollBottom() end end
    end))
end

-- ==========================================
-- SETTINGS
-- ==========================================
function NN.buildSettingsUI(SettingsTab)
    SettingsTab:CreateSection("Whitelist")
    local whitelistInput = ""
    SettingsTab:CreateInput({ Name = "Player Name", CurrentValue = "",
        PlaceholderText = "Enter player name", RemoveTextAfterFocusLost = false, Flag = "WhitelistInput",
        Callback = function(t) whitelistInput = t end })
    SettingsTab:CreateButton({ Name = "Add to Whitelist",
        Callback = function()
            if whitelistInput ~= "" and not table.find(S.Whitelist, whitelistInput) then
                table.insert(S.Whitelist, whitelistInput); if NN.notify then NN.notify("Added: " .. whitelistInput, "Whitelist") end
            end
        end })
    SettingsTab:CreateButton({ Name = "Remove from Whitelist",
        Callback = function()
            for i, name in ipairs(S.Whitelist) do
                if name == whitelistInput then table.remove(S.Whitelist, i); if NN.notify then NN.notify("Removed: " .. whitelistInput, "Whitelist") end; break end
            end
        end })
    SettingsTab:CreateButton({ Name = "Show Whitelist",
        Callback = function() if NN.notify then NN.notify(#S.Whitelist > 0 and table.concat(S.Whitelist, ", ") or "Empty", "Whitelist", 5) end end })
    SettingsTab:CreateSection("Hub")
    SettingsTab:CreateButton({ Name = "Unload NomNom (full cleanup)",
        Callback = function() if _G.NomNomFTAP and _G.NomNomFTAP.Cleanup then _G.NomNomFTAP.Cleanup() end end })
    SettingsTab:CreateParagraph({ Title = "NomNom FTAP v4 (modular)",
        Content = "Modular persistent hub. Gucci is invincible with extreme map loop-tp; grab-kill runs while dead; killers get marked & their Gucci deleted. F8 = Chat, Y = Teleport-grab." })
end

print("[NomNom] Misc module loaded")
return NN