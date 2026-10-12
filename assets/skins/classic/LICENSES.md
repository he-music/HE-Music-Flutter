# Classic Skin Preview Provenance

The classic skin has no external wallpaper or icon assets. This directory contains deterministic real-UI previews generated from the application's bundled Material icons and theme tokens.

## Preview Baseline

- Manual accent baseline: `AppConfigState.initial.themeAccent`, currently `AppThemeAccent.forest`
- Light seed: `#166534`
- Dark seed: `#34D399`
- Generation: real routed Flutter home scene through `make skin-previews`
- Actual dimensions: `360x640` for both previews
- UI revision: regenerated for stronger borderless search fills in light and dark mode; the classic color palette is unchanged

The classic skin still supports manual accent selection. These static previews represent the application default accent and must be regenerated if `AppConfigState.initial.themeAccent` or the rendered shared UI changes.

## Light Preview

- Path: `assets/skins/classic/preview_light.png`
- SHA-256: `432fc2044fe4774c731c0d8a610997c066f1ee9142a28f056696b6106085358e`
- Actual dimensions: `360x640`

## Dark Preview

- Path: `assets/skins/classic/preview_dark.png`
- SHA-256: `15f29da6213f5efa0bd209354c7219e95ef2cca57ce2698d9ea3904ce42a752a`
- Actual dimensions: `360x640`
