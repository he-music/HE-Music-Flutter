import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/player/app_player_style_models.dart';
import '../../domain/entities/player_track.dart';
import '../helpers/player_image_color_helper.dart';
import '../providers/artist_photo_provider.dart';
import '../styles/fluid_player_backdrop.dart';

typedef ArtistPhotoImageProviderBuilder =
    ImageProvider<Object> Function(String url);

enum ArtistPhotoVisualState { loading, photo, coverFallback, neutralGradient }

/// 播放器背景组件。
///
/// 根据 [stageKind] 切换样式背景。歌手写真模式下，
/// 通过 [track] 携带的歌手信息请求写真，同一首歌不重复请求。
class PlayerBackdrop extends ConsumerStatefulWidget {
  const PlayerBackdrop({
    super.key,
    required this.stageKind,
    required this.imageProvider,
    this.track,
    this.isPortrait = false,
    this.artistPhotoImageProviderBuilder,
  });

  final AppPlayerStageKind stageKind;
  final ImageProvider<Object>? imageProvider;
  final PlayerTrack? track;

  /// 竖屏模式标识，用于决定写真请求的方向。
  final bool isPortrait;

  /// 测试可注入固定图片，运行时默认使用网络缓存图片。
  final ArtistPhotoImageProviderBuilder? artistPhotoImageProviderBuilder;

  @override
  ConsumerState<PlayerBackdrop> createState() => _PlayerBackdropState();
}

class _PlayerBackdropState extends ConsumerState<PlayerBackdrop> {
  static const Duration _cycleDuration = Duration(seconds: 12);

