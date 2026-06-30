# NomNomFTAP

Merged, hardened private-test Roblox hub for the grab/fling game family. Built from `Source/Strong` with **The Wourld** as the canonical UI/feature base, fixed and rebranded to NomNom.

## Files

- `NomNom.lua` - the full merged hub (single file).
- `Loader.lua` - thin loader that `HttpGet`s `NomNom.lua` from raw.
- `SOURCE_COMPARISON.md` - per-script comparison + merge rationale.
- `SOURCE_INVENTORY.md` - raw feature counts.
- `_fixed_sources/` - the 4 original scripts after syntax fixes.

## Usage

Run `Loader.lua` in your executor, or paste `NomNom.lua` directly. UI toggle key: **Right Shift**.

## Notes

- Base UI loads Obsidian + Linoria libraries via HttpGet.
- Deprecated `wait`/`spawn`/`delay` modernized to `task.*`.
- Brand strings/storage folders rebranded `Wourld*` -> `NomNom*`; external dependency URLs left intact.
- For owned/private testing.
