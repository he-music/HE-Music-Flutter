// Adapted from github.com/guohuiyuan/music-lib/soda/crypto.go (AGPL-3.0)
// through HE-Music desktop/internal/audiodecrypt/transform/samples.go.
// See README.md for synchronization notes.
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'audio_transform_parameters.dart';

const maxAudioSampleFileSize = 128 * 1024 * 1024;

/// Decrypts the complete MP4 container into a copy, preserving the input.
/// Matches the Go executor's sequential mdat sample layout and clear-byte rules.
Uint8List decryptAudioSamples(
  Uint8List bytes,
  AudioTransformParameters parameters,
) {
  if (parameters.kind != 4 || bytes.length > maxAudioSampleFileSize) {
    throw const FormatException(
      'Invalid sample transform or file exceeds 128 MiB',
    );
  }
  final data = ByteData.sublistView(bytes);
  final moov = _find(data, 'moov', 0, bytes.length);
  final stbl = _find(data, 'stbl', moov.offset, moov.end);
  final stsz = _find(data, 'stsz', stbl.body, stbl.end);
  if (stsz.end - stsz.body < 12) _invalid();
  final fixed = data.getUint32(stsz.body + 4);
  final count = data.getUint32(stsz.body + 8);
  if (count == 0 ||
      count > 1 << 20 ||
      (fixed == 0 && count > (stsz.end - stsz.body - 12) ~/ 4)) {
    _invalid();
  }
  final sizes = Uint32List(count);
  for (var i = 0; i < count; i++) {
    sizes[i] = fixed == 0 ? data.getUint32(stsz.body + 12 + i * 4) : fixed;
  }
  final senc = _find(data, 'senc', moov.body, moov.end);
  final tenc = _tryFind(data, 'tenc', stbl.offset, stbl.end);
  var ivSize = 8;
  if (tenc != null && tenc.end - tenc.body >= 8) {
    final size = data.getUint8(tenc.body + 7);
    if (size == 8 || size == 16) ivSize = size;
  }
  final mdat = _find(data, 'mdat', 0, bytes.length);
  var remaining = mdat.end - mdat.body;
  for (final size in sizes) {
    if (size > remaining) _invalid();
    remaining -= size;
  }
  if (remaining != 0) _invalid();
  // Validate the complete table before allocating or modifying the output.
  _walkSamples(data, senc, ivSize, count, null);
  final result = Uint8List.fromList(bytes);
  var read = mdat.body;
  _walkSamples(data, senc, ivSize, count, (iv, subsStart, subsCount, index) {
    final stream = SICStreamCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(parameters.key), iv));
    final end = read + sizes[index];
    var pos = read;
    if (subsCount == 0) {
      while (pos < end) {
        result[pos] = stream.returnByte(result[pos]);
        pos++;
      }
    } else {
      for (var i = 0; i < subsCount && pos < end; i++) {
        final sub = subsStart + i * 6;
        pos += data.getUint16(sub).clamp(0, end - pos);
        final encrypted = data.getUint32(sub + 2).clamp(0, end - pos);
        for (var j = 0; j < encrypted; j++) {
          result[pos] = stream.returnByte(result[pos]);
          pos++;
        }
      }
    }
    read = end;
  });
  final stsd = _tryFind(data, 'stsd', stbl.body, stbl.end);
  if (stsd != null) {
    final enca = _index(bytes, 'enca', stsd.offset, stsd.end);
    if (enca >= 0) {
      final frma = _index(bytes, 'frma', stsd.offset, stsd.end);
      var format = <int>[109, 112, 52, 97]; // mp4a fallback, matching Go.
      if (frma >= stsd.offset + 4 && frma + 8 <= stsd.end) {
        final size = data.getUint32(frma - 4);
        if (size >= 12 && frma - 4 + size <= stsd.end) {
          format = bytes.sublist(frma + 4, frma + 8);
        }
      }
      result.setRange(enca, enca + 4, format);
    }
  }
  return result;
}

Never _invalid() => throw const FormatException('Invalid MP4 audio container');

class _Box {
  const _Box(this.offset, this.body, this.end);
  final int offset, body, end;
}

_Box _find(ByteData data, String type, int start, int end) =>
    _tryFind(data, type, start, end) ??
    (throw FormatException('$type box not found'));

_Box? _tryFind(
  ByteData data,
  String type,
  int start,
  int end, [
  int depth = 0,
]) {
  if (depth > 32 || start < 0 || end < start) return null;
  end = end.clamp(0, data.lengthInBytes);
  var pos = start;
  while (pos + 8 <= end) {
    var size = data.getUint32(pos);
    var header = 8;
    if (size == 1) {
      if (pos + 16 > end) break;
      // Avoid signed uint64 overflow in the Dart VM.
      if (data.getUint32(pos + 8) != 0) break;
      size = data.getUint32(pos + 12);
      header = 16;
    }
    if (size == 0) size = end - pos;
    if (size < header || size > end - pos) break;
    final current = String.fromCharCodes(
      List.generate(4, (i) => data.getUint8(pos + 4 + i)),
    );
    if (current == type) return _Box(pos, pos + header, pos + size);
    final extra = switch (current) {
      'moov' || 'trak' || 'mdia' || 'minf' || 'stbl' || 'sinf' || 'schi' => 0,
      'stsd' => 8,
      'enca' || 'mp4a' || 'alac' || 'fLaC' => 28,
      _ => -1,
    };
    if (extra >= 0 && pos + header + extra < pos + size) {
      final found = _tryFind(
        data,
        type,
        pos + header + extra,
        pos + size,
        depth + 1,
      );
      if (found != null) return found;
    }
    pos += size;
  }
  return null;
}

int _index(Uint8List data, String text, int start, int end) {
  for (var i = start; i + text.length <= end; i++) {
    var matches = true;
    for (var j = 0; j < text.length; j++) {
      if (data[i + j] != text.codeUnitAt(j)) {
        matches = false;
        break;
      }
    }
    if (matches) return i;
  }
  return -1;
}

// Two passes bound metadata memory: no object graph per sample/subsample.
void _walkSamples(
  ByteData data,
  _Box senc,
  int ivSize,
  int expected,
  void Function(Uint8List iv, int subsStart, int subsCount, int index)? visit,
) {
  if (senc.end - senc.body < 8) _invalid();
  final flags = data.getUint32(senc.body) & 0xffffff;
  final count = data.getUint32(senc.body + 4);
  if (count > 1 << 20 || count > (senc.end - senc.body - 8) ~/ ivSize) {
    _invalid();
  }
  var ptr = senc.body + 8;
  var parsed = 0;
  for (var i = 0; i < count; i++) {
    if (ptr + ivSize > senc.end) break;
    final ivStart = ptr;
    ptr += ivSize;
    var subsCount = 0;
    if (flags & 2 != 0) {
      if (ptr + 2 > senc.end) break;
      subsCount = data.getUint16(ptr);
      ptr += 2;
      if (ptr + subsCount * 6 > senc.end) break;
    }
    final subsStart = ptr;
    ptr += subsCount * 6;
    if (visit != null) {
      final iv = Uint8List(16);
      for (var j = 0; j < ivSize; j++) {
        iv[j] = data.getUint8(ivStart + j);
      }
      visit(iv, subsStart, subsCount, i);
    }
    parsed++;
  }
  if (parsed != expected) _invalid();
}
