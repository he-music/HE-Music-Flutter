import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/i18n/app_i18n.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_registry.dart';
import 'package:he_music_flutter/core/device/realtime_spectrum_permission.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_style_selection_sheet.dart';

import '../../../../helpers/expect_text_height_fits.dart';

void main() {
  testWidgets('style names and category tabs accommodate large text', (
    tester,
  ) async {
    await _pumpSheet(
      tester,
      _FakeSpectrumPermission(current: RealtimeSpectrumPermissionState.granted),
      textScale: 3,
    );
    expectTextHeightFits(tester, find.byType(PlayerStyleSelectionSheet));
    expect(tester.takeException(), isNull);
  });

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

    await _selectStyleOption(tester, axis: 'lyrics', optionId: 'fold_lyrics');
    expect(harness.config.state.playerLyricsId, 'fold_lyrics');
    expect(harness.config.state.playerStageId, 'vinyl');
    expect(harness.config.state.playerBackdropId, 'fluid');

    await _selectStyleOption(
      tester,
      axis: 'lyrics',
      optionId: 'cadenza_lyrics',
    );
    expect(harness.config.state.playerLyricsId, 'cadenza_lyrics');
    await _selectStyleOption(
      tester,
      axis: 'lyrics',
      optionId: 'pendolo_lyrics',
    );
    expect(harness.config.state.playerLyricsId, 'pendolo_lyrics');
    await _selectStyleOption(
      tester,
      axis: 'lyrics',
      optionId: 'claddagh_lyrics',
    );
    expect(harness.config.state.playerLyricsId, 'claddagh_lyrics');
    await _selectStyleOption(
      tester,
      axis: 'lyrics',
      optionId: 'star_tunnel_lyrics',
    );
    expect(harness.config.state.playerLyricsId, 'star_tunnel_lyrics');
    expect(find.text('潮汐'), findsNothing);
    expect(find.text('折光'), findsNothing);

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

  testWidgets('无当前曲目时歌手写真双屏预览展示示例照片', (tester) async {
    await _pumpSheet(
      tester,
      _FakeSpectrumPermission(current: RealtimeSpectrumPermissionState.denied),
    );
    await _selectStyleOption(
      tester,
      axis: 'backdrop',
      optionId: 'artist_photo',
    );

    final photo = find.byKey(
      const ValueKey<String>('player-style-demo-artist-photo'),
    );
    expect(photo, findsNWidgets(2));
    expect(
      tester.widget<Image>(photo.first).image,
      isA<AssetImage>().having(
        (image) => image.assetName,
        'assetName',
        'assets/player_styles/artist_photo/preview.png',
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('有当前曲目时不使用示例写真', (tester) async {
    await _pumpSheet(
      tester,
      _FakeSpectrumPermission(current: RealtimeSpectrumPermissionState.denied),
      track: const PlayerTrack(
        id: 'track-1',
        title: 'Song',
        artist: 'Singer',
        platform: '',
      ),
    );
    await _selectStyleOption(
      tester,
      axis: 'backdrop',
      optionId: 'artist_photo',
    );

    expect(
      find.byKey(const ValueKey<String>('player-style-demo-artist-photo')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('player-backdrop-artist-photo')),
      findsNWidgets(2),
    );
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
  final option = find.byKey(ValueKey<String>('player-style-option-$optionId'));
  await tester.ensureVisible(option);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(option);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Future<_SheetHarness> _pumpSheet(
  WidgetTester tester,
  _FakeSpectrumPermission permission, {
  Size surfaceSize = const Size(430, 1200),
  double textScale = 1,
  PlayerTrack? track,
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (context) => PlayerStyleSelectionSheet(track: track),
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
