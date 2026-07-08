import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';

extension RootRouteNavigation on BuildContext {
  void pushPlaylistDetail({
    required String id,
    required String platform,
    required String title,
  }) {
    push(
      Uri(
        path: AppRoutes.playlistDetail,
        queryParameters: <String, String>{
          'id': id,
          'platform': platform,
          'title': title,
        },
      ).toString(),
    );
  }

  void pushAlbumDetail({
    required String id,
    required String platform,
    required String title,
  }) {
    push(
      Uri(
        path: AppRoutes.albumDetail,
        queryParameters: <String, String>{
          'id': id,
          'platform': platform,
          'title': title,
        },
      ).toString(),
    );
  }
}
