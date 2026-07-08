import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/radio/presentation/controllers/radio_plaza_controller.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

RadioGroupInfo _group(String name, {int radioCount = 1}) {
  return RadioGroupInfo(
    name: name,
    radios: List.generate(
      radioCount,
      (i) => RadioInfo(
        id: 'r_${name}_$i',
        name: 'Radio $name $i',
        cover: '',
        platform: 'qq',
      ),
    ),
    platform: 'qq',
  );
}

RadioGroupInfo _emptyGroup(String name) {
  return RadioGroupInfo(name: name, radios: const [], platform: 'qq');
}

void main() {
  group('RadioPlazaState', () {
    test('initial 应为合理的默认值', () {
      final state = RadioPlazaState.initial;
      expect(state.selectedPlatformId, isNull);
      expect(state.selectedGroupName, isNull);
      expect(state.loading, isFalse);
      expect(state.groups, isEmpty);
      expect(state.errorMessage, isNull);
    });

    test('availableGroups 应过滤掉 radios 为空的 group', () {
      final state = RadioPlazaState.initial.copyWith(
        groups: [_group('A'), _emptyGroup('B'), _group('C')],
      );
      expect(state.availableGroups, hasLength(2));
      expect(state.availableGroups.map((g) => g.name), ['A', 'C']);
    });

    test('selectedGroup 应在无可用 group 时返回 null', () {
      final state = RadioPlazaState.initial.copyWith(
        groups: [_emptyGroup('X')],
      );
      expect(state.selectedGroup, isNull);
    });

    test('selectedGroup 应在 selectedGroupName 为空时返回第一个可用 group', () {
      final state = RadioPlazaState.initial.copyWith(
        groups: [_group('A'), _group('B')],
      );
      expect(state.selectedGroup?.name, 'A');
    });

    test('selectedGroup 应返回匹配 selectedGroupName 的 group', () {
      final state = RadioPlazaState.initial.copyWith(
        selectedGroupName: 'B',
        groups: [_group('A'), _group('B'), _group('C')],
      );
      expect(state.selectedGroup?.name, 'B');
    });

    test('selectedGroup 应在 selectedGroupName 不匹配时回退到第一个', () {
      final state = RadioPlazaState.initial.copyWith(
        selectedGroupName: 'NotExist',
        groups: [_group('A'), _group('B')],
      );
      expect(state.selectedGroup?.name, 'A');
    });

    test('copyWith 应正确覆盖字段', () {
      final state = RadioPlazaState.initial.copyWith(
        selectedPlatformId: 'qq',
        loading: true,
        groups: [_group('A')],
      );
      expect(state.selectedPlatformId, 'qq');
      expect(state.loading, isTrue);
      expect(state.groups, hasLength(1));
    });

    test('copyWith clearSelectedGroupName 应置为 null', () {
      final state = RadioPlazaState.initial.copyWith(selectedGroupName: 'A');
      expect(state.selectedGroupName, 'A');

      final cleared = state.copyWith(clearSelectedGroupName: true);
      expect(cleared.selectedGroupName, isNull);
    });

    test('copyWith clearError 应置为 null', () {
      final state = RadioPlazaState.initial.copyWith(
        errorMessage: 'some error',
      );
      expect(state.errorMessage, 'some error');

      final cleared = state.copyWith(clearError: true);
      expect(cleared.errorMessage, isNull);
    });
  });
}
