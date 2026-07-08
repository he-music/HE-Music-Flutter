import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/layout/ranking_layout_spec.dart';

void main() {
  test(
    'ranking wrap keeps mobile single column and scales columns on wider screens',
    () {
      final mobile = resolveRankingWrapLayoutSpec(maxWidth: 390);
      final mediumDesktop = resolveRankingWrapLayoutSpec(maxWidth: 900);
      final desktop = resolveRankingWrapLayoutSpec(maxWidth: 1440);
      final ultrawide = resolveRankingWrapLayoutSpec(maxWidth: 2200);

      expect(mobile.crossAxisCount, 1);
      expect(mobile.itemWidth, 390);
      expect(mediumDesktop.crossAxisCount, 2);
      expect(desktop.itemWidth, inInclusiveRange(320, 460));
      expect(ultrawide.itemWidth, inInclusiveRange(320, 460));
      expect(ultrawide.crossAxisCount, greaterThan(desktop.crossAxisCount));
    },
  );

  test('ranking row cover stops growing past desktop cap', () {
    final compact = resolveRankingRowLayoutSpec(maxWidth: 420);
    final desktop = resolveRankingRowLayoutSpec(maxWidth: 1440);

    expect(compact.coverSide, greaterThan(0));
    expect(desktop.coverSide, lessThanOrEqualTo(176));
    expect(desktop.coverSide, greaterThanOrEqualTo(compact.coverSide));
  });

  test('ranking grid adds columns on wide widths', () {
    final compact = resolveRankingGridLayoutSpec(maxWidth: 420);
    final desktop = resolveRankingGridLayoutSpec(maxWidth: 980);

    expect(compact.crossAxisCount, 3);
    expect(desktop.crossAxisCount, greaterThan(compact.crossAxisCount));
    expect(desktop.itemWidth, greaterThan(0));
  });
}
