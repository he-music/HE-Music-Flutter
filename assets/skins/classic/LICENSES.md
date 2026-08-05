# Classic Skin Preview Provenance

The classic skin has no external wallpaper or icon assets. This directory contains deterministic real-UI previews generated from the application's bundled Material icons and theme tokens.

## Preview Baseline

- Manual accent baseline: `AppConfigState.initial.themeAccent`, currently `AppThemeAccent.forest`
- Light seed: `#166534`
- Dark seed: `#34D399`
- Generation: real routed Flutter home scene through `make skin-previews`
- Actual dimensions: `360x640` for both previews

The classic skin still supports manual accent selection. These static previews represent the application default accent and must be regenerated if `AppConfigState.initial.themeAccent` changes.

## Light Preview

- Path: `assets/skins/classic/preview_light.png`
- SHA-256: `2ce29fa1aa51137cd0104acecc1bc459b2d4c3a79042e70d7bb7db2adb29df6e`
- Actual dimensions: `360x640`

## Dark Preview

- Path: `assets/skins/classic/preview_dark.png`
- SHA-256: `d533291856e7265cb7f16b87fd9dabdb6a3df8c494831c98e6384a5bb3a7eadc`
- Actual dimensions: `360x640`
