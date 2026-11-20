import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_environment.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/app_activity_indicator.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_content_width.dart';
import '../../../../shared/widgets/app_list_tile.dart';
import '../../../../shared/widgets/app_panel.dart';
import '../../../update/domain/entities/update_release.dart';
import '../../../update/domain/entities/update_state.dart';
import '../../../update/presentation/providers/update_providers.dart';
import '../../../update/presentation/widgets/update_available_release_sheet.dart';

class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key, this.updateSettings = const []});

  final List<Widget> updateSettings;

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  @override
  Widget build(BuildContext context) {
    ref.listen<UpdateState>(updateControllerProvider, (previous, next) {
      if (previous?.status == next.status &&
          previous?.errorMessage == next.errorMessage &&
          previous?.release?.htmlUrl == next.release?.htmlUrl) {
        return;
      }
      switch (next.status) {
        case UpdateStatus.available:
          final release = next.release;
          if (release == null) {
            return;
          }
          Future<void>.microtask(() async {
            if (!mounted) {
              return;
            }
            await _showAvailableReleaseSheet(release);
            if (!mounted) {
              return;
            }
            ref.read(updateControllerProvider.notifier).resetStatus();
          });
          break;
        case UpdateStatus.latest:
          Future<void>.microtask(() {
            if (!mounted) {
              return;
            }
            AppMessageService.showInfo(
              AppI18n.t(ref.read(appConfigProvider), 'settings.about.latest'),
            );
            ref.read(updateControllerProvider.notifier).resetStatus();
          });
          break;
        case UpdateStatus.failure:
          Future<void>.microtask(() {
            if (!mounted) {
              return;
            }
            final config = ref.read(appConfigProvider);
            final message = _failureMessage(config, next.errorMessage);
            AppMessageService.showError(message);
            ref.read(updateControllerProvider.notifier).resetStatus();
          });
          break;
        case UpdateStatus.idle:
        case UpdateStatus.checking:
          break;
      }
    });
    final localeCode = ref.watch(
      appConfigProvider.select((config) => config.localeCode),
    );
    final appInfo = ref.watch(currentAppInfoProvider).asData?.value;
    final appName = appInfo?.appName.trim() ?? '';
    final releaseConfigured = AppEnvironment.hasGitHubReleaseConfig;
    final repository =
        '${AppEnvironment.githubOwner}/${AppEnvironment.githubRepo}';

    return AppContentWidth(
      maxWidth: 600,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _AboutHero(
            appName: appName.isEmpty ? 'HE Music' : appName,
            versionLabel: appInfo?.versionLabel ?? '--',
            versionTitle: AppI18n.tByLocaleCode(
              localeCode,
              'settings.about.current_version',
            ),
          ),
          for (final group in widget.updateSettings) ...[
            const SizedBox(height: 20),
            group,
          ],
          const SizedBox(height: 20),
          AppListSection(
            header: Text(
              AppI18n.tByLocaleCode(localeCode, 'settings.about.version_links'),
            ),
            children: [
              AppListTile(
                leading: const Icon(Icons.history_rounded),
                title: Text(
                  AppI18n.tByLocaleCode(localeCode, 'update.history.title'),
                ),
                showChevron: true,
                enabled: releaseConfigured,
                onTap: releaseConfigured
                    ? () => context.push(AppRoutes.releaseHistory)
                    : null,
              ),
              AppListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: Text(
                  AppI18n.tByLocaleCode(
                    localeCode,
                    'settings.about.github_release',
                  ),
                ),
                subtitle: Text(
                  releaseConfigured
                      ? repository
                      : AppI18n.tByLocaleCode(
                          localeCode,
                          'settings.about.unconfigured',
                        ),
                ),
                showChevron: true,
                enabled: releaseConfigured,
                onTap: releaseConfigured
                    ? () => _openUrl('https://github.com/$repository/releases')
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _failureMessage(AppConfigState config, String? raw) {
    final normalized = raw?.trim() ?? '';
    if (normalized.isEmpty) {
      return AppI18n.t(config, 'settings.about.check_failed');
    }
    if (normalized.contains('未配置 GitHub Release 仓库')) {
      return AppI18n.t(config, 'settings.about.unconfigured');
    }
    return normalized;
  }

  Future<void> _openUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    final config = ref.read(appConfigProvider);
    if (uri == null) {
      AppMessageService.showError(
        AppI18n.t(config, 'settings.about.open_failed'),
      );
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      AppMessageService.showError(
        AppI18n.t(config, 'settings.about.open_failed'),
      );
    }
  }

  Future<void> _showAvailableReleaseSheet(UpdateRelease release) async {
    final config = ref.read(appConfigProvider);
    final downloadTarget = await ref
        .read(updateDownloadTargetServiceProvider)
        .resolve(release, config);
    if (!mounted) {
      return;
    }
    return showUpdateAvailableReleaseSheet(
      context: context,
      config: config,
      release: release,
      downloadTarget: downloadTarget,
      onOpenUrl: _openUrl,
    );
  }
}

class _CheckUpdateButton extends ConsumerWidget {
  const _CheckUpdateButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeCode = ref.watch(
      appConfigProvider.select((config) => config.localeCode),
    );
    final isChecking = ref.watch(
      updateControllerProvider.select(
        (state) => state.status == UpdateStatus.checking,
      ),
    );
    return AppButton.filledIcon(
      onPressed: isChecking
          ? null
          : () => ref.read(updateControllerProvider.notifier).checkForUpdates(),
      icon: isChecking
          ? const SizedBox(
              width: 18,
              height: 18,
              child: AppActivityIndicator(size: 18, strokeWidth: 2),
            )
          : const Icon(Icons.system_update_rounded),
      label: Text(
        AppI18n.tByLocaleCode(
          localeCode,
          isChecking
              ? 'settings.about.checking'
              : 'settings.about.check_update',
        ),
      ),
    );
  }
}

class _AboutHero extends StatelessWidget {
  const _AboutHero({
    required this.appName,
    required this.versionLabel,
    required this.versionTitle,
  });

  final String appName;
  final String versionLabel;
  final String versionTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppPanel(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Column(
          children: <Widget>[
            Image.asset(
              'assets/icons/favicon-512x512.png',
              key: const ValueKey<String>('about-logo'),
              width: 88,
              height: 88,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 18),
            Text(
              appName,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              versionTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              versionLabel,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            const _CheckUpdateButton(),
          ],
        ),
      ),
    );
  }
}
