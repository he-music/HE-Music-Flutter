// ignore_for_file: experimental_member_use

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'audio_player_factory.dart';
import 'decrypt/audio_decryptor.dart';
import 'decrypt/audio_transform_parameters.dart';

/// Fetches and decrypts CDN bytes directly. Only just_audio's StreamAudioSource
/// proxy exposes these bytes to the native player; this source binds no server.
final class DecryptingAudioSource extends StreamAudioSource {
  DecryptingAudioSource({
    required String url,
    required String audioParams,
    required String format,
    Directory? temporaryDirectory,
    super.tag,
  }) : _upstream = Uri.parse(url),
       _encodedParameters = audioParams,
       _parameters = AudioTransformParameters.parse(audioParams),
       _format = format,
       _temporaryDirectory = temporaryDirectory {
    if (!{'http', 'https'}.contains(_upstream.scheme) ||
        _upstream.host.isEmpty ||
        _upstream.userInfo.isNotEmpty ||
        _upstream.hasFragment ||
        !_mimeTypes.containsKey(format)) {
      throw const FormatException('Invalid encrypted audio source');
    }
  }

  static const maxAudioBytes = 128 * 1024 * 1024;
  static Future<Directory>? _workspace;
  static Future<void> _sampleTail = Future.value();
  final Uri _upstream;
  final String _encodedParameters;
  final AudioTransformParameters _parameters;
  final String _format;
  final Directory? _temporaryDirectory;
  final _reads = <_AudioRead>{};
  Future<File>? _sampleFile;
  Directory? _directory;
  bool _disposed = false;
  Future<void>? _disposal;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    _ensureActive();
    if ((start != null && (start < 0 || start > 1 << 40)) ||
        (end != null && (end <= (start ?? 0) || end > 1 << 40))) {
      throw const FormatException('Invalid audio range');
    }
    if (_parameters.kind == 4) return _requestSamples(start, end);
    final read = _beginRead();
    try {
      final response = await _fetch(read, start: start, end: end);
      _ensureActive();
      final (offset, total) = _responseRange(response);
      final worker = await _TransformWorker.start(_encodedParameters, offset);
      read.worker = worker;
      if (read.isClosed || _disposed) {
        await worker.dispose();
        throw StateError('Audio source released');
      }
      final partial = response.statusCode == HttpStatus.partialContent;
      read.bind(_transformStream(response, worker));
      return StreamAudioResponse(
        rangeRequestsSupported:
            (start == null && end == null || partial) &&
            response.headers.value(HttpHeaders.acceptRangesHeader) != 'none',
        sourceLength: total,
        contentLength: response.contentLength >= 0
            ? response.contentLength
            : null,
        offset: partial ? offset : null,
        contentType: _mimeTypes[_format]!,
        stream: read.stream,
      );
    } catch (_) {
      await read.close();
      throw const FormatException('Audio stream unavailable');
    }
  }

  _AudioRead _beginRead() {
    _ensureActive();
    if (_reads.length >= 4) throw StateError('Audio source busy');
    final userAgent = _parameters.userAgent;
    final client = HttpClient()
      ..autoUncompress = false
      ..connectionTimeout = const Duration(seconds: 20)
      ..idleTimeout = const Duration(seconds: 20)
      ..userAgent = userAgent == null || userAgent.trim().isEmpty
          ? heAudioUserAgent
          : userAgent;
    late final _AudioRead read;
    read = _AudioRead(client, () => _reads.remove(read));
    _reads.add(read);
    return read;
  }

  Future<HttpClientResponse> _fetch(
    _AudioRead read, {
    int? start,
    int? end,
  }) async {
    final request = await read.client.getUrl(_upstream);
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    if (start != null || end != null) {
      request.headers.set(
        HttpHeaders.rangeHeader,
        'bytes=${start ?? 0}-${end == null ? '' : end - 1}',
      );
    }
    return request.close().timeout(const Duration(seconds: 30));
  }

  Stream<List<int>> _transformStream(
    HttpClientResponse response,
    _TransformWorker worker,
  ) async* {
    final pending = BytesBuilder(copy: false);
    var received = 0;
    var firstChunk = true;
    await for (final chunk in response.timeout(const Duration(seconds: 30))) {
      received += chunk.length;
      if (response.contentLength >= 0 && received > response.contentLength) {
        throw const FormatException('Invalid audio length');
      }
      pending.add(chunk);
      if (pending.isNotEmpty && (firstChunk || pending.length >= 64 * 1024)) {
        firstChunk = false;
        yield await worker.transform(pending.takeBytes());
      }
    }
    if (response.contentLength >= 0 && received != response.contentLength) {
      throw const FormatException('Incomplete audio stream');
    }
    if (pending.isNotEmpty) yield await worker.transform(pending.takeBytes());
  }

  Future<StreamAudioResponse> _requestSamples(int? start, int? end) async {
    try {
      final file = await (_sampleFile ??= _loadSamplesSerial());
      _ensureActive();
      final length = await file.length();
      final begin = start ?? 0;
      final finish = min(end ?? length, length);
      if (begin >= length || finish <= begin) {
        throw const FormatException('Invalid audio range');
      }
      return StreamAudioResponse(
        sourceLength: length,
        contentLength: finish - begin,
        offset: start == null && end == null ? null : begin,
        contentType: _mimeTypes[_format]!,
        stream: file.openRead(begin, finish),
      );
    } catch (_) {
      throw const FormatException('Sample audio unavailable');
    }
  }

  Future<File> _loadSamplesSerial() async {
    final previous = _sampleTail;
    final done = Completer<void>();
    _sampleTail = done.future;
    try {
      await previous;
      _ensureActive();
      return await _loadSamples();
    } finally {
      done.complete();
    }
  }

  Future<File> _loadSamples() async {
    final root =
        _temporaryDirectory ?? await (_workspace ??= _prepareWorkspace());
    final directory = await root.createTemp('source-');
    _directory = directory;
    _ensureActive();
    final input = File('${directory.path}/source.part');
    final output = File('${directory.path}/audio.$_format');
    final read = _beginRead();
    try {
      final response = await _fetch(read);
      if (response.statusCode != HttpStatus.ok ||
          response.contentLength > maxAudioBytes ||
          !_identityEncoding(response)) {
        throw const FormatException('Invalid sample audio response');
      }
      final sink = input.openWrite();
      var bytes = 0;
      try {
        await sink.addStream(
          response.timeout(const Duration(seconds: 30)).map((chunk) {
            bytes += chunk.length;
            _ensureActive();
            if (bytes > maxAudioBytes) {
              throw const FormatException('Sample audio unavailable');
            }
            return chunk;
          }),
        );
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (bytes == 0 ||
          (response.contentLength >= 0 && bytes != response.contentLength)) {
        throw const FormatException('Incomplete sample audio response');
      }
      _ensureActive();
      await decryptAudioFile(
        input: input,
        output: output,
        encodedParameters: _encodedParameters,
      );
      await input.delete();
      _ensureActive();
      return output;
    } finally {
      await read.close();
    }
  }

  static Future<Directory> _prepareWorkspace() async {
    final parent = await getTemporaryDirectory();
    final root = Directory('${parent.path}/audio_decryption_work');
    if (await root.exists()) await root.delete(recursive: true);
    return root.create(recursive: true);
  }

  void _ensureActive() {
    if (_disposed) throw StateError('Audio source released');
  }

  /// Called by the playback lease after native playback has detached. Also
  /// releases responses whose streams were returned but never subscribed to.
  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    for (final read in _reads.toList()) {
      await read.close();
    }
    try {
      await _sampleFile;
    } catch (_) {
      // Cancelled or failed samples still own their staging directory.
    }
    final directory = _directory;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

/// A response owns its CDN connection and worker even before the player starts
/// listening. Stream cancellation closes both, and backpressure reaches the CDN.
final class _AudioRead {
  _AudioRead(this.client, this._onClosed) {
    _controller = StreamController<List<int>>(
      onListen: _listen,
      onPause: () => _subscription?.pause(),
      onResume: () => _subscription?.resume(),
      onCancel: close,
    );
  }

  final HttpClient client;
  final void Function() _onClosed;
  late final StreamController<List<int>> _controller;
  Stream<List<int>>? _input;
  StreamSubscription<List<int>>? _subscription;
  _TransformWorker? worker;
  bool isClosed = false;
  Future<void>? _closing;

  Stream<List<int>> get stream => _controller.stream;
  void bind(Stream<List<int>> input) => _input = input;

  void _listen() {
    if (isClosed) {
      _controller.addError(const FormatException('Audio source released'));
      unawaited(_controller.close());
      return;
    }
    _subscription = _input!.listen(
      (chunk) {
        if (!isClosed) _controller.add(chunk);
      },
      onError: (Object _, StackTrace stack) {
        if (!isClosed) {
          _controller.addError(
            const FormatException('Audio stream unavailable'),
            stack,
          );
        }
        unawaited(close());
      },
      onDone: () => unawaited(close()),
      cancelOnError: true,
    );
  }

  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    isClosed = true;
    client.close(force: true);
    await _subscription?.cancel();
    await worker?.dispose();
    if (_controller.hasListener && !_controller.isClosed) {
      unawaited(_controller.close());
    }
    _onClosed();
  }
}

