import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_player_style_models.dart';
import 'classic_player_style.dart';

const AppPlayerStylePackage radialSpectrumPlayerStyle = AppPlayerStylePackage(
  metadata: AppPlayerStyleMetadata(
    id: 'radial_spectrum',
    labelKey: 'player.style.radial_spectrum',
    previewAsset: 'assets/player_styles/radial_spectrum/preview.png',
  ),
  stageKind: AppPlayerStageKind.radialSpectrum,
  colors: AppPlayerStyleColors(
    backgroundStart: classicPlayerBackgroundStart,
    backgroundEnd: classicPlayerBackgroundEnd,
    foreground: Color(0xFFF7FAF9),
    secondaryForeground: Color(0xC7DDE4E2),
    accent: Color(0xFF8FE1D0),
    controlSurface: Color(0x33262B2A),
    controlBorder: Color(0x3DFFFFFF),
  ),
  geometry: AppPlayerStyleGeometry(stageMaxWidth: 440, controlRadius: 22),
  systemOverlayStyle: SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ),
  usesRealtimeSpectrum: true,
);
