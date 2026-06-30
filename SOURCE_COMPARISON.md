# Source/Strong Comparison & Merge Report

Four scripts target the same grab/fling Roblox game family (shared remotes: `GrabEvents.SetNetworkOwner`, `CreatureBlobman`, `MenuToys.SpawnToyRemoteFunction`, `NinjaShuriken` anti-kick).

## Per-script inventory

### The Wourld

- Size: 440866 chars / 5 lines, 1620 functions
- UI: 152 toggles, 64 sliders, 26 dropdowns, 67 buttons, 14 keybinds
- Features: Aura(306), Blob(204), AntiKick(192), Music(152), Config(142), Trail(118), Highlight(99), Gucci(97), KickAura(58), Fling(57), GrabLine(55), Skybox(47), Theme(46), Speed(45), Ownership(44), Teleport(41), Rejoin(39), Camera(36), Noclip(34), AntiGrab(33), Username(31), Hitbox(26), PacketLag(24), BuildPreset(22), ESP(21), Backtrack(18), LoopExplosion(17), InfiniteJump(16), AntiExplosion(15), TP(15), Trace(12), HomeGuard(11), Spinbot(10), AntiBurn(8), TriggerBot(8), Kick All(7), AntiAfk(6), Bypass(5), AntiVoid(4), FOV(2)

### XOCO

- Size: 403057 chars / 9946 lines, 660 functions
- UI: 0 toggles, 0 sliders, 0 dropdowns, 0 buttons, 0 keybinds
- Features: Blob(187), Gucci(125), Aura(109), Trail(99), Camera(50), Skybox(45), AntiKick(42), Fling(37), GrabLine(35), Config(34), Speed(31), AntiGrab(29), ESP(21), TP(19), Ownership(16), Teleport(14), Fly(13), Theme(8), KickAura(7), PacketLag(5), Highlight(4), FOV(4), Hitbox(3), Username(2)

### NoName

- Size: 235889 chars / 5459 lines, 318 functions
- UI: 67 toggles, 25 sliders, 12 dropdowns, 29 buttons, 0 keybinds
- Features: Blob(98), AntiKick(65), Gucci(42), ESP(38), Config(27), GrabLine(25), Aura(16), Fling(14), Speed(12), Camera(12), AntiGrab(11), AntiBurn(10), Teleport(9), TP(6), AntiVoid(5), Highlight(4), Hitbox(4), FOV(3), Bypass(3), KickAura(2), Username(1), Fly(1)

### NoName-Apple

- Size: 96535 chars / 2485 lines, 152 functions
- UI: 26 toggles, 4 sliders, 1 dropdowns, 9 buttons, 1 keybinds
- Features: Blob(78), Camera(27), ESP(21), Gucci(20), Fly(16), GrabLine(12), AntiKick(10), Speed(7), Theme(6), Highlight(4), FOV(3), Bypass(3), TP(2), Config(2), AntiGrab(1), AntiExplosion(1), AntiBurn(1), AntiVoid(1), Trail(1)

## Merge decision

`The Wourld` is the canonical base: most complete UI (Obsidian/Linoria compat, 9 tabs, theme + config manager, music player, build presets) and the largest feature set. The other three are feature subsets of the same game, so their essence is preserved by the base; unique extras are noted below.

### Unique/notable per script

- **NoName** (5459 lines, OrionLib hints): broad toggle set, `createLagWithGrabLine`, paint-part tools.
- **NoName-Apple** (2457 lines): TriggerBot + Fly focus, box ESP, camera tools.
- **XOCO** (9949 lines): AntiGucciTrain, Type1 ragdoll spam, strong anti-grab/anti-ragdoll pipeline.

All overlapping mechanics (anti-kick, kick methods, blob kick/kill, gucci, grab/line mods, ESP/visuals, server lag, owner tools) exist in the base.

## Fixes applied (all 4 scripts)

- **The Wourld**: no deprecated calls. Tight `while true do` loops: 4.
- **XOCO**: wait()->task.wait(): 2; spawn()->task.spawn(): 1. Tight `while true do` loops: 5.
- **NoName**: wait()->task.wait(): 4. Tight `while true do` loops: 1.
- **NoName-Apple**: no deprecated calls. Tight `while true do` loops: 0.

Fixed copies written to `_fixed_sources/`.
