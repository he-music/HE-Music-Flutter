import 'package:flutter/material.dart';

import '../../../../app/i18n/app_i18n.dart';
import '../../../../shared/widgets/detail_page_shell.dart';
import '../../../../shared/widgets/song_list_component.dart';
import '../../../../shared/widgets/scroll_to_top_overlay.dart';
import '../../domain/entities/local_song.dart';

/// Keep the subscription stable across theme/locale rebuilds and allow retry.
class LocalSongsStreamView extends StatefulWidget {
  const LocalSongsStreamView({
    required this.sourceKey,
    required this.watchSongs,
    required this.localeCode,
    required this.emptyText,
    required this.builder,
    super.key,
  });

  final Object sourceKey;
  final Stream<List<LocalSong>> Function() watchSongs;
  final String localeCode;
  final String emptyText;
  final Widget Function(BuildContext, List<LocalSong>) builder;

  @override
  State<LocalSongsStreamView> createState() => _LocalSongsStreamViewState();
}

class _LocalSongsStreamViewState extends State<LocalSongsStreamView> {
  late Stream<List<LocalSong>> _stream = widget.watchSongs();
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LocalSongsStreamView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sourceKey != widget.sourceKey) _stream = widget.watchSongs();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<LocalSong>>(
    stream: _stream,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const SongListComponent(
          itemCount: 0,
          initialLoading: true,
          itemBuilder: _emptyItem,
        );
      }
      if (snapshot.hasError) {
        return DetailErrorBody(
          message: AppI18n.tByLocaleCode(
            widget.localeCode,
            'local.load_failed',
          ),
          onRetry: () => setState(() => _stream = widget.watchSongs()),
        );
      }
      final songs = snapshot.data ?? const <LocalSong>[];
      if (songs.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(widget.emptyText, textAlign: TextAlign.center),
          ),
        );
      }
      return PrimaryScrollController(
        automaticallyInheritForPlatforms: TargetPlatform.values.toSet(),
        controller: _scrollController,
        child: ScrollToTopOverlay(
          controller: _scrollController,
          child: widget.builder(context, songs),
        ),
      );
    },
  );

  static Widget _emptyItem(BuildContext context, int index) =>
      const SizedBox.shrink();
}
