# HE Music just_audio patch

This directory contains the runtime sources from the official `just_audio`
repository at commit `fcba2a37d63bd1bf0a933621d60f8e870310aa67`.

HE Music carries eleven changes on top of that commit:

1. `stopVisualizer()` awaits the platform stop request so application-level
   start/stop convergence remains serialized.
2. Darwin disables FFT work and event delivery without removing the current
   `MTAudioProcessingTap` from a playing `AVPlayerItem`. Replacing `audioMix`
   during playback caused an audible interruption. The disabled tap only
   passes audio through and is removed after the item changes or the player is
   disposed.
3. Darwin waveform conversion uses the bounds-checked sample value when the
   requested capture size exceeds the available sample count.
4. After visualizer use, Darwin keeps the configured capture size and migrates
   a disabled pass-through tap to replacement player items. Resuming capture
   after a background track change therefore does not modify the active item's
   `audioMix`.
5. A Darwin processing tap retains its `AudioPlayer` until finalization, and
   each main-thread event owns copies of the waveform, FFT, and sampling rate.
   Tap replacement or player disposal therefore cannot leave realtime or
   queued callbacks reading released storage.
6. Position extrapolation pauses while a seek request is pending, keeping lyric
   word progress fixed at the optimistic seek target until the platform response
   establishes a new playback timestamp.
7. `LockCachingAudioSource` is a one-shot download owner with serialized
   `active -> completed | cancelled | failed` transitions. `completedFile` is
   published only after an accepted complete 200/206 response with a positive
   known length, exact `Content-Range`/byte-count validation, sink flush/close,
   and `.part` rename. Startup resource registration is serialized with clear
   and cancel. `cancelDownload()` is idempotent and closes the origin/range
   clients, response iterator, sink, pending requests, and response
   controllers before deleting staging files. Completion also reclaims paused
   auxiliary range transfers without waiting for paused proxy consumers; an
   unfinished transfer terminates with a typed content-length failure rather
   than a successful short body.
   Public failures expose only a typed category and never include the origin
   URI, request headers, cache path, or underlying exception message.
8. `AudioPlayer.releaseAudioSource()` requires both Dart playlist removal and
   proven native detachment, recursively removes its player registry entries, and
   unregisters URI/stream proxy handlers while preserving children still owned
   by the current playlist or a native graph. `detachAudioSource()` uses source
   membership snapshots captured at native load dispatch, not `audioSource`,
   which changes during Dart `_init` before replacement reaches native. Failed
   initialization/load retains old and candidate ownership; only the latest
   successful native load or acknowledged platform disposal proves detachment.
   Pending handler loads check this fence before and after their set Future
   settles, preserving stale-load convergence without stopping a committed newer
   source. Proxy registration keys include the source ID; HLS
   nested URIs are rewritten into the same owner namespace, and a generation
   fence prevents an in-flight manifest from registering handlers after release.
   Proxy bind/stop and async handlers are serialized, forwarding clients close
   in `finally`, and source failures return HTTP 500 without printing exception
   details. URI and stream loads recheck source ownership after async asset or
   proxy startup so a concurrent release cannot register a late handler.
   Android native error logs use fixed categories rather than exception
   messages. Releasing a caching source also cancels unfinished transfer ownership
   and closes its progress stream.

9. Darwin explicitly settles and clears the pending native load callback on
   cancellation and explicit disposal. Item-specific error routing must not
   discard a cancelled load's callback when the current player item is non-null.
   The Dart native-detach fence still waits for load settlement before releasing
   data; a missing callback otherwise hangs superseded transitions and retains
   cache leases. The native Release rapid-replacement regression in
   `integration_test/audio_cache_native_release_harness.dart` reproduces this
   failure; post-fix device verification is recorded in the audio-cache task.
10. Android re-anchors playback position when ExoPlayer's actual playing state
    changes. The existing buffer watcher also compares the audio clock with the
    position extrapolated at the current speed and publishes a fresh sample when
    drift exceeds 80 ms. This corrects cold-start output delays without requiring
    a user seek or a fixed lyric offset. Checks run only while playing and ready,
    outside a pending seek; the existing watcher controls scheduling and disposal.
    Run `cd android && ./gradlew :just_audio:testDebugUnitTest` from the app root
    for the native clock regression tests. Cold-start listening still needs
    verification on a physical device.
11. `LockCachingAudioSource.streamSource` optionally reads an upstream
    `StreamAudioSource` directly through `request(start, end)`. Only the caching
    source attaches to the player's proxy, so local decryption and caching do
    not introduce an additional HTTP hop. Direct responses retain positive full
    length, range offset/total, terminal byte-count and staging validation.
    Cancellation owns pending responses even before their streams are consumed;
    auxiliary range transfers propagate pause/resume and cancel upstream reads.
    The application owns disposal of the upstream source after native detach.
    Run `flutter test test/core/audio/decrypting_audio_source_test.dart
    test/core/audio/cache/stream_audio_cache_transport_test.dart` from the app
    root in addition to the existing vendored cache and lifecycle tests.

The platform interface and web packages remain pinned to the same upstream
commit. Rebases must preserve the Dart-side source registry, proxy registration,
and `LockCachingAudioSource` terminal/resource ownership changes, which overlap
upstream `AudioPlayer`, `AudioSource`, `_ProxyHttpServer`, and stream source code.
Rerun the vendored lifecycle tests plus Android, iOS, and macOS Release integration
gates before changing the upstream revision.
