import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/player/app_player_style_registry.dart';
import '../../../../core/device/realtime_spectrum_permission.dart';
import '../../domain/entities/player_track.dart';
import 'player_style_live_preview.dart';

enum _PlayerStyleAxis { stage, backdrop, lyrics }

class PlayerStyleSelectionSheet extends ConsumerStatefulWidget {
  const PlayerStyleSelectionSheet({this.track, super.key});

  final PlayerTrack? track;
  @override
  ConsumerState<PlayerStyleSelectionSheet> createState() =>
      _PlayerStyleSelectionSheetState();
}

class _PlayerStyleSelectionSheetState
    extends ConsumerState<PlayerStyleSelectionSheet> {
  _PlayerStyleAxis _activeAxis = _PlayerStyleAxis.stage;
  String? _pendingStageId;

  @override
  Widget build(BuildContext context) {
    final selection = ref.watch(
      appConfigProvider.select(
        (state) => (
          localeCode: state.localeCode,
          stageId: state.playerStageId,
          backdropId: state.playerBackdropId,
          lyricsId: state.playerLyricsId,
        ),
      ),
    );
    String label(String key) =>
        AppI18n.tByLocaleCode(selection.localeCode, key);
    final stageSuppressed =
        selection.backdropId == AppPlayerBackdropRegistry.artistPhotoId;

    final options = switch (_activeAxis) {
      _PlayerStyleAxis.stage => <_StyleOptionSpec>[
        for (final stage in AppPlayerStageRegistry.instance.options)
          _StyleOptionSpec(
            id: stage.metadata.id,
            label: label(stage.metadata.labelKey),
            previewAsset: stage.metadata.previewAsset,
          ),
      ],
      _PlayerStyleAxis.backdrop => <_StyleOptionSpec>[
        for (final backdrop in AppPlayerBackdropRegistry.instance.options)
          _StyleOptionSpec(
            id: backdrop.metadata.id,
            label: label(backdrop.metadata.labelKey),
            previewAsset: backdrop.metadata.previewAsset,
          ),
      ],
      _PlayerStyleAxis.lyrics => <_StyleOptionSpec>[
        for (final lyrics in AppPlayerLyricsRegistry.instance.options)
          _StyleOptionSpec(
            id: lyrics.metadata.id,
            label: label(lyrics.metadata.labelKey),
            previewAsset: lyrics.metadata.previewAsset,
          ),
      ],
    };
    final selectedId = switch (_activeAxis) {
      _PlayerStyleAxis.stage => selection.stageId,
      _PlayerStyleAxis.backdrop => selection.backdropId,
      _PlayerStyleAxis.lyrics => selection.lyricsId,
    };
    final onSelected = switch (_activeAxis) {
      _PlayerStyleAxis.stage => (String id) => unawaited(_selectStage(id)),
      _PlayerStyleAxis.backdrop => _applyBackdrop,
      _PlayerStyleAxis.lyrics => _applyLyrics,
    };

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label('player.action.style'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            PlayerStyleLivePreview(
              stageId: selection.stageId,
              backdropId: selection.backdropId,
              lyricsId: selection.lyricsId,
              localeCode: selection.localeCode,
              track: widget.track,
            ),
            const SizedBox(height: 16),
            _AxisTabBar(
              selected: _activeAxis,
              labels: <_PlayerStyleAxis, String>{
                _PlayerStyleAxis.stage: label('player.style.group.stage'),
                _PlayerStyleAxis.backdrop: label('player.style.group.backdrop'),
                _PlayerStyleAxis.lyrics: label('player.style.group.lyrics'),
              },
              onSelected: (axis) => setState(() => _activeAxis = axis),
            ),
            if (_activeAxis == _PlayerStyleAxis.stage && stageSuppressed) ...[
              _StageSuppressedNotice(
                message: label('player.style.stage.hidden_by_artist_photo'),
              ),
              const SizedBox(height: 8),
            ] else
              const SizedBox(height: 12),
            _StyleOptionStrip(
              options: options,
              selectedId: selectedId,
              enabled:
                  _activeAxis != _PlayerStyleAxis.stage || !stageSuppressed,
              pendingId: _activeAxis == _PlayerStyleAxis.stage
                  ? _pendingStageId
                  : null,
              onSelected: onSelected,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectStage(String stageId) async {
    final stage = AppPlayerStageRegistry.instance.resolve(stageId);
    if (!stage.usesRealtimeSpectrum ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      _applyStage(stageId);
      return;
    }
    setState(() => _pendingStageId = stageId);
    try {
      final permission = ref.read(realtimeSpectrumPermissionPortProvider);
      var status = await permission.status();
      if (!mounted) return;
      if (status == RealtimeSpectrumPermissionState.granted) {
        _applyStage(stageId);
        return;
      }
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            AppI18n.t(
              ref.read(appConfigProvider),
              'player.spectrum.permission.title',
            ),
          ),
          content: Text(
            AppI18n.t(
              ref.read(appConfigProvider),
              'player.spectrum.permission.message',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                AppI18n.t(ref.read(appConfigProvider), 'common.cancel'),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                AppI18n.t(
                  ref.read(appConfigProvider),
                  'player.spectrum.permission.continue',
                ),
              ),
            ),
          ],
        ),
      );
      if (shouldContinue != true || !mounted) {
        return;
      }
      if (status != RealtimeSpectrumPermissionState.permanentlyDenied) {
        status = await permission.request();
      }
      if (!mounted) return;
      switch (status) {
        case RealtimeSpectrumPermissionState.granted:
          _applyStage(stageId);
        case RealtimeSpectrumPermissionState.denied:
          AppMessageService.showWarning(
            AppI18n.t(
              ref.read(appConfigProvider),
              'player.spectrum.permission.denied',
            ),
          );
        case RealtimeSpectrumPermissionState.permanentlyDenied:
          await _showOpenSettingsDialog(permission);
      }
    } catch (_) {
      if (mounted) {
        AppMessageService.showError(
          AppI18n.t(
            ref.read(appConfigProvider),
            'player.spectrum.permission.failed',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pendingStageId = null);
      }
    }
  }

  Future<void> _showOpenSettingsDialog(
    RealtimeSpectrumPermissionPort permission,
  ) async {
    final config = ref.read(appConfigProvider);
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          AppI18n.t(config, 'player.spectrum.permission.settings_title'),
        ),
        content: Text(
          AppI18n.t(config, 'player.spectrum.permission.settings_message'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppI18n.t(config, 'common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              AppI18n.t(config, 'player.spectrum.permission.open_settings'),
            ),
          ),
        ],
      ),
    );
    if (shouldOpen == true) {
      await permission.openSettings();
    }
  }

  void _applyStage(String stageId) {
    ref.read(appConfigProvider.notifier).setPlayerStageId(stageId);
  }

  void _applyBackdrop(String backdropId) {
    ref.read(appConfigProvider.notifier).setPlayerBackdropId(backdropId);
  }

  void _applyLyrics(String lyricsId) {
    ref.read(appConfigProvider.notifier).setPlayerLyricsId(lyricsId);
  }
}

