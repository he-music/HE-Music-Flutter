import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../app/i18n/app_i18n.dart';
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
    this.cupertinoTitleStyle,
  });

  final T value;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final String? section;
  final TextStyle? cupertinoTitleStyle;
}

Future<void> showSettingsSingleChoiceSheet<T>({
  required BuildContext context,
  required String title,
  required T currentValue,
  required List<SettingsChoiceOption<T>> options,
  required ValueChanged<T> onSelected,
  Widget? cupertinoPreview,
  String? cupertinoFooter,
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
          title: Text(
            option.title,
            style: cupertino ? option.cupertinoTitleStyle : null,
          ),
          subtitle: option.subtitle == null ? null : Text(option.subtitle!),
          trailing: cupertino
              ? SizedBox.square(
                  dimension: 24,
                  child: selected
                      ? ExcludeSemantics(
                          child: Icon(
                            CupertinoIcons.check_mark,
                            size: 21,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : null,
                )
              : selected
              ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
              : null,
          onTap: () {
            Navigator.of(sheetContext).pop(option.value);
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
          if (cupertino) ...[
            SizedBox(
              height: 24,
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey3.resolveFrom(
                      sheetContext,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            MediaQuery.removePadding(
              context: sheetContext,
              removeTop: true,
              child: CupertinoNavigationBar(
                automaticallyImplyLeading: false,
                transitionBetweenRoutes: false,
                enableBackgroundFilterBlur: false,
                backgroundColor: Colors.transparent,
                border: null,
                middle: Text(title),
                trailing: CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(44, 44),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(
                    AppI18n.tByLocaleCode(
                      Localizations.localeOf(sheetContext).languageCode,
                      'common.done',
                    ),
                  ),
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: cupertino
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                  : EdgeInsets.zero,
              children: <Widget>[
                if (cupertino && cupertinoPreview != null) cupertinoPreview,
                if (cupertino)
                  for (final (heading, groupOptions) in groups)
                    CupertinoListSection.insetGrouped(
                      margin: const EdgeInsets.only(bottom: 16),
                      backgroundColor: Colors.transparent,
                      // A modal is a control surface, independent of the
                      // content-card background preference.
                      decoration: BoxDecoration(
                        color: CupertinoColors.tertiarySystemGroupedBackground
                            .resolveFrom(sheetContext),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      hasLeading: groupOptions.any(
                        (option) => option.leading != null,
                      ),
                      header: heading == null
                          ? null
                          : DefaultTextStyle(
                              style: CupertinoTheme.of(sheetContext)
                                  .textTheme
                                  .textStyle
                                  .copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                              child: Semantics(
                                header: true,
                                child: Text(heading),
                              ),
                            ),
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
                if (cupertino && cupertinoFooter != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      0,
                      16,
                      12,
                    ),
                    child: Text(
                      cupertinoFooter,
                      style: CupertinoTheme.of(sheetContext).textTheme.textStyle
                          .copyWith(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                    ),
                  ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  final selected = await (playerStyled
      ? showPlayerStyledBottomSheet<T>(
          context: context,
          builder: builder,
          fitContent: true,
          useAppAccent: true,
          showDragHandle: !AppUiTheme.usesCupertino(context),
          heightFactor: LayoutTokens.selectionSheetMaxHeightFactor,
        )
      : showAppThemedBottomSheet<T>(
          context: context,
          fitContent: true,
          heightFactor: LayoutTokens.selectionSheetMaxHeightFactor,
          showDragHandle: !AppUiTheme.usesCupertino(context),
          builder: builder,
        ));
  if (selected != null && context.mounted) onSelected(selected);
}
