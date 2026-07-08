import 'dart:convert';

import 'package:flutter/services.dart';

class AppEnvironment {
  AppEnvironment._();

  static String _apiBaseUrl = '';
  static String _githubOwner = '';
  static String _githubRepo = '';

  static String get apiBaseUrl => _apiBaseUrl;
  static String get githubOwner => _githubOwner;
  static String get githubRepo => _githubRepo;

  static bool get hasApiBaseUrl => _apiBaseUrl.trim().isNotEmpty;
  static bool get hasGitHubReleaseConfig =>
      _githubOwner.trim().isNotEmpty && _githubRepo.trim().isNotEmpty;

  static Future<void> initialize() async {
    final raw = await rootBundle.loadString('assets/app_config.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('assets/app_config.json 格式不正确');
    }
    final map = decoded.map(
      (dynamic key, dynamic value) => MapEntry('$key', value),
    );
    final apiBaseUrl = '${map['api_base_url'] ?? ''}'.trim();
    if (apiBaseUrl.isEmpty) {
      throw const FormatException('assets/app_config.json 缺少 api_base_url');
    }
    final githubOwner = '${map['github_owner'] ?? ''}'.trim();
    final githubRepo = '${map['github_repo'] ?? ''}'.trim();
    _apiBaseUrl = apiBaseUrl;
    _githubOwner = githubOwner;
    _githubRepo = githubRepo;
  }
}
