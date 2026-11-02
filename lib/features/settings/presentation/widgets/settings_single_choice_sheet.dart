import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_ui_theme.dart';
import '../../../../app/theme/player/app_player_style_bottom_sheet.dart';
import '../../../../app/theme/skin/app_skin_bottom_sheet.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../../shared/widgets/app_list_tile.dart';
import '../../../../shared/utils/platform_utils.dart';
import '../../../../shared/widgets/adaptive_action_menu.dart';

class SettingsChoiceOption<T> {
  const SettingsChoiceOption({
    required this.value,
    required this.title,
    this.subtitle,
    this.leading,
    this.section,
  });

  final T value;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final String? section;
}

Future<void> showSettingsSingleChoiceSheet<T>({
  required BuildContext context,
  required String title,
  required T currentValue,
  required List<SettingsChoiceOption<T>> options,
  required ValueChanged<T> onSelected,
  bool playerStyled = false,
  bool useCupertinoActionSheet = false,
}) async {
  if (useCupertinoActionSheet &&
      AppUiTheme.usesCupertino(context) &&
      !shouldUseDesktopMenu(context)) {
    final selected = await showAdaptiveActionMenu<T>(
      context: context,
      title: Text(title),
      items: [
        for (final option in options)
          AdaptiveActionMenuItem(
            value: option.value,
            label: option.title,
            selected: option.value == currentValue,
          ),
      ],
    );
    if (selected != null && context.mounted) onSelected(selected);
    return;
  }

  Widget builder(BuildContext sheetContext) {
    final cupertino = AppUiTheme.usesCupertino(sheetContext);
    final theme = Theme.of(sheetContext);
    Widget buildOption(SettingsChoiceOption<T> option) {
      final selected = option.value == currentValue;
      return Semantics(
        selected: selected,
        child: AppListTile(
          leading: option.leading,
          title: Text(option.title),
          subtitle: option.subtitle == null ? null : Text(option.subtitle!),
          trailing: selected
              ? ExcludeSemantics(
                  child: Icon(
                    cupertino ? CupertinoIcons.check_mark : Icons.check_rounded,
                    color: theme.colorScheme.primary,
                  ),
                )
              : null,
          onTap: () {
            onSelected(option.value);
            Navigator.of(sheetContext).pop();
          },
        ),
      );
    }

    final groups = <(String?, List<SettingsChoiceOption<T>>)>[];
    if (cupertino) {
      for (final option in options) {
        if (groups.isEmpty || groups.last.$1 != option.section) {
          groups.add((option.section, <SettingsChoiceOption<T>>[]));
        }
        groups.last.$2.add(option);
      }
    }
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: cupertino
                    ? CupertinoTheme.of(
                        sheetContext,
                      ).textTheme.navTitleTextStyle
                    : theme.textTheme.titleMedium,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: cupertino
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                  : EdgeInsets.zero,
              children: <Widget>[
                if (cupertino)
                  for (final (heading, groupOptions) in groups)
                    CupertinoListSection.insetGrouped(
                      margin: const EdgeInsets.only(bottom: 16),
                      backgroundColor: Colors.transparent,
                      // A modal is a control surface, independent of the
                      // content-card background preference.
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh
                            .withValues(alpha: 1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      hasLeading: groupOptions.any(
                        (option) => option.leading != null,
                      ),
                      header: heading == null
                          ? null
                          : Semantics(header: true, child: Text(heading)),
                      children: groupOptions.map(buildOption).toList(),
                    )
                else
                  for (final option in options) ...[
                    if (option.section != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                        child: Text(
                          option.section!,
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                    buildOption(option),
                  ],
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  return playerStyled
      ? showPlayerStyledBottomSheet<void>(
          context: context,
          builder: builder,
          fitContent: true,
          heightFactor: LayoutTokens.selectionSheetMaxHeightFactor,
        )
      : showAppThemedBottomSheet<void>(
          context: context,
          fitContent: true,
          heightFactor: LayoutTokens.selectionSheetMaxHeightFactor,
          showDragHandle: true,
          builder: builder,
        );
}
