import '../entities/update_release_page.dart';
import '../entities/update_check_result.dart';
import '../entities/update_version.dart';

abstract class UpdateRepository {
  Future<UpdateReleasePage> fetchReleaseHistory(int page);

  Future<UpdateCheckResult> checkForUpdates({
    required UpdateVersion currentVersion,
  });
}