class _AxisTabBar extends StatelessWidget {
  const _AxisTabBar({
    required this.selected,
    required this.labels,
    required this.onSelected,
  });

  final _PlayerStyleAxis selected;
  final Map<_PlayerStyleAxis, String> labels;
  final ValueChanged<_PlayerStyleAxis> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SizedBox(
        height: 44,
        child: Row(
          children: <Widget>[
            for (final axis in _PlayerStyleAxis.values)
              Expanded(
                child: Semantics(
                  selected: axis == selected,
                  button: true,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: ValueKey<String>('player-style-axis-${axis.name}'),
                      onTap: () => onSelected(axis),
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Text(
                            labels[axis]!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: axis == selected
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurfaceVariant,
                              fontWeight: axis == selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                          if (axis == selected)
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                width: 32,
                                height: 2,
                                color: colorScheme.onSurface,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StageSuppressedNotice extends StatelessWidget {
  const _StageSuppressedNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const ValueKey<String>('player-style-stage-suppressed-notice'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.visibility_off_outlined,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleOptionSpec {
  const _StyleOptionSpec({
    required this.id,
    required this.label,
    required this.previewAsset,
  });

  final String id;
  final String label;
  final String previewAsset;
}

class _StyleOptionStrip extends StatelessWidget {
  const _StyleOptionStrip({
    required this.options,
    required this.selectedId,
    required this.enabled,
    required this.pendingId,
    required this.onSelected,
  });

  static const double _itemWidth = 82;
  static const double _spacing = 8;

  final List<_StyleOptionSpec> options;
  final String selectedId;
  final bool enabled;
  final String? pendingId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth =
            options.length * _itemWidth + (options.length - 1) * _spacing;
        final centerOptions = contentWidth <= constraints.maxWidth;
        return SingleChildScrollView(
          key: const ValueKey<String>('player-style-option-strip'),
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: SizedBox(
            width: centerOptions ? constraints.maxWidth : contentWidth,
            child: Row(
              mainAxisAlignment: centerOptions
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: <Widget>[
                for (var index = 0; index < options.length; index++) ...[
                  if (index > 0) const SizedBox(width: _spacing),
                  _StyleOptionCard(
                    spec: options[index],
                    selected: options[index].id == selectedId,
                    pending: options[index].id == pendingId,
                    enabled: enabled && pendingId == null,
                    onTap: () => onSelected(options[index].id),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StyleOptionCard extends StatelessWidget {
  const _StyleOptionCard({
    required this.spec,
    required this.selected,
    required this.pending,
    required this.enabled,
    required this.onTap,
  });

  final _StyleOptionSpec spec;
  final bool selected;
  final bool pending;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: spec.label,
      child: SizedBox(
        width: _StyleOptionStrip._itemWidth,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey<String>('player-style-option-${spec.id}'),
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(8),
            child: AnimatedOpacity(
              opacity: enabled || pending ? 1 : 0.48,
              duration: const Duration(milliseconds: 150),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 60,
                      height: 92,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: selected
                              ? colorScheme.onSurface
                              : colorScheme.outlineVariant,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            Image.asset(
                              spec.previewAsset,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.image_not_supported_outlined,
                                  color: colorScheme.onSurfaceVariant,
                                );
                              },
                            ),
                            if (selected && !pending)
                              Align(
                                alignment: Alignment.topRight,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surface,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            if (pending)
                              ColoredBox(
                                color: colorScheme.scrim.withValues(
                                  alpha: 0.42,
                                ),
                                child: Center(
                                  child: SizedBox.square(
                                    dimension: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 32,
                      child: Text(
                        spec.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: selected
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
