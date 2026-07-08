import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_network_image.dart';

import '../../../../app/i18n/app_i18n.dart';

class SearchArtistListItem extends StatelessWidget {
  const SearchArtistListItem({
    required this.localeCode,
    required this.title,
    required this.coverUrl,
    required this.songCount,
    required this.albumCount,
    required this.videoCount,
    required this.onTap,
    super.key,
  });

  final String localeCode;
  final String title;
  final String coverUrl;
  final String songCount;
  final String albumCount;
  final String videoCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: <Widget>[
              _Cover(url: coverUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _StatsLine(
                      localeCode: localeCode,
                      songCount: songCount,
                      albumCount: albumCount,
                      videoCount: videoCount,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsLine extends StatelessWidget {
  const _StatsLine({
    required this.localeCode,
    required this.songCount,
    required this.albumCount,
    required this.videoCount,
  });

  final String localeCode;
  final String songCount;
  final String albumCount;
  final String videoCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatText(
            value: songCount,
            label: AppI18n.tByLocaleCode(localeCode, 'artist.label.song'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatText(
            value: albumCount,
            label: AppI18n.tByLocaleCode(localeCode, 'artist.label.album'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatText(
            value: videoCount,
            label: AppI18n.tByLocaleCode(localeCode, 'artist.label.video'),
          ),
        ),
      ],
    );
  }
}

class _StatText extends StatelessWidget {
  const _StatText({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              height: 1.0,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.hintColor,
              fontSize: 11,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.person_rounded,
        size: 28,
        color: Theme.of(context).hintColor,
      ),
    );
    if (url.trim().isEmpty) {
      return fallback;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AppNetworkImage(
        url: url,
        width: 68,
        height: 68,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        cacheWidth: 220,
        fallback: fallback,
      ),
    );
  }
}
