import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

@immutable
class AppCustomSkinConfig {
  AppCustomSkinConfig({
    required this.revision,
    required this.lightAssetPath,
    required this.darkAssetPath,
    required List<int> candidateColors,
    required this.seedColor,
    required this.focalX,
    required this.focalY,
    required this.sourceWidth,
    required this.sourceHeight,
  }) : candidateColors = List<int>.unmodifiable(candidateColors) {
    _validate();
  }

  static const int schemaVersion = 1;
  static const int maxCandidateColors = 6;
  static const int maxSourcePixels = 80000000;

  static const Set<String> _jsonKeys = <String>{
    'schemaVersion',
    'revision',
    'lightAssetPath',
    'darkAssetPath',
    'candidateColors',
    'seedColor',
    'focalX',
    'focalY',
    'sourceWidth',
    'sourceHeight',
  };

  final String revision;
  final String lightAssetPath;
  final String darkAssetPath;
  final List<int> candidateColors;
  final int seedColor;
  final double focalX;
  final double focalY;
  final int sourceWidth;
  final int sourceHeight;

  Alignment get focalAlignment => Alignment(focalX, focalY);

  AppCustomSkinConfig copyWith({
    String? revision,
    String? lightAssetPath,
    String? darkAssetPath,
    List<int>? candidateColors,
    int? seedColor,
    double? focalX,
    double? focalY,
    int? sourceWidth,
    int? sourceHeight,
  }) {
    return AppCustomSkinConfig(
      revision: revision ?? this.revision,
      lightAssetPath: lightAssetPath ?? this.lightAssetPath,
      darkAssetPath: darkAssetPath ?? this.darkAssetPath,
      candidateColors: candidateColors ?? this.candidateColors,
      seedColor: seedColor ?? this.seedColor,
      focalX: focalX ?? this.focalX,
      focalY: focalY ?? this.focalY,
      sourceWidth: sourceWidth ?? this.sourceWidth,
      sourceHeight: sourceHeight ?? this.sourceHeight,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
    'schemaVersion': schemaVersion,
    'revision': revision,
    'lightAssetPath': lightAssetPath,
    'darkAssetPath': darkAssetPath,
    'candidateColors': candidateColors,
    'seedColor': seedColor,
    'focalX': focalX,
    'focalY': focalY,
    'sourceWidth': sourceWidth,
    'sourceHeight': sourceHeight,
  };

  String encode() => jsonEncode(toJson());

  static AppCustomSkinConfig? tryDecode(String? source) {
    if (source == null || source.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(source);
      if (decoded is! Map<String, dynamic> ||
          !setEquals(decoded.keys.toSet(), _jsonKeys) ||
          decoded['schemaVersion'] != schemaVersion) {
        return null;
      }
      final colors = decoded['candidateColors'];
      final focalX = decoded['focalX'];
      final focalY = decoded['focalY'];
      if (decoded['revision'] is! String ||
          decoded['lightAssetPath'] is! String ||
          decoded['darkAssetPath'] is! String ||
          colors is! List<dynamic> ||
          colors.any((value) => value is! int) ||
          decoded['seedColor'] is! int ||
          focalX is! num ||
          focalY is! num ||
          decoded['sourceWidth'] is! int ||
          decoded['sourceHeight'] is! int) {
        return null;
      }
      return AppCustomSkinConfig(
        revision: decoded['revision'] as String,
        lightAssetPath: decoded['lightAssetPath'] as String,
        darkAssetPath: decoded['darkAssetPath'] as String,
        candidateColors: colors.cast<int>(),
        seedColor: decoded['seedColor'] as int,
        focalX: focalX.toDouble(),
        focalY: focalY.toDouble(),
        sourceWidth: decoded['sourceWidth'] as int,
        sourceHeight: decoded['sourceHeight'] as int,
      );
    } catch (_) {
      return null;
    }
  }

  static bool isManagedAssetPath(String value, {String? revision}) {
    if (value.trim() != value ||
        value.startsWith('/') ||
        value.contains('\\') ||
        value.contains('..')) {
      return false;
    }
    final parts = value.split('/');
    if (parts.length != 4 ||
        parts[0] != 'skins' ||
        parts[1] != 'custom_image' ||
        !_isValidRevision(parts[2])) {
      return false;
    }
    if (revision != null && parts[2] != revision) {
      return false;
    }
    return RegExp(r'^wallpaper_(light|dark)\.(jpg|png)$').hasMatch(parts[3]);
  }

  static bool _isValidRevision(String value) {
    return RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]{0,95}$').hasMatch(value);
  }

  void _validate() {
    if (!_isValidRevision(revision)) {
      throw ArgumentError.value(revision, 'revision', '非法资源版本');
    }
    if (!isManagedAssetPath(lightAssetPath, revision: revision) ||
        !isManagedAssetPath(darkAssetPath, revision: revision) ||
        lightAssetPath == darkAssetPath ||
        lightAssetPath.split('.').last != darkAssetPath.split('.').last) {
      throw ArgumentError('自定义皮肤资源路径无效');
    }
    if (candidateColors.isEmpty ||
        candidateColors.length > maxCandidateColors ||
        candidateColors.toSet().length != candidateColors.length ||
        candidateColors.any((value) => value < 0 || value > 0xFFFFFFFF) ||
        !candidateColors.contains(seedColor)) {
      throw ArgumentError('自定义皮肤候选色无效');
    }
    if (!focalX.isFinite ||
        !focalY.isFinite ||
        focalX < -1 ||
        focalX > 1 ||
        focalY < -1 ||
        focalY > 1) {
      throw ArgumentError('自定义皮肤焦点无效');
    }
    if (sourceWidth <= 0 ||
        sourceHeight <= 0 ||
        sourceWidth * sourceHeight > maxSourcePixels) {
      throw ArgumentError('自定义皮肤源图尺寸无效');
    }
  }

  @override
  bool operator ==(Object other) {
    return other is AppCustomSkinConfig &&
        other.revision == revision &&
        other.lightAssetPath == lightAssetPath &&
        other.darkAssetPath == darkAssetPath &&
        listEquals(other.candidateColors, candidateColors) &&
        other.seedColor == seedColor &&
        other.focalX == focalX &&
        other.focalY == focalY &&
        other.sourceWidth == sourceWidth &&
        other.sourceHeight == sourceHeight;
  }

  @override
  int get hashCode => Object.hash(
    revision,
    lightAssetPath,
    darkAssetPath,
    Object.hashAll(candidateColors),
    seedColor,
    focalX,
    focalY,
    sourceWidth,
    sourceHeight,
  );
}
