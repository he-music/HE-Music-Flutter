import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checks the laid-out height against the text's unconstrained line height.
void expectTextHeightFits(WidgetTester tester, Finder scope) {
  final paragraphs = find.descendant(
    of: scope,
    matching: find.byType(RichText),
  );
  expect(paragraphs, findsWidgets);
  for (final element in paragraphs.evaluate()) {
    final widget = element.widget as RichText;
    final box = element.renderObject! as RenderBox;
    final painter = TextPainter(
      text: widget.text,
      textDirection: widget.textDirection ?? TextDirection.ltr,
      textScaler: widget.textScaler,
      maxLines: widget.maxLines,
      strutStyle: widget.strutStyle,
      textHeightBehavior: widget.textHeightBehavior,
      ellipsis: widget.overflow == TextOverflow.ellipsis ? '…' : null,
    )..layout(maxWidth: box.size.width);
    expect(
      box.size.height,
      greaterThanOrEqualTo(painter.height - 0.01),
      reason: widget.text.toPlainText(),
    );
    painter.dispose();
  }
}
