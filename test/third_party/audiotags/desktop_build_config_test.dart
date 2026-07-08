import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audiotags linux build consumes bundled local artifact', () async {
    final content = await File(
      'third_party/audiotags/linux/CMakeLists.txt',
    ).readAsString();

    expect(content, contains('libaudiotags.so'));
    expect(content, contains('FATAL_ERROR'));
    expect(content, isNot(contains('file(DOWNLOAD')));
    expect(content, isNot(contains('linux.tar.gz')));
  });

  test('audiotags windows build consumes bundled local artifact', () async {
    final content = await File(
      'third_party/audiotags/windows/CMakeLists.txt',
    ).readAsString();

    expect(content, contains('audiotags.dll'));
    expect(content, contains('FATAL_ERROR'));
    expect(content, isNot(contains('file(DOWNLOAD')));
    expect(content, isNot(contains('windows.tar.gz')));
  });
}
