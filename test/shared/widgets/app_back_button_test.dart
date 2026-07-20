import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skins/city_sound_creator_skin.dart';
import 'package:he_music_flutter/shared/widgets/app_back_button.dart';

void main() {
  testWidgets('renders localized back tooltip and default icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
        ],
        child: const MaterialApp(home: Scaffold(body: AppBackButton())),
      ),
    );

    expect(find.byTooltip('返回'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });

  testWidgets('city skin back button renders configured back SVG', (
    tester,
  ) async {
    final skin = citySoundCreatorSkin();
    expect(
      skin.icons[AppSkinIconRole.back]?.asset.descriptor?.path,
      'assets/skins/city_sound_creator/icons/back.svg',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light(skin),
          home: const Scaffold(body: AppBackButton()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect((picture.bytesLoader as SvgBytesLoader).colorMapper, isNull);
  });

  testWidgets('navigates to fallback when route cannot pop', (tester) async {
    final router = GoRouter(
      initialLocation: '/leaf',
      routes: <RouteBase>[
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/leaf',
          builder: (context, state) =>
              const Scaffold(body: AppBackButton(fallbackLocation: '/')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWith(_TestAppConfigController.new),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.byType(AppBackButton));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'zh');
  }
}
