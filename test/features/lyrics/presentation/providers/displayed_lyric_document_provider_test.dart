import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_lyric_auxiliary_mode.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_request.dart';
import 'package:he_music_flutter/features/lyrics/presentation/providers/lyrics_providers.dart';

void main() {
  final nextStates = <String, AsyncValue<CurrentLyricStoreState>>{
    'data': const AsyncData(_newLyrics),
    'loading': const AsyncLoading(),
    'error': AsyncError(StateError('歌词加载失败'), StackTrace.current),
  };
  final expectedText = {
    'data': 'new|新歌词|新翻译',
    'loading': 'loading',
    'error': 'error: Bad state: 歌词加载失败',
  };

  for (final entry in nextStates.entries) {
    testWidgets(
      'remounting displayed lyrics during layout reads hidden ${entry.key} updates safely',
      (tester) async {
        final container = _createContainer();
        await tester.pumpWidget(_buildApp(container, showLyrics: true));
        await tester.pumpAndSettle();
        expect(find.text('old|旧歌词|旧翻译'), findsOneWidget);
        final store =
            container.read(currentLyricStoreProvider.notifier)
                as _TestLyricStoreController;

        await tester.pumpWidget(_buildApp(container, showLyrics: false));
        store.setValue(entry.value);
        await tester.pumpWidget(_buildApp(container, showLyrics: true));

        expect(tester.takeException(), isNull);
        expect(find.text(expectedText[entry.key]!), findsOneWidget);
        expect(container.read(currentLyricStoreProvider.notifier), same(store));
        expect(store.buildCount, 1);
      },
    );
  }

  testWidgets('remounting lyrics uses the latest auxiliary mode', (
    tester,
  ) async {
    final container = _createContainer();
    await tester.pumpWidget(_buildApp(container, showLyrics: true));
    await tester.pumpAndSettle();
    expect(find.text('old|旧歌词|旧翻译'), findsOneWidget);

    await tester.pumpWidget(_buildApp(container, showLyrics: false));
    (container.read(appConfigProvider.notifier) as _TestConfigController)
        .setAuxiliaryMode(AppLyricAuxiliaryMode.romanization);
    (container.read(currentLyricStoreProvider.notifier)
            as _TestLyricStoreController)
        .setValue(const AsyncData(_newLyrics));
    await tester.pumpWidget(_buildApp(container, showLyrics: true));

    expect(tester.takeException(), isNull);
    expect(find.text('new|新歌词|new romanization'), findsOneWidget);
  });

  testWidgets('visible lyrics react to track and auxiliary mode changes', (
    tester,
  ) async {
    final container = _createContainer();
    await tester.pumpWidget(_buildApp(container, showLyrics: true));
    await tester.pumpAndSettle();
    expect(find.text('old|旧歌词|旧翻译'), findsOneWidget);

    (container.read(currentLyricStoreProvider.notifier)
            as _TestLyricStoreController)
        .setValue(const AsyncData(_newLyrics));
    await tester.pump();
    expect(find.text('new|新歌词|新翻译'), findsOneWidget);

    final config =
        container.read(appConfigProvider.notifier) as _TestConfigController;
    config.setAuxiliaryMode(AppLyricAuxiliaryMode.romanization);
    await tester.pump();
    expect(find.text('new|新歌词|new romanization'), findsOneWidget);

    config.setAuxiliaryMode(AppLyricAuxiliaryMode.off);
    await tester.pump();
    expect(find.text('new|新歌词|'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ProviderContainer _createContainer() {
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWith(_TestConfigController.new),
      currentLyricStoreProvider.overrideWith(_TestLyricStoreController.new),
    ],
  );
  addTearDown(container.dispose);
  // Mirror the app's persistent background lyric subscription.
  final prefetch = container.listen(lyricsPrefetchBindingProvider, (_, _) {});
  addTearDown(prefetch.close);
  return container;
}

Widget _buildApp(ProviderContainer container, {required bool showLyrics}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) => showLyrics
              ? const _DisplayedLyricHost()
              : const SizedBox.shrink(),
        ),
      ),
    ),
  );
}

class _DisplayedLyricHost extends ConsumerWidget {
  const _DisplayedLyricHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document = ref.watch(displayedLyricDocumentProvider);
    final request = ref.watch(currentLyricRequestProvider);
    return Text(
      document.when(
        data: (value) {
          final line = value.lines.single;
          return '${request?.trackId}|${line.text}|${line.translation}';
        },
        loading: () => 'loading',
        error: (error, stackTrace) => 'error: $error',
      ),
    );
  }
}

class _TestConfigController extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial;

  void setAuxiliaryMode(AppLyricAuxiliaryMode mode) {
    state = state.copyWith(lyricAuxiliaryMode: mode);
  }
}

class _TestLyricStoreController extends CurrentLyricStoreController {
  int buildCount = 0;

  @override
  Future<CurrentLyricStoreState> build() async {
    buildCount++;
    return const CurrentLyricStoreState(
      request: LyricRequest(trackId: 'old'),
      document: AsyncData(
        LyricDocument(
          lines: [
            LyricLine(start: Duration.zero, text: '旧歌词', translation: '旧翻译'),
          ],
        ),
      ),
    );
  }

  void setValue(AsyncValue<CurrentLyricStoreState> value) => state = value;
}

const _newLyrics = CurrentLyricStoreState(
  request: LyricRequest(trackId: 'new'),
  document: AsyncData(
    LyricDocument(
      lines: [
        LyricLine(
          start: Duration.zero,
          text: '新歌词',
          translation: '新翻译',
          romanization: 'new romanization',
        ),
      ],
    ),
  ),
);
