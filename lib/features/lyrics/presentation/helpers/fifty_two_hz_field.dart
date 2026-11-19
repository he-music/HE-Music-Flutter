import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

const fiftyTwoHzPeriod = Duration(milliseconds: 720);
const fiftyTwoHzLifetime = Duration(milliseconds: 3600);

/// Playback-relative ring geometry. Reconstructs the same frame after a seek.
({double newest, double oldest})? fiftyTwoHzRadii({
  required Duration position,
  required Duration start,
  Duration? stop,
  required double reach,
}) {
  final period = fiftyTwoHzPeriod.inMicroseconds;
  final lineStart = math.max(0, start.inMicroseconds);
  final firstBirth = (lineStart + period - 1) ~/ period * period;
  final elapsed = position.inMicroseconds - firstBirth;
  if (elapsed < 0) return null;
  final lastBirth = stop == null
      ? elapsed
      : math.min(elapsed, stop.inMicroseconds - firstBirth - 1);
  if (lastBirth < 0) return null;
  final youngest = elapsed - lastBirth ~/ period * period;
  if (youngest >= fiftyTwoHzLifetime.inMicroseconds) return null;
  final speed = reach / fiftyTwoHzLifetime.inMicroseconds;
  return (newest: youngest * speed, oldest: elapsed * speed);
}

class FiftyTwoHzField {
  FiftyTwoHzField(this.bounds, this.image, ui.FragmentProgram program)
    : _shader = program.fragmentShader() {
    _shader.setImageSampler(0, image, filterQuality: ui.FilterQuality.low);
  }

  static final Future<ui.FragmentProgram> _program =
      ui.FragmentProgram.fromAsset('shaders/52hz_ripples.frag');

  final ui.Rect bounds;
  final ui.Image image;
  final ui.FragmentShader _shader;
  final ui.Paint _paint = ui.Paint();

  static Future<FiftyTwoHzField?> rasterize({
    required ui.Rect bounds,
    required double reach,
    required double glyphGap,
    required void Function(ui.Canvas canvas) paintMask,
  }) async {
    final scale = math.min(1.0, 480 / math.max(bounds.width, bounds.height));
    final width = math.max(1, (bounds.width * scale).round());
    final height = math.max(1, (bounds.height * scale).round());
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      ..scale(width / bounds.width, height / bounds.height)
      ..translate(-bounds.left, -bounds.top);
    paintMask(canvas);
    final picture = recorder.endRecording();
    try {
      final program = await _program;
      final mask = await picture.toImage(width, height);
      Uint8List? pixels;
      try {
        final rgba = await mask.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (rgba == null) return null;
        pixels = rgba.buffer.asUint8List(
          rgba.offsetInBytes,
          rgba.lengthInBytes,
        );
      } finally {
        mask.dispose();
      }
      final encoded = await compute(encodeFiftyTwoHzDistances, (
        rgba: pixels,
        width: width,
        height: height,
        dx: bounds.width / width,
        dy: bounds.height / height,
        reach: reach,
        glyphGap: glyphGap,
      ), debugLabel: '52Hz glyph distance field');
      if (encoded == null) return null;
      final buffer = await ui.ImmutableBuffer.fromUint8List(encoded);
      final descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: width,
        height: height,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      try {
        final codec = await descriptor.instantiateCodec();
        try {
          final frame = await codec.getNextFrame();
          return FiftyTwoHzField(bounds, frame.image, program);
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor.dispose();
        buffer.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  void paint(
    ui.Canvas canvas,
    ui.Color color,
    double reach,
    ({double newest, double oldest}) radii,
  ) {
    _shader
      ..setFloat(0, bounds.left)
      ..setFloat(1, bounds.top)
      ..setFloat(2, bounds.width)
      ..setFloat(3, bounds.height)
      ..setFloat(4, color.r)
      ..setFloat(5, color.g)
      ..setFloat(6, color.b)
      ..setFloat(7, reach)
      ..setFloat(8, radii.newest)
      ..setFloat(
        9,
        reach *
            fiftyTwoHzPeriod.inMicroseconds /
            fiftyTwoHzLifetime.inMicroseconds,
      )
      ..setFloat(10, radii.oldest);
    canvas.drawRect(bounds, _paint..shader = _shader);
  }

  void dispose() {
    _shader.dispose();
    image.dispose();
  }
}

/// Exact Euclidean distance to ink, with a linear-time pass along each axis.
/// Stores each distance in two channels to retain subpixel precision at large reach.
Uint8List? encodeFiftyTwoHzDistances(
  ({
    Uint8List rgba,
    int width,
    int height,
    double dx,
    double dy,
    double reach,
    double glyphGap,
  })
  input,
) {
  final (:rgba, :width, :height, :dx, :dy, :reach, :glyphGap) = input;
  final horizontal = Float64List(width * height);
  var hasInk = false;
  for (var y = 0; y < height; y++) {
    final row = y * width;
    var distance = double.infinity;
    var firstInk = width;
    var lastInk = -1;
    for (var x = 0; x < width; x++) {
      final i = row + x;
      if (rgba[4 * i + 3] >= 96) {
        distance = 0;
        hasInk = true;
        if (firstInk == width) firstInk = x;
        lastInk = x;
      } else {
        distance += dx;
      }
      horizontal[i] = distance * distance;
    }
    distance = double.infinity;
    for (var x = width - 1; x >= 0; x--) {
      final i = row + x;
      // Join the glyphs across each scanline so gaps inside a phrase cannot emit rings.
      final insideLine = glyphGap > 0 && x >= firstInk && x <= lastInk;
      distance = insideLine || rgba[4 * i + 3] >= 96 ? 0 : distance + dx;
      horizontal[i] = math.min(horizontal[i], distance * distance);
    }
  }
  if (!hasInk) return null;

  final result = Uint8List(width * height * 4);
  final sites = Int32List(height);
  final boundaries = Float64List(height);
  final dySquared = dy * dy;
  for (var x = 0; x < width; x++) {
    var count = 0;
    for (var y = 0; y < height; y++) {
      final value = horizontal[y * width + x];
      if (!value.isFinite) continue;
      var boundary = double.negativeInfinity;
      // Intersect the new site's squared-distance parabola with the envelope.
      while (count > 0) {
        final previous = sites[count - 1];
        boundary =
            (y + previous) / 2 +
            (value - horizontal[previous * width + x]) /
                (2 * dySquared * (y - previous));
        if (boundary > boundaries[count - 1]) break;
        count--;
      }
      sites[count] = y;
      boundaries[count] = count == 0 ? double.negativeInfinity : boundary;
      count++;
    }
    var site = 0;
    for (var y = 0; y < height; y++) {
      while (site + 1 < count && boundaries[site + 1] < y) {
        site++;
      }
      final origin = sites[site];
      final delta = (y - origin) * dy;
      final distance = math.sqrt(
        horizontal[origin * width + x] + delta * delta,
      );
      final outsideDistance = math.max(0.0, distance - glyphGap);
      final value = (math.min(1.0, outsideDistance / reach) * 65535).round();
      final offset = 4 * (y * width + x);
      result[offset] = value >> 8;
      result[offset + 1] = value & 255;
      result[offset + 3] = 255;
    }
  }
  return result;
}
