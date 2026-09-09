import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_lyric_auxiliary_mode.dart';
import '../../../../app/config/app_lyric_font_preset.dart';
import '../../../../app/config/app_lyric_highlight_color.dart';
import '../../../../app/config/app_lyric_highlight_mode.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/player/app_player_style_registry.dart';
import '../../../../app/theme/player/app_player_style_bottom_sheet.dart';
import '../../../player/domain/entities/player_track.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../../settings/presentation/pages/settings_item_presentation_registry.dart';
import '../../../settings/presentation/widgets/settings_single_choice_sheet.dart';
import '../../domain/entities/lyric_document.dart';
import '../../domain/entities/lyric_request.dart';
import '../pages/lyric_search_page.dart';
import '../providers/lyrics_providers.dart';

/// A fixed sibling of the scrollable full lyric content, never a progress owner.
class FullLyricControls extends ConsumerWidget {
  const FullLyricControls({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      playerControllerProvider.select((state) => state.currentTrack),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            const _AuxiliaryButton(),
            _OutlinedLyricButton(
              controlId: 'options',
              glyph: '词',
              tooltip: '歌词选项',
              onPressed: track == null
                  ? null
                  : () => _openOptions(context, track),
            ),
            const Spacer(),
            if (kIsWeb ||
                (defaultTargetPlatform != TargetPlatform.macOS &&
                    defaultTargetPlatform != TargetPlatform.windows &&
                    defaultTargetPlatform != TargetPlatform.linux))
              const _LyricPlayButton(),
          ],
        ),
      ),
    );
  }

  Future<void> _openOptions(BuildContext context, PlayerTrack track) async {
    final search = await showPlayerStyledBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _LyricOptions(target: track),
    );
    if (search == true && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => LyricSearchPage(target: track)),
      );
    }
  }
}

class _AuxiliaryButton extends ConsumerWidget {
  const _AuxiliaryButton();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document =
        ref.watch(currentLyricDocumentProvider).value ??
        const LyricDocument.empty();
    final preference = ref.watch(
      appConfigProvider.select((config) => config.lyricAuxiliaryMode),
    );
    final hasAuxiliary = document.lines.any(
      (line) =>
          line.translation.trim().isNotEmpty ||
          line.romanization.trim().isNotEmpty,
    );
    final effective = preference.effective(document);
    return _OutlinedLyricButton(
      controlId: 'auxiliary',
      glyph: switch (effective) {
        AppLyricAuxiliaryMode.translation => '译',
        AppLyricAuxiliaryMode.romanization => '音',
        AppLyricAuxiliaryMode.off => '原',
      },
      tooltip: effective == AppLyricAuxiliaryMode.off
          ? '仅显示原文'
          : effective.label,
      muted: effective == AppLyricAuxiliaryMode.off,
      onPressed: !hasAuxiliary
          ? null
          : () => ref
                .read(appConfigProvider.notifier)
                .setLyricAuxiliaryMode(preference.next(document)),
    );
  }
}

class _LyricPlayButton extends ConsumerWidget {
  const _LyricPlayButton();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playing = ref.watch(
      playerControllerProvider.select((state) => state.isPlaying),
    );
    return SizedBox.square(
      key: const ValueKey('lyric-play-control'),
      dimension: 52,
      child: IconButton.filled(
        tooltip: playing ? '暂停' : '播放',
        style: IconButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xff182532),
        ),
        iconSize: 30,
        onPressed: () =>
            ref.read(playerControllerProvider.notifier).togglePlayPause(),
        icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
      ),
    );
  }
}

