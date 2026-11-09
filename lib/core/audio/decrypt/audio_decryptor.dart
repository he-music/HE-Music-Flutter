// Ported from HE-Music audiodecrypt/transform/stream.go (AGPL-3.0).
// See README.md for provenance. No platform key derivation occurs here.
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'audio_transform_parameters.dart';
import 'audio_samples.dart';

export 'audio_samples.dart' show decryptAudioSamples, maxAudioSampleFileSize;

const _maxOffset = 1 << 40;

/// Returns a transformed copy. [offset] is the absolute ciphertext byte offset.
Uint8List transformAudioBytes(
  Uint8List bytes,
  AudioTransformParameters parameters, {
  int offset = 0,
}) {
  final p = parameters;
  if (p.kind == 4 ||
      offset < 0 ||
      offset > _maxOffset ||
      bytes.length > _maxOffset - offset) {
    throw const FormatException('Invalid audio stream offset or kind');
  }
  final result = Uint8List.fromList(bytes);
  if (p.kind == 1 || p.kind == 2) {
    for (var i = 0; i < result.length; i++) {
      var at = offset + i;
      if (p.kind == 1) {
        result[i] = result[i] - p.key[at % p.key.length];
      } else {
        if (at > p.period) at %= p.period;
        result[i] ^= p.key[(at * at + p.bias) % p.key.length];
      }
    }
    return result;
  }
  var pos = 0;
  while (offset < p.first && pos < result.length) {
    result[pos++] ^= p.key[_segmentSkip(p, offset++)];
  }
  while (pos < result.length) {
    final count = (p.segment - offset % p.segment).clamp(
      0,
      result.length - pos,
    );
    final box = Uint8List.fromList(p.box);
    var j = 0, k = 0;
    final skip = offset % p.segment + _segmentSkip(p, offset ~/ p.segment);
    for (var i = -skip; i < count; i++) {
      j = (j + 1) % box.length;
      k = (k + box[j]) % box.length;
      final temp = box[j];
      box[j] = box[k];
      box[k] = temp;
      if (i >= 0) result[pos + i] ^= box[(box[j] + box[k]) % box.length];
    }
    pos += count;
    offset += count;
  }
  return result;
}

int _segmentSkip(AudioTransformParameters p, int id) =>
    (p.hash / ((id + 1).toDouble() * p.key[id % p.key.length]) * 100.0)
        .truncate() %
    p.key.length;

/// Runs file I/O and transforms in a worker isolate, publishing by same-directory
/// rename only after the complete temporary file has been flushed and closed.
Future<void> decryptAudioFile({
  required File input,
  required File output,
  required String encodedParameters,
}) async {
  final inputPath = input.absolute.path;
  final outputPath = output.absolute.path;
  await Isolate.run(
    () => _decryptFile(inputPath, outputPath, encodedParameters),
  );
}

void _decryptFile(String inputPath, String outputPath, String encoded) {
  final p = AudioTransformParameters.parse(encoded);
  final input = File(inputPath), output = File(outputPath);
  if (input.absolute.uri.normalizePath() ==
          output.absolute.uri.normalizePath() ||
      (output.existsSync() &&
          FileSystemEntity.identicalSync(
            input.resolveSymbolicLinksSync(),
            output.resolveSymbolicLinksSync(),
          ))) {
    throw const FileSystemException('Input and output must differ');
  }
  final source = input.openSync();
  Directory? temporaryDirectory;
  RandomAccessFile? destination;
  try {
    final length = source.lengthSync();
    if (p.kind == 4 && length > maxAudioSampleFileSize) {
      throw const FormatException('Audio sample file exceeds 128 MiB');
    }
    temporaryDirectory = output.parent.createTempSync('.audio-decrypt-');
    final temporary = File('${temporaryDirectory.path}/output');
    destination = temporary.openSync(mode: FileMode.write);
    if (p.kind == 4) {
      final bytes = Uint8List(length);
      var read = 0;
      while (read < length) {
        final n = source.readIntoSync(bytes, read);
        if (n == 0) throw const FileSystemException('Truncated audio input');
        read += n;
      }
      if (source.readByteSync() != -1) {
        throw const FileSystemException('Audio input changed');
      }
      destination.writeFromSync(decryptAudioSamples(bytes, p));
    } else {
      var offset = 0;
      while (true) {
        final bytes = source.readSync(64 * 1024);
        if (bytes.isEmpty) break;
        destination.writeFromSync(
          transformAudioBytes(bytes, p, offset: offset),
        );
        offset += bytes.length;
      }
    }
    destination.flushSync();
    destination.closeSync();
    destination = null;
    source.closeSync();
    temporary.renameSync(outputPath);
  } finally {
    destination?.closeSync();
    // A second close is harmless, but avoid masking the original exception.
    try {
      source.closeSync();
    } catch (_) {}
    temporaryDirectory?.deleteSync(recursive: true);
  }
}
