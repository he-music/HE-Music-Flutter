import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

/// Painting resources are owned by the rail, including outgoing transition data.
abstract interface class LyricPaintResources {
  Iterable<TextPainter> get textPainters;
}

class LyricPainterOwner {
  final Set<TextPainter> _owned = Set<TextPainter>.identity();
  Set<TextPainter> _retained = Set<TextPainter>.identity();
  bool _scheduled = false;
  bool _disposed = false;

  void own(LyricPaintResources data) => _owned.addAll(data.textPainters);

  /// Release after the render object has received the new painter this frame.
  void retain(Iterable<LyricPaintResources?> data) {
    _retained = Set<TextPainter>.identity();
    for (final item in data) {
      if (item != null) _retained.addAll(item.textPainters);
    }
    _owned.addAll(_retained);
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (_disposed) return;
      final retired = _owned
          .where((painter) => !_retained.contains(painter))
          .toList();
      for (final painter in retired) {
        _owned.remove(painter);
        painter.dispose();
      }
    });
  }

  void dispose() {
    _disposed = true;
    for (final painter in _owned) {
      painter.dispose();
    }
    _owned.clear();
    _retained.clear();
  }
}
