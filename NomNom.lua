-- ==========================================================
-- NOMNOM FTAP — entry shim (v4 modular)
-- ----------------------------------------------------------
-- The hub is now split into modules under /modules for easy
-- upgrading & fixing:
--   modules/Core.lua        services, state, conn manager,
--                           existence-based spawn, map-waypoint
--                           extreme loop-tp engine
--   modules/Gucci.lua       invincible Gucci + extreme map loop-tp
--                           + recovery (waypoint dodge -> re-acquire
--                           -> sit -> verify -> protect) + steal seat
--   modules/Combat.lua      fling, bring, persistent grab-kill
--                           (works while dead) + attack-back
--   modules/Protection.lua  anti grab/explode/fire/blobman/ragdoll/void/lag
--   modules/Misc.lua        main, movement, vehicles, ESP, chat, settings
--   Loader.lua              fetches modules, builds UI, wires
--                           death/respawn + cleanup
--
-- This file just runs the Loader so the old URL keeps working:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/NomNomNemNie/NomNomFTAP/main/NomNom.lua"))()
--
-- Unload any time:  _G.NomNomFTAP.Cleanup()
-- ==========================================================

local LOADER = "https://raw.githubusercontent.com/NomNomNemNie/NomNomFTAP/main/Loader.lua"

local ok, src = pcall(function() return game:HttpGet(LOADER) end)
if not ok or not src then
    warn("[NomNom] failed to fetch Loader.lua: " .. tostring(src))
    return
end

local fn, err = loadstring(src)
if not fn then
    warn("[NomNom] Loader compile error: " .. tostring(err))
    return
end

return fn()