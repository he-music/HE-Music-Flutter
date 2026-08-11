import 'package:connectivity_plus/connectivity_plus.dart';

enum NetworkConnectionType { offline, wifi, cellular }

abstract interface class NetworkStatusPort {
  NetworkConnectionType get lastKnown;

  Future<NetworkConnectionType> current();

  Stream<NetworkConnectionType> get changes;
}

class ConnectivityNetworkStatusPort implements NetworkStatusPort {
  ConnectivityNetworkStatusPort({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  NetworkConnectionType _lastKnown = NetworkConnectionType.wifi;
  NetworkConnectionType _lastConnected = NetworkConnectionType.wifi;

  @override
  NetworkConnectionType get lastKnown => _lastKnown;

  @override
  Future<NetworkConnectionType> current() async {
    return _classify(await _connectivity.checkConnectivity());
  }

  @override
  Stream<NetworkConnectionType> get changes {
    return _connectivity.onConnectivityChanged.map(_classify).distinct();
  }

  NetworkConnectionType _classify(List<ConnectivityResult> results) {
    final hasConnection = results.any(
      (result) => result != ConnectivityResult.none,
    );
    if (!hasConnection) {
      return _lastKnown = NetworkConnectionType.offline;
    }
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet)) {
      _lastConnected = NetworkConnectionType.wifi;
      return _lastKnown = _lastConnected;
    }
    if (results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.satellite)) {
      _lastConnected = NetworkConnectionType.cellular;
      return _lastKnown = _lastConnected;
    }
    return _lastKnown = _lastConnected;
  }
}

final NetworkStatusPort globalNetworkStatusPort =
    ConnectivityNetworkStatusPort();
