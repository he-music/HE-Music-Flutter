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
    Future<void>.microtask(_checkOnStartup);
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
    if (!mounted || !config.autoCheckUpdates) {
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
    await _showAvailableReleaseSheetNow(config, release);
    if (!mounted) {
      return;
    }
    ref.read(updateControllerProvider.notifier).resetStatus();
  }

  Future<void> _showAvailableReleaseSheetNow(
    AppConfigState config,
    UpdateRelease release,
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
