import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/config/app_lyric_highlight_mode.dart';
import '../../../lyrics/presentation/widgets/lyric_panel.dart';
import '../helpers/player_lyric_highlight_color_helper.dart';

@visibleForTesting
Color resolvePlayerLyricHighlightColor(
  AppConfigState config, {
  Color? autoColor,
}) {
  return resolveLyricHighlightColor(config, autoColor: autoColor);
}

/// 播放器歌词页面
class PlayerLyricPage extends ConsumerStatefulWidget {
  const PlayerLyricPage({
    super.key,
    required this.emptyText,
    required this.onSeek,
    this.artworkUrl,
    this.artworkBytes,
    this.center = false,
  });

  final String emptyText;
  final ValueChanged<Duration> onSeek;
  final String? artworkUrl;
  final Uint8List? artworkBytes;
  final bool center;

  @override
  ConsumerState<PlayerLyricPage> createState() => _PlayerLyricPageState();
}

class _PlayerLyricPageState extends ConsumerState<PlayerLyricPage> {
  Future<Color?>? _highlightColorFuture;
  String? _lastArtworkUrl;
  int? _lastArtworkByteLength;
  AppLyricHighlightMode? _lastMode;

  @override
  void initState() {
    super.initState();
    _lastArtworkUrl = widget.artworkUrl;
    _lastArtworkByteLength = widget.artworkBytes?.length;
  }

  @override
  void didUpdateWidget(covariant PlayerLyricPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextUrl = widget.artworkUrl;
    final nextByteLength = widget.artworkBytes?.length;
    if (_lastArtworkUrl == nextUrl &&
        _lastArtworkByteLength == nextByteLength) {
      return;
    }
    _lastArtworkUrl = nextUrl;
    _lastArtworkByteLength = nextByteLength;
    _highlightColorFuture = null;
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final autoColorFuture = _resolveAutoHighlightColorFuture(config);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: FutureBuilder<Color?>(
        future: autoColorFuture,
        builder: (context, snapshot) {
          return LyricPanel(
            emptyText: widget.emptyText,
            onSeek: widget.onSeek,
            center: widget.center,
            activeHighlightColorOverride: snapshot.data,
          );
        },
      ),
    );
  }

  Future<Color?>? _resolveAutoHighlightColorFuture(AppConfigState config) {
    if (config.lyricHighlightMode != AppLyricHighlightMode.auto) {
      _lastMode = config.lyricHighlightMode;
      _highlightColorFuture = null;
      return null;
    }
    if (_highlightColorFuture != null &&
        _lastMode == AppLyricHighlightMode.auto) {
      return _highlightColorFuture;
    }
    _lastMode = AppLyricHighlightMode.auto;
    _highlightColorFuture = _loadHighlightColor();
    return _highlightColorFuture;
  }

  Future<Color?> _loadHighlightColor() async {
    return loadPlayerLyricHighlightColor(
      artworkUrl: widget.artworkUrl,
      artworkBytes: widget.artworkBytes,
    );
  }
}
