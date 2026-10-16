import '../../../../core/error/app_exception.dart';
import '../../../../core/error/failure.dart';

/// 后端已声明能力，但平台实现尚未开放。
class SheetMusicNotImplementedException extends AppException {
  const SheetMusicNotImplementedException()
    : super(const UnsupportedFailure('NotImplemented'));
}
