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
- SHA-256: `2a2ad1c28453286d6c24fc023b1e06964abc0927e0a3d9b9dea07e02a5caa127`
- Actual dimensions: `360x640`

## Dark Preview

- Path: `assets/skins/classic/preview_dark.png`
- SHA-256: `7b811916c34e5fc9e062a4b549440fc938065ab14d3f4c9cf7f923325bfeb7cc`
- Actual dimensions: `360x640`
