import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/github_download_proxy_config.dart';
import '../providers/update_providers.dart';

class GitHubDownloadProxyController
    extends AsyncNotifier<GitHubDownloadProxyConfigSnapshot> {
  @override
  Future<GitHubDownloadProxyConfigSnapshot> build() {
    return ref.read(gitHubDownloadProxyRepositoryProvider).loadLocal();
  }

  Future<GitHubDownloadProxyConfigSnapshot> refresh() async {
    final snapshot = await ref
        .read(gitHubDownloadProxyRepositoryProvider)
        .refresh();
    state = AsyncData(snapshot);
    return snapshot;
  }
}
