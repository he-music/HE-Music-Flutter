import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Supplies deterministic artwork to Flutter's debug network-image client hook.
class ArtworkHttpClient implements HttpClient {
  ArtworkHttpClient(this.load);

  final FutureOr<Uint8List> Function(Uri uri) load;
  final List<Uri> requests = [];

  @override
  bool autoUncompress = false;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requests.add(url);
    return _ArtworkRequest(() => load(url));
  }

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ArtworkRequest implements HttpClientRequest {
  _ArtworkRequest(this.load);

  final FutureOr<Uint8List> Function() load;

  @override
  final HttpHeaders headers = _ArtworkHeaders();

  @override
  Future<HttpClientResponse> close() async => _ArtworkResponse(await load());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ArtworkHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ArtworkResponse extends Stream<List<int>> implements HttpClientResponse {
  _ArtworkResponse(this.bytes);

  final Uint8List bytes;

  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
