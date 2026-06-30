-- // APPLE HUB 🍎
-- // Объединение лучших функций Ragalic и NoName
-- // Все функции переведены на русский язык
-- // Добавлены смайлики для удобства навигации

-- // APPLE_RERUN_CLEANUP_V1: disconnect previous run connections before creating a new UI/session.
do
    local state = getgenv and getgenv() or _G
    if state.APPLE_RERUN_CLEANUP_V1 and state.APPLE_RERUN_CLEANUP_V1.Disconnect then
        pcall(function() state.APPLE_RERUN_CLEANUP_V1:Disconnect() end)
    end
    state.APPLE_RERUN_CLEANUP_V1 = { Connections = {} }
    function state.APPLE_RERUN_CLEANUP_V1:Track(connection)
        if connection then table.insert(self.Connections, connection) end
        return connection
    end
    function state.APPLE_RERUN_CLEANUP_V1:Disconnect()
        for _, connection in ipairs(self.Connections) do
            pcall(function() if connection and connection.Disconnect then connection:Disconnect() end end)
        end
        table.clear(self.Connections)
    end
    for _, key in ipairs({
        "autoStruggleConn", "antiExplodeConn", "hookBurnConn", "antiVoidConn",
        "antiGucciConnection", "wsConn", "SuperGrabConn", "WaitUISConn",
        "DeleteObjConn", "KillGrabConn"
    }) do
        local connection = state[key]
        if connection and connection.Disconnect then pcall(function() connection:Disconnect() end) end
        state[key] = nil
    end
end

-- // Очистка глобальных переменных, чтобы избежать конфликтов
for k in pairs(_G) do
    if type(k) == "string" and (k:find("Anti") or k:find("Loop") or k:find("bool") or k:find("int") or k:find("etc")) then
        _G[k] = nil
    end
end

warn([[
        ----------------------------------------------
        ##   ##  ##   ##  ###               ### 
        ###  ##  ###  ##   ##                ## 
        #### ##  #### ##   ##      ##  ##    ## 
        ## ####  ## ####   #####   ##  ##    ##### 
        ##  ###  ##  ###   ##  ##  ##  ##    ##  ## 
        ##   ##  ##   ##   ##  ##  ##  ##    ##  ## 
        ##   ##  ##   ##  ###  ##   ######  ###### ...
        ----------------------------------------------
    ]])

local StartTick1 = tick()

-- // Services --
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- // LocalPlayer Locals --
local plr = Players.LocalPlayer
local mouse = plr:GetMouse()
local char = plr.Character or plr.CharacterAdded:Wait()
local hum = char:FindFirstChild("Humanoid") or char:WaitForChild("Humanoid")
local hrp = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart")
local head = char:FindFirstChild("Head") or char:WaitForChild("Head")
local IsHeld = plr.IsHeld
local CanSpawnToy = plr.CanSpawnToy
local InPlot = plr.InPlot
local InOwnedPlot = plr.InOwnedPlot
local AntiLineLag = plr.PlayerScripts.CharacterAndBeamMove
local AntiShuriLag = plr.PlayerScripts.StickyPartsTouchDetection
local inv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys") or workspace:WaitForChild(plr.Name .. "SpawnedInToys")

-- // Remotes --
local SetNetworkOwner = RS.GrabEvents:FindFirstChild("SetNetworkOwner") or RS.GrabEvents:WaitForChild("SetNetworkOwner")
local StickyEvent = RS.PlayerEvents:FindFirstChild("StickyPartEvent") or RS.PlayerEvents:WaitForChild("StickyPartEvent")
local DestroyToy = RS.MenuToys:FindFirstChild("DestroyToy") or RS.MenuToys:WaitForChild("DestroyToy")
local Struggle = RS.CharacterEvents:FindFirstChild("Struggle") or RS.CharacterEvents:WaitForChild("Struggle")
local CreateGrabLine = RS.GrabEvents:FindFirstChild("CreateGrabLine") or RS.GrabEvents:WaitForChild("CreateGrabLine")
local SetLineColor = RS.DataEvents:FindFirstChild("UpdateLineColorsEvent") or RS.DataEvents:WaitForChild("UpdateLineColorsEvent")
local SpawnToyRemote = RS.MenuToys:FindFirstChild("SpawnToyRemoteFunction") or RS.MenuToys:WaitForChild("SpawnToyRemoteFunction")
local DestroyGrabLine = RS.GrabEvents:FindFirstChild("DestroyGrabLine") or RS.GrabEvents:WaitForChild("DestroyGrabLine")
local RagdollRemote = RS.CharacterEvents:FindFirstChild("RagdollRemote") or RS.CharacterEvents:WaitForChild("RagdollRemote")

-- // Библиотека интерфейса (Obsidian)
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

-- // Настройки библиотеки
local Options = Library.Options
local Toggles = Library.Toggles
Library.ForceCheckbox = false

-- // СОЗДАНИЕ ОКНА
local Window = Library:CreateWindow({
    Title = "APPLE HUB 🍎",
    Footer = "APPLE HUB 🍎 | Version 2.0",
    NotifySide = "Right",
    ShowCustomCursor = true,
})

-- // ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ДЛЯ СОСТОЯНИЙ
_G.Toggles = {}
_G.Ints = {}
_G.Bools = {}
_G.Etc = {
    MyPCLD = nil,
    TargetPLR = nil,
    Root = nil,
    Head = nil,
    Torso = nil,
    Hum = nil,
    TargetChar = nil,
    Limbs = {
        "Left Arm",
        "Left Leg",
        "Right Arm",
        "Right Leg"
    },
    MapPoints = {
        ["🟩 Зеленый дом 🟩"] = CFrame.new(-548.305054, -2.45424771, 79.3213348),
        ["🩷 Розовый дом 🩷"] = CFrame.new(-475.493835, -2.70774508, -159.395279),
        ["🦇 Дом ведьмы 🦇"] = CFrame.new(270.225922, -2.48055029, 458.186493),
        ["🟦 Синий дом 🟦"] = CFrame.new(501.939911, 88.2323608, -349.129211),
        ["🀄 Китайский дом 💮"] = CFrame.new(545.441833, 128.004593, -99.4881439)
    },
    LastBlob = nil,
    LastTrainSeat = nil,
    FileName = "",
    FileToLoad = "",
}

local etc = _G.Etc
local Camera = workspace.CurrentCamera
local autoStruggleConn
local antiExplodeConn
local hookBurnConn
local antiVoidConn
local antiGucciConnection
local wsConn
local SuperGrabConn
local WaitUISConn
local DeleteObjConn
local KillGrabConn
local restoreFrames = 0
local CheckForHome

-- // ВКЛАДКИ
local Tabs = {
    Defense = Window:AddTab("Защита 🛡️", "shield"),
    Target = Window:AddTab("Цель 🎯", "crosshair"),
    Grab = Window:AddTab("Хватка ✊", "hand"),
    Player = Window:AddTab("Игрок 👤", "user"),
    Visual = Window:AddTab("Визуал 👁️", "layers"),
    Misc = Window:AddTab("Разное 🛠️", "circle-ellipsis"),
    Fun = Window:AddTab("Веселье 😂", "smile"),
    Keybinds = Window:AddTab("Клавиши ⌨️", "keyboard"),
    ["UI Settings"] = Window:AddTab("Настройки UI ⚙️", "settings")
}

-- // ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (из NoName)
local function FWD(parent, part, time)
    return parent:FindFirstChild(part) or parent:WaitForChild(part, time or 5)
end

local function CFP(parent, part)
    return parent:FindFirstChild(part) ~= nil
end

local function HasProperty(obj, property)
    local ok = pcall(function()
        if obj[property] then
        end
    end)
    return ok
end

local function GetMagnitude(Part1, Part2)
    return (Part1.Position - Part2.Position).Magnitude
end

local function CheckForPartOwner(Head)
    local PartOwner = Head:FindFirstChild("PartOwner")
    local HasYou = PartOwner and PartOwner.Value == plr.Name
    return HasYou
end

local function CheckNetworkOwnerOnPart(Part)
    return CFP(Part, "PartOwner") and Part["PartOwner"].Value == plr.Name
end

local function CheckNetworkOwnerOnPlayer(TargetPlr, Root)
    if Root then
        local Head = Root.Parent and Root.Parent:FindFirstChild("Head")
        return Head and CheckNetworkOwnerOnPart(Head)
    else
        local TargetChar = TargetPlr and TargetPlr.Character
        local TargetRoot = TargetChar and TargetChar:FindFirstChild("Head")
        return TargetRoot and CheckNetworkOwnerOnPart(TargetRoot)
    end
end

local function sno(part)
    SetNetworkOwner:FireServer(part, part.CFrame)
end

local function unsno(part)
    DestroyGrabLine:FireServer(part)
end

local function line(part)
    CreateGrabLine:FireServer(part, part.CFrame)
end

local function StopAllVelocity(parent)
    local ToStopPart = parent.PrimaryPart or parent
    if ToStopPart then
        ToStopPart.AssemblyLinearVelocity = Vector3.zero
        ToStopPart.AssemblyAngularVelocity = Vector3.zero
    end
end

local function StopVelocityF()
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
    end
end

local function Notify(Title, SubTitle)
    Library:Notify({
        Title = Title or "Уведомление",
        Description = SubTitle or "",
        Time = 5,
    })
end

local function toy_delete(toy)
    DestroyToy:FireServer(toy)
end

local function SpawnToy(ToyName)
    if InPlot.Value and not InOwnedPlot.Value then
        InPlot:GetPropertyChangedSignal("Value"):Wait()
    end
    if not CanSpawnToy.Value then
        CanSpawnToy:GetPropertyChangedSignal("Value"):Wait()
    end

    local SpawnCF = (etc.MyPCLD or hrp).CFrame * CFrame.new(0, 14, 20)

    local Container = InOwnedPlot.Value and CheckForHome() or inv
    if not Container then
        return nil
    end

    local spawnedObject = nil
    local connection
    connection = Container.ChildAdded:Connect(function(child)
        if child.Name == ToyName then
            spawnedObject = child
        end
    end)

    task.spawn(function()
        pcall(function()
            SpawnToyRemote:InvokeServer(ToyName, SpawnCF, Vector3.zero)
        end)
    end)

    local start = tick()
    repeat
        task.wait()
    until spawnedObject or (tick() - start) > 2.5

    if connection then
        connection:Disconnect()
    end
    return spawnedObject
end

function CheckForHome()
    if etc["LastHouse"] == nil or etc["LastPlotOwner"] == nil or etc["LastPlotOwner"].Parent == nil then
        for i = 1, 5 do
            local Plot = workspace.Plots["Plot" .. i]
            for _, v in pairs(Plot.PlotSign["ThisPlotsOwners"]:GetChildren()) do
                if v.Value == plr.Name then
                    etc["LastHouse"] = workspace.PlotItems["Plot" .. i]
                    etc["LastPlotOwner"] = v
                    return etc["LastHouse"]
                end
            end
        end
    end
    return etc["LastHouse"]
