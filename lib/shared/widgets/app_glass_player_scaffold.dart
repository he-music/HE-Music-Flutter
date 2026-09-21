import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../features/player/presentation/providers/player_providers.dart';

typedef GlassPlayerNavigationBuilder =
    Widget Function(
      Widget? accessory,
      GlassTabBarMinimizeController? controller,
      ValueChanged<bool> expandFromUser,
    );

/// Shared floating chrome. Tab pages use the native accessory transition;
/// detail routes retain their independent mini-player.
class AppGlassPlayerScaffold extends ConsumerStatefulWidget {
  const AppGlassPlayerScaffold({
    required this.body,
    required this.miniPlayer,
    this.navigation,
    this.navigationBuilder,
    super.key,
  }) : assert(navigation == null || navigationBuilder == null);

  final Widget body;
  final Widget miniPlayer;
  final Widget? navigation;
  final GlassPlayerNavigationBuilder? navigationBuilder;

  @override
  ConsumerState<AppGlassPlayerScaffold> createState() =>
      _AppGlassPlayerScaffoldState();
}

class _AppGlassPlayerScaffoldState
    extends ConsumerState<AppGlassPlayerScaffold> {
  // Enable imperative minimize/expand; the offset policy below owns when
  // these run, rather than the package's direction-based scroll handler.
  final _minimize = GlassTabBarMinimizeController(
    behavior: GlassBarMinimizeBehavior.onScrollDown,
  );

  // Offset-based hysteresis avoids animations on every direction reversal.
  static const _collapseOffset = 50.0;
  static const _expandOffset = 20.0;
  ScrollPosition? _activePosition;
  bool _holdExpanded = false;
  int _scrollEpoch = 0;
  bool _updateQueued = false;
  bool? _pendingMinimized;

  void _expandFromUser(bool returnToTop) {
    _holdExpanded = true;
    final epoch = ++_scrollEpoch;
    _updateQueued = false;
    _pendingMinimized = null;
    _minimize.expand();
    final position = _activePosition;
    if (!returnToTop) {
      // Switching tabs must not scroll the previous page back to the top.
      _activePosition = null;
    } else if (position != null &&
        position.hasContentDimensions &&
        (position.context.notificationContext?.mounted ?? false)) {
      unawaited(
        position
            .animateTo(
              position.minScrollExtent,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutQuart,
            )
            .whenComplete(() {
              if (mounted && epoch == _scrollEpoch) _holdExpanded = false;
            }),
      );
    }
  }

  @override
  void dispose() {
    _minimize.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Playback ticks and track identity do not rebuild the page chrome.
    final hasTrack = ref.watch(
      playerControllerProvider.select((state) => state.displayTrack != null),
    );
    final media = MediaQuery.of(context);
    final integrated = widget.navigationBuilder != null;
    final canMinimize =
        hasTrack &&
        integrated &&
        media.size.width >= 340 &&
        !media.highContrast &&
        !media.disableAnimations;
    final body = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Home's vertical lists live inside a horizontal PageView, so their
        // notifications reach this shell at depth > 0. Filter by axis instead.
        if (canMinimize && notification.metrics.axis == Axis.vertical) {
          final sourceContext = notification.context;
          // Inactive shell branches can finish a fling while offstage.
          if (sourceContext != null &&
              !TickerMode.getValuesNotifier(sourceContext).value.enabled) {
            return false;
          }
          final userInput =
              (notification is ScrollStartNotification &&
                  notification.dragDetails != null) ||
              (notification is ScrollUpdateNotification &&
                  notification.dragDetails != null) ||
              (notification is UserScrollNotification &&
                  notification.direction != ScrollDirection.idle);
          if (sourceContext != null) {
            _activePosition = Scrollable.maybeOf(sourceContext)?.position;
          }
          if (userInput && _holdExpanded) {
            _holdExpanded = false;
            _scrollEpoch++;
          }
          if (_holdExpanded ||
              (notification is! ScrollUpdateNotification &&
                  notification is! ScrollEndNotification)) {
            return false;
          }
          final metrics = notification.metrics;
          final distance = metrics.pixels - metrics.minScrollExtent;
          final wasMinimized = _pendingMinimized ?? _minimize.minimized;
          // Collapsing removes 60px of list clearance. Short content must
          // remain scrollable past the threshold after that size change.
          final target =
              metrics.maxScrollExtent - metrics.minScrollExtent >
                  _collapseOffset + (_minimize.minimized ? 0 : 60) &&
              distance > (wasMinimized ? _expandOffset : _collapseOffset);
          _pendingMinimized = target;
          if (_updateQueued) return false;
          if (target == _minimize.minimized) {
            _pendingMinimized = null;
            return false;
          }
          _updateQueued = true;
          final epoch = _scrollEpoch;
          // Coalesce threshold crossings; ordinary scrolling schedules no
          // rebuild. Stale callbacks cannot reverse an explicit navigation tap.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || epoch != _scrollEpoch) return;
            _updateQueued = false;
            final target = _pendingMinimized;
            _pendingMinimized = null;
            if (_holdExpanded ||
                target == null ||
                target == _minimize.minimized) {
              return;
            }
            if (target) {
              _minimize.minimize();
            } else {
              _minimize.expand();
            }
          });
        }
        return false;
      },
      child: widget.body,
    );
    return ListenableBuilder(
      listenable: _minimize,
      builder: (context, _) {
        final bottomInset = media.viewPadding.bottom;
        final hasNavigation = integrated || widget.navigation != null;
        final minimized = canMinimize && _minimize.minimized;
        final chromeHeight = minimized
            ? 64.0
            : (hasTrack ? 60.0 : 0.0) + (hasNavigation ? 64.0 : 0.0);
        final hasChrome = chromeHeight > 0;
        final clearance = hasChrome ? chromeHeight + bottomInset : 0.0;
        return MediaQuery(
          data: media.copyWith(padding: media.padding.copyWith(bottom: 0)),
          child: Material(
            type: MaterialType.transparency,
            child: GlassScaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              edgeToEdge: true,
              resizeToAvoidBottomInset: false,
              extendBody: hasChrome,
              bottomEdgeFade: hasChrome,
              bottomBarHeight: clearance,
              body: MediaQuery(
                data: media.copyWith(
                  padding: media.padding.copyWith(
                    bottom: hasChrome ? clearance : media.padding.bottom,
                  ),
                ),
                child: body,
              ),
              bottomBar: !hasChrome
                  ? null
                  : Padding(
                      padding: EdgeInsets.only(bottom: bottomInset),
                      child: integrated
                          ? widget.navigationBuilder!(
                              hasTrack ? widget.miniPlayer : null,
                              canMinimize ? _minimize : null,
                              _expandFromUser,
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (hasTrack) widget.miniPlayer,
                                ?widget.navigation,
                              ],
                            ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
