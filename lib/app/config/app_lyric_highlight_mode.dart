enum AppLyricHighlightMode {
  preset('preset', '预设'),
  auto('auto', '自动'),
  custom('custom', '自定义');

  const AppLyricHighlightMode(this.value, this.label);

  final String value;
  final String label;

  static AppLyricHighlightMode fromValue(String? value) {
    for (final item in values) {
      if (item.value == value) {
        return item;
      }
    }
    return AppLyricHighlightMode.preset;
  }
}