end

local function FindBlob()
    if etc["LastBlob"] == nil or not CFP(etc["LastBlob"], "VehicleSeat") or etc["LastBlob"].VehicleSeat.Occupant ~= hum then
        etc["LastBlob"] = hum.SeatPart and hum.SeatPart:FindFirstAncestor("CreatureBlobman")
    end
    return etc["LastBlob"]
end

local function BringRight(k)
    local v = FindBlob()
    local Root = Players[k].Character:FindFirstChild("HumanoidRootPart")
    if not Root or not v then
        return
    end
    v.BlobmanSeatAndOwnerScript.CreatureGrab:FireServer(v.RightDetector, Root, v.RightDetector.RightWeld)
end

local function DropRight(k)
    local v = FindBlob()
    local Root = Players[k].Character:FindFirstChild("HumanoidRootPart")
    if not Root or not v then
        return
    end
    v.BlobmanSeatAndOwnerScript.CreatureDrop:FireServer(v.RightDetector.RightWeld, Root)
end

local function BugRight(k)
    local v = FindBlob()
    local Root = Players[k].Character:FindFirstChild("HumanoidRootPart")
    if not Root or not v then
        return
    end
    v.BlobmanSeatAndOwnerScript.CreatureRelease:FireServer(v.RightDetector.RightWeld, Root)
end

local function RenameInShop(Instance, OriginalName, ToRename)
    local index = nil
    local ToCheckName = Instance.Name or Instance
    for i, v in pairs(inv:GetChildren()) do
        if v.Name == ToCheckName then
            index = i
        end
    end
    if index == nil then
        return
    end
    local contents = plr.PlayerGui.MenuGui.Menu.TabContents.ToyDestroy.Contents
    for i, v in ipairs(contents:GetChildren()) do
        if v.Name == OriginalName and i == index then
            local view = v.ViewItemButton
            view.Text = ToRename
            view.TextScaled = true
            view.LowResImage.Image = ""
        end
    end
end

local function ForceDeathNotG(hum)
    hum.BreakJointsOnDeath = false
    hum:ChangeState(Enum.HumanoidStateType.Dead)
    hum.Sit = false
    hum.Jump = true
end

local function IsFriend(player)
    if not player or not player.UserId then
        return false
    end
    local success, result = pcall(function()
        return plr:IsFriendsWith(player.UserId)
    end)
    if success then
        return result
    else
        return false
    end
end

local function BuildPlayerOptions()
    local options = {}
    local map = {}

    for _, player in ipairs(Players:GetPlayers()) do
        local display = string.format(
            '<font color="rgb(255,0,0)"><b>%s</b></font> <b><i>(%s)</i></b>',
            player.Name,
            player.DisplayName
        )
        table.insert(options, display)
        map[display] = player
    end

    return options, map
end

-- // --- ВКЛАДКА "ЗАЩИТА 🛡️" (Из Ragalic + NoName) ---
local DefenseGroup = Tabs.Defense:AddLeftGroupbox("Основная защита 🛡️")
local DefenseExtra = Tabs.Defense:AddRightGroupbox("Дополнительная защита 🔒")

-- // Anti Grab (Ragalic)
DefenseGroup:AddToggle("AntiGrabObsidian", {
    Text = "Анти-захват ✋",
    Default = false,
    Callback = function(Value)
        if Value then
            -- Реализация из Ragalic
            if autoStruggleConn then
                autoStruggleConn:Disconnect()
            end
            autoStruggleConn = RunService.Heartbeat:Connect(function()
                local character = plr.Character
                if character and character:FindFirstChild("Head") then
                    local head = character.Head
                    if head:FindFirstChild("PartOwner") then
                        task.spawn(function()
                            if Struggle then
                                Struggle:FireServer(plr)
                            end
                            pcall(function()
                                ReplicatedStorage.GameCorrectionEvents.StopAllVelocity:FireServer()
                            end)
                            for _, part in pairs(character:GetChildren()) do
                                if part:IsA("BasePart") then
                                    part.Anchored = true
                                end
                            end
                            local isHeld = plr:FindFirstChild("IsHeld")
                            while isHeld and isHeld.Value do
                                task.wait()
                            end
                            for _, part in pairs(character:GetChildren()) do
                                if part:IsA("BasePart") then
                                    part.Anchored = false
                                end
                            end
                        end)
                    end
                end
            end)
        else
            if autoStruggleConn then
                autoStruggleConn:Disconnect()
                autoStruggleConn = nil
            end
            local char = plr.Character
            if char then
                for _, part in pairs(char:GetChildren()) do
                    if part:IsA("BasePart") then
                        part.Anchored = false
                    end
                end
            end
        end
    end
})

-- // Anti Blobman (Ragalic)
DefenseGroup:AddToggle("AntiBlobmanToggle", {
    Text = "Анти-блобман 🧌",
    Default = false,
    Callback = function(on)
        _G.Bools.AntiBlob = on
        for _, v in (Players:GetChildren()) do
            if v == plr then
                continue
            end
            local plrInv = workspace[v.Name .. "SpawnedInToys"]
            if plrInv then
                for _, x in pairs(plrInv:GetChildren()) do
                    if x.Name == "CreatureBlobman" then
                        local RightDetector, LeftDetector = x:FindFirstChild("RightDetector"), x:FindFirstChild("LeftDetector")
                        if RightDetector and LeftDetector then
                            RightDetector.RightWeld.Enabled = not (on)
                            RightDetector.RightAlignOrientation.Enabled = not (on)
                            RightDetector.RightAlignOrientation.RigidityEnabled = not (on)
                            LeftDetector.LeftWeld.Enabled = not (on)
                            LeftDetector.LeftAlignOrientation.Enabled = not (on)
                            LeftDetector.LeftAlignOrientation.RigidityEnabled = not (on)
                        end
                    end
                end
            end
        end
        for i = 1, 5 do
            local plot = workspace.Plots["Plot" .. i]
            if plot then
                for _, y in pairs(plot:GetChildren()) do
                    if y.Name == "CreatureBlobman" then
                        local LeftDetector, RightDetector = y:FindFirstChild("LeftDetector"), y:FindFirstChild("RightDetector")
                        if LeftDetector and RightDetector then
                            RightDetector.RightWeld.Enabled = not (on)
                            RightDetector.RightAlignOrientation.Enabled = not (on)
                            RightDetector.RightAlignOrientation.RigidityEnabled = not (on)
                            LeftDetector.LeftWeld.Enabled = not (on)
                            LeftDetector.LeftAlignOrientation.Enabled = not (on)
                            LeftDetector.LeftAlignOrientation.RigidityEnabled = not (on)
                        end
                    end
                end
            end
        end
    end
})

-- // Anti Explosion (Ragalic)
DefenseGroup:AddToggle("AntiExplosionToggle", {
    Text = "Анти-взрыв 💥",
    Default = false,
    Callback = function(on)
        _G.Bools.AntiExplodeT = on
        if on then
            local antiExplodeConn = RS.BombEvents.BombExplode.OnClientEvent:Connect(function()
                hrp.Anchored = true
                task.wait()
                hrp.Anchored = false
                if not hum.SeatPart then
                    hum.Sit = false
                end
                for i = 1, #etc.Limbs do
                    local limb = char:FindFirstChild(etc.Limbs[i])
                    if limb then
                        limb.RagdollLimbPart.CanCollide = false
                    end
                end
            end)
        end
    end
})

-- // Anti Burn (Ragalic)
DefenseGroup:AddToggle("AntiBurnToggle", {
    Text = "Анти-огонь 🔥",
    Default = false,
    Callback = function(on)
        if on then
            local function hookBurn(char)
                local hum = char:WaitForChild("Humanoid")
                local hrp = char:WaitForChild("HumanoidRootPart")
                char.PrimaryPart = hrp
                if hookBurnConn then
                    hookBurnConn:Disconnect()
                end
                hookBurnConn = hum.FireDebounce.Changed:Connect(function(isBurning)
                    if isBurning then
                        local me = char
                        local oldCF = hrp.CFrame
                        local plots = workspace:FindFirstChild("Plots")
                        if plots and plots:FindFirstChild("Plot2") then
                            local plot2 = plots.Plot2
                            local barrier = plot2:FindFirstChild("Barrier")
                            local pb = barrier and barrier:FindFirstChild("PlotBarrier")
                            if pb and pb:IsA("BasePart") then
                                local safeCF = pb.CFrame * CFrame.new(0, 6, 0)
                                me:SetPrimaryPartCFrame(safeCF)
                                task.wait(0.3)
                                local firePart = me:FindFirstChild("FirePlayerPart", true)
                                if firePart then
                                    for _, obj in ipairs(firePart:GetChildren()) do
                                        if obj:IsA("Sound") then
                                            obj:Stop()
                                        end
                                        if obj:IsA("Light") or obj:IsA("ParticleEmitter") then
                                            obj.Enabled = false
                                        end
                                    end
                                    if firePart:FindFirstChild("CanBurn") then
                                        firePart.CanBurn.Value = false
                                    end
                                    if hum:FindFirstChild("FireDebounce") then
                                        hum.FireDebounce.Value = false
                                    end
                                end
                                task.wait(0.6)
                                if me and me.PrimaryPart then
                                    me:SetPrimaryPartCFrame(oldCF)
                                end
                            end
                        end
                    end
                end)
            end
            hookBurn(plr.Character)
        elseif hookBurnConn then
            hookBurnConn:Disconnect()
        end
    end
})

-- // Anti Void (Ragalic)
DefenseGroup:AddToggle("AntiVoidToggle", {
    Text = "Анти-пустота 🕳️",
    Default = false,
    Callback = function(on)
        if on then
            local VOID_THRESHOLD = -50
            local SAFE_HEIGHT = 100
            antiVoidConn = RunService.Heartbeat:Connect(function()
                local char = plr.Character
                if char and char.PrimaryPart then
                    local pos = char.PrimaryPart.Position
                    if pos.Y < VOID_THRESHOLD then
                        local safePos = Vector3.new(pos.X, pos.Y + SAFE_HEIGHT, pos.Z)
                        char:SetPrimaryPartCFrame(CFrame.new(safePos))
                        char.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
                    end
                end
            end)
        else
            if antiVoidConn then
                antiVoidConn:Disconnect()
                antiVoidConn = nil
            end
        end
    end
})

