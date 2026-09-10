import '../app_player_style_models.dart';

// Registers the native Pendolo lyric wheel.
const AppPlayerLyricsOption pendoloLyricsOption = AppPlayerLyricsOption(
  metadata: AppPlayerStyleMetadata(
    id: 'pendolo_lyrics',
    labelKey: 'player.style.pendolo_lyrics',
    previewAsset: 'assets/player_styles/pendolo_lyrics/preview.png',
  ),
  lyricsKind: AppPlayerLyricsKind.pendolo,
);
