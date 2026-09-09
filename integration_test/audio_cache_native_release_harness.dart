// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:he_music_flutter/app/bootstrap.dart';
import 'package:he_music_flutter/app/config/app_config_data_source.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/core/audio/audio_track.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_disk_capacity_port.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_entry.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_policy.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_runtime.dart';
import 'package:he_music_flutter/core/audio/cache/audio_cache_source_plan.dart';
import 'package:he_music_flutter/core/audio/cache/file_audio_cache_store.dart';
import 'package:he_music_flutter/core/audio/he_audio_handler.dart';
import 'package:he_music_flutter/core/network/network_status_port.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

import 'support/cache_harness_origin.dart';

const _bundle = 'com.hemusic.music.flutter.cacheharness';
const _run = String.fromEnvironment(
  'AUDIO_CACHE_HARNESS_RUN',
  defaultValue: 'run1',
);
const _external = String.fromEnvironment('AUDIO_CACHE_HARNESS_ORIGIN');
int _uncaughtErrors = 0;

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      final info = await PackageInfo.fromPlatform();
      if (!kReleaseMode ||
          !(Platform.isAndroid || Platform.isMacOS) ||
          info.packageName != _bundle ||
          !RegExp(r'^[a-z0-9_-]{1,32}$').hasMatch(_run)) {
        throw StateError('isolation_or_release_guard');
      }
      final cache = await getApplicationCacheDirectory();
      final root = await Directory(
        '${cache.path}/native-release-harness/$_run',
      ).create(recursive: true);
      final runner = _Runner(root);
      await runner.initialize();
      const capacity = MethodChannelAudioCacheDiskCapacityPort();
      await bootstrap(
        dataSource: const _FixtureConfig(),
        createAudioCacheStore: () => FileAudioCacheStore(
          capacity: capacity,
          applicationCacheDirectory: () async => root,
        ),
        createAudioHandler: (config, runtime) => HeAudioHandler(
          initialConfig: config,
          audioCacheRuntime: runtime,
          configDataSourceOverride: const _FixtureConfig(),
          networkStatusPort: runner.network,
          fetchSongUrlOverride: runner.resolve,
          fetchLyricsOverride:
              ({required trackId, platform, localPath}) async =>
                  const LyricDocument.empty(),
          logOverride: (_) {},
        ),
        createApp: (_, runtime) {
          runner.runtime = runtime!;
          return MaterialApp(home: _HarnessPage(runner));
        },
      );
    },
    (_, _) {
      _uncaughtErrors++;
      // Never print exception/stack: native exceptions may embed source URLs.
      debugPrint(
        'AUDIO_CACHE_HARNESS {"status":"failed","check":"uncaught_or_bootstrap"}',
      );
    },
  );
}

class _FixtureConfig extends AppConfigDataSource {
  const _FixtureConfig();
  @override
  Future<AppConfigState> load() async => AppConfigState.initial.copyWith(
    clearToken: true,
    clearRefreshToken: true,
    enableDesktopLyric: false,
    enableDesktopLyricLock: false,
    enablePlaybackAudioCache: true,
    enableCellularAudioCache: false,
  );
  @override
  Future<void> save(AppConfigState state) async {
    throw StateError('fixture_config_is_read_only');
  }
}

class _Network implements NetworkStatusPort {
  NetworkConnectionType value = NetworkConnectionType.wifi;
  final controller = StreamController<NetworkConnectionType>.broadcast(
    sync: true,
  );
  void set(NetworkConnectionType next) {
    value = next;
    controller.add(next);
  }

  @override
  NetworkConnectionType get lastKnown => value;
  @override
  Future<NetworkConnectionType> current() async => value;
  @override
  Stream<NetworkConnectionType> get changes => controller.stream;
}

class _Runner {
  _Runner(this.root);
  final Directory root;
  final network = _Network();
  late AudioCacheRuntime runtime;
  CacheHarnessOrigin? origin;
  Uri? base;
  int resolverCalls = 0;
  Future<void> counterWrites = Future.value();
  bool seededThisProcess = false;
  final checks = <String>[];
  String lastCheck = 'initialization';
  int transitionErrors = 0;
  final rapidSettled = <String, bool>{};
  bool observing = false;
  HeAudioHandler get handler => globalHeAudioHandler;
  File get counterFile => File('${root.path}/resolver-count.json');
  File get seedFile => File('${root.path}/seed.json');

