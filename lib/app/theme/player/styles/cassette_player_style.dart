import '../app_player_style_models.dart';

const AppPlayerStageOption cassettePlayerStage = AppPlayerStageOption(
  metadata: AppPlayerStyleMetadata(
    id: 'cassette',
    labelKey: 'player.style.cassette',
    previewAsset: 'assets/player_styles/cassette/preview.png',
  ),
  stageKind: AppPlayerStageKind.cassette,
  stageMaxWidth: 470,
);