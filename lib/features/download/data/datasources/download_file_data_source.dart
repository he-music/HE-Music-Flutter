import 'package:dio/dio.dart';

import '../../domain/repositories/download_repository.dart';

class DownloadFileDataSource {
  DownloadFileDataSource(this._dio);

  final Dio _dio;

  Future<void> download({
    required String url,
    required String savePath,
    required DownloadProgressCallback onProgress,
  }) {
    return _dio.download(
      url,
      savePath,
      deleteOnError: true,
      onReceiveProgress: (received, total) {
        if (total <= 0) {
          onProgress(0);
          return;
        }
        onProgress(received / total);
      },
    );
  }
}
