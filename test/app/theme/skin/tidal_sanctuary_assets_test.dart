import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_theme_accent.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_registry.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_theme.dart';
import 'package:he_music_flutter/app/theme/skins/classic_skin.dart';

void main() {
  test(
    'tidal assets are bundled, documented and separate from production sources',
    () async {
      final registry = AppSkinRegistry.builtIn(AppThemeAccent.rose);
      final skin = registry.resolve(AppSkinRegistry.tidalSanctuaryId);
      final pubspec = await File('pubspec.yaml').readAsString();
      final provenance = await File(
        'assets/skins/tidal_sanctuary/README.md',
      ).readAsString();
      final paths = <String>{
        skin.metadata.lightPreview.descriptor!.path,
        skin.metadata.darkPreview.descriptor!.path,
        for (final brightness in Brightness.values) ...[
          skin.configFor(brightness).background.wallpaper.descriptor!.path,
          (skin.configFor(brightness).background.animation
                  as AppSkinRiveAnimationDescriptor)
              .asset
              .path,
        ],
        for (final spec in skin.icons.values.values)
          if (spec.asset.descriptor != null) spec.asset.descriptor!.path,
      };
      for (final path in paths) {
        final bytes = await File(path).readAsBytes();
        expect(bytes, isNotEmpty, reason: path);
        expect(
          provenance,
          contains(sha256.convert(bytes).toString()),
          reason: path,
        );
        expect(
          pubspec,
          contains(path.endsWith('.svg') ? '${File(path).parent.path}/' : path),
        );
      }
      expect(pubspec, isNot(contains('assets/skins/tidal_sanctuary/source')));
      expect(paths.where((path) => path.endsWith('.svg')), hasLength(9));
      expect(skin.icons.values, hasLength(AppSkinIconRole.values.length));
      expect(skin.metadata.allowsManualAccent, isFalse);
      expect(registry.normalizeId('tidal_sanctuary'), 'tidal_sanctuary');
      final customRegistry = AppSkinRegistry.withCustom(
        AppThemeAccent.graphite,
        null,
      );
      expect(
        customRegistry.resolve('tidal_sanctuary').metadata.id,
        'tidal_sanctuary',
      );
    },
  );

  test(
    'tidal controls stay translucent while sheets and content preferences are independent',
    () {
      final skin = AppSkinRegistry.builtIn(
        AppThemeAccent.graphite,
      ).resolve(AppSkinRegistry.tidalSanctuaryId);
      final classic = classicSkinForAccent(AppThemeAccent.graphite);
      for (final brightness in Brightness.values) {
        final config = skin.configFor(brightness);
        final theme = brightness == Brightness.light
            ? AppTheme.light(skin)
            : AppTheme.dark(skin);
        final surface = theme.extension<AppSkinTheme>()!;
        expect(config.sheetMotif, AppSkinSheetMotif.tidal);
        expect(
          config.colorScheme,
          isNot(classic.configFor(brightness).colorScheme),
        );
        expect(surface.miniPlayerBackgroundColor.a, inExclusiveRange(0, 1));
        expect(
          surface.navigationBackgroundColor.a,
          lessThan(surface.miniPlayerBackgroundColor.a),
        );
        expect(config.colors.bottomSheetBackground.a, 1);
        expect(config.surfaces.bottomSheetOpacity, 1);
        final hidden = surface.copyWith(showContentBackground: false);
        final shown = surface.copyWith(showContentBackground: true);
        expect(hidden.contentBackgroundColor.a, 0);
        expect(shown.contentBackgroundColor.a, greaterThan(0));
        expect(
          hidden.miniPlayerBackgroundColor,
          shown.miniPlayerBackgroundColor,
        );
        expect(
          hidden.navigationBackgroundColor,
          shown.navigationBackgroundColor,
        );
      }
    },
  );
}
