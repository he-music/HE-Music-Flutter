import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/home/domain/entities/home_page_section.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test('快捷入口类型和目标类型只接受协议已知值', () {
    expect(parseHomeSectionType(6), HomeSectionType.quickEntries);
    expect(parseHomePageEntryTargetType(1), HomePageEntryTargetType.songList);
    expect(parseHomePageEntryTargetType(2), HomePageEntryTargetType.radio);
    expect(parseHomePageEntryTargetType(3), HomePageEntryTargetType.playlist);
    expect(parseHomePageEntryTargetType(0), isNull);
    expect(parseHomePageEntryTargetType(99), isNull);
  });

  test('相邻同资源 FEED 合并并保留旧标题和重复资源', () {
    final duplicate = _song('same');
    final current = <HomePageSection>[
      _feed('旧标题', HomeResourceType.song, songs: <SongInfo>[duplicate]),
    ];
    final incoming = <HomePageSection>[
      _feed('新标题', HomeResourceType.song, songs: <SongInfo>[duplicate]),
      _genericPlaylist('后续区块'),
    ];

    final result = appendRecommendSections(current, incoming);

    expect(result, hasLength(2));
    expect(result.first.title, '旧标题');
    expect(result.first.songs.map((song) => song.id), <String>['same', 'same']);
    expect(result.last.title, '后续区块');
  });

  test('section 类型或资源类型不匹配时保持独立区块', () {
    final current = <HomePageSection>[
      _feed('歌曲', HomeResourceType.song, songs: <SongInfo>[_song('1')]),
    ];
    final resourceMismatch = <HomePageSection>[
      _feed(
        '歌单',
        HomeResourceType.playlist,
        playlists: <PlaylistInfo>[_playlist('2')],
      ),
    ];
    final sectionMismatch = <HomePageSection>[_genericPlaylist('通用')];

    expect(appendRecommendSections(current, resourceMismatch), hasLength(2));
    expect(appendRecommendSections(current, sectionMismatch), hasLength(2));
  });

  test('任一页为空时返回另一页的不可变副本', () {
    final section = _genericPlaylist('歌单');
    final fromIncoming = appendRecommendSections(
      const <HomePageSection>[],
      <HomePageSection>[section],
    );
    final fromCurrent = appendRecommendSections(<HomePageSection>[
      section,
    ], const <HomePageSection>[]);

    expect(fromIncoming.single, same(section));
    expect(fromCurrent.single, same(section));
    expect(() => fromIncoming.add(section), throwsUnsupportedError);
  });
}

HomePageSection _feed(
  String title,
  HomeResourceType resourceType, {
  List<SongInfo> songs = const <SongInfo>[],
  List<PlaylistInfo> playlists = const <PlaylistInfo>[],
}) {
  return HomePageSection(
    sectionTypeCode: 5,
    sectionType: HomeSectionType.feed,
    resourceType: resourceType,
    title: title,
    songs: songs,
    playlists: playlists,
  );
}

HomePageSection _genericPlaylist(String title) {
  return HomePageSection(
    sectionTypeCode: 1,
    sectionType: HomeSectionType.generic,
    resourceType: HomeResourceType.playlist,
    title: title,
    playlists: <PlaylistInfo>[_playlist(title)],
  );
}

SongInfo _song(String id) {
  return SongInfo(
    name: id,
    subtitle: '',
    id: id,
    duration: 0,
    mvId: '',
    album: null,
    artists: const <SongInfoArtistInfo>[],
    links: const <LinkInfo>[],
    platform: 'qq',
    cover: '',
  );
}

PlaylistInfo _playlist(String id) {
  return PlaylistInfo(
    name: id,
    id: id,
    cover: '',
    creator: '',
    songCount: '',
    playCount: '',
    songs: const <SongInfo>[],
    platform: 'qq',
    description: '',
  );
}
