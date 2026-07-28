import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/player/presentation/layout/player_layout_spec.dart';

void main() {
  test('player layout spec resolves portrait landscape and desktop modes', () {
    const cases = <(Size, PlayerLayoutMode)>[
      (Size(430, 932), PlayerLayoutMode.mobilePortrait),
      (Size(932, 430), PlayerLayoutMode.mobileLandscape),
      (Size(844, 390), PlayerLayoutMode.mobileLandscape),
      (Size(700, 420), PlayerLayoutMode.mobileLandscape),
      (Size(1024, 768), PlayerLayoutMode.desktop),
      (Size(1440, 960), PlayerLayoutMode.desktop),
    ];

    for (final (size, expectedMode) in cases) {
      final spec = PlayerLayoutSpec.resolve(BoxConstraints.tight(size));

      expect(spec.mode, expectedMode, reason: '$size');
      if (expectedMode == PlayerLayoutMode.mobileLandscape) {
        expect(spec.pageGutter, 4, reason: '$size');
      }
    }
  });

  test('landscape safe insets combine gestures and edge cutouts', () {
    final insets = resolvePlayerLandscapeSafeInsets(
      size: const Size(844, 390),
      systemGestureInsets: const EdgeInsets.only(left: 16, bottom: 20),
      displayFeatures: const <DisplayFeature>[
        DisplayFeature(
          bounds: Rect.fromLTWH(0, 140, 32, 50),
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
        DisplayFeature(
          bounds: Rect.fromLTWH(824, 160, 20, 40),
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
      ],
    );

    expect(insets, const EdgeInsets.fromLTRB(32, 0, 20, 20));
  });

  test(
    'landscape content absorbs safe space already reserved by exit rail',
    () {
      expect(
        resolvePlayerLandscapeContentInsets(
          const EdgeInsets.fromLTRB(44, 12, 24, 20),
        ),
        const EdgeInsets.fromLTRB(0, 12, 24, 20),
      );
      expect(
        resolvePlayerLandscapeContentInsets(
          const EdgeInsets.fromLTRB(80, 12, 24, 20),
        ),
        const EdgeInsets.fromLTRB(20, 12, 24, 20),
      );
    },
  );
}
