import 'package:flutter/material.dart';

import '../../../../app/theme/skin/app_skin_icon.dart';
import '../../../../app/theme/skin/app_skin_models.dart';
import '../../../../shared/widgets/app_adaptive_controls.dart';
import '../../../../shared/widgets/app_list_tile.dart';

class SettingsSectionTile extends StatelessWidget {
  const SettingsSectionTile({
    required this.icon,
    required this.iconRole,
    required this.title,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final AppSkinIconRole iconRole;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AppListSection(
    children: [
      AppListTile(
        enabled: onTap != null,
        leading: AppSkinIcon(role: iconRole),
        title: Text(title),
        showChevron: true,
        onTap: onTap,
      ),
    ],
  );
}

class SettingsSelectTile extends StatelessWidget {
  const SettingsSelectTile({
    required this.icon,
    required this.iconRole,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailingText,
    this.leadingTrailing,
    this.highlighted = false,
    super.key,
  });

  final IconData icon;
  final AppSkinIconRole iconRole;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final String? trailingText;
  final Widget? leadingTrailing;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => _SettingsTileShell(
    highlighted: highlighted,
    child: AppListTile(
      enabled: onTap != null,
      leading: AppSkinIcon(role: iconRole),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      additionalInfo: trailingText == null && leadingTrailing == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leadingTrailing != null) ...[
                  leadingTrailing!,
                  const SizedBox(width: 8),
                ],
                if (trailingText != null) Flexible(child: Text(trailingText!)),
              ],
            ),
      showChevron: onTap != null,
      onTap: onTap,
    ),
  );
}

class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    required this.icon,
    required this.iconRole,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.highlighted = false,
    super.key,
  });

  final IconData icon;
  final AppSkinIconRole iconRole;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => _SettingsTileShell(
    highlighted: highlighted,
    child: AppSwitchListTile(
      value: value,
      onChanged: enabled ? onChanged : null,
      secondary: AppSkinIcon(role: iconRole),
      title: Text(title),
      subtitle: Text(subtitle),
    ),
  );
}

class SettingsNavigationTile extends StatelessWidget {
  const SettingsNavigationTile({
    required this.icon,
    required this.iconRole,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
    super.key,
  });

  final IconData icon;
  final AppSkinIconRole iconRole;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => _SettingsTileShell(
    highlighted: highlighted,
    child: AppListTile(
      leading: AppSkinIcon(role: iconRole),
      title: Text(title),
      subtitle: Text(subtitle),
      showChevron: true,
      onTap: onTap,
    ),
  );
}

class SettingsActionTile extends StatelessWidget {
  const SettingsActionTile({
    required this.icon,
    required this.iconRole,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
    this.highlighted = false,
    super.key,
  });

  final IconData icon;
  final AppSkinIconRole iconRole;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final foreground = destructive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurface;
    return _SettingsTileShell(
      highlighted: highlighted,
      child: AppListTile(
        leading: AppSkinIcon(role: iconRole, color: foreground),
        title: Text(title, style: TextStyle(color: foreground)),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}

class SettingsSearchResultTile extends StatelessWidget {
  const SettingsSearchResultTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppListTile(
    leading: const AppSkinIcon(role: AppSkinIconRole.search),
    title: Text(title),
    subtitle: Text(subtitle),
    showChevron: true,
    onTap: onTap,
  );
}

class SettingsColorDot extends StatelessWidget {
  const SettingsColorDot({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 18,
    height: 18,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
  );
}

class _SettingsTileShell extends StatelessWidget {
  const _SettingsTileShell({required this.child, required this.highlighted});

  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220),
    color: highlighted
        ? Theme.of(context).colorScheme.secondaryContainer
        : Colors.transparent,
    child: child,
  );
}
