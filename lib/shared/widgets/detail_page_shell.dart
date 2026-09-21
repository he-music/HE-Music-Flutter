import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../app/theme/glass/app_glass_scope.dart';

import '../../app/config/app_config_controller.dart';
import '../../app/i18n/app_i18n.dart';
import 'app_back_button.dart';
import 'detail_loading_skeleton.dart';
import 'song_actions_sheet.dart';

class DetailPageShell extends StatelessWidget {
  const DetailPageShell({
    required this.child,
    this.bottomBar,
    this.onBackRequested,
    this.resizeToAvoidBottomInset = true,
    super.key,
  });

  final Widget child;
  final Widget? bottomBar;
  final VoidCallback? onBackRequested;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    // MiniPlayerBar 由 AppShell 统一提供，这里不再重复添加。
    return ValueListenableBuilder<bool>(
      valueListenable: SongActionsSheetController.hasOpenSheet,
      builder: (context, hasOpenSongActionsSheet, _) {
        return PopScope(
          canPop: !hasOpenSongActionsSheet && onBackRequested == null,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              return;
            }
            if (SongActionsSheetController.dismissOpenSheet()) {
              return;
            }
            if (onBackRequested != null) {
              onBackRequested!();
              return;
            }
            context.appPopOrGo();
          },
          child: _buildScaffold(context),
        );
      },
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final clearance = AppGlassScope.isEnabled(context) && bottomBar != null
        ? MediaQuery.paddingOf(context).bottom
        : 0.0;
    final body = Padding(
      padding: EdgeInsets.only(bottom: clearance),
      child: MediaQuery.removePadding(
        context: context,
        removeBottom: clearance > 0,
        child: Column(
          children: <Widget>[
            Expanded(child: child),
            ...<Widget?>[bottomBar].nonNulls,
          ],
        ),
      ),
    );
    if (AppGlassScope.isEnabled(context)) {
      // The pinned sliver owns the collapsing hero and toolbar geometry.
      // Keep its safe areas intact; the outer shell owns the mini-player.
      return Material(
        type: MaterialType.transparency,
        child: GlassScaffold(
          edgeToEdge: true,
          extendBody: false,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: body,
        ),
      );
    }
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: body,
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
