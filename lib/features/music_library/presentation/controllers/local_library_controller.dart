import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/local_song.dart';
import '../../domain/repositories/local_music_repository.dart';
import '../providers/local_library_providers.dart';

const permissionDeniedMessage = '未获得本地音频读取权限，请先授权媒体或存储权限。';

/// 歌曲排序维度
enum SongSortBy {
  title('title', '标题'),
  artist('artist', '艺术家'),
  album('album', '专辑'),
  duration('duration', '时长'),
  size('size', '大小'),
  createdAt('created_at', '最近添加');

  const SongSortBy(this.key, this.label);
  final String key;
  final String label;
}

/// 搜索状态
class LocalLibrarySearchState {
  const LocalLibrarySearchState({this.isActive = false, this.query = ''});

  final bool isActive;
  final String query;
}

class LocalLibraryController extends AsyncNotifier<List<LocalSong>> {
  Timer? _debounceTimer;
  StreamSubscription<List<LocalSong>>? _songSubscription;
  StreamSubscription<List<ArtistGroup>>? _artistSubscription;
  StreamSubscription<List<AlbumGroup>>? _albumSubscription;
  StreamSubscription<List<GenreGroup>>? _genreSubscription;
  int _artworkLoadGeneration = 0;

  /// 当前搜索状态
  LocalLibrarySearchState searchState = const LocalLibrarySearchState();

  /// 当前排序维度
  SongSortBy sortBy = SongSortBy.title;
  bool sortAscending = true;

  /// 分组数据
  List<ArtistGroup> artistGroups = const [];
  List<AlbumGroup> albumGroups = const [];
  List<GenreGroup> genreGroups = const [];

  /// 多选模式状态
  bool isMultiSelectMode = false;
  final Set<String> selectedSongIds = {};

  @override
  Future<List<LocalSong>> build() async {
    ref.onDispose(() {
      _debounceTimer?.cancel();
      _songSubscription?.cancel();
      _artistSubscription?.cancel();
      _albumSubscription?.cancel();
      _genreSubscription?.cancel();
    });
    await _loadSortPreference();
    return const <LocalSong>[];
  }