-- // Anti Paint (Ragalic)
DefenseExtra:AddToggle("PaintDeleteToggle", {
    Text = "Анти-краска 🎨",
    Default = false,
    Callback = function(state)
        local paintPartsBackup = {}
        local paintConnections = {}
        local function deleteAllPaintParts()
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") and obj.Name == "PaintPlayerPart" then
                    local clone = obj:Clone()
                    clone.Archivable = true
                    paintPartsBackup[obj:GetDebugId()] = {
                        clone = clone,
                        parent = obj.Parent
                    }
                    obj:Destroy()
                end
            end
        end
        local function restorePaintParts()
            for _, data in pairs(paintPartsBackup) do
                if data.clone and data.parent then
                    data.clone.Parent = data.parent
                end
            end
            paintPartsBackup = {}
        end
        local function watchNewPaintParts()
            table.insert(paintConnections, Workspace.DescendantAdded:Connect(function(obj)
                if obj:IsA("BasePart") and obj.Name == "PaintPlayerPart" then
                    task.defer(function()
                        if obj and obj.Parent then
                            local clone = obj:Clone()
                            clone.Archivable = true
                            paintPartsBackup[obj:GetDebugId()] = {
                                clone = clone,
                                parent = obj.Parent
                            }
                            obj:Destroy()
                        end
                    end)
                end
            end))
        end
        if state then
            deleteAllPaintParts()
            watchNewPaintParts()
        else
            restorePaintParts()
            for _, conn in ipairs(paintConnections) do
                if conn.Connected then
                    conn:Disconnect()
                end
            end
            paintConnections = {}
        end
    end
})

-- // Anti Gucci (Blobman) (Ragalic)
DefenseExtra:AddToggle("AutoGucciToggle", {
    Text = "Анти-Гуччи (Блобман) 🚗",
    Default = false,
    Callback = function(Value)
        _G.Bools.AutoGucci = Value
        local function spawnBlobman()
            local args = {
                [1] = "CreatureBlobman",
                [2] = CFrame.new(0, 5000000, 0),
                [3] = Vector3.new(0, 60, 0)
            }
            pcall(function()
                ReplicatedStorage.MenuToys.SpawnToyRemoteFunction:InvokeServer(unpack(args))
            end)
            local folder = Workspace:WaitForChild(plr.Name .. "SpawnedInToys", 5)
            if folder and folder:FindFirstChild("CreatureBlobman") then
                local blob = folder.CreatureBlobman
                if blob:FindFirstChild("Head") then
                    blob.Head.CFrame = CFrame.new(0, 50000, 0)
                    blob.Head.Anchored = true
                end
                Notify("Успех ✅", "Блобман создан!", 3)
            end
        end
        local function startAntiGucci()
            local character = plr.Character or plr.CharacterAdded:Wait()
            local humanoid = character:WaitForChild("Humanoid")
            local rootPart = character:WaitForChild("HumanoidRootPart")
            local safePosition = rootPart.Position
            local folder = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
            local blob = folder and folder:FindFirstChild("CreatureBlobman")
            local seat = blob and blob:FindFirstChild("VehicleSeat")
            if not blob then
                spawnBlobman()
                task.wait(1)
                folder = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                blob = folder and folder:FindFirstChild("CreatureBlobman")
                seat = blob and blob:FindFirstChild("VehicleSeat")
            end
            if seat and seat:IsA("VehicleSeat") then
                rootPart.CFrame = seat.CFrame + Vector3.new(0, 2, 0)
                seat:Sit(humanoid)
            end
            humanoid:GetPropertyChangedSignal("Jump"):Connect(function()
                if humanoid.Jump and humanoid.Sit then
                    restoreFrames = 15
                    safePosition = rootPart.Position
                end
            end)
            if antiGucciConnection then
                antiGucciConnection:Disconnect()
            end
            antiGucciConnection = RunService.Heartbeat:Connect(function()
                if not rootPart or not humanoid then
                    return
                end
                ReplicatedStorage.CharacterEvents.RagdollRemote:FireServer(rootPart, 0)
                if restoreFrames > 0 then
                    rootPart.CFrame = CFrame.new(safePosition)
                    restoreFrames = restoreFrames - 1
                end
            end)
            task.spawn(function()
                while humanoid.Sit do
                    task.wait(1)
                end
                task.wait(0.5)
                rootPart.CFrame = CFrame.new(safePosition)
            end)
        end
        local function stopAntiGucci()
            if antiGucciConnection then
                antiGucciConnection:Disconnect()
                antiGucciConnection = nil
            end
            local blobFolder = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
            if blobFolder and blobFolder:FindFirstChild("CreatureBlobman") then
                blobFolder.CreatureBlobman:Destroy()
            end
        end

        if Value then
            startAntiGucci()
            Notify("Система ⚙️", "Анти-Гуччи активирован!", 3)
            task.spawn(function()
                while _G.Bools.AutoGucci do
                    local toysFolder = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                    local blobExists = toysFolder and toysFolder:FindFirstChild("CreatureBlobman")
                    if not blobExists then
                        stopAntiGucci()
                        spawnBlobman()
                        Notify("Система ⚙️", "Блобман потерян!", 3)
                        local retries = 0
                        repeat
                            task.wait(0.2)
                            retries = retries + 1
                            toysFolder = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                        until (toysFolder and toysFolder:FindFirstChild("CreatureBlobman")) or retries > 25 or not _G.Bools.AutoGucci
                        if _G.Bools.AutoGucci and toysFolder and toysFolder:FindFirstChild("CreatureBlobman") then
                            startAntiGucci()
                            Notify("Система ⚙️", "Блобман восстановлен!", 3)
                        end
                    end
                    task.wait(0.5)
                end
            end)
        else
            stopAntiGucci()
            Notify("Система ⚙️", "Анти-Гуччи отключен!", 3)
        end
    end
})

-- // Anti Input Lag (Ragalic)
DefenseExtra:AddToggle("AntiInputLag", {
    Text = "Анти-задержка ввода ⌨️",
    Default = false,
    Callback = function(Value)
        _G.Bools.AntiInputLag = Value
        if Value then
            task.spawn(function()
                local Players = game:GetService("Players")
                local ReplicatedStorage = game:GetService("ReplicatedStorage")
                local Workspace = game:GetService("Workspace")
                local RunService = game:GetService("RunService")
                local plr = Players.LocalPlayer
                local char = plr.Character or plr.CharacterAdded:Wait()
                local hrp = char:WaitForChild("HumanoidRootPart")
                local SpawnRemote = ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("SpawnToyRemoteFunction")
                local SelectedToy = "FoodHamburger" -- Можно добавить дропдаун для выбора
                while _G.Bools.AntiInputLag do
                    local toysFolder = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                    if not toysFolder then
                        task.wait(0.1)
                        continue
                    end
                    local toy = toysFolder:FindFirstChild(SelectedToy)
                    if not toy then
                        pcall(function()
                            SpawnRemote:InvokeServer(
                                SelectedToy,
                                hrp.CFrame * CFrame.new(0, 5, 0),
                                Vector3.zero
                            )
                        end)
                        local t0 = tick()
                        repeat
                            RunService.Heartbeat:Wait()
                            toysFolder = Workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                            toy = toysFolder and toysFolder:FindFirstChild(SelectedToy)
                        until toy or tick() - t0 > 1 or not _G.Bools.AntiInputLag
                    end
                    if toy and toy.Parent then
                        local holdPart = toy:FindFirstChild("HoldPart")
                        if holdPart then
                            local holdingPlayer = holdPart:FindFirstChild("HoldingPlayer")
                            holdingPlayer = holdingPlayer and holdingPlayer.Value
                            if holdingPlayer and holdingPlayer ~= plr then
                                pcall(function()
                                    holdPart.DropItemRemoteFunction:InvokeServer(
                                        toy,
                                        hrp.CFrame * CFrame.new(0, 2000, 0),
                                        Vector3.zero
                                    )
                                end)
                                toy:Destroy()
                            else
                                pcall(function()
                                    holdPart.HoldItemRemoteFunction:InvokeServer(toy, char)
                                end)
                                task.wait(0.05)
                                pcall(function()
                                    holdPart.DropItemRemoteFunction:InvokeServer(
                                        toy,
                                        hrp.CFrame * CFrame.new(0, 2000, 0),
                                        Vector3.zero
                                    )
                                end)
                                task.wait(0.01)
                            end
                        end
                    end
                    RunService.Heartbeat:Wait()
                end
            end)
        end
    end
})

