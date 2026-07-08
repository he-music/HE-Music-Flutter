import 'package:dio/dio.dart';

import '../../../shared/models/he_music_models.dart';
import '../presentation/pages/online_search_models.dart';

class SearchDefaultEntry {
  const SearchDefaultEntry({required this.key, required this.description});

  final String key;
  final String description;

  String get displayText =>
      description.trim().isEmpty ? key : '$key ${description.trim()}';
}

class AuthCodeUrlResult {
  const AuthCodeUrlResult({
    required this.url,
    required this.state,
    required this.checkInterval,
    required this.expiresAt,
  });

  final String url;
  final String state;
  final int checkInterval;
  final int expiresAt;
}

class AuthStatusResult {
  const AuthStatusResult({
    required this.status,
    required this.error,
    required this.checkInterval,
    required this.expiresAt,
  });

  final String status;
  final String error;
  final int checkInterval;
  final int expiresAt;
}

class QrLoginSessionResult {
  const QrLoginSessionResult({
    required this.sessionId,
    required this.qrContent,
    required this.resultToken,
    required this.status,
    required this.checkInterval,
    required this.expiresAt,
  });

  final String sessionId;
  final String qrContent;
  final String resultToken;
  final String status;
  final int checkInterval;
  final int expiresAt;
}

class QrLoginSessionStatusResult {
  const QrLoginSessionStatusResult({
    required this.sessionId,
    required this.status,
    required this.checkInterval,
    required this.expiresAt,
    required this.clientName,
    required this.userHint,
  });

  final String sessionId;
  final String status;
  final int checkInterval;
  final int expiresAt;
  final String clientName;
  final String userHint;
}

class QrLoginScanResult {
  const QrLoginScanResult({
    required this.sessionId,
    required this.status,
    required this.clientName,
    required this.scene,
    required this.expiresAt,
  });

  final String sessionId;
  final String status;
  final String clientName;
  final String scene;
  final int expiresAt;
}

class QrLoginConfirmResult {
  const QrLoginConfirmResult({
    required this.sessionId,
    required this.status,
    required this.expiresAt,
  });

  final String sessionId;
  final String status;
  final int expiresAt;
}

class QrLoginCancelResult {
  const QrLoginCancelResult({required this.sessionId, required this.status});

  final String sessionId;
  final String status;
}

