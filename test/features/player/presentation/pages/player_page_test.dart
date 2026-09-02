import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_color.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_mode.dart';
import 'package:he_music_flutter/app/router/app_route_observers.dart';
import 'package:he_music_flutter/app/theme/player/app_player_scene_palette.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_registry.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_boundary.dart';
import 'package:he_music_flutter/core/audio/audio_spectrum_frame.dart';
import 'package:he_music_flutter/core/audio/audio_spectrum_port.dart';
import 'package:he_music_flutter/core/audio/audio_sleep_timer.dart';
import 'package:he_music_flutter/core/device/screen_wake_lock.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/monet_lyric_layout.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/monet_lyric_painter.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/monet_lyric_rail.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/partita_lyric_painter.dart';
import 'package:he_music_flutter/features/lyrics/presentation/widgets/partita_lyric_rail.dart';
import 'package:he_music_flutter/features/my/presentation/providers/favorite_song_status_providers.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_play_mode.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_quality_option.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/realtime_spectrum_controller.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_audio_provider.dart';
import 'package:he_music_flutter/features/player/presentation/pages/player_page.dart';
import 'package:he_music_flutter/features/player/presentation/providers/artist_photo_provider.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/styles/player_style_stage.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_backdrop.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_lyric_page.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/monet_lyric_page.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/partita_lyric_page.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_queue_sheet.dart';
import 'package:he_music_flutter/shared/constants/layout_tokens.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

final _playerTestLyricPositionProvider =
    NotifierProvider<_PlayerTestLyricPositionController, Duration>(
      _PlayerTestLyricPositionController.new,
    );

const _monetFixturePosition = Duration(minutes: 1, seconds: 24);

