import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';
import '../../features/online/domain/entities/online_platform.dart';

bool isOnlineSongPlatform(String platformId) {
  final normalized = platformId.trim().toLowerCase();
  return normalized.isNotEmpty && normalized != 'local';
}

bool platformSupportsSongDetail({
  required String platformId,
  required List<OnlinePlatform> platforms,
}) {
  return isOnlineSongPlatform(platformId);
}

bool platformSupportsAlbumDetail({
  required String platformId,
  required List<OnlinePlatform> platforms,
}) {
  return _platformSupports(
    platformId: platformId,
    platforms: platforms,
    featureFlag: PlatformFeatureSupportFlag.getAlbumInfo,
  );
}

bool platformSupportsArtistDetail({
  required String platformId,
  required List<OnlinePlatform> platforms,
}) {
  return _platformSupports(
    platformId: platformId,
    platforms: platforms,
    featureFlag: PlatformFeatureSupportFlag.getSingerInfo,
  );
}

bool platformSupportsSongComment({
  required String platformId,
  required List<OnlinePlatform> platforms,
}) {
  return _platformSupports(
    platformId: platformId,
    platforms: platforms,
    featureFlag: PlatformFeatureSupportFlag.getCommentList,
  );
}

bool canOpenSongDetail({
  required String songId,
  required String platformId,
  required List<OnlinePlatform> platforms,
}) {
  return songId.trim().isNotEmpty &&
      platformSupportsSongDetail(platformId: platformId, platforms: platforms);
}

bool _platformSupports({
  required String platformId,
  required List<OnlinePlatform> platforms,
  required BigInt featureFlag,
}) {
  if (!isOnlineSongPlatform(platformId)) {
    return false;
  }
  for (final platform in platforms) {
    if (platform.id != platformId) {
      continue;
    }
    return platform.available && platform.supports(featureFlag);
  }
  return false;
}

void openSongDetailPage({
  required BuildContext context,
  required String songId,
  required String platformId,
  required String title,
}) {
  final uri = Uri(
    path: AppRoutes.songDetail,
    queryParameters: <String, String>{
      'id': songId,
      'platform': platformId,
      'title': title,
    },
  );
  context.push(uri.toString());
}
