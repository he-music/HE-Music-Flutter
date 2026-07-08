import '../../domain/entities/raw_lyric_bundle.dart';
import '../../../online/data/online_api_client.dart';

class OnlineLyricDataSource {
  const OnlineLyricDataSource(this._apiClient);

  final OnlineApiClient _apiClient;

  Future<RawLyricBundle?> fetchRawLyric({
    required String trackId,
    required String platform,
  }) async {
    final payload = await _apiClient.fetchSongLyric(
      songId: trackId,
      platform: platform,
    );
    final data = _asMap(payload['data']);
    final lrc = _asMap(payload['lrc']);
    if (!_matchesRequest(
      payload: payload,
      data: data,
      trackId: trackId,
      platform: platform,
    )) {
      return null;
    }
    final lyric =
        _readText(payload['lyric']) ??
        _readText(data['lyric']) ??
        _readText(data['lrc']) ??
        _readText(lrc['lyric']);
    if (lyric == null) {
      return null;
    }
    return RawLyricBundle(
      lyric: lyric,
      translation:
          _readText(payload['trans']) ??
          _readText(data['trans']) ??
          _readText(lrc['trans']) ??
          '',
      romanization:
          _readText(payload['roma']) ??
          _readText(data['roma']) ??
          _readText(lrc['roma']) ??
          '',
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return const <String, dynamic>{};
  }

  String? _readText(dynamic value) {
    if (value == null) {
      return null;
    }
    final text = '$value'.trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  bool _matchesRequest({
    required Map<String, dynamic> payload,
    required Map<String, dynamic> data,
    required String trackId,
    required String platform,
  }) {
    final responseTrackId =
        _readText(payload['id']) ??
        _readText(payload['songId']) ??
        _readText(data['id']) ??
        _readText(data['songId']) ??
        '';
    final responsePlatform =
        _readText(payload['platform']) ?? _readText(data['platform']) ?? '';
    if (responseTrackId.isNotEmpty && responseTrackId != trackId) {
      return false;
    }
    if (responsePlatform.isNotEmpty && responsePlatform != platform) {
      return false;
    }
    return true;
  }
}
