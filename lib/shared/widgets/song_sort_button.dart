import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_message_service.dart';
import '../../app/config/app_config_controller.dart';
import '../../app/i18n/app_i18n.dart';
import '../../app/theme/skin/app_skin_bottom_sheet.dart';
import '../providers/song_sort_providers.dart';
import '../utils/song_sort.dart';

const _defaultSongSortFields = <SongSortField>[
  SongSortField.original,
  SongSortField.title,
  SongSortField.artist,
  SongSortField.album,
  SongSortField.duration,
  SongSortField.size,
];

class SongSortButton extends ConsumerWidget {
  const SongSortButton({
    this.enabled = true,
    this.allowSize = false,
    this.allowDuration = true,
    this.onChanged,
    this.preference,
    this.fields,
    super.key,
  }) : assert(fields == null || fields.length > 0),
       assert(preference == null || onChanged != null);

  final bool enabled;
  final bool allowSize;
  final bool allowDuration;
  final FutureOr<void> Function(SongSortPreference preference)? onChanged;

  /// When supplied, the caller owns persistence and applies [onChanged].
  final SongSortPreference? preference;

  /// Available fields for this list; excludes local-only fields by default.
  final List<SongSortField>? fields;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPreference =
        preference ?? ref.watch<SongSortPreference>(songSortPreferenceProvider);
    final localeCode = ref.watch(
      appConfigProvider.select((config) => config.localeCode),
    );
    String text(String key) => AppI18n.tByLocaleCode(localeCode, key);
    final fields = this.fields ?? _defaultSongSortFields;
    final supported =
        fields.contains(currentPreference.field) &&
        (currentPreference.field != SongSortField.duration || allowDuration) &&
        (currentPreference.field != SongSortField.size || allowSize);
    final active =
        enabled &&
        supported &&
        currentPreference.field != SongSortField.original;
    final fieldLabel = text(
      'song_sort.field.${active ? currentPreference.field.name : 'original'}',
    );
    final buttonLabel = active ? fieldLabel : text('song_sort.default_label');
    final summary = !enabled
        ? text('song_sort.load_all_first')
        : active
        ? '${text('song_sort.title')}: $fieldLabel · ${text(currentPreference.ascending ? 'song_sort.ascending' : 'song_sort.descending')}'
        : '${text('song_sort.title')}: $fieldLabel';

