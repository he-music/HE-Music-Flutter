enum AppLyricFontPreset {
  small('small'),
  medium('medium'),
  large('large');

  const AppLyricFontPreset(this.value);

  final String value;

  static AppLyricFontPreset fromValue(String? value) {
    for (final item in values) {
      if (item.value == value) {
        return item;
      }
    }
    return AppLyricFontPreset.medium;
  }
}
