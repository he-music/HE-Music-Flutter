import 'my_overview.dart';

class MyOverviewState {
  const MyOverviewState({
    required this.loading,
    this.overview,
    this.errorMessage,
  });

  final bool loading;
  final MyOverview? overview;
  final String? errorMessage;

  MyOverviewState copyWith({
    bool? loading,
    MyOverview? overview,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MyOverviewState(
      loading: loading ?? this.loading,
      overview: overview ?? this.overview,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  static const initial = MyOverviewState(loading: false);
}
