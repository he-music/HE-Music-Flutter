# Player Style Preview Provenance

## Render contract

- Generator: `make player-style-previews`.
- Renderer: Flutter widget golden test using the real `PlayerPage`, shared responsive layout, style backdrop and style stage components.
- Logical output size: `360x640` for each preview.
- Fixed data: project logo artwork, Chinese track metadata, fixed playback position, fixed quality, paused hardware animation frame, and fixed test fonts.
- Output files: `assets/player_styles/classic/preview.png`, `assets/player_styles/vinyl/preview.png`, `assets/player_styles/cassette/preview.png`, and `assets/player_styles/artist_photo/preview.png`.
- License: project UI render; approved project assets and Flutter-rendered application UI may be distributed with HE Music.

## Artist photo source

- Provider source path: `assets/skins/city_sound_creator/sources/wallpaper_dark_provider_v2.png`.
- Source record: `assets/skins/city_sound_creator/LICENSES.md`, sections "Dark provider source" and "Dark production derivative".
- Provider: `sub2api`, an OpenAI-compatible provider.
- Model: `gpt-image-2` via the `openai-image-api` workflow.
- Requested size: `2160x3840`; provider original size: `941x1672`.
- Provider source SHA-256: `2442efaa998af1a23c51f160a32b06e484d0a739645a9a5f8ec3bfb43e9d8e2d`.
- Runtime preview input: `assets/skins/city_sound_creator/wallpaper_dark.png`, deterministic `1882x3344` production derivative.
- Runtime preview input SHA-256: `3b2cd675bc05b23fc37f98587d6da017f7a0bf4734d2e5ccc381e4b99eceef17`.
- Approval and license: the source and its deterministic derivative were approved by the user on 2026-07-17 for use as a project application asset.

## Generated preview hashes

- `assets/player_styles/classic/preview.png`: `8b0fef14a2587320651f413462b01e0382a7024d76b6dd23853721e1da20d4e4`.
- `assets/player_styles/vinyl/preview.png`: `17d6744b13dd502e94db7c7023a8edc1908e4c56b403e6e1c639ca9599318217`.
- `assets/player_styles/cassette/preview.png`: `bfc4da4a241af07d79a67b4f946c509eca47891da450592cb00c68be625a59f9`.
- `assets/player_styles/artist_photo/preview.png`: `388cca914a4b97034cde3d6702df4909d8441baf15903e6d4b3ec6b5a103edca`.
- Technical inspection: all four previews render readable fixed Chinese text, metadata badges, playback time and controls without blank regions or overflow; classic, vinyl, cassette and artist-photo subjects are visually distinct.
- Review status: automated golden and technical inspection completed on 2026-07-21; final product visual approval remains with the user.
