import 'package:flutter/material.dart';

/// Fixed playback chrome shared by both design languages.
class AppPlayerScaffold extends StatelessWidget {
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
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: false,
    body: body,
    bottomNavigationBar: Column(
      mainAxisSize: MainAxisSize.min,
      children: [miniPlayer, ?navigation],
    ),
  );
}
