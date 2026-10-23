import 'package:flutter/material.dart';
import '../../../../app/i18n/app_i18n.dart';

class SearchFeedback extends StatelessWidget {
  const SearchFeedback({
    required this.localeCode,
    this.error,
    this.onRetry,
    this.onEditQuery,
    super.key,
  });

  final String localeCode;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback? onEditQuery;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            error == null ? Icons.search_off : Icons.cloud_off_outlined,
            size: 32,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            error ?? AppI18n.tByLocaleCode(localeCode, 'search.result.empty'),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            AppI18n.tByLocaleCode(
              localeCode,
              error == null ? 'search.empty_hint' : 'search.retry_hint',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              if (error != null && onRetry != null)
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: Text(
                    AppI18n.tByLocaleCode(localeCode, 'common.retry'),
                  ),
                ),
              if (onEditQuery != null)
                TextButton(
                  onPressed: onEditQuery,
                  child: Text(
                    AppI18n.tByLocaleCode(localeCode, 'search.edit_query'),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
