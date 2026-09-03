import '../app_player_style_models.dart';

const AppPlayerLyricsOption legacyLyricsOption = AppPlayerLyricsOption(
  metadata: AppPlayerStyleMetadata(
    id: 'legacy',
    labelKey: 'player.style.legacy',
    previewAsset: 'assets/player_styles/legacy/preview.png',
  ),
  lyricsKind: AppPlayerLyricsKind.legacy,
);