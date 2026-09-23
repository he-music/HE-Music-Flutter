import 'package:drift/drift.dart';

/// Only current and previous slots are persisted. Metadata excludes song lists.
class PlaybackQueues extends Table {
  TextColumn get slot => text()();
  TextColumn get metadata => text()();
  @override
  Set<Column> get primaryKey => {slot};
}

/// Position identifies an occurrence, so duplicate songs remain valid.
class PlaybackQueueEntries extends Table {
  TextColumn get slot =>
      text().references(PlaybackQueues, #slot, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {slot, position};
}

class PlaybackHistory extends Table {
  TextColumn get trackKey => text()();
  IntColumn get playedAt => integer()();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {trackKey};
}

class StoredDownloadTasks extends Table {
  TextColumn get taskId => text()();
  IntColumn get updatedAt => integer()();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {taskId};
}

class CachedFavoriteSongs extends Table {
  TextColumn get platform => text()();
  TextColumn get songId => text()();
  @override
  Set<Column> get primaryKey => {platform, songId};
}

/// Written in the same transaction as imported records, before legacy cleanup.
class StorageMigrations extends Table {
  TextColumn get storageKey => text()();
  @override
  Set<Column> get primaryKey => {storageKey};
}
