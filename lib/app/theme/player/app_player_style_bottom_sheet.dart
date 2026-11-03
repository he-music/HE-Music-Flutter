import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/constants/layout_tokens.dart';

import 'app_player_style_models.dart';
import 'app_player_style_theme.dart';

import '../../config/app_ui_style.dart';
import '../app_ui_theme.dart';

Future<T?> showPlayerStyledBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  bool useSafeArea = true,
  bool isScrollControlled = false,
  bool showDragHandle = true,
  // Keep action colors consistent when opening playback submenus.
  bool useAppAccent = true,
  double? fixedHeightFactor,
  double? heightFactor,
  double? maxWidth,
  bool fitContent = false,
  bool useCupertinoActionSheet = false,
}) {
  if (useCupertinoActionSheet && AppUiTheme.usesCupertino(context)) {
    return showPlayerCupertinoActionSheet<T>(
      context: context,
      sheetBuilder: builder,
      useRootNavigator: useRootNavigator,
    );
  }
  final inheritedTheme = Theme.of(context);
  final playerStyleTheme = inheritedTheme.extension<AppPlayerStyleTheme>();
  final sheetBrightness =
      playerStyleTheme?.sheetBrightness ?? inheritedTheme.brightness;
  final sheet = AppPlayerSheetStyle.forBrightness(
    sheetBrightness,
    uiStyle: AppUiTheme.usesCupertino(context)
        ? AppUiStyle.cupertino
        : AppUiStyle.material,
  );
  final systemOverlayStyle = playerStyleTheme?.systemOverlayStyle;
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final modalContext = navigator.context;
  final overlayEntry = systemOverlayStyle == null
      ? null
      : OverlayEntry(
          builder: (_) => Positioned.fill(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  key: const ValueKey<String>(
                    'player-system-ui-overlay-style-guard',
                  ),
                  value: systemOverlayStyle,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        );

  // Modal route 位于播放器之上，弹层存续期间需要持续提供播放器的系统栏样式。
  if (overlayEntry != null) {
    Overlay.of(context, rootOverlay: true).insert(overlayEntry);
  }
  final sheetFuture = showModalBottomSheet<T>(
    // 播放器局部 Theme 固定为深色，使用 Navigator context 才能跟随实时 App Theme。
    context: modalContext,
    useRootNavigator: useRootNavigator,
    useSafeArea: useSafeArea,
    isScrollControlled:
        fitContent || fixedHeightFactor != null || isScrollControlled,
    constraints: fixedHeightFactor == null && (fitContent || isScrollControlled)
        ? BoxConstraints(
            maxWidth: maxWidth ?? double.infinity,
            maxHeight:
                MediaQuery.sizeOf(context).height *
                (heightFactor ??
                    (isScrollControlled
                        ? LayoutTokens.playerActionSheetHeightFactor
                        : 0.45)),
          )
        : maxWidth == null
        ? null
        : BoxConstraints(maxWidth: maxWidth),
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.54),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(sheet.topRadius),
      ),
    ),
    builder: (sheetContext) {
      final body = _PlayerStyledBottomSheetBody(
        builder: builder,
        showDragHandle: showDragHandle,
        opaque: fixedHeightFactor != null,
        useAppAccent: useAppAccent,
        systemOverlayStyle: systemOverlayStyle,
      );
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: fixedHeightFactor == null
            ? body
            : FractionallySizedBox(
                heightFactor: fixedHeightFactor,
                child: body,
              ),
      );
    },
  );
  if (overlayEntry == null) {
    return sheetFuture;
  }
  return sheetFuture.whenComplete(() {
    overlayEntry
      ..remove()
      ..dispose();
  });
}

class _PlayerStyledBottomSheetBody extends StatefulWidget {
  const _PlayerStyledBottomSheetBody({
    required this.builder,
    required this.showDragHandle,
    required this.opaque,
    required this.useAppAccent,
    this.systemOverlayStyle,
  });

  final WidgetBuilder builder;
  final bool showDragHandle;
  final bool opaque;
  final bool useAppAccent;
  final SystemUiOverlayStyle? systemOverlayStyle;

  @override
  State<_PlayerStyledBottomSheetBody> createState() =>
      _PlayerStyledBottomSheetBodyState();
}

class _PlayerStyledBottomSheetBodyState
    extends State<_PlayerStyledBottomSheetBody> {
  late final Widget _child = Builder(builder: widget.builder);

  @override
  Widget build(BuildContext context) {
    final inheritedTheme = Theme.of(context);
    final brightness =
        inheritedTheme.extension<AppPlayerStyleTheme>()?.sheetBrightness ??
        inheritedTheme.brightness;
    final uiStyle = AppUiTheme.usesCupertino(context)
        ? AppUiStyle.cupertino
        : AppUiStyle.material;
    final style = AppPlayerSheetStyle.forBrightness(
      brightness,
      uiStyle: uiStyle,
    );
    final sheetTheme = buildAppPlayerSheetTheme(
      style,
      brightness,
      uiStyle: uiStyle,
      primaryColor: uiStyle == AppUiStyle.cupertino || widget.useAppAccent
          ? inheritedTheme.colorScheme.primary
          : null,
      onPrimaryColor: uiStyle == AppUiStyle.cupertino || widget.useAppAccent
          ? inheritedTheme.colorScheme.onPrimary
          : null,
    );
    return Theme(
      data: widget.systemOverlayStyle == null
          ? sheetTheme
          : sheetTheme.copyWith(
              extensions: <ThemeExtension<dynamic>>[
                AppUiTheme(style: uiStyle),
                AppPlayerStyleTheme(
                  systemOverlayStyle: widget.systemOverlayStyle!,
                  sheetBrightness: brightness,
                ),
              ],
            ),
      child: PlayerSheetSurface(
        style: style,
        showDragHandle: widget.showDragHandle,
        opaque: widget.opaque,
        child: _child,
      ),
    );
  }
}

