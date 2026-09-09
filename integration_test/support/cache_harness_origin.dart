import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Deterministic, audible PCM fixture. No assets, catalog, or credentials.
Uint8List cacheHarnessWave({int seconds = 30}) {
  const rate = 44100;
  final samples = rate * seconds;
  final bytes = Uint8List(44 + samples * 2);
  final data = ByteData.sublistView(bytes);
  void text(int offset, String value) =>
      bytes.setRange(offset, offset + value.length, ascii.encode(value));
  text(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  text(8, 'WAVE');
  text(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  text(36, 'data');
  data.setUint32(40, samples * 2, Endian.little);
  for (var i = 0; i < samples; i++) {
    data.setInt16(
      44 + i * 2,
      (sin(i * 2 * pi * 440 / rate) * 3000).round(),
      Endian.little,
    );
  }
  return bytes;
}

/// One RFC byte range; multiple ranges are deliberately rejected with 416.
({int start, int end})? cacheHarnessRange(String? header, int length) {
  if (header == null) return (start: 0, end: length - 1);
  final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header);
  if (match == null || length <= 0) return null;
  final left = match[1]!;
  final right = match[2]!;
  if (left.isEmpty) {
    final count = int.tryParse(right);
    if (count == null || count <= 0) return null;
    return (start: max(0, length - count), end: length - 1);
  }
  final start = int.tryParse(left);
  final end = right.isEmpty ? length - 1 : int.tryParse(right);
  if (start == null || end == null || start >= length || end < start) {
    return null;
  }
  return (start: start, end: min(end, length - 1));
}

class CacheHarnessOrigin {
  CacheHarnessOrigin({
    required this.evidence,
    this.chunkDelay = const Duration(milliseconds: 120),
  });

  final File evidence;
  final Duration chunkDelay;
  final bytes = cacheHarnessWave();
  final counts = <String, int>{
    'resolver': 0,
    'origin': 0,
    'range': 0,
    'completed': 0,
    'aborted': 0,
    'injected': 0,
  };
  HttpServer? _server;
  Future<void> _writes = Future.value();
  Uri get base => Uri(scheme: 'http', host: '127.0.0.1', port: _server!.port);

  Future<void> start({InternetAddress? address, int port = 0}) async {
    if (await evidence.exists()) {
      final previous =
          jsonDecode(await evidence.readAsString()) as Map<String, dynamic>;
      for (final key in counts.keys) {
        final value = previous[key];
        if (value is int && value >= 0) counts[key] = value;
      }
    }
    _server = await HttpServer.bind(
      address ?? InternetAddress.loopbackIPv4,
      port,
    );
    _server!.listen((request) {
      unawaited(_serve(request));
    });
  }

  Future<void> _record() {
    final encoded = jsonEncode(counts);
    return _writes = _writes.then((_) async {
      await evidence.parent.create(recursive: true);
      final temp = File('${evidence.path}.tmp');
      await temp.writeAsString(encoded, flush: true);
      await temp.rename(evidence.path);
    });
  }

  Future<void> _serve(HttpRequest request) async {
    final response = request.response;
    try {
      // Never accept auth forwarding, arbitrary paths, redirects, or uploads.
      if (request.headers.value(HttpHeaders.authorizationHeader) != null ||
          request.method != 'GET') {
        response.statusCode = HttpStatus.forbidden;
        await response.close();
        return;
      }
      if (request.uri.path == '/stats') {
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode(counts));
        await response.close();
        return;
      }
      final segments = request.uri.pathSegments;
      if (segments.length != 2 ||
          !RegExp(r'^[a-z0-9_-]+$').hasMatch(segments[1])) {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      final id = segments[1];
      if (segments[0] == 'resolve') {
        counts['resolver'] = counts['resolver']! + 1;
        await _record();
        response.headers.contentType = ContentType.json;
        response.write(
          jsonEncode({
            'path': '/audio/$id',
            'format': id == 'mismatch' ? 'mp3' : 'wav',
          }),
        );
        await response.close();
        return;
      }
      if (segments[0] != 'audio') {
        response.statusCode = HttpStatus.notFound;
        await response.close();
        return;
      }
      counts['origin'] = counts['origin']! + 1;
      final header = request.headers.value(HttpHeaders.rangeHeader);
      if (header != null) counts['range'] = counts['range']! + 1;
      await _record();
      if (id == 'reject') {
        counts['injected'] = counts['injected']! + 1;
        response.statusCode = HttpStatus.serviceUnavailable;
        await response.close();
        await _record();
        return;
      }
      final range = cacheHarnessRange(header, bytes.length);
      response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      response.headers.contentType = ContentType('audio', 'wav');
      if (range == null) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes */${bytes.length}',
        );
        await response.close();
        return;
      }
      if (header != null) {
        response.statusCode = HttpStatus.partialContent;
        response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes ${range.start}-${range.end}/${bytes.length}',
        );
      }
      response.contentLength = range.end - range.start + 1;
      for (var offset = range.start; offset <= range.end; offset += 16384) {
        if ((id == 'truncate' || id == 'disconnect') &&
            offset - range.start >= 65536) {
          counts['injected'] = counts['injected']! + 1;
          final socket = await response.detachSocket();
          socket.destroy();
          await _record();
          return;
        }
        response.add(bytes.sublist(offset, min(offset + 16384, range.end + 1)));
        await response.flush();
        await Future<void>.delayed(chunkDelay);
      }
      await response.close();
      counts['completed'] = counts['completed']! + 1;
    } catch (_) {
      counts['aborted'] = counts['aborted']! + 1;
      try {
        await response.close();
      } catch (_) {
        /* Client cancellation. */
      }
    } finally {
      await _record();
    }
  }

  Future<void> close() async {
    await _server?.close(force: true);
    await _writes;
  }
}
