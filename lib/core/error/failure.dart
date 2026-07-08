sealed class Failure {
  const Failure(this.message);

  final String message;
}

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class StorageFailure extends Failure {
  const StorageFailure(super.message);
}

final class UnsupportedFailure extends Failure {
  const UnsupportedFailure(super.message);
}

final class LocalOnlyModeFailure extends Failure {
  const LocalOnlyModeFailure(super.message);
}

final class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}