  List<String> _photoUrls = const <String>[];
  ArtistPhotoVisualState _artistPhotoState =
      ArtistPhotoVisualState.neutralGradient;
  String? _lastRequestKey;
  String? _cacheKey;
  Timer? _cycleTimer;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _syncArtistPhoto();
  }

  @override
  void didUpdateWidget(covariant PlayerBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncArtistPhoto();
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    super.dispose();
  }

  void _syncArtistPhoto() {
    if (widget.stageKind != AppPlayerStageKind.artistPhoto ||
        widget.track == null) {
      if (_lastRequestKey != null) {
        _requestGeneration++;
      }
      _lastRequestKey = null;
      _cacheKey = null;
      _photoUrls = const <String>[];
      _artistPhotoState = ArtistPhotoVisualState.neutralGradient;
      _cycleTimer?.cancel();
      return;
    }
    final requestKey = _buildRequestKey(widget.track!, widget.isPortrait);
    if (requestKey == _lastRequestKey) return;

    _lastRequestKey = requestKey;
    final generation = ++_requestGeneration;
    _cycleTimer?.cancel();
    _cacheKey = null;
    _photoUrls = const <String>[];

    // 方向隔离缓存命中时直接恢复，否则请求完成前只显示中性渐变。
    final cacheKey = _resolveCacheKey(widget.track!);
    if (cacheKey == null) {
      _artistPhotoState = _coverFallbackState;
      return;
    }
    if (_restoreFromCache(cacheKey)) return;

    _artistPhotoState = ArtistPhotoVisualState.loading;
    _fetchArtistPhoto(
      widget.track!,
      cacheKey: cacheKey,
      generation: generation,
      requestKey: requestKey,
    );
  }

  ArtistPhotoVisualState get _coverFallbackState {
    return widget.imageProvider == null
        ? ArtistPhotoVisualState.neutralGradient
        : ArtistPhotoVisualState.coverFallback;
  }

  bool _isCurrentRequest(int generation, String requestKey) {
    return mounted &&
        generation == _requestGeneration &&
        requestKey == _lastRequestKey;
  }

  void _showCoverFallback(int generation) {
    if (!mounted || generation != _requestGeneration) return;
    _cycleTimer?.cancel();
    setState(() {
      _cacheKey = null;
      _photoUrls = const <String>[];
      _artistPhotoState = _coverFallbackState;
    });
  }

  void _handlePhotoDecodeFailure(int generation, String failedUrl) {
    if (!mounted ||
        generation != _requestGeneration ||
        _artistPhotoState != ArtistPhotoVisualState.photo ||
        _cacheKey == null ||
        _photoUrls.isEmpty) {
      return;
    }
    final index = ref
        .read(artistPhotoCacheProvider.notifier)
        .currentIndex(_cacheKey!);
    final currentUrl = _photoUrls[index.clamp(0, _photoUrls.length - 1)];
    if (currentUrl != failedUrl) return;
    _showCoverFallback(generation);
  }

  void _handleCoverDecodeFailure(int generation) {
    if (!mounted ||
        generation != _requestGeneration ||
        _artistPhotoState != ArtistPhotoVisualState.coverFallback) {
      return;
    }
    setState(() {
      _artistPhotoState = ArtistPhotoVisualState.neutralGradient;
    });
  }

  /// 尝试从 provider 缓存恢复写真列表和索引，成功返回 true。
  bool _restoreFromCache(String cacheKey) {
    final notifier = ref.read(artistPhotoCacheProvider.notifier);
    final urls = notifier.cachedPhotos(cacheKey);
    if (urls == null) return false;
    if (urls.isEmpty) {
      _artistPhotoState = _coverFallbackState;
      return true;
    }
    _photoUrls = urls;
    _cacheKey = cacheKey;
    _artistPhotoState = ArtistPhotoVisualState.photo;
    // 确保索引在有效范围内。
    if (notifier.currentIndex(cacheKey) >= urls.length) {
      notifier.updateIndex(cacheKey, 0);
    }
    _startCycle();
    return true;
  }

  /// 构建与 provider 一致的缓存 key，用于查找缓存。
  String? _resolveCacheKey(PlayerTrack track) {
    final platform = (track.platform ?? '').trim();
    if (platform.isEmpty) return null;
    final ids = track.artists
        .map((a) => a.id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    final names = track.artists
        .map((a) => a.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (ids.isEmpty && names.isEmpty) {
      final fallback = (track.artist ?? '').trim();
      if (fallback.isNotEmpty) {
        names.add(fallback);
      } else {
        return null;
      }
    }
    return ref
        .read(artistPhotoCacheProvider.notifier)
        .buildCacheKey(platform, ids, names, widget.isPortrait);
  }

  void _startCycle() {
    _cycleTimer?.cancel();
    if (_photoUrls.length <= 1 || _cacheKey == null) return;
    _cycleTimer = Timer.periodic(_cycleDuration, (_) {
      if (!mounted || _photoUrls.length <= 1 || _cacheKey == null) return;
      final notifier = ref.read(artistPhotoCacheProvider.notifier);
      final nextIndex =
          (notifier.currentIndex(_cacheKey!) + 1) % _photoUrls.length;
      notifier.updateIndex(_cacheKey!, nextIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cacheKey = _cacheKey;
    final photoIndex = cacheKey != null
        ? ref.watch(
            artistPhotoCacheProvider.select(
              (state) => state.currentIndices[cacheKey] ?? 0,
            ),
          )
        : 0;
    return switch (widget.stageKind) {
      AppPlayerStageKind.classic => _ClassicGradientBackdrop(
        imageProvider: widget.imageProvider,
      ),
      AppPlayerStageKind.fluid => FluidPlayerBackdrop(
        imageProvider: widget.imageProvider,
      ),
      AppPlayerStageKind.vinyl => const _FixedStageBackdrop(
        key: ValueKey<String>('player-backdrop-vinyl'),
        start: Color(0xFF302629),
        end: Color(0xFF090809),
      ),
      AppPlayerStageKind.cassette => const _FixedStageBackdrop(
        key: ValueKey<String>('player-backdrop-cassette'),
        start: Color(0xFF253D3B),
        end: Color(0xFF0B1212),
      ),
      AppPlayerStageKind.artistPhoto => _ArtistPhotoBackdrop(
        visualState: _artistPhotoState,
        imageProvider: _resolveArtistPhotoImageProvider(photoIndex),
        imageKey: _resolveArtistPhotoImageKey(photoIndex),
        onImageError: _resolveArtistPhotoImageError(photoIndex),
      ),
    };
  }

  ImageProvider<Object>? _resolveArtistPhotoImageProvider(int photoIndex) {
    if (_artistPhotoState == ArtistPhotoVisualState.photo &&
        _photoUrls.isNotEmpty) {
      final url = _photoUrls[photoIndex.clamp(0, _photoUrls.length - 1)];
      return widget.artistPhotoImageProviderBuilder?.call(url) ??
          CachedNetworkImageProvider(url);
    }
    if (_artistPhotoState == ArtistPhotoVisualState.coverFallback) {
      return widget.imageProvider;
    }
    return null;
  }

  String _resolveArtistPhotoImageKey(int photoIndex) {
    if (_artistPhotoState == ArtistPhotoVisualState.photo &&
        _photoUrls.isNotEmpty) {
      final url = _photoUrls[photoIndex.clamp(0, _photoUrls.length - 1)];
      return 'artist-photo-image-photo-$url';
    }
    return 'artist-photo-image-cover';
  }

  VoidCallback? _resolveArtistPhotoImageError(int photoIndex) {
    final generation = _requestGeneration;
    if (_artistPhotoState == ArtistPhotoVisualState.photo &&
        _photoUrls.isNotEmpty) {
      final url = _photoUrls[photoIndex.clamp(0, _photoUrls.length - 1)];
      return () => _handlePhotoDecodeFailure(generation, url);
    }
    if (_artistPhotoState == ArtistPhotoVisualState.coverFallback) {
      return () => _handleCoverDecodeFailure(generation);
    }
    return null;
  }

  /// 构建歌曲和方向维度的请求 generation key。
  String _buildRequestKey(PlayerTrack track, bool isPortrait) {
    final ids = track.artists
        .map((a) => a.id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    final names = track.artists
        .map((a) => a.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (ids.isEmpty && names.isEmpty) {
      final fallback = (track.artist ?? '').trim();
      names.add(fallback);
    }
    return '${track.platform ?? ""}|${track.id}|${ids.join(",")}|'
        '${names.join(",")}|$isPortrait';
  }

  /// 异步获取歌手写真列表，成功后启动轮播。
  Future<void> _fetchArtistPhoto(
    PlayerTrack track, {
    required String cacheKey,
    required int generation,
    required String requestKey,
  }) async {
    final platform = (track.platform ?? '').trim();
    if (platform.isEmpty) {
      _showCoverFallback(generation);
      return;
    }

    final ids = track.artists
        .map((a) => a.id.trim())
        .where((id) => id.isNotEmpty)
        .toList();
    final names = track.artists
        .map((a) => a.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (ids.isEmpty && names.isEmpty) {
      final fallback = (track.artist ?? '').trim();
      if (fallback.isNotEmpty) names.add(fallback);
    }
    if (ids.isEmpty && names.isEmpty) {
      _showCoverFallback(generation);
      return;
    }

    try {
      final urls = await ref
          .read(artistPhotoCacheProvider.notifier)
          .fetchPhotos(
            platform: platform,
            ids: ids,
            names: names,
            isPortrait: widget.isPortrait,
          );
      if (!_isCurrentRequest(generation, requestKey)) return;
      if (urls.isEmpty) {
        _showCoverFallback(generation);
        return;
      }
      setState(() {
        _photoUrls = urls;
        _cacheKey = cacheKey;
        _artistPhotoState = ArtistPhotoVisualState.photo;
      });
      // 确保索引在有效范围内，超出时重置为 0。
      final notifier = ref.read(artistPhotoCacheProvider.notifier);
      if (notifier.currentIndex(cacheKey) >= urls.length) {
        notifier.updateIndex(cacheKey, 0);
      }
      _startCycle();
    } catch (_) {
      if (_isCurrentRequest(generation, requestKey)) {
        _showCoverFallback(generation);
      }
    }
  }
}

class _FixedStageBackdrop extends StatelessWidget {
  const _FixedStageBackdrop({
    required this.start,
    required this.end,
    super.key,
  });

  final Color start;
  final Color end;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[start, end],
        ),
      ),
    );
  }
}

class _ArtistPhotoBackdrop extends StatelessWidget {
  const _ArtistPhotoBackdrop({
    required this.visualState,
    required this.imageProvider,
    required this.imageKey,
    required this.onImageError,
  });

  final ArtistPhotoVisualState visualState;
  final ImageProvider<Object>? imageProvider;
  final String imageKey;
  final VoidCallback? onImageError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;
    final image = imageProvider;
    return Stack(
      key: const ValueKey<String>('player-backdrop-artist-photo'),
      fit: StackFit.expand,
      children: <Widget>[
        // 底层渐变兜底，防止图片加载失败时纯黑。
        DecoratedBox(
          key: const ValueKey<String>('artist-photo-neutral-gradient'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                primary.withValues(alpha: 0.16),
                secondary.withValues(alpha: 0.16),
                const Color(0xFF0E1715),
                Colors.black.withValues(alpha: 0.96),
              ],
            ),
          ),
        ),
        // 歌手写真或封面替代图全屏展示，切换时淡入淡出。
        Positioned.fill(
          child: KeyedSubtree(
            key: ValueKey<String>('artist-photo-state-${visualState.name}'),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              child: image == null
                  ? const SizedBox.shrink()
                  : SizedBox.expand(
                      key: ValueKey<String>(imageKey),
                      child: Image(
                        image: image,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          final callback = onImageError;
                          if (callback != null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              callback();
                            });
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
            ),
          ),
        ),
        // 半透明遮罩保证歌词可读性。
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.black.withValues(alpha: 0.12),
                Colors.black.withValues(alpha: 0.24),
                Colors.black.withValues(alpha: 0.24),
              ],
              stops: const <double>[0, 0.42, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _ClassicGradientBackdrop extends StatefulWidget {
  const _ClassicGradientBackdrop({required this.imageProvider});

  final ImageProvider<Object>? imageProvider;

  @override
  State<_ClassicGradientBackdrop> createState() =>
      _ClassicGradientBackdropState();
}

class _ClassicGradientBackdropState extends State<_ClassicGradientBackdrop> {
  static const Duration _paletteTransitionDuration = Duration(
    milliseconds: 900,
  );

  int _paletteGeneration = 0;
  int _paletteVersion = 0;
  List<Color> _currentPalette = const <Color>[];
  List<Color> _previousPalette = const <Color>[];

  @override
  void initState() {
    super.initState();
    _refreshPalette();
  }

  @override
  void didUpdateWidget(covariant _ClassicGradientBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider) {
      _refreshPalette();
    }
  }

  Future<void> _refreshPalette() async {
    final generation = ++_paletteGeneration;
    final resolved = await _loadPalette(widget.imageProvider);
    if (!mounted || generation != _paletteGeneration) return;
    setState(() {
      _previousPalette = _currentPalette.isEmpty
          ? resolved
          : List<Color>.of(_currentPalette);
      _currentPalette = resolved;
      _paletteVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallbackColors = _fallbackClassicColors(theme);
    final targetColors = _currentPalette.isNotEmpty
        ? _currentPalette
        : fallbackColors;
    final previousColors = _previousPalette.isNotEmpty
        ? _previousPalette
        : targetColors;

    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(_paletteVersion),
      tween: Tween<double>(begin: 0, end: 1),
      duration: _paletteTransitionDuration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final colors = _blendPalette(previousColors, targetColors, value);
        return Stack(
          key: const ValueKey<String>('player-backdrop-classic'),
          fit: StackFit.expand,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: _buildClassicGradient(colors),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.02),
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.18),
                    Colors.black.withValues(alpha: 0.38),
                  ],
                  stops: const <double>[0, 0.35, 0.70, 1],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

Future<List<Color>> _loadPalette(ImageProvider<Object>? imageProvider) async {
  final colors = await colorsFromImageProvider(imageProvider);
  return _resolveClassicColors(colors);
}

@visibleForTesting
List<Color> resolveClassicGradientColorsForTest(List<Color> colors) {
  return _resolveClassicColors(colors);
}

List<Color> _resolveClassicColors(List<Color> candidates) {
  final unique = _deduplicateColors(candidates);
  if (unique.isEmpty) {
    return const <Color>[];
  }

  final dominant = unique.first;
  final highlight =
      _pickFurthestHue(unique, dominant, preferLighter: true) ?? dominant;
  final support = _pickSecondDarkest(unique) ?? dominant;
  final accent =
      _pickFurthestHue(unique, support, preferLighter: false) ?? support;

  return _expandClassicPalette(<Color>[
    _normalizeClassicColor(dominant, tone: _ClassicTone.base),
    _normalizeClassicColor(highlight, tone: _ClassicTone.highlight),
    _normalizeClassicColor(support, tone: _ClassicTone.base),
    _normalizeClassicColor(
      _deriveClassicColor(accent, shiftDegrees: 12, lightnessDelta: -0.04),
      tone: _ClassicTone.anchor,
    ),
  ]);
}

List<Color> _deduplicateColors(List<Color> colors) {
  final unique = <Color>[];
  for (final color in colors) {
    if (unique.any((existing) => _isColorTooClose(existing, color))) {
      continue;
    }
    unique.add(color);
  }
  return unique;
}

enum _ClassicTone { base, highlight, anchor }

Color _normalizeClassicColor(Color color, {required _ClassicTone tone}) {
  final hsl = HSLColor.fromColor(color);
  final saturation = switch (tone) {
    _ClassicTone.highlight => hsl.saturation.clamp(0.16, 0.42),
    _ClassicTone.anchor => hsl.saturation.clamp(0.12, 0.32),
    _ClassicTone.base => hsl.saturation.clamp(0.14, 0.38),
  };
  final lightness = switch (tone) {
    _ClassicTone.highlight => hsl.lightness.clamp(0.30, 0.48),
    _ClassicTone.anchor => hsl.lightness.clamp(0.10, 0.24),
    _ClassicTone.base => hsl.lightness.clamp(0.22, 0.40),
  };
  return hsl.withSaturation(saturation).withLightness(lightness).toColor();
}

Color _deriveClassicColor(
  Color base, {
  required double shiftDegrees,
  required double lightnessDelta,
}) {
  final hsl = HSLColor.fromColor(base);
  final hue = (hsl.hue + shiftDegrees) % 360;
  return hsl
      .withHue(hue)
      .withSaturation((hsl.saturation + 0.01).clamp(0.0, 1.0))
      .withLightness((hsl.lightness + lightnessDelta).clamp(0.0, 1.0))
      .toColor();
}

bool _isColorTooClose(Color left, Color right) {
  final leftHsl = HSLColor.fromColor(left);
  final rightHsl = HSLColor.fromColor(right);
  final hueDiff = (leftHsl.hue - rightHsl.hue).abs();
  final normalizedHueDiff = hueDiff > 180 ? 360 - hueDiff : hueDiff;
  return normalizedHueDiff < 10 &&
      (leftHsl.saturation - rightHsl.saturation).abs() < 0.08 &&
      (leftHsl.lightness - rightHsl.lightness).abs() < 0.08;
}

Color? _pickSecondDarkest(List<Color> colors) {
  if (colors.length < 2) {
    return colors.isEmpty ? null : colors.first;
  }
  final sorted = List<Color>.of(colors)
    ..sort((left, right) {
      final leftLightness = HSLColor.fromColor(left).lightness;
      final rightLightness = HSLColor.fromColor(right).lightness;
      return leftLightness.compareTo(rightLightness);
    });
  return sorted[1];
}

Color? _pickFurthestHue(
  List<Color> colors,
  Color seed, {
  required bool preferLighter,
}) {
  if (colors.isEmpty) {
    return null;
  }
  final seedHsl = HSLColor.fromColor(seed);
  final sorted = List<Color>.of(colors)
    ..sort((left, right) {
      final leftHsl = HSLColor.fromColor(left);
      final rightHsl = HSLColor.fromColor(right);
      final leftDiff = _circularHueDistance(seedHsl.hue, leftHsl.hue);
      final rightDiff = _circularHueDistance(seedHsl.hue, rightHsl.hue);
      // 优先选色相差异最大的
      if (leftDiff != rightDiff) {
        return rightDiff.compareTo(leftDiff);
      }
      if (preferLighter) {
        return rightHsl.lightness.compareTo(leftHsl.lightness);
      }
      return leftHsl.lightness.compareTo(rightHsl.lightness);
    });
  return sorted.first;
}

double _circularHueDistance(double left, double right) {
  final diff = (left - right).abs();
  return diff > 180 ? 360 - diff : diff;
}

List<Color> _expandClassicPalette(List<Color> seeds) {
  final colors = <Color>[];
  for (final seed in seeds) {
    if (!colors.any((existing) => _isColorTooClose(existing, seed))) {
      colors.add(seed);
    }
  }

  var index = 0;
  while (colors.length < 4) {
    final base = colors.isEmpty ? const Color(0xFF4C86D9) : colors[index];
    final tone = colors.length == 2 ? _ClassicTone.anchor : _ClassicTone.base;
    colors.add(
      _normalizeClassicColor(
        _deriveClassicColor(
          base,
          shiftDegrees: index.isEven ? 12 : -10,
          lightnessDelta: index.isEven ? 0.03 : -0.03,
        ),
        tone: tone,
      ),
    );
    index = (index + 1) % colors.length;
  }
  return colors;
}

@visibleForTesting
List<Color> fallbackClassicGradientColorsForTest(ThemeData theme) {
  return _fallbackClassicColors(theme);
}

List<Color> _fallbackClassicColors(ThemeData theme) {
  final seed = Color.lerp(
    theme.colorScheme.primary,
    theme.colorScheme.secondary,
    0.35,
  )!;
  return _expandClassicPalette(<Color>[
    _normalizeClassicColor(seed, tone: _ClassicTone.base),
    _normalizeClassicColor(
      theme.colorScheme.tertiary,
      tone: _ClassicTone.highlight,
    ),
    _normalizeClassicColor(
      _deriveClassicColor(seed, shiftDegrees: -18, lightnessDelta: -0.12),
      tone: _ClassicTone.anchor,
    ),
  ]);
}

LinearGradient _buildClassicGradient(List<Color> colors) {
  final topColor = Color.lerp(colors[0], colors[1], 0.08)!;
  final middleColor = Color.lerp(colors[0], colors[2], 0.28)!;
  final bottomColor = Color.lerp(colors[3], colors[0], 0.16)!;
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[topColor, middleColor, bottomColor],
    stops: const <double>[0, 0.52, 1],
  );
}

List<Color> _blendPalette(List<Color> from, List<Color> to, double value) {
  final length = from.length > to.length ? from.length : to.length;
  return List<Color>.generate(length, (index) {
    final left = from[index % from.length];
    final right = to[index % to.length];
    return Color.lerp(left, right, value) ?? right;
  });
}
