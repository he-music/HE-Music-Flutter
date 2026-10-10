import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/song_list_item.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/local_song.dart';

/// Observe only whether this file is playing; playback ticks do not rebuild rows.
class LocalSongListItem extends ConsumerWidget {
  const LocalSongListItem({
    required this.song,
    required this.data,
    this.selectable = false,
    this.selected = false,
    this.onTap,
    this.onSelectTap,
    this.onMoreTap,
    super.key,
  });

  final LocalSong song;
  final SongListItemData data;
  final bool selectable;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onSelectTap;
  final VoidCallback? onMoreTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCurrent = ref.watch(
      playerControllerProvider.select(
        (state) => state.displayTrack?.path == song.filePath,
      ),
    );
    return SongListItem(
      data: data.copyWith(isCurrent: isCurrent),
      selectable: selectable,
      selected: selected,
      onTap: onTap,
      onSelectTap: onSelectTap,
      onMoreTap: onMoreTap,
    );
  }
}
