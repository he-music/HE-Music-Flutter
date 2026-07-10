import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mesh_gradient/mesh_gradient.dart';

import '../../../../app/config/app_player_background_style.dart';
import '../../domain/entities/player_track.dart';
import '../helpers/player_image_color_helper.dart';
import '../providers/artist_photo_provider.dart';

/// 播放器背景组件。
///
/// 根据 [style] 切换不同背景模式。歌手写真模式下，
/// 通过 [track] 携带的歌手信息请求写真，同一首歌不重复请求。
class PlayerBackdrop extends ConsumerStatefulWidget {
  const PlayerBackdrop({
    super.key,
    required this.style,
    required this.imageProvider,
    this.track,
    this.isPortrait = false,
  });

  final AppPlayerBackgroundStyle style;
  final ImageProvider<Object>? imageProvider;
  final PlayerTrack? track;

  /// 竖屏模式标识，用于决定写真请求的方向。
  final bool isPortrait;

  @override
  ConsumerState<PlayerBackdrop> createState() => _PlayerBackdropState();
}

class _PlayerBackdropState extends ConsumerState<PlayerBackdrop> {
  static const Duration _cycleDuration = Duration(seconds: 12);

  List<String> _photoUrls = const <String>[];
  String? _lastTrackKey;
  String? _cacheKey;
  Timer? _cycleTimer;

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
    if (widget.style != AppPlayerBackgroundStyle.artistPhoto ||
        widget.track == null) {
      _lastTrackKey = null;
      _cacheKey = null;
      _photoUrls = const <String>[];
      _cycleTimer?.cancel();
      return;
    }
    final trackKey = _buildTrackKey(widget.track!);
    if (trackKey != _lastTrackKey) {
      _lastTrackKey = trackKey;
      _cycleTimer?.cancel();
      // 优先从 provider 缓存恢复，避免重新进入时先显示封面再切换写真。
      final cacheKey = _resolveCacheKey(widget.track!);
      final cached = cacheKey != null ? _restoreFromCache(cacheKey) : false;
      if (!cached) {
        _cacheKey = null;
        _photoUrls = const <String>[];
        _fetchArtistPhoto(widget.track!);
      }
    }
  }

  /// 尝试从 provider 缓存恢复写真列表和索引，成功返回 true。
  bool _restoreFromCache(String cacheKey) {
    final cacheState = ref.read(artistPhotoCacheProvider);
    final entry = cacheState.cache[cacheKey];
    if (entry == null || entry.urls.isEmpty) return false;
    _photoUrls = entry.urls;
    _cacheKey = cacheKey;
    // 确保索引在有效范围内。
    final notifier = ref.read(artistPhotoCacheProvider.notifier);
    if (notifier.currentIndex(cacheKey) >= entry.urls.length) {
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
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final photoIndex = _cacheKey != null
        ? ref.watch(artistPhotoCacheProvider).currentIndices[_cacheKey] ?? 0
        : 0;
    return switch (widget.style) {
      AppPlayerBackgroundStyle.albumCover => _AlbumCoverBackdrop(
        imageProvider: widget.imageProvider,
      ),
      AppPlayerBackgroundStyle.fluid => _FluidBackdrop(
        imageProvider: widget.imageProvider,
      ),
      AppPlayerBackgroundStyle.artistPhoto => _ArtistPhotoBackdrop(
        imageProvider: _photoUrls.isNotEmpty
            ? CachedNetworkImageProvider(_photoUrls[photoIndex])
            : widget.imageProvider,
      ),
    };
  }

  /// 构建歌曲维度的缓存 key，用于去重请求。
  String _buildTrackKey(PlayerTrack track) {
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
      return '${track.platform ?? ""}|$fallback';
    }
    return '${track.platform ?? ""}|${ids.join(",")}|${names.join(",")}';
  }

  /// 异步获取歌手写真列表，成功后启动轮播。
  Future<void> _fetchArtistPhoto(PlayerTrack track) async {
    final platform = (track.platform ?? '').trim();
    if (platform.isEmpty) return;

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
    if (ids.isEmpty && names.isEmpty) return;

    final cacheKey = ref
        .read(artistPhotoCacheProvider.notifier)
        .buildCacheKey(platform, ids, names, widget.isPortrait);

    try {
      final urls = await ref
          .read(artistPhotoCacheProvider.notifier)
          .fetchPhotos(
            platform: platform,
            ids: ids,
            names: names,
            isPortrait: widget.isPortrait,
          );
      if (!mounted || urls.isEmpty) return;
      setState(() {
        _photoUrls = urls;
        _cacheKey = cacheKey;
      });
      // 确保索引在有效范围内，超出时重置为 0。
      final notifier = ref.read(artistPhotoCacheProvider.notifier);
      if (notifier.currentIndex(cacheKey) >= urls.length) {
        notifier.updateIndex(cacheKey, 0);
      }
      _startCycle();
    } catch (_) {
      // 请求失败静默回退到封面背景。
    }
  }
}

class _AlbumCoverBackdrop extends StatelessWidget {
  const _AlbumCoverBackdrop({required this.imageProvider});

