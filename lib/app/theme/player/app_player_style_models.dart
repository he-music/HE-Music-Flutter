import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 封面（stage）轴：真实前景舞台。
enum AppPlayerStageKind {
  classic,
  vinyl,
  cassette,
  radialSpectrum,
}

/// 背景（backdrop）轴。
enum AppPlayerBackdropKind {
  /// 封面色渐变（共享 _ClassicGradientBackdrop）。
  coverGradient,

  /// 流体网状渐变。
  fluid,

  /// 歌手写真满屏（选中时隐藏前景封面舞台）。
  artistPhoto,
}

/// 歌词（lyric）轴。
enum AppPlayerLyricsKind { legacy, monet, partita, cadenza, tilt }

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

/// 封面轴选项。
@immutable
class AppPlayerStageOption {
  const AppPlayerStageOption({
    required this.metadata,
    required this.stageKind,
    required this.stageMaxWidth,
    this.usesRealtimeSpectrum = false,
  });

  final AppPlayerStyleMetadata metadata;
  final AppPlayerStageKind stageKind;
  final double stageMaxWidth;
  final bool usesRealtimeSpectrum;

  bool get isValid =>
      metadata.isValid && stageMaxWidth.isFinite && stageMaxWidth > 0;
}

/// 背景轴选项。
@immutable
class AppPlayerBackdropOption {
  const AppPlayerBackdropOption({
    required this.metadata,
    required this.backdropKind,
    required this.backgroundStart,
    required this.backgroundEnd,
  });

  final AppPlayerStyleMetadata metadata;
  final AppPlayerBackdropKind backdropKind;

  /// 背景示例色，用于选择预览与加载/丢图回退。
  final Color backgroundStart;
  final Color backgroundEnd;

  bool get isValid => metadata.isValid;
}

/// 歌词轴选项。
@immutable
class AppPlayerLyricsOption {
  const AppPlayerLyricsOption({
    required this.metadata,
    required this.lyricsKind,
  });

  final AppPlayerStyleMetadata metadata;
  final AppPlayerLyricsKind lyricsKind;

  bool get isValid => metadata.isValid;
}

/// 固定的播放器前景/强调/控件主题色。
///
/// 三轴只决定 stage / 背景 / 歌词，前景氛围统一为这一套固定值。
/// 后续如需恢复各封面造型的专属强调色，可改为跟随封面轴做差异微调。
@immutable
class AppPlayerStyleForegroundColors {
  const AppPlayerStyleForegroundColors({
    required this.foreground,
    required this.secondaryForeground,
    required this.accent,
    required this.controlSurface,
    required this.controlBorder,
  });

  final Color foreground;
  final Color secondaryForeground;
  final Color accent;
  final Color controlSurface;
  final Color controlBorder;
}

/// 固定的播放器前景/强调/控件主题色实例。
const AppPlayerStyleForegroundColors appPlayerForegroundColors =
    AppPlayerStyleForegroundColors(
      foreground: Color(0xFFF7FAF8),
      secondaryForeground: Color(0xBFD9E4DE),
      accent: Color(0xFFA7E2C5),
      controlSurface: Color(0x292B4038),
      controlBorder: Color(0x3DFFFFFF),
    );

/// 全局固定的播放器状态栏/导航栏样式（各轴一致）。
const SystemUiOverlayStyle appPlayerSystemOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
);

/// 固定的播放器深色底色（背景/加载/丢图时的最暗 surface）。
const Color appPlayerSurfaceColor = Color(0xFF080D0B);

/// 播放器自有底部弹层的亮/暗共享色板。
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
