import 'package:dio/dio.dart';

class CaptchaApiClient {
  CaptchaApiClient(this._dio);

  final Dio _dio;

  Future<CaptchaData> fetchCaptcha({
    required String scene,
    required String meta,
    int? type,
  }) async {
    final queryParams = <String, dynamic>{'scene': scene, 'meta': meta};
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

  Future<bool> verifyCaptcha({
    required String scene,
    required String meta,
    int angle = 0,
    Map<String, dynamic> point = const <String, dynamic>{},
    List<Map<String, dynamic>> dots = const <Map<String, dynamic>>[],
  }) async {
    final response = await _dio.post(
      '/v1/captcha',
      data: <String, dynamic>{
        'scene': scene,
        'meta': meta,
        'angle': angle,
        'point': point,
        'dots': dots,
      },
    );
    final payload = _unwrapBody(response.data);
    final isExpired = _readBool(payload['is_expired']);
    final isSuccess = _readBool(payload['is_success']);
    return !isExpired && isSuccess;
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

  bool _readBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    final normalized = '$value'.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
}

/// 验证码数据，直接提供 base64 字符串给 go_captcha_flutter 组件
class CaptchaData {
  const CaptchaData({
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
  final String image;
  final String thumb;
  final int thumbX;
  final int thumbY;
  final int thumbWidth;
  final int thumbHeight;
  final int thumbSize;
  final int angle;

  bool get isSupported =>
      type == 1 || type == 2 || type == 3 || type == 4 || type == 5;

  factory CaptchaData.fromMap(Map<String, dynamic> map) {
    return CaptchaData(
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
