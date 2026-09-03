import '../app_player_style_models.dart';

const AppPlayerStageOption vinylPlayerStage = AppPlayerStageOption(
  metadata: AppPlayerStyleMetadata(
    id: 'vinyl',
    labelKey: 'player.style.vinyl',
    previewAsset: 'assets/player_styles/vinyl/preview.png',
  ),
  stageKind: AppPlayerStageKind.vinyl,
  stageMaxWidth: 450,
);