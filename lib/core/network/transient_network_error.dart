import 'package:dio/dio.dart';

/// 仅重试传输层的临时异常，不重试认证、证书、取消或业务响应错误。
bool isTransientNetworkError(Object error) {
  return error is DioException &&
      switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError => true,
        _ => false,
      };
}
