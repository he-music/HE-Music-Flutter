# City Sound Creator Asset Provenance

## Release status

- Light provider source: approved by the user on 2026-07-17.
- Dark provider source: approved by the user on 2026-07-17.
- Production derivatives: 2x processing, technical inspection, and user approval completed on 2026-07-17.
- Runtime packaging: `pubspec.yaml` declares only runtime production assets (wallpaper derivatives, real UI previews, and the SVG catalog); provider sources and review files are excluded.

## Generation provider

- Provider: `sub2api` (the active OpenAI-compatible Codex provider).
- Model: `gpt-image-2`.
- Client: `openai-image-api`, Image API `/images/edits` endpoint.
- Requested size: `2160x3840`; the provider returned `941x1672` originals.
- The provider originals are not native 4K and are not described as such.

## Light provider source

- Path: `assets/skins/city_sound_creator/sources/wallpaper_light_provider_v5.png`.
- Actual dimensions: `941x1672`.
- SHA-256: `6716a96c0e87206237c020d1d5268d0dcdf0b11c351860b2e1c8b25f47a24808`.
- Prompt: `.trellis/tasks/07-16-configurable-skin-system/references/city_sound_creator_wallpaper_light_v5_prompt.txt`.
- Prompt SHA-256: `d9b216db850642e61e211e32bb86a8d33e21989135c5d63bb30d4e8c502b8ce7`.
- Reference 1: light V2 canvas/framing candidate, SHA-256 `cf8af05712d7b45bf8e7df12bd6a3078035fb525ebee09e71c4d5ac32608c550`.
- Reference 2: light V3 approved-direction candidate, SHA-256 `206eb595d63f92034d91075a587895ee96f2acf0831851c76f9c66d5ef6ea59e`.
- Approval: user approved the provider original on 2026-07-17.

## Dark provider source

- Path: `assets/skins/city_sound_creator/sources/wallpaper_dark_provider_v2.png`.
- Actual dimensions: `941x1672`.
- SHA-256: `2442efaa998af1a23c51f160a32b06e484d0a739645a9a5f8ec3bfb43e9d8e2d`.
- Prompt: `.trellis/tasks/07-16-configurable-skin-system/references/city_sound_creator_wallpaper_dark_v2_prompt.txt`.
- Prompt SHA-256: `bd1caca338050a5aa299c6f09927aab16b4295b33177acf8145785e6116adb7e`.
- Reference 1: approved light V5 provider source, SHA-256 `6716a96c0e87206237c020d1d5268d0dcdf0b11c351860b2e1c8b25f47a24808`.
- Reference 2: dark V1 palette concept, SHA-256 `a00b2a1eaaf84396a453e5d614c5e30fb04f227a6eb10dae94b8935ffbcdb8f8`.
- Approval: user approved the provider original on 2026-07-17.

## Production processing

- Processing type: deterministic 2x upscale; `upscaled=true`.
- Helper: `openai-image-api/scripts/resize_image.py`.
- Helper SHA-256: `f664fbfb430bb125923a49fd0b5bf98ff0d9d07529cf8a71adcb380249306832`.
- Backend: ImageMagick `7.1.2-13 Q16-HDRI`, arm64.
- Parameters: exact `1882x3344` resize, PNG output, `quality=95`, no crop, no sharpening, no generative enhancement.
- Face restoration: disabled; the processing pipeline has no face-restoration stage.
- Processing count: one production upscale per approved provider original.

### Light production derivative

- Path: `assets/skins/city_sound_creator/wallpaper_light.png`.
- Actual dimensions: `1882x3344`.
- SHA-256: `5da529d8fa41a4c2a487de2c3078dd9c1aff918a13bb3cd64edf51246e845a49`.
- Source: `wallpaper_light_provider_v5.png`.
- Scale: `2x`.
- Upscaled: `true`.

### Dark production derivative

- Path: `assets/skins/city_sound_creator/wallpaper_dark.png`.
- Actual dimensions: `1882x3344`.
- SHA-256: `3b2cd675bc05b23fc37f98587d6da017f7a0bf4734d2e5ccc381e4b99eceef17`.
- Source: `wallpaper_dark_provider_v2.png`.
- Scale: `2x`.
- Upscaled: `true`.

