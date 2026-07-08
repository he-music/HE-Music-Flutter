import 'home_discover_section.dart';
import 'home_platform.dart';

class HomeDiscoverState {
  const HomeDiscoverState({
    required this.loading,
    required this.platforms,
    required this.selectedPlatformId,
    required this.sections,
    this.errorMessage,
  });

  final bool loading;
  final List<HomePlatform> platforms;
  final String? selectedPlatformId;
  final List<HomeDiscoverSection> sections;
  final String? errorMessage;

  HomeDiscoverState copyWith({
    bool? loading,
    List<HomePlatform>? platforms,
    String? selectedPlatformId,
    List<HomeDiscoverSection>? sections,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HomeDiscoverState(
      loading: loading ?? this.loading,
      platforms: platforms ?? this.platforms,
      selectedPlatformId: selectedPlatformId ?? this.selectedPlatformId,
      sections: sections ?? this.sections,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  static const initial = HomeDiscoverState(
    loading: false,
    platforms: <HomePlatform>[],
    selectedPlatformId: null,
    sections: <HomeDiscoverSection>[],
  );
}
