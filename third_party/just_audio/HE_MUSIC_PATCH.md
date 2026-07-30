# HE Music just_audio patch

This directory contains the runtime sources from the official `just_audio`
repository at commit `fcba2a37d63bd1bf0a933621d60f8e870310aa67`.

HE Music carries three visualizer fixes on top of that commit:

1. `stopVisualizer()` awaits the platform stop request so application-level
   start/stop convergence remains serialized.
2. Darwin disables FFT work and event delivery without removing the current
   `MTAudioProcessingTap` from a playing `AVPlayerItem`. Replacing `audioMix`
   during playback caused an audible interruption. The disabled tap only
   passes audio through and is removed after the item changes or the player is
   disposed.
3. Darwin waveform conversion uses the bounds-checked sample value when the
   requested capture size exceeds the available sample count.

The platform interface and web packages remain pinned to the same upstream
commit. Rebase these patches and rerun the Android, iOS, and macOS spectrum
integration gates before changing the upstream revision.
