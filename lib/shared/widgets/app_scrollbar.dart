import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../app/config/app_ui_style.dart';
import '../../app/theme/app_ui_theme.dart';

/// Keeps the scrollable subtree mounted when its scrollbar design changes.
class AppScrollbar extends StatefulWidget {
  const AppScrollbar({
    required this.child,
    this.controller,
    this.uiStyle,
    super.key,
  });

  final Widget child;
  final ScrollController? controller;
  final AppUiStyle? uiStyle;

  @override
  State<AppScrollbar> createState() => _AppScrollbarState();
}

class _AppScrollbarState extends State<AppScrollbar> {
  final _childKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final child = KeyedSubtree(key: _childKey, child: widget.child);
    final cupertino = widget.uiStyle == null
        ? AppUiTheme.usesCupertino(context)
        : widget.uiStyle == AppUiStyle.cupertino;
    return cupertino
        ? CupertinoScrollbar(controller: widget.controller, child: child)
        : Scrollbar(controller: widget.controller, child: child);
  }
}
