import '../../../online/domain/entities/online_platform.dart';
import 'home_page_section.dart';

enum HomePageKind { recommend, discover }

class HomeContentState {
  const HomeContentState({
    required this.initialized,
    required this.loading,
    required this.refreshing,
    required this.loadingMore,
    required this.selectedPlatformId,
    required this.sections,
    required this.hasMore,
    required this.nextPageIndex,
    this.errorMessage,
    this.loadMoreErrorMessage,
  });

  final bool initialized;
  final bool loading;
  final bool refreshing;
  final bool loadingMore;
  final String? selectedPlatformId;
  final List<HomePageSection> sections;
  final bool hasMore;
  final int nextPageIndex;
  final String? errorMessage;
  final String? loadMoreErrorMessage;

  HomeContentState copyWith({
    bool? initialized,
    bool? loading,
    bool? refreshing,
    bool? loadingMore,
    String? selectedPlatformId,
    List<HomePageSection>? sections,
    bool? hasMore,
    int? nextPageIndex,
    String? errorMessage,
    String? loadMoreErrorMessage,
    bool clearSelectedPlatform = false,
    bool clearError = false,
    bool clearLoadMoreError = false,
  }) {
    return HomeContentState(
      initialized: initialized ?? this.initialized,
      loading: loading ?? this.loading,
      refreshing: refreshing ?? this.refreshing,
      loadingMore: loadingMore ?? this.loadingMore,
      selectedPlatformId: clearSelectedPlatform
          ? null
          : selectedPlatformId ?? this.selectedPlatformId,
      sections: sections ?? this.sections,
      hasMore: hasMore ?? this.hasMore,
      nextPageIndex: nextPageIndex ?? this.nextPageIndex,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      loadMoreErrorMessage: clearLoadMoreError
          ? null
          : loadMoreErrorMessage ?? this.loadMoreErrorMessage,
    );
  }

  static const initial = HomeContentState(
    initialized: false,
    loading: false,
    refreshing: false,
    loadingMore: false,
    selectedPlatformId: null,
    sections: <HomePageSection>[],
    hasMore: false,
    nextPageIndex: 1,
  );
}

class HomePageState {
  const HomePageState({
    required this.platforms,
    required this.selectedPage,
    required this.recommend,
    required this.discover,
    this.platformErrorMessage,
  });

  final List<OnlinePlatform> platforms;
  final HomePageKind selectedPage;
  final HomeContentState recommend;
  final HomeContentState discover;
  final String? platformErrorMessage;

  List<HomePageKind> get availablePages {
    final result = <HomePageKind>[];
    if (platformsFor(HomePageKind.recommend).isNotEmpty) {
      result.add(HomePageKind.recommend);
    }
    if (platformsFor(HomePageKind.discover).isNotEmpty) {
      result.add(HomePageKind.discover);
    }
    return result;
  }

  List<OnlinePlatform> platformsFor(HomePageKind page) {
    final flag = page == HomePageKind.recommend
        ? PlatformFeatureSupportFlag.getRecommendPage
        : PlatformFeatureSupportFlag.getDiscoverPage;
    return platforms
        .where((platform) => platform.available && platform.supports(flag))
        .toList(growable: false);
  }

  HomeContentState contentFor(HomePageKind page) {
    return page == HomePageKind.recommend ? recommend : discover;
  }

  HomePageState replaceContent(HomePageKind page, HomeContentState content) {
    return copyWith(
      recommend: page == HomePageKind.recommend ? content : recommend,
      discover: page == HomePageKind.discover ? content : discover,
    );
  }

  HomePageState copyWith({
    List<OnlinePlatform>? platforms,
    HomePageKind? selectedPage,
    HomeContentState? recommend,
    HomeContentState? discover,
    String? platformErrorMessage,
    bool clearPlatformError = false,
  }) {
    return HomePageState(
      platforms: platforms ?? this.platforms,
      selectedPage: selectedPage ?? this.selectedPage,
      recommend: recommend ?? this.recommend,
      discover: discover ?? this.discover,
      platformErrorMessage: clearPlatformError
          ? null
          : platformErrorMessage ?? this.platformErrorMessage,
    );
  }

  static const initial = HomePageState(
    platforms: <OnlinePlatform>[],
    selectedPage: HomePageKind.recommend,
    recommend: HomeContentState.initial,
    discover: HomeContentState.initial,
  );
}
