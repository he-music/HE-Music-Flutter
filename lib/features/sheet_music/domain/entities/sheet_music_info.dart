/// 列表和详情共享的曲谱信息；列表允许省略详情字段。
class SheetMusicInfo {
  const SheetMusicInfo({
    this.id = '',
    this.title = '',
    this.songName = '',
    this.uploader = '',
    this.instruments = const [],
    this.notationTypes = const [],
    this.arrangementType = '',
    this.difficulty = '',
    this.originalKey = '',
    this.bpm = 0,
    this.cover = '',
    this.pageUrls = const [],
    this.pageCount = 0,
    this.platform = '',
  });

  final String id;
  final String title;
  final String songName;
  final String uploader;
  final List<String> instruments;
  final List<String> notationTypes;
  final String arrangementType;
  final String difficulty;
  final String originalKey;
  final int bpm;
  final String cover;
  final List<String> pageUrls;
  final int pageCount;
  final String platform;

  factory SheetMusicInfo.fromMap(Map<String, dynamic> raw) {
    String text(String key) => '${raw[key] ?? ''}'.trim();
    int number(String key) => int.tryParse('${raw[key]}') ?? 0;
    List<String> strings(String key) {
      final value = raw[key];
      if (value is! List) return const [];
      return List.unmodifiable(
        value
            .whereType<String>()
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty),
      );
    }

    return SheetMusicInfo(
      id: text('id'),
      title: text('title'),
      songName: text('song_name'),
      uploader: text('uploader'),
      instruments: strings('instruments'),
      notationTypes: strings('notation_types'),
      arrangementType: text('arrangement_type'),
      difficulty: text('difficulty'),
      originalKey: text('original_key'),
      bpm: number('bpm'),
      cover: text('cover'),
      pageUrls: strings('page_urls'),
      pageCount: number('page_count'),
      platform: text('platform'),
    );
  }
}
