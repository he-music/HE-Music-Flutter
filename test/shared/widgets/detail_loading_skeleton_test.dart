import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/widgets/animated_skeleton.dart';
import 'package:he_music_flutter/shared/widgets/detail_loading_skeleton.dart';

void main() {
  testWidgets('artist videos loading skeleton uses compact video cover size', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ArtistVideosLoadingView())),
    );

    final firstSkeleton = find.byType(SkeletonBox).first;
    expect(tester.getSize(firstSkeleton), const Size(112, 64));
  });
}