    return Tooltip(
      message: summary,
      excludeFromSemantics: true,
      child: TextButton(
        key: const Key('song-sort-button'),
        style: TextButton.styleFrom(
          foregroundColor: active
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        onPressed: enabled
            ? () async {
                final next = await showAppThemedBottomSheet<SongSortPreference>(
                  context: context,
                  heightFactor: 0.85,
                  fitContent: true,
                  builder: (context) => _SongSortSheet(
                    initial: supported
                        ? currentPreference
                        : SongSortPreference(field: fields.first),
                    allowSize: allowSize,
                    allowDuration: allowDuration,
                    fields: fields,
                    localeCode: localeCode,
                  ),
                );
                if (next == null ||
                    next == currentPreference ||
                    !context.mounted) {
                  return;
                }
                final save = preference == null
                    ? ref
                          .read(songSortPreferenceProvider.notifier)
                          .setPreference(next)
                          .catchError((Object error) {
                            AppMessageService.showError(
                              text('song_sort.save_failed'),
                            );
                          })
                    : Future<void>.value();
                await Future.wait<void>([
                  save,
                  Future<void>.sync(() => onChanged?.call(next)),
                ]);
              }
            : null,
        child: Semantics(
          label: summary,
          excludeSemantics: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  buttonLabel,
                  key: const Key('song-sort-label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                active
                    ? currentPreference.ascending
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded
                    : Icons.unfold_more_rounded,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SongSortSheet extends StatefulWidget {
  const _SongSortSheet({
    required this.initial,
    required this.fields,
    required this.allowSize,
    required this.allowDuration,
    required this.localeCode,
  });

  final SongSortPreference initial;
  final bool allowSize;
  final bool allowDuration;
  final String localeCode;
  final List<SongSortField> fields;

  @override
  State<_SongSortSheet> createState() => _SongSortSheetState();
}

class _SongSortSheetState extends State<_SongSortSheet> {
  late SongSortField _field = widget.initial.field;
  late bool _ascending = widget.initial.ascending;

  String text(String key) => AppI18n.tByLocaleCode(widget.localeCode, key);

  void _selectField(SongSortField field) {
    if (_field == field) return;
    setState(() {
      _field = field;
      _ascending = field.defaultAscending;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fields = [
      for (final field in widget.fields)
        if ((field != SongSortField.size || widget.allowSize) &&
            (field != SongSortField.duration || widget.allowDuration))
          field,
    ];
    final directionEnabled = _field != SongSortField.original;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          key: const Key('song-sort-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      text('song_sort.title'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('song-sort-close'),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                key: const Key('song-sort-options'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SortSectionLabel(text('song_sort.field_label')),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final textScale =
                            MediaQuery.textScalerOf(context).scale(14) / 14;
                        final columns =
                            (constraints.maxWidth /
                                    (140 * textScale.clamp(1.0, 2.0)))
                                .floor()
                                .clamp(1, 3);
                        final width =
                            (constraints.maxWidth - (columns - 1) * 8) /
                            columns;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final field in fields)
                              SizedBox(
                                width: width,
                                child: _SortChoice(
                                  key: ValueKey(
                                    'song-sort-field-${field.name}',
                                  ),
                                  label: text('song_sort.field.${field.name}'),
                                  icon: switch (field) {
                                    SongSortField.original =>
                                      Icons.format_list_numbered_rounded,
                                    SongSortField.title => Icons.title_rounded,
                                    SongSortField.artist =>
                                      Icons.person_outline_rounded,
                                    SongSortField.album => Icons.album_outlined,
                                    SongSortField.duration =>
                                      Icons.schedule_rounded,
                                    SongSortField.size => Icons.storage_rounded,
                                    SongSortField.createdAt =>
                                      Icons.playlist_add_rounded,
                                  },
                                  selected: _field == field,
                                  onTap: () => _selectField(field),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _SortSectionLabel(text('song_sort.order_label')),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final textScale =
                            MediaQuery.textScalerOf(context).scale(14) / 14;
                        if (constraints.maxWidth < 260 * textScale) {
                          return Column(
                            key: const Key('song-sort-direction'),
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final ascending in [true, false]) ...[
                                if (!ascending) const SizedBox(height: 8),
                                _SortChoice(
                                  label: text(
                                    ascending
                                        ? 'song_sort.ascending'
                                        : 'song_sort.descending',
                                  ),
                                  icon: ascending
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  selected: _ascending == ascending,
                                  onTap: directionEnabled
                                      ? () => setState(
                                          () => _ascending = ascending,
                                        )
                                      : null,
                                ),
                              ],
                            ],
                          );
                        }
                        return SegmentedButton<bool>(
                          key: const Key('song-sort-direction'),
                          expandedInsets: EdgeInsets.zero,
                          showSelectedIcon: false,
                          style: const ButtonStyle(
                            minimumSize: WidgetStatePropertyAll(Size(0, 48)),
                            padding: WidgetStatePropertyAll(
                              EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                          segments: [
                            ButtonSegment(
                              value: true,
                              enabled: directionEnabled,
                              icon: const Icon(
                                Icons.arrow_upward_rounded,
                                size: 18,
                              ),
                              label: Text(text('song_sort.ascending')),
                            ),
                            ButtonSegment(
                              value: false,
                              enabled: directionEnabled,
                              icon: const Icon(
                                Icons.arrow_downward_rounded,
                                size: 18,
                              ),
                              label: Text(text('song_sort.descending')),
                            ),
                          ],
                          selected: {_ascending},
                          onSelectionChanged: directionEnabled
                              ? (values) =>
                                    setState(() => _ascending = values.single)
                              : null,
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('song-sort-confirm'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onPressed: () => Navigator.of(
                context,
              ).pop(SongSortPreference(field: _field, ascending: _ascending)),
              child: Text(text('common.confirm')),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortSectionLabel extends StatelessWidget {
  const _SortSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _SortChoice extends StatelessWidget {
  const _SortChoice({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = onTap == null
        ? colors.onSurface.withValues(alpha: 0.38)
        : selected
        ? colors.onPrimaryContainer
        : colors.onSurface;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: selected && onTap != null
            ? colors.primary
            : colors.outlineVariant,
        width: selected ? 1.5 : 1,
      ),
    );
    return Semantics(
      enabled: onTap != null,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: selected
            ? onTap == null
                  ? colors.onSurface.withValues(alpha: 0.04)
                  : colors.primaryContainer
            : colors.onSurface.withValues(alpha: 0.04),
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    selected ? Icons.check_circle_rounded : icon,
                    size: 20,
                    color: onTap == null
                        ? foreground
                        : selected
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
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
