import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/data/datasources/online_lyric_data_source.dart';
import 'package:he_music_flutter/features/online/data/online_api_client.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';

void main() {
  test(
    'typed candidate search uses candidate route, repeated artists and seconds',
    () async {
      final requests = <RequestOptions>[];
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: options.path == '/v1/lyric/search'
                      ? {
                          'list': [
                            {
                              'id': 'id|access-key',
                              'platform': 'kg',
                              'name': 'Song',
                              'artist_names': ['A', 'B'],
                              'duration': 279,
                            },
                          ],
                        }
                      : {
                          'info': {
                            'id': 'id|access-key',
                            'platform': 'kg',
                            'lyric': '[00:00.00]original',
                            'trans': '[00:00.00]translation',
                            'roma': '[00:00.00]roma',
                          },
                        },
                ),
              );
            },
          ),
        );
      final client = OnlineApiClient(dio);
      final results = await client.searchLyricCandidates(
        platform: 'kg',
        name: 'Song',
        artistNames: ['A', 'B'],
        duration: 279,
      );
      expect(requests.single.path, '/v1/lyric/search');
      expect(requests.single.queryParameters['artist_names'], ['A', 'B']);
      expect(requests.single.queryParameters['duration'], 279);
      expect(requests.single.listFormat, ListFormat.multi);
      final bundle = await client.fetchLyricCandidate(results.single);
      expect(requests.last.path, '/v1/lyric');
      expect(requests.last.queryParameters['id'], 'id|access-key');
      expect(bundle.romanization, '[00:00.00]roma');
      await expectLater(
        client.searchLyricCandidates(platform: 'kg', name: '', artistNames: []),
        throwsArgumentError,
      );
      expect(requests, hasLength(2));
    },
  );

  test(
    'default info lyric id may differ from song id and complete bundle is retained',
    () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.resolve(
                Response(
                  requestOptions: options,
                  data: {
                    'info': {
                      'id': 'lyric-id',
                      'platform': 'qq',
                      'lyric': '[00:00.00]original',
                      'trans': 'translation',
                      'roma': 'roma',
                    },
                  },
                ),
              );
            },
          ),
        );
      final bundle = await OnlineLyricDataSource(
        OnlineApiClient(dio),
      ).fetchRawLyric(trackId: 'song-id', platform: 'qq');
      expect(bundle!.translation, 'translation');
      expect(bundle.romanization, 'roma');
    },
  );

  test('candidate capability bit 49 is distinct from song-by-lyric bit 48', () {
    final platform = OnlinePlatform.fromMap({
      'id': 'qq',
      'name': 'QQ',
      'status': 1,
      'feature_support_flag': (BigInt.one << 49).toString(),
    });
    expect(platform.supports(PlatformFeatureSupportFlag.searchLyric), isTrue);
    expect(
      platform.supports(PlatformFeatureSupportFlag.searchLyricSong),
      isFalse,
    );
  });
}
