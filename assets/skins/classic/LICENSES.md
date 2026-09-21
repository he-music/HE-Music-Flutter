# Classic Skin Preview Provenance

The classic skin has no external wallpaper or icon assets. This directory contains deterministic real-UI previews generated from the application's bundled Material icons and theme tokens.

## Preview Baseline

- Manual accent baseline: `AppConfigState.initial.themeAccent`, currently `AppThemeAccent.forest`
- Light seed: `#166534`
- Dark seed: `#34D399`
- Generation: real routed Flutter home scene through `make skin-previews`
- Actual dimensions: `360x640` for both previews
- UI revision: regenerated on 2026-08-26 after the shared song item layout adjustment; theme tokens and bundled assets are unchanged

The classic skin still supports manual accent selection. These static previews represent the application default accent and must be regenerated if `AppConfigState.initial.themeAccent` changes.

## Light Preview

- Path: `assets/skins/classic/preview_light.png`
- SHA-256: `374ca4b0a8d506017c7e2dd24a0c9f20c8232b7dc22ffd749f95585ee0058d92`
- Actual dimensions: `360x640`

## Dark Preview

- Path: `assets/skins/classic/preview_dark.png`
- SHA-256: `26b02b9f739a7ebaf1041dc3b4fce94dd39194065b9923d0fe8243d50543c609`
- Actual dimensions: `360x640`
