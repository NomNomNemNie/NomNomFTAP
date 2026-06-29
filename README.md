# NomNom FTAP

A synthesized client-side utility hub for the private-test "Fling Things And People" Roblox experience. Built by analyzing and extracting the best, cleanest patterns from a collection of community FTAP source scripts, then rewriting them into one cohesive, maintainable hub.

> Intended for owned games, private servers, and private testing. Server-authoritative behavior (damage, ownership, persistence) still depends on the game's own systems.

## v3 — Persistent / Invincible survival layer

v3 adds a "never stops" survival layer built for private testing where other testers actively try to remove you:

- **Invincible Gucci** — spawns a Tractor/Blobman extremely high, sits + ragdoll-desyncs into it, and a per-frame hardening loop re-anchors, re-sits, re-ragdolls and re-pins it **every frame** so it can't be destroyed, unsat, or grabbed between frames.
- **Auto Re-Gucci recovery** — if the Gucci is ever lost, a recovery loop keeps re-finding / respawning + re-sitting **until it succeeds**, so you're never left exposed.
- **Persistent Grab-Kill** — the kill/mark engine runs on its own loop and **keeps working while you are dead**, so a loopkill doesn't disarm you.
- **Auto Attack Back** — on death, whoever was holding you is **marked** for the fling engine and (optionally) their Gucci is **deleted**.
- **Steal enemy seat when un-Gucci'd** — when you have no Gucci of your own, the engine can delete a holder's Gucci so you can take their seat (same sit + ragdoll desync).
- **Anti-loopkill** — on every respawn, active toggles (Gucci recovery, marked targets, fly, dash) re-arm themselves automatically.
- **Spawn throttle** — all toy spawns route through one throttled queue (min gap ~0.25s) to respect the game's toy-spawn cooldown instead of spamming.

## What it is

A single standalone `.lua` script (`NomNom.lua`) loaded through an executor-style runner. It uses the Rayfield UI library and organizes every feature into 8 tabs with clean engineering throughout:

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