-- // Anti Kick (Shuriken) из NoName
DefenseExtra:AddToggle("ShurikenAntiKick", {
    Text = "Анти-кик (Сюрикен) 🥷",
    Default = false,
    Callback = function(Value)
        _G.Bools.ShurikenAntiKick = Value
        local function ClearKunai()
            local plr = game.Players.LocalPlayer
            local inv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
            local destroyrem = game.ReplicatedStorage:FindFirstChild("MenuToys") and game.ReplicatedStorage.MenuToys:FindFirstChild("DestroyToy")
            if inv and destroyrem then
                for _, v in pairs(inv:GetChildren()) do
                    if v.Name == "AntiKick" or v.Name == "NinjaShuriken" then
                        pcall(function()
                            destroyrem:FireServer(v)
                        end)
                    end
                end
            end
        end
        if Value then
            task.spawn(function()
                local plr = game.Players.LocalPlayer
                local ReplicatedStorage = game:GetService("ReplicatedStorage")
                local setOwner = ReplicatedStorage:WaitForChild("GrabEvents"):WaitForChild("SetNetworkOwner")
                local stickyEvent = ReplicatedStorage:WaitForChild("PlayerEvents"):WaitForChild("StickyPartEvent")
                local spawnRemote = ReplicatedStorage.MenuToys.SpawnToyRemoteFunction
                local destroyrem = ReplicatedStorage:WaitForChild("MenuToys"):WaitForChild("DestroyToy")
                local canSpawn = plr:WaitForChild("CanSpawnToy")
                local function getHRP()
                    if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                        return plr.Character.HumanoidRootPart
                    else
                        local character = plr.CharacterAdded:Wait()
                        return character:WaitForChild("HumanoidRootPart")
                    end
                end
                local function CheckForHome()
                    if not workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then
                        return false
                    end
                    for _, v in pairs(workspace.Plots:GetChildren()) do
                        local sign = v:FindFirstChild("PlotSign")
                        local owners = sign and sign:FindFirstChild("ThisPlotsOwners")
                        if owners then
                            for _, b in pairs(owners:GetChildren()) do
                                if b.Value == plr.Name then
                                    local folder = workspace.PlotItems:FindFirstChild(v.Name)
                                    if folder then
                                        return true, folder
                                    end
                                end
                            end
                        end
                    end
                    return false
                end
                local function StickKunai(kunai)
                    if not kunai or not kunai:FindFirstChild("StickyPart") then
                        return
                    end
                    local currentHRP = getHRP()
                    if not currentHRP then
                        return
                    end
                    if kunai:FindFirstChild("SoundPart") then
                        if not kunai.SoundPart:FindFirstChild("PartOwner") or kunai.SoundPart.PartOwner.Value ~= plr.Name then
                            setOwner:FireServer(kunai.SoundPart, kunai.SoundPart.CFrame)
                        end
                    end
                    local firePart = currentHRP:FindFirstChild("FirePlayerPart") or currentHRP:WaitForChild("FirePlayerPart", 5)
                    if firePart then
                        stickyEvent:FireServer(
                            kunai.StickyPart,
                            firePart,
                            CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(90), math.rad(90))
                        )
                    end
                    for _, obj in pairs(kunai:GetChildren()) do
                        if obj.Name == "Pyramid" then
                            obj.CanTouch = false;
                            obj.CanCollide = false;
                            obj.CanQuery = false;
                            obj.Transparency = 0
                            if not obj:FindFirstChild("Highlight") then
                                local high = Instance.new("Highlight", obj)
                                high.FillColor = Color3.fromRGB(0, 0, 0)
                            end
                        elseif obj.Name == "Main" then
                            obj.CanTouch = false;
                            obj.CanCollide = false;
                            obj.CanQuery = false;
                            obj.Transparency = 0
                            if not obj:FindFirstChild("Highlight") then
                                local high = Instance.new("Highlight", obj)
                                high.FillColor = Color3.fromRGB(255, 255, 255)
                            end
                        elseif obj:IsA("BasePart") then
                            obj.CanTouch = false;
                            obj.CanCollide = false;
                            obj.CanQuery = false;
                            obj.Transparency = 1
                        end
                    end
                end
                local function SpawnToy(name)
                    local t = tick()
                    while not canSpawn.Value do
                        if not _G.Bools.ShurikenAntiKick or tick() - t > 5 then
                            return nil
                        end
                        task.wait(0.1)
                    end
                    local currentHRP = getHRP()
                    if currentHRP then
                        task.spawn(function()
                            pcall(function()
                                spawnRemote:InvokeServer(name, currentHRP.CFrame * CFrame.new(0, 12, 20), Vector3.new(0, 0, 0))
                            end)
                        end)
                    end
                    local boolik, house = CheckForHome()
                    local inv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                    if boolik and house then
                        return house:WaitForChild(name, 2)
                    elseif not workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) and inv then
                        return inv:WaitForChild(name, 2)
                    end
                    return nil
                end
                while _G.Bools.ShurikenAntiKick do
                    task.wait(0.005)
                    if not plr.Character or not plr.Character:FindFirstChild("Humanoid") or plr.Character.Humanoid.Health <= 0 then
                        continue
                    end
                    local inv = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
                    local kunai = inv and inv:FindFirstChild("NinjaShuriken")
                    if workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then
                        local boolik, house = CheckForHome()
                        if boolik and house and workspace.Plots:FindFirstChild(house.Name) then
                            local sign = workspace.Plots[house.Name]:FindFirstChild("PlotSign")
                            if sign and sign.ThisPlotsOwners.Value.TimeRemainingNum.Value > 89 then
                                kunai = SpawnToy("NinjaShuriken")
                                if kunai == nil then
                                    continue
                                end
                                kunai.Name = "AntiKick"
                                StickKunai(kunai)
                            end
                        end
                    end
                    if not kunai then
                        if workspace.PlotItems.PlayersInPlots:FindFirstChild(plr.Name) then
                            continue
                        end
                        kunai = SpawnToy("NinjaShuriken")
                        if kunai == nil then
                            continue
                        end
                        kunai.Name = "AntiKick"
                        if not kunai then
                            continue
                        end
                    end
                    repeat
                        if kunai and kunai:FindFirstChild("StickyPart") and kunai.StickyPart.CanTouch == true then
                            StickKunai(kunai)
                            kunai.Name = "AntiKick"
                        end
                        task.wait(0.3)
                    until not kunai or not _G.Bools.ShurikenAntiKick or not kunai:FindFirstChild("StickyPart") or kunai.StickyPart.CanTouch == false or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") or not kunai:FindFirstChild("StickyPart") or (plr.Character.HumanoidRootPart.Position - kunai.StickyPart.Position).Magnitude >= 20
                    if not kunai or not kunai:FindFirstChild("StickyPart") or not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") or (plr.Character.HumanoidRootPart.Position - kunai.StickyPart.Position).Magnitude >= 20 then
                        ClearKunai()
                    end
                    pcall(function()
                        repeat
                            task.wait(0.05)
                        until not _G.Bools.ShurikenAntiKick or not plr.Character or not plr.Character:FindFirstChild("Humanoid") or not kunai or not kunai:FindFirstChild("StickyPart") or not kunai.StickyPart:FindFirstChild("StickyWeld") or not kunai.StickyPart.StickyWeld.Part1
                        if not kunai or not kunai:FindFirstChild("StickyPart") or (plr.Character and plr.Character:FindFirstChild("Humanoid") and plr.Character.Humanoid.Health <= 0) or not kunai["StickyPart"]:FindFirstChild("StickyWeld").Part1 then
                            ClearKunai()
                        end
                    end)
                end
            end)
        else
            ClearKunai()
        end
    end
})

-- // Anti Loop Kill (Loop TP) из NoName
DefenseExtra:AddToggle("LoopTP", {
    Text = "Петля-телепорт 🔄",
    Default = false,
    Callback = function(Value)
        _G.Bools.LoopTpRandom = Value
        task.spawn(function()
            if _G.Bools.LoopTpRandom then
                local char = plr.Character
                local oldCF = char:GetPivot()
                while _G.Bools.LoopTpRandom do
                    for _, CF in pairs(etc.MapPoints) do
                        char = plr.Character
                        if not char then
                            while not plr.Character do
                                task.wait()
                            end
                            char = plr.Character
                        end
                        char:PivotTo(CF)
                        task.wait(0.1)
                    end
                end
                StopAllVelocity(char)
            end
        end)
    end
})

-- // --- ВКЛАДКА "ЦЕЛЬ 🎯" (Из Ragalic + NoName + новое) ---
local TargetGroup = Tabs.Target:AddLeftGroupbox("Взаимодействие с целью 🎯")
local KickGroup = Tabs.Target:AddRightGroupbox("Кики 🦵")
local KillGroup = Tabs.Target:AddRightGroupbox("Киллы 💀")

local selectedKickPlayer = nil
local options, playerMap = BuildPlayerOptions()

-- // Выбор цели
TargetGroup:AddDropdown("KickPlayerDropdown", {
    Values = options,
    Default = 1,
    Multi = false,
    Text = "Выберите игрока для цели 👤",
    Callback = function(Value)
        local chosenPlayer = playerMap[Value]
        selectedKickPlayer = chosenPlayer and chosenPlayer.Name or nil
    end,
})

TargetGroup:AddButton({
    Text = "Обновить список игроков 🔄",
    Func = function()
        options, playerMap = BuildPlayerOptions()
        Options.KickPlayerDropdown:SetValues(options)
        Options.KickPlayerDropdown:SetValue(nil)
        selectedKickPlayer = nil
    end
})

