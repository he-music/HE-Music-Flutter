import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_boundary.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_registry.dart';
import 'package:he_music_flutter/core/audio/audio_player_port.dart';
import 'package:he_music_flutter/core/audio/audio_track.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_playback_state.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_quality_option.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/controllers/player_controller.dart';
import 'package:he_music_flutter/features/player/presentation/pages/player_page.dart';
import 'package:he_music_flutter/features/player/presentation/providers/artist_photo_provider.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_audio_provider.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';

const _previewSize = Size(360, 640);
const _previewKey = ValueKey<String>('player-style-preview-golden-root');
const _previewFontFamily = 'PlayerPreviewRoboto';
const _previewCjkFontFamily = 'PlayerPreviewCjk';
const _previewFontFallback = <String>[_previewCjkFontFamily];

late Uint8List _artworkBytes;
late Uint8List _artistPhotoBytes;

// 预览基准图在 macOS 生成；Linux 渲染存在稳定像素差异，不做逐像素比较。
void main() {
  testWidgets('player style previews match the real player scene', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await _loadPreviewFonts();
      _artworkBytes = await File('assets/icons/logo.png').readAsBytes();
      _artistPhotoBytes = await File(
        'assets/skins/city_sound_creator/wallpaper_dark.png',
      ).readAsBytes();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _previewSize;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final style in AppPlayerStyleRegistry.instance.styles) {
      await tester.pumpWidget(_buildPreviewApp(style.metadata.id));
      await tester.pumpAndSettle();
      await _pumpUntilImagesDecoded(tester);

      await expectLater(
        find.byKey(_previewKey),
        matchesGoldenFile(
          '../../../../assets/player_styles/${style.metadata.id}/preview.png',
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  }, skip: Platform.isLinux);

  testWidgets('desktop player styles match the side by side scene', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await _loadPreviewFonts();
      _artworkBytes = await File('assets/icons/logo.png').readAsBytes();
      _artistPhotoBytes = await File(
        'assets/skins/city_sound_creator/wallpaper_dark.png',
      ).readAsBytes();
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 768);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final style in AppPlayerStyleRegistry.instance.styles) {
      await tester.pumpWidget(_buildPreviewApp(style.metadata.id));
      await tester.pumpAndSettle();
      await _pumpUntilImagesDecoded(tester);

      await expectLater(
        find.byKey(_previewKey),
        matchesGoldenFile(
          'goldens/player_styles/desktop_${style.metadata.id}.png',
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  }, skip: Platform.isLinux);

  testWidgets(
    'artist photo fallback scenes stay within the same layout',
    (tester) async {
      await tester.runAsync(() async {
        await _loadPreviewFonts();
        _artworkBytes = await File('assets/icons/logo.png').readAsBytes();
        _artistPhotoBytes = await File(
          'assets/skins/city_sound_creator/wallpaper_dark.png',
        ).readAsBytes();
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = _previewSize;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      for (final scene in <({bool includeArtwork, String name})>[
        (includeArtwork: true, name: 'cover_fallback'),
        (includeArtwork: false, name: 'neutral_fallback'),
      ]) {
        await tester.pumpWidget(
          _buildPreviewApp(
            AppPlayerStyleRegistry.artistPhotoId,
            artistPhotoMode: _PreviewArtistPhotoMode.empty,
            includeArtwork: scene.includeArtwork,
          ),
        );
        await tester.pumpAndSettle();
        if (scene.includeArtwork) {
          await _pumpUntilImagesDecoded(tester);
        }

        await expectLater(
          find.byKey(_previewKey),
          matchesGoldenFile(
            'goldens/player_styles/artist_photo_${scene.name}.png',
          ),
        );

        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      }
    },
    skip: Platform.isLinux,
  );

  test('player style preview assets match metadata and provenance', () async {
    final pubspec = await File('pubspec.yaml').readAsString();
    final provenance = await File(
      'assets/player_styles/artist_photo/LICENSES.md',
    ).readAsString();

    for (final style in AppPlayerStyleRegistry.instance.styles) {
      final path = style.metadata.previewAsset;
      final bytes = await File(path).readAsBytes();
      final hash = sha256.convert(bytes).toString();

      expect(_pngSize(bytes), (360, 640), reason: path);
      expect(pubspec, contains('    - $path'));
      expect(provenance, contains(path));
      expect(provenance, contains(hash));
    }

    expect(provenance, contains('make player-style-previews'));
    expect(provenance, contains('gpt-image-2'));
    expect(
      provenance,
      contains(
        '3b2cd675bc05b23fc37f98587d6da017f7a0bf4734d2e5ccc381e4b99eceef17',
      ),
    );
  });
}

(int, int) _pngSize(Uint8List bytes) {
  const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length < 24) {
    throw const FormatException('PNG header is incomplete');
  }
  for (var index = 0; index < signature.length; index++) {
    if (bytes[index] != signature[index]) {
      throw const FormatException('Invalid PNG signature');
    }
  }
  final header = ByteData.sublistView(bytes);
  return (header.getUint32(16), header.getUint32(20));
}

Widget _buildPreviewApp(
  String styleId, {
  _PreviewArtistPhotoMode artistPhotoMode = _PreviewArtistPhotoMode.photo,
  bool includeArtwork = true,
}) {
  final baseTheme = ThemeData.dark(useMaterial3: true);
  final textTheme = baseTheme.textTheme.apply(
    fontFamily: _previewFontFamily,
    fontFamilyFallback: _previewFontFallback,
  );
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(
        () => _PreviewAppConfigController(styleId),
      ),
      playerControllerProvider.overrideWith(
        () => _PreviewPlayerController(includeArtwork: includeArtwork),
      ),
      audioPlayerPortProvider.overrideWithValue(
        const _PreviewAudioPlayerPort(),
      ),
      artistPhotoCacheProvider.overrideWith(
        () => _PreviewArtistPhotoCache(artistPhotoMode),
      ),
      onlinePlatformsProvider.overrideWith(
        _PreviewOnlinePlatformsController.new,
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: baseTheme.copyWith(
        platform: TargetPlatform.android,
        textTheme: textTheme,
        primaryTextTheme: baseTheme.primaryTextTheme.apply(
          fontFamily: _previewFontFamily,
          fontFamilyFallback: _previewFontFallback,
        ),
      ),
      home: Builder(
        builder: (context) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: RepaintBoundary(
              key: _previewKey,
              child: AppPlayerStyleBoundary(
                child: Builder(
                  builder: (playerContext) {
                    final playerTheme = Theme.of(playerContext);
                    return Theme(
                      data: playerTheme.copyWith(
                        textTheme: playerTheme.textTheme.apply(
                          fontFamily: _previewFontFamily,
                          fontFamilyFallback: _previewFontFallback,
                        ),
                        primaryTextTheme: playerTheme.primaryTextTheme.apply(
                          fontFamily: _previewFontFamily,
                          fontFamilyFallback: _previewFontFallback,
                        ),
                      ),
                      child: PlayerPage(
                        artistPhotoImageProviderBuilder: (_) =>
                            MemoryImage(_artistPhotoBytes),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

Future<void> _loadPreviewFonts() async {
  final textLoader = FontLoader(_previewFontFamily)
    ..addFont(_fontData('test/assets/fonts/Roboto-Regular.ttf'))
    ..addFont(_fontData('test/assets/fonts/Roboto-Medium.ttf'))
    ..addFont(_fontData('test/assets/fonts/Roboto-Bold.ttf'));
  final cjkLoader = FontLoader(_previewCjkFontFamily)
    ..addFont(
      _fontData('test/assets/fonts/DroidSansFallback-PreviewSubset.ttf'),
    );
  final iconLoader = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await Future.wait(<Future<void>>[
    textLoader.load(),
    cjkLoader.load(),
    iconLoader.load(),
  ]);
}

Future<ByteData> _fontData(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.sublistView(bytes);
}

Future<void> _pumpUntilImagesDecoded(WidgetTester tester) async {
  const attempts = 120;
  for (var attempt = 0; attempt < attempts; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    final images = tester.widgetList<RawImage>(find.byType(RawImage)).toList();
    if (images.isNotEmpty && images.every((image) => image.image != null)) {
      await tester.pumpAndSettle();
      return;
    }
  }
  throw TestFailure('播放器样式预览图片在 6 秒内未完成解码');
}

class _PreviewAppConfigController extends AppConfigController {
  _PreviewAppConfigController(this.styleId);

  final String styleId;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      localeCode: 'zh',
      playerStyleId: styleId,
    );
  }
}

class _PreviewPlayerController extends PlayerController {
  _PreviewPlayerController({required this.includeArtwork});

  final bool includeArtwork;

  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(<PlayerTrack>[
      PlayerTrack(
        id: 'preview-track',
        title: '城市回声',
        artist: '林诺',
        album: '信号房间',
        artworkBytes: includeArtwork ? _artworkBytes : null,
        platform: 'platform-1',
      ),
    ]).copyWith(
      position: const Duration(minutes: 1, seconds: 24),
      duration: const Duration(minutes: 3, seconds: 48),
      currentSelectedQualityName: 'HQ',
      currentAvailableQualities: const <PlayerQualityOption>[
        PlayerQualityOption(name: 'HQ', quality: 800, format: 'flac', url: ''),
      ],
    );
  }

  @override
  Future<void> initialize() async {}
}

class _PreviewArtistPhotoCache extends ArtistPhotoCache {
  _PreviewArtistPhotoCache(this.mode);

  final _PreviewArtistPhotoMode mode;

  @override
  ArtistPhotoCacheState build() {
    final urls = mode == _PreviewArtistPhotoMode.photo
        ? const <String>['preview-artist-photo']
        : const <String>[];
    const portraitKey = 'platform-1||林诺|true';
    const landscapeKey = 'platform-1||林诺|false';
    return ArtistPhotoCacheState(
      cache: <String, ArtistPhotoCacheEntry>{
        portraitKey: ArtistPhotoCacheEntry(
          urls: urls,
          cachedAt: _previewCacheTime,
        ),
        landscapeKey: ArtistPhotoCacheEntry(
          urls: urls,
          cachedAt: _previewCacheTime,
        ),
      },
      currentIndices: const <String, int>{portraitKey: 0, landscapeKey: 0},
    );
  }
}

final DateTime _previewCacheTime = DateTime(2099);

enum _PreviewArtistPhotoMode { photo, empty }

class _PreviewOnlinePlatformsController extends OnlinePlatformsController {
  @override
  Future<List<OnlinePlatform>> build() async => const <OnlinePlatform>[];
}

class _PreviewAudioPlayerPort implements AudioPlayerPort {
  const _PreviewAudioPlayerPort();

  @override
  Stream<bool> get playingStream => const Stream<bool>.empty();

  @override
  Stream<bool> get loadingStream => const Stream<bool>.empty();

  @override
  Stream<bool> get completedStream => const Stream<bool>.empty();

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Stream<Duration?> get durationStream => const Stream<Duration?>.empty();

  @override
  Stream<int?> get currentIndexStream => const Stream<int?>.empty();

  @override
  Stream<dynamic> get customEventStream => const Stream<dynamic>.empty();

  @override
  Future<CurrentLyricStateSnapshot> getCurrentLyricState() async {
    return const CurrentLyricStateSnapshot();
  }

  @override
  Future<void> setQueue(
    List<AudioTrack> tracks, {
    int initialIndex = 0,
    bool forceReloadCurrent = false,
    bool isRadioMode = false,
    String? currentRadioId,
    String? currentRadioPlatform,
    int? currentRadioPageIndex,
  }) async {}

  @override
  Future<void> setSource(AudioTrack track) async {}

  @override
  Future<void> playAt(int index) async {}

  @override
  Future<void> seekToNext() async {}

  @override
  Future<void> seekToPrevious() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setSingleLoop(bool enabled) async {}

  @override
  Future<void> setShuffle(bool enabled) async {}

  @override
  Future<void> dispose() async {}
}
