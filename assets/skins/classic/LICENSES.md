# Classic Skin Preview Provenance

The classic skin has no external wallpaper or icon assets. This directory contains deterministic real-UI previews generated from the application's bundled Material icons and theme tokens.

## Preview Baseline

- Manual accent baseline: `AppConfigState.initial.themeAccent`, currently `AppThemeAccent.forest`
- Light seed: `#166534`
- Dark seed: `#34D399`
- Generation: real routed Flutter home scene through `make skin-previews`
- Actual dimensions: `360x640` for both previews
- UI revision: regenerated on 2026-08-07 after the Home search control became a compact floating sliver; theme tokens and bundled assets are unchanged

The classic skin still supports manual accent selection. These static previews represent the application default accent and must be regenerated if `AppConfigState.initial.themeAccent` changes.

## Light Preview

- Path: `assets/skins/classic/preview_light.png`
- SHA-256: `5a56623f39e2f11f6b9373ab100bcc4d676a2561eb15db8724d3c44edf474cb2`
- Actual dimensions: `360x640`

## Dark Preview

- Path: `assets/skins/classic/preview_dark.png`
- SHA-256: `7d1edbbd32336cd3f47e706cee8aef420c84a7721bc4a17a4219802a5dad5516`
- Actual dimensions: `360x640`