  Future<void> initialize() async {
    if (await counterFile.exists()) {
      resolverCalls = jsonDecode(await counterFile.readAsString()) as int;
    }
    if (_external.isNotEmpty) {
      final uri = Uri.parse(_external);
      final address = InternetAddress.tryParse(uri.host);
      final second = int.tryParse(uri.host.split('.').elementAtOrNull(1) ?? '');
      final privateAddress =
          address != null &&
          (address.isLoopback ||
              uri.host.startsWith('10.') ||
              uri.host.startsWith('192.168.') ||
              (uri.host.startsWith('172.') &&
                  second != null &&
                  second >= 16 &&
                  second <= 31));
      if (uri.scheme != 'http' ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment ||
          (uri.path.isNotEmpty && uri.path != '/') ||
          !privateAddress) {
        throw StateError('fixture_origin_guard');
      }
      base = uri;
    }
  }

  Future<void> onlineOrigin() async {
    network.set(NetworkConnectionType.wifi);
    if (base != null) return;
    origin = CacheHarnessOrigin(
      evidence: File('${root.path}/origin-counts.json'),
    );
    await origin!.start();
    base = origin!.base;
  }

  Future<Map<String, dynamic>> resolve({
    required String songId,
    required String platform,
    int? quality,
    String? format,
  }) async {
    resolverCalls++;
    final encodedCount = jsonEncode(resolverCalls);
    await (counterWrites = counterWrites.then((_) async {
      final temp = File('${counterFile.path}.tmp');
      await temp.writeAsString(encodedCount, flush: true);
      await temp.rename(counterFile.path);
    }));
    if (network.value == NetworkConnectionType.offline || base == null) {
      throw StateError('offline_resolver_attempt');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(base!.resolve('/resolve/$songId'));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode != 200) {
        throw StateError('fixture_resolver_status');
      }
      final payload =
          jsonDecode(await utf8.decoder.bind(response).join())
              as Map<String, dynamic>;
      if (payload['path'] != '/audio/$songId' ||
          !{'wav', 'mp3'}.contains(payload['format'])) {
        throw StateError('fixture_resolver_payload');
      }
      return {
        'url': base!.resolve(payload['path'] as String).toString(),
        'format': payload['format'],
      };
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, int>> originCounts() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(base!.resolve('/stats'));
      request.followRedirects = false;
      final response = await request.close().timeout(
        const Duration(seconds: 5),
      );
      if (response.statusCode != 200) throw StateError('stats_status');
      final decoded =
          jsonDecode(
                await utf8.decoder
                    .bind(response)
                    .join()
                    .timeout(const Duration(seconds: 5)),
              )
              as Map<String, dynamic>;
      return {
        for (final key in [
          'resolver',
          'origin',
          'range',
          'completed',
          'aborted',
          'injected',
        ])
          key: decoded[key] as int,
      };
    } finally {
      client.close(force: true);
    }
  }

  Future<void> waitOriginCount(String key, int baseline) async {
    lastCheck = 'origin_$key';
    final deadline = DateTime.now().add(const Duration(seconds: 45));
    while ((await originCounts())[key]! <= baseline) {
      if (DateTime.now().isAfter(deadline)) throw StateError(lastCheck);
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    checks.add(lastCheck);
  }

  AudioTrack track(String id, {int quality = 320}) => AudioTrack(
    id: id,
    title: 'Fixture $id',
    url: '',
    platform: 'fixture',
    links: [
      LinkInfo(
        name: 'fixture-$quality',
        quality: quality,
        format: 'wav',
        size: '2646044',
        url: '',
      ),
    ],
  );

  void check(bool success, String name) {
    lastCheck = name;
    if (!success) throw StateError(name);
    checks.add(name);
  }

  Future<void> waitFor(
    bool Function() predicate,
    String name, {
    int seconds = 45,
  }) async {
    lastCheck = name;
    final end = DateTime.now().add(Duration(seconds: seconds));
    while (!predicate()) {
      if (DateTime.now().isAfter(end)) throw StateError(name);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    checks.add(name);
  }

  Future<void> load(String id, {int quality = 320}) async {
    lastCheck = 'load_$id';
    await handler
        .setQueueData([track(id, quality: quality)], forceReloadCurrent: true)
        .timeout(const Duration(seconds: 35));
    check(handler.mediaItem.value?.id == id, 'commit_$id');
  }

  Future<void> advances() async {
    lastCheck = 'native_position_advances';
    await handler.play();
    final start = await handler.positionStream.first;
    await handler.positionStream
        .firstWhere(
          (position) => position > start + const Duration(milliseconds: 400),
        )
        .timeout(const Duration(seconds: 12));
    checks.add(lastCheck);
  }

  Future<int> parts() async {
    var count = 0;
    await for (final file in root.list(recursive: true, followLinks: false)) {
      if (file is File && file.path.endsWith('.part')) count++;
    }
    return count;
  }

  Future<void> run(String phase) async {
    checks.clear();
    final before = resolverCalls;
    final errorsBefore = transitionErrors;
    var status = 'failed';
    String? failureType;
    rapidSettled.clear();
    Map<String, int>? countsBefore;
    Map<String, int>? countsAfter;
    if (!observing) {
      observing = true;
      handler.customEvent.listen((event) {
        if (event is Map && event['type'] == 'playbackTransitionError') {
          transitionErrors++;
        }
      });
    }
    try {
      await runtime.store.initialize();
      check(
        runtime.readHealth == AudioCacheReadHealth.ready,
        'real_store_ready',
      );
      final capacity = await const MethodChannelAudioCacheDiskCapacityPort()
          .availableBytes(root.path);
      check(capacity != null && capacity >= 0, 'native_capacity_fresh');
      if (phase == 'offline' || phase == 'offline-quality') {
        check(
          !seededThisProcess && await seedFile.exists(),
          'prior_process_seed_required',
        );
        final seed =
            jsonDecode(await seedFile.readAsString()) as Map<String, dynamic>;
        check(seed['resolverCalls'] == resolverCalls, 'seed_resolver_baseline');
        check(
          seed['trackId'] == 'seed' &&
              seed['platform'] == 'fixture' &&
              seed['format'] == 'wav',
          'persisted_fixture_reference',
        );
        network.set(NetworkConnectionType.offline);
        await load(
          seed['trackId'] as String,
          quality: phase == 'offline-quality' ? 128 : 320,
        );
        check(
          handler.currentSourceKindForTesting == AudioSourceKind.localCacheHit,
          'offline_cache_hit',
        );
        check(
          handler.currentCacheKeyForTesting?.quality == 320,
          'actual_cached_quality',
        );
        await advances();
        await handler.pause();
        check(resolverCalls == before, 'zero_resolver_calls');
      } else {
        await onlineOrigin();
        countsBefore = await originCounts();
        // Only the isolated fixture store is cleared, never application data.
        await handler.setQueueData([]);
        await runtime.clear();
        await runtime.updatePolicy(const AudioCachePolicy());
        if (phase == 'seed') {
          await load('seed');
          check(
            handler.currentSourceKindForTesting ==
                AudioSourceKind.cachingRemote,
            'first_streaming_write',
          );
          check(await parts() > 0, 'partial_file_while_streaming');
          await advances();
          await waitFor(
            () => runtime.snapshot.entryCount == 1,
            'complete_published',
          );
          await handler.pause();
          check(transitionErrors == errorsBefore, 'no_transition_errors');
          await seedFile.writeAsString(
            jsonEncode({
              'resolverCalls': resolverCalls,
              'version': 1,
              'trackId': 'seed',
              'platform': 'fixture',
              'format': 'wav',
              'quality': 320,
            }),
            flush: true,
          );
          seededThisProcess = true;
        } else if (phase == 'lifecycle') {
          await lifecycle();
        } else if (phase == 'policy') {
          await policyLifecycle();
        } else if (phase == 'fft') {
          await fftCoexistence();
        } else if (phase == 'mismatch') {
          final completedBefore = (await originCounts())['completed']!;
          await load('mismatch');
          await advances();
          await handler.pause();
          await waitOriginCount('completed', completedBefore);
          check(runtime.snapshot.entryCount == 0, 'mismatch_not_published');
          await handler.setQueueData([]);
          check(await parts() == 0, 'mismatch_partial_cleanup');
        } else if ({'reject', 'truncate', 'disconnect'}.contains(phase)) {
          final injectedBefore = (await originCounts())['injected']!;
          try {
            await load(phase);
            await advances();
          } catch (_) {
            /* Expected native failure, recorded below. */
          }
          await waitOriginCount('injected', injectedBefore);
          await handler.setQueueData([]);
          check(resolverCalls > before, 'failure_resolver_exercised');
          check(runtime.snapshot.entryCount == 0, 'failure_not_published');
          check(await parts() == 0, 'failure_partial_cleanup');
        } else {
          throw StateError('unknown_phase');
        }
        countsAfter = await originCounts();
      }
      if (!{'reject', 'truncate', 'disconnect'}.contains(phase)) {
        check(transitionErrors == errorsBefore, 'no_phase_transition_errors');
      }
      check(_uncaughtErrors == 0, 'no_uncaught_errors');
      status = 'passed';
    } catch (error) {
      failureType = error is TimeoutException ? 'timeout' : 'check_or_native';
      // Never include native exception contents in the report.
    } finally {
      final report = <String, Object?>{
        'phase': phase,
        'status': status,
        'lastCheck': lastCheck,
        'failureType': failureType,
        'rapidSettled': Map.of(rapidSettled),
        'sourceKind': handler.currentSourceKindForTesting?.name,
        'sourceGeneration': handler.currentSourceGenerationForTesting,
        'checks': List.of(checks),
        'platform': Platform.operatingSystem,
        'release': kReleaseMode,
        'resolverDelta': resolverCalls - before,
        'resolverTotal': resolverCalls,
        'originMode': _external.isEmpty ? 'app-local' : 'external',
        'originCountsBefore': countsBefore,
        'originCountsAfter': countsAfter,
        'originCounts': origin == null ? null : Map.of(origin!.counts),
        'entries': runtime.snapshot.entryCount,
        'publishedBytes': runtime.snapshot.publishedBytes,
        'activeLeases': runtime.snapshot.activeLeaseCount,
        'transitionErrors': transitionErrors - errorsBefore,
        'uncaughtErrors': _uncaughtErrors,
        'physicalOfflineVerified': false,
      };
      await File(
        '${root.path}/$phase-report.json',
      ).writeAsString(jsonEncode(report), flush: true);
      final summary = Map<String, Object?>.of(report)..remove('checks');
      summary.remove('rapidSettled');
      debugPrint('AUDIO_CACHE_HARNESS ${jsonEncode(summary)}');
      debugPrint('AUDIO_CACHE_HARNESS_RAPID ${jsonEncode(rapidSettled)}');
      for (final name in checks) {
        debugPrint(
          'AUDIO_CACHE_HARNESS_CHECK ${jsonEncode({'phase': phase, 'check': name})}',
        );
      }
    }
    if (status != 'passed') throw StateError(lastCheck);
  }

  Future<void> lifecycle() async {
    await load('lifecycle');
    check(
      handler.currentSourceKindForTesting == AudioSourceKind.cachingRemote,
      'lifecycle_caching',
    );
    await advances();
    await handler.seek(const Duration(seconds: 8));
    check(
      (await handler.positionStream.first) >= const Duration(seconds: 7),
      'seek_position',
    );
    await advances();
    final leaseCount = runtime.snapshot.activeLeaseCount;
    await handler.pause();
    check(
      runtime.snapshot.activeLeaseCount == leaseCount,
      'pause_retains_lease',
    );
    await handler.stop();
    check(await parts() == 0, 'stop_cancels_partial');
    await advances();
    check(
      handler.currentSourceKindForTesting == AudioSourceKind.cachingRemote,
      'stop_replay_new_write',
    );
    for (var i = 0; i < 4; i++) {
      lastCheck = 'rapid_pair_$i';
      rapidSettled['pending_$i'] = false;
      rapidSettled['next_$i'] = false;
      final pending = handler
          .setQueueData([track('rapid_$i')], forceReloadCurrent: true)
          .whenComplete(() {
            rapidSettled['pending_$i'] = true;
          });
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final next = handler
          .setQueueData([track('settled_$i')], forceReloadCurrent: true)
          .whenComplete(() {
            rapidSettled['next_$i'] = true;
          });
      await Future.wait([pending, next]).timeout(const Duration(seconds: 40));
      check(handler.mediaItem.value?.id == 'settled_$i', 'latest_commit_$i');
    }
    await handler.setQueueData([]);
    check(await parts() == 0, 'rapid_partial_cleanup');
    await policyLifecycle();
  }

  Future<void> policyLifecycle() async {
    await load('policy');
    final generation = handler.currentSourceGenerationForTesting;
    await runtime.updatePolicy(const AudioCachePolicy(enabled: false));
    network.set(NetworkConnectionType.cellular);
    check(
      handler.currentSourceGenerationForTesting == generation,
      'policy_keeps_current_source',
    );
    await advances();
    await waitFor(
      () => runtime.snapshot.entryCount > 0,
      'active_write_completes_after_policy_change',
    );
    final cleared = await runtime.clear();
    check(
      cleared.hasDeferredData && runtime.snapshot.entryCount == 0,
      'clear_active_deferred',
    );
    await handler.pause();
    await handler.seek(const Duration(seconds: 3));
    await advances();
    await handler.stop();
    check(runtime.snapshot.activeLeaseCount == 0, 'clear_stop_releases');
    await advances();
    check(
      handler.currentSourceKindForTesting == AudioSourceKind.plainRemote,
      'next_load_policy_plain',
    );
    await runtime.updatePolicy(const AudioCachePolicy());
    await load('cellular_blocked');
    check(
      handler.currentSourceKindForTesting == AudioSourceKind.plainRemote,
      'cellular_default_no_write',
    );
    await runtime.updatePolicy(const AudioCachePolicy(allowCellular: true));
    await load('cellular_allowed');
    check(
      handler.currentSourceKindForTesting == AudioSourceKind.cachingRemote,
      'cellular_opt_in_write',
    );
    await handler.setQueueData([]);
    check(
      runtime.snapshot.activeLeaseCount == 0 && await parts() == 0,
      'final_cleanup',
    );
  }

  Future<void> fftCoexistence() async {
    check(Platform.isMacOS, 'fft_macos_only');
    var nonzeroFrames = 0;
    final subscription = handler.spectrumFrameStream.listen((frame) {
      if (frame.bands.any((value) => value > 0)) nonzeroFrames++;
    });
    try {
      for (var i = 0; i < 3; i++) {
        await handler.stopSpectrumCapture();
        await load('fft_$i');
        await advances();
        await handler.startSpectrumCapture();
        final before = nonzeroFrames;
        await waitFor(() => nonzeroFrames > before + 5, 'fft_nonzero_$i');
        await handler.seek(const Duration(seconds: 8));
        await advances();
        await waitFor(
          () => runtime.snapshot.entryCount > i,
          'fft_cache_complete_$i',
        );
        final after = nonzeroFrames;
        await handler.seek(const Duration(seconds: 2));
        await advances();
        await waitFor(() => nonzeroFrames > after + 5, 'fft_cached_nonzero_$i');
      }
    } finally {
      await handler.stopSpectrumCapture();
      await subscription.cancel();
      await handler.setQueueData([]);
    }
    check(runtime.snapshot.activeLeaseCount == 0, 'fft_cleanup');
  }
}

class _HarnessPage extends StatefulWidget {
  const _HarnessPage(this.runner);
  final _Runner runner;
  @override
  State<_HarnessPage> createState() => _HarnessPageState();
}

class _HarnessPageState extends State<_HarnessPage> {
  String result = 'Ready';
  bool busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Native Cache Release')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(result),
        for (final phase in [
          'seed',
          'offline',
          'offline-quality',
          'lifecycle',
          'policy',
          'fft',
          'mismatch',
          'reject',
          'truncate',
          'disconnect',
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() {
                        busy = true;
                        result = '$phase running';
                      });
                      try {
                        await widget.runner.run(phase);
                        if (mounted) {
                          setState(() {
                            result = '$phase passed';
                          });
                        }
                      } catch (_) {
                        if (mounted) {
                          setState(() {
                            result =
                                '$phase failed: ${widget.runner.lastCheck}';
                          });
                        }
                      } finally {
                        if (mounted) {
                          setState(() {
                            busy = false;
                          });
                        }
                      }
                    },
              child: Text(phase),
            ),
          ),
      ],
    ),
  );
}
