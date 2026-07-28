import 'package:dio/dio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/github_release_api_client.dart';
import '../../data/github_release_repository_impl.dart';
import '../../data/github_download_proxy_config_data_source.dart';
import '../../data/github_download_proxy_repository_impl.dart';
import '../../domain/entities/github_download_proxy_config.dart';
import '../../domain/entities/update_current_app_info.dart';
import '../../domain/entities/update_state.dart';
import '../../domain/repositories/github_download_proxy_repository.dart';
import '../../domain/repositories/update_repository.dart';
import '../controllers/github_download_proxy_controller.dart';
import '../controllers/update_controller.dart';
import '../../../../app/config/app_environment.dart';
import '../../application/update_download_target_service.dart';
import '../../application/github_download_proxy_auto_refresh_service.dart';

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

final gitHubDownloadProxyConfigDataSourceProvider =
    Provider<GitHubDownloadProxyConfigDataSource>((ref) {
      return GitHubDownloadProxyConfigDataSource();
    });

final gitHubDownloadProxyRepositoryProvider =
    Provider<GitHubDownloadProxyRepository>((ref) {
      return GitHubDownloadProxyRepositoryImpl(
        apiClient: ref.read(gitHubReleaseApiClientProvider),
        dataSource: ref.read(gitHubDownloadProxyConfigDataSourceProvider),
        owner: AppEnvironment.githubOwner,
        repo: AppEnvironment.githubRepo,
      );
    });

final gitHubDownloadProxyControllerProvider =
    AsyncNotifierProvider<
      GitHubDownloadProxyController,
      GitHubDownloadProxyConfigSnapshot
    >(GitHubDownloadProxyController.new);

final androidSupportedAbisProvider = FutureProvider<List<String>>((ref) async {
  if (defaultTargetPlatform != TargetPlatform.android) {
    return const <String>[];
  }
  final deviceInfo = await DeviceInfoPlugin().androidInfo;
  return List<String>.unmodifiable(deviceInfo.supportedAbis);
});

final updateDownloadTargetServiceProvider =
    Provider<UpdateDownloadTargetService>((ref) {
      return UpdateDownloadTargetService(
        isAndroid: () => defaultTargetPlatform == TargetPlatform.android,
        loadSupportedAbis: () => ref.read(androidSupportedAbisProvider.future),
        loadProxyConfig: () =>
            ref.read(gitHubDownloadProxyControllerProvider.future),
        owner: AppEnvironment.githubOwner,
        repo: AppEnvironment.githubRepo,
      );
    });

final gitHubDownloadProxyAutoRefreshServiceProvider =
    Provider<GitHubDownloadProxyAutoRefreshService>((ref) {
      return GitHubDownloadProxyAutoRefreshService(
        isAndroid: () => defaultTargetPlatform == TargetPlatform.android,
        loadLocal: () => ref.read(gitHubDownloadProxyControllerProvider.future),
        refresh: () =>
            ref.read(gitHubDownloadProxyControllerProvider.notifier).refresh(),
      );
    });

final updateControllerProvider =
    NotifierProvider<UpdateController, UpdateState>(UpdateController.new);
