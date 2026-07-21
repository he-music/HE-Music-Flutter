import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_player_style_models.dart';

const AppPlayerStylePackage cassettePlayerStyle = AppPlayerStylePackage(
  metadata: AppPlayerStyleMetadata(
    id: 'cassette',
    labelKey: 'player.style.cassette',
    previewAsset: 'assets/player_styles/cassette/preview.png',
  ),
  stageKind: AppPlayerStageKind.cassette,
  colors: AppPlayerStyleColors(
    backgroundStart: Color(0xFF253D3B),
    backgroundEnd: Color(0xFF0B1212),
    foreground: Color(0xFFF5F1E8),
    secondaryForeground: Color(0xBFD8D6CC),
    accent: Color(0xFFE9C75C),
    controlSurface: Color(0x33344C49),
    controlBorder: Color(0x3D9ED7CF),
  ),
  geometry: AppPlayerStyleGeometry(stageMaxWidth: 470, controlRadius: 16),
  systemOverlayStyle: SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ),
);
