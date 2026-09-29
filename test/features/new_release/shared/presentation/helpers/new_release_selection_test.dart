import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/new_release/shared/domain/entities/new_release_tab.dart';
import 'package:he_music_flutter/features/new_release/shared/presentation/helpers/new_release_selection.dart';

void main() {
  const tabs = [
    NewReleaseTab(id: 'first', name: 'First', platform: 'qq'),
    NewReleaseTab(id: 'second', name: 'Second', platform: 'qq'),
  ];

  test('selects a matching preferred ID after trimming whitespace', () {
    expect(
      resolveNewReleaseSelectionId(tabs, ' second ', idOf: (tab) => tab.id),
      'second',
    );
  });

  test(
    'falls back to the first item for absent or unavailable preferences',
    () {
      for (final preferred in [null, '', ' ', 'missing']) {
        expect(
          resolveNewReleaseSelectionId(tabs, preferred, idOf: (tab) => tab.id),
          'first',
        );
      }
    },
  );

  test('returns null for an empty list', () {
    expect(
      resolveNewReleaseSelectionId<NewReleaseTab>(
        [],
        'second',
        idOf: (tab) => tab.id,
      ),
      isNull,
    );
  });
}
