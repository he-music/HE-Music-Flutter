import '../../../../online/domain/entities/online_platform.dart';
import '../../../../../shared/models/he_music_models.dart';
import '../../../shared/domain/entities/new_release_tab.dart';

class NewSongPageState {
  const NewSongPageState({
    required this.platforms,
    required this.selectedPlatformId,
    required this.tabsLoading,
    required this.songsLoading,
    required this.loadingMore,
    required this.tabs,
    required this.selectedTabId,
    required this.songs,
    required this.hasMore,
    required this.pageIndex,
    this.tabsErrorMessage,
    this.songsErrorMessage,
  });

  final List<OnlinePlatform> platforms;
  final String? selectedPlatformId;
  final bool tabsLoading;
  final bool songsLoading;
  final bool loadingMore;
  final List<NewReleaseTab> tabs;
  final String? selectedTabId;
  final List<SongInfo> songs;
  final bool hasMore;
  final int pageIndex;
  final String? tabsErrorMessage;
  final String? songsErrorMessage;

  NewSongPageState copyWith({
    List<OnlinePlatform>? platforms,
    String? selectedPlatformId,
    bool? tabsLoading,
    bool? songsLoading,
    bool? loadingMore,
    List<NewReleaseTab>? tabs,
    String? selectedTabId,
    List<SongInfo>? songs,
    bool? hasMore,
    int? pageIndex,
    String? tabsErrorMessage,
    String? songsErrorMessage,
    bool clearTabsError = false,
    bool clearSongsError = false,
  }) {
    return NewSongPageState(
      platforms: platforms ?? this.platforms,
      selectedPlatformId: selectedPlatformId ?? this.selectedPlatformId,
      tabsLoading: tabsLoading ?? this.tabsLoading,
      songsLoading: songsLoading ?? this.songsLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      tabs: tabs ?? this.tabs,
      selectedTabId: selectedTabId ?? this.selectedTabId,
      songs: songs ?? this.songs,
      hasMore: hasMore ?? this.hasMore,
      pageIndex: pageIndex ?? this.pageIndex,
      tabsErrorMessage: clearTabsError
          ? null
          : tabsErrorMessage ?? this.tabsErrorMessage,
      songsErrorMessage: clearSongsError
          ? null
          : songsErrorMessage ?? this.songsErrorMessage,
    );
  }

  static const initial = NewSongPageState(
    platforms: <OnlinePlatform>[],
    selectedPlatformId: null,
    tabsLoading: false,
    songsLoading: false,
    loadingMore: false,
    tabs: <NewReleaseTab>[],
    selectedTabId: null,
    songs: <SongInfo>[],
    hasMore: false,
    pageIndex: 1,
  );
}
