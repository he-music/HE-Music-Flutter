import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/i18n/app_i18n.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_registry.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_models.dart';
import 'package:he_music_flutter/app/theme/player/styles/classic_player_style.dart';

void main() {
  test('built-in registry exposes complete unique styles', () {
    final registry = AppPlayerStyleRegistry.builtIn();

    expect(
      registry.styles.map((style) => style.metadata.id).toSet(),
      AppPlayerStyleRegistry.builtInIds,
    );
    expect(registry.styles, hasLength(9));
    expect(registry.styles.every((style) => style.isValid), isTrue);
    final cadenza = registry.resolve(AppPlayerStyleRegistry.cadenzaLyricsId);
    expect(cadenza.metadata.id, 'cadenza_lyrics');
    expect(cadenza.metadata.labelKey, 'player.style.cadenza_lyrics');
    expect(
      cadenza.metadata.previewAsset,
      'assets/player_styles/cadenza_lyrics/preview.png',
    );
    expect(cadenza.stageKind, AppPlayerStageKind.classic);
    expect(cadenza.lyricsKind, AppPlayerLyricsKind.cadenza);
    expect(AppI18n.cadenzaLyricsNameZh, 'Cadenza 心象');
    expect(AppI18n.cadenzaLyricsDescriptionZh, '按词与片段排布当前歌词，像思绪在画面中浮现');
    expect(AppI18n.cadenzaLyricsNameEn, 'Cadenza Mindscape');
    expect(
      AppI18n.cadenzaLyricsDescriptionEn,
      'Measured words and fragments arrange the current line like thoughts surfacing',
    );
    expect(
      registry.resolve(AppPlayerStyleRegistry.monetLyricsId).lyricsKind,
      AppPlayerLyricsKind.monet,
    );
    expect(
      registry.resolve(AppPlayerStyleRegistry.partitaLyricsId).lyricsKind,
      AppPlayerLyricsKind.partita,
    );
    expect(
      registry.styles
          .where(
            (style) =>
                style.metadata.id != AppPlayerStyleRegistry.monetLyricsId &&
                style.metadata.id != AppPlayerStyleRegistry.partitaLyricsId &&
                style.metadata.id != AppPlayerStyleRegistry.cadenzaLyricsId,
          )
          .every((style) => style.lyricsKind == AppPlayerLyricsKind.legacy),
      isTrue,
    );
    expect(
      registry
          .resolve(AppPlayerStyleRegistry.radialSpectrumId)
          .usesRealtimeSpectrum,
      isTrue,
    );
    expect(
      registry.styles
          .where(
            (style) =>
                style.metadata.id != AppPlayerStyleRegistry.radialSpectrumId,
          )
          .every((style) => !style.usesRealtimeSpectrum),
      isTrue,
    );
  });

  test('unknown and empty ids resolve to classic', () {
    final registry = AppPlayerStyleRegistry.builtIn();

    expect(registry.normalizeId(null), AppPlayerStyleRegistry.classicId);
    expect(registry.normalizeId(''), AppPlayerStyleRegistry.classicId);
    expect(
      registry.resolve('removed').metadata.id,
      AppPlayerStyleRegistry.classicId,
    );
  });

  test('classic-backed styles share backdrop base colors', () {
    final registry = AppPlayerStyleRegistry.builtIn();
    final classicColors = registry
        .resolve(AppPlayerStyleRegistry.classicId)
        .colors;

    for (final id in <String>{
      AppPlayerStyleRegistry.vinylId,
      AppPlayerStyleRegistry.cassetteId,
      AppPlayerStyleRegistry.radialSpectrumId,
      AppPlayerStyleRegistry.monetLyricsId,
      AppPlayerStyleRegistry.partitaLyricsId,
      AppPlayerStyleRegistry.cadenzaLyricsId,
    }) {
      final colors = registry.resolve(id).colors;
      expect(colors.backgroundStart, classicColors.backgroundStart, reason: id);
      expect(colors.backgroundEnd, classicColors.backgroundEnd, reason: id);
    }
  });

  test('registry rejects duplicate ids', () {
    expect(
      () => AppPlayerStyleRegistry(const [
        classicPlayerStyle,
        classicPlayerStyle,
      ]),
      throwsStateError,
    );
  });
}
