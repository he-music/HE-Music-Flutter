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
import '../../../../shared/widgets/song_list_item.dart';
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
    final lyricSnippet = _normalizeLyricLineBreaks(item.lyricSnippet).trim();
    final fullLyric = _normalizeLyricLineBreaks(item.lyric);
    final canExpandLyric = widget.allowFullLyric && fullLyric.trim().isNotEmpty;
    final lyricExpanded = _expandedLyricKeys.contains(songKey);
    final lyricToggle = canExpandLyric
        ? Padding(
            padding: const EdgeInsets.fromLTRB(78, 0, 12, 4),
            child: SongListItemTextAction(
              key: ValueKey<String>('search-lyric-toggle-$songKey'),
              onTap: () => _toggleLyric(songKey),
              label: AppI18n.tByLocaleCode(
                config.localeCode,
                lyricExpanded ? 'search.lyric.collapse' : 'search.lyric.expand',
              ),
              trailingIcon: lyricExpanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
            ),
          )
        : null;

    final lyricSnippetLines = lyricSnippet.split('\n');
    final lyricSnippetStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.45,
    );
    final lyricSnippetText = lyricSnippet.isEmpty
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List<Widget>.generate(lyricSnippetLines.length, (index) {
              final line = lyricSnippetLines[index];
              return Text.rich(
                TextSpan(
                  text: line.isEmpty ? ' ' : null,
                  children: <InlineSpan>[
                    if (index == 0 && !widget.allowFullLyric)
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(end: 4),
                          child: _LyricSnippetBadge(
                            key: ValueKey<String>(
                              'search-lyric-badge-$songKey',
                            ),
                            label: AppI18n.tByLocaleCode(
                              config.localeCode,
                              'search.lyric.badge',
                            ),
                          ),
                        ),
                      ),
                    ..._highlightSpans(line, item),
                  ],
                ),
                key: ValueKey<String>(
                  index == 0
                      ? 'search-lyric-snippet-$songKey'
                      : 'search-lyric-snippet-$songKey-$index',
                ),
                softWrap: false,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: lyricSnippetStyle,
                semanticsLabel: line,
              );
            }),
          );
    final lyricSnippetContent = !lyricExpanded && lyricSnippetText != null
        ? canExpandLyric
              ? InkWell(
                  key: ValueKey<String>('search-lyric-snippet-action-$songKey'),
                  onTap: () => _toggleLyric(songKey),
                  borderRadius: BorderRadius.circular(4),
                  child: lyricSnippetText,
                )
              : lyricSnippetText
        : null;
    final lyricContent = <Widget>[
      if (!lyricExpanded && lyricToggle != null) lyricToggle,
      if (canExpandLyric && lyricExpanded)
        Padding(
          key: ValueKey<String>('search-lyric-full-$songKey'),
          padding: const EdgeInsets.fromLTRB(80, 2, 16, 6),
          child: InkWell(
            key: ValueKey<String>('search-lyric-full-action-$songKey'),
            onTap: () => _toggleLyric(songKey),
            borderRadius: BorderRadius.circular(4),
            child: Text.rich(
              TextSpan(children: _highlightSpans(fullLyric, item)),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.65,
              ),
              semanticsLabel: fullLyric,
            ),
          ),
        ),
      if (lyricExpanded && lyricToggle != null) lyricToggle,
    ];

    return OnlineSongListItem(
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
      contentAfterSubtitle: lyricSnippetContent,
      footer: lyricContent.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: lyricContent,
            ),
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

  String _normalizeLyricLineBreaks(String value) {
    return value
        .replaceAll(r'\r\n', '\n')
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\r', '\n')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
  }
}

class _LyricSnippetBadge extends StatelessWidget {
  const _LyricSnippetBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.72)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontSize: 9.5,
          height: 1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
