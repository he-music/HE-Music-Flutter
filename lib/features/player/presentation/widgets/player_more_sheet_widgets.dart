import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_list_tile.dart';
import '../../../../app/theme/app_ui_theme.dart';

/// 更多操作表单的操作项
class PlayerSheetActionTile extends StatelessWidget {
  const PlayerSheetActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      enabled: enabled,
      leading: Icon(icon, size: 22),
      title: Text(title),
      subtitle:
          AppUiTheme.usesCupertino(context) || (subtitle ?? '').trim().isEmpty
          ? null
          : Text(subtitle!.trim()),
      additionalInfo:
          AppUiTheme.usesCupertino(context) &&
              (subtitle ?? '').trim().isNotEmpty
          ? Text(subtitle!.trim())
          : null,
      showChevron: enabled,
      onTap: enabled ? onTap : null,
    );
  }
}
