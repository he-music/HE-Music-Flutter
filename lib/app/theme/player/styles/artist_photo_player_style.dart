import 'package:flutter/material.dart';

import '../app_player_style_models.dart';

/// 歌手写真满屏背景（选中时隐藏前景封面舞台）。
const AppPlayerBackdropOption artistPhotoPlayerBackdrop =
    AppPlayerBackdropOption(
      metadata: AppPlayerStyleMetadata(
        id: 'artist_photo',
        labelKey: 'player.style.artist_photo',
        previewAsset: 'assets/player_styles/artist_photo/preview.png',
      ),
      backdropKind: AppPlayerBackdropKind.artistPhoto,
      backgroundStart: Color(0xFF343A3B),
      backgroundEnd: Color(0xFF101313),
    );