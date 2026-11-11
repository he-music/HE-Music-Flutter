# Classic Skin Preview Provenance

The classic skin has no external wallpaper or icon assets. This directory contains deterministic real-UI previews generated from the application's bundled Material icons and theme tokens.

## Preview Baseline

- Manual accent baseline: `AppConfigState.initial.themeAccent`, currently `AppThemeAccent.forest`
- Light seed: `#166534`
- Dark seed: `#34D399`
- Generation: real routed Flutter home scene through `make skin-previews`
- Actual dimensions: `360x640` for both previews
- UI revision: Material uses Discover / Library / My navigation with a 64 px content height, 24 px icons, and its selection indicator, an independent opaque mini player card with 12 px horizontal margins, 8 px vertical margins, 16 px corner radius and 60 px minimum height, and compact recommendation / browse TabBar and secondary platform FilterChips; the content viewport extends behind playback and navigation, with scrollable end padding keeping the final item accessible; the classic color palette is unchanged

The classic skin still supports manual accent selection. These static previews represent the application default accent and must be regenerated if `AppConfigState.initial.themeAccent` or the rendered shared UI changes.

## Light Preview

- Path: `assets/skins/classic/preview_light.png`
- SHA-256: `72987bca5ff085d18bc2890c593fe105e043042483a4d7dcc3927b8a5f361467`
- Actual dimensions: `360x640`

## Dark Preview

- Path: `assets/skins/classic/preview_dark.png`
- SHA-256: `cde769c392bbc8d7e84ff021f42fae359b067828747508ba9fca44465f9cbc85`
- Actual dimensions: `360x640`
