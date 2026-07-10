import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import 'app_navigation_service.dart';

class AppMessageService {
  AppMessageService._();

  static const double _compactLayoutBreakpoint = 600;
  static String? _lastMessage;
  static DateTime? _lastAt;

  static void showError(String message) =>
      _show(message, ToastificationType.error);

  static void showSuccess(String message) =>
      _show(message, ToastificationType.success);

  static void showInfo(String message) =>
      _show(message, ToastificationType.info);

  static void showWarning(String message) =>
      _show(message, ToastificationType.warning);

  static void _show(String message, ToastificationType type) {
    final normalized = message.trim();
    if (normalized.isEmpty) {
      return;
    }
    final now = DateTime.now();
    if (_lastMessage == normalized &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(milliseconds: 1200)) {
      return;
    }
    _lastMessage = normalized;
    _lastAt = now;
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      return;
    }
    final compact =
        MediaQuery.sizeOf(overlay.context).width < _compactLayoutBreakpoint;
    final theme = Theme.of(overlay.context);
    final colorScheme = theme.colorScheme;
    final primaryColor = theme.brightness == Brightness.dark
        ? Color.lerp(type.color, Colors.white, 0.2)!
        : type.color;
    toastification.dismissAll(delayForAnimation: false);
    toastification.show(
      overlayState: overlay,
      type: type,
      style: ToastificationStyle.flat,
      alignment: compact ? Alignment.topCenter : Alignment.topRight,
      title: Text(normalized),
      autoCloseDuration: const Duration(seconds: 3),
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
