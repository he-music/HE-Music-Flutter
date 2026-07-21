import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_player_style_models.dart';

const AppPlayerStylePackage classicPlayerStyle = AppPlayerStylePackage(
  metadata: AppPlayerStyleMetadata(
    id: 'classic',
    labelKey: 'player.style.classic',
    previewAsset: 'assets/player_styles/classic/preview.png',
  ),
  stageKind: AppPlayerStageKind.classic,
  colors: AppPlayerStyleColors(
    backgroundStart: Color(0xFF24423A),
    backgroundEnd: Color(0xFF080D0B),
    foreground: Color(0xFFF7FAF8),
    secondaryForeground: Color(0xBFD9E4DE),
    accent: Color(0xFFA7E2C5),
    controlSurface: Color(0x292B4038),
    controlBorder: Color(0x3DFFFFFF),
  ),
  geometry: AppPlayerStyleGeometry(stageMaxWidth: 420, controlRadius: 22),
  systemOverlayStyle: SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ),
);
