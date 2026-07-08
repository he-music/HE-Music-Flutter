import 'id_platform_key.dart';

String buildFavoriteSongKey({
  required String songId,
  required String platform,
}) {
  return buildIdPlatformKey(id: songId, platform: platform);
}
