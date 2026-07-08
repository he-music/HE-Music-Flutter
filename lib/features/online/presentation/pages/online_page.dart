import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/app_message_service.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../providers/online_providers.dart';
import '../widgets/online_cards.dart';

const _defaultResourceType = 'song';
const _defaultSearchPlatform = 'kuwo';

class OnlinePage extends ConsumerStatefulWidget {
  const OnlinePage({super.key});

  @override
  ConsumerState<OnlinePage> createState() => _OnlinePageState();
}

class _OnlinePageState extends ConsumerState<OnlinePage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _playlistNameController = TextEditingController();
  final _playlistFavoriteIdController = TextEditingController();
  final _commentResourceIdController = TextEditingController();
  final _resourceTypeController = TextEditingController(
    text: _defaultResourceType,
  );

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final state = ref.watch(onlineControllerProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(AppI18n.t(config, 'online.center.title')),
      ),
      body: SafeArea(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: <Widget>[
            OnlineHeroCard(
              title: AppI18n.t(config, 'online.hero.title'),
              subtitle: AppI18n.t(config, 'online.hero.subtitle'),
              trailing: FilledButton.icon(
                onPressed: _fetchProfile,
                icon: const Icon(Icons.sync_rounded),
                label: Text(AppI18n.t(config, 'online.action.sync')),
              ),
            ),
            const SizedBox(height: 12),
            ConfigCard(config: config),
            const SizedBox(height: 12),
            LoginCard(
              usernameController: _usernameController,
              passwordController: _passwordController,
              onLogin: _login,
              onFetchProfile: _fetchProfile,
            ),
            const SizedBox(height: 12),
            QuickActionsCard(
              onOpenSearchPage: () => context.push(
                Uri(
                  path: AppRoutes.onlineSearch,
                  queryParameters: const <String, String>{
                    'platform': _defaultSearchPlatform,
                  },
                ).toString(),
              ),
              onFetchProfile: _fetchProfile,
            ),
            const SizedBox(height: 12),
            SearchEntryCard(
              onOpenSearchPage: () => context.push(
                Uri(
                  path: AppRoutes.onlineSearch,
                  queryParameters: const <String, String>{
                    'platform': _defaultSearchPlatform,
                  },
                ).toString(),
              ),
            ),
            const SizedBox(height: 12),
            PlaylistCard(
              playlistNameController: _playlistNameController,
              playlistFavoriteIdController: _playlistFavoriteIdController,
              onCreate: _createPlaylist,
              onFavorite: _favoritePlaylist,
              onUnfavorite: _unfavoritePlaylist,
            ),
            const SizedBox(height: 12),
            CommentCard(
              commentResourceIdController: _commentResourceIdController,
              resourceTypeController: _resourceTypeController,
              onLoadComments: _loadComments,
            ),
            const SizedBox(height: 12),
            ResultCard(state: state),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _playlistNameController.dispose();
    _playlistFavoriteIdController.dispose();
    _commentResourceIdController.dispose();
    _resourceTypeController.dispose();
    super.dispose();
  }

  Future<void> _login() {
    return _runAction(() {
      return ref
          .read(onlineControllerProvider.notifier)
          .login(
            username: _usernameController.text,
            password: _passwordController.text,
          );
    });
  }

  Future<void> _fetchProfile() {
    return _runAction(ref.read(onlineControllerProvider.notifier).fetchProfile);
  }

  Future<void> _createPlaylist() {
    return _runAction(() {
      return ref
          .read(onlineControllerProvider.notifier)
          .createPlaylist(_playlistNameController.text);
    });
  }

  Future<void> _favoritePlaylist() {
    return _runAction(() {
      return ref
          .read(onlineControllerProvider.notifier)
          .togglePlaylistFavorite(
            playlistId: _playlistFavoriteIdController.text,
            platform: _defaultSearchPlatform,
            like: true,
          );
    });
  }

  Future<void> _unfavoritePlaylist() {
    return _runAction(() {
      return ref
          .read(onlineControllerProvider.notifier)
          .togglePlaylistFavorite(
            playlistId: _playlistFavoriteIdController.text,
            platform: _defaultSearchPlatform,
            like: false,
          );
    });
  }

  Future<void> _loadComments() {
    return _runAction(() {
      return ref
          .read(onlineControllerProvider.notifier)
          .fetchComments(
            resourceId: _commentResourceIdController.text,
            resourceType: _resourceTypeController.text,
            platform: _defaultSearchPlatform,
          );
    });
  }

  Future<void> _runAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      AppMessageService.showError('$error');
    }
  }
}
