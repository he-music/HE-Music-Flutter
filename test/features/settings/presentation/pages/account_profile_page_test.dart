import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/app_navigation_service.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_overview.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_overview_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_profile.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_summary.dart';
import 'package:he_music_flutter/features/my/presentation/controllers/my_overview_controller.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_overview_providers.dart';
import 'package:he_music_flutter/features/settings/data/account_settings_api_client.dart';
import 'package:he_music_flutter/features/settings/data/providers/account_settings_providers.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/account_profile_page.dart';
import 'package:toastification/toastification.dart';

void main() {
  testWidgets('profile page loads current profile values', (tester) async {
    final controller = _TestMyOverviewController(initialState: _profileState);
    final client = _FakeAccountSettingsApiClient();

    await _pumpPage(tester, controller: controller, client: client);

    final nickname = tester.widget<TextFormField>(
      find.byKey(const ValueKey<String>('account-profile-nickname')),
    );
    final avatar = tester.widget<TextFormField>(
      find.byKey(const ValueKey<String>('account-profile-avatar')),
    );
    expect(nickname.controller?.text, 'Original Name');
    expect(avatar.controller?.text, 'https://example.com/old.jpg');
    expect(find.text('@tester'), findsOneWidget);
  });

  testWidgets('profile page supports narrow dark english layout', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpPage(
      tester,
      controller: _TestMyOverviewController(initialState: _profileState),
      client: _FakeAccountSettingsApiClient(),
      localeCode: 'en',
      theme: ThemeData.dark(),
    );

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Nickname'), findsOneWidget);
    expect(find.text('Avatar URL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile page shows loading state while overview loads', (
    tester,
  ) async {
    final controller = _TestMyOverviewController(
      initialState: const MyOverviewState(loading: true),
    );

    await _pumpPage(
      tester,
      controller: controller,
      client: _FakeAccountSettingsApiClient(),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('account-profile-submit')),
      findsNothing,
    );
  });

  testWidgets('signed out profile page does not load or submit profile', (
    tester,
  ) async {
    final controller = _TestMyOverviewController(
      initialState: MyOverviewState.initial,
    );
    final client = _FakeAccountSettingsApiClient();

    await _pumpPage(
      tester,
      controller: controller,
      client: client,
      authToken: null,
    );

    expect(find.text('尚未登录'), findsOneWidget);
    expect(find.text('登录帐号'), findsOneWidget);
    expect(controller.refreshCalls, 0);
    expect(client.profileCalls, 0);
  });

  testWidgets('profile validation blocks empty nickname and invalid avatar', (
    tester,
  ) async {
    final controller = _TestMyOverviewController(initialState: _profileState);
    final client = _FakeAccountSettingsApiClient();
    await _pumpPage(tester, controller: controller, client: client);

    await tester.enterText(
      find.byKey(const ValueKey<String>('account-profile-nickname')),
      '',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('account-profile-avatar')),
      'avatar.jpg',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('account-profile-submit')),
    );
    await _pumpToast(tester);

    expect(find.text('请输入昵称'), findsOneWidget);
    expect(find.text('请输入绝对 http/https URL'), findsOneWidget);
    expect(client.profileCalls, 0);
  });

  testWidgets('profile validation prevents clearing an existing avatar', (
    tester,
  ) async {
    final controller = _TestMyOverviewController(initialState: _profileState);
    final client = _FakeAccountSettingsApiClient();
    await _pumpPage(tester, controller: controller, client: client);

    await tester.enterText(
      find.byKey(const ValueKey<String>('account-profile-avatar')),
      '',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('account-profile-submit')),
    );
    await _pumpToast(tester);

    expect(find.text('当前接口不支持移除已有头像'), findsOneWidget);
    expect(client.profileCalls, 0);
  });

  testWidgets('valid profile submit refreshes shared overview', (tester) async {
    final refreshedProfile = _profile(
      nickname: 'New Name',
      avatarUrl: 'https://example.com/new.jpg',
    );
    final controller = _TestMyOverviewController(
      initialState: _profileState,
      refreshedProfile: refreshedProfile,
    );
    final client = _FakeAccountSettingsApiClient();
    final container = await _pumpPage(
      tester,
      controller: controller,
      client: client,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('account-profile-nickname')),
      'New Name',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('account-profile-avatar')),
      'https://example.com/new.jpg',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('account-profile-submit')),
    );
    await _pumpToast(tester);

    expect(client.profileCalls, 1);
    expect(client.nickname, 'New Name');
    expect(client.avatarUrl, 'https://example.com/new.jpg');
    expect(controller.refreshCalls, 1);
    expect(
      container.read(myOverviewControllerProvider).overview?.profile.nickname,
      'New Name',
    );
    expect(container.read(appConfigProvider).authToken, 'token');
    expect(find.text('个人资料已更新'), findsOneWidget);
    await _dismissToasts(tester);
  });

  testWidgets('failed profile submit keeps form values and shows error', (
    tester,
  ) async {
    final controller = _TestMyOverviewController(initialState: _profileState);
    final client = _FakeAccountSettingsApiClient(
      error: StateError('profile update failed'),
    );
    await _pumpPage(tester, controller: controller, client: client);

    await tester.enterText(
      find.byKey(const ValueKey<String>('account-profile-nickname')),
      'Unsaved Name',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('account-profile-submit')),
    );
    await _pumpToast(tester);

    final nickname = tester.widget<TextFormField>(
      find.byKey(const ValueKey<String>('account-profile-nickname')),
    );
    expect(nickname.controller?.text, 'Unsaved Name');
    expect(find.textContaining('profile update failed'), findsOneWidget);
    expect(controller.refreshCalls, 0);
    await _dismissToasts(tester);
  });
}

