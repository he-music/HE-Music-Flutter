/// Widget design language, independent of skin, brightness and device platform.
enum AppUiStyle {
  material,
  cupertino;

  static AppUiStyle parse(String? value) =>
      values.where((style) => style.name == value).firstOrNull ?? material;
}
