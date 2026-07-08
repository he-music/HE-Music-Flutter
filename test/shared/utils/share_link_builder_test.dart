import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_environment.dart';
import 'package:he_music_flutter/shared/utils/share_link_builder.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await AppEnvironment.initialize();
  });

  test('buildShareLink should use app api base url and hash route format', () {
    expect(
      buildShareLink(type: 'song', platform: 'kuwo', id: '562317423'),
      'https://example.com/#/song?id=562317423&platform=kuwo',
    );
  });

  test('buildShareLink should trim base url and params', () {
    expect(
      buildShareLink(type: ' song ', platform: ' kuwo ', id: ' 562317423 '),
      'https://example.com/#/song?id=562317423&platform=kuwo',
    );
  });
}
