import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../domain/entities/my_overview_state.dart';
import '../../domain/repositories/my_overview_repository.dart';
import '../providers/my_overview_providers.dart';

class MyOverviewController extends Notifier<MyOverviewState> {
  bool _initialized = false;
  int _generation = 0;

  @override
  MyOverviewState build() {
    ref.watch(authSessionRevisionProvider);
    ref.watch(appConfigProvider.select((config) => config.apiBaseUrl));
    _generation++;
    _initialized = false;
    return MyOverviewState.initial;
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    final generation = _generation + 1;
    await refresh();
    if (ref.mounted && generation == _generation) _initialized = true;
  }

  void clear() {
    _generation++;
    _initialized = false;
    state = MyOverviewState.initial;
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final overview = await _repository.fetchOverview();
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(
        loading: false,
        overview: overview,
        clearError: true,
      );
    } catch (error) {
      if (!ref.mounted || generation != _generation) return;
      state = state.copyWith(loading: false, errorMessage: '$error');
    }
  }

  MyOverviewRepository get _repository {
    return ref.read(myOverviewRepositoryProvider);
  }
}
