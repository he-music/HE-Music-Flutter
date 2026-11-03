import 'package:flutter/material.dart';

/// Fixed playback chrome shared by both design languages.
class AppPlayerScaffold extends StatefulWidget {
  const AppPlayerScaffold({
    required this.body,
    required this.miniPlayer,
    this.navigation,
    super.key,
  });

  final Widget body;
  final Widget miniPlayer;
  final Widget? navigation;

  @override
  State<AppPlayerScaffold> createState() => _AppPlayerScaffoldState();
}

class _AppPlayerScaffoldState extends State<AppPlayerScaffold> {
  final _chromeKey = GlobalKey();
  double _chromeHeight = 0;
  bool _measureScheduled = false;

  void _scheduleChromeMeasurement() {
    if (_measureScheduled) return;
    _measureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureScheduled = false;
      if (!mounted) return;
      final height = _chromeKey.currentContext?.size?.height ?? 0;
      if (height != _chromeHeight) setState(() => _chromeHeight = height);
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleChromeMeasurement();
    final theme = Theme.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // Scaffold already places floating messages above the real bottom chrome.
    // Only compensate the part of the IME that extends beyond that chrome.
    final extraInset = (keyboard - _chromeHeight).clamp(0.0, double.infinity);
    final margin =
        theme.snackBarTheme.insetPadding ??
        const EdgeInsets.fromLTRB(15, 5, 15, 10);
    return Theme(
      data: theme.copyWith(
        snackBarTheme: theme.snackBarTheme.copyWith(
          insetPadding: margin + EdgeInsets.only(bottom: extraInset),
        ),
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: widget.body,
        bottomNavigationBar:
            NotificationListener<SizeChangedLayoutNotification>(
              onNotification: (_) {
                _scheduleChromeMeasurement();
                return false;
              },
              child: SizeChangedLayoutNotifier(
                child: Column(
                  key: _chromeKey,
                  mainAxisSize: MainAxisSize.min,
                  children: [widget.miniPlayer, ?widget.navigation],
                ),
              ),
            ),
      ),
    );
  }
}
