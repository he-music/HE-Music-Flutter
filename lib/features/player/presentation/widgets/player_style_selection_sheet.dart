import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/player/app_player_style_models.dart';
import '../../../../app/theme/player/app_player_style_registry.dart';
import '../../../../core/device/realtime_spectrum_permission.dart';

class PlayerStyleSelectionSheet extends ConsumerStatefulWidget {
  const PlayerStyleSelectionSheet({super.key});

  @override
  ConsumerState<PlayerStyleSelectionSheet> createState() =>
      _PlayerStyleSelectionSheetState();
}

class _PlayerStyleSelectionSheetState
    extends ConsumerState<PlayerStyleSelectionSheet> {
  String? _pendingStageId;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final stages = AppPlayerStageRegistry.instance.options;
    final backdrops = AppPlayerBackdropRegistry.instance.options;
    final lyrics = AppPlayerLyricsRegistry.instance.options;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                AppI18n.t(config, 'player.action.style'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            _AxisSection(
              title: AppI18n.t(config, 'player.style.group.stage'),
              options: stages
                  .map(
                    (stage) => _OptionSpec(
                      id: stage.metadata.id,
                      label: AppI18n.t(config, stage.metadata.labelKey),
                      previewAsset: stage.metadata.previewAsset,
                      backgroundStart: appPlayerForegroundColors.controlSurface,
                      backgroundEnd: appPlayerSurfaceColor,
                    ),
                  )
                  .toList(),
              selectedId: config.playerStageId,
              pendingId: _pendingStageId,
              onTap: (id) => unawaited(_selectStage(id)),
            ),
            _AxisSection(
              title: AppI18n.t(config, 'player.style.group.backdrop'),
              options: backdrops
                  .map(
                    (backdrop) => _OptionSpec(
                      id: backdrop.metadata.id,
                      label: AppI18n.t(config, backdrop.metadata.labelKey),
                      previewAsset: backdrop.metadata.previewAsset,
                      backgroundStart: backdrop.backgroundStart,
                      backgroundEnd: backdrop.backgroundEnd,
                    ),
                  )
                  .toList(),
              selectedId: config.playerBackdropId,
              onTap: (id) => _applyBackdrop(id),
            ),
            _AxisSection(
              title: AppI18n.t(config, 'player.style.group.lyrics'),
              options: lyrics
                  .map(
                    (lyric) => _OptionSpec(
                      id: lyric.metadata.id,
                      label: AppI18n.t(config, lyric.metadata.labelKey),
                      previewAsset: lyric.metadata.previewAsset,
                      backgroundStart: appPlayerForegroundColors.controlSurface,
                      backgroundEnd: appPlayerSurfaceColor,
                    ),
                  )
                  .toList(),
              selectedId: config.playerLyricsId,
              onTap: (id) => _applyLyrics(id),
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
    Navigator.of(context).pop();
  }

  void _applyBackdrop(String backdropId) {
    ref
        .read(appConfigProvider.notifier)
        .setPlayerBackdropId(backdropId);
    Navigator.of(context).pop();
  }

  void _applyLyrics(String lyricsId) {
    ref.read(appConfigProvider.notifier).setPlayerLyricsId(lyricsId);
    Navigator.of(context).pop();
  }
}

class _OptionSpec {
  const _OptionSpec({
    required this.id,
    required this.label,
    required this.previewAsset,
    required this.backgroundStart,
    required this.backgroundEnd,
  });

  final String id;
  final String label;
  final String previewAsset;
  final Color backgroundStart;
  final Color backgroundEnd;
}

class _AxisSection extends StatelessWidget {
  const _AxisSection({
    required this.title,
    required this.options,
    required this.selectedId,
    required this.onTap,
    this.pendingId,
  });

  final String title;
  final List<_OptionSpec> options;
  final String selectedId;
  final String? pendingId;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: options.length,
          itemBuilder: (context, index) {
            final option = options[index];
            final pending = pendingId == option.id;
            return _PlayerStyleOption(
              spec: option,
              selected: option.id == selectedId,
              pending: pending,
              onTap: pending ? null : () => onTap(option.id),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _PlayerStyleOption extends StatelessWidget {
  const _PlayerStyleOption({
    required this.spec,
    required this.selected,
    required this.pending,
    required this.onTap,
  });

  final _OptionSpec spec;
  final bool selected;
  final bool pending;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = appPlayerForegroundColors.accent;
    final borderColor = selected
        ? accent
        : appPlayerForegroundColors.controlBorder.withValues(alpha: 0.78);
    return Semantics(
      button: true,
      selected: selected,
      label: spec.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('player-style-option-${spec.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: appPlayerForegroundColors.controlSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: selected ? 2 : 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            spec.backgroundStart,
                            spec.backgroundEnd,
                          ],
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          Image.asset(
                            spec.previewAsset,
                            key: ValueKey<String>(
                              'player-style-preview-${spec.id}',
                            ),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return _PlayerStylePreviewFallback(spec: spec);
                            },
                          ),
                          if (selected)
                            Align(
                              alignment: Alignment.topRight,
                              child: Container(
                                key: ValueKey<String>(
                                  'player-style-selected-${spec.id}',
                                ),
                                width: 28,
                                height: 28,
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: appPlayerSurfaceColor,
                                ),
                              ),
                            ),
                          if (pending)
                            const Align(
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.hourglass_top_rounded,
                                key: ValueKey<String>(
                                  'player-style-permission-progress',
                                ),
                                size: 28,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: Center(
                      child: Text(
                        spec.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerStylePreviewFallback extends StatelessWidget {
  const _PlayerStylePreviewFallback({required this.spec});

  final _OptionSpec spec;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ValueKey<String>('player-style-preview-fallback-${spec.id}'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[spec.backgroundStart, spec.backgroundEnd],
        ),
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: 38,
        color: appPlayerForegroundColors.secondaryForeground,
      ),
    );
  }
}