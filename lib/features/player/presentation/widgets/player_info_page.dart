import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/player_quality_option.dart';
import '../providers/player_providers.dart';
import 'player_compact_lyric_section.dart';
import 'player_cover_hero.dart';

/// 播放器信息页面，显示封面、标题、艺术家、专辑等信息
class PlayerInfoPage extends ConsumerWidget {
  const PlayerInfoPage({
    super.key,
    required this.noTrackText,
    required this.compactLayout,
    this.fillHeight = true,
    required this.onOpenLyrics,
    required this.onOpenQuality,
    required this.onOpenSpeed,
  });

  final String noTrackText;
  final bool compactLayout;
  final bool fillHeight;
  final VoidCallback onOpenLyrics;
  final VoidCallback onOpenQuality;
  final VoidCallback onOpenSpeed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );
    final currentAvailableQualities = ref.watch(
      playerControllerProvider.select(
        (state) => state.currentAvailableQualities,
      ),
    );
    final currentSelectedQualityName = ref.watch(
      playerControllerProvider.select(
        (state) => state.currentSelectedQualityName,
      ),
    );
    final speed = ref.watch(
      playerControllerProvider.select((state) => state.speed),
    );
    final isRadioMode = ref.watch(
      playerControllerProvider.select((state) => state.isRadioMode),
    );
    final currentQuality = _findQualityByName(
      currentAvailableQualities,
      currentSelectedQualityName,
    );
    final title = track?.title ?? noTrackText;
    final artist = _fallbackText(track?.artist);
    final album = _fallbackText(track?.album);
    return LayoutBuilder(
      builder: (context, constraints) {
        final coverSize = compactLayout
            ? math
                  .min(
                    constraints.maxWidth * 0.42,
                    constraints.maxHeight * 0.24,
                  )
                  .clamp(132.0, 188.0)
            : math
                  .min(
                    constraints.maxWidth * 0.72,
                    constraints.maxHeight * 0.40,
                  )
                  .clamp(190.0, 320.0);
        final topSpacing = compactLayout
            ? (constraints.maxHeight * 0.004).clamp(0.0, 4.0)
            : (constraints.maxHeight * 0.01).clamp(4.0, 10.0);
        final coverBottomSpacing = compactLayout
            ? (constraints.maxHeight * 0.016).clamp(8.0, 14.0)
            : (constraints.maxHeight * 0.035).clamp(14.0, 24.0);
        return SizedBox(
          height: fillHeight && !compactLayout ? constraints.maxHeight : null,
          child: Column(
            mainAxisSize: fillHeight && !compactLayout
                ? MainAxisSize.max
                : MainAxisSize.min,
            children: <Widget>[
              SizedBox(height: topSpacing),
              PlayerCoverHero(
                artworkUrl: track?.artworkUrl,
                artworkBytes: track?.artworkBytes,
                size: coverSize,
              ),
              SizedBox(height: coverBottomSpacing),
              _buildTitle(context, title, isRadioMode),
              if (currentQuality != null) ...<Widget>[
                SizedBox(height: compactLayout ? 8 : 12),
                _buildQualityBadges(context, currentQuality, speed),
              ],
              if (currentQuality == null) ...<Widget>[
                SizedBox(height: compactLayout ? 8 : 12),
                _buildSpeedBadge(context, speed),
              ],
              SizedBox(height: compactLayout ? 8 : 14),
              _PlayerMetaLine(value: artist),
              SizedBox(height: compactLayout ? 4 : 8),
              _PlayerMetaLine(value: album),
              if (fillHeight && !compactLayout) const Spacer(),
              if (compactLayout) ...<Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: KeyedSubtree(
                    key: const ValueKey<String>('player-compact-lyric-preview'),
                    child: PlayerCompactLyricSection(onTap: onOpenLyrics),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildTitle(BuildContext context, String title, bool isRadioMode) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Flexible(
            child: Text(
              title,
              maxLines: compactLayout ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w500,
                letterSpacing: -0.6,
                color: Colors.white,
              ),
            ),
          ),
          if (isRadioMode) ...<Widget>[
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 3),
              child: _PlayerRadioModeIcon(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQualityBadges(
    BuildContext context,
    PlayerQualityOption quality,
    double speed,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          _PlayerMiniBadge(label: quality.name, onTap: onOpenQuality),
          _PlayerMiniBadge(
            label: '${speed.toStringAsFixed(speed == 1 ? 0 : 2)}x',
            onTap: onOpenSpeed,
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedBadge(BuildContext context, double speed) {
    return Align(
      alignment: Alignment.centerLeft,
      child: _PlayerMiniBadge(
        label: '${speed.toStringAsFixed(speed == 1 ? 0 : 2)}x',
        onTap: onOpenSpeed,
      ),
    );
  }

  String _fallbackText(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '-';
    }
    return value;
  }

  PlayerQualityOption? _findQualityByName(
    List<PlayerQualityOption> options,
    String? name,
  ) {
    if (name == null || name.trim().isEmpty) {
      return null;
    }
    for (final option in options) {
      if (option.name == name) {
        return option;
      }
    }
    return null;
  }
}

class _PlayerMetaLine extends StatelessWidget {
  const _PlayerMetaLine({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.left,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontSize: 14,
          color: Colors.white.withValues(alpha: 0.7),
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _PlayerRadioModeIcon extends StatelessWidget {
  const _PlayerRadioModeIcon();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 0.7,
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(5),
        child: Icon(Icons.radio_rounded, size: 14, color: Colors.white),
      ),
    );
  }
}

class _PlayerMiniBadge extends StatelessWidget {
  const _PlayerMiniBadge({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 0.7,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w400,
              letterSpacing: 0.1,
              fontSize: 10,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