-- // Поиск по нику
TargetGroup:AddTextbox({
    Name = "Найти по нику 🔍",
    Default = "",
    TextDisappear = true,
    Callback = function(Value)
        if Value == "" then
            return
        end
        Value = Value:lower()

        for _, plr1 in pairs(game.Players:GetPlayers()) do
            local nameMatch = string.sub(plr1.Name:lower(), 1, #Value) == Value
            local displayMatch = string.sub(plr1.DisplayName:lower(), 1, #Value) == Value

            if nameMatch or displayMatch then
                local displayString = string.format(
                    '<font color="rgb(255,0,0)"><b>%s</b></font> <b><i>(%s)</i></b>',
                    plr1.Name,
                    plr1.DisplayName
                )
                selectedKickPlayer = plr1.Name
                Options.KickPlayerDropdown:SetValue(displayString)
                break
            end
        end
    end
})

-- // --- КИКИ (Из NoName) ---

-- // 1. Простой кик
KickGroup:AddButton({
    Name = "Кик (Простой) 🦵",
    Func = function()
        BringRight(selectedKickPlayer)
        task.wait(0.1)
        DropRight(selectedKickPlayer)
    end
})

-- // 2. Кик с блобом
KickGroup:AddButton({
    Name = "Кик (Блоб) 🧌",
    Func = function()
        local blob = FindBlob()
        local oldCF = char:GetPivot()
        local Root = selectedKickPlayer and Players[selectedKickPlayer] and Players[selectedKickPlayer].Character and Players[selectedKickPlayer].Character:FindFirstChild("HumanoidRootPart")

        if not Root then
            return
        end
        if not blob then
            blob = SpawnToy("CreatureBlobman")
            if not blob then
                return
            end
            local Seat = FWD(blob, "VehicleSeat")
            Seat:Sit(hum)
            while Seat.Occupant ~= hum do
                task.wait()
            end
        end

        local RightDetector, RightWeld = blob and blob.RightDetector, blob and blob.RightDetector and blob.RightDetector.RightWeld
        local CreatureGrab, CreatureDrop, CreatureRelease = blob and blob.BlobmanSeatAndOwnerScript.CreatureGrab, blob and blob.BlobmanSeatAndOwnerScript.CreatureDrop, blob and blob.BlobmanSeatAndOwnerScript.CreatureRelease

        if not RightDetector or not RightWeld or not CreatureGrab or not CreatureDrop or not CreatureRelease then
            return
        end

        repeat
            char:PivotTo(Root.CFrame * CFrame.new(0, 10, 5) * CFrame.new(Root.AssemblyLinearVelocity * 0.4))
            CreatureGrab:FireServer(RightDetector, Root, RightWeld)
            task.wait(0.05)
        until RightWeld.Attachment0 or not hum.SeatPart

        if RightWeld.Attachment0 then
            CreatureRelease:FireServer(RightWeld, Root)
            if isnetworkowner(Root) then
                for _, v in pairs(Root.Parent:GetChildren()) do
                    if v:IsA("BasePart") then
                        v.CFrame = oldCF * CFrame.new(0, 20, 0)
                    end
                end
            end
            char:PivotTo(oldCF)
            while not CheckNetworkOwnerOnPlayer(_, Root) and RunService.Stepped:Wait() and hum.SeatPart do
                sno(Root)
            end
            Root.Parent:PivotTo(oldCF * CFrame.new(0, 20, 0))
            StopAllVelocity(Root.Parent)
            repeat
                CreatureGrab:FireServer(RightDetector, Root, RightWeld)
                task.wait(0.05)
            until RightWeld.Attachment0 or not hum.SeatPart
            for _ = 1, 5 do
                unsno(Root)
            end
            DestroyToy:FireServer(blob)
            etc.LastBlob = nil
        end
    end
})

-- // 3. Кик с SNO + Блоб
KickGroup:AddButton({
    Name = "Кик (SNO + Блоб) 📡",
    Func = function()
        local blob = FindBlob()
        local oldCF = char:GetPivot()
        local Root = selectedKickPlayer and Players[selectedKickPlayer] and Players[selectedKickPlayer].Character and Players[selectedKickPlayer].Character:FindFirstChild("HumanoidRootPart")

        if not Root then
            return
        end
        if not blob then
            blob = SpawnToy("CreatureBlobman")
            if not blob then
                return
            end
            local Seat = FWD(blob, "VehicleSeat")
            Seat:Sit(hum)
            while Seat.Occupant ~= hum do
                task.wait()
            end
        end

        local RightDetector, RightWeld, CreatureGrab = blob and blob.RightDetector, blob and blob.RightDetector and blob.RightDetector.RightWeld, blob and blob.BlobmanSeatAndOwnerScript.CreatureGrab
        local BodyPos = Instance.new("BodyPosition")
        BodyPos.Name = ("BlobSnoKickBodyPos")
        BodyPos.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        BodyPos.Position = Root.Position + Vector3.new(0, 20, 0)
        BodyPos.Parent = Root
        BodyPos.P = 45000
        BodyPos.D = 500

        repeat
            task.wait(0.05)
            blob:PivotTo(Root.CFrame * CFrame.new(0, 5, 5))
            sno(Root)
        until (not hum or not hum.SeatPart or not Root) or CheckForPartOwner(Players[selectedKickPlayer].Character.Head)

        for i = 1, 10 do
            task.wait(0.01)
            sno(Root)
        end

        task.defer(StopAllVelocity, blob)
        unsno(Root)
        blob:PivotTo(Root.CFrame)

        repeat
            CreatureGrab:FireServer(RightDetector, Root, RightWeld)
            task.wait(0.05)
        until blob.RightDetector.RightWeld.Attachment0 or not hum.SeatPart

        blob:PivotTo(oldCF)
        Debris:AddItem(BodyPos, 1)
        DestroyToy:FireServer(blob)
        etc.LastBlob = nil
    end
})

-- // 4. Петля-кик (Из NoName - LoopKick)
KickGroup:AddToggle("LoopKickToggle", {
    Text = "Петля-кик (Grab + Блоб) 🔄",
    Default = false,
    Callback = function(on)
        _G.Bools.LoopKick = on
        if on then
            task.spawn(function()
                local RS = game:GetService("ReplicatedStorage")
                local GE = RS:WaitForChild("GrabEvents")
                local RunService = game:GetService("RunService")
                local target = selectedKickPlayer
                if not target then
                    Toggles.LoopKickToggle:SetValue(false)
                    return
                end
                local char = plr.Character
                local hum = char and char:FindFirstChild("Humanoid")
                local seat = hum and hum.SeatPart
                if not seat or seat.Parent.Name ~= "CreatureBlobman" then
                    Toggles.LoopKickToggle:SetValue(false)
                    return
                end
                local blob = seat.Parent
                local blobRoot = blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
                local scriptObj = blob:FindFirstChild("BlobmanSeatAndOwnerScript")
                local CG = scriptObj and scriptObj:FindFirstChild("CreatureGrab")
                local CD = scriptObj and scriptObj:FindFirstChild("CreatureDrop")
                local R_Det = blob:FindFirstChild("RightDetector")
                local R_Weld = R_Det and (R_Det:FindFirstChild("RightWeld") or R_Det:FindFirstChildWhichIsA("Weld"))
                local SavedPos = blobRoot.CFrame
                local tChar = Players[target].Character
                local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                if tRoot and blobRoot then
                    local bringStart = tick()
                    while tick() - bringStart < 0.35 do
                        if not _G.Bools.LoopKick then
                            break
                        end
                        blobRoot.CFrame = tRoot.CFrame
                        blobRoot.Velocity = Vector3.zero
                        pcall(function()
                            if CG and R_Det then
                                CG:FireServer(R_Det, tRoot, R_Weld)
                            end
                            GE.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false)
                            GE.SetNetworkOwner:FireServer(tRoot, blobRoot.CFrame)
                        end)
                        RunService.Heartbeat:Wait()
                    end
                    blobRoot.CFrame = SavedPos
                    blobRoot.Velocity = Vector3.zero
                    task.wait(0.05)
                end
                local packetTimer = 0
                while _G.Bools.LoopKick do
                    if not target or not Players[target] or not Players[target].Character then
                        break
                    end
                    local tChar = Players[target].Character
                    local tRoot = tChar and tChar:FindFirstChild("HumanoidRootPart")
                    local tHum = tChar and tChar:FindFirstChild("Humanoid")
                    if tRoot and tHum and tHum.Health > 0 and blobRoot then
                        blobRoot.CFrame = SavedPos
                        blobRoot.Velocity = Vector3.zero
                        local lockPos = SavedPos * CFrame.new(0, 23, 0)
                        tRoot.CFrame = lockPos
                        tRoot.Velocity = Vector3.zero
                        tRoot.RotVelocity = Vector3.zero
                        if tick() - packetTimer > 0.05 then
                            packetTimer = tick()
                            pcall(function()
                                tHum.PlatformStand = true
                                tHum.Sit = true
                                GE.SetNetworkOwner:FireServer(tRoot, lockPos)
                                if R_Det then
                                    local weld = R_Det:FindFirstChild("RightWeld") or R_Det:FindFirstChildWhichIsA("Weld")
                                    if weld then
                                        CD:FireServer(weld)
                                    end
                                end
                                GE.DestroyGrabLine:FireServer(tRoot)
                                if R_Det then
                                    CG:FireServer(R_Det, tRoot, R_Weld)
                                end
                                GE.CreateGrabLine:FireServer(tRoot, Vector3.zero, tRoot.Position, false)
                            end)
                        end
                    else
                        blobRoot.CFrame = SavedPos
                        blobRoot.Velocity = Vector3.zero
                    end
                    if not _G.Bools.LoopKick then
                        break
                    end
                    RunService.Heartbeat:Wait()
                end
                _G.Bools.LoopKick = false
                Toggles.LoopKickToggle:SetValue(false)
                if blobRoot then
                    blobRoot.CFrame = SavedPos
                    blobRoot.Velocity = Vector3.zero
                end
            end)
        end
    end
})

-- // 5. Петля-кик с двумя руками (Из NoName - DualHandLoopKick)
KickGroup:AddToggle("DualHandLoopKick", {
    Text = "Петля-кик (Две руки) ✋✋",
    Default = false,
    Callback = function(on)
        _G.Bools.DualHandLoopKick = on
        if on then
            if not selectedKickPlayer then
                Notify("Ошибка ❌", "Сначала выберите цель!", 3)
                Toggles.DualHandLoopKick:SetValue(false)
                return
            end
            task.spawn(function()
                local target = selectedKickPlayer
                local char = plr.Character
                local hum = char and char:FindFirstChild("Humanoid")
                local seat = hum and hum.SeatPart
                while _G.Bools.DualHandLoopKick do
                    if not seat or not target or not Players[target] then
                        task.wait(0.5)
                        continue
                    end
                    local seatParent = seat.Parent
                    local grab = seatParent:FindFirstChild("BlobmanSeatAndOwnerScript") and seatParent.BlobmanSeatAndOwnerScript:FindFirstChild("CreatureGrab")
                    local drop = seatParent:FindFirstChild("BlobmanSeatAndOwnerScript") and seatParent.BlobmanSeatAndOwnerScript:FindFirstChild("CreatureDrop")
                    if not grab or not drop then
                        task.wait(0.5)
                        continue
                    end
                    local leftDet = seatParent:FindFirstChild("LeftDetector")
                    local rightDet = seatParent:FindFirstChild("RightDetector")
                    local leftWeld = leftDet and leftDet:FindFirstChild("LeftWeld")
                    local rightWeld = rightDet and rightDet:FindFirstChild("RightWeld")
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    local targetChar = Players[target].Character
                    local targetHRP = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
                    local targetHum = targetChar and targetChar:FindFirstChild("Humanoid")
                    if targetHRP and targetHum and targetHum.Health > 0 then
                        grab:FireServer(leftDet, targetHRP, leftWeld)
                        task.wait()
                        drop:FireServer(leftWeld, targetHRP)
                        task.wait()
                        grab:FireServer(rightDet, targetHRP, rightWeld)
                        task.wait()
                        drop:FireServer(rightWeld, targetHRP)
                        task.wait()
                        grab:FireServer(leftDet, targetHRP, leftWeld)
                        grab:FireServer(rightDet, targetHRP, rightWeld)
                        task.wait()
                        drop:FireServer(leftWeld, targetHRP)
                        drop:FireServer(rightWeld, targetHRP)
                        task.wait()
                    else
                        task.wait(0.1)
                    end
                end
            end)
        end
    end
})

-- // 6. Уничтожение Гуччи (Из NoName)
KickGroup:AddButton({
    Name = "Уничтожить Гуччи (Блоб) 🚗",
    Func = function()
        local blob = FindBlob() or SpawnToy("CreatureBlobman")
        if not blob then
            return
        end
        local oldCF = char:GetPivot()
        local TargetPLR = selectedKickPlayer and Players[selectedKickPlayer]
        if not TargetPLR then
            return
        end
        local Root, Hum = TargetPLR.Character:FindFirstChild("HumanoidRootPart"), TargetPLR.Character:FindFirstChild("Humanoid")
        if not Root or not Hum then
            return
        end
        Root.Massless = false
        FWD(blob, "VehicleSeat"):Sit(hum)
        while not hum.SeatPart do
            task.wait()
        end
        local CreatureGrab = FWD(FWD(blob, "BlobmanSeatAndOwnerScript"), "CreatureGrab")
        local CreatureRelease = FWD(FWD(blob, "BlobmanSeatAndOwnerScript"), "CreatureRelease")
        local RightDetector = FWD(blob, "RightDetector")
        local RightWeld = RightDetector and FWD(RightDetector, "RightWeld")
        blob:PivotTo(Root.CFrame)
        task.wait(0.15)
        for _ = 1, 15 do
            CreatureGrab:FireServer(RightDetector, Root, RightWeld)
            CreatureRelease:FireServer(RightWeld, Root)
            Root.Massless = false
            for _ = 1, 10 do
                Hum.Sit = true
            end
            task.wait()
        end
        char:PivotTo(oldCF)
    end
})

-- // 7. Уничтожение Гуччи (Прыжок/Сидение)
KickGroup:AddButton({
    Name = "Уничтожить Гуччи (Прыжок/Сидение) 🏃",
    Func = function()
        local blobs = {}
        local hum = FWD(char, "Humanoid")
        local oldCF = char:GetPivot()
        local TarInv = workspace:FindFirstChild(selectedKickPlayer .. "SpawnedInToys")
        if TarInv then
            for _, v in pairs(TarInv:GetChildren()) do
                if v.Name == "CreatureBlobman" or v.Name:sub(1, 7) == "Tractor" then
                    table.insert(blobs, v)
                end
            end
        end
        for _, plot in pairs(workspace.Plots:GetChildren()) do
            for _, owner in pairs(plot.PlotSign.ThisPlotsOwners:GetChildren()) do
                if owner.Value == selectedKickPlayer then
                    local toyFolder = workspace.PlotItems:FindFirstChild(plot.Name)
                    if toyFolder then
                        for _, v in pairs(toyFolder:GetChildren()) do
                            if v.Name == "CreatureBlobman" or v.Name:sub(1, 7) == "Tractor" then
                                table.insert(blobs, v)
                            end
                        end
                    end
                end
            end
        end
        if #blobs == 0 then
            return
        end
        for _, v in pairs(blobs) do
            for i = 1, 2 do
                local seat = v:FindFirstChild("VehicleSeat")
                if seat then
                    seat:Sit(hum)
                    while not seat.Occupant do
                        task.wait()
                    end
                    char:PivotTo(oldCF)
                    hum:ChangeState(Enum.HumanoidStateType.Jumping)
                    task.defer(StopAllVelocity, char)
                    task.wait(0.1)
                else
                    break
                end
            end
            StopAllVelocity(char)
            char:PivotTo(oldCF)
        end
    end
})

-- // --- КИЛЛЫ (Из NoName) ---

-- // Функции для киллов
_G.IsAboveLimit = function(Player)
    if Player and Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        return Player.Character.HumanoidRootPart.Position.Y > 10000
    end
    return true
end

_G.DisableCollisions = function(Character)
    for _, Desc in pairs(Character:GetDescendants()) do
        if Desc:IsA("BasePart") then
            Desc.CanCollide = false
        end
    end
end

_G.ForceDeath = function(Root, Humanoid)
    for _, Part in pairs(Humanoid.Parent:GetChildren()) do
        if Part:IsA("BasePart") then
            Part.CFrame = CFrame.new(-999999999999, 9999999999999, -999999999999)
        end
    end
    task.wait()
    for _, Part2 in pairs(Humanoid.Parent:GetChildren()) do
        if Part2:IsA("BasePart") then
            Part2.CFrame = CFrame.new(-999999999999, 9999999999999, -999999999999)
        end
    end
    local BV = Instance.new("BodyVelocity")
    BV.Velocity = Vector3.new(0, 99999999999, 0)
    BV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    BV.P = 100000075
    BV.Parent = Root
    Humanoid.Sit = false
    Humanoid.Jump = true
    Humanoid.BreakJointsOnDeath = false
    Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
    task.delay(2, function()
        if BV and BV.Parent then
            BV:Destroy()
        end
        BV = nil
    end)
end

_G.ExecuteKill = function(Player)
    if not _G.Bools.LoopKill or not Player or not Player.Character then
        return
    end
    if Workspace.PlotItems.PlayersInPlots:FindFirstChild(Player.Name) then
        return
    end

    local Char = Player.Character
    local Root = Char:FindFirstChild("HumanoidRootPart")
    local Head = Char:FindFirstChild("Head")
    local Humanoid = Char:FindFirstChild("Humanoid")
    if not (Root and Head and Humanoid) or Humanoid.Health <= 0 or _G.IsAboveLimit(Player) then
        return
    end

    local SelfChar = Players.LocalPlayer.Character
    if not SelfChar or not SelfChar:FindFirstChild("HumanoidRootPart") then
        return
    end

    pcall(function()
        if not _G.Bools.LoopKill then
            return
        end
        local SavedCFrame = SelfChar:GetPivot()
        SelfChar:PivotTo(CFrame.new(Root.Position + Vector3.new(5, -18.5, 0)))
        _G.DisableCollisions(Char)
        ReplicatedStorage.GrabEvents.SetNetworkOwner:FireServer(Root, Root.CFrame)
        task.wait()
        SelfChar:PivotTo(SavedCFrame)
        task.wait(0.1)
        ReplicatedStorage.GrabEvents.DestroyGrabLine:FireServer(Root)
        task.wait(0.1)
        if Head:FindFirstChild("PartOwner") and Head.PartOwner.Value == Players.LocalPlayer.Name then
            _G.ForceDeath(Root, Humanoid)
        end
    end)
    task.wait(0.1)
end

-- // Петля-килл (SNO)
KillGroup:AddToggle("LoopKillSNO", {
    Text = "Петля-килл (SNO) 💀",
    Default = false,
    Callback = function(Value)
        _G.Bools.LoopKill = Value
        if Value then
            local LoopKillConnection
            LoopKillConnection = RunService.Heartbeat:Connect(function()
                if _G.Bools.LoopKill then
                    local Player = selectedKickPlayer and Players[selectedKickPlayer]
                    if Player then
                        _G.ExecuteKill(Player)
                    end
                else
                    if LoopKillConnection then
                        LoopKillConnection:Disconnect()
                        LoopKillConnection = nil
                    end
                end
            end)
        end
    end
})

-- // Петля-килл (Блоб)
KillGroup:AddToggle("LoopKillBlob", {
    Text = "Петля-килл (Блоб) 🧌",
    Default = false,
    Callback = function(Value)
        _G.Bools.BypassAntiBlob1 = Value
        if Value then
            task.spawn(function()
                local TargetPLR = selectedKickPlayer and Players[selectedKickPlayer]
                local Root = TargetPLR and TargetPLR.Character:FindFirstChild("HumanoidRootPart")
                local Hum = TargetPLR and TargetPLR.Character:FindFirstChild("Humanoid")
                local oldCF = char:GetPivot()
                local blob = FindBlob() or SpawnToy("CreatureBlobman")
                FWD(blob, "VehicleSeat"):Sit(hum)
                local CreatureGrab = FWD(FWD(blob, "BlobmanSeatAndOwnerScript"), "CreatureGrab")
                local CreatureRelease = FWD(FWD(blob, "BlobmanSeatAndOwnerScript"), "CreatureRelease")
                local RightDetector = FWD(blob, "RightDetector")
                local RightWeld = RightDetector and FWD(RightDetector, "RightWeld")
                while not hum.SeatPart do
                    task.wait()
                end
                task.spawn(function()
                    while _G.Bools.BypassAntiBlob1 and task.wait() do
                        oldCF = char:GetPivot()
                        Root = TargetPLR and TargetPLR.Character and TargetPLR.Character:FindFirstChild("HumanoidRootPart")
                        Hum = TargetPLR and TargetPLR.Character:FindFirstChild("Humanoid")
                        if (not Root or not Hum) or _G.IsAboveLimit(TargetPLR) or Hum.Health == 0 then
                            continue
                        end
                        while not RightWeld.Attachment0 and _G.Bools.BypassAntiBlob1 do
                            task.wait(0.05)
                            Root = TargetPLR and TargetPLR.Character and TargetPLR.Character:FindFirstChild("HumanoidRootPart")
                            Hum = TargetPLR and TargetPLR.Character:FindFirstChild("Humanoid")
                            if (not Root or not Hum) or _G.IsAboveLimit(TargetPLR) or Hum.Health == 0 then
                                char:PivotTo(oldCF)
                                break
                            end
                            if not hum.SeatPart then
                                inv:FindFirstChild("CreatureBlobman").VehicleSeat:Sit(hum)
                            end
                            char:PivotTo(Root.CFrame)
                            hrp.AssemblyLinearVelocity = Vector3.zero
                            hrp.AssemblyAngularVelocity = Vector3.zero
                            CreatureGrab:FireServer(RightDetector, Root, RightWeld)
                        end
                        CreatureRelease:FireServer(RightWeld, Root)
                        char:PivotTo(Root.CFrame)
                        for _ = 1, 10 do
                            hrp.AssemblyLinearVelocity = Vector3.zero
                            hrp.AssemblyAngularVelocity = Vector3.zero
                            CreatureGrab:FireServer(RightDetector, Root, RightWeld)
                            CreatureRelease:FireServer(RightWeld, Root)
                            if isnetworkowner(Root) then
                                ForceDeathNotG(Hum)
                            end
                            task.wait()
                        end
                        char:PivotTo(oldCF)
                        hrp.AssemblyLinearVelocity = Vector3.zero
                        hrp.AssemblyAngularVelocity = Vector3.zero
                    end
                end)
            end)
        end
    end
})

-- // --- ВКЛАДКА "ХВАТКА ✊" (Из Ragalic + NoName) ---
local GrabGroup = Tabs.Grab:AddLeftGroupbox("Настройки хватки ✊")

-- // Сила броска (Ragalic)
_G.strength = 750
GrabGroup:AddSlider("ThrowPowerSlider", {
    Text = "Сила броска 💪",
    Default = 750,
    Min = 1,
    Max = 20000,
    Rounding = 0,
    Callback = function(value)
        _G.strength = value
    end
})

-- // Супер-сила (NoName)
GrabGroup:AddToggle("SuperStrengthToggle", {
    Text = "Супер-сила 💥",
    Default = false,
    Callback = function(Value)
        if Value then
            if SuperGrabConn then SuperGrabConn:Disconnect(); SuperGrabConn = nil end
            if WaitUISConn then WaitUISConn:Disconnect(); WaitUISConn = nil end
            if DeleteObjConn then DeleteObjConn:Disconnect(); DeleteObjConn = nil end
            local obj
            SuperGrabConn = workspace.ChildAdded:Connect(function(c)
                if c.Name == "GrabParts" then
                    local part = c:FindFirstChild("GrabPart") or c:WaitForChild("GrabPart", 1)
                    if part then
                        local weld = part:FindFirstChild("WeldConstraint") or part:WaitForChild("WeldConstraint", 1)
                        if weld then
                            obj = weld.Part1
                        end
                    end
                end
            end)
            WaitUISConn = UIS.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton2 then
                    if obj then
                        local bv = Instance.new("BodyVelocity", obj)
                        local Camera = workspace.CurrentCamera
                        bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                        bv.Velocity = Camera.CFrame.LookVector * _G.strength
                        Debris:AddItem(bv, 4)
                        obj = nil
                    end
                end
            end)
            DeleteObjConn = workspace.ChildRemoved:Connect(function(desc)
                if desc.Name == "GrabParts" then
                    task.delay(1, function()
                        obj = nil
                    end)
                end
            end)
        else
            if SuperGrabConn then SuperGrabConn:Disconnect(); SuperGrabConn = nil end
            if WaitUISConn then WaitUISConn:Disconnect(); WaitUISConn = nil end
            if DeleteObjConn then DeleteObjConn:Disconnect(); DeleteObjConn = nil end
        end
    end
})

