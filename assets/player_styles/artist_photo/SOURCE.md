# Artist photo preview source

The sample photo in `test/assets/player/artist_photo.png` was supplied by the project owner for the style picker. It is not used as an artist photo during playback.

Regenerate the 360x640 preview with:

```sh
flutter test test/app/theme/player_component_preview_test.dart \
  --dart-define=GENERATE_PLAYER_PREVIEWS=true \
  --dart-define=PREVIEW_AXIS=backdrop \
  --dart-define=PREVIEW_OPTION=artist_photo
```

The export uses `BoxFit.cover` and applies a 20% black overlay. Playback continues to fetch the current artist's photos.
