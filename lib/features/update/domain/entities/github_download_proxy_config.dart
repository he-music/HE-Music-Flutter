import 'dart:convert';

class GitHubDownloadProxy {
  const GitHubDownloadProxy({
    required this.id,
    required this.name,
    required this.urlPrefix,
    required this.enabled,
  });

  final String id;
  final String name;
  final String urlPrefix;
  final bool enabled;

  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'name': name,
    'url_prefix': urlPrefix,
    'enabled': enabled,
  };
}

class GitHubDownloadProxyConfig {
  GitHubDownloadProxyConfig({
    required this.schemaVersion,
    required this.revision,
    required this.defaultProxyId,
    required List<GitHubDownloadProxy> proxies,
  }) : proxies = List<GitHubDownloadProxy>.unmodifiable(proxies);

  static const supportedSchemaVersion = 1;

  final int schemaVersion;
  final int revision;
  final String? defaultProxyId;
  final List<GitHubDownloadProxy> proxies;

  List<GitHubDownloadProxy> get enabledProxies =>
      proxies.where((proxy) => proxy.enabled).toList(growable: false);

  GitHubDownloadProxy? resolveProxy(String? selectedId) {
    final normalizedSelectedId = selectedId?.trim() ?? '';
    if (normalizedSelectedId.isNotEmpty) {
      for (final proxy in proxies) {
        if (proxy.enabled && proxy.id == normalizedSelectedId) {
          return proxy;
        }
      }
    }
    final normalizedDefaultId = defaultProxyId?.trim() ?? '';
    if (normalizedDefaultId.isNotEmpty) {
      for (final proxy in proxies) {
        if (proxy.enabled && proxy.id == normalizedDefaultId) {
          return proxy;
        }
      }
    }
    for (final proxy in proxies) {
      if (proxy.enabled) {
        return proxy;
      }
    }
    return null;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schema_version': schemaVersion,
    'revision': revision,
    'default_proxy_id': defaultProxyId,
    'proxies': proxies.map((proxy) => proxy.toJson()).toList(growable: false),
  };

  factory GitHubDownloadProxyConfig.fromJsonString(String source) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('加速服务配置不是有效的 JSON。');
    }
    return GitHubDownloadProxyConfig.fromJson(decoded);
  }

  factory GitHubDownloadProxyConfig.fromJson(Object? source) {
    final map = _readStringMap(source, '加速服务配置格式不正确。');
    final schemaVersion = map['schema_version'];
    if (schemaVersion is! int || schemaVersion != supportedSchemaVersion) {
      throw const FormatException('不支持的加速服务配置版本。');
    }
    final revision = map['revision'];
    if (revision is! int || revision <= 0) {
      throw const FormatException('加速服务配置 revision 必须是正整数。');
    }
    final rawProxies = map['proxies'];
    if (rawProxies is! List) {
      throw const FormatException('加速服务列表格式不正确。');
    }
    final proxies = <GitHubDownloadProxy>[];
    final ids = <String>{};
    for (final rawProxy in rawProxies) {
      final proxyMap = _readStringMap(rawProxy, '加速服务格式不正确。');
      final id = _readRequiredString(proxyMap, 'id');
      final name = _readRequiredString(proxyMap, 'name');
      final urlPrefix = _normalizeUrlPrefix(
        _readRequiredString(proxyMap, 'url_prefix'),
      );
      final enabled = proxyMap['enabled'];
      if (enabled is! bool) {
        throw const FormatException('加速服务 enabled 必须是布尔值。');
      }
      if (!ids.add(id)) {
        throw FormatException('加速服务 id 重复：$id');
      }
      proxies.add(
        GitHubDownloadProxy(
          id: id,
          name: name,
          urlPrefix: urlPrefix,
          enabled: enabled,
        ),
      );
    }
    final rawDefaultProxyId = map['default_proxy_id'];
    if (rawDefaultProxyId != null && rawDefaultProxyId is! String) {
      throw const FormatException('default_proxy_id 必须是字符串。');
    }
    final normalizedDefaultProxyId = rawDefaultProxyId is String
        ? rawDefaultProxyId.trim()
        : '';
    return GitHubDownloadProxyConfig(
      schemaVersion: schemaVersion,
      revision: revision,
      defaultProxyId: normalizedDefaultProxyId.isEmpty
          ? null
          : normalizedDefaultProxyId,
      proxies: proxies,
    );
  }

  static Map<String, Object?> _readStringMap(
    Object? source,
    String errorMessage,
  ) {
    if (source is! Map) {
      throw FormatException(errorMessage);
    }
    return source.map<String, Object?>(
      (dynamic key, dynamic value) => MapEntry('$key', value),
    );
  }

  static String _readRequiredString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('加速服务缺少 $key。');
    }
    return value.trim();
  }

  static String _normalizeUrlPrefix(String value) {
    if (RegExp(r'\s').hasMatch(value)) {
      throw const FormatException('加速服务地址必须是有效的 HTTPS URL。');
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('加速服务地址必须是有效的 HTTPS URL。');
    }
    return value.endsWith('/') ? value : '$value/';
  }
}

class GitHubDownloadProxyConfigSnapshot {
  const GitHubDownloadProxyConfigSnapshot({
    required this.config,
    this.refreshedAt,
  });

  final GitHubDownloadProxyConfig config;
  final DateTime? refreshedAt;

  String toCacheJsonString() {
    final refreshedAt = this.refreshedAt;
    if (refreshedAt == null) {
      throw StateError('缓存配置必须包含刷新时间。');
    }
    return jsonEncode(<String, Object>{
      'refreshed_at': refreshedAt.toUtc().toIso8601String(),
      'config': config.toJson(),
    });
  }

  factory GitHubDownloadProxyConfigSnapshot.fromCacheJsonString(String source) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('加速服务缓存不是有效的 JSON。');
    }
    final map = GitHubDownloadProxyConfig._readStringMap(
      decoded,
      '加速服务缓存格式不正确。',
    );
    final rawRefreshedAt = map['refreshed_at'];
    if (rawRefreshedAt is! String) {
      throw const FormatException('加速服务缓存缺少刷新时间。');
    }
    final refreshedAt = DateTime.tryParse(rawRefreshedAt);
    if (refreshedAt == null) {
      throw const FormatException('加速服务缓存刷新时间无效。');
    }
    return GitHubDownloadProxyConfigSnapshot(
      config: GitHubDownloadProxyConfig.fromJson(map['config']),
      refreshedAt: refreshedAt,
    );
  }
}
