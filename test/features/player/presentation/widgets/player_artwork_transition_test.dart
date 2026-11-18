import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/presentation/widgets/player_artwork_transition.dart';

class _DelayedImage extends ImageProvider<_DelayedImage> {
  final result = Completer<ImageInfo>();
  @override
  Future<_DelayedImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    _DelayedImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(result.future);
  void ready() {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(2, 2);
    picture.dispose();
    result.complete(ImageInfo(image: image));
  }
}

void main() {
  testWidgets(
    'keeps decoded artwork while loading and ignores skipped-track completions',
    (tester) async {
      final first = _DelayedImage();
      final skipped = _DelayedImage();
      final latest = _DelayedImage();
      Future<void> show(ImageProvider<Object>? image, {bool reduced = false}) =>
          tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(disableAnimations: reduced),
                child: SizedBox.square(
                  dimension: 100,
                  child: PlayerArtworkTransition(
                    imageProvider: image,
                    placeholder: const Text('placeholder'),
                    builder: (provider) => Text(
                      'artwork',
                      key: ValueKey<ImageProvider<Object>>(provider),
                    ),
                  ),
                ),
              ),
            ),
          );
      await show(first);
      first.ready();
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey<ImageProvider<Object>>(first)),
        findsOneWidget,
      );
      await show(skipped);
      expect(
        find.byKey(ValueKey<ImageProvider<Object>>(first)),
        findsOneWidget,
      );
      await show(latest);
      skipped.ready();
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey<ImageProvider<Object>>(first)),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey<ImageProvider<Object>>(skipped)),
        findsNothing,
      );
      latest.ready();
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey<ImageProvider<Object>>(latest)),
        findsOneWidget,
      );
      expect(find.byKey(ValueKey<ImageProvider<Object>>(first)), findsNothing);
      await show(null, reduced: true);
      await tester.pump();
      expect(find.text('placeholder'), findsOneWidget);
      expect(
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher)).duration,
        Duration.zero,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
