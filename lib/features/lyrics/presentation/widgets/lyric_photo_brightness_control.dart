import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/player/app_player_style_bottom_sheet.dart';

String _brightnessLabel(double brightness, String locale) {
  final percentage = '${(brightness * 100).round()}%';
  return brightness == 1
      ? '$percentage · ${AppI18n.tByLocaleCode(locale, 'player.lyric.background_original')}'
      : percentage;
}

class LyricPhotoBrightnessTile extends ConsumerWidget {
  const LyricPhotoBrightnessTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(
      appConfigProvider.select((config) => config.lyricPhotoBrightness),
    );
    final locale = ref.watch(
      appConfigProvider.select((config) => config.localeCode),
    );
    return ListTile(
      key: const ValueKey('lyric-photo-brightness-tile'),
      leading: const Icon(Icons.brightness_6_outlined),
      title: Text(
        AppI18n.tByLocaleCode(locale, 'player.lyric.background_brightness'),
      ),
      subtitle: Text(_brightnessLabel(brightness, locale)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showPlayerStyledBottomSheet<void>(
        context: context,
        fitContent: true,
        builder: (_) =>
            const SingleChildScrollView(child: LyricPhotoBrightnessControl()),
      ),
    );
  }
}

class LyricPhotoBrightnessControl extends ConsumerWidget {
  const LyricPhotoBrightnessControl({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = ref.watch(
      appConfigProvider.select((config) => config.lyricPhotoBrightness),
    );
    final locale = ref.watch(
      appConfigProvider.select((config) => config.localeCode),
    );
    String text(String key) => AppI18n.tByLocaleCode(locale, key);
    final controller = ref.read(appConfigProvider.notifier);
    final title = text('player.lyric.background_brightness');
    // The adjustment sheet already provides the glass surface.
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Text(
            _brightnessLabel(brightness, locale),
            key: const ValueKey('lyric-photo-brightness-value'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Row(
            children: [
              Text(text('player.lyric.background_dark')),
              Expanded(
                child: Semantics(
                  label: title,
                  child: Slider(
                    key: const ValueKey('lyric-photo-brightness-slider'),
                    value: brightness,
                    divisions: 100,
                    semanticFormatterCallback: (value) =>
                        _brightnessLabel(value, locale),
                    onChanged: (value) => controller.setLyricPhotoBrightness(
                      value,
                      persist: false,
                    ),
                    onChangeEnd: controller.setLyricPhotoBrightness,
                  ),
                ),
              ),
              Text(text('player.lyric.background_bright')),
            ],
          ),
        ],
      ),
    );
  }
}
