import 'package:flutter/material.dart';

class SettingsChoiceOption<T> {
  const SettingsChoiceOption({
    required this.value,
    required this.title,
    this.subtitle,
    this.leading,
  });

  final T value;
  final String title;
  final String? subtitle;
  final Widget? leading;
}

Future<void> showSettingsSingleChoiceSheet<T>({
  required BuildContext context,
  required String title,
  required T currentValue,
  required List<SettingsChoiceOption<T>> options,
  required ValueChanged<T> onSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  for (final option in options)
                    ListTile(
                      leading: option.leading,
                      title: Text(option.title),
                      subtitle: option.subtitle == null
                          ? null
                          : Text(option.subtitle!),
                      trailing: option.value == currentValue
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () {
                        onSelected(option.value);
                        Navigator.of(sheetContext).pop();
                      },
                    ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
