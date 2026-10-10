import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/image/local_artwork_bytes_provider.dart';

void main() {
  test(
    'active artwork consumers share the cached read and other paths stay independent',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'he-artwork-test-',
      );
      final first = File('${directory.path}/first.png');
      final second = File('${directory.path}/second.png');
      await first.writeAsBytes([1, 2, 3]);
      await second.writeAsBytes([4, 5, 6]);
      final container = ProviderContainer();
      addTearDown(() async {
        container.dispose();
        await directory.delete(recursive: true);
      });
      container.listen(localArtworkBytesProvider(first.path), (_, _) {});
      final bytes = await container.read(
        localArtworkBytesProvider(first.path).future,
      );
      await first.writeAsBytes([7, 8, 9]);
      expect(
        await container.read(localArtworkBytesProvider(first.path).future),
        same(bytes),
      );
      expect(
        await container.read(localArtworkBytesProvider(second.path).future),
        [4, 5, 6],
      );
      container.invalidate(localArtworkBytesProvider(first.path));
      expect(
        await container.read(localArtworkBytesProvider(first.path).future),
        [7, 8, 9],
      );
    },
  );

  test('missing and empty artwork provide the image fallback', () async {
    final directory = await Directory.systemTemp.createTemp(
      'he-artwork-empty-',
    );
    final empty = File('${directory.path}/empty.png');
    await empty.writeAsBytes([]);
    final container = ProviderContainer();
    addTearDown(() async {
      container.dispose();
      await directory.delete(recursive: true);
    });
    expect(await container.read(localArtworkBytesProvider('').future), isNull);
    expect(
      await container.read(localArtworkBytesProvider(empty.path).future),
      isNull,
    );
    expect(
      await container.read(
        localArtworkBytesProvider('${directory.path}/missing.png').future,
      ),
      isNull,
    );
  });
}