  /// 加载排序偏好
  Future<void> _loadSortPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final sortKey = prefs.getString('local_sort_by') ?? 'title';
    final ascending = prefs.getBool('local_sort_ascending') ?? true;
    sortBy = SongSortBy.values.firstWhere(
      (e) => e.key == sortKey,
      orElse: () => SongSortBy.title,
    );
    sortAscending = ascending;
  }

  /// 保存排序偏好
  Future<void> _saveSortPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_sort_by', sortBy.key);
    await prefs.setBool('local_sort_ascending', sortAscending);
  }

  Future<void> scanLibrary() async {
    state = const AsyncLoading();
    final repository = ref.read(localMusicRepositoryProvider);
    final granted = await repository.requestPermission();
    if (!granted) {
      state = AsyncError(permissionDeniedMessage, StackTrace.current);
      return;
    }
    state = await AsyncValue.guard(repository.scanSongs);
    if (state.hasValue) {
      _startWatchingGroups();
      // 提取完成后重新监听 DB 流，获取最新的 has_artwork 状态并加载封面
      _startBackgroundArtworkExtraction().then((_) {
        startWatchingSongs();
      });
    }
  }

  Future<void> _startBackgroundArtworkExtraction() async {
    await ref.read(localArtworkExtractorProvider).extractAll();
  }

  /// 开始监听分组数据流
  void _startWatchingGroups() {
    final repository = ref.read(localMusicRepositoryProvider);
    _artistSubscription?.cancel();
    _albumSubscription?.cancel();
    _genreSubscription?.cancel();
    _artistSubscription = repository.watchArtists().listen((groups) {
      artistGroups = groups;
      ref.notifyListeners();
    });
    _albumSubscription = repository.watchAlbums().listen((groups) {
      albumGroups = groups;
      ref.notifyListeners();
    });
    _genreSubscription = repository.watchGenres().listen((groups) {
      genreGroups = groups;
      ref.notifyListeners();
    });
  }

  /// 监听歌曲列表流（带排序）
  void startWatchingSongs() {
    _songSubscription?.cancel();
    final repository = ref.read(localMusicRepositoryProvider);
    _songSubscription = repository
        .watchSongs(sortBy: sortBy.key, ascending: sortAscending)
        .listen((songs) {
          state = AsyncData(songs);
          _loadArtworkForSongs(songs);
        });
    _startWatchingGroups();
  }

  /// 从磁盘缓存加载封面字节，回填到歌曲列表
  Future<void> _loadArtworkForSongs(List<LocalSong> songs) async {
    final generation = ++_artworkLoadGeneration;
    final extractor = ref.read(localArtworkExtractorProvider);

    // 筛选需要加载封面的歌曲
    final toLoad = songs
        .where((s) => s.hasArtwork && s.artworkBytes == null)
        .toList();
    if (toLoad.isEmpty) return;

    // 保留当前 state 中已加载的 artworkBytes，避免被 DB 流数据覆盖
    final currentArtwork = <String, Uint8List>{};
    if (state.hasValue) {
      for (final s in state.value!) {
        if (s.artworkBytes != null) currentArtwork[s.id] = s.artworkBytes!;
      }
    }
    final enriched = List<LocalSong>.from(
      songs.map(
        (s) => currentArtwork.containsKey(s.id)
            ? s.copyWith(artworkBytes: currentArtwork[s.id])
            : s,
      ),
    );
    var changed = false;
    var running = 0;
    var index = 0;
    final completer = Completer<void>();

    void processNext() {
      while (running < 3 && index < toLoad.length) {
        if (generation != _artworkLoadGeneration) {
          if (!completer.isCompleted) completer.complete();
          return;
        }
        final song = toLoad[index++];
        running++;
        extractor
            .getArtworkBytes(song.filePath)
            .then((bytes) {
              if (bytes != null &&
                  bytes.isNotEmpty &&
                  generation == _artworkLoadGeneration) {
                final idx = enriched.indexWhere((s) => s.id == song.id);
                if (idx != -1) {
                  enriched[idx] = song.copyWith(
                    artworkBytes: Uint8List.fromList(bytes),
                  );
                  changed = true;
                }
              }
            })
            .catchError((_) {})
            .whenComplete(() {
              running--;
              if (index >= toLoad.length && running == 0) {
                if (!completer.isCompleted) completer.complete();
              } else {
                processNext();
              }
            });
      }
    }

    processNext();
    await completer.future;
    if (changed && generation == _artworkLoadGeneration) {
      state = AsyncData(enriched);
    }
  }

  Future<void> clearLibrary() async {
    final repository = ref.read(localMusicRepositoryProvider);
    await repository.clearLibrary();
    final extractor = ref.read(localArtworkExtractorProvider);
    extractor.cancel();
    await extractor.clearAllArtwork();
    _songSubscription?.cancel();
    _artistSubscription?.cancel();
    _albumSubscription?.cancel();
    _genreSubscription?.cancel();
    artistGroups = const [];
    albumGroups = const [];
    genreGroups = const [];
    state = const AsyncData(<LocalSong>[]);
  }

  /// 切换搜索状态
  void toggleSearch() {
    final isActive = !searchState.isActive;
    searchState = LocalLibrarySearchState(isActive: isActive);
    if (!isActive) {
      _debounceTimer?.cancel();
      _songSubscription?.cancel();
    }
    ref.notifyListeners();
  }

  /// 更新搜索关键词（带 300ms 防抖）
  void updateSearchQuery(String query) {
    searchState = LocalLibrarySearchState(isActive: true, query: query);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(query);
    });
    ref.notifyListeners();
  }

  void _executeSearch(String query) {
    _songSubscription?.cancel();
    if (query.isEmpty) {
      return;
    }
    final repository = ref.read(localMusicRepositoryProvider);
    _songSubscription = repository.watchSongs(searchQuery: query).listen((
      songs,
    ) {
      state = AsyncData(songs);
      _loadArtworkForSongs(songs);
    });
  }

  /// 切换排序维度
  void changeSortBy(SongSortBy newSortBy) {
    if (sortBy == newSortBy) {
      sortAscending = !sortAscending;
    } else {
      sortBy = newSortBy;
      sortAscending = true;
    }
    _saveSortPreference();
    startWatchingSongs();
    ref.notifyListeners();
  }

  /// 进入多选模式
  void enterMultiSelect(String songId) {
    isMultiSelectMode = true;
    selectedSongIds.clear();
    selectedSongIds.add(songId);
    ref.notifyListeners();
  }

  /// 退出多选模式
  void exitMultiSelect() {
    isMultiSelectMode = false;
    selectedSongIds.clear();
    ref.notifyListeners();
  }

  /// 切换选中状态
  void toggleSelection(String songId) {
    if (selectedSongIds.contains(songId)) {
      selectedSongIds.remove(songId);
      if (selectedSongIds.isEmpty) {
        isMultiSelectMode = false;
      }
    } else {
      selectedSongIds.add(songId);
    }
    ref.notifyListeners();
  }

  /// 全选/取消全选
  void selectAll(List<LocalSong> songs) {
    if (selectedSongIds.length == songs.length) {
      selectedSongIds.clear();
    } else {
      selectedSongIds.clear();
      selectedSongIds.addAll(songs.map((s) => s.id));
    }
    ref.notifyListeners();
  }
}
