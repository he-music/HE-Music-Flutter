import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/helpers/song_detail_navigation_helper.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../data/providers/sheet_music_providers.dart';
import '../../domain/entities/sheet_music_info.dart';
import '../../domain/entities/sheet_music_download_state.dart';
import '../controllers/sheet_music_download_controller.dart';

export '../../data/providers/sheet_music_providers.dart';

typedef SheetMusicSongRequest = ({String platform, String songId});
typedef SheetMusicDetailRequest = ({String platform, String songId, String id});

final sheetMusicDownloadProvider = NotifierProvider.autoDispose
    .family<
      SheetMusicDownloadController,
      SheetMusicDownloadState,
      SheetMusicDetailRequest
    >((_) => SheetMusicDownloadController());

final sheetMusicListProvider = FutureProvider.autoDispose
    .family<List<SheetMusicInfo>, SheetMusicSongRequest>((ref, request) async {
      _validate(request.platform, request.songId);
      final repository = ref.watch(sheetMusicRepositoryProvider);
      final platforms = await ref.watch(onlinePlatformsProvider.future);
      if (!canListSongSheetMusic(
        songId: request.songId,
        platformId: request.platform,
        platforms: platforms,
      )) {
        throw const AppException(
          UnsupportedFailure('Sheet music is unsupported'),
        );
      }
      return repository.fetchList(
        platform: request.platform,
        songId: request.songId,
      );
    }, retry: (_, _) => null);

final sheetMusicDetailProvider = FutureProvider.autoDispose
    .family<SheetMusicInfo, SheetMusicDetailRequest>((ref, request) async {
      _validate(request.platform, request.songId, id: request.id);
      final repository = ref.watch(sheetMusicRepositoryProvider);
      final platforms = await ref.watch(onlinePlatformsProvider.future);
      if (!canGetSongSheetMusic(
        songId: request.songId,
        platformId: request.platform,
        platforms: platforms,
      )) {
        throw const AppException(
          UnsupportedFailure('Sheet music is unsupported'),
        );
      }
      return repository.fetchDetail(
        platform: request.platform,
        id: request.id,
        songId: request.songId,
      );
    }, retry: (_, _) => null);

void _validate(String platform, String songId, {String? id}) {
  if (platform.trim().isEmpty ||
      songId.trim().isEmpty ||
      (id != null && id.trim().isEmpty)) {
    throw const AppException(ValidationFailure('Missing sheet music identity'));
  }
}