const _monetFixtureDocument = LyricDocument(
  lines: <LyricLine>[
    LyricLine(
      start: Duration(minutes: 1, seconds: 8),
      end: Duration(minutes: 1, seconds: 14),
      text: '城市回声',
    ),
    LyricLine(
      start: Duration(minutes: 1, seconds: 14),
      end: Duration(minutes: 1, seconds: 20),
      text: '玻璃天台',
    ),
    LyricLine(
      start: Duration(minutes: 1, seconds: 20),
      end: Duration(minutes: 1, seconds: 29),
      text: '低频大厅',
      translation: 'Low Frequency Hall',
      tokens: <LyricToken>[
        LyricToken(
          text: '低频',
          startOffset: Duration.zero,
          duration: Duration(seconds: 2),
        ),
        LyricToken(
          text: '大厅',
          startOffset: Duration(seconds: 2),
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    LyricLine(
      start: Duration(minutes: 1, seconds: 29),
      end: Duration(minutes: 1, seconds: 35),
      text: '信号房间',
    ),
    LyricLine(
      start: Duration(minutes: 1, seconds: 35),
      end: Duration(minutes: 1, seconds: 42),
      text: '现在想听什么',
    ),
  ],
);

void main() {
  test(
    'resolvePlayerLyricHighlightColor should fallback to sky on auto failure',
    () {
      final color = resolvePlayerLyricHighlightColor(
        AppConfigState.initial.copyWith(
          lyricHighlightMode: AppLyricHighlightMode.auto,
        ),
      );

      expect(color, AppLyricHighlightColor.sky.color);
    },
  );

  for (final platform in <TargetPlatform>[
    TargetPlatform.android,
    TargetPlatform.iOS,
  ]) {
    testWidgets('$platform 前台播放器活动会话启用常亮', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final wakeLock = _RecordingScreenWakeLockPort();

      await tester.pumpWidget(
        _buildPlayerTestApp(
          controllerFactory: _WakeLockPlayerController.new,
          screenWakeLockPort: wakeLock,
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(wakeLock.calls, <bool>[true]);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets(
    'mobile player pager spans full width while content keeps gutter',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildPlayerTestApp(
          controllerFactory: _OnlineTrackPlayerController.new,
        ),
      );
      await tester.pump();
      await tester.pump();

      final pagerRect = tester.getRect(
        find.byKey(const ValueKey<String>('player-mobile-pager')),
      );
      final contentRect = tester.getRect(
        find.byKey(const ValueKey<String>('player-mobile-primary-pane')),
      );

      expect(pagerRect.left, 0);
      expect(pagerRect.right, 430);
      expect(contentRect.left, 12);
      expect(contentRect.right, 418);
    },
  );

  testWidgets('播放器分页和 PopupRoute 不释放常亮', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final wakeLock = _RecordingScreenWakeLockPort();

    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: _WakeLockPlayerController.new,
        screenWakeLockPort: wakeLock,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    final pager = tester.widget<PageView>(
      find.byKey(const ValueKey<String>('player-mobile-pager')),
    );
    pager.controller!.jumpToPage(1);
    await tester.pumpAndSettle();
    expect(find.byType(PlayerLyricPage), findsOneWidget);
    expect(wakeLock.calls, <bool>[true]);

    final playerContext = tester.element(find.byType(PlayerPage));
    showModalBottomSheet<void>(
      context: playerContext,
      builder: (context) => const SizedBox(
        key: ValueKey<String>('wake-lock-test-sheet'),
        height: 100,
      ),
    );
    await tester.pumpAndSettle();
    expect(wakeLock.calls, <bool>[true]);
    debugDefaultTargetPlatformOverride = null;
    Navigator.of(
      tester.element(
        find.byKey(const ValueKey<String>('wake-lock-test-sheet')),
      ),
    ).pop();
    await tester.pumpAndSettle();

    showDialog<void>(
      context: playerContext,
      builder: (context) =>
          const AlertDialog(key: ValueKey<String>('wake-lock-test-dialog')),
    );
    await tester.pumpAndSettle();
    expect(wakeLock.calls, <bool>[true]);
  });

  testWidgets('生命周期离开 resumed 时释放，恢复后重新启用', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final wakeLock = _RecordingScreenWakeLockPort();

    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: _WakeLockPlayerController.new,
        screenWakeLockPort: wakeLock,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    for (final state in <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
      expect(wakeLock.calls.last, isFalse, reason: '$state');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(wakeLock.calls.last, isTrue, reason: '$state -> resumed');
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('完整 PageRoute 覆盖时先释放，返回后恢复且销毁不重复释放', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final ownershipEvents = <String>[];
    final wakeLock = _RecordingScreenWakeLockPort(
      onCall: (enabled) {
        ownershipEvents.add('music:$enabled');
      },
    );

    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: _WakeLockPlayerController.new,
        screenWakeLockPort: wakeLock,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    final navigator = Navigator.of(tester.element(find.byType(PlayerPage)));
    navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (context) => _WakeOwnershipProbe(events: ownershipEvents),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(ownershipEvents, <String>[
      'music:true',
      'music:false',
      'video:true',
    ]);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(ownershipEvents.last, 'music:true');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(ownershipEvents.last, 'music:false');
    expect(ownershipEvents.where((event) => event == 'music:false').length, 2);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('会话暂停和恢复分别释放与重新启用常亮', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final wakeLock = _RecordingScreenWakeLockPort();
    late _WakeLockPlayerController controller;

    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: () {
          controller = _WakeLockPlayerController();
          return controller;
        },
        screenWakeLockPort: wakeLock,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    controller.setPlaybackSessionActive(false);
    await tester.pump();
    controller.setPlaybackSessionActive(true);
    await tester.pump();

    expect(wakeLock.calls, <bool>[true, false, true]);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('环形频谱按竖屏歌词页、横屏和生命周期启停捕获', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final spectrum = _RecordingRealtimeSpectrumController();

    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: _SpectrumPlayerController.new,
        config: AppConfigState.initial.copyWith(
          localeCode: 'en',
          playerStyleId: AppPlayerStyleRegistry.radialSpectrumId,
        ),
        spectrumController: spectrum,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(spectrum.visibility, <bool>[true]);

    final pager = tester.widget<PageView>(
      find.byKey(const ValueKey<String>('player-mobile-pager')),
    );
    pager.controller!.jumpToPage(1);
    await tester.pumpAndSettle();
    expect(spectrum.visibility, <bool>[true, false]);

    await tester.binding.setSurfaceSize(const Size(932, 430));
    await tester.pump();
    await tester.pump();
    expect(spectrum.visibility, <bool>[true, false, true]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(spectrum.visibility, <bool>[true, false, true, false]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(spectrum.visibility, <bool>[true, false, true, false, true]);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('macOS 播放器失焦时保持频谱，窗口隐藏后停止', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final spectrum = _RecordingRealtimeSpectrumController();

    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: _SpectrumPlayerController.new,
        config: AppConfigState.initial.copyWith(
          localeCode: 'en',
          playerStyleId: AppPlayerStyleRegistry.radialSpectrumId,
        ),
        spectrumController: spectrum,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(spectrum.visibility, <bool>[true]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(spectrum.visibility, <bool>[true]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(spectrum.visibility, <bool>[true, false]);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(spectrum.visibility, <bool>[true, false, true]);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('环形频谱在 PopupRoute 保持捕获，PageRoute 覆盖时停止并在返回后恢复', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final spectrum = _RecordingRealtimeSpectrumController();

    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: _SpectrumPlayerController.new,
        config: AppConfigState.initial.copyWith(
          localeCode: 'en',
          playerStyleId: AppPlayerStyleRegistry.radialSpectrumId,
        ),
        spectrumController: spectrum,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(spectrum.visibility, <bool>[true]);

    final playerContext = tester.element(find.byType(PlayerPage));
    showDialog<void>(
      context: playerContext,
      builder: (context) =>
          const AlertDialog(key: ValueKey<String>('spectrum-test-dialog')),
    );
    await tester.pumpAndSettle();
    expect(spectrum.visibility, <bool>[true]);

    Navigator.of(
      tester.element(
        find.byKey(const ValueKey<String>('spectrum-test-dialog')),
      ),
    ).pop();
    await tester.pumpAndSettle();

    final navigator = Navigator.of(tester.element(find.byType(PlayerPage)));
    navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            const Scaffold(key: ValueKey<String>('spectrum-covering-page')),
      ),
    );
    await tester.pumpAndSettle();
    expect(spectrum.visibility, <bool>[true, false]);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(spectrum.visibility, <bool>[true, false, true]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(spectrum.visibility, <bool>[true, false, true, false]);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('从环形频谱切回普通样式时停止捕获', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final spectrum = _RecordingRealtimeSpectrumController();

    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: _SpectrumPlayerController.new,
        config: AppConfigState.initial.copyWith(
          localeCode: 'en',
          playerStyleId: AppPlayerStyleRegistry.radialSpectrumId,
        ),
        spectrumController: spectrum,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    expect(spectrum.visibility, <bool>[true]);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayerPage)),
    );
    container
        .read(appConfigProvider.notifier)
        .setPlayerStyleId(AppPlayerStyleRegistry.classicId);
    await tester.pump();
    await tester.pump();

    expect(spectrum.visibility, <bool>[true, false]);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('快速会话变化按顺序调用并收敛到最后目标', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final firstCall = Completer<void>();
    final secondCall = Completer<void>();
    final wakeLock = _RecordingScreenWakeLockPort(nextCompletion: firstCall);
    late _WakeLockPlayerController controller;

    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: () {
          controller = _WakeLockPlayerController();
          return controller;
        },
        screenWakeLockPort: wakeLock,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(wakeLock.calls, <bool>[true]);

    controller.setPlaybackSessionActive(false);
    wakeLock.nextCompletion = secondCall;
    firstCall.complete();
    await tester.pump();
    expect(wakeLock.calls, <bool>[true, false]);

    controller.setPlaybackSessionActive(true);
    secondCall.complete();
    await tester.pump();
    expect(wakeLock.calls, <bool>[true, false, true]);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('无活动会话时不申请常亮', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final wakeLock = _RecordingScreenWakeLockPort();

    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: _OnlineTrackPlayerController.new,
        screenWakeLockPort: wakeLock,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(wakeLock.calls, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('非移动平台不调用常亮端口', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final wakeLock = _RecordingScreenWakeLockPort();

    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: _WakeLockPlayerController.new,
        screenWakeLockPort: wakeLock,
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    expect(wakeLock.calls, isEmpty);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('常亮端口失败不影响页面且后续状态可重试', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final wakeLock = _RecordingScreenWakeLockPort(failuresRemaining: 1);
    late _WakeLockPlayerController controller;

    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: () {
          controller = _WakeLockPlayerController();
          return controller;
        },
        screenWakeLockPort: wakeLock,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.takeException(), isNull);

    controller.setPlaybackSessionActive(false);
    await tester.pump();
    controller.setPlaybackSessionActive(true);
    await tester.pump();

    expect(wakeLock.calls, <bool>[true, true]);
    expect(find.byType(PlayerPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('player more sheet shows add to playlist for online track', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    await _scrollPlayerMoreSheetTo(tester, 'Download');
    expect(find.text('Download'), findsOneWidget);
    await _scrollPlayerMoreSheetTo(tester, 'Add to Playlist');
    expect(find.text('Add to Playlist'), findsOneWidget);
  });

  testWidgets('player more sheet uses action sheet height cap', (tester) async {
    const surfaceSize = Size(430, 1200);
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    final listFinder = find.byKey(
      const ValueKey<String>('player-more-sheet-list'),
    );
    final mediaHeight = MediaQuery.sizeOf(tester.element(listFinder)).height;
    expect(
      tester.getSize(listFinder).height,
      closeTo(mediaHeight * LayoutTokens.actionSheetMaxHeightFactor, 0.1),
    );
  });

  testWidgets('player more sheet hides add to playlist for local track', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _LocalTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Add to Playlist'), findsNothing);
  });

  testWidgets('custom sleep timer picker loops hour and minute columns', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await _scrollPlayerMoreSheetTo(tester, 'Sleep Timer');
    await tester.tap(find.text('Sleep Timer'));
    await tester.pumpAndSettle();

    await _scrollSleepTimerSheetTo(tester, 'Custom');
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    final pickers = tester
        .widgetList<CupertinoPicker>(find.byType(CupertinoPicker))
        .toList();
    expect(pickers, hasLength(2));
    expect(pickers[0].childDelegate, isA<ListWheelChildLoopingListDelegate>());
    expect(pickers[1].childDelegate, isA<ListWheelChildLoopingListDelegate>());
  });

  testWidgets('player style selection uses previews and preserves playback', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late _OnlineTrackPlayerController playerController;

    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: () {
          playerController = _OnlineTrackPlayerController();
          return playerController;
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    final before = playerController.snapshot;

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Volume'), findsOneWidget);
    expect(find.text('Player Style'), findsOneWidget);

    await tester.tap(find.text('Player Style'));
    await tester.pumpAndSettle();

    for (final styleId in AppPlayerStyleRegistry.builtInIds) {
      final previewFinder = find.byKey(
        ValueKey<String>('player-style-preview-$styleId'),
      );
      expect(previewFinder, findsOneWidget);
      expect(tester.widget<Image>(previewFinder).fit, BoxFit.contain);
    }
    expect(
      find.byKey(const ValueKey<String>('player-style-selected-classic')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('vinyl-player-stage')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('cassette-player-stage')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('player-backdrop-artist-photo')),
      findsNothing,
    );

    final pager = tester.widget<PageView>(
      find.byKey(const ValueKey<String>('player-mobile-pager')),
    );
    pager.controller!.jumpToPage(1);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('player-style-option-vinyl')),
    );
    await tester.pumpAndSettle();

    final after = playerController.snapshot;
    expect(after.currentTrack, same(before.currentTrack));
    expect(after.isPlaying, before.isPlaying);
    expect(after.position, before.position);
    expect(after.queue, same(before.queue));
    expect(after.playMode, before.playMode);
    expect(
      tester
          .widget<PageView>(
            find.byKey(const ValueKey<String>('player-mobile-pager')),
          )
          .controller!
          .page,
      closeTo(1, 0.001),
    );
    expect(
      find.byKey(const ValueKey<String>('player-backdrop-vinyl')),
      findsOneWidget,
    );
  });

  testWidgets('player page hides desktop lyric actions in utility row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: _OnlineTrackPlayerController.new,
        config: AppConfigState.initial.copyWith(
          localeCode: 'en',
          enableDesktopLyric: true,
          enableDesktopLyricLock: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.lyrics), findsNothing);
    expect(find.byIcon(Icons.lock), findsNothing);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
  });

  testWidgets('player download action opens quality sheet for online track', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await _scrollPlayerMoreSheetTo(tester, 'Download');
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();

    expect(find.text('Choose Quality'), findsOneWidget);
    expect(find.text('SQ'), findsWidgets);
    expect(find.text('HQ'), findsWidgets);
  });

  testWidgets('local player shows read-only audio quality', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _LocalTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await _scrollPlayerMoreSheetTo(tester, 'Quality');

    expect(find.text('Quality'), findsOneWidget);
    expect(find.text('MP3 · 320 kbps'), findsWidgets);

    await tester.tap(find.text('Quality'));
    await tester.pumpAndSettle();
    expect(find.text('Choose Quality'), findsNothing);
  });

  testWidgets('player more sheet shows detail entry for online track', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await _scrollPlayerMoreSheetTo(tester, 'View Detail');

    expect(find.text('View Detail'), findsOneWidget);
  });

  testWidgets('player artist is tappable when its detail page is available', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('player-artist-action')),
      findsOneWidget,
    );
  });

  testWidgets('local player artist opens as an available action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _LocalTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('player-artist-action')),
      findsOneWidget,
    );
  });

  testWidgets(
    'player more sheet hides album artist comments when platform flags are unsupported',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildPlayerTestApp(
          controllerFactory: _OnlineTrackPlayerController.new,
          featureSupportFlag: BigInt.zero,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('player-artist-action')),
        findsNothing,
      );

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await _scrollPlayerMoreSheetTo(tester, 'View Detail');

      expect(find.text('View Detail'), findsOneWidget);
      expect(find.text('View Album'), findsNothing);
      expect(find.text('View Artist'), findsNothing);
      expect(find.text('View Comments'), findsNothing);
    },
  );

  testWidgets('player switch quality sheet shows quality description', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await _scrollPlayerMoreSheetTo(tester, 'Quality');
    await tester.tap(find.text('Quality'));
    await tester.pumpAndSettle();

    expect(find.text('HQ'), findsWidgets);
    expect(find.textContaining('High Quality'), findsOneWidget);
  });

  testWidgets('player page uses side by side desktop layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(PageView), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('player-desktop-primary-pane')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('player-desktop-lyrics-pane')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('player-compact-lyric-preview')),
      findsNothing,
    );
    expect(find.byType(PlayerLyricPage), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('player-page-indicator')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('player-stage-classic')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('player page uses classic color backdrop by default', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('player-backdrop-classic')),
      findsOneWidget,
    );
    final stage = find.byKey(const ValueKey<String>('classic-player-stage'));
    final palette = PlayerScenePalette.maybeOf(tester.element(stage));
    expect(palette, isNotNull);
    final sliderTheme = tester.widget<SliderTheme>(
      find.ancestor(
        of: find.byKey(const ValueKey<String>('player-progress-slider')),
        matching: find.byType(SliderTheme),
      ),
    );
    expect(sliderTheme.data.activeTrackColor, Colors.white);
    final pageIndicators = tester
        .widgetList<AnimatedContainer>(
          find.descendant(
            of: find.byKey(const ValueKey<String>('player-page-indicator')),
            matching: find.byType(AnimatedContainer),
          ),
        )
        .toList();
    expect(pageIndicators, hasLength(2));
    expect(
      (pageIndicators.first.decoration as BoxDecoration).color,
      Colors.white,
    );
    expect(
      (pageIndicators.last.decoration as BoxDecoration).color,
      Colors.white.withValues(alpha: 0.32),
    );
  });

  testWidgets('Monet style uses its lyric host and keeps classic stage', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: _OnlineTrackPlayerController.new,
        lyricDocument: _monetFixtureDocument,
        config: AppConfigState.initial.copyWith(
          localeCode: 'en',
          playerStyleId: AppPlayerStyleRegistry.monetLyricsId,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey<String>('classic-player-stage')),
      findsOneWidget,
    );

    final pager = tester.widget<PageView>(
      find.byKey(const ValueKey<String>('player-mobile-pager')),
    );
    pager.controller!.jumpToPage(1);
    await tester.pumpAndSettle();

    expect(find.byType(MonetLyricPage), findsOneWidget);
    expect(find.byType(PlayerLyricPage), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('monet-lyric-page')),
      findsOneWidget,
    );
    final monetHost = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey<String>('monet-lyric-page')),
    );
    expect((monetHost.decoration as BoxDecoration).color, isNull);
    expect(
      tester.widget<MonetLyricPage>(find.byType(MonetLyricPage)).palette,
      isNotNull,
    );
    expect(find.byType(MonetLyricRail), findsOneWidget);
    final initialPainter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey<String>('monet-lyric-painter')),
                )
                .painter!
            as MonetLyricPainter;
    final initialRenderData = initialPainter.data;
    final activeLine = initialRenderData.lines.singleWhere(
      (line) => line.positioned.entry.status == MonetLyricLineStatus.active,
    );
    expect(activeLine.positioned.entry.line.text, '低频大厅');
    expect(activeLine.translationPainter, isNotNull);
    expect(activeLine.accentPainter, isNotNull);
    final playerPageWidget = tester.widget<PlayerPage>(find.byType(PlayerPage));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayerPage)),
    );
    container
        .read(_playerTestLyricPositionProvider.notifier)
        .update(const Duration(minutes: 1, seconds: 25));
    await tester.pump();
    final sameLinePainter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey<String>('monet-lyric-painter')),
                )
                .painter!
            as MonetLyricPainter;
    expect(sameLinePainter.data, same(initialRenderData));
    expect(
      tester.widget<PlayerPage>(find.byType(PlayerPage)),
      same(playerPageWidget),
    );

    container
        .read(_playerTestLyricPositionProvider.notifier)
        .update(const Duration(minutes: 1, seconds: 30));
    await tester.pump();
    final crossedPainter =
        tester
                .widget<CustomPaint>(
                  find.byKey(const ValueKey<String>('monet-lyric-painter')),
                )
                .painter!
            as MonetLyricPainter;
    expect(crossedPainter.data, isNot(same(initialRenderData)));
    expect(
      crossedPainter.data.lines
          .singleWhere(
            (line) =>
                line.positioned.entry.status == MonetLyricLineStatus.active,
          )
          .positioned
          .entry
          .line
          .text,
      '信号房间',
    );
    expect(
      tester.widget<PlayerPage>(find.byType(PlayerPage)),
      same(playerPageWidget),
    );
    await tester.pump(const Duration(milliseconds: 400));

    container
        .read(appConfigProvider.notifier)
        .setPlayerStyleId(AppPlayerStyleRegistry.vinylId);
    await tester.pump();

    expect(find.byType(MonetLyricPage), findsNothing);
    expect(find.byType(PlayerLyricPage), findsOneWidget);
  });

  testWidgets('Partita style uses active-line chunks with the classic scene', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var playerPageBuilds = 0;
    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: _OnlineTrackPlayerController.new,
        lyricDocument: _monetFixtureDocument,
        onPlayerPageBuild: () => playerPageBuilds += 1,
        config: AppConfigState.initial.copyWith(
          localeCode: 'en',
          playerStyleId: AppPlayerStyleRegistry.partitaLyricsId,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('classic-player-stage')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('player-compact-lyric-tap')),
      findsOneWidget,
    );
    final pager = tester.widget<PageView>(
      find.byKey(const ValueKey<String>('player-mobile-pager')),
    );
    pager.controller!.jumpToPage(1);
    await tester.pumpAndSettle();

    expect(find.byType(PartitaLyricPage), findsOneWidget);
    expect(find.byType(PartitaLyricRail), findsOneWidget);
    expect(find.byType(MonetLyricPage), findsNothing);
    expect(find.byType(PlayerLyricPage), findsNothing);
    final host = tester.widget(
      find.byKey(const ValueKey<String>('partita-lyric-page')),
    );
    expect(host, isNot(isA<DecoratedBox>()));
    expect(
      tester.widget<PartitaLyricPage>(find.byType(PartitaLyricPage)).palette,
      isNotNull,
    );

    final initialPainter = _partitaPainter(tester);
    final initialData = initialPainter.data;
    final layout = initialData.layout!;
    expect(layout.sourceLine.text, '低频大厅');
    expect(layout.columns, hasLength(1));
    expect(layout.chunks.length, greaterThan(1));
    expect(
      layout.chunks
          .expand((chunk) => chunk.units)
          .map((unit) => unit.text)
          .join(),
      layout.sourceLine.text,
    );
    expect(
      layout.chunks.map((chunk) => chunk.guide.side.name).toSet(),
      containsAll(<String>{'left', 'right'}),
    );
    expect(initialData.fineTimingEnabled, isTrue);
    expect(initialData.auxiliaryPainter, isNotNull);

    final playerPageWidget = tester.widget<PlayerPage>(find.byType(PlayerPage));
    final initialPlayerPageBuilds = playerPageBuilds;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayerPage)),
    );
    container
        .read(_playerTestLyricPositionProvider.notifier)
        .update(const Duration(minutes: 1, seconds: 25));
    await tester.pump();
    final sameLinePainter = _partitaPainter(tester);
    expect(sameLinePainter.data, same(initialData));
    expect(
      tester.widget<PlayerPage>(find.byType(PlayerPage)),
      same(playerPageWidget),
    );
    expect(playerPageBuilds, initialPlayerPageBuilds);
    final playerController =
        container.read(playerControllerProvider.notifier)
            as _OnlineTrackPlayerController;
    playerController.setPlaybackActivity(isPlaying: true, isLoading: false);
    await tester.pump();
    expect(
      tester.widget<PlayerPage>(find.byType(PlayerPage)),
      same(playerPageWidget),
    );
    expect(playerPageBuilds, initialPlayerPageBuilds);
    await tester.pump(const Duration(milliseconds: 1750));
    expect(_partitaPainter(tester).breathing.value, greaterThan(0));

    playerController.setPlaybackActivity(isPlaying: true, isLoading: true);
    await tester.pump();
    expect(
      tester.widget<PlayerPage>(find.byType(PlayerPage)),
      same(playerPageWidget),
    );
    expect(playerPageBuilds, initialPlayerPageBuilds);
    expect(_partitaPainter(tester).breathing.value, 0);

    container
        .read(appConfigProvider.notifier)
        .setPlayerStyleId(AppPlayerStyleRegistry.classicId);
    await tester.pump();
    expect(find.byType(PartitaLyricPage), findsNothing);
    expect(find.byType(PlayerLyricPage), findsOneWidget);
  });

  testWidgets('favorite heart stays red across all player styles', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlayerPage)),
    );
    container
        .read(favoriteSongStatusProvider.notifier)
        .addSong(songId: 'song-1', platform: 'qq');
    await tester.pump();

    for (final styleId in AppPlayerStyleRegistry.builtInIds) {
      container.read(appConfigProvider.notifier).setPlayerStyleId(styleId);
      await tester.pump();

      final heart = tester.widget<Icon>(find.byIcon(Icons.favorite_rounded));
      expect(heart.color, Colors.redAccent, reason: styleId);
    }
  });

  testWidgets('player page switches stage backdrop from config', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: _OnlineTrackPlayerController.new,
        config: AppConfigState.initial.copyWith(
          localeCode: 'en',
          playerStyleId: AppPlayerStyleRegistry.vinylId,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('player-backdrop-vinyl')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('vinyl-player-stage')),
      findsOneWidget,
    );
    expect(
      PlayerScenePalette.maybeOf(
        tester.element(
          find.byKey(const ValueKey<String>('vinyl-player-stage')),
        ),
      ),
      isNull,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(Duration.zero);
  });

  testWidgets('player page displays cassette stage from config', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: _OnlineTrackPlayerController.new,
        config: AppConfigState.initial.copyWith(
          localeCode: 'en',
          playerStyleId: AppPlayerStyleRegistry.cassetteId,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('player-backdrop-cassette')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('cassette-player-stage')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('player-cassette-track-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('player-track-header')),
      findsNothing,
    );
    expect(find.text('在线歌曲'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('player-cassette-artist')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('player-quality-badge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('player-speed-badge')),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey<String>('player-cassette-track-header')),
        matching: find.byKey(
          const ValueKey<String>('cassette-stage-ignore-pointer'),
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('desktop cassette keeps metadata inside the label', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: _OnlineTrackPlayerController.new,
        config: AppConfigState.initial.copyWith(
          localeCode: 'en',
          playerStyleId: AppPlayerStyleRegistry.cassetteId,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('player-cassette-track-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('player-track-header')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile landscape cassette keeps compact metadata in the label', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.binding.setSurfaceSize(const Size(700, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: _OnlineTrackPlayerController.new,
        config: AppConfigState.initial.copyWith(
          localeCode: 'en',
          playerStyleId: AppPlayerStyleRegistry.cassetteId,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('player-track-header')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('player-cassette-track-header')),
      findsOneWidget,
    );
    expect(find.text('在线歌曲'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('player-cassette-artist')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('cassette-label-cover')),
      findsOneWidget,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('cassette-label-cover')))
          .width,
      greaterThan(34),
    );
    expect(
      find.byKey(const ValueKey<String>('player-quality-badge')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('player-speed-badge')),
      findsNothing,
    );
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey<String>('player-cassette-artist')),
        matching: find.byKey(const ValueKey<String>('player-artist-action')),
      ),
      findsNothing,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey<String>('player-stage-cassette')))
          .aspectRatio,
      closeTo(1.60, 0.001),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });

  test('player artist photo direction follows window orientation', () {
    expect(
      resolvePlayerArtistPhotoPortraitForTest(const Size(1440, 960)),
      isFalse,
    );
    expect(
      resolvePlayerArtistPhotoPortraitForTest(const Size(700, 420)),
      isFalse,
    );
    expect(
      resolvePlayerArtistPhotoPortraitForTest(const Size(430, 1200)),
      isTrue,
    );
  });

  test('player orientation controls only support Android and iOS apps', () {
    expect(
      supportsPlayerOrientationControlsForTest(
        platform: TargetPlatform.android,
        isWeb: false,
      ),
      isTrue,
    );
    expect(
      supportsPlayerOrientationControlsForTest(
        platform: TargetPlatform.iOS,
        isWeb: false,
      ),
      isTrue,
    );
    expect(
      supportsPlayerOrientationControlsForTest(
        platform: TargetPlatform.macOS,
        isWeb: false,
      ),
      isFalse,
    );
    expect(
      supportsPlayerOrientationControlsForTest(
        platform: TargetPlatform.android,
        isWeb: true,
      ),
      isFalse,
    );
  });

  testWidgets('player page opens queue bottom sheet on wide screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.queue_music_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.byType(PlayerQueueSheet), findsOneWidget);
  });

  testWidgets('player main page stays fixed across target mobile viewports', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in const <Size>[
      Size(320, 568),
      Size(360, 640),
      Size(430, 932),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        _buildPlayerTestApp(
          controllerFactory: _OnlineTrackPlayerController.new,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(PageView), findsOneWidget, reason: '$size');
      expect(
        find.byKey(const ValueKey<String>('player-main-fixed-layout')),
        findsOneWidget,
        reason: '$size',
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey<String>('player-mobile-primary-pane')),
          matching: find.byType(SingleChildScrollView),
        ),
        findsNothing,
        reason: '$size',
      );
      expect(
        find.byKey(const ValueKey<String>('player-compact-lyric-preview')),
        findsOneWidget,
        reason: '$size',
      );
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets(
    'tall mobile layout keeps stage and info close with space before controls',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _buildPlayerTestApp(
          controllerFactory: _OnlineTrackPlayerController.new,
        ),
      );
      await tester.pump();
      await tester.pump();

      final stageRect = tester.getRect(
        find.byKey(const ValueKey<String>('player-stage-classic')),
      );
      final headerRect = tester.getRect(
        find.byKey(const ValueKey<String>('player-track-header')),
      );
      final lyricRect = tester.getRect(
        find.byKey(const ValueKey<String>('player-compact-lyric-preview')),
      );
      final moreRect = tester.getRect(find.byIcon(Icons.more_horiz_rounded));

      expect(headerRect.top - stageRect.bottom, lessThanOrEqualTo(16));
      expect(moreRect.top - lyricRect.bottom, greaterThan(48));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile controls stay above the bottom system safe area', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    tester.view.physicalSize = Size(
      430 * tester.view.devicePixelRatio,
      932 * tester.view.devicePixelRatio,
    );
    tester.view.padding = FakeViewPadding(
      bottom: 34 * tester.view.devicePixelRatio,
    );
    tester.view.viewPadding = FakeViewPadding(
      bottom: 34 * tester.view.devicePixelRatio,
    );
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.view.resetPhysicalSize();
      tester.view.resetPadding();
      tester.view.resetViewPadding();
    });

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    final playRect = tester.getRect(find.byIcon(Icons.play_arrow_rounded));
    final playerBottom = tester.getRect(find.byType(Scaffold).first).bottom;

    expect(playerBottom - playRect.bottom, greaterThanOrEqualTo(40));
    expect(tester.takeException(), isNull);
  });

  testWidgets('player desktop target viewports stay overflow free', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in const <Size>[Size(1024, 768), Size(1440, 960)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        _buildPlayerTestApp(
          controllerFactory: _OnlineTrackPlayerController.new,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(PageView), findsNothing, reason: '$size');
      expect(
        find.byKey(const ValueKey<String>('player-desktop-primary-pane')),
        findsOneWidget,
        reason: '$size',
      );
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('player uses dedicated layout at target landscape viewports', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in const <Size>[
      Size(932, 430),
      Size(844, 390),
      Size(700, 420),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        _buildPlayerTestApp(
          controllerFactory: _OnlineTrackPlayerController.new,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('player-mobile-landscape-layout')),
        findsOneWidget,
        reason: '$size',
      );
      expect(
        find.byKey(const ValueKey<String>('player-mobile-landscape-stage')),
        findsOneWidget,
        reason: '$size',
      );
      expect(
        find.byKey(const ValueKey<String>('player-mobile-landscape-details')),
        findsOneWidget,
        reason: '$size',
      );
      final exitRect = tester.getRect(
        find.byKey(
          const ValueKey<String>('player-mobile-landscape-exit-button'),
        ),
      );
      final stageRect = tester.getRect(
        find.byKey(const ValueKey<String>('player-mobile-landscape-stage')),
      );
      expect(
        exitRect.right,
        lessThanOrEqualTo(stageRect.left),
        reason: '$size',
      );
      expect(
        find.byIcon(Icons.arrow_back_ios_new_rounded),
        findsOneWidget,
        reason: '$size',
      );
      expect(
        find.byIcon(Icons.keyboard_arrow_down_rounded),
        findsNothing,
        reason: '$size',
      );
      expect(
        find.byIcon(Icons.stay_current_portrait_rounded),
        findsNothing,
        reason: '$size',
      );
      expect(find.text('在线歌曲 - 测试歌手'), findsOneWidget, reason: '$size');
      expect(
        find.byKey(const ValueKey<String>('player-quality-badge')),
        findsNothing,
        reason: '$size',
      );
      expect(
        find.byKey(const ValueKey<String>('player-speed-badge')),
        findsNothing,
        reason: '$size',
      );
      expect(find.byIcon(Icons.repeat_rounded), findsNothing, reason: '$size');
      expect(
        find.byIcon(Icons.queue_music_rounded),
        findsNothing,
        reason: '$size',
      );
      expect(
        find.byIcon(Icons.more_horiz_rounded),
        findsNothing,
        reason: '$size',
      );
      expect(
        find.byIcon(Icons.favorite_border_rounded),
        findsOneWidget,
        reason: '$size',
      );
      expect(find.byType(PageView), findsNothing, reason: '$size');
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });

  testWidgets('all player styles stay overflow free in mobile landscape', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(700, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final styleId in AppPlayerStyleRegistry.builtInIds) {
      await tester.pumpWidget(
        _buildPlayerTestApp(
          controllerFactory: _OnlineTrackPlayerController.new,
          config: AppConfigState.initial.copyWith(
            localeCode: 'en',
            playerStyleId: styleId,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('player-mobile-landscape-layout')),
        findsOneWidget,
        reason: styleId,
      );
      if (styleId == AppPlayerStyleRegistry.artistPhotoId) {
        expect(
          tester.widget<PlayerBackdrop>(find.byType(PlayerBackdrop)).isPortrait,
          isFalse,
        );
        expect(
          find.byKey(
            const ValueKey<String>(
              'player-mobile-landscape-artist-photo-content',
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const ValueKey<String>('player-stage-artist-photo-safe-area'),
          ),
          findsNothing,
        );
      }
      expect(tester.takeException(), isNull, reason: styleId);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets(
    'artist photo centers wide lyrics while keeping progress on the left',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(844, 390));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _buildPlayerTestApp(
          controllerFactory: _OnlineTrackPlayerController.new,
          config: AppConfigState.initial.copyWith(
            localeCode: 'en',
            playerStyleId: AppPlayerStyleRegistry.artistPhotoId,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      final layoutRect = tester.getRect(
        find.byKey(const ValueKey<String>('player-mobile-landscape-layout')),
      );
      final contentRect = tester.getRect(
        find.byKey(
          const ValueKey<String>(
            'player-mobile-landscape-artist-photo-content',
          ),
        ),
      );
      final progressRect = tester.getRect(
        find.byKey(const ValueKey<String>('player-progress-slider')),
      );
      final controlsRect = tester.getRect(
        find.byKey(const ValueKey<String>('player-mobile-landscape-controls')),
      );

      expect(contentRect.center.dx, closeTo(layoutRect.center.dx, 0.01));
      expect(contentRect.width, closeTo(layoutRect.width * 0.64, 0.01));
      expect(progressRect.center.dx, lessThan(layoutRect.center.dx));
      expect(controlsRect.center.dx, greaterThan(layoutRect.center.dx));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('mobile landscape respects horizontal and bottom safe areas', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    tester.view.systemGestureInsets = FakeViewPadding(
      left: 44 * tester.view.devicePixelRatio,
      right: 24 * tester.view.devicePixelRatio,
      bottom: 20 * tester.view.devicePixelRatio,
    );
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.view.resetSystemGestureInsets();
    });
    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    final layoutRect = tester.getRect(
      find.byKey(const ValueKey<String>('player-mobile-landscape-layout')),
    );
    final stageRect = tester.getRect(
      find.byKey(const ValueKey<String>('player-mobile-landscape-stage')),
    );
    final playRect = tester.getRect(find.byIcon(Icons.play_arrow_rounded));

    expect(layoutRect.left, 4);
    expect(stageRect.left, greaterThanOrEqualTo(44));
    expect(layoutRect.right, lessThanOrEqualTo(844 - 24));
    expect(playRect.bottom, lessThanOrEqualTo(390 - 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('immersive landscape keeps gestures without hidden bar gaps', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    tester.view.viewPadding = FakeViewPadding(
      left: 36 * tester.view.devicePixelRatio,
      top: 44 * tester.view.devicePixelRatio,
    );
    tester.view.systemGestureInsets = FakeViewPadding(
      left: 16 * tester.view.devicePixelRatio,
      bottom: 20 * tester.view.devicePixelRatio,
    );
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.view.resetViewPadding();
      tester.view.resetSystemGestureInsets();
    });
    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    final layoutRect = tester.getRect(
      find.byKey(const ValueKey<String>('player-mobile-landscape-layout')),
    );
    final playRect = tester.getRect(find.byIcon(Icons.play_arrow_rounded));

    expect(layoutRect.left, 4);
    expect(layoutRect.top, 0);
    expect(playRect.bottom, lessThanOrEqualTo(390 - 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape round trip preserves lyric page and playback state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late _OnlineTrackPlayerController playerController;
    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: () {
          playerController = _OnlineTrackPlayerController();
          return playerController;
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    final pager = tester.widget<PageView>(
      find.byKey(const ValueKey<String>('player-mobile-pager')),
    );
    pager.controller!.jumpToPage(1);
    await tester.pumpAndSettle();
    final lyricState = tester.state(find.byType(PlayerLyricPage));
    final playbackBefore = playerController.snapshot;

    await tester.binding.setSurfaceSize(const Size(932, 430));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('player-mobile-landscape-layout')),
      findsOneWidget,
    );
    expect(tester.state(find.byType(PlayerLyricPage)), same(lyricState));

    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpAndSettle();
    final restoredPager = tester.widget<PageView>(
      find.byKey(const ValueKey<String>('player-mobile-pager')),
    );
    expect(restoredPager.controller!.page, closeTo(1, 0.001));
    expect(tester.state(find.byType(PlayerLyricPage)), same(lyricState));
    expect(
      playerController.snapshot.currentTrack,
      same(playbackBefore.currentTrack),
    );
    expect(playerController.snapshot.isPlaying, playbackBefore.isPlaying);
    expect(playerController.snapshot.position, playbackBefore.position);
    expect(playerController.snapshot.queue, same(playbackBefore.queue));
  });

  testWidgets('mobile landscape actions request and release orientations', (
    tester,
  ) async {
    final orientationRequests = <List<String>>[];
    final systemUiRequests = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            orientationRequests.add(List<String>.from(call.arguments as List));
          }
          if (call.method == 'SystemChrome.setEnabledSystemUIMode' ||
              call.method == 'SystemChrome.setEnabledSystemUIOverlays') {
            systemUiRequests.add(call);
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      debugDefaultTargetPlatformOverride = null;
      tester.binding.setSurfaceSize(null);
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Landscape Mode'), findsOneWidget);
    await _scrollPlayerMoreSheetTo(tester, 'Landscape Mode');
    await tester.tap(find.text('Landscape Mode'));
    await tester.pumpAndSettle();
    expect(orientationRequests.last, <String>[
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);

    await tester.binding.setSurfaceSize(const Size(932, 430));
    await tester.pumpAndSettle();
    expect(systemUiRequests.last.method, 'SystemChrome.setEnabledSystemUIMode');
    expect(systemUiRequests.last.arguments, 'SystemUiMode.immersiveSticky');
    final systemUiRequestCountBeforeExit = systemUiRequests.length;
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await tester.pump();
    expect(orientationRequests.last, <String>[
      'DeviceOrientation.portraitUp',
      'DeviceOrientation.portraitDown',
    ]);
    expect(systemUiRequests, hasLength(systemUiRequestCountBeforeExit));

    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpAndSettle();
    expect(
      systemUiRequests.last.method,
      'SystemChrome.setEnabledSystemUIOverlays',
    );
    expect(systemUiRequests.last.arguments, <String>[
      'SystemUiOverlay.top',
      'SystemUiOverlay.bottom',
    ]);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await _scrollPlayerMoreSheetTo(tester, 'Landscape Mode');
    await tester.tap(find.text('Landscape Mode'));
    await tester.pumpAndSettle();
    expect(orientationRequests.last, <String>[
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(orientationRequests.last, isEmpty);
    expect(
      systemUiRequests.last.method,
      'SystemChrome.setEnabledSystemUIOverlays',
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('automatic rotation enters and leaves immersive system UI', (
    tester,
  ) async {
    final systemUiRequests = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setEnabledSystemUIMode' ||
              call.method == 'SystemChrome.setEnabledSystemUIOverlays') {
            systemUiRequests.add(call);
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      debugDefaultTargetPlatformOverride = null;
      tester.binding.setSurfaceSize(null);
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();

    await tester.binding.setSurfaceSize(const Size(932, 430));
    await tester.pump();
    await tester.pump();
    expect(systemUiRequests.last.method, 'SystemChrome.setEnabledSystemUIMode');
    expect(systemUiRequests.last.arguments, 'SystemUiMode.immersiveSticky');

    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pump();
    await tester.pump();
    expect(
      systemUiRequests.last.method,
      'SystemChrome.setEnabledSystemUIOverlays',
    );
    expect(systemUiRequests.last.arguments, <String>[
      'SystemUiOverlay.top',
      'SystemUiOverlay.bottom',
    ]);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('system back exits mobile landscape before closing player', (
    tester,
  ) async {
    final orientationRequests = <List<String>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            orientationRequests.add(List<String>.from(call.arguments as List));
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
      debugDefaultTargetPlatformOverride = null;
      tester.binding.setSurfaceSize(null);
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await tester.binding.setSurfaceSize(const Size(932, 430));
    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.byType(PlayerPage), findsOneWidget);
    expect(orientationRequests.last, <String>[
      'DeviceOrientation.portraitUp',
      'DeviceOrientation.portraitDown',
    ]);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('desktop platform hides landscape mode action', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      tester.binding.setSurfaceSize(null);
    });
    await tester.binding.setSurfaceSize(const Size(430, 932));
    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Landscape Mode'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final platform in <TargetPlatform>[
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  ]) {
    testWidgets('$platform never uses mobile landscape layout when resized', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(430, 932));
      await tester.pumpWidget(
        _buildPlayerTestApp(
          controllerFactory: _OnlineTrackPlayerController.new,
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.binding.setSurfaceSize(const Size(932, 430));
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('player-mobile-landscape-layout')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('player-desktop-primary-pane')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('player page opens queue bottom sheet on narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.queue_music_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('player-queue-desktop-panel')),
      findsNothing,
    );
  });

  testWidgets('player page hides queue entry in radio mode', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _RadioTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.queue_music_rounded), findsNothing);
  });

  testWidgets('player page hides play mode toggle in radio mode', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _RadioTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.repeat_rounded), findsNothing);
  });

  testWidgets('player page shows radio icon in radio mode', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 960));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _RadioTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.radio_rounded), findsOneWidget);
  });

  testWidgets('player page uses light status bar style while visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildPlayerTestApp(controllerFactory: _OnlineTrackPlayerController.new),
    );
    await tester.pump();
    await tester.pump();

    final overlayRegion = tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byWidgetPredicate(
            (widget) => widget is AnnotatedRegion<SystemUiOverlayStyle>,
          ),
        )
        .last;
    final overlayStyle = overlayRegion.value;

    expect(overlayStyle.statusBarIconBrightness, Brightness.light);
    expect(overlayStyle.statusBarBrightness, Brightness.dark);
    expect(overlayStyle.statusBarColor, Colors.transparent);
  });

  testWidgets('完整播放器快速三次下一曲立即显示 B C D 且正式索引保持 A', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late _TransitionPlayerController controller;

    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: () {
          controller = _TransitionPlayerController();
          return controller;
        },
      ),
    );
    await tester.pump();
    await tester.pump();
    final initialHeaderSize = tester.getSize(
      find.byKey(const ValueKey<String>('player-track-header')),
    );

    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.pump();
    expect(_visiblePlayerTitle(tester), 'Track B');

    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.pump();
    expect(_visiblePlayerTitle(tester), 'Track C');

    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.pump();
    expect(_visiblePlayerTitle(tester), 'Track D');
    expect(controller.nextCalls, 3);
    expect(controller.snapshot.currentIndex, 0);
    expect(controller.snapshot.currentTrack?.id, 'track-a');
    expect(controller.snapshot.displayTrack?.id, 'track-d');
    expect(
      find.byKey(const ValueKey<String>('player-track-preparing-indicator')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('player-track-header'))),
      initialHeaderSize,
    );

    controller.commitRequestedTrack();
    await tester.pump();
    expect(_visiblePlayerTitle(tester), 'Track D');
    expect(controller.snapshot.currentIndex, 3);
    expect(controller.snapshot.isTrackTransitioning, isFalse);
    expect(
      find.byKey(const ValueKey<String>('player-track-preparing-indicator')),
      findsNothing,
    );
  });

  testWidgets('过渡期仅上一下一和队列保持可用', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late _TransitionPlayerController controller;
    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: () {
          controller = _TransitionPlayerController();
          return controller;
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('player-control-preparing-indicator')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Slider>(
            find.byKey(const ValueKey<String>('player-progress-slider')),
          )
          .onChanged,
      isNull,
    );
    expect(
      tester
          .widget<InkWell>(
            find.byKey(const ValueKey<String>('player-compact-lyric-tap')),
          )
          .onTap,
      isNull,
    );
    expect(_iconButton(tester, Icons.repeat_rounded).onPressed, isNull);
    expect(_iconButton(tester, Icons.queue_music_rounded).onPressed, isNotNull);
    expect(_iconButton(tester, Icons.skip_next_rounded).onPressed, isNotNull);
    expect(
      _iconButton(tester, Icons.skip_previous_rounded).onPressed,
      isNotNull,
    );
    expect(_inkResponse(tester, Icons.more_horiz_rounded).onTap, isNull);
    expect(_inkResponse(tester, Icons.favorite_border_rounded).onTap, isNull);
    expect(
      find.byKey(const ValueKey<String>('player-artist-action')),
      findsNothing,
    );

    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.skip_previous_rounded));
    await tester.pump();
    expect(controller.nextCalls, 2);
    expect(controller.previousCalls, 1);
    expect(_visiblePlayerTitle(tester), 'Track B');
  });

  testWidgets('未知目标保留当前标题，准确目标到达后更新，失败时回退', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late _TransitionPlayerController controller;
    await tester.pumpWidget(
      _buildPlayerTestApp(
        controllerFactory: () {
          controller = _TransitionPlayerController();
          return controller;
        },
      ),
    );
    await tester.pump();
    await tester.pump();

    controller.showUnknownTarget();
    await tester.pump();
    expect(_visiblePlayerTitle(tester), 'Track A');
    expect(controller.snapshot.isTrackTransitioning, isTrue);

    controller.showTarget(2);
    await tester.pump();
    expect(_visiblePlayerTitle(tester), 'Track C');
    expect(
      tester.widget<PlayerStyleStage>(find.byType(PlayerStyleStage)).track?.id,
      'track-c',
    );

    controller.failRequestedTrack();
    await tester.pump();
    expect(_visiblePlayerTitle(tester), 'Track A');
    expect(
      tester.widget<PlayerStyleStage>(find.byType(PlayerStyleStage)).track?.id,
      'track-a',
    );
  });

  testWidgets('经典流体和磁带样式都立即接收目标歌曲', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final styleId in const <String>[
      AppPlayerStyleRegistry.classicId,
      AppPlayerStyleRegistry.fluidId,
      AppPlayerStyleRegistry.cassetteId,
    ]) {
      late _TransitionPlayerController controller;
      await tester.pumpWidget(
        _buildPlayerTestApp(
          controllerFactory: () {
            controller = _TransitionPlayerController();
            return controller;
          },
          config: AppConfigState.initial.copyWith(
            localeCode: 'en',
            playerStyleId: styleId,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      controller.showTarget(2);
      await tester.pump();
      final stage = tester.widget<PlayerStyleStage>(
        find.byType(PlayerStyleStage),
      );
      expect(stage.track?.id, 'track-c', reason: styleId);
      if (styleId == AppPlayerStyleRegistry.cassetteId) {
        expect(find.text('Track C'), findsWidgets);
      }
      expect(tester.takeException(), isNull, reason: styleId);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('过渡状态在手机和桌面布局均不溢出', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in const <Size>[Size(320, 568), Size(1440, 960)]) {
      await tester.binding.setSurfaceSize(size);
      late _TransitionPlayerController controller;
      await tester.pumpWidget(
        _buildPlayerTestApp(
          controllerFactory: () {
            controller = _TransitionPlayerController();
            return controller;
          },
        ),
      );
      await tester.pump();
      await tester.pump();
      controller.showTarget(3);
      await tester.pump();

      expect(_visiblePlayerTitle(tester), 'Track D', reason: '$size');
      expect(
        find.byKey(
          const ValueKey<String>('player-control-preparing-indicator'),
        ),
        findsOneWidget,
        reason: '$size',
      );
      expect(tester.takeException(), isNull, reason: '$size');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}

String _visiblePlayerTitle(WidgetTester tester) {
  return tester
      .widget<Text>(find.byKey(const ValueKey<String>('player-track-title')))
      .data!;
}

IconButton _iconButton(WidgetTester tester, IconData icon) {
  return tester.widget<IconButton>(
    find.ancestor(of: find.byIcon(icon), matching: find.byType(IconButton)),
  );
}

InkResponse _inkResponse(WidgetTester tester, IconData icon) {
  return tester.widget<InkResponse>(
    find.ancestor(of: find.byIcon(icon), matching: find.byType(InkResponse)),
  );
}

PartitaLyricPainter _partitaPainter(WidgetTester tester) {
  return tester
          .widget<CustomPaint>(
            find.byKey(const ValueKey<String>('partita-lyric-painter')),
          )
          .painter!
      as PartitaLyricPainter;
}

Widget _buildPlayerTestApp({
  required PlayerController Function() controllerFactory,
  BigInt? featureSupportFlag,
  AppConfigState? config,
  LyricDocument? lyricDocument,
  ScreenWakeLockPort? screenWakeLockPort,
  AudioSpectrumPort? spectrumPort,
  RealtimeSpectrumController? spectrumController,
  VoidCallback? onPlayerPageBuild,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(
        () => _TestAppConfigController(
          config ?? AppConfigState.initial.copyWith(localeCode: 'en'),
        ),
      ),
      playerControllerProvider.overrideWith(controllerFactory),
      if (lyricDocument != null)
        currentLyricDocumentProvider.overrideWithValue(
          AsyncData<LyricDocument>(lyricDocument),
        ),
      if (lyricDocument != null)
        lyricPositionProvider.overrideWith(
          (ref) => ref.watch(_playerTestLyricPositionProvider),
        ),
      if (screenWakeLockPort != null)
        screenWakeLockPortProvider.overrideWithValue(screenWakeLockPort),
      audioSpectrumPortProvider.overrideWithValue(
        spectrumPort ?? const _NoopSpectrumPort(),
      ),
      sleepTimerAudioPortProvider.overrideWithValue(
        const _NoopSleepTimerAudioPort(),
      ),
      if (spectrumController != null)
        realtimeSpectrumControllerProvider.overrideWith(
          () => spectrumController,
        ),
      artistPhotoCacheProvider.overrideWith(_EmptyArtistPhotoCache.new),
      onlinePlatformsProvider.overrideWith(
        () => _TestOnlinePlatformsController(
          featureSupportFlag:
              featureSupportFlag ??
              (PlatformFeatureSupportFlag.getAlbumInfo |
                  PlatformFeatureSupportFlag.getSingerInfo |
                  PlatformFeatureSupportFlag.getCommentList),
        ),
      ),
    ],
    child: MaterialApp(
      navigatorObservers: <NavigatorObserver>[appPageRouteObserver],
      home: AppPlayerStyleBoundary(
        child: PlayerPage(debugOnBuild: onPlayerPageBuild),
      ),
    ),
  );
}

Future<void> _scrollPlayerMoreSheetTo(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    120,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey<String>('player-more-sheet-list')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollSleepTimerSheetTo(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    120,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey<String>('player-sleep-timer-sheet-list')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
}

class _EmptyArtistPhotoCache extends ArtistPhotoCache {
  @override
  Future<List<String>> fetchPhotos({
    required String platform,
    List<String> ids = const <String>[],
    List<String> names = const <String>[],
    bool isPortrait = false,
  }) async {
    return const <String>[];
  }
}

class _TestAppConfigController extends AppConfigController {
  _TestAppConfigController(this.config);

  final AppConfigState config;

  @override
  AppConfigState build() {
    return config;
  }

  @override
  void setPlayerStyleId(String styleId) {
    state = state.copyWith(
      playerStyleId: AppPlayerStyleRegistry.instance.normalizeId(styleId),
    );
  }
}

class _PlayerTestLyricPositionController extends Notifier<Duration> {
  @override
  Duration build() => _monetFixturePosition;

  void update(Duration position) {
    state = position;
  }
}

class _OnlineTrackPlayerController extends PlayerController {
  PlayerPlaybackState get snapshot => state;

  void setPlaybackActivity({required bool isPlaying, required bool isLoading}) {
    state = state.copyWith(isPlaying: isPlaying, isLoading: isLoading);
  }

  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(<PlayerTrack>[
      PlayerTrack(
        id: 'song-1',
        title: '在线歌曲',
        links: <LinkInfo>[
          LinkInfo(
            name: 'SQ',
            quality: 500,
            format: 'mp3',
            size: '3145728',
            url: 'https://example.com/sq.mp3',
          ),
          LinkInfo(
            name: 'HQ',
            quality: 800,
            format: 'flac',
            size: '10485760',
            url: 'https://example.com/hq.flac',
          ),
        ],
        artist: '测试歌手',
        album: '测试专辑',
        albumId: 'album-1',
        artists: <SongInfoArtistInfo>[
          SongInfoArtistInfo(id: 'artist-1', name: '测试歌手'),
        ],
        platform: 'qq',
      ),
    ]).copyWith(
      currentAvailableQualities: const <PlayerQualityOption>[
        PlayerQualityOption(
          name: 'HQ',
          quality: 800,
          format: 'flac',
          url: 'https://example.com/hq.flac',
        ),
        PlayerQualityOption(
          name: 'SQ',
          quality: 500,
          format: 'mp3',
          url: 'https://example.com/sq.mp3',
        ),
      ],
      currentSelectedQualityName: 'HQ',
    );
  }

  @override
  Future<void> initialize() async {}
}

class _WakeLockPlayerController extends _OnlineTrackPlayerController {
  @override
  PlayerPlaybackState build() {
    return super.build().copyWith(isPlaybackSessionActive: true);
  }

  void setPlaybackSessionActive(bool active) {
    state = state.copyWith(isPlaybackSessionActive: active);
  }
}

class _SpectrumPlayerController extends _OnlineTrackPlayerController {
  @override
  PlayerPlaybackState build() {
    return super.build().copyWith(isPlaying: true);
  }
}

class _RecordingRealtimeSpectrumController extends RealtimeSpectrumController {
  final List<bool> visibility = <bool>[];
  bool? _lastVisible;

  @override
  RealtimeSpectrumState build() => RealtimeSpectrumState.initial();

  @override
  void setConsumerVisible(bool visible) {
    if (_lastVisible == visible) {
      return;
    }
    _lastVisible = visible;
    visibility.add(visible);
  }
}

class _NoopSpectrumPort implements AudioSpectrumPort {
  const _NoopSpectrumPort();

  @override
  Stream<AudioSpectrumFrame> get spectrumFrameStream =>
      const Stream<AudioSpectrumFrame>.empty();

  @override
  Future<void> startSpectrumCapture() async {}

  @override
  Future<void> stopSpectrumCapture() async {}
}

class _NoopSleepTimerAudioPort implements SleepTimerAudioPort {
  const _NoopSleepTimerAudioPort();

  @override
  SleepTimerState get currentSleepTimerState => SleepTimerState.inactive;

  @override
  Stream<SleepTimerState> get sleepTimerStateStream =>
      const Stream<SleepTimerState>.empty();

  @override
  Future<void> setSleepTimer(
    Duration duration, {
    required bool stopAfterCurrent,
  }) async {}

  @override
  Future<void> cancelSleepTimer() async {}
}

class _RecordingScreenWakeLockPort implements ScreenWakeLockPort {
  _RecordingScreenWakeLockPort({
    this.failuresRemaining = 0,
    this.onCall,
    this.nextCompletion,
  });

  final List<bool> calls = <bool>[];
  final void Function(bool enabled)? onCall;
  int failuresRemaining;
  Completer<void>? nextCompletion;

  @override
  Future<void> setEnabled(bool enabled) async {
    calls.add(enabled);
    onCall?.call(enabled);
    if (failuresRemaining > 0) {
      failuresRemaining -= 1;
      throw StateError('wake lock failed');
    }
    final completion = nextCompletion;
    nextCompletion = null;
    await completion?.future;
  }
}

class _WakeOwnershipProbe extends StatefulWidget {
  const _WakeOwnershipProbe({required this.events});

  final List<String> events;

  @override
  State<_WakeOwnershipProbe> createState() => _WakeOwnershipProbeState();
}

class _WakeOwnershipProbeState extends State<_WakeOwnershipProbe> {
  @override
  void initState() {
    super.initState();
    widget.events.add('video:true');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.expand());
  }
}

class _LocalTrackPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(
        id: 'local-song-1',
        title: '本地歌曲',
        artist: '本地歌手',
        album: '本地专辑',
        platform: 'local',
        format: 'MP3',
        bitrate: 320,
        sampleRate: 44100,
      ),
    ]);
  }

  @override
  Future<void> initialize() async {}
}

