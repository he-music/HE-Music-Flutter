import 'package:flutter/material.dart';

import '../../app/theme/skin/app_skin_bottom_sheet.dart';
import '../constants/layout_tokens.dart';

void showDetailDescriptionSheet(
  BuildContext context, {
  required String title,
  required String text,
}) {
  final normalized = text.trim();
  if (normalized.isEmpty) return;
  showAppThemedBottomSheet<void>(
    context: context,
    fixedHeightFactor: LayoutTokens.contentSheetHeightFactor,
    builder: (context) => ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        Text(normalized),
      ],
    ),
  );
}
