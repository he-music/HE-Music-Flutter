import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/radio/presentation/providers/radio_providers.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test('initialize loads groups and selects first group', () async {
    final client = _FakeRadioApiClient();
    final container = ProviderContainer(
      overrides: [radioApiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    await container
        .read(radioPlazaControllerProvider.notifier)
        .initialize('qq');
    final state = container.read(radioPlazaControllerProvider);

    expect(client.fetchGroupsCalls, 1);
    expect(state.selectedPlatformId, 'qq');
    expect(state.groups.map((g) => g.name), contains('华语'));
    expect(state.selectedGroupName, '华语');
    expect(state.loading, false);
  });

  test('selectGroup switches to another group', () async {
    final client = _FakeRadioApiClient();
    final container = ProviderContainer(
      overrides: [radioApiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    await container
        .read(radioPlazaControllerProvider.notifier)
        .initialize('qq');
    await container
        .read(radioPlazaControllerProvider.notifier)
        .selectGroup('欧美');
    final state = container.read(radioPlazaControllerProvider);

    expect(state.selectedGroupName, '欧美');
  });

  test('selectPlatform uses cache when available', () async {
    final client = _FakeRadioApiClient();
    final container = ProviderContainer(
      overrides: [radioApiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    await container
        .read(radioPlazaControllerProvider.notifier)
        .initialize('qq');
    await container
        .read(radioPlazaControllerProvider.notifier)
        .selectPlatform('qq');
    final state = container.read(radioPlazaControllerProvider);

    expect(client.fetchGroupsCalls, 1);
    expect(state.selectedPlatformId, 'qq');
    expect(state.loading, false);
  });

  test('retry reloads groups after error', () async {
    final client = _FakeRadioApiClient(shouldFail: true);
    final container = ProviderContainer(
      overrides: [radioApiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    await container
        .read(radioPlazaControllerProvider.notifier)
        .initialize('qq');
    final stateAfterError = container.read(radioPlazaControllerProvider);
    expect(stateAfterError.errorMessage, isNotNull);
    expect(stateAfterError.groups, isEmpty);

    client.shouldFail = false;
    await container.read(radioPlazaControllerProvider.notifier).retry();
    final stateAfterRetry = container.read(radioPlazaControllerProvider);

    expect(client.fetchGroupsCalls, 2);
    expect(stateAfterRetry.errorMessage, isNull);
    expect(stateAfterRetry.groups, isNotEmpty);
  });

  test('A-B-A reuses pending A request and ignores late B response', () async {
    final client = _ControlledRadioApiClient();
    final container = ProviderContainer(
      overrides: [radioApiClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);
    final controller = container.read(radioPlazaControllerProvider.notifier);

    final firstA = controller.selectPlatform('a');
    final loadingB = controller.selectPlatform('b');
    final secondA = controller.selectPlatform('a');

    expect(client.callsFor('a'), 1);
    expect(client.callsFor('b'), 1);

    client.complete('a');
    await Future.wait(<Future<void>>[firstA, secondA]);
    client.complete('b');
    await loadingB;

    final state = container.read(radioPlazaControllerProvider);
    expect(state.selectedPlatformId, 'a');
    expect(state.groups.single.platform, 'a');
    expect(state.groups.single.radios.single.platform, 'a');
  });
}

class _FakeRadioApiClient extends RadioApiClient {
  _FakeRadioApiClient({this.shouldFail = false}) : super(Dio());

  int fetchGroupsCalls = 0;
  bool shouldFail;

  @override
  Future<List<RadioGroupInfo>> fetchGroups({required String platform}) async {
    fetchGroupsCalls += 1;
    if (shouldFail) {
      throw Exception('Network error');
    }
    return <RadioGroupInfo>[
      RadioGroupInfo(
        name: '华语',
        platform: platform,
        radios: <RadioInfo>[
          RadioInfo(name: '热歌', id: 'r1', cover: '', platform: platform),
        ],
      ),
      RadioGroupInfo(
        name: '欧美',
        platform: platform,
        radios: <RadioInfo>[
          RadioInfo(name: 'Pop', id: 'r2', cover: '', platform: platform),
        ],
      ),
    ];
  }
}

class _ControlledRadioApiClient extends RadioApiClient {
  _ControlledRadioApiClient() : super(Dio());

  final Map<String, int> _calls = <String, int>{};
  final Map<String, Completer<List<RadioGroupInfo>>> _requests =
      <String, Completer<List<RadioGroupInfo>>>{};

  int callsFor(String platform) => _calls[platform] ?? 0;

  @override
  Future<List<RadioGroupInfo>> fetchGroups({required String platform}) {
    _calls.update(platform, (count) => count + 1, ifAbsent: () => 1);
    return (_requests[platform] ??= Completer<List<RadioGroupInfo>>()).future;
  }

  void complete(String platform) {
    _requests[platform]!.complete(<RadioGroupInfo>[
      RadioGroupInfo(
        name: '$platform-group',
        platform: platform,
        radios: <RadioInfo>[
          RadioInfo(
            name: '$platform-radio',
            id: '$platform-radio',
            cover: '',
            platform: platform,
          ),
        ],
      ),
    ]);
  }
}