class PlayerSheetSurface extends StatelessWidget {
  const PlayerSheetSurface({
    required this.style,
    required this.showDragHandle,
    required this.child,
    this.opaque = false,
    super.key,
  });

  final AppPlayerSheetStyle style;
  final bool showDragHandle;
  final Widget child;
  final bool opaque;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      key: const ValueKey<String>('player-sheet-surface'),
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(style.topRadius),
      ),
      child: ColoredBox(
        color: style.backgroundColor.withValues(alpha: 1),
        child: IconTheme(
          data: IconThemeData(color: style.foregroundColor),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: style.foregroundColor),
            child: showDragHandle
                ? Stack(
                    alignment: Alignment.topCenter,
                    children: <Widget>[
                      _PlayerSheetDragHandle(color: style.handleColor),
                      Padding(
                        padding: const EdgeInsets.only(
                          top: kMinInteractiveDimension,
                        ),
                        child: child,
                      ),
                    ],
                  )
                : child,
          ),
        ),
      ),
    );
  }
}

class _PlayerSheetDragHandle extends StatelessWidget {
  const _PlayerSheetDragHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      button: true,
      onTap: () => Navigator.of(context).maybePop(),
      child: SizedBox(
        width: kMinInteractiveDimension,
        height: kMinInteractiveDimension,
        child: Center(
          child: DecoratedBox(
            key: const ValueKey<String>('player-sheet-drag-handle'),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
            child: const SizedBox(width: 32, height: 4),
          ),
        ),
      ),
    );
  }
}

class PlayerCupertinoAction<T> {
  const PlayerCupertinoAction({
    required this.value,
    required this.label,
    this.enabled = true,
    this.destructive = false,
  });

  final T value;
  final String label;
  final bool enabled;
  final bool destructive;
}

Future<T?> showPlayerCupertinoActionSheet<T>({
  required BuildContext context,
  List<PlayerCupertinoAction<T>>? actions,
  Widget? title,
  Widget? message,
  WidgetBuilder? sheetBuilder,
  bool useRootNavigator = true,
}) {
  assert(actions != null || sheetBuilder != null);
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final inheritedTheme = Theme.of(navigator.context);
  final playerStyleTheme = Theme.of(context).extension<AppPlayerStyleTheme>();
  final brightness =
      playerStyleTheme?.sheetBrightness ?? inheritedTheme.brightness;
  const uiStyle = AppUiStyle.cupertino;
  final style = AppPlayerSheetStyle.forBrightness(brightness, uiStyle: uiStyle);
  final sheetTheme = buildAppPlayerSheetTheme(
    style,
    brightness,
    uiStyle: uiStyle,
    primaryColor: inheritedTheme.colorScheme.primary,
    onPrimaryColor: inheritedTheme.colorScheme.onPrimary,
  );
  final systemOverlayStyle = playerStyleTheme?.systemOverlayStyle;
  final overlayEntry = systemOverlayStyle == null
      ? null
      : OverlayEntry(
          builder: (_) => Positioned.fill(
            child: IgnorePointer(
              child: AnnotatedRegion<SystemUiOverlayStyle>(
                key: const ValueKey<String>(
                  'player-system-ui-overlay-style-guard',
                ),
                value: systemOverlayStyle,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );
  if (overlayEntry != null) {
    Overlay.of(context, rootOverlay: true).insert(overlayEntry);
  }
  final route = showCupertinoModalPopup<T>(
    context: navigator.context,
    useRootNavigator: useRootNavigator,
    semanticsDismissible: true,
    builder: (popupContext) => CupertinoTheme(
      data: CupertinoThemeData(
        brightness: brightness,
        primaryColor: sheetTheme.colorScheme.primary,
        primaryContrastingColor: sheetTheme.colorScheme.onPrimary,
        scaffoldBackgroundColor: style.backgroundColor,
        barBackgroundColor: style.backgroundColor,
        textTheme: CupertinoTextThemeData(
          primaryColor: sheetTheme.colorScheme.primary,
          textStyle: sheetTheme.textTheme.bodyMedium,
          actionTextStyle: sheetTheme.textTheme.labelLarge?.copyWith(
            color: sheetTheme.colorScheme.primary,
          ),
        ),
      ),
      child: Theme(
        data: sheetTheme.copyWith(
          extensions: <ThemeExtension<dynamic>>[
            AppUiTheme(style: AppUiStyle.cupertino),
            ?playerStyleTheme,
          ],
        ),
        child: AppUiStyleScope(
          style: AppUiStyle.cupertino,
          child: sheetBuilder != null
              ? Builder(builder: sheetBuilder)
              : CupertinoActionSheet(
                  title: title,
                  message: message,
                  actions: <Widget>[
                    for (final action in actions!)
                      if (action.enabled)
                        CupertinoActionSheetAction(
                          isDestructiveAction: action.destructive,
                          onPressed: () =>
                              Navigator.of(popupContext).pop(action.value),
                          child: Text(action.label),
                        )
                      else
                        CupertinoButton(
                          onPressed: null,
                          child: Text(action.label),
                        ),
                  ],
                  cancelButton: CupertinoActionSheetAction(
                    onPressed: () => Navigator.of(popupContext).pop(),
                    child: Text(
                      CupertinoLocalizations.of(popupContext).cancelButtonLabel,
                    ),
                  ),
                ),
        ),
      ),
    ),
  );
  if (overlayEntry == null) return route;
  return route.whenComplete(() {
    overlayEntry
      ..remove()
      ..dispose();
  });
}