class _RadioTrackPlayerController extends PlayerController {
  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(const <PlayerTrack>[
      PlayerTrack(
        id: 'radio-song-1',
        title: '电台歌曲',
        artist: '电台歌手',
        album: '电台专辑',
        platform: 'qq',
      ),
    ]).copyWith(
      playMode: PlayerPlayMode.sequence,
      isRadioMode: true,
      currentRadioId: 'radio-1',
      currentRadioPlatform: 'qq',
      currentRadioPageIndex: 1,
    );
  }

  @override
  Future<void> initialize() async {}
}

class _TransitionPlayerController extends PlayerController {
  int nextCalls = 0;
  int previousCalls = 0;
  int _transitionId = 100;

  PlayerPlaybackState get snapshot => state;

  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(_transitionTracks);
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> playNext() async {
    nextCalls += 1;
    final sourceIndex = state.requestedTrackIndex ?? state.currentIndex;
    showTarget((sourceIndex + 1) % state.queue.length);
  }

  @override
  Future<void> playPrevious() async {
    previousCalls += 1;
    final sourceIndex = state.requestedTrackIndex ?? state.currentIndex;
    showTarget((sourceIndex - 1 + state.queue.length) % state.queue.length);
  }

  void showUnknownTarget() {
    state = state.copyWith(
      requestedTransitionId: ++_transitionId,
      clearRequestedTrackIndex: true,
    );
  }

