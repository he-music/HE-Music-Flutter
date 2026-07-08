enum AppLyricFontPreset {
  small('small', '小'),
  medium('medium', '中'),
  large('large', '大');

  const AppLyricFontPreset(this.value, this.label);

  final String value;
  final String label;

  static AppLyricFontPreset fromValue(String? value) {
    for (final item in values) {
      if (item.value == value) {
        return item;
      }
    }
    return AppLyricFontPreset.medium;
  }
}