class _OutlinedLyricButton extends StatelessWidget {
  const _OutlinedLyricButton({
    required this.controlId,
    required this.glyph,
    required this.tooltip,
    required this.onPressed,
    this.muted = false,
  });
  final String controlId;
  final String glyph;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = muted || onPressed == null ? Colors.white54 : Colors.white;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        child: SizedBox.square(
          key: ValueKey('lyric-$controlId-control'),
          dimension: 48,
          child: InkResponse(
            onTap: onPressed,
            radius: 24,
            child: Center(
              child: Container(
                key: ValueKey('lyric-$controlId-outline'),
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color, width: 1.2),
                ),
                child: Text(
                  glyph,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(fontSize: 14, color: color, height: 1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LyricOptions extends ConsumerStatefulWidget {
  const _LyricOptions({required this.target});
  final PlayerTrack target;
  @override
  ConsumerState<_LyricOptions> createState() => _LyricOptionsState();
}

class _LyricOptionsState extends ConsumerState<_LyricOptions> {
  late final _request = LyricRequest(
    trackId: widget.target.id,
    platform: widget.target.platform,
    localPath: widget.target.path,
  );
  late final _hasManual = ref.read(lyricStoreProvider).hasManual(_request);
  bool _restoring = false;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final controller = ref.read(appConfigProvider.notifier);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(
                widget.target.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: const Text('歌词'),
            ),
            FutureBuilder<bool>(
              future: _hasManual,
              builder: (context, snapshot) => Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.search),
                    title: Text(snapshot.data == true ? '更换歌词' : '搜索歌词'),
                    onTap: _restoring
                        ? null
                        : () => Navigator.pop(context, true),
                  ),
                  if (snapshot.data == true)
                    ListTile(
                      leading: const Icon(Icons.restore),
                      title: const Text('恢复默认歌词'),
                      trailing: _restoring
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                      onTap: _restoring
                          ? null
                          : () async {
                              setState(() => _restoring = true);
                              try {
                                await ref
                                    .read(lyricStoreProvider)
                                    .restoreDefault(_request);
                                if (context.mounted) Navigator.pop(context);
                              } catch (_) {
                                AppMessageService.showError('恢复默认歌词失败，请重试');
                                if (mounted) setState(() => _restoring = false);
                              }
                            },
                    ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.style_outlined),
              title: const Text('歌词样式'),
              onTap: () => showSettingsSingleChoiceSheet<String>(
                context: context,
                playerStyled: true,
                title: '歌词样式',
                currentValue: config.playerLyricsId,
                options: [
                  for (final option in AppPlayerLyricsRegistry.instance.options)
                    SettingsChoiceOption(
                      value: option.metadata.id,
                      title: AppI18n.t(config, option.metadata.labelKey),
                    ),
                ],
                onSelected: controller.setPlayerLyricsId,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('歌词大小'),
              subtitle: Text(
                settingsLyricFontPresetLabel(config.lyricFontPreset, config),
              ),
              onTap: () => showSettingsSingleChoiceSheet<AppLyricFontPreset>(
                context: context,
                playerStyled: true,
                title: '歌词大小',
                currentValue: config.lyricFontPreset,
                options: [
                  for (final preset in AppLyricFontPreset.values)
                    SettingsChoiceOption(
                      value: preset,
                      title: settingsLyricFontPresetLabel(preset, config),
                    ),
                ],
                onSelected: controller.setLyricFontPreset,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('歌词颜色'),
              onTap: () => showSettingsSingleChoiceSheet<String>(
                context: context,
                playerStyled: true,
                title: '歌词颜色',
                currentValue:
                    config.lyricHighlightMode == AppLyricHighlightMode.auto
                    ? 'auto'
                    : config.lyricHighlightPreset.value,
                options: [
                  SettingsChoiceOption(
                    value: 'auto',
                    title: AppI18n.t(config, 'settings.choice.auto'),
                  ),
                  for (final color in AppLyricHighlightColor.values)
                    SettingsChoiceOption(
                      value: color.value,
                      title: settingsLyricHighlightColorLabel(color, config),
                      leading: Icon(Icons.circle, color: color.color),
                    ),
                ],
                onSelected: (value) {
                  if (value == 'auto') {
                    controller.setLyricHighlightMode(
                      AppLyricHighlightMode.auto,
                    );
                  } else {
                    controller.setLyricHighlightPreset(
                      AppLyricHighlightColor.fromValue(value),
                    );
                  }
                },
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.lyrics_outlined),
              title: const Text('逐字歌词'),
              value: config.enableWordByWordLyric,
              onChanged: controller.setEnableWordByWordLyric,
            ),
          ],
        ),
      ),
    );
  }
}
