import 'package:dio/dio.dart';

class AccountSettingsApiClient {
  const AccountSettingsApiClient(this._dio);

  final Dio _dio;

  Future<void> updateProfile({
    required String nickname,
    String? avatarUrl,
  }) async {
    await _dio.put(
      '/v1/user/info',
      data: <String, dynamic>{
        'nickname': nickname,
        'avatar': ?avatarUrl,
      },
    );
  }

  Future<void> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _dio.put(
      '/v1/user/password',
      data: <String, dynamic>{
        'old_password': oldPassword,
        'new_password': newPassword,
      },
    );
  }
}
