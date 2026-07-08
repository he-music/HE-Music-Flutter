import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/config/app_config_controller.dart';
import '../../app/i18n/app_i18n.dart';
import 'app_back_button.dart';
import 'detail_loading_skeleton.dart';
import 'song_actions_sheet.dart';

class DetailPageShell extends StatelessWidget {
  const DetailPageShell({
    required this.child,
    this.bottomBar,
    this.resizeToAvoidBottomInset = true,
    super.key,
  });

  final Widget child;
  final Widget? bottomBar;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    // MiniPlayerBar 由 AppShell 统一提供，这里不再重复添加。
    return ValueListenableBuilder<bool>(
      valueListenable: SongActionsSheetController.hasOpenSheet,
      builder: (context, hasOpenSongActionsSheet, _) {
        return PopScope(
          canPop: !hasOpenSongActionsSheet,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              return;
            }
            if (SongActionsSheetController.dismissOpenSheet()) {
              return;
            }
            context.appPopOrGo();
          },
          child: Scaffold(
            resizeToAvoidBottomInset: resizeToAvoidBottomInset,
            body: Column(
              children: <Widget>[
                Expanded(child: child),
                ...<Widget?>[bottomBar].nonNulls,
              ],
            ),
          ),
        );
      },
    );
  }
}

class DetailLoadingBody extends StatelessWidget {
  const DetailLoadingBody({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return GenericDetailLoadingBody(title: title);
  }
}

class DetailErrorBody extends ConsumerWidget {
  const DetailErrorBody({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(AppI18n.t(config, 'common.retry')),
          ),
        ],
      ),
    );
  }
}
