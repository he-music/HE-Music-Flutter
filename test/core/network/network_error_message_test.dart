import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/error/app_exception.dart';
import 'package:he_music_flutter/core/error/failure.dart';
import 'package:he_music_flutter/core/network/network_error_message.dart';

DioException _dioException({
  int? statusCode,
  DioExceptionType type = DioExceptionType.badResponse,
  dynamic data,
  String? message,
}) {
  return DioException(
    requestOptions: RequestOptions(path: '/test'),
    response: statusCode != null
        ? Response(
            requestOptions: RequestOptions(path: '/test'),
            statusCode: statusCode,
            data: data,
          )
        : null,
    type: type,
    message: message,
  );
}

void main() {
  group('NetworkErrorMessage.resolve', () {
    group('AppException', () {
      test('返回 failure.message', () {
        final error = AppException(NetworkFailure('网络不可用'));
        final result = NetworkErrorMessage.resolve(error);
        expect(result, '网络不可用');
      });
    });

    group('非 DioException 的普通对象', () {
      test('返回 toString 内容', () {
        final result = NetworkErrorMessage.resolve(StateError('state broken'));
        expect(result, contains('state broken'));
      });

      test('空 toString 返回 null', () {
        // 空字符串的 toString 仍会返回 ''，trim 后为空则返回 null
        final result = NetworkErrorMessage.resolve('');
        expect(result, isNull);
      });
    });

    group('status code 分支', () {
      test('400 返回 bad_request', () {
        final error = _dioException(statusCode: 400);
        final result = NetworkErrorMessage.resolve(error);
        expect(result, '请求参数错误');
      });

      test('403 返回 forbidden', () {
        final error = _dioException(statusCode: 403);
        final result = NetworkErrorMessage.resolve(error);
        expect(result, isNotNull);
      });

      test('404 返回 not_found', () {
        final error = _dioException(statusCode: 404);
        final result = NetworkErrorMessage.resolve(error);
        expect(result, isNotNull);
      });

      test('500 返回 server_error', () {
        final error = _dioException(statusCode: 500);
        final result = NetworkErrorMessage.resolve(error);
        expect(result, isNotNull);
      });
    });

    group('DioException type 分支', () {
      test('connectionTimeout 返回超时消息', () {
        final error = _dioException(type: DioExceptionType.connectionTimeout);
        final result = NetworkErrorMessage.resolve(error);
        expect(result, isNotNull);
      });

      test('connectionError 返回连接失败消息', () {
        final error = _dioException(type: DioExceptionType.connectionError);
        final result = NetworkErrorMessage.resolve(error);
        expect(result, isNotNull);
      });

      test('badCertificate 返回证书错误消息', () {
        final error = _dioException(type: DioExceptionType.badCertificate);
        final result = NetworkErrorMessage.resolve(error);
        expect(result, isNotNull);
      });

      test('cancel 返回取消消息', () {
        final error = _dioException(type: DioExceptionType.cancel);
        final result = NetworkErrorMessage.resolve(error);
        expect(result, isNotNull);
      });

      test('unknown + 有 message 返回 message', () {
        final error = _dioException(
          type: DioExceptionType.unknown,
          message: 'custom error',
        );
        final result = NetworkErrorMessage.resolve(error);
        expect(result, 'custom error');
      });

      test('unknown + 空 message 返回默认请求失败', () {
        final error = _dioException(
          type: DioExceptionType.unknown,
          message: '',
        );
        final result = NetworkErrorMessage.resolve(error);
        expect(result, isNotNull);
      });
    });

    group('ignore 标志', () {
      test('ignoreUnauthorized=true + 401 返回 null', () {
        final error = _dioException(statusCode: 401);
        final result = NetworkErrorMessage.resolve(
          error,
          ignoreUnauthorized: true,
        );
        expect(result, isNull);
      });

      test('ignoreUnauthorized=false + 401 不返回 null', () {
        final error = _dioException(statusCode: 401);
        final result = NetworkErrorMessage.resolve(
          error,
          ignoreUnauthorized: false,
        );
        expect(result, isNotNull);
      });

      test('ignoreCaptchaRequired=true + 403 + CAPTCHA_REQUIRED 返回 null', () {
        final error = _dioException(
          statusCode: 403,
          data: {'reason': 'CAPTCHA_REQUIRED'},
        );
        final result = NetworkErrorMessage.resolve(
          error,
          ignoreCaptchaRequired: true,
        );
        expect(result, isNull);
      });

      test('ignoreCaptchaRequired=true + 403 + 非 CAPTCHA reason 不返回 null', () {
        final error = _dioException(
          statusCode: 403,
          data: {'reason': 'FORBIDDEN'},
        );
        final result = NetworkErrorMessage.resolve(
          error,
          ignoreCaptchaRequired: true,
        );
        expect(result, isNotNull);
      });
    });

    group('data message 提取', () {
      test('data.message 优先于 statusCode 映射', () {
        final error = _dioException(
          statusCode: 500,
          data: {'message': '服务器维护中'},
        );
        final result = NetworkErrorMessage.resolve(error);
        expect(result, '服务器维护中');
      });

      test('data.msg 被提取', () {
        final error = _dioException(statusCode: 400, data: {'msg': '参数错误'});
        final result = NetworkErrorMessage.resolve(error);
        expect(result, '参数错误');
      });

      test('data.error 被提取', () {
        final error = _dioException(statusCode: 404, data: {'error': '未找到'});
        final result = NetworkErrorMessage.resolve(error);
        expect(result, '未找到');
      });

      test('data.detail 被提取', () {
        final error = _dioException(statusCode: 403, data: {'detail': '无权限'});
        final result = NetworkErrorMessage.resolve(error);
        expect(result, '无权限');
      });

      test('嵌套 data.data.message 被提取', () {
        final error = _dioException(
          statusCode: 500,
          data: {
            'data': {'message': '内部错误'},
          },
        );
        final result = NetworkErrorMessage.resolve(error);
        expect(result, '内部错误');
      });

      test('空 message 字段被跳过', () {
        final error = _dioException(
          statusCode: 400,
          data: {'message': '', 'msg': '实际消息'},
        );
        final result = NetworkErrorMessage.resolve(error);
        expect(result, '实际消息');
      });
    });

    group('localeCode', () {
      test('英文 localeCode 返回英文错误消息', () {
        final error = _dioException(statusCode: 400);
        final result = NetworkErrorMessage.resolve(error, localeCode: 'en');
        expect(result, 'Bad request');
      });

      test('中文 localeCode 返回中文错误消息', () {
        final error = _dioException(statusCode: 400);
        final result = NetworkErrorMessage.resolve(error, localeCode: 'zh');
        expect(result, '请求参数错误');
      });
    });
  });
}
