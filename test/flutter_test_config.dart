import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/database/app_database.dart';
import 'package:he_music_flutter/core/database/local_music_database.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(() {
    final database = LocalMusicDatabase.forTesting();
    setAppDatabaseForTesting(database);
    addTearDown(database.close);
  });
  await testMain();
}
