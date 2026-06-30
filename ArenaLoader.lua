-- ============================================================
-- NomNom FTAP Arena Loader
-- A standalone UI whose ONLY job is to pick and load script packs.
-- Tick one or more packs (Wourld / NoName / XOCO), then "Load Selected"
-- runs all ticked packs (with a small delay between each to reduce
-- UI/loop conflicts). "Load All" loads everything.
-- Paste-and-run. For owned/private testing.
-- ============================================================

local REPO = "https://raw.githubusercontent.com/NomNomNemNie/NomNomFTAP/main/"

-- Packs available in the arena. Order = display order.
local PACKS = {
    { name = "Wourld", url = REPO .. "_fixed_sources/The_Wourld.fixed.lua" },
    { name = "NoName", url = REPO .. "_fixed_sources/NoName.fixed.lua" },
    { name = "XOCO",   url = REPO .. "_fixed_sources/XOCO.fixed.lua" },
}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- selected[name] = true/false
local selected = {}
for _, p in ipairs(PACKS) do
    selected[p.name] = false
end

local busy = false

-- ---- rerun-safe cleanup ----------------------------------------------------
local CLEANUP_KEY = "__NomNomArenaLoaderGui"
do
    local g = getgenv and getgenv() or _G
    local prev = g[CLEANUP_KEY]
    if typeof(prev) == "Instance" then
        pcall(function() prev:Destroy() end)
    end
    g[CLEANUP_KEY] = nil
end

local function getGuiParent()
    local ok, hui = pcall(function()
        return gethui and gethui()
    end)
    if ok and typeof(hui) == "Instance" then
        return hui
    end
    local pg = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then
        return pg
    end
    return game:GetService("CoreGui")
end

-- fetch + run one pack; returns ok, message
local function runPack(pack)
    local ok, src = pcall(function()
        return game:HttpGet(pack.url)
    end)
    if not ok or type(src) ~= "string" or #src < 32 then
        return false, pack.name .. ": fetch failed"
    end
    local fn, err = loadstring(src)
    if not fn then
        warn("[Arena] " .. pack.name .. " compile: " .. tostring(err))
        return false, pack.name .. ": compile failed"
    end
    local ranOk, runErr = pcall(fn)
    if not ranOk then
        warn("[Arena] " .. pack.name .. " runtime: " .. tostring(runErr))
        return false, pack.name .. ": runtime error"
    end
    return true, pack.name .. " loaded"
end

-- ---- build UI --------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "NomNomArenaLoader"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 9999
gui.Parent = getGuiParent()

do
    local g = getgenv and getgenv() or _G
    g[CLEANUP_KEY] = gui
end

local root = Instance.new("Frame")
root.Name = "Root"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.fromOffset(300, 320)
root.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
root.BorderSizePixel = 0
root.Active = true
root.Draggable = true
root.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = root

local stroke = Instance.new("UIStroke")
stroke.Thickness = 1.4
stroke.Color = Color3.fromRGB(120, 120, 130)
stroke.Transparency = 0.25
stroke.Parent = root

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 0, 0, 10)
title.Size = UDim2.new(1, 0, 0, 26)
title.Font = Enum.Font.GothamBold
title.Text = "Arena Loader"
title.TextColor3 = Color3.fromRGB(236, 236, 236)
title.TextSize = 18
title.Parent = root

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.new(0, 0, 0, 34)
subtitle.Size = UDim2.new(1, 0, 0, 16)
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "Tick packs, then Load Selected"
subtitle.TextColor3 = Color3.fromRGB(150, 150, 160)
subtitle.TextSize = 12
subtitle.Parent = root

