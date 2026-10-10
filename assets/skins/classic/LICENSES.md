# Classic Skin Preview Provenance

The classic skin has no external wallpaper or icon assets. This directory contains deterministic real-UI previews generated from the application's bundled Material icons and theme tokens.

## Preview Baseline

- Manual accent baseline: `AppConfigState.initial.themeAccent`, currently `AppThemeAccent.forest`
- Light seed: `#166534`
- Dark seed: `#34D399`
- Generation: real routed Flutter home scene through `make skin-previews`
- Actual dimensions: `360x640` for both previews
- UI revision: regenerated for unified search fields, tabs and 48-pixel control touch targets; the classic color palette is unchanged

The classic skin still supports manual accent selection. These static previews represent the application default accent and must be regenerated if `AppConfigState.initial.themeAccent` or the rendered shared UI changes.

## Light Preview

- Path: `assets/skins/classic/preview_light.png`
- SHA-256: `569481f18313aed6b3e7eaeac714008ec5c43da9538a15f3b716cee70e0e41cc`
- Actual dimensions: `360x640`

## Dark Preview

- Path: `assets/skins/classic/preview_dark.png`
- SHA-256: `21515811cde98595039e6d8775793a0cf03cf2727e5a3e68f56a2f79e3ace650`
- Actual dimensions: `360x640`
