// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:he_music_flutter/app/app_navigation_service.dart';
import 'package:he_music_flutter/app/bootstrap.dart';
import 'package:he_music_flutter/app/audio_cache_simulator_guard.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_data_source.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_environment.dart';
import 'package:he_music_flutter/app/config/app_online_audio_quality.dart';
import 'package:he_music_flutter/app/config/app_theme_mode.dart';
import 'package:he_music_flutter/app/router/app_route_observers.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_boundary.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_disk_capacity_port.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_provider.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_runtime.dart';
import 'package:he_music_flutter/core/audio/cache/file_audio_cache_store.dart';
import 'package:he_music_flutter/core/audio/he_audio_handler.dart';
import 'package:he_music_flutter/core/network/api_dio_provider.dart';
import 'package:he_music_flutter/core/network/network_status_port.dart';
import 'package:he_music_flutter/features/download/presentation/providers/download_providers.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_queue_snapshot.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_track.dart';
import 'package:he_music_flutter/features/player/presentation/pages/player_page.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_audio_provider.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_playback_api_provider.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_providers.dart';
import 'package:he_music_flutter/features/player/presentation/providers/player_queue_provider.dart';
import 'package:he_music_flutter/features/settings/domain/settings_catalog.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/settings_page.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

import 'support/cache_ui_fixture.dart';

String get _owned => 'cache_ui.$_run.initialized';
String get _offline => 'cache_ui.$_run.injected_offline';
bool _simulator = false;
String get _run => _simulator ? 'sim1' : 'ui1';
const _external = String.fromEnvironment('AUDIO_CACHE_UI_ORIGIN');
int _errors = 0;

void _safeError() {
  _errors++;
  debugPrint('AUDIO_CACHE_UI {"event":"error","detail":"suppressed"}');
}

void main() => runCacheUiHarness();

void runCacheUiHarness({bool debugIosSimulator = false}) {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    _simulator = debugIosSimulator;
    final info = await PackageInfo.fromPlatform();
    if (_simulator) {
      await requireAudioCacheDebugSimulator();
      if (info.packageName != audioCacheSimulatorBundle ||
          _external.isNotEmpty) {
        throw StateError('simulator_isolation_guard');
      }
    } else if (!cacheUiIsolationAllowed(
      release: kReleaseMode,
      supportedPlatform: Platform.isAndroid || Platform.isMacOS,
      packageName: info.packageName,
    )) {
      throw StateError('release_isolation_guard');
    }
    // No app-owned write or bootstrap can precede the exact runtime guard.
    final external = _external.isEmpty ? null : cacheUiOrigin(_external);
    FlutterError.onError = (_) => _safeError();
    ErrorWidget.builder = (_) =>
        const Center(child: Text('Validation UI error'));
    final prefs = await SharedPreferences.getInstance();
    await AppEnvironment.initialize();
    if (prefs.getBool(_owned) != true) {
      if (prefs.getKeys().isNotEmpty) throw StateError('unowned_preferences');
      await const AppConfigDataSource().save(
        AppConfigState.initial.copyWith(
          clearToken: true,
          clearRefreshToken: true,
          enableDesktopLyric: false,
          enableDesktopLyricLock: false,
          autoCheckUpdates: false,
          enablePlaybackAudioCache: true,
          enableCellularAudioCache: false,
          wifiOnlineAudioQualityPreference: AppOnlineAudioQuality.mp3320,
          cellularOnlineAudioQualityPreference: AppOnlineAudioQuality.mp3320,
        ),
      );
      if (!await prefs.setBool(_owned, true)) {
        throw StateError('ownership_write');
      }
    }
    final config = await const AppConfigDataSource().load();
    if (config.authToken != null ||
        config.refreshToken != null ||
        config.enableDesktopLyric ||
        config.enableDesktopLyricLock) {
      throw StateError('unsupported_validation_config');
    }
    final prior = await const PlayerQueueDataSource().readQueue();
    _guardQueue(prior);
    final cache = await getApplicationCacheDirectory();
    final root = await Directory(
      '${cache.path}/native-ui-validation/$_run',
    ).create(recursive: true);
    final fixture = CacheUiFixture(
      root,
      CacheUiNetwork(offline: prefs.getBool(_offline) ?? false),
      external: external,
    );
    await fixture.initialize();
    final session = _Session(fixture, prior);
    await bootstrap(
      debugIosSimulatorCache: _simulator,
      createAudioCacheStore: () => FileAudioCacheStore(
        capacity: const MethodChannelAudioCacheDiskCapacityPort(),
        applicationCacheDirectory: () async => root,
      ),
      createAudioHandler: (config, runtime) => HeAudioHandler(
        initialConfig: config,
        audioCacheRuntime: runtime,
        networkStatusPort: fixture.network,
        fetchSongUrlOverride: fixture.resolve,
        fetchLyricsOverride: ({required trackId, platform, localPath}) async =>
            const LyricDocument.empty(),
        logOverride: (_) {},
      ),
      createApp: (config, runtime) {
        if (runtime == null) throw StateError('runtime_unavailable');
        session.runtime = runtime;
        // One independent provider container avoids inherited-scope resolution
        // escaping the fixture API overrides. Audio/config stores stay real.
        final container = ProviderContainer(
          overrides: [
            bootstrapAppConfigProvider.overrideWithValue(config),
            audioCacheRuntimeProvider.overrideWithValue(runtime),
            onlinePlatformsProvider.overrideWith(_Platforms.new),
            apiDioProvider.overrideWith(
              (_) => throw StateError('backend_disabled'),
            ),
            playerPlaybackApiClientProvider.overrideWith(
              (_) => throw StateError('backend_disabled'),
            ),
            downloadControllerProvider.overrideWith(
              () => throw StateError('downloads_disabled'),
            ),
          ],
        );
        return UncontrolledProviderScope(
          container: container,
          child: _App(session),
        );
      },
    );
  }, (_, _) => _safeError());
}

