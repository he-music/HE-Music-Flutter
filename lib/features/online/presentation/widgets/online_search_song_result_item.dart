import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../features/player/presentation/providers/player_providers.dart';
import '../../../../shared/helpers/current_track_helper.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/utils/cover_resolver.dart';
import '../../../../shared/widgets/online_song_list_item.dart';
import '../../domain/entities/online_platform.dart';
import '../providers/online_providers.dart';
import '../utils/search_text_highlight.dart';

class OnlineSearchSongResultItem extends ConsumerStatefulWidget {
  const OnlineSearchSongResultItem({
    required this.item,
    required this.searchKeyword,
    required this.likedSongKeys,
    required this.onTapSong,
    required this.onLikeSong,
    required this.onMoreSong,
    this.allowFullLyric = false,
    super.key,
  });

  final SearchSongInfo item;
  final String searchKeyword;
  final Set<String> likedSongKeys;
  final ValueChanged<SongInfo> onTapSong;
  final Future<void> Function(SongInfo) onLikeSong;
  final ValueChanged<SongInfo> onMoreSong;
  final bool allowFullLyric;

  @override
  ConsumerState<OnlineSearchSongResultItem> createState() =>
      _OnlineSearchSongResultItemState();
}

class _OnlineSearchSongResultItemState
    extends ConsumerState<OnlineSearchSongResultItem> {
  bool _versionsExpanded = false;
  final Set<String> _expandedLyricKeys = <String>{};

  @override
  void didUpdateWidget(covariant OnlineSearchSongResultItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.item, widget.item) ||
        oldWidget.searchKeyword != widget.searchKeyword ||
        oldWidget.allowFullLyric != widget.allowFullLyric) {
      _versionsExpanded = false;
      _expandedLyricKeys.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _buildSongItem(
        item: widget.item,
        showMoreVersion: widget.item.sublist.isNotEmpty,
        onMoreVersionTap: widget.item.sublist.isEmpty ? null : _toggleVersions,
      ),
    ];
    if (_versionsExpanded) {
      for (final subItem in widget.item.sublist) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _buildSongItem(
              item: subItem,
              showMoreVersion: false,
              onMoreVersionTap: null,
            ),
          ),
        );
      }
    }
    return Column(children: children);
  }

  Widget _buildSongItem({
    required SearchSongInfo item,
    required bool showMoreVersion,
    required VoidCallback? onMoreVersionTap,
  }) {
    final song = item.song;
    final songKey = _songKey(song);
    final config = ref.read(appConfigProvider);
    final platforms =
        ref.read(onlinePlatformsProvider).value ?? const <OnlinePlatform>[];
    final currentTrack = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );
    final coverUrl = resolveSongCoverUrl(
      baseUrl: config.apiBaseUrl,
      token: config.authToken ?? '',
      platforms: platforms,
      platformId: song.platform,
      songId: song.id,
      cover: song.cover,
      size: 300,
    );
    final lyricSnippet = item.lyricSnippet.trim();
    final canExpandLyric =
        widget.allowFullLyric && item.lyric.trim().isNotEmpty;
    final lyricExpanded = _expandedLyricKeys.contains(songKey);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        OnlineSongListItem(
          song: song,
          artistAlbumText: song.artistAlbumText,
          subtitleText: song.displaySubtitle,
          titleSpans: _highlightSpans(song.title, item),
          artistAlbumSpans: _highlightSpans(song.artistAlbumText, item),
          subtitleSpans: _highlightSpans(song.displaySubtitle, item),
          additionalTags: item.originalType == 1
              ? <String>[
                  AppI18n.tByLocaleCode(config.localeCode, 'song.tag.original'),
                ]
              : const <String>[],
          coverUrl: coverUrl.trim().isEmpty ? null : coverUrl,
          isCurrent: isCurrentSongTrack(currentTrack, song),
          showMoreVersionButton: showMoreVersion,
          isLiked: widget.likedSongKeys.contains(songKey),
          onTap: () => widget.onTapSong(song),
          onLikeTap: () => unawaited(widget.onLikeSong(song)),
          onMoreTap: () => widget.onMoreSong(song),
          onMoreVersionTap: onMoreVersionTap,
        ),
        if (lyricSnippet.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(80, 2, 16, 6),
            child: Text.rich(
              TextSpan(children: _highlightSpans(lyricSnippet, item)),
              key: ValueKey<String>('search-lyric-snippet-$songKey'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
              semanticsLabel: lyricSnippet,
            ),
          ),
        if (canExpandLyric)
          Padding(
            padding: const EdgeInsets.fromLTRB(76, 0, 12, 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: ValueKey<String>('search-lyric-toggle-$songKey'),
                onPressed: () => _toggleLyric(songKey),
                icon: Icon(
                  lyricExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                ),
                label: Text(
                  AppI18n.tByLocaleCode(
                    config.localeCode,
                    lyricExpanded
                        ? 'search.lyric.collapse'
                        : 'search.lyric.expand',
                  ),
                ),
              ),
            ),
          ),
        if (canExpandLyric && lyricExpanded)
          Padding(
            key: ValueKey<String>('search-lyric-full-$songKey'),
            padding: const EdgeInsets.fromLTRB(80, 0, 16, 12),
            child: Text.rich(
              TextSpan(children: _highlightSpans(item.lyric, item)),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.65,
              ),
              semanticsLabel: item.lyric,
            ),
          ),
      ],
    );
  }

  List<InlineSpan> _highlightSpans(String text, SearchSongInfo item) {
    final highlightStyle = TextStyle(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    return splitSearchHighlightText(
          text: text,
          matchedKeywords: item.matchedKeywords,
          fallbackKeyword: widget.searchKeyword,
        )
        .map<InlineSpan>(
          (segment) => TextSpan(
            text: segment.text,
            style: segment.highlighted ? highlightStyle : null,
          ),
        )
        .toList(growable: false);
  }

  void _toggleVersions() {
    setState(() => _versionsExpanded = !_versionsExpanded);
  }

  void _toggleLyric(String songKey) {
    setState(() {
      if (!_expandedLyricKeys.add(songKey)) {
        _expandedLyricKeys.remove(songKey);
      }
    });
  }

  String _songKey(SongInfo song) => '${song.id}|${song.platform}';
}
