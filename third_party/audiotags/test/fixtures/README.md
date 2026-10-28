# Audio tag test fixtures

These are 0.1-second silent mono files at 8 kHz, generated locally with FFmpeg.
They contain no copyrighted audio or artwork. Native tests copy each file to an
isolated temporary path before adding tags, lyrics and small synthetic picture
byte arrays; the checked-in fixtures are never modified by tests.

To regenerate from this directory:

```sh
for format in mp3 m4a flac wav; do
  ffmpeg -nostdin -hide_banner -loglevel error \
    -f lavfi -i anullsrc=r=8000:cl=mono -t 0.1 -y "silence.$format"
done
```

Run the native tests with `cargo test --manifest-path rust/Cargo.toml` from the
vendored package root. MP4 does not encode picture types, so the expected cover
fallback for that format is the first image.
