import 'package:dio/dio.dart';
import '../../domain/repositories/sheet_music_download_repository.dart';
import '../repositories/sheet_music_download_repository_impl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_dio_provider.dart';
import '../../domain/repositories/sheet_music_repository.dart';
import '../datasources/sheet_music_api_client.dart';
import '../repositories/sheet_music_repository_impl.dart';

final sheetMusicApiClientProvider = Provider<SheetMusicApiClient>((ref) {
  return SheetMusicApiClient(ref.watch(apiDioProvider));
});

final sheetMusicRepositoryProvider = Provider<SheetMusicRepository>((ref) {
  return SheetMusicRepositoryImpl(ref.watch(sheetMusicApiClientProvider));
});

final sheetMusicDownloadRepositoryProvider =
    Provider<SheetMusicDownloadRepository>((ref) {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      ref.onDispose(() => dio.close(force: true));
      return SheetMusicDownloadRepositoryImpl(dio);
    });
