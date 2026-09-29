import 'package:dio/dio.dart';

class CaptchaApiClient {
  CaptchaApiClient(this._dio);

  final Dio _dio;

  Future<CaptchaData> fetchCaptcha({
    required String scene,
    required String meta,
    int? type,
    String? sessionId,
  }) async {
    final queryParams = <String, dynamic>{'scene': scene, 'meta': meta};
    if (sessionId == null) {
      queryParams['supported_methods'] = 1;
    } else {
      queryParams['session_id'] = sessionId;
    }
    if (type != null && type > 0) {
      queryParams['type'] = type;
    }
    final response = await _dio.get(
      '/v1/captcha',
      queryParameters: queryParams,
    );
    final payload = _unwrapBody(response.data);
    return CaptchaData.fromMap(payload);
  }

  Future<CaptchaVerification> verifyCaptcha({
    required String scene,
    required String meta,
    required String sessionId,
    required String challengeId,
    int angle = 0,
    Map<String, dynamic> point = const <String, dynamic>{},
    List<Map<String, dynamic>> dots = const <Map<String, dynamic>>[],
  }) async {
    final response = await _dio.post(
      '/v1/captcha',
      data: <String, dynamic>{
        'scene': scene,
        'meta': meta,
        'session_id': sessionId,
        'challenge_id': challengeId,
        'angle': angle,
        'point': point,
        'dots': dots,
      },
    );
    return CaptchaVerification.fromMap(_unwrapBody(response.data));
  }

  Future<CaptchaVerification> getResult(String sessionId) async {
    final response = await _dio.post(
      '/v1/captcha/result',
      data: <String, dynamic>{'session_id': sessionId},
    );
    return CaptchaVerification.fromMap(_unwrapBody(response.data));
  }

  Map<String, dynamic> _unwrapBody(dynamic raw) {
    final map = _asMap(raw);
    final nested = _asMap(map['data']);
    if (nested.isNotEmpty) {
      return nested;
    }
    return map;
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((dynamic key, dynamic item) => MapEntry('$key', item));
    }
    return const <String, dynamic>{};
  }
}

class CaptchaVerification {
  const CaptchaVerification({
    required this.isSuccess,
    required this.isExpired,
    required this.ticket,
  });

  final bool isSuccess;
  final bool isExpired;
  final String ticket;

  factory CaptchaVerification.fromMap(Map<String, dynamic> map) =>
      CaptchaVerification(
        isSuccess: _readBool(map['is_success']),
        isExpired: _readBool(map['is_expired']),
        ticket: '${map['captcha_ticket'] ?? ''}',
      );

  static bool _readBool(dynamic value) =>
      value == true || value == 1 || '$value'.toLowerCase() == 'true';
}

/// 验证码数据，直接提供 base64 字符串给 go_captcha_flutter 组件
class CaptchaData {
  const CaptchaData({
    required this.sessionId,
    required this.challengeId,
    required this.expiresAt,
    required this.method,
    required this.type,
    required this.image,
    required this.thumb,
    this.thumbX = 0,
    this.thumbY = 0,
    this.thumbWidth = 0,
    this.thumbHeight = 0,
    this.thumbSize = 0,
    this.angle = 0,
  });

  final int type;
  final String sessionId;
  final String challengeId;
  final int expiresAt;
  final int method;
  final String image;
  final String thumb;
  final int thumbX;
  final int thumbY;
  final int thumbWidth;
  final int thumbHeight;
  final int thumbSize;
  final int angle;

  bool get isSupported =>
      method == 1 &&
      sessionId.isNotEmpty &&
      challengeId.isNotEmpty &&
      expiresAt > DateTime.now().millisecondsSinceEpoch &&
      (type == 1 || type == 2 || type == 3 || type == 4 || type == 5);

  factory CaptchaData.fromMap(Map<String, dynamic> map) {
    return CaptchaData(
      sessionId: '${map['session_id'] ?? ''}',
      challengeId: '${map['challenge_id'] ?? ''}',
      expiresAt: _readInt(map['expires_at']),
      method: _readInt(map['method']),
      type: _readInt(map['type']),
      image: _normalizeBase64(map['image']),
      thumb: _normalizeBase64(map['thumb']),
      thumbX: _readInt(map['thumb_x'] ?? map['thumbX']),
      thumbY: _readInt(map['thumb_y'] ?? map['thumbY']),
      thumbWidth: _readInt(
        map['thumb_width'] ?? map['thumbWidth'],
        fallback: 44,
      ),
      thumbHeight: _readInt(
        map['thumb_height'] ?? map['thumbHeight'],
        fallback: 44,
      ),
      thumbSize: _readInt(map['thumb_size'] ?? map['thumbSize'], fallback: 44),
      angle: _readInt(map['angle']),
    );
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? fallback;
  }

  static String _normalizeBase64(dynamic value) {
    final raw = '$value'.trim();
    if (raw.isEmpty) {
      return '';
    }
    if (raw.startsWith('data:image')) {
      return raw;
    }
    return 'data:image/png;base64,$raw';
  }
}
