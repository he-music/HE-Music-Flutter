import 'app_routes.dart';

/// These routes render local data or settings without platform capabilities.
/// All other routes retain the online startup gate, including deep links.
bool canOpenWithoutPlatforms(Uri uri) {
  final path = uri.path.startsWith('${AppRoutes.rootBrowsePrefix}/')
      ? uri.path.substring(AppRoutes.rootBrowsePrefix.length)
      : uri.path;
  if (path == AppRoutes.library ||
      path == AppRoutes.collection ||
      path == AppRoutes.downloads ||
      path == AppRoutes.downloadedMusic ||
      path == AppRoutes.localGenre ||
      path == AppRoutes.localMetadataEdit ||
      path == AppRoutes.my ||
      path == AppRoutes.myHistory ||
      path == AppRoutes.player ||
      path == AppRoutes.settings ||
      path.startsWith('${AppRoutes.settings}/')) {
    return true;
  }
  return uri.queryParameters['platform'] == 'local' &&
      (path == AppRoutes.artistDetail || path == AppRoutes.albumDetail);
}
