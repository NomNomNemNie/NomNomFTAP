# NomNomFTAP

Merged, hardened private-test Roblox hub for the grab/fling game family. Built from `Source/Strong` with **The Wourld** as the canonical UI/feature base, fixed and rebranded to NomNom.

## Files

- `NomNom.lua` - the full merged hub (single file).
- `Loader.lua` - thin loader that `HttpGet`s `NomNom.lua` from raw.
- `PackLoader.lua` - standalone 3-button UI that loads each script pack
  separately (Wourld / NoName / XOCO) instead of the merged hub.
- `SOURCE_COMPARISON.md` - per-script comparison + merge rationale.
- `SOURCE_INVENTORY.md` - raw feature counts.
- `_fixed_sources/` - the individual script packs (fixed), served by PackLoader.

## Usage

Merged hub: run `Loader.lua` or paste `NomNom.lua` directly. UI toggle key: **Right Shift**.

Individual packs: run `PackLoader.lua` for a small window with three buttons -
**Load Wourld**, **Load NoName**, **Load XOCO** - each fetches and runs that
single pack from the repo. Draggable window, close button, rerun-safe.

## Notes

- Base UI loads Obsidian + Linoria libraries via HttpGet.
- Deprecated `wait`/`spawn`/`delay` modernized to `task.*`.
- Brand strings/storage folders rebranded `Wourld*` -> `NomNom*`; external dependency URLs left intact.
- For owned/private testing.
