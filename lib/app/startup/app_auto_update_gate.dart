import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_message_service.dart';
import '../app_navigation_service.dart';
import '../config/app_config_controller.dart';
import '../config/app_config_state.dart';
import '../i18n/app_i18n.dart';
import '../../features/update/domain/entities/update_release.dart';
import '../../features/update/domain/entities/update_state.dart';
import '../../features/update/presentation/providers/update_providers.dart';
import '../../features/update/presentation/widgets/update_available_release_sheet.dart';

class AppAutoUpdateGate extends ConsumerStatefulWidget {
  AppAutoUpdateGate({
    required this.child,
    super.key,
    GlobalKey<NavigatorState>? navigatorKey,
  }) : navigatorKey = navigatorKey ?? rootNavigatorKey;

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  ConsumerState<AppAutoUpdateGate> createState() => _AppAutoUpdateGateState();
}

class _AppAutoUpdateGateState extends ConsumerState<AppAutoUpdateGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    // 等首帧完成，确保 Router 的 Navigator 已经挂载。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkOnStartup();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  Future<void> _checkOnStartup() async {
    if (_checked || !mounted) {
      return;
    }
    _checked = true;
    final config = await ref.read(appConfigDataSourceProvider).load();
    if (!mounted) {
      return;
    }
    unawaited(_autoRefreshDownloadProxyConfig(config));
    if (!config.autoCheckUpdates) {
      return;
    }
    await ref.read(updateControllerProvider.notifier).checkForUpdates();
    if (!mounted) {
      return;
    }
    final updateState = ref.read(updateControllerProvider);
    if (updateState.status != UpdateStatus.available ||
        updateState.release == null) {
      ref.read(updateControllerProvider.notifier).resetStatus();
      return;
    }
    await _showAvailableReleaseSheet(config, updateState);
  }

  Future<void> _autoRefreshDownloadProxyConfig(AppConfigState config) async {
    try {
      await ref
          .read(gitHubDownloadProxyAutoRefreshServiceProvider)
          .refreshIfNeeded(config);
    } catch (_) {
      // 后台刷新失败时继续使用现有有效配置，不打断启动或更新检查。
    }
  }

  Future<void> _showAvailableReleaseSheet(
    AppConfigState config,
    UpdateState updateState,
  ) async {
    final release = updateState.release;
    if (release == null) {
      return;
    }
    if (!mounted) {
      ref.read(updateControllerProvider.notifier).resetStatus();
      return;
    }
    final navigatorReady = await _waitForNavigatorReady();
    if (!mounted || !navigatorReady) {
      ref.read(updateControllerProvider.notifier).resetStatus();
      return;
    }
    final downloadTarget = await ref
        .read(updateDownloadTargetServiceProvider)
        .resolve(release, config);
    if (!mounted) {
      return;
    }
    await _showAvailableReleaseSheetNow(
      config,
      release,
      downloadTarget?.downloadUrl,
    );
    if (!mounted) {
      return;
    }
    ref.read(updateControllerProvider.notifier).resetStatus();
  }

  Future<void> _showAvailableReleaseSheetNow(
    AppConfigState config,
    UpdateRelease release,
    String? downloadUrl,
  ) async {
    final navigatorContext = widget.navigatorKey.currentContext;
    if (navigatorContext == null) {
      ref.read(updateControllerProvider.notifier).resetStatus();
      return;
    }
    await showUpdateAvailableReleaseSheet(
      context: navigatorContext,
      config: config,
      release: release,
      downloadUrl: downloadUrl,
      onOpenUrl: (rawUrl) => _openReleaseUrl(rawUrl, config),
    );
  }

  Future<bool> _waitForNavigatorReady() async {
    for (var attempt = 0; attempt < 10; attempt += 1) {
      if (widget.navigatorKey.currentContext != null) {
        return true;
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return false;
      }
    }
    return widget.navigatorKey.currentContext != null;
  }

  Future<void> _openReleaseUrl(String rawUrl, AppConfigState config) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) {
      AppMessageService.showError(
        AppI18n.t(config, 'settings.about.open_failed'),
      );
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      AppMessageService.showError(
        AppI18n.t(config, 'settings.about.open_failed'),
      );
    }
  }
}
