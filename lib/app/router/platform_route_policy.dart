import 'app_routes.dart';

/// These routes render local data or settings without platform capabilities.
/// All other routes retain the online startup gate, including deep links.
bool canOpenWithoutPlatforms(Uri uri) {
  if (uri.path == AppRoutes.library ||
      uri.path == AppRoutes.downloads ||
      uri.path == AppRoutes.downloadedMusic ||
      uri.path == AppRoutes.localGenre ||
      uri.path == AppRoutes.localMetadataEdit ||
      uri.path == AppRoutes.my ||
      uri.path == AppRoutes.myHistory ||
      uri.path == AppRoutes.player ||
      uri.path == AppRoutes.settings ||
      uri.path.startsWith('${AppRoutes.settings}/')) {
    return true;
  }
  return uri.queryParameters['platform'] == 'local' &&
      (uri.path == AppRoutes.artistDetail || uri.path == AppRoutes.albumDetail);
}