void _guardQueue(PlayerQueueSnapshot? snapshot) {
  if (snapshot == null) return;
  if (snapshot.isRadioMode) throw StateError('unowned_queue');
  for (final track in snapshot.queue) {
    if (track.platform != 'fixture' ||
        !{'ui1_a', 'ui1_b', 'ui1_c'}.contains(track.id) ||
        track.path != null ||
        track.artworkUrl != null ||
        track.artworkBytes != null ||
        track.artists.isNotEmpty ||
        track.artist != null) {
      throw StateError('unowned_queue');
    }
  }
  _guardQueue(snapshot.previousSnapshot);
}

class _Platforms extends OnlinePlatformsController {
  static final items = [
    OnlinePlatform(
      id: 'fixture',
      name: 'Fixture',
      shortName: 'Fixture',
      status: 1,
      featureSupportFlag: BigInt.zero,
      qualities: const {'fixture-128': '128 WAV', 'fixture-320': '320 WAV'},
    ),
  ];
  @override
  Future<List<OnlinePlatform>> build() async => items;
  @override
  Future<List<OnlinePlatform>> ensureLoaded({
    bool forceRefresh = false,
  }) async => items;
  @override
  Future<void> refresh() async {}
}

Map<String, Object?> _configEvidence(AppConfigState config) => {
  'enabled': config.enablePlaybackAudioCache,
  'cellular': config.enableCellularAudioCache,
  'limit': config.audioCacheLimitBytes,
  'wifiQuality': config.wifiOnlineAudioQualityPreference.value,
  'cellularQuality': config.cellularOnlineAudioQualityPreference.value,
  'lastSelected': config.lastSelectedOnlineAudioQualityName,
};

class _Session {
  _Session(this.fixture, this.prior)
    : launchResolverCalls = fixture.resolverCalls;
  final CacheUiFixture fixture;
  final PlayerQueueSnapshot? prior;
  final int launchResolverCalls;
  late AudioCacheRuntime runtime;
  bool ready = false;
  bool seeded = false;
  int transitionErrors = 0;
  final launch = DateTime.now().microsecondsSinceEpoch;
  int snapshotNumber = 0;

  Future<void> initialize(WidgetRef ref) async {
    await ref.read(appConfigProvider.notifier).waitUntilHydrated();
    await ref.read(onlinePlatformsProvider.future);
    globalHeAudioHandler.customEvent.listen((event) {
      if (event is Map && event['type'] == 'playbackTransitionError') {
        transitionErrors++;
      }
    });
    await ref.read(playerControllerProvider.notifier).initialize();
    ready = true;
  }

