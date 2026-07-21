import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../../shared/helpers/album_id_helper.dart';
import '../../../../shared/helpers/platform_label_helper.dart';
import '../../../../shared/helpers/song_artist_navigation_helper.dart';
import '../../../../shared/helpers/song_detail_navigation_helper.dart';
import '../../../../shared/helpers/user_playlist_song_action_helper.dart';
import '../../../../shared/models/he_music_models.dart';
import '../../../../shared/utils/cover_resolver.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../my/presentation/providers/favorite_song_status_providers.dart';
import '../../domain/entities/online_platform.dart';
import '../../../player/domain/entities/player_quality_option.dart';
import '../../../player/domain/entities/player_track.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../download/domain/entities/download_task.dart';
import '../../../download/presentation/providers/download_providers.dart';
import '../../../download/presentation/widgets/download_quality_sheet.dart';
import '../providers/online_providers.dart';
import 'online_search_actions_handler.dart';
import 'online_search_bars.dart';
import 'online_search_hot_panel.dart';
import 'online_search_models.dart';
import 'online_search_result_page.dart';
import 'online_search_suggest_panel.dart';
import 'online_search_song_actions.dart';
import '../../../../shared/widgets/detail_page_shell.dart';

class OnlineSearchPage extends ConsumerStatefulWidget {
  const OnlineSearchPage({
    required this.platform,
    this.initialKeyword,
    this.initialType,
    super.key,
  });

  final String platform;
  final String? initialKeyword;
  final String? initialType;

  @override
  ConsumerState<OnlineSearchPage> createState() => _OnlineSearchPageState();
}

class _OnlineSearchPageState extends ConsumerState<OnlineSearchPage> {
  static const int _searchPageSize = 30;
  static const List<String> _defaultHotKeywords = <String>[
    '周杰伦',
    '林俊杰',
    '邓紫棋',
    '毛不易',
    '陈奕迅',
    '张杰',
    'Taylor Swift',
    'Adele',
  ];

  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final Map<String, List<Map<String, dynamic>>> _searchResultCache =
      <String, List<Map<String, dynamic>>>{};
  final Map<String, OnlineComprehensiveSearchResult> _comprehensiveResultCache =
      <String, OnlineComprehensiveSearchResult>{};
  final Map<String, String> _searchErrorCache = <String, String>{};
  final Set<String> _loadingCacheKeys = <String>{};
  final Set<String> _loadingMoreCacheKeys = <String>{};
  final Map<String, int> _nextPageCache = <String, int>{};
  final Map<String, bool> _hasMoreCache = <String, bool>{};

  Timer? _suggestDebounce;
  bool _showSuggestionPanel = true;
  bool _loadingSearchHistory = true;
  bool _loadingHotKeywords = true;
  bool _loadingSuggestions = false;
  String _activeSearchKeyword = '';
  SearchDefaultEntry? _frozenPlaceholderEntry;
  List<String> _searchHistoryKeywords = const <String>[];
  List<String> _hotKeywords = const <String>[];
  List<String> _suggestKeywords = const <String>[];

  SearchType _selectedType = SearchType.comprehensive;
  late String _selectedPlatformId;

  @override
  void initState() {
    super.initState();
    _selectedPlatformId = widget.platform;
    _selectedType =
        _parseInitialType(widget.initialType) ?? SearchType.comprehensive;
    _searchFocusNode.addListener(_onSearchFocusChanged);
    Future.microtask(() async {
      await _loadSearchHistory();
      await _loadHotKeywords();
    });
    _prefillKeywordIfNeeded();
  }

  SearchType? _parseInitialType(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    return switch (value) {
      'song' => SearchType.song,
      'comprehensive' => SearchType.comprehensive,
      'all' => SearchType.comprehensive,
      'playlist' => SearchType.playlist,
      'album' => SearchType.album,
      'artist' => SearchType.artist,
      'video' => SearchType.video,
      'mv' => SearchType.video,
      _ => null,
    };
  }

