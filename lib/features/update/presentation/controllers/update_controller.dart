import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/update_state.dart';
import '../../domain/entities/update_version.dart';
import '../providers/update_providers.dart';

class UpdateController extends Notifier<UpdateState> {
  @override
  UpdateState build() {
    return UpdateState.initial;
  }

  Future<void> checkForUpdates() async {
    state = state.copyWith(
      status: UpdateStatus.checking,
      clearError: true,
      clearRelease: true,
    );
    try {
      final appInfo = await ref.read(currentAppInfoProvider.future);
      final result = await ref
          .read(updateRepositoryProvider)
          .checkForUpdates(
            currentVersion: UpdateVersion.parse(appInfo.version),
          );
      if (result.isAvailable && result.release != null) {
        state = state.copyWith(
          status: UpdateStatus.available,
          release: result.release,
          clearError: true,
        );
        return;
      }
      state = state.copyWith(
        status: UpdateStatus.latest,
        clearError: true,
        clearRelease: true,
      );
    } catch (error) {
      state = state.copyWith(
        status: UpdateStatus.failure,
        errorMessage: '$error',
        clearRelease: true,
      );
    }
  }

  void resetStatus() {
    state = state.copyWith(
      status: UpdateStatus.idle,
      clearError: true,
      clearRelease: true,
    );
  }
}
