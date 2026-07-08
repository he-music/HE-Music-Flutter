import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_message_service.dart';
import '../../app/config/app_config_controller.dart';
import 'network_error_message.dart';

class ErrorMessageInterceptor extends Interceptor {
  ErrorMessageInterceptor(this._ref);

  final Ref _ref;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_isSilent(err.requestOptions)) {
      handler.next(err);
      return;
    }
    final localeCode = _ref.read(appConfigProvider).localeCode;
    final message = NetworkErrorMessage.resolve(
      err,
      ignoreUnauthorized: true,
      ignoreCaptchaRequired: true,
      localeCode: localeCode,
    );
    if (message != null) {
      AppMessageService.showError(message);
    }
    handler.next(err);
  }

  bool _isSilent(RequestOptions options) {
    return options.extra['silentErrorMessage'] == true;
  }
}
