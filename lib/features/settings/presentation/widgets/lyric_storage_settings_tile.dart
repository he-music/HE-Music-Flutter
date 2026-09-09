import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../lyrics/presentation/providers/lyrics_providers.dart';

import '../../../../app/app_message_service.dart';
import '../../../lyrics/data/storage/lyric_store.dart';
import 'audio_cache_settings_tile.dart';

class LyricStorageSettingsTile extends ConsumerStatefulWidget {
  const LyricStorageSettingsTile({required this.manual, super.key});
  final bool manual;
  @override
  ConsumerState<LyricStorageSettingsTile> createState() =>
      _LyricStorageSettingsTileState();
}

class _LyricStorageSettingsTileState
    extends ConsumerState<LyricStorageSettingsTile> {
  late Future<LyricStorageStats> _stats = ref
      .read(lyricStoreProvider)
      .statistics();
  bool _busy = false;

  Future<void> _clear() async {
    if (widget.manual) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除全部手动选择歌词？'),
          content: const Text('所有歌曲将恢复默认歌词。此操作无法撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('全部删除'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }
    setState(() => _busy = true);
    try {
      if (widget.manual) {
        await ref.read(lyricStoreProvider).clearManual();
      } else {
        await ref.read(lyricStoreProvider).clearAutomatic();
      }
      AppMessageService.showSuccess(widget.manual ? '手动选择歌词已删除' : '自动歌词缓存已清除');
    } catch (_) {
      AppMessageService.showError('部分歌词未能删除，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _stats = ref.read(lyricStoreProvider).statistics();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(lyricStorageStatisticsChangesProvider, (_, next) {
      if (next.hasValue) {
        setState(() {
          _stats = ref.read(lyricStoreProvider).statistics();
        });
      }
    });
    return FutureBuilder<LyricStorageStats>(
      future: _stats,
      builder: (context, snapshot) {
        final stats = snapshot.data;
        return ListTile(
          leading: Icon(widget.manual ? Icons.lyrics_outlined : Icons.cached),
          title: Text(widget.manual ? '手动选择歌词' : '自动歌词缓存'),
          subtitle: Text(
            snapshot.hasError
                ? '无法读取占用，点击重试'
                : stats == null
                ? '正在统计…'
                : widget.manual
                ? '${stats.manualCount} 首 · ${lyricStorageSizeLabel(stats.manualBytes)} · 全部删除'
                : '${lyricStorageSizeLabel(stats.automaticBytes)} / 50 MiB · 清除缓存',
          ),
          trailing: _busy
              ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline),
          onTap: _busy
              ? null
              : snapshot.hasError
              ? () => setState(() {
                  _stats = ref.read(lyricStoreProvider).statistics();
                })
              : stats == null
              ? null
              : _clear,
        );
      },
    );
  }
}

String lyricStorageSizeLabel(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
  return audioCacheSizeLabel(
    bytes,
  ).replaceAll('MB', 'MiB').replaceAll('GB', 'GiB');
}
