import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../lyrics/presentation/providers/lyrics_providers.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
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
    final config = ref.read(appConfigProvider);
    if (widget.manual) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppI18n.t(config, 'settings.lyric_cache.confirm_title')),
          content: Text(AppI18n.t(config, 'settings.lyric_cache.confirm_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppI18n.t(config, 'common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(AppI18n.t(config, 'settings.lyric_cache.delete_all')),
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
      AppMessageService.showSuccess(
        AppI18n.t(
          config,
          widget.manual
              ? 'settings.lyric_cache.manual_cleared'
              : 'settings.lyric_cache.automatic_cleared',
        ),
      );
    } catch (_) {
      AppMessageService.showError(
        AppI18n.t(config, 'settings.lyric_cache.clear_failed'),
      );
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
    final locale = ref.watch(
      appConfigProvider.select((state) => state.localeCode),
    );
    String t(String key) => AppI18n.tByLocaleCode(locale, key);
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
          title: Text(
            t(
              widget.manual
                  ? 'settings.lyric_cache.manual'
                  : 'settings.lyric_cache.automatic',
            ),
          ),
          subtitle: Text(
            snapshot.hasError
                ? t('settings.lyric_cache.read_failed')
                : stats == null
                ? t('settings.lyric_cache.calculating')
                : widget.manual
                ? t('settings.lyric_cache.manual_usage')
                      .replaceAll('{count}', '${stats.manualCount}')
                      .replaceAll(
                        '{size}',
                        lyricStorageSizeLabel(stats.manualBytes),
                      )
                : t('settings.lyric_cache.automatic_usage').replaceAll(
                    '{size}',
                    lyricStorageSizeLabel(stats.automaticBytes),
                  ),
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
