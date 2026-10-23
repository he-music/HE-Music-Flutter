import 'package:drift/drift.dart';

/// Nonzero user timing corrections, independent of cached lyric content.
@DataClassName('LyricOffsetEntry')
class LyricOffsets extends Table {
  TextColumn get targetKey => text()();
  TextColumn get sourceKind => text()();
  IntColumn get milliseconds => integer()();
  TextColumn get manualRevision => text().nullable()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {targetKey, sourceKind};

  @override
  List<String> get customConstraints => [
    "CHECK (source_kind IN ('default', 'manual'))",
    'CHECK (milliseconds <> 0)',
  ];
}
