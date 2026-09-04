import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/player/app_player_style_models.dart';
import '../../../../app/theme/player/app_player_style_registry.dart';
import '../../../../core/audio/audio_spectrum_frame.dart';
import '../../../lyrics/domain/entities/lyric_document.dart';
import '../../../lyrics/domain/entities/lyric_line.dart';
import '../../../lyrics/domain/entities/lyric_request.dart';
import '../../../lyrics/presentation/providers/lyrics_providers.dart';
import '../../domain/entities/player_playback_state.dart';
import '../../domain/entities/player_track.dart';
import '../controllers/player_controller.dart';
import '../controllers/realtime_spectrum_controller.dart';
import '../helpers/player_artwork_helper.dart';
import '../providers/player_providers.dart';
import '../styles/player_style_stage.dart';
import 'cadenza_lyric_page.dart';
import 'monet_lyric_page.dart';
import 'partita_lyric_page.dart';
import 'player_backdrop.dart';
import 'player_lyric_page.dart';

/// 播放器样式选择面板中的双屏组合预览。
///
/// 封面页和歌词页都使用固定逻辑画布渲染后整体缩放，避免真实播放器组件
/// 被狭窄约束挤压变形。
class PlayerStyleLivePreview extends StatelessWidget {
  const PlayerStyleLivePreview({
    required this.stageId,
    required this.backdropId,
    required this.lyricsId,
    required this.localeCode,
    this.track,
    super.key,
  });

  final String stageId;
  final String backdropId;
  final String lyricsId;
  final String localeCode;
  final PlayerTrack? track;

  @override
  Widget build(BuildContext context) {
    final previewTrack = track ?? _demoTrack;
    return ProviderScope(
      overrides: [
        playerControllerProvider.overrideWith(
          () => _PreviewPlayerController(previewTrack),
        ),
        realtimeSpectrumControllerProvider.overrideWith(
          _PreviewSpectrumController.new,
        ),
      ],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PreviewPane(
            label: AppI18n.tByLocaleCode(
              localeCode,
              'player.style.preview.cover',
            ),
            frameKey: const ValueKey<String>(
              'player-style-live-preview-cover-frame',
            ),
            child: _CoverStagePreview(
              key: const ValueKey<String>('player-style-preview-cover'),
              track: previewTrack,
              stageId: stageId,
              backdropId: backdropId,
            ),
          ),
          const SizedBox(width: 16),
          _PreviewPane(
            label: AppI18n.tByLocaleCode(
              localeCode,
              'player.style.preview.lyrics',
            ),
            frameKey: const ValueKey<String>(
              'player-style-live-preview-lyrics-frame',
            ),
            child: _LyricStagePreview(
              key: const ValueKey<String>('player-style-preview-lyrics'),
              track: previewTrack,
              backdropId: backdropId,
              lyricsId: lyricsId,
              localeCode: localeCode,
            ),
          ),
        ],
      ),
    );
  }
}

const PlayerTrack _demoTrack = PlayerTrack(
  id: 'preview-track',
  title: '城市回声',
  artist: '林诺',
  album: '信号房间',
  platform: 'preview',
);

/// 预览用模拟频谱控制器：输出固定波形，避免接入真实麦克风采集。
class _PreviewSpectrumController extends RealtimeSpectrumController {
  @override
  RealtimeSpectrumState build() {
    final bands = List<double>.generate(AudioSpectrumFrame.bandCount, (index) {
      final base = math.sin(index * 0.42).abs();
      final detail = math.cos(index * 0.17 + 0.6).abs();
      return (0.16 + base * detail * 0.72 + (index % 7) * 0.03).clamp(0.0, 1.0);
    }, growable: false);
    return RealtimeSpectrumState(
      status: RealtimeSpectrumStatus.running,
      bands: List<double>.unmodifiable(bands),
    );
  }

  @override
  void setConsumerVisible(bool visible) {}
}

/// 预览用播放控制器：返回固定播放位置，避免接入真实音频引擎。
class _PreviewPlayerController extends PlayerController {
  _PreviewPlayerController(this.track);

  final PlayerTrack track;

  @override
  PlayerPlaybackState build() {
    return PlayerPlaybackState.initial(<PlayerTrack>[track]).copyWith(
      position: const Duration(seconds: 6),
      duration: track.duration ?? const Duration(minutes: 3, seconds: 48),
    );
  }

  @override
  Future<void> initialize() async {}
}

