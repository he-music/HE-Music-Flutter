import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_player_style_models.dart';
import 'classic_player_style.dart';

const AppPlayerStylePackage monetLyricsPlayerStyle = AppPlayerStylePackage(
  metadata: AppPlayerStyleMetadata(
    id: 'monet_lyrics',
    labelKey: 'player.style.monet_lyrics',
    previewAsset: 'assets/player_styles/monet_lyrics/preview.png',
  ),
  stageKind: AppPlayerStageKind.classic,
  lyricsKind: AppPlayerLyricsKind.monet,
  colors: AppPlayerStyleColors(
    backgroundStart: classicPlayerBackgroundStart,
    backgroundEnd: classicPlayerBackgroundEnd,
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
