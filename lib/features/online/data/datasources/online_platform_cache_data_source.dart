import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/online_platform.dart';

const _storageKey = 'online_platform_snapshot_v1';

/// Platform capabilities belong to one server and credential. Only a completely
/// parsed, non-empty response may replace the last usable snapshot.
class OnlinePlatformCacheDataSource {
  const OnlinePlatformCacheDataSource();

  static String scopeFor(String baseUrl, String? authToken) => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            baseUrl.trim().replaceAll(RegExp(r'/+$'), ''),
            authToken?.trim() ?? '',
          ]),
        ),
      )
      .toString();

  Future<List<OnlinePlatform>?> read(String scope) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map || json['schema'] != 1 || json['scope'] != scope) {
        return null;
      }
      final items = json['platforms'];
      if (items is! List || items.isEmpty) return null;
      final platforms = <OnlinePlatform>[];
      for (final item in items) {
        if (item is! Map ||
            item['status'] is! int ||
            item['image_sizes'] is! List ||
            item['qualities'] is! List ||
            BigInt.tryParse('${item['feature_support_flag']}') == null) {
          return null;
        }
        platforms.add(OnlinePlatform.fromMap(Map<String, dynamic>.from(item)));
      }
      if (platforms.map((platform) => platform.id).toSet().length !=
          platforms.length) {
        return null;
      }
      return List.unmodifiable(platforms);
    } catch (_) {
      // Missing, corrupt or unavailable local storage never prevents a request.
      return null;
    }
  }

  Future<void> write(String scope, List<OnlinePlatform> platforms) async {
    if (platforms.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKey,
        jsonEncode({
          'schema': 1,
          'scope': scope,
          'platforms': [
            for (final platform in platforms)
              {
                'id': platform.id,
                'name': platform.name,
                'shortname': platform.shortName,
                'status': platform.status,
                'feature_support_flag': platform.featureSupportFlag.toString(),
                'image_sizes': platform.imageSizes,
                'qualities': [
                  for (final quality in platform.qualities.entries)
                    {'name': quality.key, 'description': quality.value},
                ],
              },
          ],
        }),
      );
    } catch (_) {
      // Persistence is best-effort; fresh server data remains usable.
    }
  }

  Future<void> clear(String scope) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;
      final json = jsonDecode(raw);
      if (json is Map && json['scope'] == scope) {
        await prefs.remove(_storageKey);
      }
    } catch (_) {
      // Clearing an obsolete snapshot is best-effort.
    }
  }
}
