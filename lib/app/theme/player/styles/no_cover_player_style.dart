import '../app_player_style_models.dart';
import 'classic_player_style.dart';

/// 保留经典封面的布局与留白，不绘制前景封面。
const AppPlayerStageOption noCoverPlayerStage = AppPlayerStageOption(
  metadata: AppPlayerStyleMetadata(
    id: 'none',
    labelKey: 'player.style.none',
    previewAsset: 'assets/player_styles/none/preview.png',
  ),
  stageKind: AppPlayerStageKind.none,
  stageMaxWidth: classicPlayerStageMaxWidth,
);
