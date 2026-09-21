# Use liquid glass as a control surface

**Status: accepted**

HE-Music uses `liquid_glass_widgets` for navigation and control surfaces. Existing skins continue to own backgrounds, color identity, and icons; lists, media content, and lyrics remain content surfaces. Feature code uses project adapters and the package's public API. All subsequent changes and reviews follow `.pi/skills/liquid-glass-widgets/SKILL.md` as required by `AGENTS.md`.

The main bootstrap preloads shaders and wraps the app with adaptive quality and the Material brightness resolver. The independent lyrics overlay is excluded. Flutter 3.41+ is required. `ENABLE_LIQUID_GLASS=false` skips setup and restores Material/skin surfaces.

## Page composition and quality

Both the tab shell and root content routes containing a MiniPlayer use `AppGlassPlayerScaffold`, backed by `GlassScaffold`. The adapter owns bottom safe-area spacing once, using viewPadding to keep chrome stationary when the keyboard opens. It only observes whether a display track exists; progress and track identity changes do not rebuild the page shell. The existing background remains authoritative; the scaffold uses the active skin's background color, including transparent backgrounds for wallpaper skins.

The tab shell extends content beneath navigation. Its home/my scroll content consumes the supplied bottom clearance. Root detail pages reserve MiniPlayer space to preserve existing content bounds. Navigation uses `GlassTabBar.bottom` and its own selection indicator. Global quality is standard; navigation and the MiniPlayer request premium individually, always subject to the adaptive ceiling. High-contrast fallback keeps control surfaces opaque.

Navigation and MiniPlayer material follows the official [Apple Music demo](https://github.com/sdegenaar/liquid_glass_widgets/blob/main/example/lib/apple_music/apple_music_demo.dart): thickness 30, blur 2, saturation 1.2, chromatic aberration .01, Fresnel strength 0, navigation alpha 0xAA/light intensity .2, and player pill alpha 0xCC/light intensity .18. The skin supplies the hue. MiniPlayer retains existing swipe and button behavior within a glass container; its children are not refractive controls.

## Modal sheets

The glass branch of `showAppThemedBottomSheet` uses `GlassModalSheet.show` with medium/large detents. All callers start at their medium detent: song menus and queues explicitly reuse the original 0.60 screen-height token via `initialHeightFactor`, while ordinary short action panels retain the 0.45 default. Material's `isScrollControlled` is a layout permission, not a request to open full-screen. Half and full states explicitly use the package's 1.6.1 sheet optics (reproduced through the public API because the preset constant is internal), so expanding does not activate the default opaque-fill transition. Tint comes from the library's light/dark GlassThemeVariant selected by Material Theme.brightness. The skin's bottom-sheet color supplies the documented 35% backerColor contrast pad, preserving light/dark identity over busy backgrounds. Content keeps the captured Material text/icon theme; the drag indicator uses onSurfaceVariant. Press feedback remains unchanged. Sheets explicitly request standard quality. A transparent Material ancestor preserves existing Ink, text and form controls; caller themes, root/local Navigator selection, result futures, safe areas and keyboard insets are handled by the adapter. There is no additional AppGlassSurface around sheet content. The queue empty state uses plain padding/text rather than another blurred panel.

The disabled branch retains `showModalBottomSheet`. The earlier Material-scaffold and glass-wrapper-only sheet implementations were superseded during skill compliance review: they did not provide the required page compositing or native sheet interaction model. This migration intentionally changes glass-sheet presentation to the package's detents; it is not a pixel-identical reskin.

## Validation boundary

Unit/widget tests verify fallback, quality intent, layout, keyboard stability, sheet result/dismissal and queue state behavior. Tests use a minimal adaptive ceiling to avoid GPU dependence; production still requests the quality levels above. They do not prove premium shader appearance or device performance. Manual platform, visual, accessibility and performance acceptance is recorded in `docs/liquid-glass-acceptance.md`.
