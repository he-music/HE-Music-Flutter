import 'package:flutter/material.dart';

/// 全屏播放器当前场景的有效视觉色。
///
/// 样式包提供静态兜底，使用封面色的样式可在播放器页面内覆盖这些语义色。
@immutable
class PlayerScenePalette extends ThemeExtension<PlayerScenePalette> {
  const PlayerScenePalette({
    required this.surface,
    required this.surfaceDeep,
    required this.surfaceRaised,
    required this.edge,
    required this.accent,
    required this.foreground,
    required this.secondaryForeground,
    required this.onAccent,
  });

  final Color surface;
  final Color surfaceDeep;
  final Color surfaceRaised;
  final Color edge;
  final Color accent;
  final Color foreground;
  final Color secondaryForeground;
  final Color onAccent;

  static PlayerScenePalette? maybeOf(BuildContext context) {
    return Theme.of(context).extension<PlayerScenePalette>();
  }

  @override
  PlayerScenePalette copyWith({
    Color? surface,
    Color? surfaceDeep,
    Color? surfaceRaised,
    Color? edge,
    Color? accent,
    Color? foreground,
    Color? secondaryForeground,
    Color? onAccent,
  }) {
    return PlayerScenePalette(
      surface: surface ?? this.surface,
      surfaceDeep: surfaceDeep ?? this.surfaceDeep,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      edge: edge ?? this.edge,
      accent: accent ?? this.accent,
      foreground: foreground ?? this.foreground,
      secondaryForeground: secondaryForeground ?? this.secondaryForeground,
      onAccent: onAccent ?? this.onAccent,
    );
  }

  @override
  PlayerScenePalette lerp(covariant PlayerScenePalette? other, double t) {
    if (other == null) return this;
    return PlayerScenePalette(
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceDeep: Color.lerp(surfaceDeep, other.surfaceDeep, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      edge: Color.lerp(edge, other.edge, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      secondaryForeground: Color.lerp(
        secondaryForeground,
        other.secondaryForeground,
        t,
      )!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlayerScenePalette &&
            surface == other.surface &&
            surfaceDeep == other.surfaceDeep &&
            surfaceRaised == other.surfaceRaised &&
            edge == other.edge &&
            accent == other.accent &&
            foreground == other.foreground &&
            secondaryForeground == other.secondaryForeground &&
            onAccent == other.onAccent;
  }

  @override
  int get hashCode => Object.hash(
    surface,
    surfaceDeep,
    surfaceRaised,
    edge,
    accent,
    foreground,
    secondaryForeground,
    onAccent,
  );
}
