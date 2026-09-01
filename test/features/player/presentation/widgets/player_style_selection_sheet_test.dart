import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_registry.dart';
import 'package:he_music_flutter/core/device/realtime_spectrum_permission.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_style_selection_sheet.dart';

void main() {
  testWidgets('Android 已授权时直接保存环形样式且不重复申请', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final permission = _FakeSpectrumPermission(
      current: RealtimeSpectrumPermissionState.granted,
    );
    final harness = await _pumpSheet(tester, permission);

    await tester.tap(_radialOption);
    await tester.pumpAndSettle();

    expect(harness.config.state.playerStyleId, 'radial_spectrum');
    expect(permission.statusCount, 1);
    expect(permission.requestCount, 0);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android 取消用途说明时保持原样式且不申请', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final permission = _FakeSpectrumPermission(
      current: RealtimeSpectrumPermissionState.denied,
    );
    final harness = await _pumpSheet(tester, permission);

    await tester.tap(_radialOption);
    await tester.pumpAndSettle();
    expect(find.text('Allow Real-time Spectrum'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(harness.config.state.playerStyleId, 'classic');
    expect(permission.requestCount, 0);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android 请求期间禁用同一选项，授权后才保存', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final requestGate = Completer<RealtimeSpectrumPermissionState>();
    final permission = _FakeSpectrumPermission(
      current: RealtimeSpectrumPermissionState.denied,
      requestGate: requestGate,
    );
    final harness = await _pumpSheet(tester, permission);

    await tester.tap(_radialOption);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('player-style-permission-progress')),
      findsOneWidget,
    );
    await tester.tap(_radialOption);
    expect(permission.requestCount, 1);
    expect(harness.config.state.playerStyleId, 'classic');

    requestGate.complete(RealtimeSpectrumPermissionState.granted);
    await tester.pumpAndSettle();
    expect(harness.config.state.playerStyleId, 'radial_spectrum');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android 请求后拒绝时保持原样式并允许重试', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final permission = _FakeSpectrumPermission(
      current: RealtimeSpectrumPermissionState.denied,
    );
    final harness = await _pumpSheet(tester, permission);

    await tester.tap(_radialOption);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(permission.requestCount, 1);
    expect(harness.config.state.playerStyleId, 'classic');
    expect(_radialOption, findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('永久拒绝时保持原样式并提供系统设置入口', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final permission = _FakeSpectrumPermission(
      current: RealtimeSpectrumPermissionState.permanentlyDenied,
    );
    final harness = await _pumpSheet(tester, permission);

    await tester.tap(_radialOption);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Allow Access in Settings'), findsOneWidget);
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(permission.requestCount, 0);
    expect(permission.openSettingsCount, 1);
    expect(harness.config.state.playerStyleId, 'classic');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('非 Android 平台不访问权限端口', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final permission = _FakeSpectrumPermission(
      current: RealtimeSpectrumPermissionState.denied,
    );
    final harness = await _pumpSheet(tester, permission);

    await tester.tap(_radialOption);
    await tester.pumpAndSettle();

    expect(harness.config.state.playerStyleId, 'radial_spectrum');
    expect(permission.statusCount, 0);
    expect(permission.requestCount, 0);
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('Monet 保持可见且 Partita 预览可选择', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final harness = await _pumpSheet(
      tester,
      _FakeSpectrumPermission(current: RealtimeSpectrumPermissionState.denied),
    );

    expect(find.text('Monet Lyrics'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('player-style-preview-monet_lyrics')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('player-style-option-monet_lyrics')),
      findsOneWidget,
    );
    expect(find.text('Partita Cloud Steps'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('player-style-preview-partita_lyrics')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('player-style-option-partita_lyrics')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('player-style-option-partita_lyrics')),
    );
    await tester.pumpAndSettle();

    expect(harness.config.state.playerStyleId, 'partita_lyrics');
    debugDefaultTargetPlatformOverride = null;
  });
}

Finder get _radialOption =>
    find.byKey(const ValueKey<String>('player-style-option-radial_spectrum'));

Future<_SheetHarness> _pumpSheet(
  WidgetTester tester,
  _FakeSpectrumPermission permission,
) async {
  await tester.binding.setSurfaceSize(const Size(430, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  late _TestConfigController config;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWith(() {
          config = _TestConfigController();
          return config;
        }),
        realtimeSpectrumPermissionPortProvider.overrideWithValue(permission),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (context) => const PlayerStyleSelectionSheet(),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return _SheetHarness(config: config);
}

class _SheetHarness {
  const _SheetHarness({required this.config});

  final _TestConfigController config;
}

class _TestConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'en');
  }

  @override
  void setPlayerStyleId(String styleId) {
    state = state.copyWith(
      playerStyleId: AppPlayerStyleRegistry.instance.normalizeId(styleId),
    );
  }
}

class _FakeSpectrumPermission implements RealtimeSpectrumPermissionPort {
  _FakeSpectrumPermission({required this.current, this.requestGate});

  RealtimeSpectrumPermissionState current;
  final Completer<RealtimeSpectrumPermissionState>? requestGate;
  int statusCount = 0;
  int requestCount = 0;
  int openSettingsCount = 0;

  @override
  Future<RealtimeSpectrumPermissionState> status() async {
    statusCount += 1;
    return current;
  }

  @override
  Future<RealtimeSpectrumPermissionState> request() async {
    requestCount += 1;
    current = await requestGate?.future ?? current;
    return current;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCount += 1;
    return true;
  }
}
