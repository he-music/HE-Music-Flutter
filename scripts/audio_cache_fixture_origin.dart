import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../integration_test/support/cache_harness_origin.dart';

/// Opt-in external fixture process. Counts survive app AND fixture restart.
void main(List<String> args) {
  runZonedGuarded(
    () async {
      if (args.length != 3 ||
          !RegExp(r'^[a-z0-9_-]{1,32}$').hasMatch(args[0])) {
        stderr.writeln(
          'Usage: dart run scripts/audio_cache_fixture_origin.dart RUN BIND_IP PORT',
        );
        exitCode = 64;
        return;
      }
      final bind = InternetAddress.tryParse(args[1]);
      final port = int.tryParse(args[2]);
      if (bind == null || port == null || port < 1024 || port > 65535) {
        throw StateError('arguments');
      }
      final root = Directory(
        '${Directory.systemTemp.path}/he-music-native-release-fixture/${args[0]}',
      );
      final origin = CacheHarnessOrigin(
        evidence: File('${root.path}/counts.json'),
      );
      await origin.start(address: bind, port: port);
      stdout.writeln('AUDIO_CACHE_FIXTURE ready');
      final timer = Timer.periodic(const Duration(seconds: 2), (_) {
        stdout.writeln('AUDIO_CACHE_FIXTURE ${jsonEncode(origin.counts)}');
      });
      ProcessSignal.sigint.watch().listen((_) async {
        timer.cancel();
        await origin.close();
        exit(0);
      });
    },
    (_, _) {
      stderr.writeln('AUDIO_CACHE_FIXTURE failed');
      exitCode = 1;
    },
  );
}
