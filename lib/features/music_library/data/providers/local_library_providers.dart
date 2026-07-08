import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/audio/local_audio_metadata_reader.dart';
import '../../../../core/database/local_music_database.dart';
import '../../domain/repositories/local_music_repository.dart';
import '../datasources/local_artwork_extractor.dart';
import '../datasources/local_music_dao.dart';
import '../datasources/local_music_query_data_source.dart';
import '../repositories/local_music_repository_impl.dart';

final localMusicDatabaseProvider = Provider<LocalMusicDatabase>((ref) {
  return LocalMusicDatabase();
});

final localMusicDaoProvider = Provider<LocalMusicDao>((ref) {
  final dao = LocalMusicDao(ref.read(localMusicDatabaseProvider));
  return dao;
});

final localArtworkExtractorProvider = Provider<LocalArtworkExtractor>((ref) {
  final dao = ref.read(localMusicDaoProvider);
  return LocalArtworkExtractor(dao, LocalAudioMetadataReader());
});

final localMusicQueryDataSourceProvider = Provider<LocalMusicQueryDataSource>((
  ref,
) {
  return LocalMusicQueryDataSource();
});

final localMusicRepositoryProvider = Provider<LocalMusicRepository>((ref) {
  final dataSource = ref.read(localMusicQueryDataSourceProvider);
  final dao = ref.read(localMusicDaoProvider);
  return LocalMusicRepositoryImpl(dataSource, LocalAudioMetadataReader(), dao);
});
