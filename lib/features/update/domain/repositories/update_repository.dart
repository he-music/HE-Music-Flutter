import '../entities/update_check_result.dart';
import '../entities/update_version.dart';

abstract class UpdateRepository {
  Future<UpdateCheckResult> checkForUpdates({
    required UpdateVersion currentVersion,
  });
}
