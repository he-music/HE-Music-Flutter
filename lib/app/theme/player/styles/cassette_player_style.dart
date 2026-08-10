import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_player_style_models.dart';
import 'classic_player_style.dart';

const AppPlayerStylePackage cassettePlayerStyle = AppPlayerStylePackage(
  metadata: AppPlayerStyleMetadata(
    id: 'cassette',
    labelKey: 'player.style.cassette',
    previewAsset: 'assets/player_styles/cassette/preview.png',
  ),
  stageKind: AppPlayerStageKind.cassette,
  colors: AppPlayerStyleColors(
    backgroundStart: classicPlayerBackgroundStart,
    backgroundEnd: classicPlayerBackgroundEnd,
    foreground: Color(0xFFF4F0E7),
    secondaryForeground: Color(0xBFD6E1DE),
    accent: Color(0xFF70E1D1),
    controlSurface: Color(0x40151F21),
    controlBorder: Color(0x6670E1D1),
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
