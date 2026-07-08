import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/online/data/datasources/search_history_data_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('SearchHistoryDataSource', () {
    test('appendKeyword 应将新关键字插入列表头部', () async {
      const ds = SearchHistoryDataSource();
      final result = await ds.appendKeyword('周杰伦');

      expect(result, hasLength(1));
      expect(result.first, '周杰伦');
    });

    test('appendKeyword 应去重并移至头部', () async {
      const ds = SearchHistoryDataSource();
      await ds.appendKeyword('A');
      await ds.appendKeyword('B');
      final result = await ds.appendKeyword('A');

      expect(result, hasLength(2));
      expect(result.first, 'A');
      expect(result.last, 'B');
    });

    test('appendKeyword 应自动 trim 空白', () async {
      const ds = SearchHistoryDataSource();
      final result = await ds.appendKeyword('  周杰伦  ');

      expect(result.first, '周杰伦');
    });

    test('appendKeyword 空字符串应返回当前列表', () async {
      const ds = SearchHistoryDataSource();
      await ds.appendKeyword('A');
      final result = await ds.appendKeyword('');

      expect(result, hasLength(1));
      expect(result.first, 'A');
    });

    test('appendKeyword 应限制最多 20 条', () async {
      const ds = SearchHistoryDataSource();
      for (var i = 0; i < 25; i++) {
        await ds.appendKeyword('keyword-$i');
      }
      final result = await ds.listKeywords();

      expect(result, hasLength(20));
      expect(result.first, 'keyword-24');
    });

    test('listKeywords 应保持最新在前', () async {
      const ds = SearchHistoryDataSource();
      await ds.appendKeyword('first');
      await ds.appendKeyword('second');
      await ds.appendKeyword('third');

      final result = await ds.listKeywords();
      expect(result, ['third', 'second', 'first']);
    });

    test('listKeywords 无数据时返回空列表', () async {
      const ds = SearchHistoryDataSource();
      final result = await ds.listKeywords();

      expect(result, isEmpty);
    });

    test('clearKeywords 应清空所有历史', () async {
      const ds = SearchHistoryDataSource();
      await ds.appendKeyword('A');
      await ds.appendKeyword('B');
      await ds.clearKeywords();

      expect(await ds.listKeywords(), isEmpty);
    });
  });
}
