import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/github_release_api_client.dart';
import '../../data/github_release_repository_impl.dart';
import '../../domain/entities/update_current_app_info.dart';
import '../../domain/entities/update_state.dart';
import '../../domain/repositories/update_repository.dart';
import '../controllers/update_controller.dart';

final currentAppInfoProvider = FutureProvider<UpdateCurrentAppInfo>((
  ref,
) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return UpdateCurrentAppInfo(
    appName: packageInfo.appName,
    version: packageInfo.version,
    buildNumber: packageInfo.buildNumber,
  );
});

final gitHubReleaseDioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: 'https://api.github.com',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: const <String, String>{
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      },
    ),
  );
});

final gitHubReleaseApiClientProvider = Provider<GitHubReleaseApiClient>((ref) {
  final dio = ref.read(gitHubReleaseDioProvider);
  return GitHubReleaseApiClient(dio);
});

final updateRepositoryProvider = Provider<UpdateRepository>((ref) {
  final apiClient = ref.read(gitHubReleaseApiClientProvider);
  return GitHubReleaseRepositoryImpl(apiClient);
});

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);
