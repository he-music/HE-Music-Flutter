# Classic Skin Preview Provenance

The classic skin has no external wallpaper or icon assets. This directory contains deterministic real-UI previews generated from the application's bundled Material icons and theme tokens.

## Preview Baseline

- Manual accent baseline: `AppConfigState.initial.themeAccent`, currently `AppThemeAccent.forest`
- Light seed: `#166534`
- Dark seed: `#34D399`
- Generation: real routed Flutter home scene through `make skin-previews`
- Actual dimensions: `360x640` for both previews
- UI revision: Material uses Discover / Library / My navigation with its selection indicator, an adjoining opaque playback bar, and compact recommendation / browse TabBar and secondary platform FilterChips; the classic color palette is unchanged

The classic skin still supports manual accent selection. These static previews represent the application default accent and must be regenerated if `AppConfigState.initial.themeAccent` or the rendered shared UI changes.

## Light Preview

- Path: `assets/skins/classic/preview_light.png`
- SHA-256: `dc8fe609d9d2a0cfd919ecda07f00906297c2e776a3b314a368e3a8f9800384f`
- Actual dimensions: `360x640`

## Dark Preview

- Path: `assets/skins/classic/preview_dark.png`
- SHA-256: `eb0f5216eb038dcf4dbcb0bc8082004be2deba9927a0eb7e2f8edcb0dc087aec`
- Actual dimensions: `360x640`