  final ImageProvider<Object>? imageProvider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.secondary;
    final image = imageProvider;
    return Stack(
      key: const ValueKey<String>('player-backdrop-album-cover'),
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
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
        if (image != null)
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
            child: Transform.scale(
              scale: 1.18,
              child: Image(
                image: image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Colors.black.withValues(alpha: 0.18),
                Colors.black.withValues(alpha: 0.30),
                Colors.black.withValues(alpha: 0.30),
              ],
              stops: const <double>[0, 0.42, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _ArtistPhotoBackdrop extends StatelessWidget {
  const _ArtistPhotoBackdrop({required this.imageProvider});

  final ImageProvider<Object>? imageProvider;

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
        // 歌手写真全屏展示，切换时淡入淡出。
        if (image != null)
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 800),
              child: SizedBox.expand(
                key: ValueKey<ImageProvider>(image),
                child: Image(
                  image: image,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
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

class _FluidBackdrop extends StatefulWidget {
  const _FluidBackdrop({required this.imageProvider});

  final ImageProvider<Object>? imageProvider;

  @override
  State<_FluidBackdrop> createState() => _FluidBackdropState();
}

class _FluidBackdropState extends State<_FluidBackdrop> {
  static const Duration _paletteTransitionDuration = Duration(
    milliseconds: 900,
  );

  final ValueNotifier<int> _paletteVersion = ValueNotifier<int>(0);

  List<Color> _currentPalette = const <Color>[];
  List<Color> _previousPalette = const <Color>[];

  @override
  void initState() {
    super.initState();
    _refreshPalette();
  }

  @override
  void didUpdateWidget(covariant _FluidBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider) {
      _refreshPalette();
    }
  }

  @override
  void dispose() {
    _paletteVersion.dispose();
    super.dispose();
  }

  Future<void> _refreshPalette() async {
    final resolved = await _loadPalette(widget.imageProvider);
    if (!mounted) return;
    setState(() {
      _previousPalette = _currentPalette.isEmpty
          ? resolved
          : List<Color>.of(_currentPalette);
      _currentPalette = resolved;
      _paletteVersion.value++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallbackColors = _fallbackFluidColors(theme);
    final targetColors = _currentPalette.isNotEmpty
        ? _currentPalette
        : fallbackColors;
    final previousColors = _previousPalette.isNotEmpty
        ? _previousPalette
        : targetColors;

    return ValueListenableBuilder<int>(
      valueListenable: _paletteVersion,
      builder: (context, version, child) {
        return TweenAnimationBuilder<double>(
          key: ValueKey<int>(version),
          tween: Tween<double>(begin: 0, end: 1),
          duration: _paletteTransitionDuration,
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            final colors = _blendPalette(previousColors, targetColors, value);
            return Stack(
              key: const ValueKey<String>('player-backdrop-fluid'),
              fit: StackFit.expand,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _buildFluidBaseGradient(colors),
                  ),
                ),
                AnimatedMeshGradient(
                  colors: colors,
                  options: AnimatedMeshGradientOptions(
                    speed: 2,
                    frequency: 5,
                    amplitude: 25,
                    grain: 0.04,
                  ),
                  child: const SizedBox.expand(),
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
      },
    );
  }
}

Future<List<Color>> _loadPalette(ImageProvider<Object>? imageProvider) async {
  final colors = await colorsFromImageProvider(imageProvider);
  return _resolveFluidColors(colors);
}

@visibleForTesting
List<Color> resolveFluidColorsForTest(List<Color> colors) {
  return _resolveFluidColors(colors);
}

List<Color> _resolveFluidColors(List<Color> candidates) {
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

  return _expandFluidPalette(<Color>[
    _normalizeFluidColor(dominant, tone: _FluidTone.base),
    _normalizeFluidColor(highlight, tone: _FluidTone.highlight),
    _normalizeFluidColor(support, tone: _FluidTone.base),
    _normalizeFluidColor(
      _deriveFluidColor(accent, shiftDegrees: 12, lightnessDelta: -0.04),
      tone: _FluidTone.anchor,
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

enum _FluidTone { base, highlight, anchor }

Color _normalizeFluidColor(Color color, {required _FluidTone tone}) {
  final hsl = HSLColor.fromColor(color);
  final saturation = switch (tone) {
    _FluidTone.highlight => hsl.saturation.clamp(0.20, 0.65),
    _FluidTone.anchor => hsl.saturation.clamp(0.15, 0.55),
    _FluidTone.base => hsl.saturation.clamp(0.18, 0.60),
  };
  final lightness = switch (tone) {
    _FluidTone.highlight => hsl.lightness.clamp(0.42, 0.68),
    _FluidTone.anchor => hsl.lightness.clamp(0.18, 0.38),
    _FluidTone.base => hsl.lightness.clamp(0.28, 0.55),
  };
  return hsl.withSaturation(saturation).withLightness(lightness).toColor();
}

Color _deriveFluidColor(
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

List<Color> _expandFluidPalette(List<Color> seeds) {
  final colors = <Color>[];
  for (final seed in seeds) {
    if (!colors.any((existing) => _isColorTooClose(existing, seed))) {
      colors.add(seed);
    }
  }

  var index = 0;
  while (colors.length < 4) {
    final base = colors.isEmpty ? const Color(0xFF4C86D9) : colors[index];
    final tone = colors.length == 2 ? _FluidTone.anchor : _FluidTone.base;
    colors.add(
      _normalizeFluidColor(
        _deriveFluidColor(
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
List<Color> fallbackFluidColorsForTest(ThemeData theme) {
  return _fallbackFluidColors(theme);
}

List<Color> _fallbackFluidColors(ThemeData theme) {
  final seed = Color.lerp(
    theme.colorScheme.primary,
    theme.colorScheme.secondary,
    0.35,
  )!;
  return _expandFluidPalette(<Color>[
    _normalizeFluidColor(seed, tone: _FluidTone.base),
    _normalizeFluidColor(
      theme.colorScheme.tertiary,
      tone: _FluidTone.highlight,
    ),
    _normalizeFluidColor(
      _deriveFluidColor(seed, shiftDegrees: -18, lightnessDelta: -0.12),
      tone: _FluidTone.anchor,
    ),
  ]);
}

LinearGradient _buildFluidBaseGradient(List<Color> colors) {
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
