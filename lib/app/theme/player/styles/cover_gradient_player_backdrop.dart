import '../app_player_style_models.dart';
import 'classic_player_style.dart';

/// 封面色渐变背景（共享 _ClassicGradientBackdrop）。
const AppPlayerBackdropOption coverGradientPlayerBackdrop =
    AppPlayerBackdropOption(
      metadata: AppPlayerStyleMetadata(
        id: 'cover_gradient',
        labelKey: 'player.style.cover_gradient',
        previewAsset: 'assets/player_styles/cover_gradient/preview.png',
      ),
      backdropKind: AppPlayerBackdropKind.coverGradient,
      backgroundStart: classicPlayerBackgroundStart,
      backgroundEnd: classicPlayerBackgroundEnd,
    );