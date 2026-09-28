import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// One route animation owns both presentation and direct manipulation, so a
/// moving player can be grabbed without jumping to its logical destination.
class PlayerRoutePage extends Page<void> {
  const PlayerRoutePage({required this.child, super.key});

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) => _PlayerRoute(this);
}

class _PlayerRoute extends PageRouteBuilder<void> {
  _PlayerRoute(PlayerRoutePage page)
    : super(
        settings: page,
        pageBuilder: (context, animation, secondaryAnimation) => page.child,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            SlideTransition(
              position: animation.drive(
                Tween(begin: const Offset(0, 1), end: Offset.zero),
              ),
              child: child,
            ),
      );

  static final _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 400,
    ratio: 1,
  );
  int _revision = 0;
  bool _dismissInProgress = false;

  // animateWith stays forward so the closing player remains interactive.
  // Its completion must only occlude the previous route when fully expanded,
  // never when the spring has finished with the player below the viewport.
  @override
  bool get opaque => controller?.value == 1;

  @override
  Simulation createSimulation({required bool forward}) => SpringSimulation(
    _spring,
    controller!.value,
    forward ? 1 : 0,
    controller!.velocity,
  );

  @override
  void didChangeNext(Route<dynamic>? nextRoute) {
    if (nextRoute != null) {
      _revision++;
      controller!.value = 1;
    }
    super.didChangeNext(nextRoute);
  }

  bool get canDrag =>
      !_dismissInProgress &&
      isActive &&
      isCurrent &&
      popDisposition != RoutePopDisposition.doNotPop;

  void startDrag() {
    if (!canDrag) return;
    _revision++;
    controller!.stop();
  }

  void updateDrag(double delta, double height) {
    if (!canDrag || height <= 0) return;
    // Keep the route alive until the closing spring has settled and the page
    // has restored orientation/system UI. Never pop at a drag threshold.
    controller!.value = (controller!.value - delta / height).clamp(.0001, 1);
  }

  void endDrag(
    double velocity,
    double height,
    Future<void> Function() onDismiss,
  ) {
    if (!canDrag || height <= 0) return;
    final travel = 1 - controller!.value;
    final projectedTravel =
        travel + (velocity / 1000) * .998 / (1 - .998) / height;
    unawaited(
      _settle(
        dismiss: projectedTravel > .35,
        velocity: -velocity / height,
        onDismiss: onDismiss,
      ),
    );
  }

  void cancelDrag(Future<void> Function() onDismiss) {
    unawaited(_settle(dismiss: false, velocity: 0, onDismiss: onDismiss));
  }

  Future<void> close(Future<void> Function() onDismiss) => _settle(
    dismiss: true,
    velocity: controller!.velocity,
    onDismiss: onDismiss,
  );

  Future<void> _settle({
    required bool dismiss,
    required double velocity,
    required Future<void> Function() onDismiss,
  }) async {
    if (!canDrag) return;
    final revision = ++_revision;
    try {
      final simulation = SpringSimulation(
        _spring,
        controller!.value,
        dismiss ? .0001 : 1,
        velocity,
      );
      await controller!.animateWith(simulation).orCancel;
      if (revision == _revision && canDrag && dismiss) {
        _dismissInProgress = true;
        try {
          await onDismiss();
        } finally {
          _dismissInProgress = false;
        }
      }
    } on TickerCanceled {
      // A fresh gesture or route disposal supersedes the previous destination.
    }
  }
}

/// Only the player header participates; lyrics retain vertical scrolling and
/// the player's horizontal pager retains its own gesture recognizer.
class PlayerDismissRegion extends StatelessWidget {
  const PlayerDismissRegion({
    required this.onDismiss,
    required this.child,
    super.key,
  });

  final Future<void> Function() onDismiss;
  final Widget child;

  static Future<void> close(
    BuildContext context,
    Future<void> Function() onDismiss,
  ) {
    final route = ModalRoute.of(context);
    return route is _PlayerRoute ? route.close(onDismiss) : onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    if (route is! _PlayerRoute) return child;
    final height = MediaQuery.sizeOf(context).height;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragDown: (_) => route.startDrag(),
      onVerticalDragUpdate: (details) =>
          route.updateDrag(details.delta.dy, height),
      onVerticalDragEnd: (details) =>
          route.endDrag(details.velocity.pixelsPerSecond.dy, height, onDismiss),
      onVerticalDragCancel: () => route.cancelDrag(onDismiss),
      child: child,
    );
  }
}
