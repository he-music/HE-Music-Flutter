import 'package:flutter/material.dart';

import '../app_player_style_models.dart';

/// 经典封书背景使用的封面渐变示例色（供 cover_gradient 背景复用）。
const Color classicPlayerBackgroundStart = Color(0xFF24423A);
const Color classicPlayerBackgroundEnd = Color(0xFF080D0B);

const AppPlayerStageOption classicPlayerStage = AppPlayerStageOption(
  metadata: AppPlayerStyleMetadata(
    id: 'classic',
    labelKey: 'player.style.classic',
    previewAsset: 'assets/player_styles/classic/preview.png',
  ),
  stageKind: AppPlayerStageKind.classic,
  stageMaxWidth: 420,
);