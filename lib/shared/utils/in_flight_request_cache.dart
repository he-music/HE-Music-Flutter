/// 合并相同 key 的并发请求；请求完成后立即释放，不缓存结果。
class InFlightRequestCache<K, V> {
  final Map<K, Future<V>> _requests = <K, Future<V>>{};

  Future<V> run(K key, Future<V> Function() createRequest) {
    return _requests[key] ??= _run(key, createRequest);
  }

  Future<V> _run(K key, Future<V> Function() createRequest) async {
    try {
      return await createRequest();
    } finally {
      _requests.remove(key);
    }
  }
}
