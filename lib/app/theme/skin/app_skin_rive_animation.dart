import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

import 'app_skin_asset_resolver.dart';
import 'app_skin_models.dart';

class AppSkinRiveAnimation extends StatefulWidget {
  const AppSkinRiveAnimation({
    required this.descriptor,
    required this.assetResolver,
    required this.enabled,
    super.key,
  });

  final AppSkinRiveAnimationDescriptor descriptor;
  final AppSkinAssetResolver assetResolver;
  final bool enabled;

  @override
  State<AppSkinRiveAnimation> createState() => _AppSkinRiveAnimationState();
}

class _AppSkinRiveAnimationState extends State<AppSkinRiveAnimation>
    with WidgetsBindingObserver {
  AppLifecycleState _lifecycleState =
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  rive.File? _file;
  rive.RiveWidgetController? _controller;
  var _disableAnimations = false;
  var _loadStarted = false;
  var _loadFailed = false;
  var _loadGeneration = 0;

  bool get _shouldAnimate {
    return widget.enabled &&
        !_disableAnimations &&
        _lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshDisableAnimations();
    _synchronizeAnimation();
  }

  @override
  void didUpdateWidget(covariant AppSkinRiveAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    _refreshDisableAnimations();
    final sourceChanged =
        oldWidget.descriptor != widget.descriptor ||
        oldWidget.assetResolver != widget.assetResolver;
    if (sourceChanged) {
      _disposeAnimation();
      _loadFailed = false;
    } else if (!oldWidget.enabled && widget.enabled) {
      _loadFailed = false;
    }
    _synchronizeAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_lifecycleState == state) {
      return;
    }
    setState(() => _lifecycleState = state);
    _synchronizeAnimation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeAnimation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_shouldAnimate || controller == null) {
      return const SizedBox.shrink();
    }

    return Opacity(
      key: const ValueKey<String>('app-skin-rive-animation'),
      opacity: widget.descriptor.opacity,
      child: rive.RiveWidget(
        key: const ValueKey<String>('app-skin-rive-widget'),
        controller: controller,
        fit: _toRiveFit(widget.descriptor.fit),
        alignment: widget.descriptor.alignment,
      ),
    );
  }

  void _synchronizeAnimation() {
    final shouldAnimate = _shouldAnimate;
    final controller = _controller;
    if (controller != null) {
      controller.active = shouldAnimate;
      return;
    }
    if (!shouldAnimate || _loadStarted || _loadFailed) {
      return;
    }

    _loadStarted = true;
    final generation = ++_loadGeneration;
    unawaited(_loadAnimation(generation));
  }

  void _refreshDisableAnimations() {
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_disableAnimations == disableAnimations) {
      return;
    }
    _disableAnimations = disableAnimations;
    if (!disableAnimations) {
      _loadFailed = false;
    }
  }

  Future<void> _loadAnimation(int generation) async {
    rive.File? file;
    rive.RiveWidgetController? controller;
    try {
      final result = await widget.assetResolver.load(widget.descriptor.asset);
      if (result is! AppSkinAssetLoadSuccess) {
        throw StateError('皮肤 Rive 资源加载失败');
      }
      final bytes = result.bytes;
      file = await rive.File.decode(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        // 稀疏背景动画使用 Flutter renderer，保持透明 Stack 合成稳定。
        riveFactory: rive.Factory.flutter,
      );
      if (file == null) {
        throw StateError('皮肤 Rive 资源解码失败');
      }
      controller = rive.RiveWidgetController(
        file,
        artboardSelector: rive.ArtboardSelector.byName(
          widget.descriptor.artboard,
        ),
        stateMachineSelector: rive.StateMachineSelector.byName(
          widget.descriptor.stateMachine,
        ),
      );
      if (!_isCurrentLoad(generation)) {
        controller.dispose();
        file.dispose();
        return;
      }

      controller.active = _shouldAnimate;
      setState(() {
        _file = file;
        _controller = controller;
        _loadStarted = false;
      });
    } catch (_) {
      controller?.dispose();
      file?.dispose();
      if (_isCurrentLoad(generation)) {
        setState(() {
          _loadStarted = false;
          _loadFailed = true;
        });
      }
    }
  }

  bool _isCurrentLoad(int generation) {
    return mounted && generation == _loadGeneration;
  }

  void _disposeAnimation() {
    _loadGeneration += 1;
    _controller?.dispose();
    _file?.dispose();
    _controller = null;
    _file = null;
    _loadStarted = false;
  }
}

rive.Fit _toRiveFit(BoxFit fit) {
  return switch (fit) {
    BoxFit.fill => rive.Fit.fill,
    BoxFit.contain => rive.Fit.contain,
    BoxFit.cover => rive.Fit.cover,
    BoxFit.fitWidth => rive.Fit.fitWidth,
    BoxFit.fitHeight => rive.Fit.fitHeight,
    BoxFit.none => rive.Fit.none,
    BoxFit.scaleDown => rive.Fit.scaleDown,
  };
}
