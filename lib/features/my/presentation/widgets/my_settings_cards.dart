import 'package:flutter/material.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/config/app_theme_mode.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../shared/widgets/glass_panel.dart';

class MyThemeCard extends StatelessWidget {
  const MyThemeCard({
    required this.config,
    required this.controller,
    super.key,
  });

  final AppConfigState config;
  final AppConfigController controller;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: BorderRadius.circular(28),
      blurSigma: 0,
      tintColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.42),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppI18n.t(config, 'my.theme'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          SegmentedButton<AppThemeMode>(
            segments: <ButtonSegment<AppThemeMode>>[
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.system,
                label: Text(AppI18n.t(config, 'my.theme.system')),
              ),
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.light,
                label: Text(AppI18n.t(config, 'my.theme.light')),
              ),
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.dark,
                label: Text(AppI18n.t(config, 'my.theme.dark')),
              ),
            ],
            selected: <AppThemeMode>{config.themeMode},
            onSelectionChanged: (selection) {
              if (selection.isEmpty) {
                return;
              }
              controller.setThemeMode(selection.first);
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(AppI18n.t(config, 'my.monochrome')),
            value: config.isMonochrome,
            onChanged: (_) => controller.toggleMonochrome(),
          ),
        ],
      ),
    );
  }
}

class MyLanguageCard extends StatelessWidget {
  const MyLanguageCard({
    required this.config,
    required this.controller,
    super.key,
  });

  final AppConfigState config;
  final AppConfigController controller;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: BorderRadius.circular(28),
      blurSigma: 0,
      tintColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.42),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            AppI18n.t(config, 'my.language'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: <Widget>[
              ChoiceChip(
                label: Text(AppI18n.t(config, 'my.language.system')),
                selected: config.localeCode == 'system',
                onSelected: (_) => controller.setLocaleCode('system'),
              ),
              ChoiceChip(
                label: Text(AppI18n.t(config, 'my.language.zh')),
                selected: config.localeCode == 'zh',
                onSelected: (_) => controller.setLocaleCode('zh'),
              ),
              ChoiceChip(
                label: Text(AppI18n.t(config, 'my.language.en')),
                selected: config.localeCode == 'en',
                onSelected: (_) => controller.setLocaleCode('en'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
