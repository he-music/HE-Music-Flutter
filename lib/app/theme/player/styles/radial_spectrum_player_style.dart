import '../app_player_style_models.dart';

const AppPlayerStageOption radialSpectrumPlayerStage = AppPlayerStageOption(
  metadata: AppPlayerStyleMetadata(
    id: 'radial_spectrum',
    labelKey: 'player.style.radial_spectrum',
    previewAsset: 'assets/player_styles/radial_spectrum/preview.png',
  ),
  stageKind: AppPlayerStageKind.radialSpectrum,
  stageMaxWidth: 440,
  usesRealtimeSpectrum: true,
);