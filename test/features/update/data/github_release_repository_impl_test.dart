import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/update/data/github_release_api_client.dart';
import 'package:he_music_flutter/features/update/data/github_release_repository_impl.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_version.dart';

void main() {
  test('maps valid release assets and ignores incomplete entries', () async {
    final repository = GitHubReleaseRepositoryImpl(
      _FakeApiClient(<String, dynamic>{
        'tag_name': 'v1.1.0',
        'html_url': 'https://github.com/owner/repo/releases/tag/v1.1.0',
        'name': 'v1.1.0',
        'body': 'notes',
        'published_at': '2026-07-27T12:00:00Z',
        'draft': false,
        'prerelease': false,
        'assets': <Object?>[
          <String, Object>{
            'name': 'HE-Music-v1.1.0-android-arm64-v8a.apk',
            'browser_download_url':
                'https://github.com/owner/repo/releases/download/v1.1.0/HE-Music-v1.1.0-android-arm64-v8a.apk',
          },
          <String, Object>{
            'name': 'HE-Music-v1.1.0-android-x86_64.apk',
            'browser_download_url':
                'https://github.com/owner/repo/releases/download/v1.1.0/HE-Music-v1.1.0-android-x86_64.apk',
          },
          <String, Object>{'name': 'missing-url.apk'},
          'invalid',
        ],
      }),
      owner: 'owner',
      repo: 'repo',
    );

    final result = await repository.checkForUpdates(
      currentVersion: UpdateVersion.parse('1.0.0'),
    );

    expect(result.release?.assets, hasLength(2));
    expect(
      result.release?.assets.first.name,
      'HE-Music-v1.1.0-android-arm64-v8a.apk',
    );
    expect(
      () => result.release?.assets.add(result.release!.assets.first),
      throwsUnsupportedError,
    );
  });
}

class _FakeApiClient extends GitHubReleaseApiClient {
  _FakeApiClient(this.response) : super(Dio());

  final Map<String, dynamic> response;

  @override
  Future<Map<String, dynamic>> fetchLatestRelease({
    required String owner,
    required String repo,
  }) async {
    return response;
  }
}
