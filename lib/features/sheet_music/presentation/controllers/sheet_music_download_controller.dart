import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/sheet_music_providers.dart';
import '../../domain/entities/sheet_music_download_state.dart';
import '../../domain/entities/sheet_music_info.dart';
import '../../domain/repositories/sheet_music_download_repository.dart';

class SheetMusicDownloadController extends Notifier<SheetMusicDownloadState> {
  SheetMusicDownloadDestination? _destination;
  SheetMusicInfo? _sheet;
  final Set<int> _saved = {};

  @override
  SheetMusicDownloadState build() => const SheetMusicDownloadState();

  Future<void> download(SheetMusicInfo sheet, {int? pageIndex}) async {
    if (state.running || sheet.pageUrls.isEmpty) return;
    if (pageIndex != null &&
        (pageIndex < 0 || pageIndex >= sheet.pageUrls.length)) {
      return;
    }
    final previousSheet = _sheet;
    final previousDestination = _destination;
    final previousSaved = Set<int>.of(_saved);
    _sheet = sheet;
    _destination = null;
    _saved.clear();
    await _run(
      pageIndex == null
          ? List.generate(sheet.pageUrls.length, (index) => index)
          : [pageIndex],
      onCancel: () {
        _sheet = previousSheet;
        _destination = previousDestination;
        _saved
          ..clear()
          ..addAll(previousSaved);
      },
    );
  }

  Future<void> retryFailed() async {
    if (state.running || _sheet == null || state.failedPages.isEmpty) return;
    await _run(state.failedPages);
  }

  Future<void> _run(List<int> pages, {void Function()? onCancel}) async {
    final sheet = _sheet!;
    final repository = ref.read(sheetMusicDownloadRepositoryProvider);
    // 关闭阅读器也让用户已发起的保存完成；任务结束后恢复自动释放。
    final keepAlive = ref.keepAlive();
    final previous = state;
    state = SheetMusicDownloadState(
      running: true,
      total: pages.length,
      savedCount: _saved.length,
    );
    try {
      _destination ??= await repository.prepare(
        sheet.title.isEmpty ? sheet.songName : sheet.title,
      );
      if (!ref.mounted) return;
      final destination = _destination;
      if (destination == null) {
        onCancel?.call();
        state = previous;
        return;
      }
      final failed = <int>[];
      Object? lastError;
      var processed = 0;
      for (final index in pages) {
        try {
          await repository.downloadPage(
            destination: destination,
            url: sheet.pageUrls[index],
            title: sheet.title.isEmpty ? sheet.songName : sheet.title,
            pageIndex: index,
          );
          _saved.add(index);
        } catch (error) {
          failed.add(index);
          lastError = error;
        }
        if (!ref.mounted) return;
        state = SheetMusicDownloadState(
          running: true,
          processed: ++processed,
          total: pages.length,
          savedCount: _saved.length,
          failedPages: List.unmodifiable(failed),
          error: lastError,
          directoryPath: destination.directoryPath,
        );
      }
      state = SheetMusicDownloadState(
        processed: processed,
        total: pages.length,
        savedCount: _saved.length,
        failedPages: List.unmodifiable(failed),
        error: lastError,
        directoryPath: destination.directoryPath,
      );
    } catch (error) {
      if (ref.mounted) {
        state = SheetMusicDownloadState(
          total: pages.length,
          savedCount: _saved.length,
          failedPages: List.unmodifiable(pages),
          error: error,
        );
      }
    } finally {
      keepAlive.close();
    }
  }
}
