# City Sound Creator Asset Provenance

## Release status

- Light provider source: approved by the user on 2026-07-17.
- Original dark provider source and derivative: approved by the user on 2026-07-17; the source remains as a palette/provenance reference and its derivative was replaced on 2026-07-27.
- Deterministic dark grade source, replacement production derivative, real UI previews, player previews, and existing Rive alignment: approved by the user on 2026-07-27.
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

## Original dark provider source

- Path: `assets/skins/city_sound_creator/sources/wallpaper_dark_provider_v2.png`.
- Actual dimensions: `941x1672`.
- SHA-256: `2442efaa998af1a23c51f160a32b06e484d0a739645a9a5f8ec3bfb43e9d8e2d`.
- Prompt: `.trellis/tasks/07-16-configurable-skin-system/references/city_sound_creator_wallpaper_dark_v2_prompt.txt`.
- Prompt SHA-256: `bd1caca338050a5aa299c6f09927aab16b4295b33177acf8145785e6116adb7e`.
- Reference 1: approved light V5 provider source, SHA-256 `6716a96c0e87206237c020d1d5268d0dcdf0b11c351860b2e1c8b25f47a24808`.
- Reference 2: dark V1 palette concept, SHA-256 `a00b2a1eaaf84396a453e5d614c5e30fb04f227a6eb10dae94b8935ffbcdb8f8`.
- Approval: user approved the provider original on 2026-07-17.
- Current role: retained as the approved night-palette reference; it is no longer the geometry or production-derivative source.

## Deterministic dark grade correction

- Path: `assets/skins/city_sound_creator/sources/wallpaper_dark_graded_v1.png`.
- Actual dimensions: `941x1672`.
- SHA-256: `5d6b1dc447f70dfc2c05be26e87fd649a4d69b290345838b86864568a09949f0`.
- Geometry source: approved `wallpaper_light_provider_v5.png`, SHA-256 `6716a96c0e87206237c020d1d5268d0dcdf0b11c351860b2e1c8b25f47a24808`.
- Palette reference: original `wallpaper_dark_provider_v2.png`, SHA-256 `2442efaa998af1a23c51f160a32b06e484d0a739645a9a5f8ec3bfb43e9d8e2d`.
- Processing: deterministic ImageMagick HSL channel math, saturation multiplier `0.90`, continuous lightness curve, and `8%` `#101413` color blend.
- Geometry contract: every output pixel reads only the same input coordinate; no spatial transform, crop, resize, blur, sharpen, generative edit, face restoration, or local redraw is used.
- Deterministic output: PNG time/date metadata is stripped; an independent full replay passed byte comparison and produced the same SHA-256.
- Candidate visual approval: approved on 2026-07-27.

## Production processing

- Processing type: deterministic 2x upscale; `upscaled=true`.
- Helper: `openai-image-api/scripts/resize_image.py`.
- Helper SHA-256: `f664fbfb430bb125923a49fd0b5bf98ff0d9d07529cf8a71adcb380249306832`.
- Backend: ImageMagick `7.1.2-13 Q16-HDRI`, arm64.
- Parameters: exact `1882x3344` resize, PNG output, `quality=95`, no crop, no sharpening, no generative enhancement.
- Face restoration: disabled; the processing pipeline has no face-restoration stage.
- Processing count: one current production upscale per approved source; the replacement dark derivative uses the approved deterministic grade source.

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
- SHA-256: `4364a6fdd1e14e7f854ff599aed1f8bb349734d10e759d602b69fc131ed46706`.
- Source: `wallpaper_dark_graded_v1.png`.
- Scale: `2x`.
- Upscaled: `true`.
- Output normalization: PNG time/date metadata stripped; a second independent resize produced the same bytes and SHA-256.

## Technical inspection

The original 2x derivatives were inspected at full frame and in local detail crops on 2026-07-17.

- Face and light/dark character identity: pass.
- Hands, fingers, and sampler interaction: pass.
- Headphones, waveform display, turntable, sampler, and record-shelf edges: pass.
- Halos, jagged edges, amplified noise, and invented detail: no blocking issue found.
- Text, logos, signatures, watermarks, and extra people: no blocking issue found.
- Final user approval of the 2x derivatives: approved on 2026-07-17.

The replacement dark derivative was inspected at full frame and local detail on 2026-07-27.

- Source/production dimensions, hashes, deterministic replay, and zero spatial-transform contract: pass.
- Face, hands, headphones, waveform display, turntable, sampler, plants, and record shelf: pass.
- Halos, jagged edges, amplified noise, invented detail, text, logos, watermarks, and extra people: no blocking issue found.
- Alignment against the light source: same pixel geometry by construction; blink/side-by-side review passed.
- Replacement dark derivative approval: approved by the user on 2026-07-27 after real UI, player-preview, and existing Rive alignment review.

## Semantic icon catalog

- Production path: `assets/skins/city_sound_creator/icons/`.
- Original V2 review manifest SHA-256: `6b7f2aa9162637585e1a319ecc8ffe1250cc25099f67bfdf5866165b11804d68`.
- Scope: 81 semantic roles mapped to 55 unique `24x24` SVG files; 26 strictly synonymous or visually equivalent roles intentionally reuse an existing asset.
- Authorship: project-original vector paths authored for this skin; no third-party icon set, stock vector, font glyph, embedded image, or generated raster source is bundled.
- Promotion: the original 53 approved V2 SVG files were promoted with no tracing, conversion, recoloring, or optimization pass; trailing blank lines were normalized to one EOF newline for repository whitespace compliance.
- Runtime color contract: `#E85D52` is the exact replaceable source color; device teal `#138F87`, beat yellow `#E7B93E`, and other authored identity colors remain fixed.
- Technical inspection: XML parsing, `viewBox="0 0 24 24"`, 20px/24px rendering, light/dark surfaces, forbidden embedded elements, and role-to-asset completeness passed on 2026-07-17.
- Approval: the user approved the complete V2 icon catalog on 2026-07-17.
- Runtime packaging: `pubspec.yaml` declares only the production `icons/` directory; temporary review HTML, manifest, and preview files were discarded after approval.

