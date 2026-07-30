import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/shared/widgets/plaza_widgets.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  group('PlazaEmptyState', () {
    testWidgets('应显示 label 文本', (tester) async {
      await tester.pumpWidget(_wrap(const PlazaEmptyState(label: '暂无数据')));

      expect(find.text('暂无数据'), findsOneWidget);
    });
  });

  group('PlazaErrorView', () {
    testWidgets('应显示错误消息和重试按钮', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrapWithProvider(
          PlazaErrorView(message: '加载失败', onRetry: () => retried = true),
        ),
      );

      expect(find.text('加载失败'), findsOneWidget);
      final button = find.byType(FilledButton);
      expect(button, findsOneWidget);

      await tester.tap(button);
      expect(retried, isTrue);
    });
  });

  group('PlazaChoiceChip', () {
    testWidgets('应使用统一的选中态与未选中态样式', (tester) async {
      await tester.pumpWidget(
        _wrap(
          Row(
            children: <Widget>[
              PlazaChoiceChip(label: '推荐', selected: true, onSelected: () {}),
              PlazaChoiceChip(label: '华语', selected: false, onSelected: () {}),
            ],
          ),
        ),
      );

      final theme = Theme.of(tester.element(find.text('推荐')));
      final selectedChip = tester.widget<ChoiceChip>(
        find.ancestor(of: find.text('推荐'), matching: find.byType(ChoiceChip)),
      );
      final unselectedChip = tester.widget<ChoiceChip>(
        find.ancestor(of: find.text('华语'), matching: find.byType(ChoiceChip)),
      );

      expect(selectedChip.selected, isTrue);
      expect(
        selectedChip.selectedColor,
        theme.colorScheme.primary.withValues(alpha: 0.10),
      );
      expect(unselectedChip.selected, isFalse);
      expect(
        unselectedChip.backgroundColor,
        theme.colorScheme.surface.withValues(alpha: 0.18),
      );
    });

    testWidgets('点击后应触发回调', (tester) async {
      var selected = false;
      await tester.pumpWidget(
        _wrap(
          PlazaChoiceChip(
            label: '欧美',
            selected: false,
            onSelected: () => selected = true,
          ),
        ),
      );

      await tester.tap(find.text('欧美'));

      expect(selected, isTrue);
    });
  });

  group('PlazaFilterChipRow', () {
    testWidgets('应渲染所有过滤选项', (tester) async {
      const group = FilterInfo(
        id: 'region',
        platform: 'qq',
        options: [
          FilterOptionInfo(value: 'cn', label: '华语'),
          FilterOptionInfo(value: 'eu', label: '欧美'),
          FilterOptionInfo(value: 'jp', label: '日语'),
        ],
      );

      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 400,
            height: 60,
            child: PlazaFilterChipRow(
              group: group,
              selectedValue: 'cn',
              onSelect: _noop,
            ),
          ),
        ),
      );

      expect(find.text('华语'), findsOneWidget);
      expect(find.text('欧美'), findsOneWidget);
      expect(find.text('日语'), findsOneWidget);
    });

    testWidgets('点击选项应触发 onSelect', (tester) async {
      String? selected;
      const group = FilterInfo(
        id: 'region',
        platform: 'qq',
        options: [
          FilterOptionInfo(value: 'cn', label: '华语'),
          FilterOptionInfo(value: 'eu', label: '欧美'),
        ],
      );

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 400,
            height: 60,
            child: PlazaFilterChipRow(
              group: group,
              selectedValue: null,
              onSelect: (v) => selected = v,
            ),
          ),
        ),
      );

      await tester.tap(find.text('欧美'));
      expect(selected, 'eu');
    });

    testWidgets('未选中项应使用低透明度主题背景', (tester) async {
      const group = FilterInfo(
        id: 'region',
        platform: 'qq',
        options: [
          FilterOptionInfo(value: 'cn', label: '华语'),
          FilterOptionInfo(value: 'eu', label: '欧美'),
        ],
      );

      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 400,
            height: 60,
            child: PlazaFilterChipRow(
              group: group,
              selectedValue: 'cn',
              onSelect: _noop,
            ),
          ),
        ),
      );

      final theme = Theme.of(tester.element(find.text('欧美')));
      final unselectedChip = tester.widget<ChoiceChip>(
        find.ancestor(of: find.text('欧美'), matching: find.byType(ChoiceChip)),
      );
      expect(
        unselectedChip.backgroundColor,
        theme.colorScheme.surface.withValues(alpha: 0.18),
      );
    });
  });

  group('PlazaFiltersPanel', () {
    testWidgets('空 filterGroups 应返回空 widget', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 400,
            height: 60,
            child: PlazaFiltersPanel(
              filterGroups: [],
              selectedFilters: {},
              onSelectFilter: _noopGroup,
            ),
          ),
        ),
      );

      expect(find.byType(PlazaFilterChipRow), findsNothing);
    });

    testWidgets('应渲染多个过滤组', (tester) async {
      const groups = [
        FilterInfo(
          id: 'region',
          platform: 'qq',
          options: [FilterOptionInfo(value: 'cn', label: '华语')],
        ),
        FilterInfo(
          id: 'type',
          platform: 'qq',
          options: [FilterOptionInfo(value: 'mv', label: 'MV')],
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 400,
            height: 120,
            child: PlazaFiltersPanel(
              filterGroups: groups,
              selectedFilters: {'region': 'cn'},
              onSelectFilter: _noopGroup,
            ),
          ),
        ),
      );

      expect(find.byType(PlazaFilterChipRow), findsNWidgets(2));
      expect(find.text('华语'), findsOneWidget);
      expect(find.text('MV'), findsOneWidget);
    });

    testWidgets('options 为空的 group 应被过滤', (tester) async {
      const groups = [
        FilterInfo(id: 'empty', platform: 'qq', options: []),
        FilterInfo(
          id: 'region',
          platform: 'qq',
          options: [FilterOptionInfo(value: 'cn', label: '华语')],
        ),
      ];

      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 400,
            height: 60,
            child: PlazaFiltersPanel(
              filterGroups: groups,
              selectedFilters: {},
              onSelectFilter: _noopGroup,
            ),
          ),
        ),
      );

      expect(find.byType(PlazaFilterChipRow), findsOneWidget);
    });
  });
}

void _noop(String value) {}
void _noopGroup(String groupId, String value) {}

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

Widget _wrapWithProvider(Widget child) {
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
