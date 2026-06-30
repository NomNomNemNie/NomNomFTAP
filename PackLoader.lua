-- ============================================================
-- NomNom FTAP Pack Loader
-- A small standalone UI with 3 buttons that each load a separate
-- script pack (Wourld / NoName / XOCO) from the repo, instead of
-- loading the merged NomNom hub.
-- Paste-and-run. For owned/private testing.
-- ============================================================

local REPO = "https://raw.githubusercontent.com/NomNomNemNie/NomNomFTAP/main/"

-- Each pack -> raw URL of its individual script in the repo.
local PACKS = {
    { name = "Wourld", url = REPO .. "_fixed_sources/The_Wourld.fixed.lua" },
    { name = "NoName", url = REPO .. "_fixed_sources/NoName.fixed.lua" },
    { name = "XOCO",   url = REPO .. "_fixed_sources/XOCO.fixed.lua" },
}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Rerun-safe cleanup: destroy any previous loader UI.
local CLEANUP_KEY = "__NomNomPackLoaderGui"
do
    local g = getgenv and getgenv() or _G
    local prev = g[CLEANUP_KEY]
    if typeof(prev) == "Instance" then
        pcall(function() prev:Destroy() end)
    end
    g[CLEANUP_KEY] = nil
end

-- Pick a safe parent for the GUI (CoreGui via gethui when available,
-- else PlayerGui).
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

local busy = false

local function loadPack(pack, statusLabel)
    if busy then
        return
    end
    busy = true
    statusLabel.Text = "Loading " .. pack.name .. "..."
    task.spawn(function()
        local ok, src = pcall(function()
            return game:HttpGet(pack.url)
        end)
        if not ok or type(src) ~= "string" or #src < 32 then
            statusLabel.Text = pack.name .. ": fetch failed"
            busy = false
            return
        end
        local fn, err = loadstring(src)
        if not fn then
            statusLabel.Text = pack.name .. ": compile failed"
            warn("[NomNom PackLoader] " .. pack.name .. " compile: " .. tostring(err))
            busy = false
            return
        end
        local ranOk, runErr = pcall(fn)
        if ranOk then
            statusLabel.Text = pack.name .. " loaded"
        else
            statusLabel.Text = pack.name .. ": runtime error"
            warn("[NomNom PackLoader] " .. pack.name .. " runtime: " .. tostring(runErr))
        end
        busy = false
    end)
end

-- ---- Build the UI ----------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "NomNomPackLoader"
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
root.Size = UDim2.fromOffset(280, 250)
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
title.Name = "Title"
title.BackgroundTransparency = 1
title.Position = UDim2.new(0, 0, 0, 10)
title.Size = UDim2.new(1, 0, 0, 28)
title.Font = Enum.Font.GothamBold
title.Text = "NomNom Pack Loader"
title.TextColor3 = Color3.fromRGB(236, 236, 236)
title.TextSize = 18
title.Parent = root

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.new(0, 0, 0, 36)
subtitle.Size = UDim2.new(1, 0, 0, 16)
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "Pick a script pack to load"
subtitle.TextColor3 = Color3.fromRGB(150, 150, 160)
subtitle.TextSize = 12
subtitle.Parent = root

local function makeButton(text, yOffset, callback)
    local btn = Instance.new("TextButton")
    btn.Name = text .. "Button"
    btn.AnchorPoint = Vector2.new(0.5, 0)
    btn.Position = UDim2.new(0.5, 0, 0, yOffset)
    btn.Size = UDim2.fromOffset(240, 38)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Font = Enum.Font.GothamMedium
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(235, 235, 240)
    btn.TextSize = 15
    btn.Parent = root

    local bc = Instance.new("UICorner")
    bc.CornerRadius = UDim.new(0, 8)
    bc.Parent = btn

    local bs = Instance.new("UIStroke")
    bs.Thickness = 1
    bs.Color = Color3.fromRGB(90, 90, 100)
    bs.Transparency = 0.3
    bs.Parent = btn

    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = Color3.fromRGB(44, 44, 52)
    end)
    btn.MouseLeave:Connect(function()
        btn.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    end)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local status = Instance.new("TextLabel")
status.Name = "Status"
status.BackgroundTransparency = 1
status.AnchorPoint = Vector2.new(0.5, 1)
status.Position = UDim2.new(0.5, 0, 1, -10)
status.Size = UDim2.new(1, -20, 0, 18)
status.Font = Enum.Font.Gotham
status.Text = "Ready"
status.TextColor3 = Color3.fromRGB(160, 200, 160)
status.TextSize = 12
status.TextTruncate = Enum.TextTruncate.AtEnd
status.Parent = root

local y = 62
for _, pack in ipairs(PACKS) do
    makeButton("Load " .. pack.name, y, function()
        loadPack(pack, status)
    end)
    y = y + 46
end

-- Close button (top-right).
local close = Instance.new("TextButton")
close.Name = "Close"
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

status.Text = "Ready - 3 packs available"