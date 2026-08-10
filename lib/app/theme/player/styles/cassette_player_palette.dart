import 'package:flutter/material.dart';

@immutable
class CassettePlayerPalette extends ThemeExtension<CassettePlayerPalette> {
  const CassettePlayerPalette({
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

  static const CassettePlayerPalette fallback = CassettePlayerPalette(
    surface: Color(0xFF263234),
    surfaceDeep: Color(0xFF0B1112),
    surfaceRaised: Color(0xFF344042),
    edge: Color(0xFF70E1D1),
    accent: Color(0xFFFF7368),
    foreground: Color(0xFFF4F0E7),
    secondaryForeground: Color(0xBFD6E1DE),
    onAccent: Color(0xFF111718),
  );

  factory CassettePlayerPalette.fromBackdrop(List<Color> colors) {
    if (colors.isEmpty) return fallback;

    final dominant = colors.first;
    final highlight = colors.length > 1 ? colors[1] : dominant;
    final anchor = colors.length > 3 ? colors[3] : dominant;
    final edge = _signalColor(dominant, lightness: 0.66);
    final accent = _signalColor(highlight, lightness: 0.64);
    final surface = Color.lerp(const Color(0xFF202729), dominant, 0.28)!;
    final surfaceDeep = Color.lerp(const Color(0xFF080C0D), anchor, 0.18)!;
    final surfaceRaised = Color.lerp(const Color(0xFF30383A), highlight, 0.20)!;
    final foreground = Color.lerp(const Color(0xFFF4F0E7), edge, 0.06)!;
    final secondaryForeground = Color.lerp(
      const Color(0xFFD6E1DE),
      edge,
      0.16,
    )!.withValues(alpha: 0.78);

    return CassettePlayerPalette(
      surface: surface,
      surfaceDeep: surfaceDeep,
      surfaceRaised: surfaceRaised,
      edge: edge,
      accent: accent,
      foreground: foreground,
      secondaryForeground: secondaryForeground,
      onAccent: accent.computeLuminance() > 0.42 ? surfaceDeep : foreground,
    );
  }

  static CassettePlayerPalette? maybeOf(BuildContext context) {
    return Theme.of(context).extension<CassettePlayerPalette>();
  }

  static CassettePlayerPalette of(BuildContext context) {
    return maybeOf(context) ?? fallback;
  }

  @override
  CassettePlayerPalette copyWith({
    Color? surface,
    Color? surfaceDeep,
    Color? surfaceRaised,
    Color? edge,
    Color? accent,
    Color? foreground,
    Color? secondaryForeground,
    Color? onAccent,
  }) {
    return CassettePlayerPalette(
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
  CassettePlayerPalette lerp(covariant CassettePlayerPalette? other, double t) {
    if (other == null) return this;
    return CassettePlayerPalette(
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
        other is CassettePlayerPalette &&
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

Color _signalColor(Color source, {required double lightness}) {
  final hsl = HSLColor.fromColor(source);
  return hsl
      .withSaturation(hsl.saturation.clamp(0.52, 0.82))
      .withLightness(lightness)
      .toColor();
}