  void _prefillKeywordIfNeeded() {
    final keyword = widget.initialKeyword?.trim() ?? '';
    if (keyword.isEmpty) {
      return;
    }
    _searchController.text = keyword;
    _showSuggestionPanel = false;
    Future.microtask(_search);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<OnlinePlatform>>>(onlinePlatformsProvider, (
      previous,
      next,
    ) {
      final previousHadHotPlatform = _hasHotKeywordPlatform(previous?.value);
      final nextHasHotPlatform = _hasHotKeywordPlatform(next.value);
      if (previousHadHotPlatform ||
          !nextHasHotPlatform ||
          !_shouldReloadHotKeywordsAfterPlatformLoad()) {
        return;
      }
      unawaited(_loadHotKeywords());
    });
    final config = ref.watch(appConfigProvider);
    final platformsAsync = ref.watch(onlinePlatformsProvider);
    final platforms = _resolvePlatforms(platformsAsync);
    final defaultPlaceholderState = ref.watch(searchDefaultPlaceholderProvider);
    _syncSelectedPlatform(platforms);

    final keyword = _searchController.text.trim();
    final effectiveKeyword = _effectiveSearchKeyword();
    final showHotPanel = effectiveKeyword.isEmpty;
    final showSuggestPanel =
        keyword.isNotEmpty &&
        (_showSuggestionPanel || _searchFocusNode.hasFocus);
    final cacheKey = _currentCacheKey();
    final likedSongKeys = ref.watch(
      favoriteSongStatusProvider.select((state) => state.songKeys),
    );
    final loading = cacheKey != null && _loadingCacheKeys.contains(cacheKey);
    final results = cacheKey == null
        ? const <Map<String, dynamic>>[]
        : (_searchResultCache[cacheKey] ?? const <Map<String, dynamic>>[]);
    final comprehensiveResult = cacheKey == null
        ? null
        : _comprehensiveResultCache[cacheKey];
    final error = cacheKey == null ? null : _searchErrorCache[cacheKey];
    final initialLoading = loading && results.isEmpty && error == null;
    final loadingMore =
        cacheKey != null && _loadingMoreCacheKeys.contains(cacheKey);
    final hasMore = cacheKey != null && (_hasMoreCache[cacheKey] ?? false);
    final loadingPlatforms =
        platformsAsync.isLoading && !platformsAsync.hasValue;
    final availableTypes = _availableSearchTypes(platforms);
    final defaultEntry = _searchFocusNode.hasFocus
        ? (_frozenPlaceholderEntry ?? defaultPlaceholderState.currentEntry)
        : defaultPlaceholderState.currentEntry;
    final searchPlaceholderPrimary = defaultEntry?.key.trim().isNotEmpty == true
        ? defaultEntry!.key.trim()
        : AppI18n.t(config, 'home.search');
    final searchPlaceholderSecondary =
        defaultEntry?.description.trim().isNotEmpty == true
        ? defaultEntry!.description.trim()
        : null;

    return DetailPageShell(
      resizeToAvoidBottomInset: false,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  LayoutTokens.compactPageGutter,
                  8,
                  LayoutTokens.compactPageGutter,
                  10,
                ),
                child: _SearchHeader(
                  onBack: () => context.appPopOrGo(),
                  controller: _searchController,
                  placeholderPrimary: searchPlaceholderPrimary,
                  placeholderSecondary: searchPlaceholderSecondary,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  onSubmit: _search,
                  onSearch: _search,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: LayoutTokens.compactPageGutter,
                  ),
                  child: showHotPanel
                      ? OnlineSearchHotPanel(
                          localeCode: config.localeCode,
                          historyKeywords: _searchHistoryKeywords,
                          hotKeywords: _hotKeywords,
                          loadingHistory: _loadingSearchHistory,
                          loadingHot: _loadingHotKeywords,
                          onTapKeyword: _onTapSuggestedKeyword,
                          onClearHistory: () =>
                              unawaited(_clearSearchHistory()),
                        )
                      : showSuggestPanel
                      ? OnlineSearchSuggestPanel(
                          loading: _loadingSuggestions,
                          suggestions: _suggestKeywords,
                          onTapKeyword: _onTapSuggestedKeyword,
                        )
                      : OnlineSearchResultPage(
                          localeCode: config.localeCode,
                          selectedType: _selectedType,
                          onTypeChanged: _onTypeChanged,
                          loadingPlatforms: loadingPlatforms,
                          platforms: platforms,
                          selectedPlatformId: _selectedPlatformId,
                          onPlatformChanged: _onPlatformChanged,
                          availableTypes: availableTypes,
                          loading: loading,
                          results: results,
                          comprehensiveResult: comprehensiveResult,
                          error: error,
                          initialLoading: initialLoading,
                          likedSongKeys: likedSongKeys,
                          onTapItem: (type, item) async {
                            if (type == SearchType.song) {
                              await _playSong(item);
                              return;
                            }
                            openSearchDetail(
                              context: context,
                              type: type,
                              item: item,
                              fallbackPlatformId: _selectedPlatformId,
                              localeCode: ref
                                  .read(appConfigProvider)
                                  .localeCode,
                              onError: AppMessageService.showWarning,
                            );
                          },
                          onLikeSongItem: _toggleSongLike,
                          onMoreSongItem: _showSongActions,
                          onMoreSection: _openMoreSection,
                          onLoadMore: _loadMore,
                          loadingMore: loadingMore,
                          hasMore: hasMore,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _searchFocusNode
      ..removeListener(_onSearchFocusChanged)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final resolved = _resolveSearchIntent();
    final config = ref.read(appConfigProvider);
    final keyword = resolved.keyword;
    if (keyword.isEmpty) {
      AppMessageService.showWarning(AppI18n.t(config, 'search.empty_keyword'));
      return;
    }
    if (!_ensureSelectedPlatformValid()) {
      AppMessageService.showWarning(AppI18n.t(config, 'search.no_platform'));
      return;
    }
    if (resolved.fillController) {
      _searchController.value = TextEditingValue(
        text: keyword,
        selection: TextSelection.collapsed(offset: keyword.length),
      );
    }
    _searchFocusNode.unfocus();
    if (_showSuggestionPanel) {
      setState(() {
        _showSuggestionPanel = false;
        _loadingSuggestions = false;
        _suggestKeywords = const <String>[];
      });
    }
    final cacheKey = _cacheKey(
      keyword: keyword,
      type: _selectedType,
      platformId: _selectedPlatformId,
    );
    if (_loadingCacheKeys.contains(cacheKey)) {
      return;
    }
    setState(() {
      _loadingCacheKeys.add(cacheKey);
      _searchErrorCache.remove(cacheKey);
    });
    try {
      if (_selectedType == SearchType.comprehensive) {
        final result = await ref
            .read(onlineSearchRepositoryProvider)
            .comprehensiveSearch(
              keyword: keyword,
              platform: _selectedPlatformId,
            );
        if (!mounted) {
          return;
        }
        setState(() {
          _activeSearchKeyword = keyword;
          _comprehensiveResultCache[cacheKey] = result;
          _hasMoreCache[cacheKey] = false;
          _searchErrorCache.remove(cacheKey);
        });
        await _appendSearchHistory(keyword);
        return;
      }
      final results = await ref
          .read(onlineSearchRepositoryProvider)
          .searchMusic(
            keyword: keyword,
            platform: _selectedPlatformId,
            type: _selectedType.apiType,
            pageIndex: 1,
            pageSize: _searchPageSize,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _activeSearchKeyword = keyword;
        _searchResultCache[cacheKey] = results;
        _nextPageCache[cacheKey] = 2;
        _hasMoreCache[cacheKey] = results.length >= _searchPageSize;
        _searchErrorCache.remove(cacheKey);
      });
      await _appendSearchHistory(keyword);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        if (!_searchResultCache.containsKey(cacheKey)) {
          _searchErrorCache[cacheKey] = '$error';
        }
      });
      _showErrorMessage('$error');
    } finally {
      if (mounted) {
        setState(() {
          _loadingCacheKeys.remove(cacheKey);
        });
      }
    }
  }

  _ResolvedSearchIntent _resolveSearchIntent() {
    final typed = _searchController.text.trim();
    if (typed.isNotEmpty) {
      return _ResolvedSearchIntent(keyword: typed, fillController: false);
    }
    final defaultEntry = ref
        .read(searchDefaultPlaceholderProvider)
        .currentEntry;
    final fallbackKeyword = defaultEntry?.key.trim() ?? '';
    return _ResolvedSearchIntent(
      keyword: fallbackKeyword,
      fillController: fallbackKeyword.isNotEmpty,
    );
  }

  Future<void> _searchIfKeywordPresent() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty || _showSuggestionPanel) {
      return;
    }
    if (!_ensureSelectedPlatformValid()) {
      return;
    }
    final cacheKey = _cacheKey(
      keyword: keyword,
      type: _selectedType,
      platformId: _selectedPlatformId,
    );
    final hasCachedResult = _selectedType == SearchType.comprehensive
        ? _comprehensiveResultCache.containsKey(cacheKey)
        : _searchResultCache.containsKey(cacheKey);
    if (hasCachedResult || _loadingCacheKeys.contains(cacheKey)) {
      return;
    }
    await _search();
  }

  Future<void> _loadMore() async {
    if (_selectedType == SearchType.comprehensive) {
      return;
    }
    final keyword = _effectiveSearchKeyword();
    final cacheKey = _currentCacheKey();
    if (keyword.isEmpty || cacheKey == null) {
      return;
    }
    if (!_ensureSelectedPlatformValid()) {
      return;
    }
    if (_loadingCacheKeys.contains(cacheKey) ||
        _loadingMoreCacheKeys.contains(cacheKey) ||
        !(_hasMoreCache[cacheKey] ?? false)) {
      return;
    }
    final currentResults = _searchResultCache[cacheKey];
    if (currentResults == null || currentResults.isEmpty) {
      return;
    }
    final pageIndex = _nextPageCache[cacheKey] ?? 2;
    setState(() => _loadingMoreCacheKeys.add(cacheKey));
    try {
      final nextList = await ref
          .read(onlineSearchRepositoryProvider)
          .searchMusic(
            keyword: keyword,
            platform: _selectedPlatformId,
            type: _selectedType.apiType,
            pageIndex: pageIndex,
            pageSize: _searchPageSize,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _searchResultCache[cacheKey] = <Map<String, dynamic>>[
          ...currentResults,
          ...nextList,
        ];
        _nextPageCache[cacheKey] = pageIndex + 1;
        _hasMoreCache[cacheKey] = nextList.length >= _searchPageSize;
      });
    } catch (error) {
      _showErrorMessage('$error');
    } finally {
      if (mounted) {
        setState(() => _loadingMoreCacheKeys.remove(cacheKey));
      }
    }
  }

  Future<void> _loadSearchHistory() async {
    try {
      final keywords = await ref
          .read(onlineSearchRepositoryProvider)
          .getSearchHistory();
      if (!mounted) {
        return;
      }
      setState(() {
        _searchHistoryKeywords = keywords;
        _loadingSearchHistory = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loadingSearchHistory = false);
    }
  }

  Future<void> _appendSearchHistory(String keyword) async {
    final next = await ref
        .read(onlineSearchRepositoryProvider)
        .saveSearchKeyword(keyword);
    if (!mounted) {
      return;
    }
    setState(() => _searchHistoryKeywords = next);
  }

  Future<void> _clearSearchHistory() async {
    await ref.read(onlineSearchRepositoryProvider).clearSearchHistory();
    if (!mounted) {
      return;
    }
    setState(() => _searchHistoryKeywords = const <String>[]);
  }

  Future<void> _loadHotKeywords() async {
    final platformId = _firstPlatformIdSupportingFeature(
      PlatformFeatureSupportFlag.getSearchHotkey,
    );
    if (platformId == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hotKeywords = _defaultHotKeywords;
        _loadingHotKeywords = false;
      });
      return;
    }
    final cached = ref
        .read(searchHotKeywordsCacheProvider.notifier)
        .getCached(platformId);
    if (cached != null && cached.keywords.isNotEmpty && mounted) {
      setState(() {
        _hotKeywords = cached.keywords;
        _loadingHotKeywords = false;
      });
    }
    try {
      final hot = await ref
          .read(searchHotKeywordsCacheProvider.notifier)
          .ensureKeywords(platformId);
      if (!mounted) {
        return;
      }
      setState(() {
        _hotKeywords = hot;
        _loadingHotKeywords = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _hotKeywords = _defaultHotKeywords;
        _loadingHotKeywords = false;
      });
    }
  }

  bool _shouldReloadHotKeywordsAfterPlatformLoad() {
    return !_loadingHotKeywords &&
        (_hotKeywords.isEmpty || _isDefaultHotKeywords(_hotKeywords));
  }

  bool _hasHotKeywordPlatform(List<OnlinePlatform>? platforms) {
    if (platforms == null || platforms.isEmpty) {
      return false;
    }
    return platforms.any(
      (platform) =>
          platform.available &&
          platform.supports(PlatformFeatureSupportFlag.getSearchHotkey),
    );
  }

  bool _isDefaultHotKeywords(List<String> values) {
    if (values.length != _defaultHotKeywords.length) {
      return false;
    }
    for (var index = 0; index < values.length; index++) {
      if (values[index] != _defaultHotKeywords[index]) {
        return false;
      }
    }
    return true;
  }

  void _onSearchChanged(String value) {
    final keyword = value.trim();
    if (keyword.isNotEmpty) {
      if (!_showSuggestionPanel) {
        setState(() => _showSuggestionPanel = true);
      }
      _scheduleLoadSuggestions(keyword);
      return;
    }
    _suggestDebounce?.cancel();
    setState(() {
      _showSuggestionPanel = false;
      _loadingSuggestions = false;
      _suggestKeywords = const <String>[];
      if (_activeSearchKeyword.isNotEmpty) {
        _activeSearchKeyword = '';
      }
    });
  }

  void _onSearchFocusChanged() {
    if (!mounted) {
      return;
    }
    final focused = _searchFocusNode.hasFocus;
    if (focused) {
      _frozenPlaceholderEntry = ref
          .read(searchDefaultPlaceholderProvider)
          .currentEntry;
    } else {
      _frozenPlaceholderEntry = null;
    }
    final shouldShowSuggestion = focused && !_showSuggestionPanel;
    setState(() {
      if (shouldShowSuggestion) {
        _showSuggestionPanel = true;
      }
    });
    if (_searchFocusNode.hasFocus) {
      final current = _searchController.text.trim();
      if (current.isNotEmpty) {
        _scheduleLoadSuggestions(current);
      }
      return;
    }
    _suggestDebounce?.cancel();
  }

  Future<void> _onTapSuggestedKeyword(String keyword) async {
    final normalized = keyword.trim();
    if (normalized.isEmpty) {
      return;
    }
    _searchController.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
    await _search();
  }

  void _scheduleLoadSuggestions(String keyword) {
    _suggestDebounce?.cancel();
    _suggestDebounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_loadSearchSuggestions(keyword));
    });
  }

  Future<void> _loadSearchSuggestions(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingSuggestions = true;
    });
    var suggested = const <String>[];
    final suggestPlatformId = _firstPlatformIdSupportingFeature(
      PlatformFeatureSupportFlag.getSearchSuggest,
    );
    if (suggestPlatformId != null) {
      try {
        suggested = await ref
            .read(onlineSearchRepositoryProvider)
            .fetchSearchSuggestions(
              keyword: query,
              platform: suggestPlatformId,
            );
      } catch (_) {
        suggested = const <String>[];
      }
    }
    if (!mounted) {
      return;
    }
    if (_searchController.text.trim() != query) {
      return;
    }
    final local = _localSuggestions(query);
    final merged = <String>[...suggested, ...local];
    final deduped = <String>[];
    for (final item in merged) {
      final trimmed = item.trim();
      if (trimmed.isEmpty || deduped.contains(trimmed)) {
        continue;
      }
      deduped.add(trimmed);
    }
    setState(() {
      _loadingSuggestions = false;
      _suggestKeywords = deduped.take(18).toList(growable: false);
    });
  }

  List<String> _localSuggestions(String keyword) {
    final query = keyword.toLowerCase();
    final source = <String>[..._searchHistoryKeywords, ..._hotKeywords];
    return source
        .where((value) => value.toLowerCase().contains(query))
        .toList(growable: false);
  }

  void _showSongActions(Map<String, dynamic> item) {
    final platform = resolveSearchPlatform(item, _selectedPlatformId);
    final song = searchSongInfo(item);
    final artists = song.artists;
    final albumId = song.album?.id.trim() ?? '';
    final albumTitle = song.album?.name.trim() ?? '';
    final config = ref.read(appConfigProvider);
    final platforms =
        ref.read(onlinePlatformsProvider).value ?? const <OnlinePlatform>[];
    final canViewAlbum =
        hasValidAlbumId(albumId) &&
        platformSupportsAlbumDetail(platformId: platform, platforms: platforms);
    final artistActionLabel =
        platformSupportsArtistDetail(platformId: platform, platforms: platforms)
        ? songArtistActionLabel(artists, localeCode: config.localeCode)
        : null;
    final canViewComment = platformSupportsSongComment(
      platformId: platform,
      platforms: platforms,
    );
    final qualities = buildDownloadQualityOptions(
      links: song.links,
      qualityDescriptions: _platformQualityDescriptions(platform, platforms),
    );
    final coverUrl = resolveSongCoverUrl(
      baseUrl: config.apiBaseUrl,
      token: config.authToken ?? '',
      platforms: platforms,
      platformId: platform,
      songId: text(item['id']),
      cover: text(item['cover']) == '-' ? '' : text(item['cover']),
      size: 300,
    );
    showSearchSongActions(
      context: context,
      song: item,
      coverUrl: coverUrl.isEmpty ? null : coverUrl,
      hasMv: songHasMv(item),
      sourceLabel: AppI18n.format(config, 'song.source', <String, String>{
        'platform': resolvePlatformLabel(platform, platforms: platforms),
      }),
      onPlay: () => unawaited(_playSong(item)),
      onPlayNext: () => unawaited(_queuePlayNext(item)),
      onAddToPlaylist: () => unawaited(_appendToQueue(item)),
      onDownload: platform.trim().toLowerCase() == 'local' || qualities.isEmpty
          ? null
          : () => unawaited(
              _downloadSongFromSearch(
                item: item,
                song: song,
                artworkUrl: coverUrl.isEmpty ? null : coverUrl,
                qualities: qualities,
              ),
            ),
      onAddToUserPlaylist: () => unawaited(_addToUserPlaylist(item)),
      onWatchMv: () => openSearchSongMvDetail(
        context: context,
        item: item,
        fallbackPlatformId: _selectedPlatformId,
        localeCode: config.localeCode,
        onError: AppMessageService.showWarning,
      ),
      onViewDetail:
          canOpenSongDetail(
            songId: song.id,
            platformId: platform,
            platforms: platforms,
          )
          ? () => openSongDetailPage(
              context: context,
              songId: song.id,
              platformId: platform,
              title: song.title,
            )
          : null,
      onViewComment: canViewComment ? () => _openCommentPage(item) : null,
      albumActionLabel: canViewAlbum
          ? AppI18n.t(config, 'player.action.view_album')
          : null,
      onViewAlbum: canViewAlbum
          ? () => _openAlbumDetail(
              albumId: albumId,
              platformId: platform,
              albumTitle: albumTitle,
            )
          : null,
      artistActionLabel: artistActionLabel,
      onViewArtists: artistActionLabel == null
          ? null
          : () => unawaited(
              openSongArtistSelection(
                context: context,
                platformId: platform,
                artists: artists,
                onError: AppMessageService.showWarning,
              ),
            ),
      onCopySongName: () => unawaited(
        copySearchSongName(
          item: item,
          localeCode: config.localeCode,
          onError: AppMessageService.showWarning,
          onSuccess: AppMessageService.showSuccess,
        ),
      ),
      onCopySongShareLink: () => unawaited(
        copySearchSongShareLink(
          item: item,
          fallbackPlatformId: _selectedPlatformId,
          localeCode: config.localeCode,
          onError: AppMessageService.showWarning,
          onSuccess: AppMessageService.showSuccess,
        ),
      ),
      onSearchSameName: () => unawaited(
        searchBySameSongName(
          item: item,
          controller: _searchController,
          onSearch: _search,
          localeCode: config.localeCode,
          onError: AppMessageService.showWarning,
        ),
      ),
      onCopySongId: () => unawaited(
        copySearchSongId(
          item: item,
          localeCode: config.localeCode,
          onError: AppMessageService.showWarning,
          onSuccess: AppMessageService.showSuccess,
        ),
      ),
    );
  }

  Future<void> _downloadSongFromSearch({
    required Map<String, dynamic> item,
    required SongInfo song,
    required String? artworkUrl,
    required List<PlayerQualityOption> qualities,
  }) async {
    final platform = resolveSearchPlatform(item, _selectedPlatformId);
    final config = ref.read(appConfigProvider);
    final selected = await showDownloadQualitySheet(
      context: context,
      qualities: qualities,
      selectedQualityName: qualities.first.name,
    );
    if (selected == null) {
      return;
    }
    try {
      await ref
          .read(downloadControllerProvider.notifier)
          .enqueue(
            title: song.title,
            quality: DownloadTaskQuality(
              label: selected.name,
              bitrate: selected.quality.toDouble(),
              fileExtension: selected.format.trim().toLowerCase(),
            ),
            songId: song.id,
            platform: platform,
            artist: song.artist,
            album: song.album?.name,
            artworkUrl: artworkUrl,
          );
      AppMessageService.showSuccess(
        AppI18n.format(config, 'player.download.added', <String, String>{
          'title': song.title,
        }),
      );
    } catch (_) {
      AppMessageService.showError(AppI18n.t(config, 'player.download.failed'));
    }
  }

  Map<String, String> _platformQualityDescriptions(
    String platformId,
    List<OnlinePlatform> platforms,
  ) {
    for (final platform in platforms) {
      if (platform.id == platformId) {
        return platform.qualities;
      }
    }
    return const <String, String>{};
  }

  Future<void> _toggleSongLike(Map<String, dynamic> item) async {
    final songId = text(item['id']);
    final platform = resolveSearchPlatform(item, _selectedPlatformId);
    final liked = ref.read(
      favoriteSongStatusProvider.select(
        (state) => state.songKeys.contains('$songId|$platform'),
      ),
    );
    try {
      await ref
          .read(onlineControllerProvider.notifier)
          .toggleSongFavorite(songId: songId, platform: platform, like: !liked);
    } catch (error) {
      _showErrorMessage('$error');
    }
  }

  void _openAlbumDetail({
    required String albumId,
    required String platformId,
    required String albumTitle,
  }) {
    final uri = Uri(
      path: AppRoutes.albumDetail,
      queryParameters: <String, String>{
        'id': albumId,
        'platform': platformId,
        'title': albumTitle.isEmpty
            ? AppI18n.t(ref.read(appConfigProvider), 'album.fallback_title')
            : albumTitle,
      },
    );
    context.push(uri.toString());
  }

  void _openCommentPage(Map<String, dynamic> item) {
    final id = text(item['id']);
    if (id == '-') {
      AppMessageService.showWarning(
        AppI18n.t(ref.read(appConfigProvider), 'search.invalid_song'),
      );
      return;
    }
    final platform = resolveSearchPlatform(item, _selectedPlatformId);
    if (!_platformSupportsFeature(
      platformId: platform,
      featureFlag: PlatformFeatureSupportFlag.getCommentList,
    )) {
      AppMessageService.showWarning(
        AppI18n.t(ref.read(appConfigProvider), 'search.comment_unsupported'),
      );
      return;
    }
    final uri = Uri(
      path: AppRoutes.onlineComments,
      queryParameters: <String, String>{
        'id': id,
        'resource_type': 'song',
        'platform': platform,
        'title': songTitle(item),
      },
    );
    context.push(uri.toString());
  }

  Future<void> _playSong(Map<String, dynamic> item) async {
    try {
      final track = await _buildPlayerTrack(item);
      await ref
          .read(playerControllerProvider.notifier)
          .insertNextAndPlay(track);
    } catch (error) {
      _showErrorMessage('$error');
    }
  }

  Future<void> _queuePlayNext(Map<String, dynamic> item) async {
    try {
      final track = await _buildPlayerTrack(item);
      await ref.read(playerControllerProvider.notifier).insertNextTrack(track);
      AppMessageService.showSuccess(
        AppI18n.t(ref.read(appConfigProvider), 'search.queue.next_added'),
      );
    } catch (error) {
      _showErrorMessage('$error');
    }
  }

  Future<void> _appendToQueue(Map<String, dynamic> item) async {
    try {
      final track = await _buildPlayerTrack(item);
      await ref.read(playerControllerProvider.notifier).appendTrack(track);
      AppMessageService.showSuccess(
        AppI18n.t(ref.read(appConfigProvider), 'search.queue.appended'),
      );
    } catch (error) {
      _showErrorMessage('$error');
    }
  }

  Future<void> _addToUserPlaylist(Map<String, dynamic> item) async {
    final song = searchSongInfo(item);
    final id = _safeValue(song.id);
    if (id == '-') {
      AppMessageService.showWarning(
        AppI18n.t(ref.read(appConfigProvider), 'search.invalid_song'),
      );
      return;
    }
    await addSingleSongToUserPlaylist(
      context: context,
      ref: ref,
      song: IdPlatformInfo(
        id: id,
        platform: resolveSearchPlatform(item, _selectedPlatformId),
      ),
    );
  }

  Future<PlayerTrack> _buildPlayerTrack(Map<String, dynamic> item) async {
    final song = searchSongInfo(item);
    final id = _safeValue(song.id);
    final platform = resolveSearchPlatform(item, _selectedPlatformId);
    if (id == '-') {
      throw StateError(
        AppI18n.t(ref.read(appConfigProvider), 'search.invalid_song'),
      );
    }
    return PlayerTrack(
      id: id,
      title: _safeValue(song.name),
      links: song.links,
      artist: song.artist,
      album: song.album?.name.trim().isEmpty ?? true ? null : song.album?.name,
      albumId: song.album?.id.trim().isEmpty ?? true ? null : song.album?.id,
      artists: song.artists,
      mvId: song.mvId,
      artworkUrl: () {
        final config = ref.read(appConfigProvider);
        final platforms =
            ref.read(onlinePlatformsProvider).value ?? const <OnlinePlatform>[];
        final resolved = resolveSongCoverUrl(
          baseUrl: config.apiBaseUrl,
          token: config.authToken ?? '',
          platforms: platforms,
          platformId: platform,
          songId: id,
          cover: song.cover,
          size: maxCoverSize,
        );
        return resolved.isEmpty ? null : resolved;
      }(),
      platform: platform,
    );
  }

  String _safeValue(String value) {
    final text = value.trim();
    if (text.isEmpty) {
      return '-';
    }
    return text;
  }

  void _showErrorMessage(String message) =>
      AppMessageService.showError(message);

  String _cacheKey({
    required String keyword,
    required SearchType type,
    required String platformId,
  }) {
    return '${keyword.toLowerCase()}|${type.apiType}|$platformId';
  }

  String? _currentCacheKey() {
    final keyword = _effectiveSearchKeyword();
    if (keyword.isEmpty) {
      return null;
    }
    return _cacheKey(
      keyword: keyword,
      type: _selectedType,
      platformId: _selectedPlatformId,
    );
  }

  String _effectiveSearchKeyword() {
    final typed = _searchController.text.trim();
    if (typed.isNotEmpty) {
      return typed;
    }
    return _activeSearchKeyword;
  }

  List<SearchPlatform> _resolvePlatforms(
    AsyncValue<List<OnlinePlatform>> platformsAsync,
  ) {
    final allPlatforms = platformsAsync.value;
    if (allPlatforms == null) {
      return <SearchPlatform>[
        SearchPlatform(
          id: _selectedPlatformId,
          label: _selectedPlatformId,
          available: true,
          featureSupportFlag: _selectedType.requiredPlatformFeatureFlag,
        ),
      ];
    }
    final availablePlatforms = _featureFilteredPlatforms(
      allPlatforms: allPlatforms,
      type: _selectedType,
    );
    if (availablePlatforms.isEmpty) {
      return const <SearchPlatform>[];
    }
    final parsed = availablePlatforms
        .map<SearchPlatform>(SearchPlatform.fromOnlinePlatform)
        .toList(growable: false);
    return parsed;
  }

  void _syncSelectedPlatform(List<SearchPlatform> platforms) {
    final exists = platforms.any((p) => p.id == _selectedPlatformId);
    if (platforms.isEmpty) {
      return;
    }
    final preferredType = _preferredSearchTypeForPlatforms(platforms);
    if (_selectedType != preferredType &&
        widget.initialType == null &&
        _effectiveSearchKeyword().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selectedType == preferredType) {
          return;
        }
        setState(() => _selectedType = preferredType);
      });
    }
    if (exists) {
      return;
    }
    final fallbackId = platforms.first.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedPlatformId == fallbackId) {
        return;
      }
      setState(() => _selectedPlatformId = fallbackId);
    });
  }

  void _onTypeChanged(SearchType type) {
    setState(() {
      _selectedType = type;
      _ensureSelectedPlatformValid(rebuild: false);
    });
    unawaited(_searchIfKeywordPresent());
  }

  void _onPlatformChanged(String platformId) {
    setState(() {
      _selectedPlatformId = platformId;
      _loadingHotKeywords = true;
    });
    unawaited(_loadHotKeywords());
    unawaited(_searchIfKeywordPresent());
  }

  List<OnlinePlatform> _featureFilteredPlatforms({
    required List<OnlinePlatform>? allPlatforms,
    required SearchType type,
  }) {
    if (allPlatforms == null || allPlatforms.isEmpty) {
      return const <OnlinePlatform>[];
    }
    final requiredFeature = type.requiredPlatformFeatureFlag;
    return allPlatforms
        .where(
          (platform) =>
              platform.available && platform.supports(requiredFeature),
        )
        .toList(growable: false);
  }

  List<SearchType> _availableSearchTypes(List<SearchPlatform> platforms) {
    const ordered = <SearchType>[
      SearchType.comprehensive,
      SearchType.song,
      SearchType.playlist,
      SearchType.album,
      SearchType.artist,
      SearchType.video,
    ];
    if (platforms.isEmpty) {
      return ordered.where((type) => type != SearchType.comprehensive).toList();
    }
    return ordered
        .where(
          (type) => platforms.any(
            (platform) => platform.supports(type.requiredPlatformFeatureFlag),
          ),
        )
        .toList(growable: false);
  }

  SearchType _preferredSearchTypeForPlatforms(List<SearchPlatform> platforms) {
    final availableTypes = _availableSearchTypes(platforms);
    if (availableTypes.contains(SearchType.comprehensive)) {
      return SearchType.comprehensive;
    }
    if (availableTypes.contains(SearchType.song)) {
      return SearchType.song;
    }
    return availableTypes.isEmpty ? SearchType.song : availableTypes.first;
  }

  void _openMoreSection(SearchType type) {
    setState(() {
      _selectedType = type;
      _ensureSelectedPlatformValid(rebuild: false);
    });
    unawaited(_searchIfKeywordPresent());
  }

  bool _ensureSelectedPlatformValid({bool rebuild = true}) {
    final allPlatforms = ref.read(onlinePlatformsProvider).value;
    if (allPlatforms == null) {
      return true;
    }
    final filtered = _featureFilteredPlatforms(
      allPlatforms: allPlatforms,
      type: _selectedType,
    );
    if (filtered.isEmpty) {
      return false;
    }
    final exists = filtered.any(
      (platform) => platform.id == _selectedPlatformId,
    );
    if (exists) {
      return true;
    }
    final fallbackId = filtered.first.id;
    if (fallbackId == _selectedPlatformId) {
      return true;
    }
    if (rebuild && mounted) {
      setState(() => _selectedPlatformId = fallbackId);
    } else {
      _selectedPlatformId = fallbackId;
    }
    return true;
  }

  bool _platformSupportsFeature({
    required String platformId,
    required BigInt featureFlag,
  }) {
    final allPlatforms = ref.read(onlinePlatformsProvider).value;
    if (allPlatforms == null || allPlatforms.isEmpty) {
      return true;
    }
    for (final platform in allPlatforms) {
      if (platform.id != platformId) {
        continue;
      }
      return platform.available && platform.supports(featureFlag);
    }
    return false;
  }

  String? _firstPlatformIdSupportingFeature(BigInt featureFlag) {
    final allPlatforms = ref.read(onlinePlatformsProvider).value;
    if (allPlatforms == null || allPlatforms.isEmpty) {
      return null;
    }
    for (final platform in allPlatforms) {
      if (platform.available && platform.supports(featureFlag)) {
        return platform.id;
      }
    }
    return null;
  }
}

class _ResolvedSearchIntent {
  const _ResolvedSearchIntent({
    required this.keyword,
    required this.fillController,
  });

  final String keyword;
  final bool fillController;
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.onBack,
    required this.controller,
    required this.placeholderPrimary,
    required this.onSubmit,
    required this.onChanged,
    required this.onSearch,
    this.placeholderSecondary,
    this.focusNode,
  });

  final VoidCallback onBack;
  final TextEditingController controller;
  final String placeholderPrimary;
  final String? placeholderSecondary;
  final Future<void> Function() onSubmit;
  final ValueChanged<String> onChanged;
  final Future<void> Function() onSearch;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        AppBackButton(onPressed: onBack),
        Expanded(
          child: SearchTopBox(
            controller: controller,
            placeholderPrimary: placeholderPrimary,
            placeholderSecondary: placeholderSecondary,
            focusNode: focusNode,
            onChanged: onChanged,
            onSubmit: onSubmit,
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.72,
          ),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onSearch,
            borderRadius: BorderRadius.circular(14),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Icon(Icons.arrow_forward_rounded, size: 18),
            ),
          ),
        ),
      ],
    );
  }
}
