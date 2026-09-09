import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_cache_entry.dart';
import 'audio_cache_runtime.dart';

/// Overridden by bootstrap; never create a second store/mutation queue in UI.
final audioCacheRuntimeProvider = Provider<AudioCacheRuntime?>((ref) => null);

final audioCacheSnapshotProvider = StreamProvider<AudioCacheSnapshot>((ref) {
  final runtime = ref.watch(audioCacheRuntimeProvider);
  if (runtime == null) return const Stream.empty();
  return runtime.snapshots;
});