-- // Убийственный захват (Ragalic)
GrabGroup:AddToggle("KillGrabToggle", {
    Text = "Убийственный захват ☠️",
    Default = false,
    Callback = function(Value)
        _G.Bools.KillGrab = Value
        local function killGrabFunction()
            if KillGrabConn then KillGrabConn:Disconnect(); KillGrabConn = nil end
            KillGrabConn = workspace.ChildAdded:Connect(function(v)
                if v:IsA("Model") and v.Name == "GrabParts" and _G.Bools.KillGrab then
                    task.wait(0.05)
                    local grabPart = v:FindFirstChild("GrabPart")
                    if grabPart and grabPart:FindFirstChild("WeldConstraint") then
                        local part1 = grabPart.WeldConstraint.Part1
                        if part1 and part1.Parent and part1.Parent ~= plr.Character then
                            local targetChar = part1.Parent
                            local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
                            if targetHum and targetChar then
                                pcall(function()
                                    targetHum.Health = 0
                                    targetChar:BreakJoints()
                                end)
                            end
                        end
                    end
                end
            end)
        end
        if Value then
            killGrabFunction()
        else
            if KillGrabConn then KillGrabConn:Disconnect(); KillGrabConn = nil end
        end
    end
})

-- // --- ВКЛАДКА "ИГРОК 👤" (Из Ragalic + новое: Blob Fly) ---
local PlayerView = Tabs.Player:AddLeftGroupbox("Движение и обзор 👀")

