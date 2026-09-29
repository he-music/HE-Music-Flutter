import '../error/app_exception.dart';
import '../error/failure.dart';

/// 保留已有字符串键 Map；其他 Map 将键转成字符串，非 Map 响应抛出网络异常。
Map<String, dynamic> parseResponseMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry('$key', item));
  }
  throw AppException(
    NetworkFailure('Invalid payload type: ${value.runtimeType}'),
  );
}

/// 兼容布尔值、数字和布尔字符串；无法识别时使用接口指定的默认值。
bool parseResponseBool(dynamic value, {required bool fallback}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  final text = '$value'.trim().toLowerCase();
  if (text == 'true' || text == '1') {
    return true;
  }
  if (text == 'false' || text == '0') {
    return false;
  }
  return fallback;
}
