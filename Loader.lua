-- NomNom FTAP Loader
-- Loads the merged NomNom hub from the local build.
-- Edit RAW_URL to your GitHub raw path after pushing.
local RAW_URL = "https://raw.githubusercontent.com/NomNomNemNie/NomNomFTAP/main/NomNom.lua"
local ok, src = pcall(function() return game:HttpGet(RAW_URL) end)
if not ok or type(src) ~= "string" or #src < 32 then
    warn("[NomNom] loader fetch failed")
    return
end
local fn, err = loadstring(src)
if not fn then
    warn("[NomNom] compile failed: " .. tostring(err))
    return
end
fn()
