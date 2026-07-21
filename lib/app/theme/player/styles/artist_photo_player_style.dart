import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_player_style_models.dart';

const AppPlayerStylePackage artistPhotoPlayerStyle = AppPlayerStylePackage(
  metadata: AppPlayerStyleMetadata(
    id: 'artist_photo',
    labelKey: 'player.style.artist_photo',
    previewAsset: 'assets/player_styles/artist_photo/preview.png',
  ),
  stageKind: AppPlayerStageKind.artistPhoto,
  colors: AppPlayerStyleColors(
    backgroundStart: Color(0xFF343A3B),
    backgroundEnd: Color(0xFF101313),
    foreground: Color(0xFFFFFFFF),
    secondaryForeground: Color(0xCCFFFFFF),
    accent: Color(0xFFE8D8B5),
    controlSurface: Color(0x2E111515),
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
