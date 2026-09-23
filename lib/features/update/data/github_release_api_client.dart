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

  Future<List<Map<String, dynamic>>> fetchReleases({
    required String owner,
    required String repo,
    required int page,
    int perPage = 30,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/repos/${Uri.encodeComponent(owner)}/${Uri.encodeComponent(repo)}/releases',
      queryParameters: {'page': page, 'per_page': perPage},
    );
    return (response.data ?? const <dynamic>[])
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList();
  }

  Future<String> fetchDownloadProxyConfig({
    required String owner,
    required String repo,
  }) async {
    final response = await _dio.get<String>(
      '/repos/${Uri.encodeComponent(owner)}/${Uri.encodeComponent(repo)}/contents/gh-proxy.json',
      options: Options(
        responseType: ResponseType.plain,
        headers: const <String, String>{
          'Accept': 'application/vnd.github.raw+json',
        },
      ),
    );
    return response.data ?? '';
  }
}
