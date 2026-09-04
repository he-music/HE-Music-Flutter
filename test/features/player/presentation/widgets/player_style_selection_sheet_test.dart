import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/i18n/app_i18n.dart';
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

    await _selectStyleOption(
      tester,
      axis: 'stage',
      optionId: 'radial_spectrum',
    );

    expect(harness.config.state.playerStageId, 'radial_spectrum');
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

    await _selectStyleOption(
      tester,
      axis: 'stage',
      optionId: 'radial_spectrum',
    );
    expect(find.text('Allow Real-time Spectrum'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(harness.config.state.playerStageId, 'classic');
    expect(permission.requestCount, 0);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Android 请求后拒绝时保持原样式', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final permission = _FakeSpectrumPermission(
      current: RealtimeSpectrumPermissionState.denied,
    );
    final harness = await _pumpSheet(tester, permission);

    await _selectStyleOption(
      tester,
      axis: 'stage',
      optionId: 'radial_spectrum',
    );
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(permission.requestCount, 1);
    expect(harness.config.state.playerStageId, 'classic');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('永久拒绝时保持原样式并提供系统设置入口', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final permission = _FakeSpectrumPermission(
      current: RealtimeSpectrumPermissionState.permanentlyDenied,
    );
    final harness = await _pumpSheet(tester, permission);

    await _selectStyleOption(
      tester,
      axis: 'stage',
      optionId: 'radial_spectrum',
    );
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('Allow Access in Settings'), findsOneWidget);
    await tester.tap(find.text('Open Settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(permission.requestCount, 0);
    expect(permission.openSettingsCount, 1);
    expect(harness.config.state.playerStageId, 'classic');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('非 Android 平台不访问权限端口', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final permission = _FakeSpectrumPermission(
      current: RealtimeSpectrumPermissionState.denied,
    );
    final harness = await _pumpSheet(tester, permission);

    await _selectStyleOption(
      tester,
      axis: 'stage',
      optionId: 'radial_spectrum',
    );

    expect(harness.config.state.playerStageId, 'radial_spectrum');
    expect(permission.statusCount, 0);
    expect(permission.requestCount, 0);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('三轴缩略图分别保存对应配置且面板不关闭', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final harness = await _pumpSheet(
      tester,
      _FakeSpectrumPermission(current: RealtimeSpectrumPermissionState.denied),
    );

    await _selectStyleOption(tester, axis: 'stage', optionId: 'vinyl');
    expect(harness.config.state.playerStageId, 'vinyl');

    await _selectStyleOption(tester, axis: 'backdrop', optionId: 'fluid');
    expect(harness.config.state.playerBackdropId, 'fluid');

    await _selectStyleOption(
      tester,
      axis: 'lyrics',
      optionId: 'cadenza_lyrics',
    );
    expect(harness.config.state.playerLyricsId, 'cadenza_lyrics');

    // 选择后面板保持打开，不自动关闭。
    expect(find.byType(PlayerStyleSelectionSheet), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('同时展示紧凑的封面页和歌词页预览', (tester) async {
    await _pumpSheet(
      tester,
      _FakeSpectrumPermission(current: RealtimeSpectrumPermissionState.denied),
    );

    for (final page in <String>['cover', 'lyrics']) {
      final preview = find.byKey(
        ValueKey<String>('player-style-live-preview-$page-frame'),
      );
      final previewSize = tester.getSize(preview);
      expect(previewSize.width, 96);
      expect(previewSize.height, closeTo(96 * 16 / 9, 0.01));
      expect(
        find.byKey(ValueKey<String>('player-style-preview-$page')),
        findsOneWidget,
      );
    }
    expect(find.byType(PopupMenuButton), findsNothing);
  });

  testWidgets('歌手写真背景禁用封面选项并在切换背景后恢复', (tester) async {
    final harness = await _pumpSheet(
      tester,
      _FakeSpectrumPermission(current: RealtimeSpectrumPermissionState.denied),
    );

    await _selectStyleOption(
      tester,
      axis: 'backdrop',
      optionId: 'artist_photo',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('player-style-axis-stage')),
    );
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey<String>('player-style-stage-suppressed-notice'),
      ),
      findsOneWidget,
    );
    final vinylFinder = find.byKey(
      const ValueKey<String>('player-style-option-vinyl'),
    );
    expect(tester.widget<InkWell>(vinylFinder).onTap, isNull);
    expect(harness.config.state.playerStageId, 'classic');

    await _selectStyleOption(
      tester,
      axis: 'backdrop',
      optionId: 'cover_gradient',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('player-style-axis-stage')),
    );
    await tester.pump();

    expect(
      find.byKey(
        const ValueKey<String>('player-style-stage-suppressed-notice'),
      ),
      findsNothing,
    );
    expect(tester.widget<InkWell>(vinylFinder).onTap, isNotNull);
  });

  testWidgets('歌词样式按语言显示简洁名称', (tester) async {
    expect(AppI18n.tByLocaleCode('zh', 'player.style.monet_lyrics'), '莫奈');
    expect(AppI18n.tByLocaleCode('zh', 'player.style.partita_lyrics'), '云阶');
    expect(AppI18n.tByLocaleCode('zh', 'player.style.cadenza_lyrics'), '心象');

    await _pumpSheet(
      tester,
      _FakeSpectrumPermission(current: RealtimeSpectrumPermissionState.denied),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('player-style-axis-lyrics')),
    );
    await tester.pump();

    expect(find.text('Monet'), findsOneWidget);
    expect(find.text('Partita'), findsOneWidget);
    expect(find.text('Cadenza'), findsOneWidget);
    expect(find.text('Monet Lyrics'), findsNothing);
    expect(find.text('Partita Cloud Steps'), findsNothing);
    expect(find.text('Cadenza Mindscape'), findsNothing);
  });

  testWidgets('窄屏切换三轴时保持无溢出', (tester) async {
    await _pumpSheet(
      tester,
      _FakeSpectrumPermission(current: RealtimeSpectrumPermissionState.denied),
      surfaceSize: const Size(320, 700),
    );
    expect(tester.takeException(), isNull);

    for (final axis in <String>['backdrop', 'lyrics', 'stage']) {
      await tester.tap(find.byKey(ValueKey<String>('player-style-axis-$axis')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    }
  });
}

Future<void> _selectStyleOption(
  WidgetTester tester, {
  required String axis,
  required String optionId,
}) async {
  await tester.tap(find.byKey(ValueKey<String>('player-style-axis-$axis')));
  await tester.pump(const Duration(milliseconds: 200));
  await tester.tap(
    find.byKey(ValueKey<String>('player-style-option-$optionId')),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<_SheetHarness> _pumpSheet(
  WidgetTester tester,
  _FakeSpectrumPermission permission, {
  Size surfaceSize = const Size(430, 1200),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
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
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
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
  void setPlayerStageId(String stageId) {
    state = state.copyWith(
      playerStageId: AppPlayerStageRegistry.instance.normalizeId(stageId),
    );
  }

  @override
  void setPlayerBackdropId(String backdropId) {
    state = state.copyWith(
      playerBackdropId: AppPlayerBackdropRegistry.instance.normalizeId(
        backdropId,
      ),
    );
  }

  @override
  void setPlayerLyricsId(String lyricsId) {
    state = state.copyWith(
      playerLyricsId: AppPlayerLyricsRegistry.instance.normalizeId(lyricsId),
    );
  }
}

class _FakeSpectrumPermission implements RealtimeSpectrumPermissionPort {
  _FakeSpectrumPermission({required this.current});

  RealtimeSpectrumPermissionState current;
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
    return current;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCount += 1;
    return true;
  }
}
