import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../shared/widgets/app_button.dart';
import '../shared/utils/platform_utils.dart';
import 'app_navigation_service.dart';
import 'theme/app_ui_theme.dart';

class AppMessageService {
  AppMessageService._();

  static final messengerKey = GlobalKey<ScaffoldMessengerState>();
  static String? _lastMessage;
  static DateTime? _lastAt;
  static OverlayState? _lastOverlay;
  static _AppMessage? _current;
  static OverlayEntry? _entry;
  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _snackBar;

  static ScaffoldMessengerState? get _messenger {
    final configured = messengerKey.currentState;
    if (configured != null) return configured;
    final context = rootNavigatorKey.currentContext;
    return context == null ? null : ScaffoldMessenger.maybeOf(context);
  }

  static void showError(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) => _show(
    message,
    ToastificationType.error,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void showSuccess(String message) =>
      _show(message, ToastificationType.success);

  static void showInfo(String message) =>
      _show(message, ToastificationType.info);

  static void showWarning(String message) =>
      _show(message, ToastificationType.warning);

  static void _show(
    String message,
    ToastificationType type, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final normalized = message.trim();
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (normalized.isEmpty || overlay == null) return;
    final now = DateTime.now();
    if (identical(_lastOverlay, overlay) &&
        _lastMessage == normalized &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(milliseconds: 1200)) {
      return;
    }
    _lastOverlay = overlay;
    _lastMessage = normalized;
    _lastAt = now;
    final item = _AppMessage(normalized, type, actionLabel?.trim(), onAction);
    _present(item, overlay);
  }

  static void _present(_AppMessage message, OverlayState overlay) {
    _dismissMobile();
    toastification.dismissAll(delayForAnimation: false);
    _current = message;
    final context = overlay.context;
    if (shouldUseDesktopMenu(context)) {
      _showDesktop(message, overlay);
    } else if (AppUiTheme.usesCupertino(context)) {
      _entry = OverlayEntry(
        builder: (_) => _CupertinoMessage(message: message),
      );
      overlay.insert(_entry!);
    } else {
      final messenger = _messenger;
      if (messenger == null) return;
      // Scaffold owns bottom chrome geometry; AppPlayerScaffold compensates
      // the keyboard while keeping its persistent playback controls fixed.
      final controller = messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: message.duration,
          persist:
              message.hasAction && MediaQuery.accessibleNavigationOf(context),
          showCloseIcon: true,
          content: _MaterialMessage(message: message),
          action: message.hasAction
              ? SnackBarAction(
                  label: message.actionLabel!,
                  onPressed: () => _runAction(message),
                )
              : null,
        ),
      );
      _snackBar = controller;
      unawaited(
        controller.closed.then((_) {
          if (identical(_snackBar, controller)) {
            _snackBar = null;
            if (identical(_current, message)) _current = null;
          }
        }),
      );
    }
  }

  static void _dismissMobile() {
    final entry = _entry;
    _entry = null;
    entry?.remove();
    entry?.dispose();
    _snackBar = null;
    _messenger?.removeCurrentSnackBar();
  }

  static void _dismiss(_AppMessage message) {
    if (!identical(_current, message)) return;
    _current = null;
    _dismissMobile();
  }

  static void _runAction(_AppMessage message) {
    if (message.actionTaken || !identical(_current, message)) return;
    message.actionTaken = true;
    _dismiss(message);
    toastification.dismissAll(delayForAnimation: false);
    message.onAction?.call();
  }

  static void _refresh(_AppMessage message) {
    if (!identical(_current, message)) return;
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay != null) _present(message, overlay);
  }

  static void _showDesktop(_AppMessage message, OverlayState overlay) {
    final theme = Theme.of(overlay.context);
    final colorScheme = theme.colorScheme;
    final primaryColor = theme.brightness == Brightness.dark
        ? Color.lerp(message.type.color, Colors.white, 0.2)!
        : message.type.color;
    toastification.show(
      overlayState: overlay,
      type: message.type,
      style: ToastificationStyle.flat,
      alignment: Alignment.topRight,
      title: _DesktopMessage(message: message),
      description: message.hasAction
          ? Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton.text(
                onPressed: () => _runAction(message),
                child: Text(message.actionLabel!),
              ),
            )
          : null,
      autoCloseDuration:
          message.hasAction &&
              MediaQuery.accessibleNavigationOf(overlay.context)
          ? null
          : message.duration,
      primaryColor: primaryColor,
      backgroundColor: colorScheme.surfaceContainerHigh,
      foregroundColor: colorScheme.onSurface,
      borderSide: BorderSide(
        color: primaryColor.withValues(alpha: 0.5),
        width: 1.2,
      ),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: colorScheme.shadow.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.4 : 0.16,
          ),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }
}

