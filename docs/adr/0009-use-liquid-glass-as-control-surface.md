# Use liquid glass as a control surface

**Status: accepted**

HE-Music uses `liquid_glass_widgets` for navigation and control surfaces. Skins own backgrounds, color identity, geometry and icons; songs, media content and lyrics remain readable content surfaces. Subsequent changes and reviews follow `.pi/skills/liquid-glass-widgets/SKILL.md` as required by `AGENTS.md`.

The main bootstrap preloads shaders and wraps the app with adaptive quality and the Material brightness resolver. The independent lyrics overlay is excluded. Flutter 3.41+ is required. `ENABLE_LIQUID_GLASS=false` skips setup and restores Material/skin surfaces. The runtime glass preference can change presentation without remounting the Navigator.

## Page composition and quality

Tab and root content routes containing a MiniPlayer use `AppGlassPlayerScaffold`, backed by `GlassScaffold`. It owns bottom safe-area spacing once, using viewPadding to keep chrome stationary when the keyboard opens. It observes only whether a display track exists; playback progress does not rebuild the page shell. Root content and MiniPlayer widths are capped at the same 1120 logical pixels as desktop tab content. Mobile pages retain their full available width.

Navigation uses `GlassTabBar.minimizable`. It integrates the MiniPlayer accessory and collapses according to the shared scroll policy. Re-selecting the active tab expands the bar and returns its content to the top. High contrast, reduced motion, insufficient width or oversized text disables minimization.

Ordinary controls and sheets request standard quality. Persistent navigation and MiniPlayer surfaces may request premium in automatic and high modes. High mode starts with a premium ceiling; it does not promote every control to premium. Every mode permits degradation to minimal. Standard and power-saving modes cap quality at standard, while low and off cap it at minimal. Recovery is permitted up to the selected ceiling in automatic, high, standard and power-saving modes. The library's adaptive and accessibility scopes remain authoritative. Power saving retains glass only for persistent navigation and playback surfaces.

Navigation and MiniPlayer material follows the official [Apple Music demo](https://github.com/sdegenaar/liquid_glass_widgets/blob/main/example/lib/apple_music/apple_music_demo.dart): thickness 30, blur 2, saturation 1.2, chromatic aberration .01, Fresnel strength 0, navigation alpha 0xAA/light intensity .2, and player pill alpha 0xCC/light intensity .18. The skin supplies the hue. MiniPlayer children remain non-refractive controls.

Settings uses `GlassScaffold` and native glass navigation when enabled. Its home adapts to two section columns on desktop; section forms are capped at 720 logical pixels. Search pages share `AppSearchField`: a native standalone `GlassTextField` when controls are enabled, and a Material field with visible focus feedback otherwise. The home search entry uses native `GlassButton.custom` with the same geometry. These controls have no enclosing refractive container. Search height grows with text scale, radius follows the skin, and clear/navigation buttons retain 48-pixel touch targets.

Settings reserves the toolbar area with `extendBody: false`; its explicitly padded lists must not start underneath navigation. The floating home search row clips scrolling content below its moving lower edge, keeping wallpaper visible through glass while excluding scrolling text. This changes paint clipping rather than scroll layout and preserves the PageView across visibility changes. With glass controls disabled, the search submit icon retains its 48-pixel target and uses the input's fill color and rounded-rectangle radius instead of Material's default secondary-color circular background.

## Modal sheets

`showAppThemedBottomSheet` uses the public `GlassModalSheetScaffold` through `showLiveGlassSheet`. Its route resolves the current navigator theme so open sheets respond to appearance changes. Sheets use one medium detent at the requested height and can be dragged down to dismiss. Short panels may measure content before entering; they do not open at the maximum height and then shrink. `isScrollControlled` is a Material layout permission, not a request to open full-screen.

`LayoutTokens` owns heights: song/download action menus use a 0.72 maximum, selections use 0.80, and queues and long content use 0.88. Callers explicitly pass their height or opt into fitting short content. There is no intermediate queue stop. The 1.6.1 sheet optics are reproduced through public settings because the preset is internal. The current light/dark skin supplies a 35% backerColor contrast pad. Content keeps Material text/icon semantics, handles safe areas and keyboard insets, and never adds another refractive surface around the sheet. Disabled glass controls retain the Material sheet path.

Floating sheets retain the package entry point's 8-logical-pixel horizontal and bottom margins. The spacing preserves the floating outline; it is not required by the glass renderer. This records a package default, without claiming an Apple requirement for that value. Content measurement uses the same inset width as the visible sheet so wrapped text contributes the correct height. Player speed, volume, sleep presets/custom duration and mobile adaptive action menus opt into content fitting; slider and custom duration panels can scroll when space or text scaling requires it.

## Validation boundary

Widget tests verify navigation preservation, quality intent and ceilings, search submit/clear/focus behavior, layout, keyboard stability and sheet results. Tests use a minimal adaptive ceiling to avoid GPU dependence; they do not prove premium shader appearance, physical input accessibility or device frame rate. Manual visual, accessibility and performance acceptance is described in `docs/liquid-glass-acceptance.md`.

Earlier documentation described `GlassTabBar.bottom`, 60% queues and medium/large sheet detents. Those descriptions no longer matched the implementation. This revision records the existing single-height sheet behavior and the unified controls/quality policy; tests passing alone do not replace this specification check.
