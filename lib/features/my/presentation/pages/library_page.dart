import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/skin/app_skin_icon.dart';
import '../../../../app/theme/skin/app_skin_models.dart';
import '../../../../shared/widgets/app_adaptive_controls.dart';
import '../../../../shared/widgets/app_list_tile.dart';
import '../widgets/library_playlist_shelf.dart';

/// A tab that links to the existing local, download and collection workflows.
class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (locale, signedIn) = ref.watch(
      appConfigProvider.select(
        (state) =>
            (state.localeCode, state.authToken?.trim().isNotEmpty ?? false),
      ),
    );
    String text(String key) => AppI18n.tByLocaleCode(locale, key);
    return Scaffold(
      appBar: AppNavigationBar(
        title: Text(text('tab.library')),
        actions: [
          AppIconButton(
            tooltip: text('common.search'),
            icon: const AppSkinIcon(role: AppSkinIconRole.search),
            onPressed: () => context.push(AppRoutes.onlineSearch),
          ),
        ],
      ),
      body: ListView(
        key: const PageStorageKey<String>('library-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        children: [
          AppListSection(
            header: Text(text('library.on_device')),
            children: [
              _entry(
                context,
                AppSkinIconRole.myLocalMusic,
                text('local.title'),
                AppRoutes.library,
              ),
              _entry(
                context,
                AppSkinIconRole.myDownloads,
                text('my.download'),
                AppRoutes.downloads,
              ),
              _entry(
                context,
                AppSkinIconRole.myHistory,
                text('my.entry.history'),
                AppRoutes.myHistory,
              ),
            ],
          ),
          const SizedBox(height: 24),
          AppListSection(
            header: Text(text('library.your_music')),
            children: [
              _entry(
                context,
                AppSkinIconRole.myCollection,
                text('my.collection'),
                signedIn ? AppRoutes.myCollection : _loginLocation,
              ),
              if (!signedIn)
                AppListTile(
                  leading: const AppSkinIcon(
                    role: AppSkinIconRole.settingsLogin,
                  ),
                  title: Text(text('my.profile.login_now')),
                  subtitle: Text(text('my.profile.login_hint')),
                  showChevron: true,
                  onTap: () => context.push(_loginLocation),
                ),
            ],
          ),
          if (signedIn) ...[
            const SizedBox(height: 24),
            const LibraryPlaylistShelf(),
          ],
        ],
      ),
    );
  }

  static String get _loginLocation => Uri(
    path: AppRoutes.login,
    queryParameters: const {'redirect': AppRoutes.collection},
  ).toString();

  static Widget _entry(
    BuildContext context,
    AppSkinIconRole icon,
    String title,
    String location,
  ) => AppListTile(
    leading: AppSkinIcon(role: icon),
    title: Text(title),
    showChevron: true,
    onTap: () => context.push(location),
  );
}