  Future<String> save(WidgetRef ref) async {
    final memoryConfig = _configEvidence(ref.read(appConfigProvider));
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final diskConfig = _configEvidence(
      await const AppConfigDataSource().load(),
    );
    final persistedQueue = await const PlayerQueueDataSource().readQueue();
    final player = ref.read(playerControllerProvider);
    final cache = runtime.snapshot;
    final handler = globalHeAudioHandler;
    final marker = '$launch-${++snapshotNumber}';
    final evidence = <String, Object?>{
      'marker': marker,
      'run': _run,
      if (_simulator) 'environment': 'Debug Simulator',
      if (_simulator) 'bundle': audioCacheSimulatorBundle,
      if (_simulator) 'iosReleaseCapability': false,
      'launch': launch,
      'ready': ready,
      'restorationReady':
          ready &&
          !seeded &&
          prior != null &&
          prior!.queue.isNotEmpty &&
          listEquals(
            player.queue.map((t) => t.id).toList(),
            prior!.queue.map((t) => t.id).toList(),
          ) &&
          player.currentIndex == prior!.currentIndex &&
          !player.isLoading &&
          player.playbackFailure == null &&
          handler.mediaItem.value?.id == player.currentTrack?.id &&
          handler.currentSourceKindForTesting != null,
      'seededThisProcess': seeded,
      'priorQueueCount': prior?.queue.length ?? 0,
      'priorIndex': prior?.currentIndex,
      'queueCount': player.queue.length,
      'queueIndex': player.currentIndex,
      'persistedQueueCount': persistedQueue?.queue.length ?? 0,
      'persistedQueueIndex': persistedQueue?.currentIndex,
      'queueMatchesDisk':
          listEquals(
            player.queue.map((t) => t.id).toList(),
            persistedQueue?.queue.map((t) => t.id).toList(),
          ) &&
          player.currentIndex == persistedQueue?.currentIndex,
      'source': handler.currentSourceKindForTesting?.name,
      'generation': handler.currentSourceGenerationForTesting,
      'needsReload': handler.currentSourceNeedsReloadForTesting,
      'requiresNetwork': handler.currentSourceRequiresNetworkForTesting,
      'actualCacheQuality': handler.currentCacheKeyForTesting?.quality,
      'committedBitrate': player.currentTrack?.bitrate,
      'committedFormat': player.currentTrack?.format,
      'selectedLabel': player.currentSelectedQualityName,
      'playing': player.isPlaying,
      'loading': player.isLoading,
      'positionMs': player.position.inMilliseconds,
      'publishedBytes': cache.publishedBytes,
      'managedBytes': cache.managedFootprintBytes,
      'entries': cache.entryCount,
      'leases': cache.activeLeaseCount,
      'clearEpoch': cache.clearEpoch,
      'readHealth': cache.readHealth.name,
      'writeHealth': cache.writeHealth.name,
      'memoryConfig': memoryConfig,
      'persistedConfig': diskConfig,
      'configMatchesDisk': mapEquals(memoryConfig, diskConfig),
      'runtimePolicyEnabled': runtime.policy.enabled,
      'resolverTotal': fixture.resolverCalls,
      'resolverAtLaunch': launchResolverCalls,
      'resolverDeltaSinceLaunch': fixture.resolverCalls - launchResolverCalls,
      'injectedNetwork': fixture.network.lastKnown.name,
      'physicalOfflineVerified': false,
      'externalOriginConfigured': _external.isNotEmpty,
      'transitionErrors': transitionErrors,
      'uncaughtErrors': _errors,
    };
    final file = File('${fixture.root.path}/snapshot-$marker.json');
    await file.writeAsString(jsonEncode(evidence), flush: true);
    debugPrint(
      'AUDIO_CACHE_UI ${jsonEncode({'event': 'snapshot_saved', 'marker': marker})}',
    );
    for (final entry in evidence.entries) {
      debugPrint(
        'AUDIO_CACHE_UI ${jsonEncode({'marker': marker, entry.key: entry.value})}',
      );
    }
    return const JsonEncoder.withIndent('  ').convert(evidence);
  }
}

class _App extends ConsumerStatefulWidget {
  const _App(this.session);
  final _Session session;
  @override
  ConsumerState<_App> createState() => _AppState();
}

class _AppState extends ConsumerState<_App> {
  late final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    observers: [appPageRouteObserver],
    routes: [
      GoRoute(path: '/', builder: (_, _) => _Controls(widget.session)),
      GoRoute(
        path: '/settings',
        builder: (_, _) =>
            const SettingsPage(sectionId: SettingsSectionIds.playback),
      ),
      GoRoute(
        path: '/player',
        builder: (_, _) => const AppPlayerStyleBoundary(child: PlayerPage()),
      ),
    ],
    errorBuilder: (_, _) =>
        const Scaffold(body: Center(child: Text('Route unavailable'))),
  );
  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(
      appConfigProvider.select(
        (s) => (
          s.themeAccent,
          s.skinId,
          s.themeMode,
          s.localeCode,
          s.showContentBackground,
        ),
      ),
    );
    final skin = AppSkinRegistry.builtIn(appearance.$1).resolve(appearance.$2);
    return MaterialApp.router(
      title: _simulator ? 'HE-Music Debug Simulator' : 'HE-Music Cache UI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(skin, showContentBackground: appearance.$5),
      darkTheme: AppTheme.dark(skin, showContentBackground: appearance.$5),
      themeMode: switch (appearance.$3) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      locale: appearance.$4 == 'system' ? null : Locale(appearance.$4),
      supportedLocales: const [Locale('zh'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
    );
  }
}

