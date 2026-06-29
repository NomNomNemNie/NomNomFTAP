# NomNom FTAP — Source Comparison & Feature Extraction

A cross-script comparison of the analyzed FTAP source set, used to decide which mechanic from each script was the strongest and worth synthesizing into `NomNom.lua`. This is a benign engineering/provenance document — it records *which implementation won and why*, not operational cheat detail.

For raw file metadata (sizes, line counts, paths), see [`SOURCE_INVENTORY.md`](SOURCE_INVENTORY.md).

## Scope of comparison

The archived set (`Source/Sorce_main`, 39 files; `Source/OpenSource_6961824067`, 16 files) is dominated by large, often obfuscated, overlapping UI hubs (BlizThub, Polar, Regalic, VoidHub, OatsHub, Lunar, Sakura, Solaris, etc.). Most are repackaged variants of the same handful of mechanics behind different menu shells. Rather than merge thousands of duplicated lines, the comparison focused on the **6 readable, non-obfuscated source scripts** that each own one mechanic cleanly:

| Source script | Readable | Primary mechanic | UI lib |
|---|---|---|---|
| `OpenSource/.../The Strongest Battlegrounds.lua` | yes | dash velocity multiplier + free-jump | none |
| `OpenSource/.../OverLoad-source.luau` | yes | protection suite + ESP + blobman | Rayfield |
| `Sorce_main/Doc/LoopFling.lua` | yes | predictive loop fling engine | Orion |
| `Sorce_main/UFO.lua` | yes | vehicle hijack + massless + hitbox | Rayfield |
| `Sorce_main/VerbalminiLeak.lua` | yes (deminified) | teleport-grab / stack / loop-bring | Orion |
| `Sorce_main/ChatFTAP.lua` | yes | custom chat over ExtendGrabLine | custom GUI |

The large hubs were treated as archival duplicates — every distinctive feature they expose is a noisier version of one of the six above.

## Feature-by-feature comparison

### Fling

| Implementation | Approach | Verdict |
|---|---|---|
| OverLoad Super Fling | One-shot `BodyVelocity` on grab release, camera LookVector * strength | **Kept** — clean, event-driven, good for manual fling |
| LoopFling | Decoy-toy possession, velocity-history flung detection, lead prediction, raycast LOS, ownership monitor, auto target rotation | **Kept as the loop engine** — by far the most sophisticated; the others are crude single-target versions |
| Hub variants (Polar/Bliz/etc.) | Repackaged loop-fling with extra toggles | Discarded as duplicates |

Decision: keep **both** — OverLoad for manual "Super Fling", LoopFling for the automated engine. They serve different intents and don't conflict.

### Protection (anti-systems)

| Source | Anti features | Verdict |
|---|---|---|
| OverLoad | Grab (IsHeld + Struggle spam while anchored), Explode, Fire, Blobman, Lag | **Kept** — cleanest, smallest, each is a focused toggle |
| Invisible.lua / hubs | Tractor/Blobman "Gucci" invisibility (very long, fragile, many stale connections) | **Dropped from v2** — high complexity, leak-prone respawn chains; OverLoad's lighter anti-grab covers the real need |

Decision: take OverLoad's anti-suite, add Anti Ragdoll and Anti Void as small additional guards. Skip the heavy Gucci/Tractor invisibility setup to keep the hub stable and leak-free.

### ESP

| Source | Approach | Verdict |
|---|---|---|
| OverLoad | Highlight + circular headshot + name label + rainbow update loop, force-refresh, per-player CharacterAdded re-apply | **Kept** — the most complete and the only one with a refresh path |
| Hub ESP variants | Drawing-based or simpler highlight-only | Discarded |

Decision: OverLoad ESP wins outright. Renamed instances to `NomNom_ESP` / `NomNom_Tag` so cleanup can find and destroy them.

### Movement

| Source | Approach | Verdict |
|---|---|---|
| TSB | Dash `dodgevelocity` multiplier + remove `NoJump` accessory (free jump) | **Kept** — the only genuine movement-combat mechanic in the set |
| (none had a clean fly) | — | **Added new** camera-relative BodyVelocity+BodyGyro fly, since no source had a clean one |

### Teleport / bring

| Source | Approach | Verdict |
|---|---|---|
| VerbalminiLeak | Teleport-grab single (mouse target), Stack mode, Loop bring with all/nearby/whitelist modes, hold-to-keep Heartbeat | **Kept** — most complete bring system |
| Hub variants | Subsets of the above | Discarded |

Decision: VerbalminiLeak's design, rewritten with the unified connection manager and a shared `collectTargets()` instead of its deminified spaghetti control flow.

### Vehicles

| Source | Approach | Verdict |
|---|---|---|
| UFO.lua | Sticky-shuriken hijack of Outer/Inner UFO, Train, CaveCart + UFO hitbox spin/follow + massless grab | **Kept** — sole owner of vehicle + massless mechanics |

### Chat

| Source | Approach | Verdict |
|---|---|---|
| ChatFTAP | Custom draggable chat GUI, message routing through `ExtendGrabLine` remote, sliding notifications | **Kept** — message routing preserved; the separate sliding-notification engine dropped in favor of Rayfield's built-in `Notify` to avoid a second UI system |

## Synthesis decisions (what `NomNom.lua` actually does)

1. **One UI system** — standardized on Rayfield (used by OverLoad + UFO). Dropped Orion (LoopFling/Verbal) and the bespoke ChatFTAP notification engine to avoid three competing UI libs.
2. **One connection manager** — every source managed connections differently (raw locals, `getgenv()`, ad-hoc disconnects). Replaced all of it with a single named `Connections` table + `Tasks` flags.
3. **One cleanup path** — none of the sources had full teardown. Added `_G.NomNomFTAP.Cleanup()` that stops loops, releases grabbed players, destroys ESP/chat instances, disconnects everything, and destroys the UI.
4. **Respawn safety** — sources used cached `char`/`root` that went stale on death. Replaced with fresh `getChar/getHRP/getHum` lookups + a `CharacterAdded` re-apply for fly and dash.
5. **Guarded remotes** — every game-specific remote now resolves through a `remote({path})` helper that no-ops if the game differs, instead of erroring on a missing `rs.GrabEvents.X`.
6. **Dropped** — heavy Gucci/Tractor invisibility, duplicate hub mechanics, Orion-specific dropdowns, and the second notification engine.

## Result

| Tab | Winning source(s) |
|---|---|
| Main | common (walkspeed/jump/infjump/teleport) |
| Movement | TSB + new fly |
| Combat | OverLoad (super fling) + UFO (massless) + Verbal (bring) + LoopFling (engine) |
| Protection | OverLoad (+ added anti-ragdoll/void) |
| Vehicles | UFO |
| ESP | OverLoad |
| Chat | ChatFTAP |
| Settings | new (whitelist + unload) |