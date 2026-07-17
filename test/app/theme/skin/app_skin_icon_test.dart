import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_asset_resolver.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_icon.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/app/theme/skins/classic_skin.dart';

void main() {
  testWidgets('classic icon renders the role fallback at requested sizes', (
    tester,
  ) async {
    final classic = classicSkinForAccent(AppThemeAccent.forest);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(classic),
        home: const Row(
          children: <Widget>[
            AppSkinIcon(role: AppSkinIconRole.search, size: 20),
            AppSkinIcon(role: AppSkinIconRole.search, size: 24),
          ],
        ),
      ),
    );

    final icons = tester.widgetList<Icon>(find.byIcon(Icons.search_rounded));
    expect(icons.map((icon) => icon.size), containsAll(<double>[20, 24]));
  });

  testWidgets('successful svg load uses the themed asset', (tester) async {
    final skin = _skinWithSearchAsset();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(skin),
        home: AppSkinIcon(
          role: AppSkinIconRole.search,
          size: 24,
          color: Colors.red,
          semanticLabel: 'Search',
          assetResolver: const _SvgResolver(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.bySemanticsLabel('Search'), findsOneWidget);
    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    final colorMapper = (picture.bytesLoader as SvgBytesLoader).colorMapper!;
    expect(
      colorMapper.substitute(null, 'path', 'fill', Colors.black),
      Colors.red,
    );
    expect(
      colorMapper.substitute(null, 'path', 'fill', Colors.yellow),
      Colors.yellow,
    );
  });

  testWidgets('svg load failure falls back to the classic role', (
    tester,
  ) async {
    final skin = _skinWithSearchAsset();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(skin),
        home: const AppSkinIcon(
          role: AppSkinIconRole.search,
          assetResolver: _FailingResolver(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
  });

  testWidgets('city skin renders every role at 20 and 24 in both themes', (
    tester,
  ) async {
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.graphite,
    ).resolve('city_sound_creator');

    for (final brightness in Brightness.values) {
      final theme = brightness == Brightness.light
          ? AppTheme.light(skin)
          : AppTheme.dark(skin);
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey<Brightness>(brightness),
          theme: theme,
          home: SingleChildScrollView(
            child: Wrap(
              children: <Widget>[
                for (final role in AppSkinIconRole.values) ...<Widget>[
                  AppSkinIcon(role: role, size: 20),
                  AppSkinIcon(role: role, size: 24),
                ],
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final pictures = tester.widgetList<SvgPicture>(find.byType(SvgPicture));
      expect(pictures, hasLength(AppSkinIconRole.values.length * 2));
      expect(
        pictures.where((picture) => picture.width == 20),
        hasLength(AppSkinIconRole.values.length),
      );
      expect(
        pictures.where((picture) => picture.width == 24),
        hasLength(AppSkinIconRole.values.length),
      );
    }
  });

  testWidgets('city icon replaces only the declared coral source color', (
    tester,
  ) async {
    final skin = AppSkinRegistry.builtIn(
      AppThemeAccent.graphite,
    ).resolve('city_sound_creator');
    const replacement = Color(0xFF7C4DFF);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(skin),
        home: const AppSkinIcon(
          role: AppSkinIconRole.settingsPassword,
          size: 24,
          color: replacement,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
    final colorMapper = (picture.bytesLoader as SvgBytesLoader).colorMapper!;
    expect(
      colorMapper.substitute(null, 'path', 'stroke', const Color(0xFFE85D52)),
      replacement,
    );
    expect(
      colorMapper.substitute(null, 'circle', 'fill', const Color(0xFF138F87)),
      const Color(0xFF138F87),
    );
    expect(
      colorMapper.substitute(null, 'circle', 'fill', const Color(0xFFE7B93E)),
      const Color(0xFFE7B93E),
    );
  });
}

AppSkinPackage _skinWithSearchAsset() {
  final classic = classicSkinForAccent(AppThemeAccent.forest);
  final fallback = classic.icons[AppSkinIconRole.search]!;
  return classic.copyWith(
    icons: classic.icons.copyWith(
      overrides: <AppSkinIconRole, AppSkinIconSpec>{
        AppSkinIconRole.search: AppSkinIconSpec(
          asset: const AppSkinAssetSlot.asset(
            AppSkinAssetDescriptor(
              path: 'assets/skins/test/search.svg',
              type: AppSkinAssetType.svg,
              themeColorSource: Color(0xFF000000),
            ),
          ),
          fallbackIcon: fallback.fallbackIcon,
        ),
      },
    ),
  );
}

class _SvgResolver implements AppSkinAssetResolver {
  const _SvgResolver();

  @override
  Future<AppSkinAssetLoadResult> load(AppSkinAssetDescriptor descriptor) async {
    const svg =
        '<svg viewBox="0 0 24 24"><path fill="#000000" d="M0 0h24v24H0z"/></svg>';
    final bytes = Uint8List.fromList(svg.codeUnits);
    return AppSkinAssetLoadSuccess(bytes.buffer.asByteData());
  }
}

class _FailingResolver implements AppSkinAssetResolver {
  const _FailingResolver();

  @override
  Future<AppSkinAssetLoadResult> load(AppSkinAssetDescriptor descriptor) async {
    return AppSkinAssetLoadFailure(StateError('missing'));
  }
}
