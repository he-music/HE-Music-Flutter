import 'package:dio/dio.dart';

import 'client_instance_id_store.dart';

/// Only our backend receives the installation identity. Media/CDN requests use
/// their own transport and must not inherit this header.
class ClientInstanceInterceptor extends Interceptor {
  ClientInstanceInterceptor({
    required String baseUrl,
    Future<String> Function()? loadId,
  }) : _backend = Uri.parse(baseUrl),
       _loadId = loadId ?? clientInstanceIdStore.load;

  static const headerName = 'X-Client-Instance-ID';
  final Uri _backend;
  final Future<String> Function() _loadId;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers.removeWhere(
      (key, _) => key.toLowerCase() == headerName.toLowerCase(),
    );
    final target = options.uri;
    final backendPath = _backend.path.replaceAll(RegExp(r'/+$'), '');
    if ((_backend.scheme != 'http' && _backend.scheme != 'https') ||
        (target.scheme != 'http' && target.scheme != 'https') ||
        !_backend.hasAuthority ||
        !target.hasAuthority ||
        target.origin != _backend.origin ||
        !target.path.startsWith('$backendPath/')) {
      handler.next(options);
      return;
    }
    // Native redirects happen below interceptors. Never forward the identity to
    // a redirect target, even when local storage is temporarily unavailable.
    options.followRedirects = false;
    try {
      final id = await _loadId();
      if (ClientInstanceIdStore.isValid(id)) options.headers[headerName] = id;
    } catch (_) {
      // The backend supports old clients without this header (IP + UA fallback).
      // Storage failures must not prevent login or public browsing.
    }
    handler.next(options);
  }
}
