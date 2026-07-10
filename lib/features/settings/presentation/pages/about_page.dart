import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_environment.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../update/domain/entities/update_release.dart';
import '../../../update/domain/entities/update_state.dart';
import '../../../update/presentation/providers/update_providers.dart';
import '../../../update/presentation/widgets/update_available_release_sheet.dart';

class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key, this.embedded = false});

  final bool embedded;

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
    final config = ref.watch(appConfigProvider);
    final content = AboutContent(
      releaseDescriptionBuilder: _gitHubReleaseDescription,
      releasePageUrl: _releasePageUrl,
      onOpenUrl: _openUrl,
    );
    if (widget.embedded) {
      return content;
    }
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(AppI18n.t(config, 'settings.about.title')),
      ),
      body: content,
    );
  }

  String get _releasePageUrl {
    if (!AppEnvironment.hasGitHubReleaseConfig) {
      return '';
    }
    return 'https://github.com/${AppEnvironment.githubOwner}/${AppEnvironment.githubRepo}/releases';
  }

  String _gitHubReleaseDescription(AppConfigState config) {
    if (!AppEnvironment.hasGitHubReleaseConfig) {
      return AppI18n.t(config, 'settings.about.unconfigured');
    }
    return '${AppEnvironment.githubOwner}/${AppEnvironment.githubRepo}';
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

  Future<void> _showAvailableReleaseSheet(UpdateRelease release) {
    return showUpdateAvailableReleaseSheet(
      context: context,
      config: ref.read(appConfigProvider),
      release: release,
      onOpenUrl: _openUrl,
    );
  }
}

class AboutContent extends ConsumerWidget {
  const AboutContent({
    required this.releaseDescriptionBuilder,
    required this.releasePageUrl,
    required this.onOpenUrl,
    super.key,
  });

  final String Function(AppConfigState config) releaseDescriptionBuilder;
  final String releasePageUrl;
  final Future<void> Function(String rawUrl) onOpenUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final appInfoAsync = ref.watch(currentAppInfoProvider);
    final updateState = ref.watch(updateControllerProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: <Widget>[
        _AboutHero(
          appName: appInfoAsync.maybeWhen(
            data: (info) =>
                info.appName.trim().isEmpty ? 'HE Music' : info.appName,
            orElse: () => 'HE Music',
          ),
          versionLabel: appInfoAsync.maybeWhen(
            data: (info) => info.versionLabel,
            orElse: () => '--',
          ),
          versionTitle: AppI18n.t(config, 'settings.about.current_version'),
        ),
        const SizedBox(height: 18),
        Card(
          child: Column(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: Text(AppI18n.t(config, 'settings.about.github_release')),
                subtitle: Text(releaseDescriptionBuilder(config)),
                trailing: const Icon(Icons.chevron_right_rounded),
                enabled: AppEnvironment.hasGitHubReleaseConfig,
                onTap: AppEnvironment.hasGitHubReleaseConfig
                    ? () => onOpenUrl(releasePageUrl)
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: updateState.status == UpdateStatus.checking
              ? null
              : () => ref
                    .read(updateControllerProvider.notifier)
                    .checkForUpdates(),
          icon: updateState.status == UpdateStatus.checking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.system_update_rounded),
          label: Text(
            updateState.status == UpdateStatus.checking
                ? AppI18n.t(config, 'settings.about.checking')
                : AppI18n.t(config, 'settings.about.check_update'),
          ),
        ),
      ],
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
    return Card(
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
          ],
        ),
      ),
    );
  }
}
