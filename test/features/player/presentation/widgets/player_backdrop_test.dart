import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_models.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/providers/artist_photo_provider.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_backdrop.dart';

void main() {
  test('classic gradient keeps the cover hue recognizable', () {
    final colors = resolveClassicGradientColorsForTest([
      const Color(0xFF1E88E5),
      const Color(0xFF42A5F5),
      const Color(0xFF0D47A1),
    ]);

    expect(colors.length, 4);

    final leading = HSLColor.fromColor(colors.first);
    expect(leading.hue, inInclusiveRange(190, 235));
    expect(leading.saturation, greaterThan(0.18));
    expect(leading.lightness, greaterThan(0.28));
  });

  test('classic gradient derives a complete palette from one seed', () {
    final colors = resolveClassicGradientColorsForTest([
      const Color(0xFF43A047),
    ]);

    expect(colors.length, 4);
    expect(colors.toSet().length, greaterThanOrEqualTo(3));
  });

  test('classic gradient preserves a muted purple mood', () {
    final colors = resolveClassicGradientColorsForTest([
      const Color(0xFFB39AC7),
      const Color(0xFF8F7FA6),
      const Color(0xFF6E678B),
    ]);

    expect(colors.length, 4);

    final averageSaturation =
        colors
            .map((color) => HSLColor.fromColor(color).saturation)
            .reduce((left, right) => left + right) /
        colors.length;
    final averageLightness =
        colors
            .map((color) => HSLColor.fromColor(color).lightness)
            .reduce((left, right) => left + right) /
        colors.length;

    expect(averageSaturation, lessThan(0.55));
    expect(averageLightness, inInclusiveRange(0.28, 0.58));
  });

  test('classic fallback returns a stable cool palette', () {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F8CFF)),
    );

    final colors = fallbackClassicGradientColorsForTest(theme);

    expect(colors.length, 4);
    expect(colors.any((color) => HSLColor.fromColor(color).hue >= 180), isTrue);
  });

  testWidgets('classic backdrop builds without throwing', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlayerBackdrop(
            stageKind: AppPlayerStageKind.classic,
            imageProvider: null,
          ),
        ),
      ),
    );
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.byKey(const ValueKey<String>('player-backdrop-classic')),
      findsOneWidget,
    );
  });

  testWidgets('artist photo cache miss stays neutral while loading', (
    tester,
  ) async {
    final request = Completer<List<String>>();
    final cache = _TestArtistPhotoCache((_) => request.future);
    final container = _createContainer(cache);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildArtistBackdrop(
        container,
        cover: _validImageProvider(),
        photoBuilder: (_) => _validImageProvider(),
      ),
    );

    expect(_artistPhotoStateFinder(ArtistPhotoVisualState.loading), findsOne);
    expect(
      find.byKey(const ValueKey<String>('artist-photo-image-cover')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('artist-photo-neutral-gradient')),
      findsOne,
    );

    request.complete(const <String>['photo-a']);
    await tester.pump();

    expect(_artistPhotoStateFinder(ArtistPhotoVisualState.photo), findsOne);
    expect(
      find.byKey(const ValueKey<String>('artist-photo-image-photo-photo-a')),
      findsOne,
    );
  });

  testWidgets('empty artist photo result displays the full-screen cover', (
    tester,
  ) async {
    final cache = _TestArtistPhotoCache((_) async => const <String>[]);
    final container = _createContainer(cache);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildArtistBackdrop(
        container,
        cover: _validImageProvider(),
        photoBuilder: (_) => _validImageProvider(),
      ),
    );
    await tester.pump();

    expect(
      _artistPhotoStateFinder(ArtistPhotoVisualState.coverFallback),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey<String>('artist-photo-image-cover')),
      findsOne,
    );
  });

  testWidgets('artist photo request failure displays the full-screen cover', (
    tester,
  ) async {
    final cache = _TestArtistPhotoCache(
      (_) => Future<List<String>>.error(StateError('request failed')),
    );
    final container = _createContainer(cache);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildArtistBackdrop(
        container,
        cover: _validImageProvider(),
        photoBuilder: (_) => _validImageProvider(),
      ),
    );
    await tester.pump();

    expect(
      _artistPhotoStateFinder(ArtistPhotoVisualState.coverFallback),
      findsOne,
    );
  });

  testWidgets('artist photo decode failure falls back to the cover', (
    tester,
  ) async {
    final cache = _TestArtistPhotoCache(
      (_) async => const <String>['broken-photo'],
    );
    final container = _createContainer(cache);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildArtistBackdrop(
        container,
        cover: _validImageProvider(),
        photoBuilder: (_) => _invalidImageProvider(),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      _artistPhotoStateFinder(ArtistPhotoVisualState.coverFallback),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey<String>('artist-photo-image-cover')),
      findsOne,
    );
  });

  testWidgets('cover decode failure returns to the neutral gradient', (
    tester,
  ) async {
    final cache = _TestArtistPhotoCache((_) async => const <String>[]);
    final container = _createContainer(cache);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildArtistBackdrop(
        container,
        cover: _invalidImageProvider(),
        photoBuilder: (_) => _validImageProvider(),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      _artistPhotoStateFinder(ArtistPhotoVisualState.neutralGradient),
      findsOne,
    );
    expect(
      find.byKey(const ValueKey<String>('artist-photo-neutral-gradient')),
      findsOne,
    );
  });

  testWidgets('direction change ignores the expired artist photo request', (
    tester,
  ) async {
    final portraitRequest = Completer<List<String>>();
    final landscapeRequest = Completer<List<String>>();
    final cache = _TestArtistPhotoCache(
      (isPortrait) =>
          isPortrait ? portraitRequest.future : landscapeRequest.future,
    );
    final container = _createContainer(cache);
    final isPortrait = ValueNotifier<bool>(true);
    addTearDown(container.dispose);
    addTearDown(isPortrait.dispose);

    await tester.pumpWidget(_buildDynamicArtistBackdrop(container, isPortrait));
    isPortrait.value = false;
    await tester.pump();

    portraitRequest.complete(const <String>['portrait-photo']);
    await tester.pump();
    expect(_artistPhotoStateFinder(ArtistPhotoVisualState.loading), findsOne);
    expect(
      find.byKey(
        const ValueKey<String>('artist-photo-image-photo-portrait-photo'),
      ),
      findsNothing,
    );

    landscapeRequest.complete(const <String>['landscape-photo']);
    await tester.pump();
    expect(
      find.byKey(
        const ValueKey<String>('artist-photo-image-photo-landscape-photo'),
      ),
      findsOne,
    );
    expect(cache.requestedDirections, <bool>[true, false]);
  });

  testWidgets('cached index resumes and advances every twelve seconds', (
    tester,
  ) async {
    const cacheKey = 'qq||Artist|true';
    final cache = _TestArtistPhotoCache(
      (_) => throw StateError('cache hit must not request photos'),
      initialCache: const <String, List<String>>{
        cacheKey: <String>['photo-a', 'photo-b'],
      },
      initialIndices: const <String, int>{cacheKey: 1},
    );
    final container = _createContainer(cache);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _buildArtistBackdrop(
        container,
        cover: _validImageProvider(),
        photoBuilder: (_) => _validImageProvider(),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('artist-photo-image-photo-photo-b')),
      findsOne,
    );
    expect(cache.requestedDirections, isEmpty);

    await tester.pump(const Duration(seconds: 12));

    expect(
      container.read(artistPhotoCacheProvider).currentIndices[cacheKey],
      0,
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(
      find.byKey(const ValueKey<String>('artist-photo-image-photo-photo-a')),
      findsOne,
    );
  });
}