const _mimeTypes = <String, String>{
  'mp3': 'audio/mpeg',
  'flac': 'audio/flac',
  'wav': 'audio/wav',
  'm4a': 'audio/mp4',
  'aac': 'audio/aac',
  'ogg': 'audio/ogg',
  'opus': 'audio/ogg',
  'aiff': 'audio/aiff',
  'alac': 'audio/mp4',
};

bool _identityEncoding(HttpClientResponse response) {
  final encoding = response.headers.value(HttpHeaders.contentEncodingHeader);
  return encoding == null || encoding == 'identity';
}

(int, int?) _responseRange(HttpClientResponse response) {
  if (!_identityEncoding(response) ||
      (response.headers.contentType?.mimeType.startsWith('multipart/') ??
          false)) {
    throw const FormatException('Invalid audio response');
  }
  final range = response.headers.value(HttpHeaders.contentRangeHeader);
  if (response.statusCode == HttpStatus.ok && range == null) {
    return (0, response.contentLength >= 0 ? response.contentLength : null);
  }
  if (response.statusCode != HttpStatus.partialContent || range == null) {
    throw const FormatException('Invalid audio response');
  }
  final match = RegExp(r'^bytes (\d+)-(\d+)/(\d+|\*)$').firstMatch(range);
  if (match == null) throw const FormatException('Invalid audio range');
  final start = int.parse(match[1]!);
  final end = int.parse(match[2]!);
  final total = match[3] == '*' ? null : int.parse(match[3]!);
  if (end < start ||
      end > 1 << 40 ||
      (total != null && total <= end) ||
      (response.contentLength >= 0 &&
          response.contentLength != end - start + 1)) {
    throw const FormatException('Invalid audio range');
  }
  return (start, total);
}

