import '../../../../shared/models/he_music_models.dart';
import 'playlist_category_group.dart';

class PlaylistPlazaState {
  const PlaylistPlazaState({
    required this.selectedPlatformId,
    required this.categoriesLoading,
    required this.playlistsLoading,
    required this.loadingMore,
    required this.categoryGroups,
    required this.selectedCategoryId,
    required this.playlists,
    required this.hasMore,
    required this.pageIndex,
    required this.lastId,
    this.categoriesErrorMessage,
    this.playlistsErrorMessage,
  });

  final String? selectedPlatformId;
  final bool categoriesLoading;
  final bool playlistsLoading;
  final bool loadingMore;
  final List<PlaylistCategoryGroup> categoryGroups;
  final String? selectedCategoryId;
  final List<PlaylistInfo> playlists;
  final bool hasMore;
  final int pageIndex;
  final String lastId;
  final String? categoriesErrorMessage;
  final String? playlistsErrorMessage;

  List<CategoryInfo> get allCategories {
    return categoryGroups
        .expand((group) => group.categories)
        .toList(growable: false);
  }

  PlaylistPlazaState copyWith({
    String? selectedPlatformId,
    bool? categoriesLoading,
    bool? playlistsLoading,
    bool? loadingMore,
    List<PlaylistCategoryGroup>? categoryGroups,
    String? selectedCategoryId,
    List<PlaylistInfo>? playlists,
    bool? hasMore,
    int? pageIndex,
    String? lastId,
    String? categoriesErrorMessage,
    String? playlistsErrorMessage,
    bool clearCategoriesError = false,
    bool clearPlaylistsError = false,
  }) {
    return PlaylistPlazaState(
      selectedPlatformId: selectedPlatformId ?? this.selectedPlatformId,
      categoriesLoading: categoriesLoading ?? this.categoriesLoading,
      playlistsLoading: playlistsLoading ?? this.playlistsLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      categoryGroups: categoryGroups ?? this.categoryGroups,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      playlists: playlists ?? this.playlists,
      hasMore: hasMore ?? this.hasMore,
      pageIndex: pageIndex ?? this.pageIndex,
      lastId: lastId ?? this.lastId,
      categoriesErrorMessage: clearCategoriesError
          ? null
          : categoriesErrorMessage ?? this.categoriesErrorMessage,
      playlistsErrorMessage: clearPlaylistsError
          ? null
          : playlistsErrorMessage ?? this.playlistsErrorMessage,
    );
  }

  static const initial = PlaylistPlazaState(
    selectedPlatformId: null,
    categoriesLoading: false,
    playlistsLoading: false,
    loadingMore: false,
    categoryGroups: <PlaylistCategoryGroup>[],
    selectedCategoryId: null,
    playlists: <PlaylistInfo>[],
    hasMore: false,
    pageIndex: 1,
    lastId: '',
  );
}
