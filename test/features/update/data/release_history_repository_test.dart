import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/update/data/github_release_api_client.dart';
import 'package:he_music_flutter/features/update/data/github_release_repository_impl.dart';

void main() {
  test(
    'history filters nonstable tags and sorts by semantic version',
    () async {
      final api = _Api([
        _release('v1.9.0'),
        _release('v1.10.0'),
        {..._release('v2.0.0'), 'prerelease': true},
        {..._release('v3.0.0'), 'draft': true},
        _release('nightly'),
        {..._release('v4.0.0'), 'html_url': ''},
      ]);
      final repository = GitHubReleaseRepositoryImpl(
        api,
        owner: 'owner',
        repo: 'repo',
      );
      final result = await repository.fetchReleaseHistory(2);
      expect(result.releases.map((r) => r.version.normalized), [
        '1.10.0',
        '1.9.0',
      ]);
      expect(result.hasMore, isFalse);
      expect(api.requestedPage, 2);
      expect(result.releases.first.releaseNotes, 'notes v1.10.0');
    },
  );

  test('a full filtered page still allows loading the next page', () async {
    final api = _Api(List.generate(30, (_) => _release('nightly')));
    final result = await GitHubReleaseRepositoryImpl(
      api,
      owner: 'owner',
      repo: 'repo',
    ).fetchReleaseHistory(1);
    expect(result.releases, isEmpty);
    expect(result.hasMore, isTrue);
  });
}

Map<String, dynamic> _release(String version) => {
  'tag_name': version,
  'html_url': 'https://github.com/owner/repo/releases/tag/$version',
  'body': 'notes $version',
  'published_at': '2026-07-18T00:00:00Z',
};

class _Api extends GitHubReleaseApiClient {
  _Api(this.data) : super(Dio());
  final List<Map<String, dynamic>> data;
  int? requestedPage;

  @override
  Future<List<Map<String, dynamic>>> fetchReleases({
    required String owner,
    required String repo,
    required int page,
    int perPage = 30,
  }) async {
    requestedPage = page;
    return data;
  }
}
