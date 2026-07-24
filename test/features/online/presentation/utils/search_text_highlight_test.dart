import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/online/presentation/utils/search_text_highlight.dart';

void main() {
  test('highlights every matched keyword without changing original text', () {
    final segments = splitSearchHighlightText(
      text: 'Love Story by Taylor Swift',
      matchedKeywords: const <String>['story', 'TAYLOR'],
      fallbackKeyword: '',
    );

    expect(
      segments.map((item) => item.text).join(),
      'Love Story by Taylor Swift',
    );
    expect(
      segments.where((item) => item.highlighted).map((item) => item.text),
      <String>['Story', 'Taylor'],
    );
  });

  test('uses fallback keyword when matched keywords are empty', () {
    final segments = splitSearchHighlightText(
      text: '故事的小黄花',
      matchedKeywords: const <String>[],
      fallbackKeyword: '故事',
    );

    expect(segments.first.text, '故事');
    expect(segments.first.highlighted, isTrue);
  });

  test('prefers longest keyword for overlapping matches', () {
    final segments = splitSearchHighlightText(
      text: '晴天故事',
      matchedKeywords: const <String>['晴', '晴天'],
      fallbackKeyword: '',
    );

    expect(segments.first.text, '晴天');
    expect(segments.first.highlighted, isTrue);
    expect(segments.map((item) => item.text).join(), '晴天故事');
  });

  test('keeps html-like text as plain content', () {
    final segments = splitSearchHighlightText(
      text: '<em>晴天</em>',
      matchedKeywords: const <String>['晴天'],
      fallbackKeyword: '',
    );

    expect(segments.map((item) => item.text).join(), '<em>晴天</em>');
    expect(segments.where((item) => item.highlighted).single.text, '晴天');
  });
}
