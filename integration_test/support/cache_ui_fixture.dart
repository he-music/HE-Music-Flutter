import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:he_music_flutter/core/network/network_status_port.dart';

import 'cache_harness_origin.dart';

const cacheUiBundle = 'com.hemusic.music.flutter.cacheui';

bool cacheUiIsolationAllowed({
  required bool release,
  required bool supportedPlatform,
  required String packageName,
}) => release && supportedPlatform && packageName == cacheUiBundle;

Uri cacheUiOrigin(String value) {
  final uri = Uri.parse(value);
  final address = InternetAddress.tryParse(uri.host);
  final octets = address?.rawAddress;
  final private =
      address != null &&
      (address.isLoopback ||
          (address.type == InternetAddressType.IPv4 &&
              (octets![0] == 10 ||
                  (octets[0] == 192 && octets[1] == 168) ||
                  (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31))));
  if (uri.scheme != 'http' ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      !private) {
    throw StateError('fixture_origin_guard');
  }
  return uri;
}

class CacheUiNetwork implements NetworkStatusPort {
  CacheUiNetwork({required bool offline})
    : _value = offline
          ? NetworkConnectionType.offline
          : NetworkConnectionType.wifi;
  NetworkConnectionType _value;
  final _changes = StreamController<NetworkConnectionType>.broadcast(
    sync: true,
  );
  void setOffline(bool offline) {
    _value = offline
        ? NetworkConnectionType.offline
        : NetworkConnectionType.wifi;
    _changes.add(_value);
  }

  @override
  NetworkConnectionType get lastKnown => _value;
  @override
  Future<NetworkConnectionType> current() async => _value;
  @override
  Stream<NetworkConnectionType> get changes => _changes.stream;
}

/// Owns only ui1 evidence and the fixture resolver, never app persistence.
class CacheUiFixture {
  CacheUiFixture(this.root, this.network, {Uri? external}) : base = external;
  final Directory root;
  final CacheUiNetwork network;
  Uri? base;
  CacheHarnessOrigin? _origin;
  int resolverCalls = 0;
  Future<void> _writes = Future.value();
  File get _counter => File('${root.path}/resolver-count.json');

  Future<void> initialize() async {
    if (await _counter.exists()) {
      final count = jsonDecode(await _counter.readAsString());
      if (count is! int || count < 0) {
        throw StateError('resolver_counter_invalid');
      }
      resolverCalls = count;
    }
    if (network.lastKnown != NetworkConnectionType.offline) await online();
  }

  Future<void> online() async {
    if (base != null) return;
    _origin = CacheHarnessOrigin(
      evidence: File('${root.path}/origin-counts.json'),
    );
    await _origin!.start();
    base = _origin!.base;
  }

  Future<Map<String, dynamic>> resolve({
    required String songId,
    required String platform,
    int? quality,
    String? format,
  }) async {
    final count = ++resolverCalls;
    // Persist attempts before validation/network, including requests that fail.
    await (_writes = _writes.then((_) async {
      final temp = File('${_counter.path}.tmp');
      await temp.writeAsString(jsonEncode(count), flush: true);
      await temp.rename(_counter.path);
    }));
    if (platform != 'fixture' ||
        !{'ui1_a', 'ui1_b', 'ui1_c'}.contains(songId) ||
        !{128, 320}.contains(quality) ||
        format != 'wav' ||
        network.lastKnown == NetworkConnectionType.offline ||
        base == null) {
      throw StateError('fixture_resolution_refused');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(base!.resolve('/resolve/$songId'));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode != 200) throw StateError('fixture_status');
      final raw = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 5));
      final payload = jsonDecode(raw);
      if (payload is! Map ||
          payload['path'] != '/audio/$songId' ||
          payload['format'] != 'wav') {
        throw StateError('fixture_payload');
      }
      return {
        'url': base!.resolve('/audio/$songId').toString(),
        'format': 'wav',
      };
    } finally {
      client.close(force: true);
    }
  }
}
