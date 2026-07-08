import 'update_release.dart';

class UpdateCheckResult {
  const UpdateCheckResult._({required this.isAvailable, this.release});

  final bool isAvailable;
  final UpdateRelease? release;

  const UpdateCheckResult.latest() : this._(isAvailable: false);

  const UpdateCheckResult.available(UpdateRelease release)
    : this._(isAvailable: true, release: release);
}
