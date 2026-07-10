import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_item.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_type.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test('album favorite subtitle only contains artist names', () {
    final item = MyFavoriteItem.fromAlbumInfo(
      type: MyFavoriteType.albums,
      album: const AlbumInfo(
        name: '测试专辑',
        id: 'album-1',
        cover: '',
        artists: <SongInfoArtistInfo>[
          SongInfoArtistInfo(name: '歌手甲', id: 'artist-1'),
          SongInfoArtistInfo(name: '歌手乙', id: 'artist-2'),
        ],
        songCount: '0',
        publishTime: '',
        songs: <SongInfo>[],
        description: '',
        platform: 'qq',
        language: '',
        genre: '',
        type: 0,
        isFinished: true,
        playCount: '0',
      ),
    );

    expect(item.subtitle, '歌手甲/歌手乙');
  });

  test('artist favorite subtitle only contains alias', () {
    final item = MyFavoriteItem.fromArtistInfo(
      type: MyFavoriteType.artists,
      artist: const ArtistInfo(
        id: 'artist-1',
        name: '测试歌手',
        cover: '',
        platform: 'qq',
        description: '',
        mvCount: '0',
        songCount: '0',
        albumCount: '0',
        alias: '别名',
      ),
    );

    expect(item.subtitle, '别名');
  });
}
