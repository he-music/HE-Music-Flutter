import 'package:flutter/material.dart';

import '../app_player_style_models.dart';

/// 流体网状渐变背景。
const AppPlayerBackdropOption fluidPlayerBackdrop = AppPlayerBackdropOption(
  metadata: AppPlayerStyleMetadata(
    id: 'fluid',
    labelKey: 'player.style.fluid',
    previewAsset: 'assets/player_styles/fluid/preview.png',
  ),
  backdropKind: AppPlayerBackdropKind.fluid,
  backgroundStart: Color(0xFF315A88),
  backgroundEnd: Color(0xFF151725),
);