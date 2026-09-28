import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/features/ranking/domain/entities/ranking_info.dart';
import 'package:he_music_flutter/features/ranking/domain/entities/ranking_preview_song.dart';
import 'package:he_music_flutter/features/ranking/presentation/widgets/ranking_cards.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';
import 'package:he_music_flutter/shared/widgets/artist_grid_card.dart';

void main() {
  testWidgets('大字体下歌手卡片的文字不被固定高度裁切', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 160,
          height: 190,
          child: ArtistGridCard(
            artist: ArtistInfo.fromMap(<String, dynamic>{
              'name': '歌手 Artist',
              'alias': '别名 Alias',
            }),
            onTap: () {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    for (final text in <String>['歌手 Artist', '别名 Alias']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
        ),
      );
    }
  });

  testWidgets('大字体下排行榜高度容纳全部三首预览歌曲', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 320,
          child: RankingCards(
            rankings: const <RankingInfo>[
              RankingInfo(
                id: '1',
                platform: '',
                name: '排行榜',
                coverUrl: '',
                previewSongs: <RankingPreviewSong>[
                  RankingPreviewSong(name: '一', artist: 'A'),
                  RankingPreviewSong(name: '二', artist: 'B'),
                  RankingPreviewSong(name: '三', artist: 'C'),
                ],
              ),
            ],
            onTap: (_) {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final cardRect = tester.getRect(find.byType(InkWell));
    expect(
      tester.getRect(find.text('3. 三 - C')).bottom,
      lessThanOrEqualTo(cardRect.bottom),
    );
  });
}

Widget _wrap(Widget child) => ProviderScope(
  overrides: [appConfigProvider.overrideWith(_TestAppConfigController.new)],
  child: MaterialApp(
    home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(3.2)),
      child: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  ),
);

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial.copyWith(localeCode: 'zh');
}
