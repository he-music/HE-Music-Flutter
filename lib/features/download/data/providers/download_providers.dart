import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../lyrics/data/datasources/online_lyric_data_source.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../domain/repositories/download_repository.dart';
import '../datasources/download_path_data_source.dart';
import '../datasources/download_runner_data_source.dart';
import '../datasources/download_task_store_data_source.dart';
import '../repositories/download_repository_impl.dart';
import '../services/download_lyric_resolver.dart';
import '../services/download_metadata_writer.dart';
import 'package:dio/dio.dart';

final downloadPathDataSourceProvider = Provider<DownloadPathDataSource>((ref) {
  return DownloadPathDataSource();
});

final downloadRunnerDataSourceProvider = Provider<DownloadRunnerDataSource>((
  ref,
) {
  return DownloadRunnerDataSource();
});

final downloadTaskStoreDataSourceProvider =
    Provider<DownloadTaskStoreDataSource>((ref) {
      return DownloadTaskStoreDataSource();
    });

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  final runnerDataSource = ref.read(downloadRunnerDataSourceProvider);
  final taskStoreDataSource = ref.read(downloadTaskStoreDataSourceProvider);
  final pathDataSource = ref.read(downloadPathDataSourceProvider);
  return DownloadRepositoryImpl(
    runnerDataSource,
    taskStoreDataSource,
    pathDataSource,
  );
});

final downloadMetadataWriterProvider = Provider<DownloadMetadataWriter>((ref) {
  final lyricDataSource = OnlineLyricDataSource(
    ref.read(onlineApiClientProvider),
  );
  return DownloadMetadataWriter(
    lyricResolver: DownloadLyricResolver.fromDataSource(lyricDataSource),
    metadataAdapter: const AudioMetadataAdapter(),
    dio: Dio(),
  );
});
