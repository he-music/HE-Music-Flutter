import '../../../../shared/widgets/app_alert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../core/audio/cache/audio_cache_policy.dart';
import '../../../../core/audio/cache/audio_cache_provider.dart';
import '../../domain/settings_catalog.dart';
import '../../domain/settings_models.dart';
import 'settings_single_choice_sheet.dart';

String audioCacheSizeLabel(int bytes) {
  if (bytes >= 1024 * AudioCachePolicy.mebibyte) {
    final gb = bytes / (1024 * AudioCachePolicy.mebibyte);
    return '${gb.toStringAsFixed(gb == gb.roundToDouble() ? 0 : 1)} GB';
  }
  final mb = bytes / AudioCachePolicy.mebibyte;
  return '${mb.toStringAsFixed(mb == mb.roundToDouble() ? 0 : 1)} MB';
}

class AudioCacheSettingsTile extends ConsumerWidget {
  const AudioCacheSettingsTile({
    required this.item,
    this.highlighted = false,
    super.key,
  });

  final SettingsItemNode item;
  final bool highlighted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(audioCacheRuntimeProvider);
    if (runtime == null || !runtime.capabilityEnabled) {
      return const SizedBox.shrink();
    }
    final (enabled, cellular, limit, _) = ref.watch(
      appConfigProvider.select(
        (config) => (
          config.enablePlaybackAudioCache,
          config.enableCellularAudioCache,
          config.audioCacheLimitBytes,
          config.localeCode,
        ),
      ),
    );
    final config = ref.read(appConfigProvider);
    final controller = ref.read(appConfigProvider.notifier);
    final title = Text(AppI18n.t(config, item.titleKey));
    final icon = Icon(item.icon);
    final Widget tile = switch (item.id) {
      SettingsItemIds.playbackAudioCache => SwitchListTile.adaptive(
        secondary: icon,
        title: title,
        value: enabled,
        onChanged: controller.setEnablePlaybackAudioCache,
      ),
      SettingsItemIds.cellularAudioCache => SwitchListTile.adaptive(
        secondary: icon,
        title: title,
        value: cellular,
        onChanged: enabled ? controller.setEnableCellularAudioCache : null,
      ),
      SettingsItemIds.audioCacheLimit => ListTile(
        leading: icon,
        title: title,
        subtitle: Text(AppI18n.t(config, 'settings.audio_cache.limit_desc')),
        trailing: Text(audioCacheSizeLabel(limit)),
        onTap: () => showSettingsSingleChoiceSheet<int>(
          context: context,
          title: AppI18n.t(config, item.titleKey),
          currentValue: limit,
          options: [
            for (final bytes in AudioCachePolicy.limits)
              SettingsChoiceOption(
                value: bytes,
                title: audioCacheSizeLabel(bytes),
              ),
          ],
          onSelected: controller.setAudioCacheLimitBytes,
        ),
      ),
      SettingsItemIds.clearAudioCache => _ClearAudioCacheTile(item: item),
      _ => throw ArgumentError.value(item.id),
    };
    return ColoredBox(
      color: highlighted
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.transparent,
      child: tile,
    );
  }
}

class _ClearAudioCacheTile extends ConsumerStatefulWidget {
  const _ClearAudioCacheTile({required this.item});
  final SettingsItemNode item;

  @override
  ConsumerState<_ClearAudioCacheTile> createState() =>
      _ClearAudioCacheTileState();
}

class _ClearAudioCacheTileState extends ConsumerState<_ClearAudioCacheTile> {
  bool _clearing = false;

  @override
  Widget build(BuildContext context) {
    final runtime = ref.watch(audioCacheRuntimeProvider)!;
    final snapshot =
        ref.watch(audioCacheSnapshotProvider).value ?? runtime.snapshot;
    final config = ref.read(appConfigProvider);
    return ListTile(
      leading: Icon(widget.item.icon),
      title: Text(AppI18n.t(config, widget.item.titleKey)),
      subtitle: Text(
        AppI18n.format(config, 'settings.audio_cache.used', {
          'size': audioCacheSizeLabel(snapshot.publishedBytes),
        }),
      ),
      onTap: _clearing ? null : _clear,
    );
  }

  Future<void> _clear() async {
    final config = ref.read(appConfigProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AppAlertDialog(
        title: Text(AppI18n.t(config, 'settings.audio_cache.clear')),
        content: Text(AppI18n.t(config, 'settings.audio_cache.confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppI18n.t(config, 'common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppI18n.t(config, 'common.confirm')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _clearing = true);
    try {
      final result = await ref.read(audioCacheRuntimeProvider)!.clear();
      if (!mounted) return;
      if (result.hasDeferredData) {
        AppMessageService.showInfo(
          AppI18n.t(config, 'settings.audio_cache.deferred'),
        );
      } else {
        AppMessageService.showSuccess(
          AppI18n.t(config, 'settings.audio_cache.cleared'),
        );
      }
    } catch (_) {
      if (mounted) {
        AppMessageService.showError(
          AppI18n.t(config, 'settings.audio_cache.clear_failed'),
        );
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }
}
