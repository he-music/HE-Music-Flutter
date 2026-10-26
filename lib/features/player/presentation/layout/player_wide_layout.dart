import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../../../app/config/app_player_wide_view.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/glass/app_glass_scope.dart';
import '../../../../app/theme/player/app_player_scene_palette.dart';

/// Independent wide-player composition. Phone paging and landscape layouts do
/// not share its sizing or controls placement.
class PlayerWideLayout extends StatelessWidget {
  const PlayerWideLayout({
    required this.view,
    required this.localeCode,
    required this.onViewChanged,
    required this.onClose,
    required this.onOpenStyle,
    required this.onOpenMore,
    required this.background,
    required this.stage,
    required this.stageMaxWidth,
    required this.metadataHeight,
    this.stageAspectRatio = 1,
    this.metadataWidthFactor = 1,
    this.hasStage = true,
    required this.lyrics,
    required this.metadata,
    required this.progress,
    required this.controls,
    required this.actions,
    super.key,
  });

  final AppPlayerWideView view;
  final String localeCode;
  final ValueChanged<AppPlayerWideView> onViewChanged;
  final VoidCallback onClose;
  final VoidCallback onOpenStyle;
  final VoidCallback? onOpenMore;
  final Widget background;
  final Widget stage;
  final double stageMaxWidth;
  final double stageAspectRatio;
  final double metadataHeight;
  final double metadataWidthFactor;
  final bool hasStage;
  final Widget lyrics;
  final Widget metadata;
  final Widget progress;
  final Widget controls;
  final Widget actions;

  /// Existing mobile-landscape routing always takes precedence, including
  /// unusually wide phones. Low desktop windows can use a compact wide stage.
  static bool supports(Size size, {required bool isMobileLandscape}) =>
      !isMobileLandscape && size.width >= 1000 && size.height >= 480;

  @override
  Widget build(BuildContext context) {
    final foreground =
        PlayerScenePalette.maybeOf(context)?.foreground ?? Colors.white;
    return Material(
      type: MaterialType.transparency,
      child: GlassScaffold(
        key: const ValueKey('player-wide-layout'),
        background: background,
        edgeFade: false,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(32, 12, 32, 8),
                child: SizedBox(
                  height: math.max(
                    48,
                    MediaQuery.textScalerOf(context).scale(32),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _WideAction(
                          icon: Icons.keyboard_arrow_down_rounded,
                          label: AppI18n.tByLocaleCode(
                            localeCode,
                            'common.back',
                          ),
                          onPressed: onClose,
                        ),
                      ),
                      SizedBox(width: 320, child: _buildViewSelector(context)),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _WideAction(
                              icon: Icons.palette_outlined,
                              label: AppI18n.tByLocaleCode(
                                localeCode,
                                'player.action.style',
                              ),
                              onPressed: onOpenStyle,
                            ),
                            const SizedBox(width: 12),
                            _WideAction(
                              icon: Icons.more_horiz_rounded,
                              label: AppI18n.tByLocaleCode(
                                localeCode,
                                'common.more',
                              ),
                              onPressed: onOpenMore,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1440),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(48, 12, 48, 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (view != AppPlayerWideView.lyrics)
                            Expanded(
                              flex: 5,
                              child: KeyedSubtree(
                                key: const ValueKey('player-wide-stage'),
                                child: hasStage
                                    ? _buildStageWithMetadata()
                                    : stage,
                              ),
                            ),
                          if (view == AppPlayerWideView.split)
                            const SizedBox(width: 64),
                          if (view != AppPlayerWideView.cover)
                            Expanded(
                              flex: 7,
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 960,
                                  ),
                                  child: SizedBox.expand(
                                    key: const ValueKey('player-wide-lyrics'),
                                    child: lyrics,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              DecoratedBox(
                key: const ValueKey('player-wide-control-bar'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: .16),
                    ],
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1440),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 8, 32, 16),
                        child: IconTheme(
                          data: IconThemeData(color: foreground),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child:
                                    view == AppPlayerWideView.lyrics ||
                                        !hasStage
                                    ? metadata
                                    : const SizedBox.shrink(),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 5,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    progress,
                                    const SizedBox(height: 4),
                                    controls,
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 3,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 180,
                                    ),
                                    child: actions,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageWithMetadata() => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 20.0;
      final availableStageHeight = math.max(
        0.0,
        constraints.maxHeight - metadataHeight - gap,
      );
      final width = math.min(
        math.min(constraints.maxWidth, stageMaxWidth),
        availableStageHeight * stageAspectRatio,
      );
      return Center(
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: width / stageAspectRatio, child: stage),
              const SizedBox(height: gap),
              SizedBox(
                width: width * metadataWidthFactor,
                height: metadataHeight,
                child: metadata,
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _buildViewSelector(BuildContext context) {
    final labels = [
      for (final view in AppPlayerWideView.values)
        AppI18n.tByLocaleCode(localeCode, 'player.view.${view.name}'),
    ];
    final foreground =
        PlayerScenePalette.maybeOf(context)?.foreground ?? Colors.white;
    if (AppGlassScope.controlsEnabled(context)) {
      return GlassSegmentedControl(
        key: const ValueKey('player-wide-view-selector'),
        segments: [for (final label in labels) GlassSegment(label: label)],
        selectedIndex: view.index,
        onSegmentSelected: (index) =>
            onViewChanged(AppPlayerWideView.values[index]),
        useOwnLayer: true,
        quality: AppGlassScope.qualityOf(context),
        selectedTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
        unselectedTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: foreground.withValues(alpha: .65),
        ),
      );
    }
    return SegmentedButton<AppPlayerWideView>(
      key: const ValueKey('player-wide-view-selector'),
      segments: [
        for (final view in AppPlayerWideView.values)
          ButtonSegment(value: view, label: Text(labels[view.index])),
      ],
      selected: {view},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onViewChanged(selection.single),
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(foreground),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => foreground.withValues(
            alpha: states.contains(WidgetState.selected) ? .16 : .04,
          ),
        ),
        side: WidgetStatePropertyAll(
          BorderSide(color: foreground.withValues(alpha: .12)),
        ),
      ),
    );
  }
}

class _WideAction extends StatelessWidget {
  const _WideAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground =
        PlayerScenePalette.maybeOf(context)?.foreground ?? Colors.white;
    if (AppGlassScope.controlsEnabled(context)) {
      return Tooltip(
        message: label,
        child: GlassIconButton(
          icon: Icon(icon, color: foreground),
          onPressed: onPressed,
          semanticLabel: label,
          useOwnLayer: true,
          quality: AppGlassScope.qualityOf(context),
        ),
      );
    }
    return IconButton(
      onPressed: onPressed,
      tooltip: label,
      icon: Icon(icon, color: foreground),
    );
  }
}
