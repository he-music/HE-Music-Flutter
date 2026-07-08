enum AppPlayerBackgroundStyle {
  albumCover('albumCover', '专辑封面'),
  fluid('fluid', '流体'),
  artistPhoto('artistPhoto', '歌手写真');

  const AppPlayerBackgroundStyle(this.value, this.label);

  final String value;
  final String label;

  static AppPlayerBackgroundStyle fromValue(String? value) {
    for (final item in values) {
      if (item.value == value) {
        return item;
      }
    }
    return AppPlayerBackgroundStyle.albumCover;
  }
}