const LyricDocument _demoLyricDocument = LyricDocument(
  lines: <LyricLine>[
    LyricLine(
      start: Duration(seconds: 0),
      end: Duration(seconds: 4),
      text: '城市回声',
    ),
    LyricLine(
      start: Duration(seconds: 4),
      end: Duration(seconds: 9),
      text: '玻璃天台',
      translation: 'Glass Rooftop',
    ),
    LyricLine(
      start: Duration(seconds: 9),
      end: Duration(seconds: 14),
      text: '低频大厅',
      translation: 'Low Frequency Hall',
      tokens: <LyricToken>[
        LyricToken(
          text: '低频',
          startOffset: Duration.zero,
          duration: Duration(seconds: 1),
        ),
        LyricToken(
          text: '大厅',
          startOffset: Duration(seconds: 1),
          duration: Duration(seconds: 4),
        ),
      ],
    ),
    LyricLine(start: Duration(seconds: 14), text: '信号房间'),
  ],
);

const Duration _demoLyricPosition = Duration(seconds: 6);
const LyricRequest _demoLyricRequest = LyricRequest(
  trackId: 'preview-track',
  platform: 'preview',
);

class _CoverStagePreview extends StatelessWidget {
  const _CoverStagePreview({
    required this.track,
    required this.stageId,
    required this.backdropId,
    super.key,
  });

  final PlayerTrack track;
  final String stageId;
  final String backdropId;

  @override
  Widget build(BuildContext context) {
    final stage = AppPlayerStageRegistry.instance.resolve(stageId);
    final backdrop = AppPlayerBackdropRegistry.instance.resolve(backdropId);
    final imageProvider = artworkProvider(track.artworkUrl, track.artworkBytes);
    final showStage =
        backdrop.backdropKind != AppPlayerBackdropKind.artistPhoto;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        PlayerBackdrop(
          backdropKind: backdrop.backdropKind,
          imageProvider: imageProvider,
          track: track,
          isPortrait: true,
        ),
        if (showStage)
          PlayerStyleStage(
            stageKind: stage.stageKind,
            track: track,
            maxWidth: stage.stageMaxWidth,
          ),
      ],
    );
  }
}

class _LyricStagePreview extends StatelessWidget {
  const _LyricStagePreview({
    required this.track,
    required this.backdropId,
    required this.lyricsId,
    required this.localeCode,
    super.key,
  });

  final PlayerTrack track;
  final String backdropId;
  final String lyricsId;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final backdrop = AppPlayerBackdropRegistry.instance.resolve(backdropId);
    final lyrics = AppPlayerLyricsRegistry.instance.resolve(lyricsId);
    final imageProvider = artworkProvider(track.artworkUrl, track.artworkBytes);
    final emptyText = AppI18n.tByLocaleCode(localeCode, 'player.lyrics.empty');
    return ProviderScope(
      overrides: [
        currentLyricDocumentProvider.overrideWithValue(
          const AsyncData<LyricDocument>(_demoLyricDocument),
        ),
        currentLyricRequestProvider.overrideWithValue(_demoLyricRequest),
        lyricPositionProvider.overrideWithValue(_demoLyricPosition),
      ],
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          PlayerBackdrop(
            backdropKind: backdrop.backdropKind,
            imageProvider: imageProvider,
            track: track,
            isPortrait: true,
          ),
          _buildLyricHost(lyrics.lyricsKind, emptyText),
        ],
      ),
    );
  }

  Widget _buildLyricHost(AppPlayerLyricsKind kind, String emptyText) {
    return switch (kind) {
      AppPlayerLyricsKind.legacy => PlayerLyricPage(
        emptyText: emptyText,
        onSeek: null,
        artworkUrl: track.artworkUrl,
        artworkBytes: track.artworkBytes,
        center: false,
      ),
      AppPlayerLyricsKind.monet => MonetLyricPage(
        emptyText: emptyText,
        onSeek: null,
        palette: null,
      ),
      AppPlayerLyricsKind.partita => PartitaLyricPage(
        emptyText: emptyText,
        onSeek: null,
        palette: null,
        breathingEnabled: true,
      ),
      AppPlayerLyricsKind.cadenza => CadenzaLyricPage(
        emptyText: emptyText,
        onSeek: null,
        palette: null,
      ),
    };
  }
}

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({
    required this.label,
    required this.frameKey,
    required this.child,
  });

  final String label;
  final Key frameKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _PreviewPhoneFrame(frameKey: frameKey, child: child),
        const SizedBox(height: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PreviewPhoneFrame extends StatelessWidget {
  const _PreviewPhoneFrame({required this.frameKey, required this.child});

  static const Size _logicalSize = Size(360, 640);
  static const double _previewWidth = 96;

  final Key frameKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    return RepaintBoundary(
      key: frameKey,
      child: SizedBox(
        width: _previewWidth,
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF101313),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: theme.colorScheme.outlineVariant),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.16),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox.fromSize(
                    size: _logicalSize,
                    child: MediaQuery(
                      data: mediaQuery.copyWith(
                        size: _logicalSize,
                        padding: EdgeInsets.zero,
                        viewPadding: EdgeInsets.zero,
                        viewInsets: EdgeInsets.zero,
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