-- // 3-е лицо (Ragalic)
PlayerView:AddToggle("ThirdPersonToggle", {
    Text = "Вид от 3-го лица 🎥",
    Default = false,
    Callback = function(Value)
        if Value then
            plr.CameraMode = Enum.CameraMode.Classic
            Camera.CameraType = Enum.CameraType.Custom
            Camera.CameraSubject = plr.Character:WaitForChild("Humanoid")
            plr.CameraMaxZoomDistance = 10000
            plr.CameraMinZoomDistance = 0.5
        else
            plr.CameraMode = Enum.CameraMode.LockFirstPerson
            Camera.CameraType = Enum.CameraType.Custom
            Camera.CameraSubject = plr.Character:WaitForChild("Humanoid")
            plr.CameraMaxZoomDistance = 0
            plr.CameraMinZoomDistance = 0
        end
    end
})

-- // Бесконечный прыжок (Ragalic)
PlayerView:AddToggle("infJumpToggle", {
    Text = "Бесконечный прыжок 🚀",
    Default = false,
    Callback = function(Value)
        _G.Bools.InfJump = Value
    end
})
state.APPLE_RERUN_CLEANUP_V1:Track(UIS.JumpRequest:Connect(function()
    if _G.Bools.InfJump then
        local character = plr.Character
        if character and character:FindFirstChildOfClass("Humanoid") then
            character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end))

-- // Скорость ходьбы (NoName)
PlayerView:AddSlider("WalkSpeedValue", {
    Text = "Множитель скорости 🏃",
    Default = 5,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = function(Value)
        _G.Ints.WalkspeedValue = Value
    end
})

PlayerView:AddToggle("ApplyWalkSpeed", {
    Text = "Применить скорость 🏃",
    Default = false,
    Callback = function(Value)
        _G.Bools.WalkSpeed = Value
        if Value then
            wsConn = RunService.Stepped:Connect(function()
                if plr and plr.Character and plr.Character:FindFirstChild('HumanoidRootPart') and plr.Character:FindFirstChildOfClass('Humanoid') and typeof(_G.Ints.WalkspeedValue) == 'number' then
                    local h = plr.Character.HumanoidRootPart
                    local u = plr.Character:FindFirstChildOfClass('Humanoid')
                    h.CFrame = h.CFrame + u.MoveDirection * ((16 * _G.Ints.WalkspeedValue) / 10)
                end
            end)
        else
            if wsConn then
                wsConn:Disconnect()
                wsConn = nil
            end
        end
    end
})

-- // Полёт на блобе (Из Ragalic)
local blobFlyActive = false
local blobFlySpeed = 50
local bvInstance, bgInstance

PlayerView:AddToggle("BlobFlyToggle", {
    Text = "Полёт на блобе 🛸",
    Default = false,
    Callback = function(on)
        blobFlyActive = on
        if not blobFlyActive then
            if bvInstance then
                bvInstance:Destroy()
                bvInstance = nil
            end
            if bgInstance then
                bgInstance:Destroy()
                bgInstance = nil
            end
        end
    end
})

PlayerView:AddSlider("BlobFlySpeed", {
    Text = "Скорость полёта 🚀",
    Default = 50,
    Min = 10,
    Max = 200,
    Rounding = 0,
    Callback = function(Value)
        blobFlySpeed = Value
    end
})

local function GetBlobRoot()
    local char = plr.Character
    local hum = char and char:FindFirstChild("Humanoid")
    if hum and hum.SeatPart and hum.SeatPart.Parent and hum.SeatPart.Parent.Name == "CreatureBlobman" then
        return hum.SeatPart.Parent:FindFirstChild("HumanoidRootPart") or hum.SeatPart.Parent.PrimaryPart
    end
    local folder = workspace:FindFirstChild(plr.Name .. "SpawnedInToys")
    if folder then
        local blob = folder:FindFirstChild("CreatureBlobman")
        if blob then
            return blob:FindFirstChild("HumanoidRootPart") or blob.PrimaryPart
        end
    end
    return nil
end

state.APPLE_RERUN_CLEANUP_V1:Track(RunService.Heartbeat:Connect(function()
    if not blobFlyActive then
        if bvInstance then
            bvInstance:Destroy()
            bvInstance = nil
        end
        if bgInstance then
            bgInstance:Destroy()
            bgInstance = nil
        end
        return
    end
    local root = GetBlobRoot()
    if root then
        if not root:FindFirstChild("BlobFlyVelocity") then
            bvInstance = Instance.new("BodyVelocity")
            bvInstance.Name = "BlobFlyVelocity"
            bvInstance.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bvInstance.P = 10000
            bvInstance.Parent = root
        else
            bvInstance = root.BlobFlyVelocity
        end
        if not root:FindFirstChild("BlobFlyGyro") then
            bgInstance = Instance.new("BodyGyro")
            bgInstance.Name = "BlobFlyGyro"
            bgInstance.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bgInstance.P = 20000
            bgInstance.D = 100
            bgInstance.Parent = root
        else
            bgInstance = root.BlobFlyGyro
        end
        local cam = workspace.CurrentCamera
        local moveDir = Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then
            moveDir = moveDir + cam.CFrame.LookVector
        end
        if UIS:IsKeyDown(Enum.KeyCode.S) then
            moveDir = moveDir - cam.CFrame.LookVector
        end
        if UIS:IsKeyDown(Enum.KeyCode.A) then
            moveDir = moveDir - cam.CFrame.RightVector
        end
        if UIS:IsKeyDown(Enum.KeyCode.D) then
            moveDir = moveDir + cam.CFrame.RightVector
        end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then
            moveDir = moveDir + Vector3.new(0, 1, 0)
        end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
            moveDir = moveDir - Vector3.new(0, 1, 0)
        end
        if bvInstance then
            bvInstance.Velocity = moveDir * blobFlySpeed
        end
        if bgInstance then
            bgInstance.CFrame = cam.CFrame
        end
    else
        if bvInstance then
            bvInstance:Destroy()
            bvInstance = nil
        end
        if bgInstance then
            bgInstance:Destroy()
            bgInstance = nil
        end
    end
end))

-- // --- ВКЛАДКА "ВИЗУАЛ 👁️" (Из Ragalic + NoName) ---
local VisualGroup = Tabs.Visual:AddLeftGroupbox("ESP и интерфейс 👁️")

-- // ESP PCLD (Ragalic)
VisualGroup:AddToggle("BoxESPWhite", {
    Text = "PCLD Box ESP 📦",
    Default = false,
    Callback = function(Value)
        _G.Bools.BoxESP = Value
        local espBoxes = {}
        local function AddBoxESP(obj)
            if espBoxes[obj] then
                return
            end
            local box = Instance.new("BoxHandleAdornment")
            box.Adornee = obj
            box.AlwaysOnTop = true
            box.ZIndex = 5
            box.Color3 = Color3.fromRGB(255, 255, 255)
            box.Transparency = 0.5
            box.Size = obj.Size
            box.Parent = CoreGui
            espBoxes[obj] = box
            obj.AncestryChanged:Connect(function(_, parent)
                if not parent and espBoxes[obj] then
                    espBoxes[obj]:Destroy()
                    espBoxes[obj] = nil
                end
            end)
        end
        local function RemoveAllBoxes()
            for obj, box in pairs(espBoxes) do
                if box then
                    box:Destroy()
                end
            end
            espBoxes = {}
        end
        local function Scan()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if _G.Bools.BoxESP and (obj.Name == "partesp" or obj.Name == "playercharacterlocationdetector") then
                    AddBoxESP(obj)
                end
            end
        end
        workspace.DescendantAdded:Connect(function(obj)
            if _G.Bools.BoxESP and (obj.Name == "partesp" or obj.Name == "playercharacterlocationdetector") then
                AddBoxESP(obj)
            end
        end)
        if Value then
            Scan()
        else
            RemoveAllBoxes()
        end
    end
})

-- // Никнейм ESP (Ragalic)
VisualGroup:AddToggle("NicknameESP", {
    Text = "ESP Никнеймов 📛",
    Default = false,
    Callback = function(Value)
        local function createESP(plr)
            if plr == Players.LocalPlayer then
                return
            end
            if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = plr.Character.HumanoidRootPart
                if hrp:FindFirstChild("NameESP") then
                    return
                end
                local billboard = Instance.new("BillboardGui")
                billboard.Name = "NameESP"
                billboard.Adornee = hrp
                billboard.Size = UDim2.new(0, 100, 0, 30)
                billboard.StudsOffset = Vector3.new(0, 3, 0)
                billboard.AlwaysOnTop = true
                billboard.Parent = hrp
                local textLabel = Instance.new("TextLabel")
                textLabel.Size = UDim2.new(1, 0, 1, 0)
                textLabel.BackgroundTransparency = 1
                textLabel.Text = plr.Name
                textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                textLabel.TextStrokeTransparency = 0
                textLabel.TextScaled = true
                textLabel.Parent = billboard
            end
        end
        if Value then
            for _, plr in pairs(Players:GetPlayers()) do
                createESP(plr)
                plr.CharacterAdded:Connect(function()
                    createESP(plr)
                end)
            end
            Players.PlayerAdded:Connect(function(plr)
                plr.CharacterAdded:Connect(function()
                    createESP(plr)
                end)
            end)
        else
            for _, plr in pairs(Players:GetPlayers()) do
                if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                    local hrp = plr.Character.HumanoidRootPart
                    if hrp:FindFirstChild("NameESP") then
                        hrp.NameESP:Destroy()
                    end
                end
            end
        end
    end
})