Finder _artistPhotoStateFinder(ArtistPhotoVisualState state) {
  return find.byKey(ValueKey<String>('artist-photo-state-${state.name}'));
}

ProviderContainer _createContainer(ArtistPhotoCache cache) {
  return ProviderContainer(
    overrides: [artistPhotoCacheProvider.overrideWith(() => cache)],
  );
}

Widget _buildArtistBackdrop(
  ProviderContainer container, {
  required ImageProvider<Object>? cover,
  required ArtistPhotoImageProviderBuilder photoBuilder,
}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: PlayerBackdrop(
          stageKind: AppPlayerStageKind.artistPhoto,
          imageProvider: cover,
          track: _track,
          isPortrait: true,
          artistPhotoImageProviderBuilder: photoBuilder,
        ),
      ),
    ),
  );
}

Widget _buildDynamicArtistBackdrop(
  ProviderContainer container,
  ValueNotifier<bool> isPortrait,
) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: ValueListenableBuilder<bool>(
          valueListenable: isPortrait,
          builder: (context, value, child) {
            return PlayerBackdrop(
              stageKind: AppPlayerStageKind.artistPhoto,
              imageProvider: _validImageProvider(),
              track: _track,
              isPortrait: value,
              artistPhotoImageProviderBuilder: (_) => _validImageProvider(),
            );
          },
        ),
      ),
    ),
  );
}

ImageProvider<Object> _validImageProvider() {
  return MemoryImage(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
      '+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    ),
  );
}

ImageProvider<Object> _invalidImageProvider() {
  return MemoryImage(Uint8List.fromList(const <int>[0, 1, 2, 3]));
}

const PlayerTrack _track = PlayerTrack(
  id: 'track-a',
  title: 'Track A',
  artist: 'Artist',
  platform: 'qq',
);

class _TestArtistPhotoCache extends ArtistPhotoCache {
  _TestArtistPhotoCache(
    this.loader, {
    this.initialCache = const <String, List<String>>{},
    this.initialIndices = const <String, int>{},
  });

  final Future<List<String>> Function(bool isPortrait) loader;
  final Map<String, List<String>> initialCache;
  final Map<String, int> initialIndices;
  final List<bool> requestedDirections = <bool>[];

  @override
  ArtistPhotoCacheState build() {
    return ArtistPhotoCacheState(
      cache: initialCache.map(
        (key, urls) => MapEntry(
          key,
          ArtistPhotoCacheEntry(urls: urls, cachedAt: DateTime.now()),
        ),
      ),
      currentIndices: initialIndices,
    );
  }

  @override
  Future<List<String>> fetchPhotos({
    required String platform,
    List<String> ids = const <String>[],
    List<String> names = const <String>[],
    bool isPortrait = false,
  }) async {
    requestedDirections.add(isPortrait);
    final urls = await loader(isPortrait);
    final key = buildCacheKey(platform, ids, names, isPortrait);
    state = ArtistPhotoCacheState(
      cache: <String, ArtistPhotoCacheEntry>{
        ...state.cache,
        key: ArtistPhotoCacheEntry(urls: urls, cachedAt: DateTime.now()),
      },
      currentIndices: state.currentIndices,
    );
    return urls;
  }
}
