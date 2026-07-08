import 'update_release.dart';

enum UpdateStatus { idle, checking, latest, available, failure }

class UpdateState {
  const UpdateState({required this.status, this.release, this.errorMessage});

  final UpdateStatus status;
  final UpdateRelease? release;
  final String? errorMessage;

  UpdateState copyWith({
    UpdateStatus? status,
    UpdateRelease? release,
    String? errorMessage,
    bool clearRelease = false,
    bool clearError = false,
  }) {
    return UpdateState(
      status: status ?? this.status,
      release: clearRelease ? null : release ?? this.release,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  static const initial = UpdateState(status: UpdateStatus.idle);
}
