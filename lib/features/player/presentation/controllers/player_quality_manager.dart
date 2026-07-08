import '../../../../app/config/app_config_state.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../domain/entities/player_quality_option.dart';
import '../../domain/entities/player_track.dart';
import '../../../../shared/utils/audio_quality_selector.dart';

/// 曲目播放解析结果。
///
/// 封装了曲目解析后的队列、可用音质等信息。
class TrackPlaybackResolution {
  const TrackPlaybackResolution({
    required this.track,
    required this.updatedQueue,
    required this.availableQualities,
    required this.selectedQualityName,
  });

  final PlayerTrack track;
  final List<PlayerTrack> updatedQueue;
  final List<PlayerQualityOption> availableQualities;
  final String? selectedQualityName;
}

/// 音质管理器。
///
/// 负责音质列表解析、音质选择、曲目播放前的 URL 解析/预处理。
/// 通过函数回调读取配置，不直接依赖 Riverpod。
class PlayerQualityManager {
  PlayerQualityManager({
    required List<OnlinePlatform> Function() platformsReader,
    required AppConfigState Function() configReader,
  }) : _platformsReader = platformsReader,
       _configReader = configReader;

  final List<OnlinePlatform> Function() _platformsReader;
  final AppConfigState Function() _configReader;

  /// 解析曲目可用的音质列表。
  List<PlayerQualityOption> resolveAvailableQualities(PlayerTrack track) {
    if (track.links.isEmpty) {
      return const <PlayerQualityOption>[];
    }
    final descriptions = _platformQualityDescriptions(
      (track.platform ?? '').trim(),
    );
    final available = <PlayerQualityOption>[];
    final seenNames = <String>{};
    for (final link in track.links) {
      final name = link.name.trim();
      if (name.isEmpty || !seenNames.add(name)) {
        continue;
      }
      final description = (descriptions[name] ?? '').trim();
      available.add(
        PlayerQualityOption(
          name: name,
          description: description.isEmpty ? null : description,
          quality: link.quality,
          format: link.format,
          url: link.url,
          sizeBytes: _parseLinkSizeBytes(link.size),
        ),
      );
    }
    return List<PlayerQualityOption>.unmodifiable(available.reversed);
  }

  /// 根据配置和偏好选择最佳音质名称。
  String? resolveSelectedQualityName({
    required List<PlayerQualityOption> availableQualities,
    String? forcedQualityName,
  }) {
    if (availableQualities.isEmpty) {
      return null;
    }
    final forced = forcedQualityName?.trim() ?? '';
    if (forced.isNotEmpty &&
        findQualityOptionByName(availableQualities, forced) != null) {
      return forced;
    }
    final config = _configReader();
    final matched = selectPreferredAudioQuality(
      availableQualities,
      preference: config.onlineAudioQualityPreference,
      lastSelectedQualityName: config.lastSelectedOnlineAudioQualityName,
      nameOf: (PlayerQualityOption option) => option.name,
      formatOf: (PlayerQualityOption option) => option.format,
      bitrateOf: (PlayerQualityOption option) => option.quality,
    );
    if (matched != null) {
      return matched.name;
    }
    return availableQualities.first.name;
  }

  /// 按名称查找音质选项。
  PlayerQualityOption? findQualityOptionByName(
    List<PlayerQualityOption> options,
    String qualityName,
  ) {
    for (final option in options) {
      if (option.name == qualityName) {
        return option;
      }
    }
    return null;
  }

  /// 解析曲目的播放 URL 和音质信息。
  Future<TrackPlaybackResolution> resolveTrackForPlayback(
    List<PlayerTrack> queue,
    int index, {
    String? forcedQualityName,
  }) async {
    if (index < 0 || index >= queue.length) {
      throw const AppException(ValidationFailure('Player track is missing.'));
    }
    final track = queue[index];
    final availableQualities = resolveAvailableQualities(track);
    final selectedQualityName = resolveSelectedQualityName(
      availableQualities: availableQualities,
      forcedQualityName: forcedQualityName,
    );
    final localPath = track.path?.trim() ?? '';
    if (localPath.isNotEmpty) {
      final localUrl = _localPathToUrl(localPath);
      final updatedTrack = track.copyWith(url: localUrl);
      return TrackPlaybackResolution(
        track: updatedTrack,
        updatedQueue: <PlayerTrack>[
          ...queue.take(index),
          updatedTrack,
          ...queue.skip(index + 1),
        ],
        availableQualities: availableQualities,
        selectedQualityName: selectedQualityName,
      );
    }
    final platform = (track.platform ?? '').trim();
    var resolvedTrack = track;
    if (platform.isNotEmpty) {
      resolvedTrack = track.copyWith(url: '');
    }
    if (resolvedTrack.url.trim().isEmpty && platform.isEmpty) {
      throw const AppException(
        ValidationFailure('Player track url is missing.'),
      );
    }
    final nextQueue = <PlayerTrack>[...queue];
    nextQueue[index] = resolvedTrack;
    return TrackPlaybackResolution(
      track: resolvedTrack,
      updatedQueue: nextQueue,
      availableQualities: availableQualities,
      selectedQualityName: selectedQualityName,
    );
  }

  /// 从在线平台配置获取音质描述映射。
  Map<String, String> _platformQualityDescriptions(String platformId) {
    if (platformId.isEmpty) {
      return const <String, String>{};
    }
    final platforms = _platformsReader();
    if (platforms.isEmpty) {
      return const <String, String>{};
    }
    for (final platform in platforms) {
      if (platform.id == platformId) {
        return platform.qualities;
      }
    }
    return const <String, String>{};
  }

  int? _parseLinkSizeBytes(String rawSize) {
    final normalized = rawSize.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(normalized);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    return parsed;
  }

  String _localPathToUrl(String localPath) {
    final normalized = localPath.trim();
    if (normalized.isEmpty) {
      return '';
    }
    final parsed = Uri.tryParse(normalized);
    if (parsed != null && parsed.hasScheme) {
      return parsed.toString();
    }
    return Uri.file(normalized).toString();
  }
}
