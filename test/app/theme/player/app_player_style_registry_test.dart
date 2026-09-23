import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_registry.dart';
import 'package:he_music_flutter/app/theme/player/app_player_style_models.dart';
import 'package:he_music_flutter/app/theme/player/styles/classic_player_style.dart';

void main() {
  test('stage registry exposes four unique stage options', () {
    final registry = AppPlayerStageRegistry.builtIn();

    expect(
      registry.options.map((o) => o.metadata.id).toSet(),
      AppPlayerStageRegistry.builtInIds,
    );
    expect(registry.options, hasLength(4));
    expect(registry.options.every((o) => o.isValid), isTrue);
    expect(
      registry.resolve(AppPlayerStageRegistry.classicId).stageKind,
      AppPlayerStageKind.classic,
    );
    expect(
      registry.resolve(AppPlayerStageRegistry.vinylId).stageKind,
      AppPlayerStageKind.vinyl,
    );
    expect(
      registry.resolve(AppPlayerStageRegistry.cassetteId).stageKind,
      AppPlayerStageKind.cassette,
    );
    expect(
      registry.resolve(AppPlayerStageRegistry.radialSpectrumId).stageKind,
      AppPlayerStageKind.radialSpectrum,
    );
    expect(
      registry
          .resolve(AppPlayerStageRegistry.radialSpectrumId)
          .usesRealtimeSpectrum,
      isTrue,
    );
    expect(registry.normalizeId(null), AppPlayerStageRegistry.classicId);
    expect(registry.normalizeId(''), AppPlayerStageRegistry.classicId);
    expect(
      registry.resolve('removed').metadata.id,
      AppPlayerStageRegistry.classicId,
    );
  });

  test('backdrop registry exposes three unique backdrop options', () {
    final registry = AppPlayerBackdropRegistry.builtIn();

    expect(
      registry.options.map((o) => o.metadata.id).toSet(),
      AppPlayerBackdropRegistry.builtInIds,
    );
    expect(registry.options, hasLength(3));
    expect(registry.options.every((o) => o.isValid), isTrue);
    expect(
      registry.resolve(AppPlayerBackdropRegistry.coverGradientId).backdropKind,
      AppPlayerBackdropKind.coverGradient,
    );
    expect(
      registry.resolve(AppPlayerBackdropRegistry.fluidId).backdropKind,
      AppPlayerBackdropKind.fluid,
    );
    expect(
      registry.resolve(AppPlayerBackdropRegistry.artistPhotoId).backdropKind,
      AppPlayerBackdropKind.artistPhoto,
    );
    expect(
      registry.normalizeId(null),
      AppPlayerBackdropRegistry.coverGradientId,
    );
    expect(registry.normalizeId(''), AppPlayerBackdropRegistry.coverGradientId);
    expect(
      registry.resolve('removed').metadata.id,
      AppPlayerBackdropRegistry.coverGradientId,
    );
  });

  test('lyrics registry exposes eleven unique lyric options', () {
    final registry = AppPlayerLyricsRegistry.builtIn();

    expect(
      registry.options.map((o) => o.metadata.id).toSet(),
      AppPlayerLyricsRegistry.builtInIds,
    );
    expect(registry.options, hasLength(11));
    expect(registry.options.every((o) => o.isValid), isTrue);
    expect(
      registry.resolve(AppPlayerLyricsRegistry.legacyId).lyricsKind,
      AppPlayerLyricsKind.legacy,
    );
    expect(
      registry.resolve(AppPlayerLyricsRegistry.monetId).lyricsKind,
      AppPlayerLyricsKind.monet,
    );
    expect(
      registry.resolve(AppPlayerLyricsRegistry.cinemaId).lyricsKind,
      AppPlayerLyricsKind.cinema,
    );
    expect(
      registry.resolve(AppPlayerLyricsRegistry.partitaId).lyricsKind,
      AppPlayerLyricsKind.partita,
    );
    expect(
      registry.resolve(AppPlayerLyricsRegistry.cadenzaId).lyricsKind,
      AppPlayerLyricsKind.cadenza,
    );
    expect(
      registry.resolve(AppPlayerLyricsRegistry.tiltId).lyricsKind,
      AppPlayerLyricsKind.tilt,
    );
    expect(
      registry.resolve(AppPlayerLyricsRegistry.pendoloId).lyricsKind,
      AppPlayerLyricsKind.pendolo,
    );
    expect(
      registry.resolve(AppPlayerLyricsRegistry.starTunnelId).lyricsKind,
      AppPlayerLyricsKind.starTunnel,
    );
    expect(
      registry.resolve(AppPlayerLyricsRegistry.kineticId).lyricsKind,
      AppPlayerLyricsKind.kinetic,
    );
    expect(
      registry.resolve(AppPlayerLyricsRegistry.claddaghId).lyricsKind,
      AppPlayerLyricsKind.claddagh,
    );
    expect(
      registry.resolve(AppPlayerLyricsRegistry.foldId).lyricsKind,
      AppPlayerLyricsKind.fold,
    );
    expect(registry.normalizeId(null), AppPlayerLyricsRegistry.legacyId);
    expect(registry.normalizeId(''), AppPlayerLyricsRegistry.legacyId);
    expect(
      registry.resolve('removed').metadata.id,
      AppPlayerLyricsRegistry.legacyId,
    );
  });

  test(
    'removed lyric styles resolve to cinema without appearing as options',
    () {
      final registry = AppPlayerLyricsRegistry.builtIn();

      for (final id in ['tide_lyrics', 'refraction_lyrics']) {
        expect(registry.contains(id), isFalse);
        expect(
          registry.options.map((option) => option.metadata.id),
          isNot(contains(id)),
        );
        expect(registry.normalizeId(id), AppPlayerLyricsRegistry.cinemaId);
        expect(registry.resolve(id).lyricsKind, AppPlayerLyricsKind.cinema);
      }
    },
  );

  test('stage registry rejects duplicate ids', () {
    expect(
      () => AppPlayerStageRegistry([classicPlayerStage, classicPlayerStage]),
      throwsStateError,
    );
  });
}