class QrLoginExchangeResult {
  const QrLoginExchangeResult({
    required this.sessionId,
    required this.status,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String sessionId;
  final String status;
  final String accessToken;
  final String refreshToken;
  final int expiresAt;
}

/// OAuth/QR 登录兑换返回的 Token 三元组
class AuthTokenResult {
  const AuthTokenResult({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresAt;
}

class OnlineCommentPageResult {
  const OnlineCommentPageResult({
    required this.list,
    required this.hasMore,
    required this.lastId,
    required this.totalCount,
  });

  final List<Map<String, dynamic>> list;
  final bool hasMore;
  final String lastId;
  final int totalCount;
}

class SourceUrlParseResult {
  const SourceUrlParseResult({
    required this.platform,
    required this.id,
    required this.type,
  });

  final String platform;
  final String id;
  final String type;

  factory SourceUrlParseResult.fromMap(Map<String, dynamic> raw) {
    return SourceUrlParseResult(
      platform: '${raw['platform'] ?? ''}'.trim(),
      id: '${raw['id'] ?? ''}'.trim(),
      type: '${raw['type'] ?? ''}'.trim(),
    );
  }
}

class OnlineApiClient {
  OnlineApiClient(this._dio);

  final Dio _dio;

  Future<SourceUrlParseResult> parseSourceUrl(String text) async {
    final response = await _dio.post(
      '/v1/source/url/parse',
      data: <String, dynamic>{'url': text},
    );
    final raw = _asMap(response.data);
    return SourceUrlParseResult.fromMap(raw);
  }

  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
    Map<String, dynamic>? deviceInfo,
  }) async {
    final response = await _dio.post(
      '/v1/user/login',
      data: <String, dynamic>{
        'username': username,
        'password': password,
        'device_info': ?deviceInfo,
      },
    );
    return _asMap(response.data);
  }

  Future<List<String>> listAuthProviders() async {
    final response = await _dio.get('/v1/auth/providers');
    final data = _asMap(response.data);
    return _extractStringList(data, <String>['list']);
  }

  Future<AuthCodeUrlResult> getAuthCodeUrl({
    required String provider,
    String? redirectUri,
    Map<String, dynamic>? deviceInfo,
  }) async {
    final response = await _dio.post(
      '/v1/auth/session',
      data: <String, dynamic>{
        'provider': provider,
        if (redirectUri != null && redirectUri.trim().isNotEmpty)
          'redirect_uri': redirectUri.trim(),
        'device_info': ?deviceInfo,
      },
    );
    final data = _asMap(response.data);
    return AuthCodeUrlResult(
      url: '${data['url'] ?? ''}'.trim(),
      state: '${data['state'] ?? ''}'.trim(),
      checkInterval: _asInt(data['check_interval']),
      expiresAt: _asInt(data['expires_at']),
    );
  }

  Future<AuthStatusResult> getAuthStatus({required String state}) async {
    final response = await _dio.get(
      '/v1/auth/status',
      queryParameters: <String, dynamic>{'state': state},
    );
    final data = _asMap(response.data);
    return AuthStatusResult(
      status: '${data['status'] ?? ''}'.trim(),
      error: '${data['error'] ?? ''}'.trim(),
      checkInterval: _asInt(data['check_interval']),
      expiresAt: _asInt(data['expires_at']),
    );
  }

  Future<AuthTokenResult> exchangeAuthResult({required String state}) async {
    final response = await _dio.get(
      '/v1/auth/result',
      queryParameters: <String, dynamic>{'state': state},
    );
    final data = _asMap(response.data);
    return AuthTokenResult(
      accessToken: '${data['access_token'] ?? ''}'.trim(),
      refreshToken: '${data['refresh_token'] ?? ''}'.trim(),
      expiresAt: _asInt(data['expires_at']),
    );
  }

  /// 登出当前设备，后端会清除对应的 refresh_token。
  Future<void> logout() async {
    await _dio.post('/v1/auth/logout');
  }

  Future<QrLoginSessionResult> createQrLoginSession({
    required String clientType,
    required String clientName,
    required String scene,
    Map<String, dynamic>? deviceInfo,
  }) async {
    final response = await _dio.post(
      '/v1/auth/qr/session',
      data: <String, dynamic>{
        'client_type': clientType,
        'client_name': clientName,
        'scene': scene,
        'device_info': ?deviceInfo,
      },
    );
    final data = _asMap(response.data);
    return QrLoginSessionResult(
      sessionId: '${data['session_id'] ?? ''}'.trim(),
      qrContent: '${data['qr_content'] ?? ''}'.trim(),
      resultToken: '${data['result_token'] ?? ''}'.trim(),
      status: '${data['status'] ?? ''}'.trim(),
      checkInterval: _asInt(data['check_interval']),
      expiresAt: _asInt(data['expires_at']),
    );
  }

  Future<QrLoginSessionStatusResult> getQrLoginSessionStatus({
    required String sessionId,
  }) async {
    final response = await _dio.get(
      '/v1/auth/qr/status',
      queryParameters: <String, dynamic>{'session_id': sessionId},
    );
    final data = _asMap(response.data);
    return QrLoginSessionStatusResult(
      sessionId: '${data['session_id'] ?? ''}'.trim(),
      status: '${data['status'] ?? ''}'.trim(),
      checkInterval: _asInt(data['check_interval']),
      expiresAt: _asInt(data['expires_at']),
      clientName: '${data['client_name'] ?? ''}'.trim(),
      userHint: '${data['user_hint'] ?? ''}'.trim(),
    );
  }

  Future<QrLoginScanResult> scanQrLoginSession({
    required String sessionId,
    required String challenge,
  }) async {
    final response = await _dio.post(
      '/v1/auth/qr/scan',
      data: <String, dynamic>{'session_id': sessionId, 'challenge': challenge},
    );
    final data = _asMap(response.data);
    return QrLoginScanResult(
      sessionId: '${data['session_id'] ?? ''}'.trim(),
      status: '${data['status'] ?? ''}'.trim(),
      clientName: '${data['client_name'] ?? ''}'.trim(),
      scene: '${data['scene'] ?? ''}'.trim(),
      expiresAt: _asInt(data['expires_at']),
    );
  }

  Future<QrLoginConfirmResult> confirmQrLoginSession({
    required String sessionId,
    required String challenge,
  }) async {
    final response = await _dio.post(
      '/v1/auth/qr/confirm',
      data: <String, dynamic>{'session_id': sessionId, 'challenge': challenge},
    );
    final data = _asMap(response.data);
    return QrLoginConfirmResult(
      sessionId: '${data['session_id'] ?? ''}'.trim(),
      status: '${data['status'] ?? ''}'.trim(),
      expiresAt: _asInt(data['expires_at']),
    );
  }

  Future<QrLoginCancelResult> cancelQrLoginSession({
    required String sessionId,
    required String challenge,
  }) async {
    final response = await _dio.post(
      '/v1/auth/qr/cancel',
      data: <String, dynamic>{'session_id': sessionId, 'challenge': challenge},
    );
    final data = _asMap(response.data);
    return QrLoginCancelResult(
      sessionId: '${data['session_id'] ?? ''}'.trim(),
      status: '${data['status'] ?? ''}'.trim(),
    );
  }

  Future<QrLoginExchangeResult> exchangeQrLoginResult({
    required String sessionId,
    required String resultToken,
  }) async {
    final response = await _dio.post(
      '/v1/auth/qr/result',
      data: <String, dynamic>{
        'session_id': sessionId,
        'result_token': resultToken,
      },
    );
    final data = _asMap(response.data);
    return QrLoginExchangeResult(
      sessionId: '${data['session_id'] ?? ''}'.trim(),
      status: '${data['status'] ?? ''}'.trim(),
      accessToken: '${data['access_token'] ?? ''}'.trim(),
      refreshToken: '${data['refresh_token'] ?? ''}'.trim(),
      expiresAt: _asInt(data['expires_at']),
    );
  }

  Future<Map<String, dynamic>> fetchProfile() async {
    final response = await _dio.get('/v1/user/info');
    return _asMap(response.data);
  }

  Future<List<Map<String, dynamic>>> fetchPlatforms({
    bool silentErrorMessage = false,
  }) async {
    final response = await _dio.get(
      '/v1/platforms',
      options: Options(
        extra: <String, dynamic>{
          if (silentErrorMessage) 'silentErrorMessage': true,
        },
      ),
    );
    final data = _asMap(response.data);
    return _extractList(data, <String>['list']);
  }

  Future<List<String>> fetchHotKeywords({String? platform}) async {
    final response = await _dio.get(
      '/v1/search/hotkey',
      queryParameters: <String, dynamic>{
        if (platform != null && platform.isNotEmpty) 'platform': platform,
      },
    );
    final data = _asMap(response.data);
    final list = _extractStringList(data, <String>['keys']);
    if (list.isNotEmpty) {
      return list;
    }
    return const <String>[
      '周杰伦',
      '林俊杰',
      '邓紫棋',
      '毛不易',
      '陈奕迅',
      '张杰',
      '薛之谦',
      'Taylor Swift',
      'Adele',
      'Billie Eilish',
    ];
  }

  Future<List<String>> fetchSearchSuggestions({
    required String keyword,
    String? platform,
  }) async {
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }
    final response = await _dio.get(
      '/v1/search/suggest',
      queryParameters: <String, dynamic>{
        'key': normalized,
        if (platform != null && platform.isNotEmpty) 'platform': platform,
      },
    );
    final data = _asMap(response.data);
    final list = _extractStringList(data, <String>['keys']);
    if (list.isNotEmpty) {
      return list;
    }
    return const <String>[];
  }

  Future<List<SearchDefaultEntry>> fetchDefaultKeywords({
    String? platform,
  }) async {
    final response = await _dio.get(
      '/v1/search/default',
      queryParameters: <String, dynamic>{
        if (platform != null && platform.isNotEmpty) 'platform': platform,
      },
    );
    final data = _asMap(response.data);
    final list = _extractList(data, <String>['list']);
    if (list.isEmpty) {
      return const <SearchDefaultEntry>[];
    }
    return list
        .map((item) => _asMap(item))
        .map((item) {
          final key = '${item['key'] ?? ''}'.trim();
          final description = '${item['description'] ?? ''}'.trim();
          if (key.isEmpty || key == 'null') {
            return null;
          }
          return SearchDefaultEntry(key: key, description: description);
        })
        .whereType<SearchDefaultEntry>()
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> searchMusic({
    required String keyword,
    required String platform,
    String type = 'song',
    int pageIndex = 1,
    int pageSize = 30,
  }) async {
    final response = await _dio.get(
      '/v1/$type/search',
      queryParameters: <String, dynamic>{
        'key': keyword,
        'platform': platform,
        'page_index': pageIndex,
        'page_size': pageSize,
      },
    );
    final data = _asMap(response.data);
    return _extractList(data, <String>['list']);
  }

  Future<OnlineComprehensiveSearchResult> comprehensiveSearch({
    required String keyword,
    required String platform,
  }) async {
    final response = await _dio.get(
      '/v1/search',
      queryParameters: <String, dynamic>{'key': keyword, 'platform': platform},
    );
    final data = _asMap(response.data);
    return OnlineComprehensiveSearchResult(
      keyword: '${data['key'] ?? keyword}'.trim(),
      bestMatch: _readBestMatch(data['bestMatch'] ?? data['best_match']),
      song: _readComprehensiveSection(data['song']),
      playlist: _readComprehensiveSection(data['playlist']),
      album: _readComprehensiveSection(data['album']),
      video: _readComprehensiveSection(data['mv']),
      artist: _readComprehensiveSection(data['artist']),
    );
  }

  Future<Map<String, dynamic>> fetchSongUrl({
    required String songId,
    required String platform,
    int? quality,
    String? format,
  }) async {
    final response = await _dio.get(
      '/v1/song/url',
      queryParameters: <String, dynamic>{
        'id': songId,
        'platform': platform,
        'quality': quality ?? 320,
        'format': (format == null || format.trim().isEmpty) ? 'mp3' : format,
      },
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> fetchSongLyric({
    required String songId,
    required String platform,
  }) async {
    final response = await _dio.get(
      '/v1/song/lyric',
      queryParameters: <String, dynamic>{'id': songId, 'platform': platform},
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> createPlaylist(String name) async {
    final response = await _dio.post(
      '/v1/user/playlist',
      data: <String, dynamic>{'name': name},
    );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> togglePlaylistFavorite({
    required String playlistId,
    required String platform,
    required bool like,
    String? name,
    String? cover,
    String? creator,
  }) async {
    final response = like
        ? await _dio.post(
            '/v1/user/favourite/playlist',
            data: <String, dynamic>{
              'id': playlistId,
              'platform': platform,
              'name': name ?? '',
              'cover': cover ?? '',
              'creator': creator ?? '',
            },
          )
        : await _dio.delete(
            '/v1/user/favourite/playlist',
            data: <String, dynamic>{'id': playlistId, 'platform': platform},
          );
    return _asMap(response.data);
  }

  Future<List<IdPlatformInfo>> fetchFavoriteSongs({
    int pageIndex = 1,
    int pageSize = 1000,
  }) async {
    final response = await _dio.get(
      '/v1/user/favourite/songs',
      queryParameters: <String, dynamic>{
        'page_index': pageIndex,
        'page_size': pageSize,
      },
    );
    final data = _asMap(response.data);
    final list = _extractList(data, <String>['list']);
    return list.map(IdPlatformInfo.fromMap).toList(growable: false);
  }

  Future<Map<String, dynamic>> toggleSongFavorite({
    required String songId,
    required String platform,
    required bool like,
  }) async {
    final response = like
        ? await _dio.post(
            '/v1/user/favourite/song',
            data: <String, dynamic>{'id': songId, 'platform': platform},
          )
        : await _dio.delete(
            '/v1/user/favourite/song',
            data: <String, dynamic>{'id': songId, 'platform': platform},
          );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> toggleAlbumFavorite({
    required String albumId,
    required String platform,
    required bool like,
    String? name,
    String? cover,
    List<Map<String, dynamic>>? artists,
  }) async {
    final response = like
        ? await _dio.post(
            '/v1/user/favourite/album',
            data: <String, dynamic>{
              'id': albumId,
              'platform': platform,
              'name': name ?? '',
              'cover': cover ?? '',
              'artists': artists ?? const <Map<String, dynamic>>[],
            },
          )
        : await _dio.delete(
            '/v1/user/favourite/album',
            data: <String, dynamic>{'id': albumId, 'platform': platform},
          );
    return _asMap(response.data);
  }

  Future<Map<String, dynamic>> toggleArtistFavorite({
    required String artistId,
    required String platform,
    required bool like,
    String? name,
    String? cover,
  }) async {
    final response = like
        ? await _dio.post(
            '/v1/user/favourite/artist',
            data: <String, dynamic>{
              'id': artistId,
              'platform': platform,
              'name': name ?? '',
              'cover': cover ?? '',
            },
          )
        : await _dio.delete(
            '/v1/user/favourite/artist',
            data: <String, dynamic>{'id': artistId, 'platform': platform},
          );
    return _asMap(response.data);
  }

  Future<List<Map<String, dynamic>>> fetchComments({
    required String resourceId,
    required String resourceType,
    required String platform,
    int pageIndex = 1,
    int pageSize = 20,
    String? lastId,
    bool isHot = false,
  }) async {
    final result = await fetchCommentPage(
      resourceId: resourceId,
      resourceType: resourceType,
      platform: platform,
      pageIndex: pageIndex,
      pageSize: pageSize,
      lastId: lastId,
      isHot: isHot,
    );
    return result.list;
  }

  Future<OnlineCommentPageResult> fetchCommentPage({
    required String resourceId,
    required String resourceType,
    required String platform,
    int pageIndex = 1,
    int pageSize = 20,
    String? lastId,
    bool isHot = false,
  }) async {
    final safePageIndex = pageIndex <= 0 ? 1 : pageIndex;
    final safePageSize = pageSize <= 0
        ? 20
        : (pageSize > 1000 ? 1000 : pageSize);
    final response = await _dio.get(
      '/v1/comments',
      queryParameters: <String, dynamic>{
        'id': resourceId,
        'resource_type': resourceType,
        'platform': platform,
        'page_index': safePageIndex,
        'page_size': safePageSize,
        if (lastId != null && lastId.trim().isNotEmpty)
          'last_id': lastId.trim(),
        if (isHot) 'is_hot': true,
      },
    );
    final data = _asMap(response.data);
    final list = _extractList(data, <String>[
      'list',
      'comments',
      'items',
      'data',
    ]);
    return OnlineCommentPageResult(
      list: list,
      hasMore: _readBoolField(
        data,
        'has_more',
        fallback: list.length >= safePageSize,
      ),
      lastId: _readStringField(data, 'last_id'),
      totalCount: _readIntField(data, 'total_count'),
    );
  }

  Future<OnlineCommentPageResult> fetchSubCommentPage({
    required String resourceId,
    required String parentId,
    required String resourceType,
    required String platform,
    int pageIndex = 1,
    int pageSize = 15,
    String? lastId,
  }) async {
    final safePageIndex = pageIndex <= 0 ? 1 : pageIndex;
    final safePageSize = pageSize <= 0
        ? 15
        : (pageSize > 1000 ? 1000 : pageSize);
    final response = await _dio.get(
      '/v1/comment/subs',
      queryParameters: <String, dynamic>{
        'id': resourceId,
        'parent_id': parentId,
        'resource_type': resourceType,
        'platform': platform,
        'page_index': safePageIndex,
        'page_size': safePageSize,
        if (lastId != null && lastId.trim().isNotEmpty)
          'last_id': lastId.trim(),
      },
    );
    final data = _asMap(response.data);
    final list = _extractList(data, <String>[
      'list',
      'comments',
      'items',
      'data',
    ]);
    return OnlineCommentPageResult(
      list: list,
      hasMore: _readBoolField(
        data,
        'has_more',
        fallback: list.length >= safePageSize,
      ),
      lastId: _readStringField(data, 'last_id'),
      totalCount: _readIntField(data, 'total_count'),
    );
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return <String, dynamic>{'data': value};
  }

  int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }

  List<Map<String, dynamic>> _extractList(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = payload[key];
      if (value is List) {
        return value.map(_toMap).toList(growable: false);
      }
      if (value is Map) {
        for (final childKey in keys) {
          final nested = value[childKey];
          if (nested is List) {
            return nested.map(_toMap).toList(growable: false);
          }
        }
      }
    }
    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, item) => MapEntry('$key', item));
    }
    return <String, dynamic>{'value': value};
  }

  List<String> _extractStringList(
    Map<String, dynamic> payload,
    List<String> keys,
  ) {
    final result = <String>[];
    for (final key in keys) {
      final value = payload[key];
      _collectKeywords(value, result);
      if (result.isNotEmpty) {
        return result;
      }
    }
    for (final key in keys) {
      final nested = payload[key];
      if (nested is Map) {
        for (final child in keys) {
          _collectKeywords(nested[child], result);
        }
      }
      if (result.isNotEmpty) {
        return result;
      }
    }
    return result;
  }

  void _collectKeywords(dynamic value, List<String> target) {
    if (value is List) {
      for (final item in value) {
        final keyword = _toKeyword(item);
        if (keyword.isEmpty || target.contains(keyword)) {
          continue;
        }
        target.add(keyword);
      }
      return;
    }
    final keyword = _toKeyword(value);
    if (keyword.isEmpty || target.contains(keyword)) {
      return;
    }
    target.add(keyword);
  }

  String _toKeyword(dynamic value) {
    if (value is String) {
      return value.trim();
    }
    if (value is Map<String, dynamic>) {
      return _pickKeywordFromMap(value);
    }
    if (value is Map) {
      return _pickKeywordFromMap(
        value.map((key, item) => MapEntry('$key', item)),
      );
    }
    return '';
  }

  String _pickKeywordFromMap(Map<String, dynamic> value) {
    const keys = <String>['name', 'keyword', 'key', 'title', 'word'];
    for (final key in keys) {
      final raw = '${value[key] ?? ''}'.trim();
      if (raw.isNotEmpty) {
        return raw;
      }
    }
    return '';
  }

  dynamic _readField(Map<String, dynamic> payload, String field) {
    if (payload.containsKey(field)) {
      return payload[field];
    }
    final nested = payload['data'];
    if (nested is Map<String, dynamic> && nested.containsKey(field)) {
      return nested[field];
    }
    if (nested is Map && nested.containsKey(field)) {
      return nested[field];
    }
    return null;
  }

  String _readStringField(Map<String, dynamic> payload, String field) {
    final value = _readField(payload, field);
    if (value == null) {
      return '';
    }
    return '$value'.trim();
  }

  int _readIntField(Map<String, dynamic> payload, String field) {
    final value = _readField(payload, field);
    if (value is int) {
      return value;
    }
    if (value is double) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }

  bool _readBoolField(
    Map<String, dynamic> payload,
    String field, {
    required bool fallback,
  }) {
    final value = _readField(payload, field);
    if (value is bool) {
      return value;
    }
    if (value is int) {
      return value > 0;
    }
    if (value is double) {
      return value > 0;
    }
    final parsed = '$value'.trim().toLowerCase();
    if (parsed == 'true' || parsed == '1') {
      return true;
    }
    if (parsed == 'false' || parsed == '0') {
      return false;
    }
    return fallback;
  }

  OnlineComprehensiveSearchSection _readComprehensiveSection(dynamic value) {
    final payload = _asMap(value);
    final list = _extractList(payload, const <String>['list', 'items', 'data']);
    return OnlineComprehensiveSearchSection(
      items: list,
      hasMore: _readBoolField(payload, 'has_more', fallback: false),
      totalCount: _readIntField(payload, 'total_count'),
    );
  }

  /// 解析 best_match 字段，将 primary + recommendations 合并为一个有序列表
  List<BestMatchRecommendItem> _readBestMatch(dynamic value) {
    final payload = _asMap(value);
    if (payload.isEmpty) {
      return const <BestMatchRecommendItem>[];
    }
    final items = <BestMatchRecommendItem>[];
    // primary 作为第一项
    final primary = _readRecommendItem(payload['primary']);
    if (primary != null) {
      items.add(primary);
    }
    // recommendations 依次追加
    final recs = payload['recommendations'];
    if (recs is List) {
      for (final entry in recs) {
        final item = _readRecommendItem(entry);
        if (item != null) {
          items.add(item);
        }
      }
    }
    return items;
  }

  /// 解析单个 RecommendItem: resourceType + oneof data
  BestMatchRecommendItem? _readRecommendItem(dynamic value) {
    final map = _asMap(value);
    if (map.isEmpty) {
      return null;
    }
    final resourceType = '${map['resourceType'] ?? map['resource_type'] ?? ''}'
        .trim();
    if (resourceType.isEmpty) {
      return null;
    }
    // oneof data: 根据 resourceType 取对应字段
    final data = _asMap(map[resourceType]);
    if (data.isEmpty) {
      return null;
    }
    return BestMatchRecommendItem(resourceType: resourceType, data: data);
  }
}
