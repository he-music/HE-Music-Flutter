import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_ui_theme.dart';
import '../../../../app/theme/skin/app_skin_background.dart';
import '../../../../app/theme/skin/app_skin_icon.dart';
import '../../../../app/theme/skin/app_skin_models.dart';
import '../../../../app/theme/skin/app_skin_surface.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../../shared/widgets/animated_skeleton.dart';
import '../../../../shared/widgets/app_adaptive_controls.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_list_tile.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../domain/entities/my_overview_state.dart';
import '../providers/my_overview_providers.dart';

class MyPage extends ConsumerStatefulWidget {
  const MyPage({super.key});

  @override
  ConsumerState<MyPage> createState() => _MyPageState();
}

class _MyPageState extends ConsumerState<MyPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platform = theme.platform;
    ref.watch(
      appConfigProvider.select(
        (config) => (config.localeCode, config.authToken),
      ),
    );
    final config = ref.read(appConfigProvider);
    final state = ref.watch(myOverviewControllerProvider);
    final tokenSet = config.authToken != null && config.authToken!.isNotEmpty;
    final overview = state.overview;
    final profileLoading =
        tokenSet && overview == null && state.errorMessage == null;
    final showQrScanEntry =
        platform == TargetPlatform.android || platform == TargetPlatform.iOS;
    _syncOverviewLoading(tokenSet, state);
    final header = Row(
      children: <Widget>[
        Expanded(
          child: Text(
            AppI18n.t(config, 'my.title'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        if (showQrScanEntry)
          AppIconButton(
            tooltip: AppI18n.t(config, 'common.scan'),
            onPressed: () => context.push(AppRoutes.loginQrScan),
            icon: const AppSkinIcon(role: AppSkinIconRole.scan),
          ),
        AppIconButton(
          tooltip: AppI18n.t(config, 'settings.title'),
          onPressed: () => context.push(AppRoutes.settings),
          icon: const AppSkinIcon(role: AppSkinIconRole.settings),
        ),
      ],
    );
    final Widget accountCard = profileLoading
        ? const _AccountCardLoadingSkeleton()
        : _AccountCard(
            localeCode: config.localeCode,
            nickname: overview?.profile.nickname,
            username: overview?.profile.username,
            avatarUrl: overview?.profile.avatarUrl,
            tokenSet: tokenSet,
            loading: state.loading && overview != null,
            onLogin: () => _openLogin(context),
          );
    final errorCard = state.errorMessage == null
        ? null
        : _ErrorCard(
            message: state.errorMessage!,
            retryLabel: AppI18n.t(config, 'common.retry'),
            onRetry: tokenSet
                ? ref.read(myOverviewControllerProvider.notifier).refresh
                : () => _openLogin(context),
          );
    final quickEntryCards = <Widget>[
      if (tokenSet) ...[
        _EntryCard(
          iconRole: AppSkinIconRole.settingsAccountProfile,
          title: AppI18n.t(config, 'settings.account.profile'),
          onTap: () => context.push(AppRoutes.settingsProfile),
        ),
        const SizedBox(height: 10),
        _EntryCard(
          iconRole: AppSkinIconRole.settingsDevices,
          title: AppI18n.t(config, 'settings.device_management'),
          onTap: () => context.push(AppRoutes.settingsDevice),
        ),
        const SizedBox(height: 10),
      ],
      _EntryCard(
        iconRole: AppSkinIconRole.settings,
        title: AppI18n.t(config, 'settings.title'),
        onTap: () => context.push(AppRoutes.settings),
      ),
      const SizedBox(height: 10),
      _EntryCard(
        iconRole: AppSkinIconRole.settingsAbout,
        title: AppI18n.t(config, 'settings.about'),
        onTap: () => context.push(AppRoutes.about),
      ),
    ];
    final topInset = MediaQuery.paddingOf(context).top;
    return Stack(
      children: <Widget>[
        Positioned(
          top: -topInset,
          left: 0,
          right: 0,
          bottom: 0,
          child: const _MyBackground(),
        ),
        ListView(
          physics: AppUiTheme.usesCupertino(context)
              ? const BouncingScrollPhysics()
              : null,
          padding: EdgeInsets.fromLTRB(
            LayoutTokens.compactPageGutter,
            topInset + 8,
            LayoutTokens.compactPageGutter,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: <Widget>[
            header,
            const SizedBox(height: 12),
            accountCard,
            if (errorCard != null) ...<Widget>[
              const SizedBox(height: 12),
              errorCard,
            ],
            const SizedBox(height: 18),
            ...quickEntryCards,
          ],
        ),
      ],
    );
  }

  void _syncOverviewLoading(bool tokenSet, MyOverviewState state) {
    if (!tokenSet) {
      if (state.loading ||
          state.overview != null ||
          state.errorMessage != null) {
        Future.microtask(() {
          ref.read(myOverviewControllerProvider.notifier).clear();
        });
      }
      return;
    }
    if (!state.loading &&
        state.overview == null &&
        state.errorMessage == null) {
      Future.microtask(() {
        ref.read(myOverviewControllerProvider.notifier).initialize();
      });
    }
  }

  void _openLogin(BuildContext context) {
    context.push(
      Uri(
        path: AppRoutes.login,
        queryParameters: const <String, String>{'redirect': AppRoutes.my},
      ).toString(),
    );
  }
}

class _MyBackground extends StatelessWidget {
  const _MyBackground();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppSkinLegacyPageBackground(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                theme.colorScheme.primaryContainer.withValues(alpha: 0.10),
                theme.colorScheme.surface.withValues(alpha: 0.98),
                theme.scaffoldBackgroundColor,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.localeCode,
    required this.nickname,
    required this.username,
    required this.avatarUrl,
    required this.tokenSet,
    required this.loading,
    required this.onLogin,
  });

  final String localeCode;
  final String? nickname;
  final String? username;
  final String? avatarUrl;
  final bool tokenSet;
  final bool loading;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayName = (nickname ?? '').trim().isNotEmpty
        ? nickname!.trim()
        : ((username ?? '').trim().isNotEmpty
              ? username!.trim()
              : AppI18n.tByLocaleCode(localeCode, 'my.profile.guest'));
    final subtitle = tokenSet
        ? ((username ?? '').trim().isEmpty
              ? AppI18n.tByLocaleCode(localeCode, 'my.profile.logged_in')
              : '@${username!.trim()}')
        : AppI18n.tByLocaleCode(localeCode, 'my.profile.login_hint');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          AppNetworkAvatar(
            imageUrl: avatarUrl,
            radius: 30,
            backgroundColor: colorScheme.primaryContainer,
            fallbackIcon: Icons.person_rounded,
            iconColor: colorScheme.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (loading)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: AppLoadingIndicator(
                      label: AppI18n.tByLocaleCode(localeCode, 'home.loading'),
                    ),
                  )
                else if (!tokenSet) ...<Widget>[
                  const SizedBox(height: 12),
                  AppButton.filled(
                    onPressed: onLogin,
                    child: Text(
                      AppI18n.tByLocaleCode(localeCode, 'my.profile.login_now'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCardLoadingSkeleton extends StatelessWidget {
  const _AccountCardLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('my-account-loading-skeleton'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: const Row(
        children: <Widget>[
          SkeletonBox(width: 60, height: 60, radius: 30),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SkeletonBox(width: 148, height: 22, radius: 10),
                SizedBox(height: 8),
                SkeletonBox(width: 108, height: 14, radius: 7),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.iconRole,
    required this.title,
    required this.onTap,
  });

  final AppSkinIconRole iconRole;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (AppUiTheme.usesCupertino(context)) {
      return AppListSection(
        children: [
          AppListTile(
            leading: AppSkinIcon(role: iconRole),
            title: Text(title),
            showChevron: true,
            onTap: onTap,
          ),
        ],
      );
    }
    return AppSkinSurface(
      role: AppSkinSurfaceRole.scrollingContent,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.64,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AppSkinIcon(
                    role: iconRole,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline_rounded, color: colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
          const SizedBox(width: 10),
          AppButton.text(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    );
  }
}
