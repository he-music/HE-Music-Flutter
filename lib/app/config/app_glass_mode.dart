/// Rendering preference for the app's glass controls and sheets.
enum AppGlassMode {
  automatic,
  high,
  standard,
  low,
  powerSaving,
  off;

  bool get usesGlass => this != powerSaving && this != off;

  static AppGlassMode parse(String? value) =>
      values.where((mode) => mode.name == value).firstOrNull ?? automatic;
}
