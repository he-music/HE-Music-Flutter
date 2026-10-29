import 'package:flutter/foundation.dart';

/// The next page of the exact list that was handed to the player.
/// Clicking a page again replaces this cursor together with the loaded songs.
@immutable
class SongListPagination {
  const SongListPagination({
    required this.path,
    required this.parameters,
    required this.nextPageIndex,
    required this.pageSize,
    required this.hasMore,
    this.lastId,
  });

  static const supportedPaths = {
    '/v1/playlist/songs',
    '/v1/user/playlist/songs',
    '/v1/ranking',
    '/v1/song/tab/news',
    '/v1/artist/songs',
  };

  final String path;
  final Map<String, String> parameters;
  final int nextPageIndex;
  final int pageSize;
  final bool hasMore;
  final String? lastId;

  SongListPagination advance({required bool hasMore, String? lastId}) =>
      SongListPagination(
        path: path,
        parameters: parameters,
        nextPageIndex: nextPageIndex + 1,
        pageSize: pageSize,
        hasMore: hasMore,
        lastId: lastId,
      );

  Map<String, dynamic> toMap() => {
    'path': path,
    'parameters': parameters,
    'next_page_index': nextPageIndex,
    'page_size': pageSize,
    'has_more': hasMore,
    'last_id': lastId,
  };

  static SongListPagination? fromMap(dynamic raw) {
    if (raw is! Map || !supportedPaths.contains(raw['path'])) return null;
    final parameters = raw['parameters'];
    final nextPageIndex = raw['next_page_index'];
    final pageSize = raw['page_size'];
    if (parameters is! Map ||
        nextPageIndex is! int ||
        nextPageIndex < 1 ||
        pageSize is! int ||
        pageSize < 1) {
      return null;
    }
    return SongListPagination(
      path: raw['path'] as String,
      parameters: Map.unmodifiable(
        parameters.map((key, value) => MapEntry('$key', '$value')),
      ),
      nextPageIndex: nextPageIndex,
      pageSize: pageSize,
      hasMore: raw['has_more'] == true,
      lastId: raw['last_id'] is String ? raw['last_id'] as String : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SongListPagination &&
      path == other.path &&
      mapEquals(parameters, other.parameters) &&
      nextPageIndex == other.nextPageIndex &&
      pageSize == other.pageSize &&
      hasMore == other.hasMore &&
      lastId == other.lastId;

  @override
  int get hashCode => Object.hash(
    path,
    Object.hashAllUnordered(
      parameters.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    nextPageIndex,
    pageSize,
    hasMore,
    lastId,
  );
}
