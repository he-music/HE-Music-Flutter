import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../player/domain/entities/player_track.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../pages/lyric_search_page.dart';

Future<void> openLyricSearch(
  BuildContext context,
  WidgetRef ref,
  PlayerTrack track,
) async {
  final playback = ref.read(playerControllerProvider);
  final current = playback.currentTrack;
  final isCurrent =
      current != null &&
      current.id == track.id &&
      current.platform == track.platform &&
      current.path == track.path;
  final target = isCurrent && playback.duration > Duration.zero
      ? track.copyWith(duration: playback.duration)
      : track;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => LyricSearchPage(target: target)),
  );
}

class LyricSearchEmpty extends ConsumerWidget {
  const LyricSearchEmpty({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );
    final locale = ref.watch(
      appConfigProvider.select((state) => state.localeCode),
    );
    return Center(
      child: TextButton.icon(
        style: TextButton.styleFrom(foregroundColor: color),
        onPressed: track == null
            ? null
            : () => openLyricSearch(context, ref, track),
        icon: const Icon(Icons.search_rounded),
        label: Text(AppI18n.tByLocaleCode(locale, 'player.lyric.search')),
      ),
    );
  }
}