Future<ProviderContainer> _pumpPage(
  WidgetTester tester, {
  required _TestMyOverviewController controller,
  required _FakeAccountSettingsApiClient client,
  String? authToken = 'token',
  String localeCode = 'zh',
  ThemeData? theme,
}) async {
  final container = ProviderContainer(
    overrides: [
      appConfigProvider.overrideWith(
        () => _TestAppConfigController(
          authToken: authToken,
          localeCode: localeCode,
        ),
      ),
      myOverviewControllerProvider.overrideWith(() => controller),
      accountSettingsApiClientProvider.overrideWithValue(client),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        theme: theme,
        home: const AccountProfilePage(),
      ),
    ),
  );
  await tester.pump();
  return container;
}

Future<void> _dismissToasts(WidgetTester tester) async {
  toastification.dismissAll(delayForAnimation: false);
  await tester.pump(const Duration(milliseconds: 700));
}

Future<void> _pumpToast(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
}

class _TestAppConfigController extends AppConfigController {
  _TestAppConfigController({
    required this.authToken,
    required this.localeCode,
  });

  final String? authToken;
  final String localeCode;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      authToken: authToken,
      clearToken: authToken == null,
      localeCode: localeCode,
    );
  }
}

class _TestMyOverviewController extends MyOverviewController {
  _TestMyOverviewController({
    required this.initialState,
    this.refreshedProfile,
  });

  final MyOverviewState initialState;
  final MyProfile? refreshedProfile;
  int refreshCalls = 0;

  @override
  MyOverviewState build() => initialState;

  @override
  Future<void> refresh() async {
    refreshCalls++;
    final profile = refreshedProfile;
    if (profile != null) {
      state = MyOverviewState(
        loading: false,
        overview: MyOverview(profile: profile, summary: _summary),
      );
    }
  }
}

class _FakeAccountSettingsApiClient extends AccountSettingsApiClient {
  _FakeAccountSettingsApiClient({this.error}) : super(Dio());

  final Object? error;
  int profileCalls = 0;
  String? nickname;
  String? avatarUrl;

  @override
  Future<void> updateProfile({
    required String nickname,
    String? avatarUrl,
  }) async {
    profileCalls++;
    this.nickname = nickname;
    this.avatarUrl = avatarUrl;
    if (error != null) {
      throw error!;
    }
  }
}

const _summary = MySummary(
  favoriteSongCount: 1,
  favoritePlaylistCount: 2,
  favoriteArtistCount: 3,
  favoriteAlbumCount: 4,
  createdPlaylistCount: 5,
);

final _profileState = MyOverviewState(
  loading: false,
  overview: MyOverview(profile: _profile(), summary: _summary),
);

MyProfile _profile({
  String nickname = 'Original Name',
  String avatarUrl = 'https://example.com/old.jpg',
}) {
  return MyProfile(
    id: 'user-1',
    username: 'tester',
    nickname: nickname,
    email: '',
    status: 1,
    avatarUrl: avatarUrl,
  );
}
