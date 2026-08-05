# Starlit Melody Asset Provenance

This directory currently contains the approved light evaluation build, a user-confirmed dark runtime evaluation candidate, and deterministic light/dark real-UI previews. It does not contain a production dark wallpaper, animation, or custom SVG icon catalog.

## Light Provider Source

- Path: `assets/skins/starlit_melody/sources/wallpaper_light_provider.png`
- SHA-256: `ef01feb3bc440b514881287d9bf2c271fc3c8b25fa94e890722e6f41b3577820`
- Actual dimensions: `941x1672`
- Provider route: configured OpenAI-compatible Image API
- Model: `gpt-image-2`
- Request: `2160x3840`, `quality=high`, `size-policy=warn`, one image
- Prompt: `.trellis/tasks/07-28-anime-skin/references/starlit_melody_wallpaper_light_prompt.txt`
- Prompt SHA-256: `15157a1eef1fa586740101ee30aa5db2e247392faa376263df1788dbf92eac47`
- Approval: light character and composition approved by the user on 2026-07-28 for an in-App evaluation build

The provider returned a smaller image than requested. The source is retained unchanged and is not described as native 4K.

## Light Production Derivative

- Path: `assets/skins/starlit_melody/wallpaper_light.png`
- SHA-256: `7232392767ae9f99f6289130ffc446fe4a45986df91cfb7691846560b6d9c78c`
- Actual dimensions: `1882x3344`
- `upscaled=true`
- Scale factor: `2x`
- Face restoration: disabled
- Resize helper: `openai-image-api/scripts/resize_image.py`
- Resize backend: ImageMagick `7.1.2-13 Q16-HDRI`
- Resize parameters: exact `1882x3344`, `quality=95`
- Metadata normalization: `-strip -define png:exclude-chunk=time,date`
- Deterministic replay: independently resized and normalized output matched byte-for-byte with the same SHA-256

No generative enhancement, face repair, spatial crop, or composition change was applied during production resizing.

## Real UI Previews

- Generation: real routed Flutter home scene through `make skin-previews`
- Actual dimensions: `360x640` for both previews
- Light preview: `assets/skins/starlit_melody/preview_light.png`
- Light preview SHA-256: `5c6a1dcd1cb16c899da95f909471187f80b2f8838d7ffe70df8ce1577ff416e9`
- Dark preview: `assets/skins/starlit_melody/preview_dark.png`
- Dark preview SHA-256: `dff52ae2b9a789fd77c604e4644742c1bcab3209835fe79d4f1d8028e6507da0`
- Light tokens: Ice Rail primary `#00677A`, Berry Signal secondary `#B72F5B`, Ink text `#17202A`, transparent scrolling content surface
- Dark tokens: Ice Rail primary `#78D5E7`, blue-gray fixed surfaces, Mist text `#F0EDF5`, transparent scrolling content surface
- Approval status: the light preview and current dark evaluation appearance were approved by the user on 2026-07-28; these files were regenerated from those same runtime tokens

## Dark Runtime Evaluation Candidate

- Path: `assets/skins/starlit_melody/wallpaper_dark_evaluation.png`
- Candidate source: `.trellis/tasks/07-28-anime-skin/outputs/wallpaper_dark_graded_candidate_v1.png`
- SHA-256: `704ad67cc9b98dfe86d25b7a35d289a2d4bb0ff7ba9763cb7fac68638176650a`
- Actual dimensions: `941x1672`
- `upscaled=false`
- Image API generation/edit call: not used
- Processing: deterministic whole-image ImageMagick grade plus a fixed-coordinate star overlay; no local character mask, halo, crop, warp, face restoration, or generative enhancement
- Runtime promotion: byte-for-byte copy requested by the user on 2026-07-28 for on-device Gate B evaluation
- Approval status: current on-device evaluation appearance confirmed by the user on 2026-07-28; not a production dark wallpaper

The deterministic grade command, star-overlay parameters, rejected halo experiment, replay result, and review hashes are recorded in `.trellis/tasks/07-28-anime-skin/references/starlit_melody_dark_grade.md`.

## Deferred Production Scope

- `wallpaper_dark.png` does not exist. Dark mode and its real-UI preview use the original-size evaluation candidate until production upscaling is approved.
- `icons/` does not exist. All 81 semantic roles inherit their classic Material icon fallback.
- No Rive asset is declared. Both evaluation backgrounds are static.
- Only the light production wallpaper, original-size dark evaluation candidate, and two real-UI previews are declared in `pubspec.yaml`; provider sources and task review artifacts remain outside the runtime bundle.