## Technical inspection

The 2x derivatives were inspected at full frame and in local detail crops on 2026-07-17.

- Face and light/dark character identity: pass.
- Hands, fingers, and sampler interaction: pass.
- Headphones, waveform display, turntable, sampler, and record-shelf edges: pass.
- Halos, jagged edges, amplified noise, and invented detail: no blocking issue found.
- Text, logos, signatures, watermarks, and extra people: no blocking issue found.
- Final user approval of the 2x derivatives: approved on 2026-07-17.

## Semantic icon catalog

- Production path: `assets/skins/city_sound_creator/icons/`.
- Review source: `outputs/city_sound_creator_icons_v2/`.
- Review manifest SHA-256: `6b7f2aa9162637585e1a319ecc8ffe1250cc25099f67bfdf5866165b11804d68`.
- Scope: 71 semantic roles mapped to 53 unique `24x24` SVG files; 18 strictly synonymous roles intentionally reuse an existing asset.
- Authorship: project-original vector paths authored for this skin; no third-party icon set, stock vector, font glyph, embedded image, or generated raster source is bundled.
- Promotion: the 53 approved SVG files were copied from the V2 review source with no tracing, conversion, recoloring, or optimization pass; trailing blank lines were normalized to one EOF newline for repository whitespace compliance.
- Runtime color contract: `#E85D52` is the exact replaceable source color; device teal `#138F87`, beat yellow `#E7B93E`, and other authored identity colors remain fixed.
- Technical inspection: XML parsing, `viewBox="0 0 24 24"`, 20px/24px rendering, light/dark surfaces, forbidden embedded elements, and role-to-asset completeness passed on 2026-07-17.
- Approval: the user approved the complete V2 icon catalog on 2026-07-17.
- Runtime packaging: `pubspec.yaml` declares only the production `icons/` directory; the review HTML, manifest, and preview PNG files remain outside the app bundle.

## Real UI skin previews

- Generator: `make skin-previews`, which runs `flutter test --update-goldens test/app/theme/skin_preview_golden_test.dart`.
- Render contract: actual `MaterialApp.router`, `AppTheme`, `AppSkinBackgroundLayer`, home route, discover entries, song list, mini player, bottom navigation, production wallpapers, and production SVG catalog at a fixed `360x640` logical-pixel viewport.
- Data contract: deterministic Riverpod overrides provide fixed English UI content; no image model redraws or synthesizes application text.
- Test fonts: Roboto Regular, Medium, and Bold under Apache License 2.0; the files and license are retained under `test/assets/fonts/` and are not declared as runtime assets.
- Material fallback icons: loaded from the Material Icons font already declared by Flutter's `uses-material-design` contract.
- Technical inspection: both previews show the decoded production wallpaper, readable text, production SVGs, Material fallbacks, mini player, and navigation without blank regions or overlaps. The 2026-07-17 contrast revision adds zero-blur scrolling content surfaces and a stronger light overlay; the later home-section revision removes the background surface from section title rows.
- Approval: the user approved the original real-UI preview stage on 2026-07-17; the later contrast revision remains pending visual confirmation.

### Light real UI preview

- Path: `assets/skins/city_sound_creator/preview_light.png`.
- Actual dimensions: `360x640`.
- SHA-256: `73647d7cee0fd0d8753e921b3f782fe53cb575925a1c54852aceffd392e7a438`.

### Dark real UI preview

- Path: `assets/skins/city_sound_creator/preview_dark.png`.
- Actual dimensions: `360x640`.
- SHA-256: `afbde82aad22cad3d7c5b041335eede125ba1ec4147867cac187fc273a5d36a4`.

## Usage note

The wallpaper raster assets were generated for this project through the configured provider; the real UI preview rasters are deterministic Flutter renders of those production assets. No third-party stock image is bundled. Distribution and external reuse of the generated wallpaper remain subject to the generation provider account terms. This record documents provenance and processing; it does not claim that the upscaled derivatives are native 4K.
