import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_check_result.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_current_app_info.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_release.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_state.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_version.dart';
import 'package:he_music_flutter/features/update/domain/repositories/update_repository.dart';
import 'package:he_music_flutter/features/update/presentation/providers/update_providers.dart';

void main() {
  test('checkForUpdates exposes available release', () async {
    final container = ProviderContainer(
      overrides: [
        updateRepositoryProvider.overrideWithValue(
          _FakeUpdateRepository.available(),
        ),
        currentAppInfoProvider.overrideWith(
          (ref) async => const UpdateCurrentAppInfo(
            appName: 'HE Music',
            version: '1.0.0',
            buildNumber: '1',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(updateControllerProvider.notifier).checkForUpdates();
    final state = container.read(updateControllerProvider);

    expect(state.status, UpdateStatus.available);
    expect(state.release?.version.normalized, '1.1.0');
    expect(state.errorMessage, isNull);
  });

  test('checkForUpdates exposes latest when no newer release exists', () async {
    final container = ProviderContainer(
      overrides: [
        updateRepositoryProvider.overrideWithValue(
          _FakeUpdateRepository.latest(),
        ),
        currentAppInfoProvider.overrideWith(
          (ref) async => const UpdateCurrentAppInfo(
            appName: 'HE Music',
            version: '1.0.0',
            buildNumber: '1',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(updateControllerProvider.notifier).checkForUpdates();
    final state = container.read(updateControllerProvider);

    expect(state.status, UpdateStatus.latest);
    expect(state.release, isNull);
    expect(state.errorMessage, isNull);
  });
}

class _FakeUpdateRepository implements UpdateRepository {
  const _FakeUpdateRepository._(this._result);

  final UpdateCheckResult _result;

  factory _FakeUpdateRepository.available() {
    return _FakeUpdateRepository._(
      UpdateCheckResult.available(
        UpdateRelease(
          version: UpdateVersion.parse('1.1.0'),
          versionTag: 'v1.1.0',
          title: 'v1.1.0',
          releaseNotes: '修复若干问题',
          htmlUrl: 'https://github.com/example/he-music/releases/tag/v1.1.0',
          publishedAt: DateTime.parse('2026-03-26T12:00:00Z'),
        ),
      ),
    );
  }

  factory _FakeUpdateRepository.latest() {
    return const _FakeUpdateRepository._(UpdateCheckResult.latest());
  }

  @override
  Future<UpdateCheckResult> checkForUpdates({
    required UpdateVersion currentVersion,
  }) async {
    return _result;
  }
}
