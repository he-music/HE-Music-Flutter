import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../shared/widgets/app_network_image.dart';
import '../../../../shared/widgets/glass_panel.dart';
import '../../domain/entities/my_profile.dart';

class MyAccountCard extends ConsumerWidget {
  const MyAccountCard({
    required this.profile,
    required this.tokenSet,
    super.key,
  });

  final MyProfile profile;
  final bool tokenSet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final theme = Theme.of(context);
    return GlassPanel(
      borderRadius: BorderRadius.circular(32),
      blurSigma: 0,
      tintColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppNetworkAvatar(
            imageUrl: profile.avatarUrl,
            radius: 34,
            backgroundColor: theme.colorScheme.primaryContainer,
            fallbackIcon: Icons.person,
            iconSize: 30,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'PROFILE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  profile.nickname.isEmpty
                      ? profile.username
                      : profile.nickname,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '@${profile.username}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _ProfileMetaChip(label: 'ID ${profile.id}'),
                    _ProfileMetaChip(
                      label: AppI18n.format(
                        config,
                        'my.account.status',
                        <String, String>{'value': '${profile.status}'},
                      ),
                    ),
                    _ProfileMetaChip(
                      label: tokenSet
                          ? AppI18n.t(config, 'my.account.token_set')
                          : AppI18n.t(config, 'my.account.token_unset'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMetaChip extends StatelessWidget {
  const _ProfileMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.66),
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
