import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../helpers/player_artwork_helper.dart';

/// 播放器封面组件，带发光效果
class PlayerCoverHero extends StatelessWidget {
  const PlayerCoverHero({
    super.key,
    required this.artworkUrl,
    required this.artworkBytes,
    required this.size,
  });

  final String? artworkUrl;
  final Uint8List? artworkBytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageProvider = artworkProvider(artworkUrl, artworkBytes);
    final glowColor = Theme.of(
      context,
    ).colorScheme.primary.withValues(alpha: 0.16);
    return SizedBox(
      width: size + 56,
      height: size + 56,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: size * 0.92,
            height: size * 0.92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  glowColor,
                  glowColor.withValues(alpha: 0.06),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, 6),
            child: Opacity(
              opacity: 0.18,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: imageProvider == null
                    ? Container(
                        width: size * 0.88,
                        height: size * 0.88,
                        color: glowColor,
                      )
                    : Image(
                        image: imageProvider,
                        width: size * 0.88,
                        height: size * 0.88,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: size * 0.88,
                          height: size * 0.88,
                          color: glowColor,
                        ),
                      ),
              ),
            ),
          ),
          _PlayerCover(
            artworkUrl: artworkUrl,
            artworkBytes: artworkBytes,
            size: size,
          ),
        ],
      ),
    );
  }
}

class _PlayerCover extends StatelessWidget {
  const _PlayerCover({
    required this.artworkUrl,
    required this.artworkBytes,
    required this.size,
  });

  final String? artworkUrl;
  final Uint8List? artworkBytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageProvider = artworkProvider(artworkUrl, artworkBytes);
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
      ),
      child: const Icon(Icons.music_note_rounded, size: 96),
    );
    if (imageProvider == null) {
      return placeholder;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: Image(
        image: imageProvider,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) => placeholder,
      ),
    );
  }
}
