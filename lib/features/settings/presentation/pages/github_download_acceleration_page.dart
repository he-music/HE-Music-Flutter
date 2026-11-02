import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_adaptive_controls.dart';
import 'package:flutter/cupertino.dart';
import '../../../../app/theme/app_ui_theme.dart';
import '../../../../shared/widgets/app_list_tile.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_activity_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../update/domain/entities/github_download_proxy_config.dart';
import '../../../update/presentation/providers/update_providers.dart';

class GitHubDownloadAccelerationPage extends ConsumerStatefulWidget {
  const GitHubDownloadAccelerationPage({this.embedded = false, super.key});

  final bool embedded;

  @override
  ConsumerState<GitHubDownloadAccelerationPage> createState() =>
      _GitHubDownloadAccelerationPageState();
}

class _GitHubDownloadAccelerationPageState
    extends ConsumerState<GitHubDownloadAccelerationPage> {
  bool _refreshing = false;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final proxyConfigAsync = ref.watch(gitHubDownloadProxyControllerProvider);
    final content = ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        AppListSection(
          children: <Widget>[
            AppSwitchListTile(
              key: const ValueKey<String>(
                'github-download-proxy-auto-update-switch',
              ),
              value: config.githubDownloadProxyAutoUpdateEnabled,
              onChanged: ref
                  .read(appConfigProvider.notifier)
                  .setGitHubDownloadProxyAutoUpdateEnabled,
              secondary: const Icon(Icons.sync_rounded),
              title: Text(
                AppI18n.t(
                  config,
                  'settings.github_download_acceleration.auto_update',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                AppI18n.t(
                  config,
                  'settings.github_download_acceleration.services',
                ),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            AppIconButton(
              key: const ValueKey<String>('refresh-github-proxy-list'),
              tooltip: AppI18n.t(
                config,
                'settings.github_download_acceleration.refresh',
              ),
              onPressed: _refreshing || !proxyConfigAsync.hasValue
                  ? null
                  : _refresh,
              icon: _refreshing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: AppActivityIndicator(size: 20, strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        proxyConfigAsync.when(
          data: (snapshot) => _buildProxyList(config, snapshot),
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: AppActivityIndicator(size: 36, strokeWidth: 4),
            ),
          ),
          error: (error, stackTrace) => _buildLoadError(config),
        ),
      ],
    );
    if (widget.embedded) {
      return content;
    }
    return Scaffold(
      appBar: AppNavigationBar(
        leading: const AppBackButton(),
        title: Text(
          AppI18n.t(config, 'settings.github_download_acceleration.title'),
        ),
      ),
      body: content,
    );
  }

  Widget _buildProxyList(
    AppConfigState appConfig,
    GitHubDownloadProxyConfigSnapshot snapshot,
  ) {
    final proxies = snapshot.config.enabledProxies;
    final selectedProxy = snapshot.config.resolveProxy(
      appConfig.githubDownloadProxyId,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (snapshot.refreshedAt != null) ...<Widget>[
          Text(
            AppI18n.format(
              appConfig,
              'settings.github_download_acceleration.refreshed_at',
              <String, String>{'time': _formatDateTime(snapshot.refreshedAt!)},
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
        ],
        if (proxies.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                AppI18n.t(
                  appConfig,
                  'settings.github_download_acceleration.empty',
                ),
              ),
            ),
          )
        else
          RadioGroup<String>(
            groupValue: selectedProxy?.id,
            onChanged: (value) {
              ref
                  .read(appConfigProvider.notifier)
                  .setGitHubDownloadProxyId(value);
            },
            child: AppListSection(
              children: <Widget>[
                for (var index = 0; index < proxies.length; index++) ...[
                  if (AppUiTheme.usesCupertino(context))
                    Semantics(
                      selected: selectedProxy?.id == proxies[index].id,
                      child: AppListTile(
                        key: ValueKey<String>(
                          'github-download-proxy-${proxies[index].id}',
                        ),
                        title: Text(proxies[index].name),
                        subtitle: Text(
                          proxies[index].urlPrefix,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: selectedProxy?.id == proxies[index].id
                            ? Icon(
                                CupertinoIcons.check_mark,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                        onTap: () => ref
                            .read(appConfigProvider.notifier)
                            .setGitHubDownloadProxyId(proxies[index].id),
                      ),
                    )
                  else
                    RadioListTile<String>(
                      key: ValueKey<String>(
                        'github-download-proxy-${proxies[index].id}',
                      ),
                      value: proxies[index].id,
                      title: Text(proxies[index].name),
                      subtitle: Text(
                        proxies[index].urlPrefix,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildLoadError(AppConfigState config) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: <Widget>[
          Text(
            AppI18n.t(
              config,
              'settings.github_download_acceleration.load_failed',
            ),
          ),
          const SizedBox(height: 12),
          AppButton.outlined(
            onPressed: () =>
                ref.invalidate(gitHubDownloadProxyControllerProvider),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh_rounded),
                const SizedBox(width: 8),
                Flexible(child: Text(AppI18n.t(config, 'common.retry'))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
    });
    try {
      final snapshot = await ref
          .read(gitHubDownloadProxyControllerProvider.notifier)
          .refresh();
      if (!mounted) {
        return;
      }
      final config = ref.read(appConfigProvider);
      final selectedId = config.githubDownloadProxyId;
      if (selectedId != null &&
          snapshot.config.resolveProxy(selectedId)?.id != selectedId) {
        ref.read(appConfigProvider.notifier).setGitHubDownloadProxyId(null);
      }
      AppMessageService.showSuccess(
        AppI18n.t(
          config,
          'settings.github_download_acceleration.refresh_success',
        ),
      );
    } catch (_) {
      if (mounted) {
        final config = ref.read(appConfigProvider);
        AppMessageService.showError(
          AppI18n.t(
            config,
            'settings.github_download_acceleration.refresh_failed',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}-$month-$day $hour:$minute';
}
