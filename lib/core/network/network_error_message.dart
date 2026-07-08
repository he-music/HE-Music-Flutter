import 'package:dio/dio.dart';

import '../../app/i18n/app_i18n.dart';
import '../error/app_exception.dart';

class NetworkErrorMessage {
  NetworkErrorMessage._();

  static const captchaReason = 'CAPTCHA_REQUIRED';

  static String? resolve(
    Object error, {
    bool ignoreUnauthorized = false,
    bool ignoreCaptchaRequired = false,
    String localeCode = 'zh',
  }) {
    if (error is AppException) {
      return error.failure.message.trim();
    }
    if (error is! DioException) {
      final fallback = '$error'.trim();
      return fallback.isEmpty ? null : fallback;
    }
    final statusCode = error.response?.statusCode;
    if (ignoreUnauthorized && statusCode == 401) {
      return null;
    }
    if (ignoreCaptchaRequired &&
        statusCode == 403 &&
        _readReason(error.response?.data) == captchaReason) {
      return null;
    }
    final dataMessage = _readMessage(error.response?.data);
    if (dataMessage != null) {
      return dataMessage;
    }
    if (statusCode != null) {
      return switch (statusCode) {
        400 => AppI18n.tByLocaleCode(localeCode, 'error.network.bad_request'),
        403 => AppI18n.tByLocaleCode(localeCode, 'error.network.forbidden'),
        404 => AppI18n.tByLocaleCode(localeCode, 'error.network.not_found'),
        500 => AppI18n.tByLocaleCode(localeCode, 'error.network.server_error'),
        _ => _messageForType(error, localeCode),
      };
    }
    return _messageForType(error, localeCode);
  }

  static String _messageForType(DioException error, String localeCode) {
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => AppI18n.tByLocaleCode(
        localeCode,
        'error.network.timeout',
      ),
      DioExceptionType.connectionError => AppI18n.tByLocaleCode(
        localeCode,
        'error.network.connection_failed',
      ),
      DioExceptionType.badCertificate => AppI18n.tByLocaleCode(
        localeCode,
        'error.network.bad_certificate',
      ),
      DioExceptionType.cancel => AppI18n.tByLocaleCode(
        localeCode,
        'error.network.cancelled',
      ),
      DioExceptionType.badResponse => AppI18n.tByLocaleCode(
        localeCode,
        'error.network.bad_response',
      ),
      DioExceptionType.unknown => _fallbackMessage(error.message, localeCode),
    };
  }

  static String _fallbackMessage(String? message, String localeCode) {
    final normalized = message?.trim() ?? '';
    if (normalized.isEmpty) {
      return AppI18n.tByLocaleCode(localeCode, 'error.network.request_failed');
    }
    return normalized;
  }

  static String? _readMessage(dynamic raw) {
    final map = _asMap(raw);
    for (final key in const <String>['message', 'msg', 'error', 'detail']) {
      final direct = '${map[key] ?? ''}'.trim();
      if (direct.isNotEmpty) {
        return direct;
      }
    }
    final data = _asMap(map['data']);
    for (final key in const <String>['message', 'msg', 'error', 'detail']) {
      final nested = '${data[key] ?? ''}'.trim();
      if (nested.isNotEmpty) {
        return nested;
      }
    }
    return null;
  }

  static String _readReason(dynamic raw) {
    final map = _asMap(raw);
    return '${map['reason'] ?? ''}'.trim();
  }

  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((dynamic key, dynamic item) => MapEntry('$key', item));
    }
    return const <String, dynamic>{};
  }
}
