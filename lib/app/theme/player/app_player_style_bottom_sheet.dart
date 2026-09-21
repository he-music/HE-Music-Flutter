import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/constants/layout_tokens.dart';
import '../glass/app_glass_sheet.dart';
import '../glass/app_glass_scope.dart';

import 'app_player_style_models.dart';
import 'app_player_style_theme.dart';

Future<T?> showPlayerStyledBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = true,
  bool useSafeArea = true,
  bool isScrollControlled = false,
  bool showDragHandle = true,
  double? fixedHeightFactor,
  double? heightFactor,
  bool fitContent = false,
}) {
  final inheritedTheme = Theme.of(context);
  final playerStyleTheme = inheritedTheme.extension<AppPlayerStyleTheme>();
  final sheetBrightness =
      playerStyleTheme?.sheetBrightness ?? inheritedTheme.brightness;
  final sheet = AppPlayerSheetStyle.forBrightness(sheetBrightness);
  final systemOverlayStyle = playerStyleTheme?.systemOverlayStyle;
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final modalContext = playerStyleTheme == null ? context : navigator.context;
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
  final glassEnabled =
      AppGlassScope.isEnabled(context) &&
      !AppGlassScope.preferOpaqueSurfaces(context);
  final sheetFuture = glassEnabled
      ? showLiveGlassSheet<T>(
          context: modalContext,
          useRootNavigator: useRootNavigator,
          useSafeArea: useSafeArea,
          // Player sheets share one glass material regardless of height.
          // A single detent preserves immediate content scrolling.
          heightFactor:
              fixedHeightFactor ??
              heightFactor ??
              (isScrollControlled
                  ? LayoutTokens.playerActionSheetHeightFactor
                  : 0.45),
          showDragHandle: showDragHandle,
          fitContent: fitContent,
          resolveTheme: (theme) => buildAppPlayerSheetTheme(
            AppPlayerSheetStyle.forBrightness(theme.brightness),
            theme.brightness,
          ),
          builder: builder,
        )
      : showModalBottomSheet<T>(
          // 播放器局部 Theme 固定为深色，使用 Navigator context 才能跟随实时 App Theme。
          context: modalContext,
          useRootNavigator: useRootNavigator,
          useSafeArea: useSafeArea,
          isScrollControlled:
              fitContent || fixedHeightFactor != null || isScrollControlled,
          constraints:
              fixedHeightFactor == null && (fitContent || isScrollControlled)
              ? BoxConstraints(
                  maxHeight:
                      MediaQuery.sizeOf(context).height *
                      (heightFactor ??
                          (isScrollControlled
                              ? LayoutTokens.playerActionSheetHeightFactor
                              : 0.45)),
                )
              : null,
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
            );
            return fixedHeightFactor == null
                ? body
                : FractionallySizedBox(
                    heightFactor: fixedHeightFactor,
                    child: body,
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
  });

  final WidgetBuilder builder;
  final bool showDragHandle;
  final bool opaque;

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
    final style = AppPlayerSheetStyle.forBrightness(brightness);
    return Theme(
      data: buildAppPlayerSheetTheme(style, brightness),
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
        color: opaque || AppGlassScope.preferOpaqueSurfaces(context)
            ? style.backgroundColor.withValues(alpha: 1)
            : style.backgroundColor,
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
