enum AppOnlineAudioQuality {
  auto('auto', '自动', '自动选择可用音质'),
  mp3128('128mp3', '128mp3', '标准音质 128kbps'),
  mp3192('192mp3', '192mp3', '较高音质 192kbps'),
  mp3320('320mp3', '320mp3', '超高音质 320kbps'),
  flac('flac', 'flac', '高保真无损音质，最高 48kHz/16bit'),
  hires('hires', 'hires', '更饱满清晰的高解析度音质，最高192kHz/24bit'),
  dolby('dolby', 'dolby', '杜比全景声音乐，沉浸式聆听体验'),
  galaxy('galaxy', 'galaxy', '臻品全景声'),
  master('master', 'master', '还原音频细节，192kHz/24bit');

  const AppOnlineAudioQuality(this.value, this.label, this.tip);

  final String value;
  final String label;
  final String tip;

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

  static String autoDescription({String? lastSelectedQualityName}) {
    final lastSelected = lastSelectedQualityName?.trim() ?? '';
    final fallbackText = autoFallbackOrder
        .map((item) => item.value)
        .join(' > ');
    if (lastSelected.isEmpty) {
      return '自动按优先级选择：$fallbackText';
    }
    return '优先使用上次手动选择的 $lastSelected，否则按 $fallbackText';
  }

  static AppOnlineAudioQuality fromValue(String? value) {
    for (final item in AppOnlineAudioQuality.values) {
      if (item.value == value) {
        return item;
      }
    }
    return AppOnlineAudioQuality.auto;
  }
}
