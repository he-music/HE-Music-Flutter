import '../../../../online/domain/entities/online_platform.dart';
import '../../../../../shared/models/he_music_models.dart';
import '../../../shared/domain/entities/new_release_tab.dart';

class NewAlbumPageState {
  const NewAlbumPageState({
    required this.platforms,
    required this.selectedPlatformId,
    required this.tabsLoading,
    required this.albumsLoading,
    required this.loadingMore,
    required this.tabs,
    required this.selectedTabId,
    required this.albums,
    required this.hasMore,
    required this.pageIndex,
    this.tabsErrorMessage,
    this.albumsErrorMessage,
  });

  final List<OnlinePlatform> platforms;
  final String? selectedPlatformId;
  final bool tabsLoading;
  final bool albumsLoading;
  final bool loadingMore;
  final List<NewReleaseTab> tabs;
  final String? selectedTabId;
  final List<AlbumInfo> albums;
  final bool hasMore;
  final int pageIndex;
  final String? tabsErrorMessage;
  final String? albumsErrorMessage;

  NewAlbumPageState copyWith({
    List<OnlinePlatform>? platforms,
    String? selectedPlatformId,
    bool? tabsLoading,
    bool? albumsLoading,
    bool? loadingMore,
    List<NewReleaseTab>? tabs,
    String? selectedTabId,
    List<AlbumInfo>? albums,
    bool? hasMore,
    int? pageIndex,
    String? tabsErrorMessage,
    String? albumsErrorMessage,
    bool clearTabsError = false,
    bool clearAlbumsError = false,
  }) {
    return NewAlbumPageState(
      platforms: platforms ?? this.platforms,
      selectedPlatformId: selectedPlatformId ?? this.selectedPlatformId,
      tabsLoading: tabsLoading ?? this.tabsLoading,
      albumsLoading: albumsLoading ?? this.albumsLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      tabs: tabs ?? this.tabs,
      selectedTabId: selectedTabId ?? this.selectedTabId,
      albums: albums ?? this.albums,
      hasMore: hasMore ?? this.hasMore,
      pageIndex: pageIndex ?? this.pageIndex,
      tabsErrorMessage: clearTabsError
          ? null
          : tabsErrorMessage ?? this.tabsErrorMessage,
      albumsErrorMessage: clearAlbumsError
          ? null
          : albumsErrorMessage ?? this.albumsErrorMessage,
    );
  }

  static const initial = NewAlbumPageState(
    platforms: <OnlinePlatform>[],
    selectedPlatformId: null,
    tabsLoading: false,
    albumsLoading: false,
    loadingMore: false,
    tabs: <NewReleaseTab>[],
    selectedTabId: null,
    albums: <AlbumInfo>[],
    hasMore: false,
    pageIndex: 1,
  );
}