-- one checkbox row per pack
local rowY = 58
local rowH = 40
local function makeRow(pack)
    local row = Instance.new("Frame")
    row.Name = pack.name .. "Row"
    row.AnchorPoint = Vector2.new(0.5, 0)
    row.Position = UDim2.new(0.5, 0, 0, rowY)
    row.Size = UDim2.fromOffset(260, 34)
    row.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    row.BorderSizePixel = 0
    row.Parent = root
    local rc = Instance.new("UICorner")
    rc.CornerRadius = UDim.new(0, 8)
    rc.Parent = row

    local box = Instance.new("TextButton")
    box.Name = "Check"
    box.AnchorPoint = Vector2.new(0, 0.5)
    box.Position = UDim2.new(0, 8, 0.5, 0)
    box.Size = UDim2.fromOffset(20, 20)
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    box.BorderSizePixel = 0
    box.AutoButtonColor = false
    box.Text = ""
    box.Parent = row
    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 5)
    bc.Parent = box
    local bs = Instance.new("UIStroke")
    bs.Thickness = 1
    bs.Color = Color3.fromRGB(100, 100, 110)
    bs.Parent = box

    local check = Instance.new("TextLabel")
    check.BackgroundTransparency = 1
    check.Size = UDim2.fromScale(1, 1)
    check.Font = Enum.Font.GothamBold
    check.Text = ""
    check.TextColor3 = Color3.fromRGB(120, 220, 140)
    check.TextSize = 16
    check.Parent = box

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.AnchorPoint = Vector2.new(0, 0.5)
    label.Position = UDim2.new(0, 38, 0.5, 0)
    label.Size = UDim2.new(1, -44, 1, 0)
    label.Font = Enum.Font.GothamMedium
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = pack.name
    label.TextColor3 = Color3.fromRGB(235, 235, 240)
    label.TextSize = 15
    label.Parent = row

    local function toggle()
        selected[pack.name] = not selected[pack.name]
        check.Text = selected[pack.name] and "X" or ""
        box.BackgroundColor3 = selected[pack.name]
            and Color3.fromRGB(34, 70, 44)
            or Color3.fromRGB(40, 40, 48)
    end
    box.MouseButton1Click:Connect(toggle)
    -- clicking the row label also toggles
    local labelBtn = Instance.new("TextButton")
    labelBtn.BackgroundTransparency = 1
    labelBtn.Position = UDim2.new(0, 32, 0, 0)
    labelBtn.Size = UDim2.new(1, -32, 1, 0)
    labelBtn.Text = ""
    labelBtn.Parent = row
    labelBtn.MouseButton1Click:Connect(toggle)

    rowY = rowY + rowH
end

for _, pack in ipairs(PACKS) do
    makeRow(pack)
end

-- status label (above buttons)
local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.AnchorPoint = Vector2.new(0.5, 0)
status.Position = UDim2.new(0.5, 0, 0, rowY + 4)
status.Size = UDim2.new(1, -24, 0, 18)
status.Font = Enum.Font.Gotham
status.Text = "Ready"
status.TextColor3 = Color3.fromRGB(160, 200, 160)
status.TextSize = 12
status.TextTruncate = Enum.TextTruncate.AtEnd
status.Parent = root

-- load a list of packs sequentially with delay between each
local function loadList(list)
    if busy then
        return
    end
    if #list == 0 then
        status.Text = "No packs selected"
        return
    end
    busy = true
    task.spawn(function()
        local loaded, failed = 0, 0
        for i, pack in ipairs(list) do
            status.Text = "Loading " .. pack.name
                .. " (" .. i .. "/" .. #list .. ")"
            local ok = runPack(pack)
            if ok then
                loaded = loaded + 1
            else
                failed = failed + 1
            end
            -- delay between loads to reduce UI/loop conflicts
            if i < #list then
                task.wait(0.6)
            end
        end
        status.Text = "Done: " .. loaded .. " loaded, " .. failed .. " failed"
        busy = false
    end)
end

local function makeActionButton(text, xScale, callback)
    local btn = Instance.new("TextButton")
    btn.AnchorPoint = Vector2.new(0.5, 1)
    btn.Position = UDim2.new(xScale, 0, 1, -44)
    btn.Size = UDim2.fromOffset(130, 34)
    btn.BackgroundColor3 = Color3.fromRGB(34, 60, 44)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Font = Enum.Font.GothamMedium
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(235, 245, 238)
    btn.TextSize = 14
    btn.Parent = root
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = btn
    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = Color3.fromRGB(46, 80, 58)
    end)
    btn.MouseLeave:Connect(function()
        btn.BackgroundColor3 = Color3.fromRGB(34, 60, 44)
    end)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

makeActionButton("Load Selected", 0.30, function()
    local list = {}
    for _, pack in ipairs(PACKS) do
        if selected[pack.name] then
            table.insert(list, pack)
        end
    end
    loadList(list)
end)

makeActionButton("Load All", 0.70, function()
    local list = {}
    for _, pack in ipairs(PACKS) do
        table.insert(list, pack)
    end
    loadList(list)
end)

-- close button
local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(1, 0)
close.Position = UDim2.new(1, -8, 0, 8)
close.Size = UDim2.fromOffset(24, 24)
close.BackgroundColor3 = Color3.fromRGB(60, 32, 32)
close.BorderSizePixel = 0
close.AutoButtonColor = false
close.Font = Enum.Font.GothamBold
close.Text = "X"
close.TextColor3 = Color3.fromRGB(240, 200, 200)
close.TextSize = 14
close.Parent = root
local cc = Instance.new("UICorner")
cc.CornerRadius = UDim.new(0, 6)
cc.Parent = close
close.MouseButton1Click:Connect(function()
    pcall(function() gui:Destroy() end)
    local g = getgenv and getgenv() or _G
    g[CLEANUP_KEY] = nil
end)

status.Text = "Ready - " .. #PACKS .. " packs"