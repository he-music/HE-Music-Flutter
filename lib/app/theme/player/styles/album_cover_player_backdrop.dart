import 'package:flutter/material.dart';

import '../app_player_style_models.dart';

/// 复用写真背景的图片呈现，始终显示当前歌曲封面。
const AppPlayerBackdropOption albumCoverPlayerBackdrop =
    AppPlayerBackdropOption(
      metadata: AppPlayerStyleMetadata(
        id: 'album_cover',
        labelKey: 'player.style.album_cover',
        previewAsset: 'assets/player_styles/album_cover/preview.png',
      ),
      backdropKind: AppPlayerBackdropKind.albumCover,
      backgroundStart: Color(0xFF343A3B),
      backgroundEnd: Color(0xFF101313),
    );
