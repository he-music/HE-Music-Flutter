import '../../features/online/domain/entities/online_platform.dart';

/// 通用封面解析：仅负责 `{x}/{y}` 尺寸占位符替换（按平台 `image_sizes` 选择尺寸）。
/// 注意：不做任何兜底接口拼接。适用于歌单/专辑/歌手等非歌曲资源。
String resolveTemplateCoverUrl({
  required List<OnlinePlatform> platforms,
  required String platformId,
  String? cover,
  int size = 300,
}) {
  final normalizedPlatform = platformId.trim();
  final normalizedCover = (cover ?? '').trim();
  if (normalizedPlatform.isEmpty || normalizedCover.isEmpty) {
    return '';
  }
  var finalSize = size;
  if (finalSize == 0) finalSize = 300;
  if (finalSize < 0) finalSize = -1;
  final imageSizes = _platformImageSizes(platforms, normalizedPlatform);
  finalSize = _pickSize(imageSizes: imageSizes, requested: finalSize);
  return normalizedCover
      .replaceAll('{x}', finalSize.toString())
      .replaceAll('{y}', finalSize.toString());
}

String resolveSongCoverUrl({
  required String baseUrl,
  required String token,
  required List<OnlinePlatform> platforms,
  required String platformId,
  required String songId,
  String? cover,
  int size = 300,
}) {
  final normalizedBaseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  final normalizedPlatform = platformId.trim();
  final normalizedId = songId.trim();
  final normalizedCover = (cover ?? '').trim();

  if (normalizedPlatform.isEmpty || normalizedId.isEmpty) {
    return '';
  }

  var finalSize = size;
  if (finalSize == 0) finalSize = 300;
  if (finalSize < 0) finalSize = -1;

  final imageSizes = _platformImageSizes(platforms, normalizedPlatform);
  finalSize = _pickSize(imageSizes: imageSizes, requested: finalSize);

  if (normalizedCover.isNotEmpty) {
    return resolveTemplateCoverUrl(
      platforms: platforms,
      platformId: normalizedPlatform,
      cover: normalizedCover,
      size: finalSize,
    );
  }

  // 与 HE-Music 对齐：没有 cover 时走 /v1/song/cover 的 query token 生成方式。
  // 注意：这里不是通过 Dio 去请求，因此 Authorization header 不会参与，需要把 token 带在 query 上。
  return _getCoverUrlStr(
    baseUrl: normalizedBaseUrl,
    platform: normalizedPlatform,
    id: normalizedId,
    quality: finalSize,
    redirect: true,
    token: token,
  );
}

List<int> _platformImageSizes(
  List<OnlinePlatform> platforms,
  String platformId,
) {
  for (final platform in platforms) {
    if (platform.id == platformId) {
      return platform.imageSizes;
    }
  }
  return const <int>[];
}

int _pickSize({required List<int> imageSizes, required int requested}) {
  if (requested < 0) {
    if (imageSizes.isNotEmpty) return imageSizes.last;
    return 1000;
  }
  if (imageSizes.isEmpty) return requested;
  for (final item in imageSizes) {
    if (item >= requested) return item;
  }
  return imageSizes.last;
}

String _getCoverUrlStr({
  required String baseUrl,
  required String platform,
  required String id,
  required int quality,
  required bool redirect,
  required String token,
}) {
  final query = <String, dynamic>{
    'id': id,
    'platform': platform,
    'quality': quality.toString(),
    'redirect': redirect.toString(),
    'token': token,
  };
  return '$baseUrl/v1/song/cover?${Uri(queryParameters: query).query}';
}
