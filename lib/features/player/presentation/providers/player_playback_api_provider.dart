import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../online/data/online_api_client.dart';

final playerPlaybackApiClientProvider = Provider<OnlineApiClient>((ref) {
  final (apiBaseUrl, authToken) = ref.watch(
    appConfigProvider.select((config) => (config.apiBaseUrl, config.authToken)),
  );
  final baseUrl = apiBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      responseType: ResponseType.json,
      headers: <String, String>{
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13; Pixel 6) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        if (authToken != null && authToken.isNotEmpty) ...<String, String>{
          'authorization': 'Bearer $authToken',
          'Authorization': 'Bearer $authToken',
        },
      },
    ),
  );
  ref.onDispose(() {
    dio.close(force: true);
  });
  return OnlineApiClient(dio);
});
