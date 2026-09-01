import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_player_style_models.dart';
import 'classic_player_style.dart';

const AppPlayerStylePackage partitaLyricsPlayerStyle = AppPlayerStylePackage(
  metadata: AppPlayerStyleMetadata(
    id: 'partita_lyrics',
    labelKey: 'player.style.partita_lyrics',
    previewAsset: 'assets/player_styles/partita_lyrics/preview.png',
  ),
  stageKind: AppPlayerStageKind.classic,
  lyricsKind: AppPlayerLyricsKind.partita,
  colors: AppPlayerStyleColors(
    backgroundStart: classicPlayerBackgroundStart,
    backgroundEnd: classicPlayerBackgroundEnd,
    foreground: Color(0xFFF8FAF7),
    secondaryForeground: Color(0xBFD2DDD6),
    accent: Color(0xFFF0C86E),
    controlSurface: Color(0x2935413A),
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
