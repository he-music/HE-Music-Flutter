import '../../app/config/app_online_audio_quality.dart';

AppOnlineAudioQuality? inferOnlineAudioQualityBucket({
  required String name,
  required String format,
  required int bitrate,
}) {
  final normalizedName = name.trim().toLowerCase();
  final normalizedFormat = format.trim().toLowerCase();
  if (normalizedName.contains('master')) {
    return AppOnlineAudioQuality.master;
  }
  if (normalizedName.contains('galaxy')) {
    return AppOnlineAudioQuality.galaxy;
  }
  if (normalizedName.contains('dolby')) {
    return AppOnlineAudioQuality.dolby;
  }
  if (normalizedName.contains('hires') || normalizedName.contains('hi-res')) {
    return AppOnlineAudioQuality.hires;
  }
  if (normalizedName.contains('flac') || normalizedFormat == 'flac') {
    return AppOnlineAudioQuality.flac;
  }
  if (normalizedName.contains('320') ||
      (normalizedFormat == 'mp3' && bitrate >= 320)) {
    return AppOnlineAudioQuality.mp3320;
  }
  if (normalizedName.contains('192') ||
      (normalizedFormat == 'mp3' && bitrate >= 192)) {
    return AppOnlineAudioQuality.mp3192;
  }
  if (normalizedName.contains('128') ||
      (normalizedFormat == 'mp3' && bitrate >= 128)) {
    return AppOnlineAudioQuality.mp3128;
  }
  return null;
}

T? selectPreferredAudioQuality<T>(
  List<T> items, {
  required AppOnlineAudioQuality preference,
  required String? lastSelectedQualityName,
  required String Function(T item) nameOf,
  required String Function(T item) formatOf,
  required int Function(T item) bitrateOf,
}) {
  if (items.isEmpty) {
    return null;
  }
  final lastSelected = lastSelectedQualityName?.trim() ?? '';
  if (preference.isAuto && lastSelected.isNotEmpty) {
    for (final item in items) {
      if (nameOf(item).trim() == lastSelected) {
        return item;
      }
    }
  }
  if (!preference.isAuto) {
    for (final item in items) {
      if (nameOf(item).trim().toLowerCase() == preference.value) {
        return item;
      }
    }
    for (final item in items) {
      if (inferOnlineAudioQualityBucket(
            name: nameOf(item),
            format: formatOf(item),
            bitrate: bitrateOf(item),
          ) ==
          preference) {
        return item;
      }
    }
    return items.first;
  }
  for (final fallback in AppOnlineAudioQuality.autoFallbackOrder) {
    for (final item in items) {
      if (inferOnlineAudioQualityBucket(
            name: nameOf(item),
            format: formatOf(item),
            bitrate: bitrateOf(item),
          ) ==
          fallback) {
        return item;
      }
    }
  }
  return items.first;
}
