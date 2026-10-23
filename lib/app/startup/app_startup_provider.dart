import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config_controller.dart';
import '../i18n/app_i18n.dart';
import '../../features/my/presentation/providers/favorite_collection_status_providers.dart';
import '../../features/online/presentation/providers/online_providers.dart';

/// Only local configuration is required to open downloads and local music.
final appLocalStartupProvider = FutureProvider<void>((ref) async {
  await ref.read(appConfigProvider.notifier).waitUntilHydrated();
}, retry: (_, _) => null);

/// Online pages remain gated on usable platform metadata, fresh or cached.
final appStartupProvider = FutureProvider<void>((ref) async {
  await ref.read(appLocalStartupProvider.future);
  final apiBaseUrl = ref.read(appConfigProvider).apiBaseUrl.trim();
  if (apiBaseUrl.isEmpty) {
    final config = ref.read(appConfigProvider);
    throw StateError(AppI18n.t(config, 'startup.config_missing'));
  }
  await ref.watch(onlinePlatformsProvider.future);
  final token = ref.read(appConfigProvider).authToken?.trim() ?? '';
  if (token.isNotEmpty) {
    unawaited(
      ref
          .read(favoriteCollectionStatusProvider.notifier)
          .ensureReady()
          .catchError((Object _, StackTrace _) {
            // Collection pages own their retry UI; this is optional preloading.
          }),
    );
  }
}, retry: (_, _) => null);
