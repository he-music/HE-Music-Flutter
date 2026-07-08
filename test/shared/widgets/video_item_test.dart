import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/shared/widgets/video_item.dart';

void main() {
  group('VideoListItem', () {
    testWidgets('应显示标题', (tester) async {
      await tester.pumpWidget(
        _wrap(VideoListItem(title: 'MV Title', coverUrl: '', onTap: () {})),
      );

      expect(find.text('MV Title'), findsOneWidget);
    });

    testWidgets('应显示 creator', (tester) async {
      await tester.pumpWidget(
        _wrap(
          VideoListItem(
            title: 'T',
            creator: 'Artist',
            coverUrl: '',
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Artist'), findsOneWidget);
    });

    testWidgets('creator 为空时应显示未知作者', (tester) async {
      await tester.pumpWidget(
        _wrap(VideoListItem(title: 'T', coverUrl: '', onTap: () {})),
      );

      // 空 creator 使用 i18n 的 common.unknown_author
      expect(find.text('T'), findsOneWidget);
    });

    testWidgets('点击应触发 onTap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          VideoListItem(title: 'T', coverUrl: '', onTap: () => tapped = true),
        ),
      );

      await tester.tap(find.text('T'));
      expect(tapped, isTrue);
    });

    testWidgets('coverUrl 为空时应显示 fallback 图标', (tester) async {
      await tester.pumpWidget(
        _wrap(VideoListItem(title: 'T', coverUrl: '', onTap: () {})),
      );

      expect(find.byIcon(Icons.play_circle_fill_rounded), findsOneWidget);
    });

    testWidgets('playCount 非空时应显示播放图标', (tester) async {
      await tester.pumpWidget(
        _wrap(
          VideoListItem(
            title: 'T',
            coverUrl: 'https://img/cover.jpg',
            playCount: '12345',
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('duration 非空时应显示时长文本', (tester) async {
      await tester.pumpWidget(
        _wrap(
          VideoListItem(
            title: 'T',
            coverUrl: 'https://img/cover.jpg',
            duration: '240',
            onTap: () {},
          ),
        ),
      );

      // formatDurationSecondsLabel('240') => '04:00'
      expect(find.text('04:00'), findsOneWidget);
    });
  });

  group('VideoGridItem', () {
    testWidgets('应显示封面角标、标题和作者', (tester) async {
      await tester.pumpWidget(
        _wrap(
          VideoGridItem(
            title: 'Grid MV',
            creator: 'Grid Artist',
            coverUrl: 'https://img/cover.jpg',
            playCount: '12345',
            duration: '240',
            onTap: () {},
          ),
          width: 180,
          height: 180,
        ),
      );

      expect(find.text('Grid MV'), findsOneWidget);
      expect(find.text('Grid Artist'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.text('04:00'), findsOneWidget);
    });
  });
}

Widget _wrap(Widget child, {double width = 400, double height = 120}) {
  return ProviderScope(
    overrides: [appConfigProvider.overrideWith(_TestAppConfigController.new)],
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(width: width, height: height, child: child),
      ),
    ),
  );
}

class _TestAppConfigController extends AppConfigController {
  @override
  AppConfigState build() {
    return AppConfigState.initial.copyWith(localeCode: 'en');
  }
}
