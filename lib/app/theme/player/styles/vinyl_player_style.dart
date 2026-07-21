import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_player_style_models.dart';

const AppPlayerStylePackage vinylPlayerStyle = AppPlayerStylePackage(
  metadata: AppPlayerStyleMetadata(
    id: 'vinyl',
    labelKey: 'player.style.vinyl',
    previewAsset: 'assets/player_styles/vinyl/preview.png',
  ),
  stageKind: AppPlayerStageKind.vinyl,
  colors: AppPlayerStyleColors(
    backgroundStart: Color(0xFF302629),
    backgroundEnd: Color(0xFF090809),
    foreground: Color(0xFFFFF8EC),
    secondaryForeground: Color(0xBFE8DCCB),
    accent: Color(0xFFE1BC72),
    controlSurface: Color(0x3346363B),
    controlBorder: Color(0x3DE1BC72),
  ),
  geometry: AppPlayerStyleGeometry(stageMaxWidth: 450, controlRadius: 18),
  systemOverlayStyle: SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ),
);
