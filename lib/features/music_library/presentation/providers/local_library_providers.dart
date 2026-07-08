import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/local_song.dart';
import '../controllers/local_library_controller.dart';

export '../../data/providers/local_library_providers.dart';

final localLibraryControllerProvider =
    AsyncNotifierProvider<LocalLibraryController, List<LocalSong>>(
      LocalLibraryController.new,
    );

typedef LocalSongFileShare = Future<void> Function(LocalSong song);

final localSongFileShareProvider = Provider<LocalSongFileShare>((ref) {
  return (song) async {
    await SharePlus.instance.share(
      ShareParams(
        title: song.title,
        files: [XFile(song.filePath, mimeType: song.mimeType)],
      ),
    );
  };
});
