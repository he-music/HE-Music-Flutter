import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/helpers/root_route_navigation_helper.dart';
import '../../../../shared/utils/share_link_builder.dart';
import 'online_search_models.dart';

void openSearchDetail({
  required BuildContext context,
  required SearchType type,
  required Map<String, dynamic> item,
  required String fallbackPlatformId,
  required String localeCode,
  required ValueChanged<String> onError,
}) {
  final id = text(item['id']);
  if (id == '-') {
    onError(AppI18n.tByLocaleCode(localeCode, 'search.invalid_detail'));
    return;
  }
  final platform = resolveSearchPlatform(item, fallbackPlatformId);
  final title = displayTitle(type, item);
  switch (type) {
    case SearchType.playlist:
      context.pushPlaylistDetail(id: id, platform: platform, title: title);
      return;
    case SearchType.album:
      context.pushAlbumDetail(id: id, platform: platform, title: title);
      return;
    case SearchType.comprehensive:
    case SearchType.artist:
    case SearchType.video:
    case SearchType.song:
      final uri = Uri(
        path: _detailRouteForSearchType(type),
        queryParameters: <String, String>{
          'type': type.apiType,
          'id': id,
          'platform': platform,
          'title': title,
        },
      );
      context.push(uri.toString());
  }
}

void openSearchSongAlbumDetail({
  required BuildContext context,
  required Map<String, dynamic> item,
  required String fallbackPlatformId,
  required String localeCode,
  required ValueChanged<String> onError,
}) {
  final albumId = songAlbumId(item);
  if (albumId == '-') {
    onError(AppI18n.tByLocaleCode(localeCode, 'search.no_album'));
    return;
  }
  context.pushAlbumDetail(
    id: albumId,
    platform: resolveSearchPlatform(item, fallbackPlatformId),
    title: songAlbum(item),
  );
}

void openSearchSongArtistDetail({
  required BuildContext context,
  required Map<String, dynamic> item,
  required String fallbackPlatformId,
  required String localeCode,
  required ValueChanged<String> onError,
}) {
  final artistId = songPrimaryArtistId(item);
  if (artistId == '-') {
    onError(AppI18n.tByLocaleCode(localeCode, 'search.no_artist'));
    return;
  }
  final uri = Uri(
    path: AppRoutes.artistDetail,
    queryParameters: <String, String>{
      'type': 'artist',
      'id': artistId,
      'platform': resolveSearchPlatform(item, fallbackPlatformId),
      'title': songSubtitle(item),
    },
  );
  context.push(uri.toString());
}

Future<void> searchBySameSongName({
  required Map<String, dynamic> item,
  required TextEditingController controller,
  required Future<void> Function() onSearch,
  required String localeCode,
  required ValueChanged<String> onError,
}) async {
  final name = songTitle(item);
  if (name == '-') {
    onError(AppI18n.tByLocaleCode(localeCode, 'search.invalid_name'));
    return;
  }
  controller.text = name;
  await onSearch();
}

Future<void> copySearchSongId({
  required Map<String, dynamic> item,
  required String localeCode,
  required ValueChanged<String> onError,
  required ValueChanged<String> onSuccess,
}) async {
  final id = text(item['id']);
  if (id == '-') {
    onError(AppI18n.tByLocaleCode(localeCode, 'search.invalid_id'));
    return;
  }
  await Clipboard.setData(ClipboardData(text: id));
  onSuccess(AppI18n.tByLocaleCode(localeCode, 'player.copy.id_done'));
}

Future<void> copySearchSongName({
  required Map<String, dynamic> item,
  required String localeCode,
  required ValueChanged<String> onError,
  required ValueChanged<String> onSuccess,
}) async {
  final name = songTitle(item);
  if (name == '-') {
    onError(AppI18n.tByLocaleCode(localeCode, 'search.invalid_name'));
    return;
  }
  await Clipboard.setData(ClipboardData(text: name));
  onSuccess(AppI18n.tByLocaleCode(localeCode, 'player.copy.name_done'));
}

Future<void> copySearchSongShareLink({
  required Map<String, dynamic> item,
  required String fallbackPlatformId,
  required String localeCode,
  required ValueChanged<String> onError,
  required ValueChanged<String> onSuccess,
}) async {
  final id = text(item['id']);
  if (id == '-') {
    onError(AppI18n.tByLocaleCode(localeCode, 'search.invalid_id'));
    return;
  }
  final platform = resolveSearchPlatform(item, fallbackPlatformId);
  final link = buildShareLink(type: 'song', platform: platform, id: id);
  await Clipboard.setData(ClipboardData(text: link));
  onSuccess(AppI18n.tByLocaleCode(localeCode, 'player.copy.share_done'));
}

void openSearchSongMvDetail({
  required BuildContext context,
  required Map<String, dynamic> item,
  required String fallbackPlatformId,
  required String localeCode,
  required ValueChanged<String> onError,
}) {
  final mvId = songMvId(item);
  if (mvId == '-' || mvId == '0') {
    onError(AppI18n.tByLocaleCode(localeCode, 'search.no_mv'));
    return;
  }
  final uri = Uri(
    path: AppRoutes.videoDetail,
    queryParameters: <String, String>{
      'type': 'mv',
      'id': mvId,
      'platform': resolveSearchPlatform(item, fallbackPlatformId),
      'title': songTitle(item),
    },
  );
  context.push(uri.toString());
}

String resolveSearchPlatform(
  Map<String, dynamic> item,
  String fallbackPlatformId,
) {
  final platform = text(item['platform']);
  if (platform == '-') {
    return fallbackPlatformId;
  }
  return platform;
}

String _detailRouteForSearchType(SearchType type) {
  return switch (type) {
    SearchType.comprehensive => AppRoutes.onlineSearch,
    SearchType.playlist => AppRoutes.playlistDetail,
    SearchType.album => AppRoutes.albumDetail,
    SearchType.artist => AppRoutes.artistDetail,
    SearchType.video => AppRoutes.videoDetail,
    SearchType.song => AppRoutes.songDetail,
  };
}
