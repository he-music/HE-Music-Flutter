import 'failure.dart';

class AppException implements Exception {
  const AppException(this.failure);

  final Failure failure;

  @override
  String toString() {
    return 'AppException: ${failure.message}';
  }
}
