# Classic Skin Preview Provenance

The classic skin has no external wallpaper or icon assets. This directory contains deterministic real-UI previews generated from the application's bundled Material icons and theme tokens.

## Preview Baseline

- Manual accent baseline: `AppConfigState.initial.themeAccent`, currently `AppThemeAccent.forest`
- Light seed: `#166534`
- Dark seed: `#34D399`
- Generation: real routed Flutter home scene through `make skin-previews`
- Actual dimensions: `360x640` for both previews
- UI revision: regenerated on 2026-08-11 with compact MiniPlayer and bottom navigation heights; theme tokens and bundled assets are unchanged

The classic skin still supports manual accent selection. These static previews represent the application default accent and must be regenerated if `AppConfigState.initial.themeAccent` changes.

## Light Preview

- Path: `assets/skins/classic/preview_light.png`
- SHA-256: `0c7dda2a66c134cc0d2ce5e325bc540e129ea774e993fd1b8914d84698b81e4f`
- Actual dimensions: `360x640`

## Dark Preview

- Path: `assets/skins/classic/preview_dark.png`
- SHA-256: `b98d3fcf60fcf70e946640abe78185f382ce34d3e485cdfb0f824be9ff3b9e88`
- Actual dimensions: `360x640`
