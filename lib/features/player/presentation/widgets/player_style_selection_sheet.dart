import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/player/app_player_style_models.dart';
import '../../../../app/theme/player/app_player_style_registry.dart';

class PlayerStyleSelectionSheet extends ConsumerWidget {
  const PlayerStyleSelectionSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final styles = AppPlayerStyleRegistry.instance.styles;
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
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: styles.length,
              itemBuilder: (context, index) {
                final style = styles[index];
                return _PlayerStyleOption(
                  style: style,
                  label: AppI18n.t(config, style.metadata.labelKey),
                  selected: style.metadata.id == config.playerStyleId,
                  onTap: () {
                    ref
                        .read(appConfigProvider.notifier)
                        .setPlayerStyleId(style.metadata.id);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerStyleOption extends StatelessWidget {
  const _PlayerStyleOption({
    required this.style,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppPlayerStylePackage style;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = style.colors;
    final borderColor = selected
        ? colors.accent
        : colors.controlBorder.withValues(alpha: 0.78);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey<String>('player-style-option-${style.metadata.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.controlSurface,
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
                            colors.backgroundStart,
                            colors.backgroundEnd,
                          ],
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          Image.asset(
                            style.metadata.previewAsset,
                            key: ValueKey<String>(
                              'player-style-preview-${style.metadata.id}',
                            ),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return _PlayerStylePreviewFallback(style: style);
                            },
                          ),
                          if (selected)
                            Align(
                              alignment: Alignment.topRight,
                              child: Container(
                                key: ValueKey<String>(
                                  'player-style-selected-${style.metadata.id}',
                                ),
                                width: 28,
                                height: 28,
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: colors.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: style.colors.backgroundEnd,
                                ),
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
                        label,
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
  const _PlayerStylePreviewFallback({required this.style});

  final AppPlayerStylePackage style;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ValueKey<String>(
        'player-style-preview-fallback-${style.metadata.id}',
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            style.colors.backgroundStart,
            style.colors.backgroundEnd,
          ],
        ),
      ),
      child: Icon(
        switch (style.stageKind) {
          AppPlayerStageKind.classic => Icons.album_rounded,
          AppPlayerStageKind.vinyl => Icons.radio_button_checked_rounded,
          AppPlayerStageKind.cassette => Icons.audiotrack_rounded,
          AppPlayerStageKind.artistPhoto => Icons.photo_rounded,
        },
        size: 38,
        color: style.colors.secondaryForeground,
      ),
    );
  }
}
