import '../../app/config/app_environment.dart';

String buildShareLink({
  required String type,
  required String platform,
  required String id,
}) {
  final baseUrl = AppEnvironment.apiBaseUrl.trim().replaceAll(
    RegExp(r'/+$'),
    '',
  );
  final normalizedType = type.trim().replaceAll(RegExp(r'^/+|/+$'), '');
  final normalizedPlatform = platform.trim();
  final normalizedId = id.trim();
  final query = Uri(
    queryParameters: <String, String>{
      'id': normalizedId,
      'platform': normalizedPlatform,
    },
  ).query;
  return '$baseUrl/#/$normalizedType?$query';
}
