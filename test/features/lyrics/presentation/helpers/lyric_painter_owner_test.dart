import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics/presentation/helpers/lyric_painter_owner.dart';

class _Resources implements LyricPaintResources {
  _Resources(this.textPainters);
  @override
  final List<TextPainter> textPainters;
}

class _Painter extends TextPainter {
  int disposals = 0;
  @override
  void dispose() {
    disposals++;
    super.dispose();
  }
}

void main() {
  testWidgets(
    'shared current outgoing and preheated resources survive until detached',
    (tester) async {
      final owner = LyricPainterOwner();
      final shared = _Painter();
      final outgoing = _Painter();
      final warm = _Painter();
      final first = _Resources([shared, outgoing]);
      final second = _Resources([shared]);
      final third = _Resources([warm]);
      owner.own(first);
      owner.own(second);
      owner.own(third);
      owner.retain([second, first, third]);
      tester.binding.scheduleFrame();
      await tester.pump();
      expect([shared.disposals, outgoing.disposals, warm.disposals], [0, 0, 0]);
      // An interrupted transition replaces outgoing/current before the callback.
      owner.retain([second]);
      owner.retain([third, second]);
      expect(outgoing.disposals, 0);
      tester.binding.scheduleFrame();
      await tester.pump();
      expect([shared.disposals, outgoing.disposals, warm.disposals], [0, 1, 0]);
      owner.retain([third]);
      tester.binding.scheduleFrame();
      await tester.pump();
      expect(shared.disposals, 1);
      owner.dispose();
      expect(warm.disposals, 1);
      expect(outgoing.disposals, 1);
    },
  );

  testWidgets('unmount cancels deferred release without double disposal', (
    tester,
  ) async {
    final owner = LyricPainterOwner();
    final painter = _Painter();
    owner.own(_Resources([painter]));
    owner.retain([]);
    owner.dispose();
    await tester.pump();
    expect(painter.disposals, 1);
  });
}
