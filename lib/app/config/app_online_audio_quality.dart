enum AppOnlineAudioQuality {
  auto('auto'),
  mp3128('128mp3'),
  mp3192('192mp3'),
  mp3320('320mp3'),
  flac('flac'),
  hires('hires'),
  dolby('dolby'),
  galaxy('galaxy'),
  master('master');

  const AppOnlineAudioQuality(this.value);

  final String value;

  bool get isAuto => this == AppOnlineAudioQuality.auto;

  static List<AppOnlineAudioQuality> get concreteValues {
    return AppOnlineAudioQuality.values
        .where((item) => !item.isAuto)
        .toList(growable: false);
  }

  static const List<AppOnlineAudioQuality> autoFallbackOrder =
      <AppOnlineAudioQuality>[
        AppOnlineAudioQuality.mp3320,
        AppOnlineAudioQuality.hires,
        AppOnlineAudioQuality.flac,
        AppOnlineAudioQuality.mp3128,
      ];

  static AppOnlineAudioQuality fromValue(String? value) {
    for (final item in AppOnlineAudioQuality.values) {
      if (item.value == value) {
        return item;
      }
    }
    return AppOnlineAudioQuality.auto;
  }
}
