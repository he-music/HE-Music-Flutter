import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/settings/data/account_settings_api_client.dart';

void main() {
  group('AccountSettingsApiClient', () {
    test('updateProfile sends nickname and avatar with PUT', () async {
      final capture = _DioCapture();
      final client = AccountSettingsApiClient(capture.dio);

      await client.updateProfile(
        nickname: 'New Name',
        avatarUrl: 'https://example.com/avatar.jpg',
      );

      expect(capture.method, 'PUT');
      expect(capture.path, '/v1/user/info');
      expect(capture.data, <String, dynamic>{
        'nickname': 'New Name',
        'avatar': 'https://example.com/avatar.jpg',
      });
    });

    test('updateProfile omits avatar when it is not supplied', () async {
      final capture = _DioCapture();
      final client = AccountSettingsApiClient(capture.dio);

      await client.updateProfile(nickname: 'New Name');

      expect(capture.method, 'PUT');
      expect(capture.path, '/v1/user/info');
      expect(capture.data, <String, dynamic>{'nickname': 'New Name'});
    });

    test('updatePassword sends snake case fields with PUT', () async {
      final capture = _DioCapture();
      final client = AccountSettingsApiClient(capture.dio);

      await client.updatePassword(
        oldPassword: 'old-pass',
        newPassword: 'new-pass',
      );

      expect(capture.method, 'PUT');
      expect(capture.path, '/v1/user/password');
      expect(capture.data, <String, dynamic>{
        'old_password': 'old-pass',
        'new_password': 'new-pass',
      });
    });
  });
}

class _DioCapture {
  _DioCapture() : dio = Dio() {
    dio.httpClientAdapter = _CaptureAdapter(_capture);
  }

  final Dio dio;
  String? method;
  String? path;
  dynamic data;

  void _capture(RequestOptions options) {
    method = options.method;
    path = options.path;
    data = options.data;
  }
}

class _CaptureAdapter implements HttpClientAdapter {
  const _CaptureAdapter(this.onRequest);

  final void Function(RequestOptions options) onRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    onRequest(options);
    return ResponseBody.fromString(
      '{}',
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }
}
