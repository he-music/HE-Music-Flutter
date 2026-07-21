import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppPlayerStageKind { classic, vinyl, cassette, artistPhoto }

@immutable
class AppPlayerStyleMetadata {
  const AppPlayerStyleMetadata({
    required this.id,
    required this.labelKey,
    required this.previewAsset,
  });

  final String id;
  final String labelKey;
  final String previewAsset;

  bool get isValid {
    return RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(id) &&
        labelKey.trim().isNotEmpty &&
        previewAsset.startsWith('assets/player_styles/$id/') &&
        previewAsset.endsWith('.png') &&
        !previewAsset.contains('..');
  }
}

@immutable
class AppPlayerStyleColors {
  const AppPlayerStyleColors({
    required this.backgroundStart,
    required this.backgroundEnd,
    required this.foreground,
    required this.secondaryForeground,
    required this.accent,
    required this.controlSurface,
    required this.controlBorder,
  });

  final Color backgroundStart;
  final Color backgroundEnd;
  final Color foreground;
  final Color secondaryForeground;
  final Color accent;
  final Color controlSurface;
  final Color controlBorder;
}

@immutable
class AppPlayerStyleGeometry {
  const AppPlayerStyleGeometry({
    required this.stageMaxWidth,
    required this.controlRadius,
  });

  final double stageMaxWidth;
  final double controlRadius;

  bool get isValid {
    return stageMaxWidth.isFinite &&
        stageMaxWidth > 0 &&
        controlRadius.isFinite &&
        controlRadius >= 0;
  }
}

@immutable
class AppPlayerSheetStyle {
  const AppPlayerSheetStyle({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.secondaryForegroundColor,
    required this.dividerColor,
    required this.handleColor,
    required this.topRadius,
  });

  static const AppPlayerSheetStyle light = AppPlayerSheetStyle(
    backgroundColor: Color(0xFFFAFAFA),
    foregroundColor: Color(0xFF151515),
    secondaryForegroundColor: Color(0xFF666666),
    dividerColor: Color(0x1F000000),
    handleColor: Color(0x42000000),
    topRadius: 24,
  );

  static const AppPlayerSheetStyle dark = AppPlayerSheetStyle(
    backgroundColor: Color(0xFF171717),
    foregroundColor: Color(0xFFF5F5F5),
    secondaryForegroundColor: Color(0xFFADADAD),
    dividerColor: Color(0x24FFFFFF),
    handleColor: Color(0x5CFFFFFF),
    topRadius: 24,
  );

  final Color backgroundColor;
  final Color foregroundColor;
  final Color secondaryForegroundColor;
  final Color dividerColor;
  final Color handleColor;
  final double topRadius;

  static AppPlayerSheetStyle forBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }
}

@immutable
class AppPlayerStylePackage {
  const AppPlayerStylePackage({
    required this.metadata,
    required this.stageKind,
    required this.colors,
    required this.geometry,
    required this.systemOverlayStyle,
  });

  final AppPlayerStyleMetadata metadata;
  final AppPlayerStageKind stageKind;
  final AppPlayerStyleColors colors;
  final AppPlayerStyleGeometry geometry;
  final SystemUiOverlayStyle systemOverlayStyle;

  bool get isValid => metadata.isValid && geometry.isValid;
}