class _DesktopMessage extends StatefulWidget {
  const _DesktopMessage({required this.message});
  final _AppMessage message;

  @override
  State<_DesktopMessage> createState() => _DesktopMessageState();
}

class _DesktopMessageState extends State<_DesktopMessage> {
  ColorScheme? _colors;
  bool? _accessibleNavigation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final colors = Theme.of(context).colorScheme;
    final accessible = MediaQuery.accessibleNavigationOf(context);
    final changed =
        (_colors != null && _colors != colors) ||
        (_accessibleNavigation != null &&
            _accessibleNavigation != accessible) ||
        !shouldUseDesktopMenu(
          rootNavigatorKey.currentState?.overlay?.context ?? context,
        );
    _colors = colors;
    _accessibleNavigation = accessible;
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AppMessageService._refresh(widget.message);
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      Semantics(liveRegion: true, child: Text(widget.message.text));
}

class _AppMessage {
  _AppMessage(this.text, this.type, this.actionLabel, this.onAction);

  final String text;
  final ToastificationType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  bool actionTaken = false;
  bool get hasAction => (actionLabel?.isNotEmpty ?? false) && onAction != null;
  Duration get duration => Duration(seconds: hasAction ? 5 : 3);
}

class _MaterialMessage extends StatefulWidget {
  const _MaterialMessage({required this.message});
  final _AppMessage message;

  @override
  State<_MaterialMessage> createState() => _MaterialMessageState();
}

class _MaterialMessageState extends State<_MaterialMessage> {
  bool? _accessibleNavigation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final accessible = MediaQuery.accessibleNavigationOf(context);
    final needsRefresh =
        AppUiTheme.usesCupertino(context) ||
        shouldUseDesktopMenu(context) ||
        (_accessibleNavigation != null && _accessibleNavigation != accessible);
    _accessibleNavigation = accessible;
    if (needsRefresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AppMessageService._refresh(widget.message);
      });
    }
  }

  @override
  Widget build(BuildContext context) =>
      Semantics(liveRegion: true, child: Text(widget.message.text));
}

class _CupertinoMessage extends StatefulWidget {
  const _CupertinoMessage({required this.message});
  final _AppMessage message;

  @override
  State<_CupertinoMessage> createState() => _CupertinoMessageState();
}

class _CupertinoMessageState extends State<_CupertinoMessage> {
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timer?.cancel();
    if (!AppUiTheme.usesCupertino(context) || shouldUseDesktopMenu(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AppMessageService._refresh(widget.message);
      });
      return;
    }
    if (!widget.message.hasAction ||
        !MediaQuery.accessibleNavigationOf(context)) {
      _timer = Timer(
        widget.message.duration,
        () => AppMessageService._dismiss(widget.message),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    top: 0,
    left: 12,
    right: 12,
    child: SafeArea(
      bottom: false,
      child: Semantics(
        liveRegion: true,
        container: true,
        child: CupertinoTheme(
          data: CupertinoThemeData(
            brightness: Theme.of(context).brightness,
            primaryColor: Theme.of(context).colorScheme.primary,
          ),
          child: DecoratedBox(
            key: const ValueKey('cupertino-app-message'),
            decoration: BoxDecoration(
              color: CupertinoColors.secondarySystemGroupedBackground
                  .resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            widget.message.text,
                            style: TextStyle(
                              fontSize: 15,
                              color: CupertinoColors.label.resolveFrom(context),
                            ),
                          ),
                        ),
                        if (widget.message.hasAction)
                          CupertinoButton(
                            padding: const EdgeInsets.only(bottom: 8),
                            alignment: AlignmentDirectional.centerStart,
                            onPressed: () =>
                                AppMessageService._runAction(widget.message),
                            child: Text(widget.message.actionLabel!),
                          ),
                      ],
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.all(12),
                    onPressed: () => AppMessageService._dismiss(widget.message),
                    child: Semantics(
                      label: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      child: const Icon(CupertinoIcons.xmark, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
