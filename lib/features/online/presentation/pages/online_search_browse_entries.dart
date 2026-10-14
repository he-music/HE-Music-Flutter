import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../../app/theme/skin/app_skin_icon.dart';
import '../../../../app/theme/skin/app_skin_models.dart';

const _entries = <({String route, AppSkinIconRole iconRole, String titleKey})>[
  (
    route: AppRoutes.rankingList,
    iconRole: AppSkinIconRole.homeRanking,
    titleKey: 'home.entry.ranking',
  ),
  (
    route: AppRoutes.playlistPlaza,
    iconRole: AppSkinIconRole.homePlaylist,
    titleKey: 'home.entry.playlist',
  ),
  (
    route: AppRoutes.artistPlaza,
    iconRole: AppSkinIconRole.homeArtist,
    titleKey: 'home.entry.artist',
  ),
  (
    route: AppRoutes.videoPlaza,
    iconRole: AppSkinIconRole.homeVideo,
    titleKey: 'home.entry.video',
  ),
  (
    route: AppRoutes.radioPlaza,
    iconRole: AppSkinIconRole.homeRadio,
    titleKey: 'home.entry.radio',
  ),
];

class OnlineSearchBrowseEntries extends StatelessWidget {
  const OnlineSearchBrowseEntries({
    required this.localeCode,
    required this.platform,
    super.key,
  });

  final String localeCode;
  final String platform;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodySmall;
    final fontSize = textStyle?.fontSize ?? 12;
    final minItemWidth =
        64.0 *
        math.max(
          1.0,
          MediaQuery.textScalerOf(context).scale(fontSize) / fontSize,
        );
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: LayoutTokens.compactPageGutter + 2,
        ),
        child: SizedBox(
          width: math.max(
            constraints.maxWidth - (LayoutTokens.compactPageGutter + 2) * 2,
            minItemWidth * _entries.length,
          ),
          child: Material(
            color: Colors.transparent,
            child: Row(
              children: _entries
                  .map((entry) {
                    final title = AppI18n.tByLocaleCode(
                      localeCode,
                      entry.titleKey,
                    );
                    return Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          context.push(
                            Uri(
                              path: entry.route,
                              queryParameters: <String, String>{
                                if (platform.isNotEmpty) 'platform': platform,
                              },
                            ).toString(),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 10,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              AppSkinIcon(
                                role: entry.iconRole,
                                color: theme.colorScheme.primary,
                                size: 22,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                title,
                                style: textStyle,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }
}
