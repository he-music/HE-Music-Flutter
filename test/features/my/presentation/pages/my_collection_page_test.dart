import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/theme/app_theme.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_icon.dart';
import 'package:he_music_flutter/app/theme/skin/app_skin_models.dart';
import 'package:he_music_flutter/app/theme/skins/city_sound_creator_skin.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_collection_state.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_item.dart';
import 'package:he_music_flutter/features/my/domain/entities/my_favorite_type.dart';
import 'package:he_music_flutter/features/my/presentation/controllers/my_collection_controller.dart';
import 'package:he_music_flutter/features/my/presentation/pages/my_collection_page.dart';
import 'package:he_music_flutter/features/my/presentation/providers/my_collection_providers.dart';
import 'package:he_music_flutter/shared/widgets/song_list_component.dart';

void main() {
  testWidgets('my collection first load shows only the list skeleton', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp(MyCollectionState.initial));
    await tester.pump();

    final list = tester.widget<SongListComponent>(
      find.byType(SongListComponent),
    );
    expect(list.initialLoading, isTrue);
    expect(find.text('暂无收藏内容'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('my collection refresh keeps existing items visible', (
    tester,
  ) async {
    const item = MyFavoriteItem(
      id: 'playlist-1',
      platform: 'qq',
      type: MyFavoriteType.playlists,
      title: '保留的歌单',
      subtitle: '测试用户',
      coverUrl: '',
    );
    final state = MyCollectionState.initial.copyWith(
      loading: true,
      playlists: const <MyFavoriteItem>[item],
    );

    await tester.pumpWidget(_buildTestApp(state));
    await tester.pump();

    final list = tester.widget<SongListComponent>(
      find.byType(SongListComponent),
    );
    expect(list.initialLoading, isFalse);
    expect(find.text('保留的歌单'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('my collection actions request skin icon roles', (tester) async {
    const item = MyFavoriteItem(
      id: 'artist-1',
      platform: 'qq',
      type: MyFavoriteType.artists,
      title: '测试歌手',
      subtitle: '12 首歌曲',
      coverUrl: '',
    );
    final state = MyCollectionState.initial.copyWith(
      loading: false,
      selectedType: MyFavoriteType.artists,
      artists: const <MyFavoriteItem>[item],
    );

    await tester.pumpWidget(_buildTestApp(state, useCitySkin: true));
    await tester.pump();

    expect(_findSkinIcon(AppSkinIconRole.myCollectionRefresh), findsOneWidget);
    expect(_findSkinIcon(AppSkinIconRole.myCollectionRemove), findsOneWidget);
  });
}

Widget _buildTestApp(MyCollectionState state, {bool useCitySkin = false}) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWith(_TestAppConfigController.new),
      myCollectionControllerProvider.overrideWith(
        () => _TestMyCollectionController(state),
      ),
    ],
    child: MaterialApp(
      theme: useCitySkin ? AppTheme.light(citySoundCreatorSkin()) : null,
      home: const MyCollectionPage(),
    ),
  );
}

Finder _findSkinIcon(AppSkinIconRole role) {
  return find.byWidgetPredicate(
    (widget) => widget is AppSkinIcon && widget.role == role,
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'zh');
  }
}

class _TestMyCollectionController extends MyCollectionController {
  _TestMyCollectionController(this.initialState);

  final MyCollectionState initialState;

  @override
  MyCollectionState build() {
    return initialState;
  }

  @override
  Future<void> initialize() async {}
}
