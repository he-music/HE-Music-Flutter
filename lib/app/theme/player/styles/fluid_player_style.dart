import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_player_style_models.dart';

const AppPlayerStylePackage fluidPlayerStyle = AppPlayerStylePackage(
  metadata: AppPlayerStyleMetadata(
    id: 'fluid',
    labelKey: 'player.style.fluid',
    previewAsset: 'assets/player_styles/fluid/preview.png',
  ),
  stageKind: AppPlayerStageKind.fluid,
  colors: AppPlayerStyleColors(
    backgroundStart: Color(0xFF315A88),
    backgroundEnd: Color(0xFF151725),
    foreground: Color(0xFFF8FAFF),
    secondaryForeground: Color(0xC7DDE8F7),
    accent: Color(0xFFBBD7FF),
    controlSurface: Color(0x29283B52),
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