/// One worker per upstream response keeps transforms off the UI isolate and
/// transfers bounded chunks with backpressure, rather than spawning per chunk.
final class _TransformWorker {
  _TransformWorker(this._isolate, this._messages, this._send);

  final Isolate _isolate;
  final StreamIterator<dynamic> _messages;
  final SendPort _send;
  bool _disposed = false;

  static Future<_TransformWorker> start(String parameters, int offset) async {
    final receive = ReceivePort();
    final messages = StreamIterator<dynamic>(receive);
    final isolate = await Isolate.spawn(
      _transformEntry,
      (receive.sendPort, parameters, offset),
      onExit: receive.sendPort,
      onError: receive.sendPort,
    );
    try {
      if (!await messages.moveNext() || messages.current is! SendPort) {
        throw const FormatException('Audio transform unavailable');
      }
      return _TransformWorker(isolate, messages, messages.current as SendPort);
    } catch (_) {
      isolate.kill(priority: Isolate.immediate);
      await messages.cancel();
      receive.close();
      rethrow;
    }
  }

  Future<Uint8List> transform(Uint8List bytes) async {
    if (_disposed) throw StateError('Audio transform disposed');
    _send.send(TransferableTypedData.fromList([bytes]));
    if (!await _messages.moveNext() ||
        _messages.current is! TransferableTypedData) {
      throw const FormatException('Audio transform unavailable');
    }
    return (_messages.current as TransferableTypedData)
        .materialize()
        .asUint8List();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _isolate.kill(priority: Isolate.immediate);
    await _messages.cancel();
  }
}

void _transformEntry((SendPort, String, int) arguments) {
  final (send, encoded, initialOffset) = arguments;
  final receive = ReceivePort();
  try {
    final parameters = AudioTransformParameters.parse(encoded);
    var offset = initialOffset;
    send.send(receive.sendPort);
    receive.listen((message) {
      try {
        final input = (message as TransferableTypedData)
            .materialize()
            .asUint8List();
        final output = transformAudioBytes(input, parameters, offset: offset);
        offset += input.length;
        send.send(TransferableTypedData.fromList([output]));
      } catch (_) {
        send.send(null);
        receive.close();
      }
    });
  } catch (_) {
    send.send(null);
    receive.close();
  }
}
