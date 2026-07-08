import '../../app/i18n/app_i18n.dart';

String buildPlaylistSongCountText({
  required String count,
  required String localeCode,
}) {
  final normalized = count.trim();
  if (normalized.isEmpty || normalized == '-' || normalized == '0') {
    return '';
  }
  return AppI18n.formatByLocaleCode(
    localeCode,
    'playlist.track_count',
    <String, String>{'count': normalized},
  );
}

String joinPlaylistMetaText({
  required String primaryText,
  required String songCountText,
}) {
  final primary = primaryText.trim();
  final songCount = songCountText.trim();
  if (primary.isEmpty) {
    return songCount;
  }
  if (songCount.isEmpty) {
    return primary;
  }
  return '$primary · $songCount';
}
