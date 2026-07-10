import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_message_service.dart';
import '../../app/i18n/app_i18n.dart';
import '../../app/router/app_routes.dart';
import '../models/he_music_models.dart';

Future<void> openSongArtistSelection({
  required BuildContext context,
  required String platformId,
  required List<SongInfoArtistInfo> artists,
  ValueChanged<String>? onError,
}) async {
  final availableArtists = _normalizeArtists(artists);
  final localeCode = Localizations.localeOf(context).languageCode;
  if (availableArtists.isEmpty) {
    final message = AppI18n.tByLocaleCode(
      localeCode,
      'song.artist.unavailable',
    );
    if (onError != null) {
      onError(message);
      return;
    }
    AppMessageService.showWarning(message);
    return;
  }

  if (availableArtists.length == 1) {
    _openArtistDetail(
      context: context,
      platformId: platformId,
      artist: availableArtists.first,
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final maxHeight = MediaQuery.of(sheetContext).size.height * 0.52;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              ListTile(
                title: Text(
                  AppI18n.tByLocaleCode(localeCode, 'song.artist.select'),
                ),
                subtitle: Text(
                  AppI18n.formatByLocaleCode(
                    localeCode,
                    'song.artist.count',
                    <String, String>{'count': '${availableArtists.length}'},
                  ),
                ),
              ),
              const Divider(height: 1),
              ...availableArtists.map(
                (artist) => ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(artist.name),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openArtistDetail(
                      context: context,
                      platformId: platformId,
                      artist: artist,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

String? songArtistActionLabel(
  List<SongInfoArtistInfo> artists, {
  String localeCode = 'zh',
}) {
  final availableArtists = _normalizeArtists(artists);
  if (availableArtists.isEmpty) {
    return null;
  }
  if (availableArtists.length == 1) {
    return AppI18n.tByLocaleCode(localeCode, 'player.action.view_artists');
  }
  return AppI18n.formatByLocaleCode(
    localeCode,
    'player.action.view_artists_count',
    <String, String>{'count': '${availableArtists.length}'},
  );
}

List<SongInfoArtistInfo> _normalizeArtists(List<SongInfoArtistInfo> artists) {
  final result = <SongInfoArtistInfo>[];
  final seen = <String>{};
  for (final artist in artists) {
    final id = artist.id.trim();
    final name = artist.name.trim();
    if (id.isEmpty || name.isEmpty) {
      continue;
    }
    final key = '$id|$name';
    if (seen.add(key)) {
      result.add(SongInfoArtistInfo(id: id, name: name));
    }
  }
  return result;
}

void _openArtistDetail({
  required BuildContext context,
  required String platformId,
  required SongInfoArtistInfo artist,
}) {
  final uri = Uri(
    path: AppRoutes.artistDetail,
    queryParameters: <String, String>{
      'type': 'artist',
      'id': artist.id,
      'platform': platformId,
      'title': artist.name,
    },
  );
  context.push(uri.toString());
}
