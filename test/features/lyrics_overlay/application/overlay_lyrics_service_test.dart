import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/lyrics_overlay/application/overlay_lyrics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('isActive returns false when overlay plugin is unavailable', () async {
    final service = OverlayLyricsService();

    await expectLater(service.isActive(), completion(isFalse));
  });

  test('close is a no-op when overlay plugin is unavailable', () async {
    final service = OverlayLyricsService();

    await expectLater(service.close(), completes);
  });
}
