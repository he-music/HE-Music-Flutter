import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class AppMessageService {
  AppMessageService._();

  static String? _lastMessage;
  static DateTime? _lastAt;

  static void showError(String message) {
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
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) {
      return;
    }
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(normalized), duration: const Duration(seconds: 2)),
    );
  }
}
