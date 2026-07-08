import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('audiotags android build consumes bundled jniLibs artifacts', () async {
    final buildFile = File('third_party/audiotags/android/build.gradle');
    final content = await buildFile.readAsString();

    expect(content, contains("main.jniLibs.srcDirs = ['src/main/jniLibs']"));
    expect(content, isNot(contains('externalNativeBuild')));
    expect(
      content,
      isNot(
        contains("apply from: '../rust_builder/cargokit/gradle/plugin.gradle'"),
      ),
    );
  });
}
