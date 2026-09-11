import '../app_player_style_models.dart';

// Registers the native Claddagh tilted lyric orbit.
const AppPlayerLyricsOption claddaghLyricsOption = AppPlayerLyricsOption(
  metadata: AppPlayerStyleMetadata(
    id: 'claddagh_lyrics',
    labelKey: 'player.style.claddagh_lyrics',
    previewAsset: 'assets/player_styles/claddagh_lyrics/preview.png',
  ),
  lyricsKind: AppPlayerLyricsKind.claddagh,
);
