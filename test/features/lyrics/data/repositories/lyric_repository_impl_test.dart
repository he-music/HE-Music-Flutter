import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:he_music_flutter/core/audio/local_audio_metadata_reader.dart';
import 'package:he_music_flutter/features/lyrics/data/datasources/demo_lyric_data_source.dart';
import 'package:he_music_flutter/features/lyrics/data/datasources/online_lyric_data_source.dart';
import 'package:he_music_flutter/features/lyrics/data/repositories/lyric_repository_impl.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/raw_lyric_bundle.dart';
import 'package:he_music_flutter/features/online/data/online_api_client.dart';

void main() {
  test('在线歌词失败时不应降级到 demo 歌词', () async {
    final repository = LyricRepositoryImpl(
      _ThrowingOnlineLyricDataSource(),
      _FakeDemoLyricDataSource(),
      const LocalAudioMetadataReader(),
    );

    final document = await repository.fetchLyrics(
      trackId: 'song-1',
      platform: 'qq',
    );

    expect(document.isEmpty, isTrue);
  });
}

class _ThrowingOnlineLyricDataSource extends OnlineLyricDataSource {
  _ThrowingOnlineLyricDataSource() : super(_FakeOnlineApiClient());

  @override
  Future<RawLyricBundle?> fetchRawLyric({
    required String trackId,
    required String platform,
  }) async {
    throw Exception('network error');
  }
}

class _FakeDemoLyricDataSource extends DemoLyricDataSource {
  @override
  Future<String?> fetchRawLyric(String trackId) async {
    return '[00:00.00]demo lyric';
  }
}

class _FakeOnlineApiClient extends OnlineApiClient {
  _FakeOnlineApiClient() : super(Dio());
}
