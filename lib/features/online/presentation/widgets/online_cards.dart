import 'package:flutter/material.dart';

import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../domain/entities/online_feature_state.dart';

class OnlineHeroCard extends StatelessWidget {
  const OnlineHeroCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    return GlassPanel(
      borderRadius: BorderRadius.circular(32),
      blurSigma: 0,
      tintColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppI18n.tByLocaleCode(localeCode, 'online.center.title'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(subtitle, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

class OnlineSectionCard extends StatelessWidget {
  const OnlineSectionCard({
    required this.title,
    required this.child,
    this.caption,
    super.key,
  });

  final String title;
  final String? caption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      borderRadius: BorderRadius.circular(28),
      blurSigma: 0,
      tintColor: theme.colorScheme.surface.withValues(alpha: 0.42),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          if (caption != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(caption!, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class ConfigCard extends StatelessWidget {
  const ConfigCard({required this.config, super.key});

  final AppConfigState config;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final baseUrlText = config.apiBaseUrl.isEmpty
        ? AppI18n.tByLocaleCode(localeCode, 'download.none')
        : config.apiBaseUrl;
    final tokenText = config.authToken == null
        ? AppI18n.tByLocaleCode(localeCode, 'online.config.token_unset')
        : AppI18n.tByLocaleCode(localeCode, 'online.config.token_set');
    return OnlineSectionCard(
      title: AppI18n.tByLocaleCode(localeCode, 'online.config.title'),
      caption: AppI18n.tByLocaleCode(localeCode, 'online.config.caption'),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          _OnlineMetaChip(
            label: AppI18n.formatByLocaleCode(
              localeCode,
              'online.config.base',
              <String, String>{'value': baseUrlText},
            ),
          ),
          _OnlineMetaChip(label: tokenText),
        ],
      ),
    );
  }
}

class LoginCard extends StatelessWidget {
  const LoginCard({
    required this.usernameController,
    required this.passwordController,
    required this.onLogin,
    required this.onFetchProfile,
    super.key,
  });

  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final VoidCallback onLogin;
  final VoidCallback onFetchProfile;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    return OnlineSectionCard(
      title: AppI18n.tByLocaleCode(localeCode, 'online.login.title'),
      caption: AppI18n.tByLocaleCode(localeCode, 'online.login.caption'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: usernameController,
            decoration: InputDecoration(
              labelText: AppI18n.tByLocaleCode(
                localeCode,
                'online.login.username',
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: passwordController,
            decoration: InputDecoration(
              labelText: AppI18n.tByLocaleCode(
                localeCode,
                'online.login.password',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              FilledButton(
                onPressed: onLogin,
                child: Text(
                  AppI18n.tByLocaleCode(localeCode, 'online.login.submit'),
                ),
              ),
              OutlinedButton(
                onPressed: onFetchProfile,
                child: Text(
                  AppI18n.tByLocaleCode(localeCode, 'online.login.profile'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({
    required this.onOpenSearchPage,
    required this.onFetchProfile,
    super.key,
  });

  final VoidCallback onOpenSearchPage;
  final VoidCallback onFetchProfile;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    return OnlineSectionCard(
      title: AppI18n.tByLocaleCode(localeCode, 'online.quick.title'),
      caption: AppI18n.tByLocaleCode(localeCode, 'online.quick.caption'),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _QuickActionTile(
              icon: Icons.search_rounded,
              title: AppI18n.tByLocaleCode(
                localeCode,
                'online.quick.search.title',
              ),
              subtitle: AppI18n.tByLocaleCode(
                localeCode,
                'online.quick.search.subtitle',
              ),
              onTap: onOpenSearchPage,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _QuickActionTile(
              icon: Icons.account_circle_rounded,
              title: AppI18n.tByLocaleCode(
                localeCode,
                'online.quick.profile.title',
              ),
              subtitle: AppI18n.tByLocaleCode(
                localeCode,
                'online.quick.profile.subtitle',
              ),
              onTap: onFetchProfile,
            ),
          ),
        ],
      ),
    );
  }
}

class SearchEntryCard extends StatelessWidget {
  const SearchEntryCard({required this.onOpenSearchPage, super.key});

  final VoidCallback onOpenSearchPage;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    return OnlineSectionCard(
      title: AppI18n.tByLocaleCode(localeCode, 'online.search_entry.title'),
      caption: AppI18n.tByLocaleCode(localeCode, 'online.search_entry.caption'),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              AppI18n.tByLocaleCode(localeCode, 'online.search_entry.desc'),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onOpenSearchPage,
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(
              AppI18n.tByLocaleCode(localeCode, 'online.search_entry.open'),
            ),
          ),
        ],
      ),
    );
  }
}

class PlaylistCard extends StatelessWidget {
  const PlaylistCard({
    required this.playlistNameController,
    required this.playlistFavoriteIdController,
    required this.onCreate,
    required this.onFavorite,
    required this.onUnfavorite,
    super.key,
  });

  final TextEditingController playlistNameController;
  final TextEditingController playlistFavoriteIdController;
  final VoidCallback onCreate;
  final VoidCallback onFavorite;
  final VoidCallback onUnfavorite;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    return OnlineSectionCard(
      title: AppI18n.tByLocaleCode(localeCode, 'online.playlist.title'),
      caption: AppI18n.tByLocaleCode(localeCode, 'online.playlist.caption'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: playlistNameController,
            decoration: InputDecoration(
              labelText: AppI18n.tByLocaleCode(
                localeCode,
                'online.playlist.name',
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: onCreate,
            child: Text(
              AppI18n.tByLocaleCode(localeCode, 'online.playlist.create'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: playlistFavoriteIdController,
            decoration: InputDecoration(
              labelText: AppI18n.tByLocaleCode(
                localeCode,
                'online.playlist.id',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton(
                onPressed: onFavorite,
                child: Text(
                  AppI18n.tByLocaleCode(localeCode, 'online.playlist.favorite'),
                ),
              ),
              OutlinedButton(
                onPressed: onUnfavorite,
                child: Text(
                  AppI18n.tByLocaleCode(
                    localeCode,
                    'online.playlist.unfavorite',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CommentCard extends StatelessWidget {
  const CommentCard({
    required this.commentResourceIdController,
    required this.resourceTypeController,
    required this.onLoadComments,
    super.key,
  });

  final TextEditingController commentResourceIdController;
  final TextEditingController resourceTypeController;
  final VoidCallback onLoadComments;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    return OnlineSectionCard(
      title: AppI18n.tByLocaleCode(localeCode, 'online.comment.title'),
      caption: AppI18n.tByLocaleCode(localeCode, 'online.comment.caption'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: commentResourceIdController,
            decoration: InputDecoration(
              labelText: AppI18n.tByLocaleCode(
                localeCode,
                'online.comment.resource_id',
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: resourceTypeController,
            decoration: InputDecoration(
              labelText: AppI18n.tByLocaleCode(
                localeCode,
                'online.comment.resource_type',
              ),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: onLoadComments,
            child: Text(
              AppI18n.tByLocaleCode(localeCode, 'online.comment.load'),
            ),
          ),
        ],
      ),
    );
  }
}

class ResultCard extends StatelessWidget {
  const ResultCard({required this.state, super.key});

  final OnlineFeatureState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localeCode = Localizations.localeOf(context).languageCode;
    return OnlineSectionCard(
      title: AppI18n.tByLocaleCode(localeCode, 'online.result.title'),
      caption: AppI18n.tByLocaleCode(localeCode, 'online.result.caption'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (state.loading) const LinearProgressIndicator(),
          if (state.loading) const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _OnlineMetaChip(
                label: state.profile != null
                    ? AppI18n.tByLocaleCode(
                        localeCode,
                        'online.result.profile_loaded',
                      )
                    : AppI18n.tByLocaleCode(
                        localeCode,
                        'online.result.profile_idle',
                      ),
              ),
              _OnlineMetaChip(
                label: AppI18n.formatByLocaleCode(
                  localeCode,
                  'online.result.search_count',
                  <String, String>{'count': '${state.searchResults.length}'},
                ),
              ),
              _OnlineMetaChip(
                label: AppI18n.formatByLocaleCode(
                  localeCode,
                  'online.result.comment_count',
                  <String, String>{'count': '${state.comments.length}'},
                ),
              ),
            ],
          ),
          if (state.message != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              AppI18n.formatByLocaleCode(
                localeCode,
                'online.result.message',
                <String, String>{'value': state.message!},
              ),
            ),
          ],
          if (state.error != null) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              AppI18n.formatByLocaleCode(
                localeCode,
                'online.result.error',
                <String, String>{'value': state.error!},
              ),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(height: 10),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnlineMetaChip extends StatelessWidget {
  const _OnlineMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}
