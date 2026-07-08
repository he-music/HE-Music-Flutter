import 'package:dio/dio.dart';

class GitHubReleaseApiClient {
  GitHubReleaseApiClient(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> fetchLatestRelease({
    required String owner,
    required String repo,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/repos/${Uri.encodeComponent(owner)}/${Uri.encodeComponent(repo)}/releases/latest',
    );
    return response.data ?? const <String, dynamic>{};
  }
}