### Incremental V2 extension (2026-07-23)

- Task: `.trellis/tasks/07-23-city-sound-skin-icon-coverage/`.
- Added `refresh.svg`, SHA-256 `89d2a9972cad2420191b0a8c54a820b8afb81c77f95e6018ab9abeeb93139152`.
- Added `batch_deselect_all.svg`, SHA-256 `3b89098a822bd5032d401acc1e0a7893f8459d31c06042de67170796cb27b8eb`.
- Authorship: project-original vector paths authored directly for this extension from the approved V2 stroke, corner, and palette contract; no third-party or generated raster source was used.
- Reuse: eight new semantic roles reuse approved V2 assets while keeping role-specific Material fallbacks for `classic`.
- Review contract: XML parsing, `24x24` viewBox, source-color presence, forbidden-element checks, 20dp/24dp rendering, light/dark rendering, and full role-to-file coverage.

## Real UI skin previews

- Generator: `make skin-previews`, which runs `flutter test --update-goldens test/app/theme/skin_preview_golden_test.dart`.
- Render contract: actual `MaterialApp.router`, `AppTheme`, `AppSkinBackgroundLayer`, home route, discover entries, song list, mini player, bottom navigation, production wallpapers, and production SVG catalog at a fixed `360x640` logical-pixel viewport.
- Data contract: deterministic Riverpod overrides provide fixed Chinese UI content; no image model redraws or synthesizes application text.
- Test fonts: Roboto Regular, Medium, and Bold plus a 14 KB Chinese glyph subset derived from Android Open Source Project's Droid Sans Fallback, all under Apache License 2.0. The files, subset glyph manifest, provenance, and license are retained under `test/assets/fonts/` and are not declared as runtime assets.
- Material fallback icons: loaded from the Material Icons font already declared by Flutter's `uses-material-design` contract.
- Technical inspection: both previews show the decoded production wallpaper, readable Chinese text, production SVGs, Material fallbacks, mini player, and navigation without blank regions or overlaps. The current revision uses a roughly `48%` white readability overlay in light mode; scrolling Items are transparent in both brightness modes and transparent surfaces do not draw shadows.
- Approval: the user approved the original real-UI preview stage on 2026-07-17 and the current light/dark preview pair with the replacement dark wallpaper on 2026-07-27.

### Light real UI preview

- Path: `assets/skins/city_sound_creator/preview_light.png`.
- Actual dimensions: `360x640`.
- SHA-256: `3c67bd41062d677c5d491705e2cc783d3af0c05f78e932b7825e54d320432654`.

### Dark real UI preview

- Path: `assets/skins/city_sound_creator/preview_dark.png`.
- Actual dimensions: `360x640`.
- SHA-256: `6d3bca3a5c1f83a18525fab74201a50a4ce1cf4bebd29bcd2a9499fa0c854dc0`.

## Rive ambient animation

- Runtime path: `assets/skins/city_sound_creator/ambient.riv`.
- Temporary generation inputs and review renders were discarded after the
  approved runtime asset and its provenance were promoted.
- Authorship: project-original vector shapes and motion authored for this skin;
  no third-party image, font, audio, script, or external file is embedded.
- Generator: unofficial `rive-mcp-server` `0.3.0`, repository commit
  `db7462eaee30dad0c3c1ec37c2bdfdcd47b37365`.
- Generator license: source-available freeware; its license permits personal
  and commercial use and unrestricted use, modification, and distribution of
  generated `.riv` files. The generator itself is not bundled with the App.
- File size: `8603` bytes.
- SHA-256: `0c40df781b4f6d0125a9d1054cb7080a6e67ef2c7ad1bafbb308de546761d218`.
- Runtime contract: Artboard `CitySoundAmbient`, Animation `ambient_loop`,
  State Machine `AmbientLoop`, no inputs, transparent `360x640` artboard,
  8-second 30 fps loop.
- Composition: wallpaper, light/dark readability overlay, sparse device-bound
  Rive animation, then App content. Wallpaper and Rive share the same fit and
  alignment so their device coordinates remain attached on tall screens.
- Validation: `rive-mcp` `riv_lint` returned no findings; the official Rive Web
  runtime loaded and rendered 120 preview frames and entered `ambient_loop`;
  the Flutter runtime integration tests load the bundled bytes and named State
  Machine.
- Approval: the user approved V2 for an in-App trial on 2026-07-20 and approved
  its alignment with the replacement dark wallpaper on 2026-07-27. Final Android
  lifecycle, frame pacing, GPU, and memory acceptance remains pending.

## Usage note

The wallpaper raster assets were generated for this project through the configured provider; the real UI preview rasters are deterministic Flutter renders of those production assets. No third-party stock image is bundled. Distribution and external reuse of the generated wallpaper remain subject to the generation provider account terms. This record documents provenance and processing; it does not claim that the upscaled derivatives are native 4K.
