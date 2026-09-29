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
import 'package:he_music_flutter/shared/widgets/video_item.dart';
import 'package:he_music_flutter/shared/widgets/song_batch_action_bar.dart';
import 'package:he_music_flutter/features/online/presentation/pages/online_search_bars.dart';
import 'package:he_music_flutter/shared/widgets/artist_grid_card.dart';

void main() {
  testWidgets('large text fits video list and grid cards', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              VideoListItem(
                title: '很长的视频标题 Video title',
                creator: '视频作者 Creator',
                coverUrl: '',
                onTap: () {},
              ),
              SizedBox(
                width: 140,
                height: 140 / videoGridItemChildAspectRatio,
                child: VideoGridItem(
                  title: '网格视频标题',
                  creator: '网格视频作者',
                  coverUrl: '',
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    for (final text in ['视频作者 Creator', '网格视频标题', '网格视频作者']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
        ),
      );
    }
  });

  testWidgets('search placeholder and input follow large text', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 280,
          child: SearchTopBox(
            controller: controller,
            placeholderPrimary: '搜索音乐',
            onSubmit: () async {},
            onChanged: (_) {},
          ),
        ),
      ),
    );
    final placeholder = tester.widget<RichText>(
      find.text('搜索音乐', findRichText: true),
    );
    expect(placeholder.textScaler.scale(14), closeTo(44.8, 0.01));
    await tester.enterText(find.byType(TextField), '测试歌曲');
    await tester.pump();
    final editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    expect(
      editable.size.height,
      greaterThanOrEqualTo(editable.preferredLineHeight),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('batch action labels retain two lines at large text', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 320,
          child: SongBatchActionBar(
            enabled: true,
            onRemoveFromPlaylistPressed: () {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    for (final element in find.byType(Text).evaluate()) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.byWidget(element.widget),
      );
      expect(
        paragraph.size.height,
        greaterThanOrEqualTo(
          paragraph.getMaxIntrinsicHeight(paragraph.size.width) - 0.01,
        ),
      );
    }
  });
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
