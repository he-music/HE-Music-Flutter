import 'package:dio/dio.dart';

import '../captcha/captcha_challenge.dart';
import '../captcha/captcha_coordinator.dart';

class CaptchaChallengeInterceptor extends Interceptor {
  CaptchaChallengeInterceptor({required this.dio, required this.coordinator});

  final Dio dio;
  final CaptchaCoordinator coordinator;

  static const _captchaRetriedKey = 'captchaRetried';
  static const _captchaReason = 'CAPTCHA_REQUIRED';

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_isCaptchaRequired(err)) {
      handler.next(err);
      return;
    }
    final requestOptions = err.requestOptions;
    if (requestOptions.extra[_captchaRetriedKey] == true) {
      handler.next(err);
      return;
    }
    final challenge = _readChallenge(err.response?.data);
    if (challenge == null) {
      handler.next(err);
      return;
    }
    final passed = await coordinator.open(challenge);
    if (!passed) {
      handler.next(err);
      return;
    }
    final retryOptions = requestOptions.copyWith(
      extra: <String, dynamic>{
        ...requestOptions.extra,
        _captchaRetriedKey: true,
      },
    );
    try {
      final response = await dio.fetch<dynamic>(retryOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    } catch (retryError) {
      handler.next(
        DioException(requestOptions: retryOptions, error: retryError),
      );
    }
  }

  bool _isCaptchaRequired(DioException err) {
    return err.response?.statusCode == 403 &&
        _readReason(err.response?.data) == _captchaReason;
  }

  String _readReason(dynamic raw) {
    final map = _asMap(raw);
    return '${map['reason'] ?? ''}'.trim();
  }

  CaptchaChallenge? _readChallenge(dynamic raw) {
    final map = _asMap(raw);
    final metadata = _asMap(map['metadata']);
    final scene = '${metadata['scene'] ?? ''}'.trim();
    final meta = '${metadata['meta'] ?? ''}'.trim();
    if (scene.isEmpty || meta.isEmpty) {
      return null;
    }
    return CaptchaChallenge(scene: scene, meta: meta);
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
}