  void showTarget(int index) {
    state = state.copyWith(
      requestedTrackIndex: index,
      requestedTransitionId: ++_transitionId,
    );
  }

  void commitRequestedTrack() {
    final targetIndex = state.requestedTrackIndex;
    if (targetIndex == null) return;
    state = state.copyWith(
      currentIndex: targetIndex,
      clearRequestedTrackIndex: true,
      clearRequestedTransitionId: true,
    );
  }

  void failRequestedTrack() {
    state = state.copyWith(
      clearRequestedTrackIndex: true,
      clearRequestedTransitionId: true,
    );
  }
}

const List<PlayerTrack> _transitionTracks = <PlayerTrack>[
  PlayerTrack(
    id: 'track-a',
    title: 'Track A',
    artist: 'Artist A',
    platform: 'qq',
  ),
  PlayerTrack(
    id: 'track-b',
    title: 'Track B',
    artist: 'Artist B',
    platform: 'qq',
  ),
  PlayerTrack(
    id: 'track-c',
    title: 'Track C',
    artist: 'Artist C',
    platform: 'qq',
  ),
  PlayerTrack(
    id: 'track-d',
    title: 'Track D',
    artist: 'Artist D',
    platform: 'qq',
  ),
];

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  _TestOnlinePlatformsController({required this.featureSupportFlag});

  final BigInt featureSupportFlag;

  @override
  Future<List<OnlinePlatform>> build() async {
    return <OnlinePlatform>[
      OnlinePlatform(
        id: 'qq',
        name: 'QQ 音乐',
        shortName: 'QQ',
        status: 1,
        featureSupportFlag: featureSupportFlag,
        qualities: const <String, String>{
          'SQ': 'Standard Quality',
          'HQ': 'High Quality',
        },
      ),
    ];
  }
}