-- // FOV (Ragalic)
VisualGroup:AddSlider("FOVSlider", {
    Text = "Поле зрения (FOV) 👁️",
    Default = 90,
    Min = 1,
    Max = 120,
    Rounding = 0,
    Suffix = "°",
    Callback = function(value)
        workspace.CurrentCamera.FieldOfView = value
    end
})

-- // FPS буст (Ragalic)
VisualGroup:AddButton({
    Text = "Буст FPS 🚀",
    Func = function()
        local Lighting = game:GetService("Lighting")
        local oldProperties = {}
        for _, v in pairs(Workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                if not oldProperties[v] then
                    oldProperties[v] = {
                        Material = v.Material,
                        Reflectance = v.Reflectance,
                        CastShadow = v.CastShadow
                    }
                end
                v.Material = Enum.Material.Plastic
                v.Reflectance = 0
                v.CastShadow = false
            elseif v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") then
                if not oldProperties[v] then
                    oldProperties[v] = {
                        Enabled = v.Enabled
                    }
                end
                v.Enabled = false
            end
        end
        for _, plr in pairs(Players:GetPlayers()) do
            if plr.Character then
                for _, part in pairs(plr.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        if not oldProperties[part] then
                            oldProperties[part] = {
                                Material = part.Material,
                                Reflectance = part.Reflectance,
                                CastShadow = part.CastShadow
                            }
                        end
                        part.Material = Enum.Material.Plastic
                        part.Reflectance = 0
                        part.CastShadow = false
                    end
                end
            end
        end
        if not oldProperties["Lighting"] then
            oldProperties["Lighting"] = {
                GlobalShadows = Lighting.GlobalShadows,
                FogEnd = Lighting.FogEnd,
                Brightness = Lighting.Brightness
            }
        end
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        Lighting.Brightness = 2
        Notify("Буст FPS 💨", "Графика оптимизирована для производительности!", 3)
    end
})

-- // Восстановление FPS
VisualGroup:AddButton({
    Text = "Восстановить графику 🔄",
    Func = function()
        local Lighting = game:GetService("Lighting")
        local oldProperties = {}
        for obj, props in pairs(oldProperties) do
            if typeof(obj) == "Instance" and obj.Parent then
                for prop, value in pairs(props) do
                    obj[prop] = value
                end
            elseif obj == "Lighting" then
                for prop, value in pairs(props) do
                    Lighting[prop] = value
                end
            end
        end
        oldProperties = {}
        Notify("Графика восстановлена 🔄", "Настройки графики возвращены!", 3)
    end
})

-- // --- ВКЛАДКА "РАЗНОЕ 🛠️" (Из Ragalic + NoName) ---
local MiscGroup = Tabs.Misc:AddLeftGroupbox("Разное 🛠️")

-- // Триггер бот (Aim Bot) (Ragalic)
MiscGroup:AddToggle("TriggerbotToggle", {
    Text = "Триггер бот 🎯",
    Default = false,
    Callback = function(value)
        local Triggerbot = {
            Enabled = value,
            Connection = nil,
            canGrab = true,
            maxDistance = 20,
            preGrabDelay = 0.00001,
            postGrabDelay = 0.05,
            lastTarget = nil,
            lastHitTime = 0,
            targetMemoryDuration = 0.1,
            checkThrottle = 0.008,
            lastCheck = 0,
            rayParams = RaycastParams.new()
        }
        Triggerbot.rayParams.FilterType = Enum.RaycastFilterType.Exclude

        function Triggerbot:GetTarget()
            local c = plr.Character
            if not c or not c:FindFirstChild("HumanoidRootPart") then
                return
            end
            if Workspace:FindFirstChild("GrabParts") then
                return
            end
            local origin, dir = Camera.CFrame.Position, Camera.CFrame.LookVector
            self.rayParams.FilterDescendantsInstances = {
                c,
                Workspace.Terrain
            }
            local result = Workspace:Raycast(origin, dir * 1000, self.rayParams)
            if not result then
                local dirs = {
                    dir,
                    (dir + Vector3.new(0, 0.075, 0)).Unit,
                    (dir - Vector3.new(0, 0.075, 0)).Unit
                }
                for _, d in ipairs(dirs) do
                    result = Workspace:Raycast(origin, d * 1000, self.rayParams)
                    if result then
                        break
                    end
                end
            end
            if not result then
                return
            end
            local hit = result.Instance
            local model = hit:FindFirstAncestorOfClass("Model")
            if not model or not model:FindFirstChildOfClass("Humanoid") or model == c then
                return
            end
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum.Health <= 0 then
                return
            end
            local root = model:FindFirstChild("HumanoidRootPart")
            if not root then
                return
            end
            local dist = (c.HumanoidRootPart.Position - root.Position).Magnitude
            if dist > self.maxDistance then
                return
            end
            return model
        end

        function Triggerbot:OnHeartbeat()
            if not self.Enabled or not self.canGrab then
                return
            end
            if UIS:GetFocusedTextBox() then
                return
            end
            if tick() - self.lastCheck < self.checkThrottle then
                return
            end
            self.lastCheck = tick()
            local t = self:GetTarget()
            if t then
                self.lastTarget = t
                self.lastHitTime = tick()
            elseif self.lastTarget and tick() - self.lastHitTime > self.targetMemoryDuration then
                self.lastTarget = nil
            end
            local c = plr.Character
            local root = self.lastTarget and self.lastTarget:FindFirstChild("HumanoidRootPart")
            if not (self.lastTarget and c and c:FindFirstChild("HumanoidRootPart") and root) then
                return
            end
            if (c.HumanoidRootPart.Position - root.Position).Magnitude > self.maxDistance then
                self.lastTarget = nil
                return
            end
            if self.lastTarget then
                self.canGrab = false
                task.spawn(function()
                    task.wait(self.preGrabDelay)
                    pcall(mouse1press)
                    local t0 = tick()
                    repeat
                        task.wait(0.02)
                    until not Workspace:FindFirstChild("GrabParts") or tick() - t0 > 1.6
                    task.wait(self.postGrabDelay)
                    self.canGrab = true
                    self.lastTarget = nil
                end)
            end
        end

        if Triggerbot.Enabled and not Triggerbot.Connection then
            Triggerbot.Connection = RunService.Heartbeat:Connect(function()
                Triggerbot:OnHeartbeat()
            end)
        elseif not Triggerbot.Enabled and Triggerbot.Connection then
            Triggerbot.Connection:Disconnect()
            Triggerbot.Connection = nil
        end
    end
})

-- // Игнорирование барьеров (Ragalic)
MiscGroup:AddToggle("NoBarrierCollision", {
    Text = "Игнорировать барьеры домов 🚧",
    Default = false,
    Callback = function(Value)
        local plots = workspace:FindFirstChild("Plots")
        if not plots then
            return
        end
        for _, plot in ipairs(plots:GetChildren()) do
            local barrier = plot:FindFirstChild("Barrier")
            if barrier then
                for _, obj in ipairs(barrier:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        obj.CanCollide = not Value
                    end
                end
            end
        end
    end
})

-- // Авто-респаун (Ragalic)
MiscGroup:AddToggle("AutoResetToggle", {
    Text = "Авто-респаун 🔄",
    Default = false,
    Callback = function(on)
        _G.Bools.AutoReset = on
        if not on then
            _G.Bools.AutoReset = false
            return
        end
        task.spawn(function()
            local plr = game.Players.LocalPlayer
            while _G.Bools.AutoReset do
                local char = plr.Character
                local hum = char and char:FindFirstChild("Humanoid")
                if hum and hum.Health > 0 then
                    hum.Health = 0
                end
                task.wait(0.5)
            end
        end)
    end
})

-- // --- ВКЛАДКА "ВЕСЕЛЬЕ 😂" (Из Ragalic) ---
local FunGroup = Tabs.Fun:AddLeftGroupbox("Троллинг 😂")

-- // JERK OFF (Ragalic)
local playJerkOffActive = false
local jerkOffAnimTrack = nil
FunGroup:AddToggle("JerkOffToggle", {
    Text = "Дрочка ✊",
    Default = false,
    Callback = function(on)
        playJerkOffActive = on
        local function startJerkOff()
            local plr = Players.LocalPlayer
            local char = plr.Character or plr.CharacterAdded:Wait()
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum then
                return
            end
            local animator = hum:FindFirstChildOfClass("Animator")
            if not animator then
                animator = Instance.new("Animator")
                animator.Parent = hum
            end
            local anim = Instance.new("Animation")
            anim.AnimationId = "rbxassetid://168268306"
            jerkOffAnimTrack = animator:LoadAnimation(anim)
            jerkOffAnimTrack.Priority = Enum.AnimationPriority.Action
            jerkOffAnimTrack:Play()
            task.spawn(function()
                while playJerkOffActive do
                    task.wait(0.1)
                    if jerkOffAnimTrack and jerkOffAnimTrack.IsPlaying then
                        jerkOffAnimTrack.TimePosition = 0.3
                    end
                end
            end)
        end
        local function stopJerkOff()
            if jerkOffAnimTrack then
                jerkOffAnimTrack:Stop()
                jerkOffAnimTrack = nil
            end
        end
        if on then
            startJerkOff()
        else
            stopJerkOff()
        end
    end
})

-- // --- ВКЛАДКА "КЛАВИШИ ⌨️" (Из Ragalic + NoName) ---
local KeybindsGroup = Tabs.Keybinds:AddLeftGroupbox("Клавиши ⌨️")

-- // --- ВКЛАДКА "НАСТРОЙКИ UI ⚙️" (Из Ragalic) ---
local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Меню")
MenuGroup:AddButton("Выгрузить", function()
    Library:Unload()
end)
MenuGroup:AddLabel("Клавиша меню"):AddKeyPicker("MenuKeybind", {
    Default = "RightShift",
    NoUI = true,
    Text = "Клавиша меню"
})
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({
    "MenuKeybind"
})
ThemeManager:SetFolder("APPLE HUB")
SaveManager:SetFolder("APPLE HUB/Configs")
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])

-- // Уведомление о загрузке
Notify("APPLE HUB 🍎", "Загружен за " .. tostring(math.round(tick() - StartTick1)) .. " секунд!", 5)