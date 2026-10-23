import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/player/app_player_style_bottom_sheet.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/lyric_document.dart';
import '../../domain/entities/lyric_request.dart';
import '../providers/lyrics_providers.dart';

String _offsetLabel(int milliseconds, String locale) {
  String text(String key) => AppI18n.tByLocaleCode(locale, 'player.lyric.$key');
  if (milliseconds == 0) return text('offset_zero');
  return text(
    milliseconds > 0 ? 'offset_advanced' : 'offset_delayed',
  ).replaceAll('{seconds}', (milliseconds.abs() / 1000).toStringAsFixed(1));
}

Future<void> showLyricOffsetSheet(
  BuildContext context,
  LyricRequest request,
) async {
  await showPlayerStyledBottomSheet<void>(
    context: context,
    fitContent: true,
    builder: (_) => _LyricOffsetSheet(request: request),
  );
}

class LyricOffsetTile extends ConsumerWidget {
  const LyricOffsetTile({
    required this.request,
    required this.manual,
    required this.onTap,
    super.key,
  });

  final LyricRequest request;
  final bool manual;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(
      appConfigProvider.select((config) => config.localeCode),
    );
    final offset = ref.watch(
      lyricOffsetProvider((request: request, manual: manual)),
    );
    return ListTile(
      key: const ValueKey('lyric-offset-tile'),
      leading: const Icon(Icons.timer_outlined),
      title: Text(AppI18n.tByLocaleCode(locale, 'player.lyric.offset')),
      subtitle: Text(
        offset.hasError
            ? AppI18n.tByLocaleCode(locale, 'player.lyric.offset_load_failed')
            : _offsetLabel(offset.value ?? 0, locale),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _LyricOffsetSheet extends ConsumerWidget {
  const _LyricOffsetSheet({required this.request});
  final LyricRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lyricRequest = ref.watch(currentLyricRequestProvider);
    final document = ref.watch(
      currentLyricDocumentProvider.select(
        (value) => (
          available: value.value?.isEmpty == false,
          manual: value.value?.source == LyricSource.manual,
        ),
      ),
    );
    final track = ref.watch(
      playerControllerProvider.select(
        (state) => (
          state.currentTrack?.id,
          state.currentTrack?.platform,
          state.currentTrack?.path,
        ),
      ),
    );
    return SingleChildScrollView(
      key: const ValueKey('lyric-offset-sheet'),
      child: LyricOffsetControl(
        request: request,
        manual: document.manual,
        enabled:
            lyricRequest == request &&
            document.available &&
            track == (request.trackId, request.platform, request.localPath),
      ),
    );
  }
}

/// A local control; playback progress never rebuilds this subtree.
class LyricOffsetControl extends ConsumerStatefulWidget {
  const LyricOffsetControl({
    required this.request,
    required this.manual,
    required this.enabled,
    super.key,
  });

  final LyricRequest request;
  final bool manual;
  final bool enabled;

  @override
  ConsumerState<LyricOffsetControl> createState() => _LyricOffsetControlState();
}

class _LyricOffsetControlState extends ConsumerState<LyricOffsetControl> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(
      appConfigProvider.select((config) => config.localeCode),
    );
    String text(String key) =>
        AppI18n.tByLocaleCode(locale, 'player.lyric.$key');
    final target = (request: widget.request, manual: widget.manual);
    final offset = widget.enabled
        ? ref.watch(lyricOffsetProvider(target))
        : null;
    final milliseconds = offset?.value ?? 0;
    final canAdjust = widget.enabled && offset?.hasValue == true && !_saving;
    final value = _offsetLabel(milliseconds, locale);
    return Padding(
      key: const ValueKey('lyric-offset-control'),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text('offset'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Semantics(
            liveRegion: true,
            child: Text(
              offset?.hasError == true ? text('offset_load_failed') : value,
              key: const ValueKey('lyric-offset-value'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('lyric-offset-advance'),
                  onPressed: canAdjust ? () => _update(100) : null,
                  child: Text(
                    text('offset_advance'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: const ValueKey('lyric-offset-reset'),
                onPressed: canAdjust && milliseconds != 0
                    ? () => _update(null)
                    : null,
                child: Text(text('offset_reset')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  key: const ValueKey('lyric-offset-delay'),
                  onPressed: canAdjust ? () => _update(-100) : null,
                  child: Text(
                    text('offset_delay'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          if (offset?.hasError == true)
            TextButton(
              onPressed: () => ref.invalidate(lyricOffsetProvider(target)),
              child: Text(text('offset_retry')),
            ),
        ],
      ),
    );
  }

  Future<void> _update(int? delta) async {
    final target = (request: widget.request, manual: widget.manual);
    final store = ref.read(lyricStoreProvider);
    setState(() => _saving = true);
    try {
      if (delta == null) {
        await store.resetOffset(target.request, manual: target.manual);
      } else {
        await store.adjustOffset(target.request, delta, manual: target.manual);
      }
    } catch (_) {
      if (mounted) {
        AppMessageService.showError(
          AppI18n.t(
            ref.read(appConfigProvider),
            'player.lyric.offset_save_failed',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
