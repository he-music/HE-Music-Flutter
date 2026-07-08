import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/data/datasources/online_lyric_data_source.dart';
import 'package:he_music_flutter/features/online/data/online_api_client.dart';

void main() {
  test('歌词返回的 id 或 platform 不匹配时应忽略结果', () async {
    final dataSource = OnlineLyricDataSource(
      _FakeOnlineApiClient(
        payload: <String, dynamic>{
          'id': 'song-2',
          'platform': 'kg',
          'lyric': '[00:00.00]错误歌词',
        },
      ),
    );

    final result = await dataSource.fetchRawLyric(
      trackId: 'song-1',
      platform: 'qq',
    );

    expect(result, isNull);
  });
}

class _FakeOnlineApiClient extends OnlineApiClient {
  _FakeOnlineApiClient({required this.payload}) : super(Dio());

  final Map<String, dynamic> payload;

  @override
  Future<Map<String, dynamic>> fetchSongLyric({
    required String songId,
    required String platform,
  }) async {
    return payload;
  }
}
