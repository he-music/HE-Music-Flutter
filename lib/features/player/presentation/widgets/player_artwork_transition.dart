import 'package:flutter/material.dart';

/// Keeps the displayed artwork until its replacement is decoded. Late loads from
/// skipped tracks never replace the current request.
class PlayerArtworkTransition extends StatefulWidget {
  const PlayerArtworkTransition({
    required this.imageProvider,
    required this.builder,
    required this.placeholder,
    this.animate = true,
    super.key,
  });

  final ImageProvider<Object>? imageProvider;
  final Widget Function(ImageProvider<Object>) builder;
  final Widget placeholder;
  final bool animate;

  @override
  State<PlayerArtworkTransition> createState() =>
      _PlayerArtworkTransitionState();
}

class _PlayerArtworkTransitionState extends State<PlayerArtworkTransition> {
  ImageProvider<Object>? _shown;
  ImageProvider<Object>? _requested;
  int _generation = 0;
  bool _initialized = false;
  bool _animateReplacement = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(covariant PlayerArtworkTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  Future<void> _load() async {
    final target = widget.imageProvider;
    if (_initialized && target == _requested) return;
    _initialized = true;
    _requested = target;
    final generation = ++_generation;
    if (target == null) {
      setState(() => _shown = null);
      return;
    }
    var failed = false;
    await precacheImage(target, context, onError: (_, _) => failed = true);
    if (!mounted || generation != _generation) return;
    // A failed replacement belongs to a different track: show its placeholder,
    // rather than presenting the old album as the new song's artwork.
    setState(() {
      _animateReplacement = _shown != null;
      _shown = failed ? null : target;
    });
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration:
        widget.animate &&
            _animateReplacement &&
            !MediaQuery.disableAnimationsOf(context)
        ? const Duration(milliseconds: 450)
        : Duration.zero,
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: (current, previous) =>
        Stack(fit: StackFit.expand, children: [...previous, ?current]),
    child: KeyedSubtree(
      key: ValueKey(_shown),
      child: _shown == null ? widget.placeholder : widget.builder(_shown!),
    ),
  );
}
