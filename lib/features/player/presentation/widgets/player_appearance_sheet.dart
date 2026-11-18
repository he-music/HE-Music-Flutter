import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_player_appearance.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/player/app_player_appearance_palette.dart';
import '../../../../app/theme/player/app_player_style_bottom_sheet.dart';
import '../../../../app/theme/player/styles/classic_player_palette.dart';
import '../../../../shared/widgets/app_adaptive_controls.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_sheet_header.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/app_color_picker.dart';
import '../helpers/player_artwork_helper.dart';
import '../providers/player_artwork_palette_provider.dart';
import '../providers/player_providers.dart';

Future<void> showPlayerAppearanceSheet(BuildContext context) =>
    showPlayerStyledBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      heightFactor: .88,
      maxWidth: 640,
      builder: (_) => const PlayerAppearanceSheet(),
    );

class PlayerAppearanceSheet extends ConsumerStatefulWidget {
  const PlayerAppearanceSheet({super.key});

  @override
  ConsumerState<PlayerAppearanceSheet> createState() =>
      _PlayerAppearanceSheetState();
}

class _PlayerAppearanceSheetState extends ConsumerState<PlayerAppearanceSheet> {
  final _preview = ValueNotifier<AppPlayerAppearance?>(null);

  @override
  void dispose() {
    _preview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(
      appConfigProvider.select((s) => (s.playerAppearance, s.localeCode)),
    );
    final appearance = settings.$1;
    String label(String key) =>
        AppI18n.tByLocaleCode(settings.$2, 'player.appearance.$key');
    void update(AppPlayerAppearance value) {
      _preview.value = null;
      ref.read(appConfigProvider.notifier).setPlayerAppearance(value);
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSheetHeader(title: label('title'), padding: EdgeInsets.zero),
            const SizedBox(height: 12),
            ValueListenableBuilder<AppPlayerAppearance?>(
              valueListenable: _preview,
              builder: (_, draft, _) => _AppearancePreview(
                appearance: draft ?? appearance,
                animate: draft == null,
              ),
            ),
            const SizedBox(height: 20),
            Text(label('mood'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final mood in AppPlayerColorMood.values)
                  _AppearanceChoice(
                    selected: appearance.mood == mood,
                    label: label(mood.name),
                    onPressed: () => update(appearance.copyWith(mood: mood)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _ColorOverride(
              key: const ValueKey('player-background-color'),
              title: label('background'),
              value: appearance.backgroundColor,
              autoLabel: label('auto'),
              customLabel: label('custom'),
              hexLabel: label('hex'),
              invalidLabel: label('invalid_hex'),
              hueLabel: label('hue'),
              saturationLabel: label('saturation'),
              brightnessLabel: label('brightness'),
              onPreview: (color) =>
                  _preview.value = appearance.copyWith(backgroundColor: color),
              onSelected: (color) => update(
                appearance.copyWith(
                  backgroundColor: color,
                  autoBackground: color == null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ColorOverride(
              key: const ValueKey('player-accent-color'),
              title: label('accent'),
              value: appearance.accentColor,
              autoLabel: label('auto'),
              customLabel: label('custom'),
              hexLabel: label('hex'),
              invalidLabel: label('invalid_hex'),
              hueLabel: label('hue'),
              saturationLabel: label('saturation'),
              brightnessLabel: label('brightness'),
              onPreview: (color) =>
                  _preview.value = appearance.copyWith(accentColor: color),
              onSelected: (color) => update(
                appearance.copyWith(
                  accentColor: color,
                  autoAccent: color == null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label('color_note'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 32),
            AppSwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(label('cover_animation')),
              subtitle: Text(label('cover_animation_note')),
              value: appearance.animateCover,
              onChanged: (value) =>
                  update(appearance.copyWith(animateCover: value)),
            ),
            AppButton.text(
              onPressed: () => update(const AppPlayerAppearance()),
              child: Text(label('reset')),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppearanceChoice extends StatelessWidget {
  const _AppearanceChoice({
    required this.selected,
    required this.label,
    required this.onPressed,
  });
  final bool selected;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: AppButton.tonal(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected) ...[
            const Icon(Icons.check, size: 18),
            const SizedBox(width: 6),
          ],
          Flexible(child: Text(label)),
        ],
      ),
    ),
  );
}

class _AppearancePreview extends ConsumerWidget {
  const _AppearancePreview({required this.appearance, this.animate = true});
  final AppPlayerAppearance appearance;
  final bool animate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(
      playerControllerProvider.select((s) => s.displayTrack),
    );
    final image = artworkProvider(track?.artworkUrl, track?.artworkBytes);
    final colors =
        ref.watch(playerArtworkPaletteProvider(image)).value ?? const <Color>[];
    final palette = playerAppearanceScenePalette(
      classicPlayerScenePaletteFallback,
      colors,
      appearance,
    );
    return AnimatedContainer(
      key: const ValueKey('player-appearance-preview'),
      duration: !animate || MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 450),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: playerAppearanceColors(colors, appearance),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox.square(
              dimension: 72,
              child: image == null
                  ? ColoredBox(
                      color: palette.surfaceRaised,
                      child: Icon(
                        Icons.album_outlined,
                        color: palette.foreground,
                      ),
                    )
                  : Image(
                      image: image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          Icon(Icons.album_outlined, color: palette.foreground),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track?.title ?? 'HE Music',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.foreground,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                ExcludeSemantics(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(height: 3, color: palette.accent),
                      ),
                      const SizedBox(width: 12),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.accent,
                          shape: BoxShape.circle,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: palette.onAccent,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorOverride extends StatefulWidget {
  const _ColorOverride({
    super.key,
    required this.title,
    required this.value,
    required this.autoLabel,
    required this.customLabel,
    required this.hexLabel,
    required this.invalidLabel,
    required this.hueLabel,
    required this.saturationLabel,
    required this.brightnessLabel,
    required this.onPreview,
    required this.onSelected,
  });
  final String title;
  final int? value;
  final String autoLabel;
  final String customLabel;
  final String hexLabel;
  final String invalidLabel;
  final String hueLabel;
  final String saturationLabel;
  final String brightnessLabel;
  final ValueChanged<int> onPreview;
  final ValueChanged<int?> onSelected;

  @override
  State<_ColorOverride> createState() => _ColorOverrideState();
}

class _ColorOverrideState extends State<_ColorOverride> {
  static const _colors = [
    0xff6ab6ce,
    0xffa0c8a2,
    0xffb8a1df,
    0xffe3a0b5,
    0xffe3ac70,
    0xffc2c6cb,
  ];
  late final _hex = TextEditingController(text: _hexOf(widget.value));
  bool _invalid = false;
  int? _draft;
  String _hexOf(int? color) => color == null
      ? ''
      : '#${(color & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  void didUpdateWidget(covariant _ColorOverride oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _draft = null;
    if (oldWidget.value != widget.value && _parse(_hex.text) != widget.value) {
      _hex.text = _hexOf(widget.value);
      _invalid = false;
    }
  }

  int? _parse(String text) {
    final hex = text.trim().replaceFirst(RegExp(r'^#'), '');
    return RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)
        ? 0xff000000 | int.parse(hex, radix: 16)
        : null;
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.title, style: Theme.of(context).textTheme.titleSmall),
      Wrap(
        spacing: 8,
        children: [
          _AppearanceChoice(
            selected: widget.value == null,
            label: widget.autoLabel,
            onPressed: () => widget.onSelected(null),
          ),
          _AppearanceChoice(
            selected: widget.value != null,
            label: widget.customLabel,
            onPressed: () => widget.onSelected(widget.value ?? _colors.first),
          ),
        ],
      ),
      if (widget.value != null) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 4,
          children: [
            for (final color in _colors)
              AppIconButton(
                tooltip: _hexOf(color),
                onPressed: () => widget.onSelected(color),
                icon: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Color(color),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  child: widget.value == color
                      ? const Icon(Icons.check, size: 18, color: Colors.black)
                      : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        AppColorPicker(
          color: Color(_draft ?? widget.value!),
          hueLabel: widget.hueLabel,
          saturationLabel: widget.saturationLabel,
          brightnessLabel: widget.brightnessLabel,
          onChanged: (color) {
            setState(() {
              _draft = color.toARGB32();
              _invalid = false;
            });
            _hex.text = _hexOf(_draft);
            widget.onPreview(_draft!);
          },
          onChangeEnd: (color) => widget.onSelected(color.toARGB32()),
        ),
        const SizedBox(height: 8),
        AppTextField(
          controller: _hex,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: widget.hexLabel,
            hintText: '#6AB6CE',
            errorText: _invalid ? widget.invalidLabel : null,
          ),
          onChanged: (text) {
            if (_invalid) setState(() => _invalid = false);
            final color = _parse(text);
            if (color != null) widget.onSelected(color);
          },
          onSubmitted: (text) {
            final color = _parse(text);
            if (color == null) {
              setState(() => _invalid = true);
            } else {
              widget.onSelected(color);
            }
          },
        ),
      ],
    ],
  );
}
