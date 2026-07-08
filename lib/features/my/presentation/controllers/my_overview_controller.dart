import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/my_overview_state.dart';
import '../../domain/repositories/my_overview_repository.dart';
import '../providers/my_overview_providers.dart';

class MyOverviewController extends Notifier<MyOverviewState> {
  bool _initialized = false;

  @override
  MyOverviewState build() {
    return MyOverviewState.initial;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    await refresh();
    _initialized = true;
  }

  void clear() {
    _initialized = false;
    state = MyOverviewState.initial;
  }

  Future<void> refresh() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final overview = await _repository.fetchOverview();
      state = state.copyWith(
        loading: false,
        overview: overview,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(loading: false, errorMessage: '$error');
    }
  }

  MyOverviewRepository get _repository {
    return ref.read(myOverviewRepositoryProvider);
  }
}
