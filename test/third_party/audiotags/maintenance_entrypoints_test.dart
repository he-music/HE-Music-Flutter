import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audiotags exposes documented maintenance entrypoints', () async {
    final makefile = File('third_party/audiotags/Makefile');
    final readme = File('third_party/audiotags/README.md');

    expect(await makefile.exists(), isTrue);
    expect(await readme.exists(), isTrue);

    final makefileContent = await makefile.readAsString();
    final readmeContent = await readme.readAsString();

    expect(makefileContent, contains('codegen:'));
    expect(makefileContent, contains('build-android:'));
    expect(makefileContent, contains('build-macos:'));
    expect(makefileContent, contains('build-ios:'));
    expect(makefileContent, contains('build-linux:'));
    expect(makefileContent, contains('build-windows:'));
    expect(makefileContent, contains('regen:'));

    expect(readmeContent, contains('## Development'));
    expect(readmeContent, contains('make regen'));
    expect(readmeContent, contains('make build-android'));
    expect(readmeContent, contains('make build-macos'));
    expect(readmeContent, contains('make build-ios'));
    expect(readmeContent, contains('make build-linux'));
    expect(readmeContent, contains('make build-windows'));
  });
}
