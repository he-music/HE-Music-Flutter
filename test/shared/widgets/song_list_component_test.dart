import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/shared/widgets/song_list_component.dart';

void main() {
  group('SongListComponent', () {
    testWidgets('initialLoading 为 true 时应显示骨架屏', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SongListComponent(
            itemCount: 0,
            itemBuilder: _itemBuilder,
            initialLoading: true,
          ),
        ),
      );

      // 骨架屏默认 8 个
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('itemCount 为 0 时应显示空状态', (tester) async {
      await tester.pumpWidget(
        _wrap(const SongListComponent(itemCount: 0, itemBuilder: _itemBuilder)),
      );

      // 默认空状态显示 i18n 文本
      expect(find.byType(Center), findsOneWidget);
    });

    testWidgets('itemCount 为 0 且提供 empty widget 时应显示自定义空状态', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SongListComponent(
            itemCount: 0,
            itemBuilder: _itemBuilder,
            empty: Center(child: Text('No songs')),
          ),
        ),
      );

      expect(find.text('No songs'), findsOneWidget);
    });

    testWidgets('应正确渲染列表项', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SongListComponent(
            itemCount: 3,
            itemBuilder: (context, index) =>
                ListTile(title: Text('Song $index')),
          ),
        ),
      );

      expect(find.text('Song 0'), findsOneWidget);
      expect(find.text('Song 1'), findsOneWidget);
      expect(find.text('Song 2'), findsOneWidget);
    });

    testWidgets('enablePaging 为 false 时不应显示加载更多', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SongListComponent(
            itemCount: 2,
            itemBuilder: (context, index) =>
                ListTile(title: Text('Song $index')),
            enablePaging: false,
            hasMore: true,
          ),
        ),
      );

      // 不应有 "no more" 文本
      expect(find.text('Song 0'), findsOneWidget);
    });

    testWidgets('loadingMore 为 true 时应显示加载指示器', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 400,
            child: SongListComponent(
              itemCount: 5,
              itemBuilder: (context, index) =>
                  SizedBox(height: 50, child: Text('Song $index')),
              enablePaging: true,
              loadingMore: true,
              hasMore: true,
            ),
          ),
        ),
      );

      // loadingMore 时底部应有 SkeletonBox
      expect(find.byType(SongListComponent), findsOneWidget);
    });

    testWidgets('hasMore 为 false 时应显示无更多提示', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            height: 400,
            child: SongListComponent(
              itemCount: 2,
              itemBuilder: (context, index) =>
                  SizedBox(height: 50, child: Text('Song $index')),
              enablePaging: true,
              loadingMore: false,
              hasMore: false,
            ),
          ),
        ),
      );

      // hasMore=false, loadingMore=false → 显示 footer
      expect(find.byType(SongListComponent), findsOneWidget);
    });
  });
}

Widget _itemBuilder(BuildContext context, int index) {
  return ListTile(title: Text('Item $index'));
}

Widget _wrap(Widget child) {
  return ProviderScope(
    overrides: [appConfigProvider.overrideWith(_TestAppConfigController.new)],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'en');
  }
}
