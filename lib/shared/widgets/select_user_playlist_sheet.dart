import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/i18n/app_i18n.dart';
import '../../features/my/domain/entities/my_favorite_item.dart';
import '../../features/my/presentation/providers/my_playlist_shelf_providers.dart';
import '../utils/playlist_song_count_text.dart';
import '../../features/online/presentation/widgets/search_playlist_list_item.dart';

class SelectedUserPlaylist {
  const SelectedUserPlaylist({required this.id, required this.isDefault});

  final String id;
  final bool isDefault;
}

Future<SelectedUserPlaylist?> showSelectUserPlaylistSheet(
  BuildContext context, {
  String? excludedPlaylistId,
}) {
  return showModalBottomSheet<SelectedUserPlaylist>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SelectUserPlaylistSheet(excludedPlaylistId: excludedPlaylistId);
    },
  );
}

class SelectUserPlaylistSheet extends ConsumerWidget {
  const SelectUserPlaylistSheet({this.excludedPlaylistId, super.key});

  final String? excludedPlaylistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final asyncValue = ref.watch(myCreatedPlaylistsProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: asyncValue.when(
            data: (items) => _PlaylistListView(
              items: items,
              excludedPlaylistId: excludedPlaylistId,
              localeCode: localeCode,
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => _SheetHint(
              title: AppI18n.tByLocaleCode(
                localeCode,
                'detail.batch.playlist_load_failed',
              ),
              actionLabel: AppI18n.tByLocaleCode(localeCode, 'common.retry'),
              onAction: () => ref.invalidate(myCreatedPlaylistsProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistListView extends StatelessWidget {
  const _PlaylistListView({
    required this.items,
    required this.excludedPlaylistId,
    required this.localeCode,
  });

  final List<MyFavoriteItem> items;
  final String? excludedPlaylistId;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items
        .where((item) => item.id.trim() != (excludedPlaylistId ?? '').trim())
        .toList(growable: false);
    if (visibleItems.isEmpty) {
      return _SheetHint(
        title: AppI18n.tByLocaleCode(localeCode, 'detail.batch.playlist_empty'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            AppI18n.tByLocaleCode(localeCode, 'detail.batch.select_playlist'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: visibleItems.length,
            separatorBuilder: (context, index) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final item = visibleItems[index];
              return SearchPlaylistListItem(
                title: item.title,
                subtitle: item.subtitle,
                coverUrl: item.coverUrl,
                songCountText: buildPlaylistSongCountText(
                  count: item.songCount,
                  localeCode: localeCode,
                ),
                onTap: () {
                  Navigator.of(context).pop(
                    SelectedUserPlaylist(
                      id: item.id.trim(),
                      isDefault: item.isDefault,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SheetHint extends StatelessWidget {
  const _SheetHint({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
