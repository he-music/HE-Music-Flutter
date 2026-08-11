import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_lyric_font_preset.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_color.dart';
import 'package:he_music_flutter/app/config/app_lyric_highlight_mode.dart';
import 'package:he_music_flutter/app/config/app_online_audio_quality.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/router/app_routes.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_icon.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_feature_state.dart';
import 'package:he_music_flutter/features/online/presentation/controllers/online_controller.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/settings/domain/settings_catalog.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/settings_page.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/settings_item_presentation_registry.dart';
import 'package:toastification/toastification.dart';

void main() {
  test('setting option labels and descriptions support English', () {
    final config = AppConfigState.initial.copyWith(localeCode: 'en');

    expect(
      AppThemeAccent.values
          .map((item) => settingsThemeAccentLabel(item, config))
          .toList(),
      <String>[
        'Forest',
        'Ocean',
        'Cobalt',
        'Sunset',
        'Rose',
        'Violet',
        'Amber',
        'Midnight',
        'Mint',
        'Cherry',
        'Graphite',
      ],
    );
    expect(
      AppLyricHighlightColor.values
          .map((item) => settingsLyricHighlightColorLabel(item, config))
          .toList(),
      <String>['Sky Blue', 'Emerald', 'Amber', 'Coral', 'Violet'],
    );
    expect(
      AppLyricFontPreset.values
          .map((item) => settingsLyricFontPresetLabel(item, config))
          .toList(),
      <String>['Small', 'Medium', 'Large'],
    );
    expect(
      AppOnlineAudioQuality.values
          .map((item) => settingsOnlineAudioQualityLabel(item, config))
          .toList(),
      <String>[
        'Auto',
        '128mp3',
        '192mp3',
        '320mp3',
        'flac',
        'hires',
        'dolby',
        'galaxy',
        'master',
      ],
    );
    expect(
      settingsOnlineAudioQualityDescription(AppOnlineAudioQuality.auto, config),
      'Select automatically by priority: 320mp3 > hires > flac > 128mp3',
    );
    expect(
      settingsOnlineAudioQualityDescription(
        AppOnlineAudioQuality.mp3128,
        config,
      ),
      'Standard quality, 128 kbps',
    );
    expect(
      settingsOnlineAudioQualityDescription(
        AppOnlineAudioQuality.auto,
        config.copyWith(lastSelectedOnlineAudioQualityName: 'hires'),
      ),
      'Prefer the last manual selection, hires; otherwise use '
      '320mp3 > hires > flac > 128mp3',
    );
    expect(
      settingsItemSubtitle(SettingsItemIds.contentBackground, config),
      'Show translucent backgrounds for cards and list items',
    );
  });

  testWidgets('lyric setting choices follow English locale', (tester) async {
    final container = _createContainer(authToken: null, localeCode: 'en');
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp(container: container));
    await tester.pump();

    await tester.tap(find.text('Lyrics'));
    await tester.pumpAndSettle();

    expect(find.text('Sky Blue'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text('天蓝'), findsNothing);
    expect(find.text('中'), findsNothing);

    await tester.tap(find.text('Lyric Size'));
    await tester.pumpAndSettle();

    expect(find.text('Small'), findsOneWidget);
    expect(find.text('Medium'), findsNWidgets(2));
    expect(find.text('Large'), findsOneWidget);
    expect(find.text('小'), findsNothing);
    expect(find.text('大'), findsNothing);
  });

  testWidgets('mobile settings home shows search and four sections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('settings-search-field')),
      findsOne,
    );
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('播放'), findsOneWidget);
    expect(find.text('歌词'), findsOneWidget);
    expect(find.text('通用'), findsOneWidget);
  });

  testWidgets('城市声场设置搜索图标与歌曲搜索样式一致', (tester) async {
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.graphite,
    ).resolve(AppSkinRegistry.citySoundCreatorId);

    await tester.pumpWidget(_buildSettingsApp(theme: AppTheme.light(skin)));
    await tester.pump();

    final searchIcon = tester.widget<AppSkinIcon>(
      find.descendant(
        of: find.byKey(const ValueKey<String>('settings-search-field')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is AppSkinIcon && widget.role == AppSkinIconRole.search,
        ),
      ),
    );
    expect(searchIcon.size, 18);
    expect(searchIcon.color, skin.light.colorScheme.primary);
  });

  testWidgets('mobile settings opens lyric section with three items', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pump();

    await tester.tap(find.text('歌词'));
    await tester.pumpAndSettle();

    expect(find.text('歌词颜色'), findsOneWidget);
    expect(find.text('歌词大小'), findsOneWidget);
    expect(find.text('逐字歌词'), findsOneWidget);
  });

  testWidgets('playback settings keep separate Wi-Fi and cellular qualities', (
    tester,
  ) async {
    final container = _createContainer(authToken: null, localeCode: 'en');
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_buildSettingsApp(container: container));
    await tester.pump();

    await tester.tap(find.text('Playback'));
    await tester.pumpAndSettle();
    expect(find.text('Wi-Fi Audio Quality'), findsOneWidget);
    expect(find.text('Cellular Audio Quality'), findsOneWidget);

    await tester.tap(find.text('Wi-Fi Audio Quality'));
    await tester.pumpAndSettle();
    final flacOption = find.text('flac').last;
    await tester.ensureVisible(flacOption);
    await tester.pump();
    await tester.tap(flacOption);
    await tester.pumpAndSettle();
    var config = container.read(appConfigProvider);
    expect(config.wifiOnlineAudioQualityPreference, AppOnlineAudioQuality.flac);
    expect(
      config.cellularOnlineAudioQualityPreference,
      AppOnlineAudioQuality.mp3320,
    );

    await tester.tap(find.text('Cellular Audio Quality'));
    await tester.pumpAndSettle();
    final mp3128Option = find.text('128mp3').last;
    await tester.ensureVisible(mp3128Option);
    await tester.pump();
    await tester.tap(mp3128Option);
    await tester.pumpAndSettle();
    config = container.read(appConfigProvider);
    expect(config.wifiOnlineAudioQualityPreference, AppOnlineAudioQuality.flac);
    expect(
      config.cellularOnlineAudioQualityPreference,
      AppOnlineAudioQuality.mp3128,
    );
  });

  testWidgets('mobile appearance section shows grouped settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pump();

    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();

    expect(find.text('主题与配色'), findsOneWidget);
    expect(find.text('显示效果'), findsOneWidget);
    expect(find.text('主题'), findsOneWidget);
    expect(find.text('主题色'), findsOneWidget);
    expect(find.text('皮肤'), findsOneWidget);
    expect(find.text('皮肤动画'), findsOneWidget);
    expect(find.text('显示内容背景'), findsOneWidget);
    expect(find.text('黑白模式'), findsOneWidget);
    expect(find.text('播放器背景样式'), findsNothing);
  });

  testWidgets('content background switch defaults off and updates config', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp(container: container));
    await tester.pump();
    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();

    expect(container.read(appConfigProvider).showContentBackground, isFalse);
    await tester.tap(find.text('显示内容背景'));
    await tester.pump();
    expect(container.read(appConfigProvider).showContentBackground, isTrue);
  });

  testWidgets('content background setting is searchable', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('settings-search-field')),
      '卡片背景',
    );
    await tester.pump();

    expect(find.text('外观 / 显示内容背景'), findsOneWidget);
  });

  testWidgets('settings search updates results without rebuilding scaffold', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pump();
    final initialScaffold = tester.widget<Scaffold>(find.byType(Scaffold));

    await tester.enterText(
      find.byKey(const ValueKey<String>('settings-search-field')),
      '卡片背景',
    );
    await tester.pump();

    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)),
      same(initialScaffold),
    );
    expect(find.text('外观 / 显示内容背景'), findsOneWidget);
  });

  testWidgets(
    'Android general settings show download acceleration after update toggle',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
      });
      tester.view.physicalSize = const Size(1170, 2532);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_buildSettingsApp());
      await tester.pump();
      await tester.tap(find.text('通用'));
      await tester.pumpAndSettle();

      final updateTopLeft = tester.getTopLeft(find.text('自动检查更新'));
      final accelerationTopLeft = tester.getTopLeft(find.text('安装包下载加速'));
      expect(accelerationTopLeft.dy, greaterThan(updateTopLeft.dy));
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('non-Android general settings hide download acceleration', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pump();
    await tester.tap(find.text('通用'));
    await tester.pumpAndSettle();

    expect(find.text('安装包下载加速'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('immersive skin disables manual accent and shows skin state', (
    tester,
  ) async {
    final container = _createContainer(
      authToken: null,
      skinId: AppSkinRegistry.citySoundCreatorId,
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp(container: container));
    await tester.pump();
    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();

    expect(find.text('跟随皮肤'), findsWidgets);
    expect(find.text('城市声场创作者'), findsOneWidget);
    final accentTile = tester.widget<ListTile>(
      find.ancestor(of: find.text('主题色'), matching: find.byType(ListTile)),
    );
    expect(accentTile.onTap, isNull);
    expect(accentTile.enabled, isFalse);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey<String>('settings-item-theme-accent')),
        matching: find.byIcon(Icons.chevron_right_rounded),
      ),
      findsNothing,
    );
  });

  testWidgets('wide settings keeps mobile section list', (tester) async {
    tester.view.physicalSize = const Size(2700, 2700);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pump();

    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('歌词'), findsOneWidget);
    expect(find.text('主题'), findsNothing);
  });

  testWidgets('desktop search jumps to lyric font preset item', (tester) async {
    tester.view.physicalSize = const Size(2700, 2700);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey<String>('settings-search-field')),
      '歌词大小',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('歌词 / 歌词大小'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('settings-item-lyric-font-preset')),
      findsOneWidget,
    );
    expect(find.text('逐字歌词'), findsOneWidget);
  });

  testWidgets('word by word lyric switch updates config state', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp(container: container));
    await tester.pump();

    await tester.tap(find.text('歌词'));
    await tester.pumpAndSettle();

    expect(container.read(appConfigProvider).enableWordByWordLyric, isTrue);

    await tester.tap(find.text('逐字歌词'));
    await tester.pump();

    expect(container.read(appConfigProvider).enableWordByWordLyric, isFalse);
  });

  testWidgets('signed out account section only shows sign in entry', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pump();

    await tester.tap(find.text('帐号'));
    await tester.pumpAndSettle();

    expect(find.text('登录帐号'), findsOneWidget);
    expect(find.text('个人资料'), findsNothing);
    expect(find.text('修改密码'), findsNothing);
    expect(find.text('设备管理'), findsNothing);
    expect(find.text('退出帐号'), findsNothing);
  });

  testWidgets('signed in account section shows all management entries', (
    tester,
  ) async {
    final container = _createContainer(authToken: 'token');
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp(container: container));
    await tester.pump();
    await tester.tap(find.text('帐号'));
    await tester.pumpAndSettle();

    expect(find.text('个人资料'), findsOneWidget);
    expect(find.text('修改密码'), findsOneWidget);
    expect(find.text('设备管理'), findsOneWidget);
    expect(find.text('退出帐号'), findsOneWidget);
    expect(find.text('登录帐号'), findsNothing);

    final logoutText = tester.widget<Text>(find.text('退出帐号'));
    expect(
      logoutText.style?.color,
      Theme.of(tester.element(find.text('退出帐号'))).colorScheme.error,
    );
  });

  testWidgets('signed out search does not expose protected account entries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp());
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey<String>('settings-search-field')),
      '个人资料',
    );
    await tester.pump();

    expect(find.text('帐号 / 登录帐号'), findsOneWidget);
    expect(find.text('帐号 / 个人资料'), findsNothing);
  });

  testWidgets('logout requires confirmation and cancel keeps session', (
    tester,
  ) async {
    final container = _createContainer(authToken: 'token');
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp(container: container));
    await tester.pump();
    await tester.tap(find.text('帐号'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出帐号'));
    await tester.pumpAndSettle();

    expect(find.text('退出帐号？'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    final controller =
        container.read(onlineControllerProvider.notifier)
            as _TestOnlineController;
    expect(controller.logoutCalls, 0);
    expect(container.read(appConfigProvider).authToken, 'token');
  });

  testWidgets('confirmed logout clears session and returns home', (
    tester,
  ) async {
    final container = _createContainer(authToken: 'token');
    addTearDown(container.dispose);
    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp(container: container));
    await tester.pump();
    await tester.tap(find.text('帐号'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出帐号'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '退出帐号'));
    await tester.pumpAndSettle();

    final controller =
        container.read(onlineControllerProvider.notifier)
            as _TestOnlineController;
    expect(controller.logoutCalls, 1);
    expect(container.read(appConfigProvider).authToken, isNull);
    expect(find.text('home-page'), findsOneWidget);
    toastification.dismissAll(delayForAnimation: false);
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('lyric highlight color shows auto summary when mode is auto', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(appConfigProvider.notifier)
        .setLyricHighlightMode(AppLyricHighlightMode.auto);

    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp(container: container));
    await tester.pump();

    await tester.tap(find.text('歌词'));
    await tester.pumpAndSettle();

    expect(find.text('自动'), findsOneWidget);
  });

  testWidgets('settings does not expose player appearance controls', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp(container: container));
    await tester.pump();

    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();

    expect(find.text('播放器背景样式'), findsNothing);
    expect(find.text('播放器样式'), findsNothing);
  });

  testWidgets('language sheet can select system locale', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    tester.view.physicalSize = const Size(1170, 2532);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildSettingsApp(container: container));
    await tester.pump();

    await tester.tap(find.text('通用'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('语言'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('跟随系统'));
    await tester.pumpAndSettle();

    expect(container.read(appConfigProvider).localeCode, 'system');
  });
}

Widget _buildSettingsApp({ProviderContainer? container, ThemeData? theme}) {
  final scopeChild = _SettingsTestApp(
    theme: theme ?? ThemeData(platform: TargetPlatform.android),
  );
  if (container == null) {
    return ProviderScope(child: scopeChild);
  }
  return UncontrolledProviderScope(container: container, child: scopeChild);
}

class _SettingsTestApp extends StatefulWidget {
  const _SettingsTestApp({required this.theme});

  final ThemeData theme;

  @override
  State<_SettingsTestApp> createState() => _SettingsTestAppState();
}

class _SettingsTestAppState extends State<_SettingsTestApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: AppRoutes.settings,
    routes: <GoRoute>[
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const Scaffold(body: Text('home-page')),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.settingsSection,
        builder: (context, state) => SettingsPage(
          sectionId: state.pathParameters['sectionId'],
          highlightedItemId: state.uri.queryParameters['highlight'],
        ),
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(theme: widget.theme, routerConfig: _router);
  }
}

ProviderContainer _createContainer({
  required String? authToken,
  String skinId = AppSkinRegistry.classicId,
  String localeCode = 'zh',
}) {
  return ProviderContainer(
    overrides: [
      appConfigProvider.overrideWith(
        () => _TestAppConfigController(
          authToken: authToken,
          skinId: skinId,
          localeCode: localeCode,
        ),
      ),
      onlineControllerProvider.overrideWith(_TestOnlineController.new),
    ],
  );
}

class _TestAppConfigController extends AppConfigController {
  _TestAppConfigController({
    required this.authToken,
    required this.skinId,
    required this.localeCode,
  });

  final String? authToken;
  final String skinId;
  final String localeCode;

  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(
      authToken: authToken,
      skinId: skinId,
      localeCode: localeCode,
      clearToken: authToken == null,
    );
  }
}

class _TestOnlineController extends OnlineController {
  int logoutCalls = 0;

  @override
  OnlineFeatureState build() => OnlineFeatureState.initial;

  @override
  Future<void> logout() async {
    logoutCalls++;
    ref.read(appConfigProvider.notifier).clearAuthToken();
    state = OnlineFeatureState.initial;
  }
}