class _Controls extends ConsumerStatefulWidget {
  const _Controls(this.session);
  final _Session session;
  @override
  ConsumerState<_Controls> createState() => _ControlsState();
}

class _ControlsState extends ConsumerState<_Controls> {
  bool busy = false;
  bool blocked = false;
  String status = 'Initializing';
  String report = '';
  _Session get session => widget.session;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!session.ready) {
        unawaited(_action(() => session.initialize(ref)));
      } else {
        setState(() => status = 'Ready');
      }
    });
  }

  Future<void> _action(Future<void> Function() work) async {
    setState(() {
      busy = true;
      status = 'Running';
    });
    try {
      await work().timeout(const Duration(seconds: 45));
      if (mounted) {
        setState(() => status = session.ready ? 'Ready' : 'Not ready');
      }
    } catch (_) {
      // Timeout does not cancel native work. Do not permit a second mutation.
      blocked = true;
      _safeError();
      if (mounted) setState(() => status = 'Failed; evidence required');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _seed() async {
    if (session.prior != null ||
        ref.read(playerControllerProvider).queue.isNotEmpty ||
        session.seeded) {
      throw StateError('seed_requires_empty_queue');
    }
    session.seeded = true;
    await ref.read(playerControllerProvider.notifier).replaceQueue([
      for (final id in (_simulator ? ['ui1_a'] : ['ui1_a', 'ui1_b', 'ui1_c']))
        PlayerTrack(
          id: id,
          title: 'Fixture $id',
          platform: 'fixture',
          links: [
            for (final quality in [128, 320])
              LinkInfo(
                name: 'fixture-$quality',
                quality: quality,
                format: 'wav',
                size: '2646044',
                url: '',
              ),
          ],
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !busy && !blocked && session.ready;
    final offline =
        session.fixture.network.lastKnown == NetworkConnectionType.offline;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _simulator ? 'Debug Simulator / sim1' : 'HE-Music Cache UI / ui1',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(status),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: enabled ? () => context.push('/settings') : null,
                icon: const Icon(Icons.settings),
                label: const Text('Playback settings'),
              ),
              FilledButton.icon(
                onPressed: enabled ? () => context.push('/player') : null,
                icon: const Icon(Icons.music_note),
                label: const Text('Player'),
              ),
              OutlinedButton.icon(
                onPressed: enabled && !session.seeded && session.prior == null
                    ? () => _action(_seed)
                    : null,
                icon: const Icon(Icons.queue_music),
                label: const Text('Seed queue once'),
              ),
              OutlinedButton.icon(
                onPressed: enabled
                    ? () => _action(
                        () => ref.read(audioPlayerPortProvider).stop(),
                      )
                    : null,
                icon: const Icon(Icons.stop),
                label: const Text('Stop source'),
              ),
              OutlinedButton.icon(
                onPressed: enabled
                    ? () => _action(() async {
                        final state = ref.read(playerControllerProvider);
                        if (state.queue.isEmpty) {
                          throw StateError('queue_empty');
                        }
                        await ref
                            .read(playerControllerProvider.notifier)
                            .playAt(state.currentIndex);
                      })
                    : null,
                icon: const Icon(Icons.replay),
                label: const Text('Reload current'),
              ),
              OutlinedButton.icon(
                onPressed: !busy
                    ? () => _action(() async {
                        final next = await session.save(ref);
                        if (mounted) setState(() => report = next);
                      })
                    : null,
                icon: const Icon(Icons.save),
                label: const Text('Save snapshot'),
              ),
            ],
          ),
          SwitchListTile(
            title: const Text('Injected offline (persistent)'),
            value: offline,
            onChanged: enabled
                ? (value) => _action(() async {
                    final prefs = await SharedPreferences.getInstance();
                    if (!await prefs.setBool(_offline, value)) {
                      throw StateError('network_mode_write');
                    }
                    if (!value) await session.fixture.online();
                    session.fixture.network.setOffline(value);
                  })
                : null,
          ),
          if (report.isNotEmpty)
            SelectableText(
              report,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
        ],
      ),
    );
  }
}
