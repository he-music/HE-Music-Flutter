import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_entry.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_runtime.dart';

import 'phase4_cache_test_support.dart';

/// Records the rendered labels and icons, including icon-only badges/actions.
List<Object?> visibleCacheSurface(WidgetTester tester) => [
  for (final widget in tester.allWidgets)
    if (widget is Text)
      ('text', widget.data, widget.textSpan?.toPlainText())
    else if (widget is Icon)
      ('icon', widget.icon, widget.semanticLabel)
    else if (widget is Tooltip)
      ('tooltip', widget.message)
    else if (widget is Semantics)
      ('semantics', widget.properties.label),
];

class CacheSurfaceFixture {
  final store = RecordingAudioCacheStore();
  late final runtime = AudioCacheRuntime(store: store, capabilityEnabled: true);

  void publish() => store.emit(
    const AudioCacheSnapshot(
      entryCount: 2,
      publishedBytes: 2097152,
      readHealth: AudioCacheReadHealth.ready,
      writeHealth: AudioCacheWriteHealth.ready,
    ),
  );
}
