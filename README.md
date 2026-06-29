# NomNom FTAP

A synthesized client-side utility hub for the private-test "Fling Things And People" Roblox experience. Built by analyzing and extracting the best, cleanest patterns from a collection of community FTAP source scripts, then rewriting them into one cohesive, maintainable hub.

> Intended for owned games, private servers, and private testing. Server-authoritative behavior (damage, ownership, persistence) still depends on the game's own systems.

## v4 — Modular + extreme survival layer

The hub is now split into modules under [`modules/`](modules) for easy upgrading and fixing, loaded by [`Loader.lua`](Loader.lua). `NomNom.lua` is a thin entry shim that runs the Loader, so the original load URL keeps working.

| File | Responsibility |
|---|---|
| `modules/Core.lua` | services, shared state, connection/task manager, respawn-safe access, **existence-based toy spawn** (waits until the toy actually exists — no fixed delay), and the **map-bounds + extreme waypoint loop-tp engine** |
| `modules/Gucci.lua` | invincible Gucci + **extreme map-wide loop-tp** of the toy + recovery (waypoint dodge → re-acquire → sit → verify → protect) + steal enemy seat |
| `modules/Combat.lua` | super fling, massless, teleport/bring, predictive loop-fling, **persistent grab-kill (works while dead)** + attack-back |
| `modules/Protection.lua` | anti grab/explode/fire/blobman/ragdoll/void/lag |
| `modules/Misc.lua` | main, movement (fly + dash), vehicles, ESP, chat, settings |
| `Loader.lua` | fetches the modules, builds the Rayfield UI, wires death/respawn + cleanup |

### Survival behaviour

- **Invincible Gucci + extreme loop-tp** — once gucci'd, the toy is teleported to a fresh random map waypoint **every frame** (re-claiming ownership each jump), so no one can steal-seat, grab, or destroy it. It stays above the void, never dropping in.
- **Lost-Gucci recovery** — drop a waypoint, loop-tp the character around the map to dodge loopkill, re-acquire (existing → steal enemy/empty seat → else spawn own), re-sit, verify, then resume protect-by-loop-tp. Checks run on a fast cadence.
- **Persistent grab-kill while dead** — the kill/mark engine runs on its own loop that does not stop when you die. Being killed means you lost gucci, so the killer is marked and their Gucci is deleted immediately, then killed back.
- **Anti-loopkill on spawn** — the moment you respawn (before the character settles) the script loop-teleports you around the map via ownership to dodge an instant re-pin, then re-arms Gucci → verify → protect-by-loop-tp.
- **Existence-based spawning** — instead of a fixed cooldown, the spawner fires and polls until the toy actually appears, which respects the game's real spawn timing.

## What it is

A modular hub loaded through an executor-style runner. It uses the Rayfield UI library and organizes every feature into 8 tabs with clean engineering throughout:

- **Unified connection manager** — every event connection is named and tracked, so nothing leaks.
- **`_G` rerun cleanup** — re-running the script tears down the previous instance first (no duplicate UI, no stacked loops).
- **Respawn-safe** — character/HRP/Humanoid are fetched fresh on every use; fly and dash hooks re-apply on respawn.
- **Throttled loops** — Heartbeat/RenderStepped work is bounded; no per-frame teleport or remote spam.
- **Safe remote lookups** — game-specific remotes resolve through a guarded helper and no-op if the game differs.
- **Full teardown** — `Settings → Unload NomNom` (or `_G.NomNomFTAP.Cleanup()`) disconnects everything, releases held players, removes ESP/chat instances, and destroys the UI.

## Tabs & features

| Tab | Features |
|---|---|
| **Main** | WalkSpeed, JumpPower, Infinite Jump, Unlock 3rd Person, Teleport to Spawn, Respawn |
| **Movement** | Camera-relative Fly (WASD + Space/Shift), Fly Speed, TSB-style Dash multiplier, Free Jump |
| **Combat** | Super Fling, Massless Grab, Teleport & Bring (Stack / Loop / all-nearby-whitelist), Loop Fling (predictive + line-of-sight + ownership monitor) |
| **Protection** | Anti Grab, Anti Explode, Anti Fire, Anti Blobman, Anti Ragdoll, Anti Void, Anti Lag |
| **Vehicles** | Hijack Outer/Inner UFO, Train, CaveCart; UFO Hitbox Spin / Follow |
| **ESP** | Highlight + headshot + name tags, rainbow mode, color picker, force refresh |
| **Chat** | Custom chat GUI over the ExtendGrabLine remote (only other NomNom users see it) |
| **Settings** | Whitelist management, full unload |

## Keybinds

- **F8** — toggle the custom chat GUI
- **Y** — teleport-grab the player under your mouse

## Sources synthesized

The hub distills the strongest mechanic from each of these analyzed source scripts:

- **The Strongest Battlegrounds** — dash velocity multiplier + free-jump movement combat
- **OverLoad** — protection suite, full ESP engine, blobman targeting
- **LoopFling** — the predictive fling engine (velocity history, lead prediction, raycast line-of-sight, decoy ownership lifecycle)
- **UFO** — vehicle hijack via sticky shurikens, UFO hitbox spin/follow, massless grab
- **VerbalminiLeak** — teleport-grab, stack mode, loop-bring (all / nearby / whitelist)
- **ChatFTAP** — custom chat UI and message routing

See [`SOURCE_INVENTORY.md`](SOURCE_INVENTORY.md) for the full provenance catalog of the archived source set.

## Usage

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/NomNomNemNie/NomNomFTAP/main/NomNom.lua"))()
```

To unload at any time:

```lua
_G.NomNomFTAP.Cleanup()