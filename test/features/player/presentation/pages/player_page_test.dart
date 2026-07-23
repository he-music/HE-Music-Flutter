import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_color.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_mode.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_registry.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_boundary.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_play_mode.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_quality_option.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/pages/player_page.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/styles/player_style_stage.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_lyric_page.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_queue_sheet.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

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
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Add to Playlist'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
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
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download'));
    await tester.pumpAndSettle();

    expect(find.text('Choose Quality'), findsOneWidget);
    expect(find.text('SQ'), findsWidgets);
    expect(find.text('HQ'), findsWidgets);
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
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('View Detail'), findsOneWidget);
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

      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).last, const Offset(0, -600));
      await tester.pumpAndSettle();

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
    await tester.drag(find.byType(ListView).last, const Offset(0, -300));
    await tester.pumpAndSettle();
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
  });

  test('player artist photo direction follows window shape and width', () {
    expect(
      resolvePlayerArtistPhotoPortraitForTest(const Size(1440, 960)),
      isFalse,
    );
    expect(
      resolvePlayerArtistPhotoPortraitForTest(const Size(700, 420)),
      isTrue,
    );
    expect(
      resolvePlayerArtistPhotoPortraitForTest(const Size(430, 1200)),
      isTrue,
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
    tester.view.padding = FakeViewPadding(
      bottom: 34 * tester.view.devicePixelRatio,
    );
    addTearDown(() {
      tester.binding.setSurfaceSize(null);
      tester.view.resetPadding();
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

Widget _buildPlayerTestApp({
  required PlayerController Function() controllerFactory,
  BigInt? featureSupportFlag,
  AppConfigState? config,
}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(
        () => _TestAppConfigController(
          config ?? AppConfigState.initial.copyWith(localeCode: 'en'),
        ),
      ),
      playerControllerProvider.overrideWith(controllerFactory),
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
    child: const MaterialApp(home: AppPlayerStyleBoundary(child: PlayerPage())),
  );
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

class _OnlineTrackPlayerController extends PlayerController {
  PlayerPlaybackState get snapshot => state;

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
