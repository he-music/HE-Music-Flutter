import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/skin/app_skin_asset_resolver.dart';
import '../../../../app/theme/skin/app_skin_models.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../controllers/custom_skin_editor_controller.dart';

class CustomSkinEditorPage extends ConsumerStatefulWidget {
  const CustomSkinEditorPage({this.assetResolver, super.key});

  final AppSkinAssetResolver? assetResolver;

  @override
  ConsumerState<CustomSkinEditorPage> createState() =>
      _CustomSkinEditorPageState();
}

class _CustomSkinEditorPageState extends ConsumerState<CustomSkinEditorPage> {
  late AppSkinAssetResolver _assetResolver;

  @override
  void initState() {
    super.initState();
    _assetResolver = widget.assetResolver ?? BundledAppSkinAssetResolver();
    Future.microtask(() {
      if (mounted) {
        ref.read(customSkinEditorControllerProvider.notifier).initialize();
      }
    });
  }

  @override
  void didUpdateWidget(covariant CustomSkinEditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetResolver != widget.assetResolver) {
      _assetResolver = widget.assetResolver ?? BundledAppSkinAssetResolver();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(
      appConfigProvider.select(
        (state) => (localeCode: state.localeCode, skinId: state.skinId),
      ),
    );
    final editor = ref.watch(customSkinEditorControllerProvider);
    final controller = ref.read(customSkinEditorControllerProvider.notifier);
    ref.listen<CustomSkinEditorState>(customSkinEditorControllerProvider, (
      previous,
      next,
    ) {
      if (next.errorKey != null &&
          next.errorVersion != previous?.errorVersion) {
        AppMessageService.showError(
          AppI18n.tByLocaleCode(config.localeCode, next.errorKey!),
        );
      }
    });
    final busy =
        editor.phase == CustomSkinEditorPhase.processing ||
        editor.phase == CustomSkinEditorPhase.saving;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(
          AppI18n.tByLocaleCode(config.localeCode, 'settings.skin.custom.name'),
        ),
        actions: <Widget>[
          if (editor.draft != null)
            IconButton(
              key: const ValueKey<String>('replace-custom-skin-image'),
              tooltip: AppI18n.tByLocaleCode(
                config.localeCode,
                'settings.skin.custom.replace',
              ),
              onPressed: busy ? null : controller.chooseImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
            ),
          if (editor.canDelete)
            IconButton(
              key: const ValueKey<String>('delete-custom-skin'),
              tooltip: AppI18n.tByLocaleCode(
                config.localeCode,
                'settings.skin.custom.delete',
              ),
              onPressed: busy
                  ? null
                  : () => _confirmDelete(config.localeCode, controller),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: switch (editor.draft) {
        null => _EmptyEditor(
          localeCode: config.localeCode,
          processing: editor.phase == CustomSkinEditorPhase.processing,
          onChoose: controller.chooseImage,
        ),
        final draft => _EditorWorkbench(
          draft: draft,
          localeCode: config.localeCode,
          busy: busy,
          assetResolver: _assetResolver,
          onSeedSelected: controller.selectSeed,
          onSwap: controller.swapBrightness,
          onFocalChanged: controller.setFocalPoint,
        ),
      },
      bottomNavigationBar: editor.draft == null
          ? null
          : SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: const ValueKey<String>('apply-custom-skin'),
                      onPressed: busy || !editor.canApplyFor(config.skinId)
                          ? null
                          : () async {
                              final applied = await controller.apply();
                              if (!mounted || !applied) {
                                return;
                              }
                              AppMessageService.showSuccess(
                                AppI18n.tByLocaleCode(
                                  config.localeCode,
                                  'settings.skin.custom.applied',
                                ),
                              );
                            },
                      child: editor.phase == CustomSkinEditorPhase.saving
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              AppI18n.tByLocaleCode(
                                config.localeCode,
                                'settings.skin.apply',
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _confirmDelete(
    String localeCode,
    CustomSkinEditorController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppI18n.tByLocaleCode(
            localeCode,
            'settings.skin.custom.delete.confirm_title',
          ),
        ),
        content: Text(
          AppI18n.tByLocaleCode(
            localeCode,
            'settings.skin.custom.delete.confirm_message',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppI18n.tByLocaleCode(localeCode, 'common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              AppI18n.tByLocaleCode(localeCode, 'settings.skin.custom.delete'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final deleted = await controller.delete();
    if (mounted && deleted) {
      Navigator.of(context).pop();
    }
  }
}

class _EmptyEditor extends StatelessWidget {
  const _EmptyEditor({
    required this.localeCode,
    required this.processing,
    required this.onChoose,
  });

  final String localeCode;
  final bool processing;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: processing
          ? const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : FilledButton.icon(
              key: const ValueKey<String>('choose-custom-skin-image'),
              onPressed: onChoose,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                AppI18n.tByLocaleCode(
                  localeCode,
                  defaultTargetPlatform == TargetPlatform.macOS
                      ? 'settings.skin.custom.choose.file'
                      : 'settings.skin.custom.choose',
                ),
              ),
            ),
    );
  }
}

class _EditorWorkbench extends StatefulWidget {
  const _EditorWorkbench({
    required this.draft,
    required this.localeCode,
    required this.busy,
    required this.assetResolver,
    required this.onSeedSelected,
    required this.onSwap,
    required this.onFocalChanged,
  });

  final CustomSkinEditorDraft draft;
  final String localeCode;
  final bool busy;
  final AppSkinAssetResolver assetResolver;
  final ValueChanged<int> onSeedSelected;
  final VoidCallback onSwap;
  final void Function(double x, double y) onFocalChanged;

  @override
  State<_EditorWorkbench> createState() => _EditorWorkbenchState();
}

class _EditorWorkbenchState extends State<_EditorWorkbench> {
  late final ValueNotifier<Alignment> _focal;

  @override
  void initState() {
    super.initState();
    _focal = ValueNotifier<Alignment>(_draftFocal(widget.draft));
  }

  @override
  void didUpdateWidget(covariant _EditorWorkbench oldWidget) {
    super.didUpdateWidget(oldWidget);
    final draftChanged = oldWidget.draft.revision != widget.draft.revision;
    final focalChanged =
        oldWidget.draft.focalX != widget.draft.focalX ||
        oldWidget.draft.focalY != widget.draft.focalY;
    if (draftChanged || focalChanged) {
      _focal.value = _draftFocal(widget.draft);
    }
  }

  @override
  void dispose() {
    _focal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = defaultTargetPlatform == TargetPlatform.macOS;
    final previewAspectRatio = desktop ? 16 / 10 : 9 / 16;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: <Widget>[
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Stack(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: _BrightnessPreview(
                            key: const ValueKey<String>('custom-preview-light'),
                            label: AppI18n.tByLocaleCode(
                              widget.localeCode,
                              'my.theme.light',
                            ),
                            brightness: Brightness.light,
                            bytes: widget.draft.lightPreviewBytes,
                            assetPath: widget.draft.lightAssetPath,
                            seedColor: Color(widget.draft.seedColor),
                            focal: _focal,
                            sourceWidth: widget.draft.sourceWidth,
                            sourceHeight: widget.draft.sourceHeight,
                            aspectRatio: previewAspectRatio,
                            assetResolver: widget.assetResolver,
                            enabled: !widget.busy,
                            onFocalDelta: _moveFocal,
                            onFocalCommit: _commitFocal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _BrightnessPreview(
                            key: const ValueKey<String>('custom-preview-dark'),
                            label: AppI18n.tByLocaleCode(
                              widget.localeCode,
                              'my.theme.dark',
                            ),
                            brightness: Brightness.dark,
                            bytes: widget.draft.darkPreviewBytes,
                            assetPath: widget.draft.darkAssetPath,
                            seedColor: Color(widget.draft.seedColor),
                            focal: _focal,
                            sourceWidth: widget.draft.sourceWidth,
                            sourceHeight: widget.draft.sourceHeight,
                            aspectRatio: previewAspectRatio,
                            assetResolver: widget.assetResolver,
                            enabled: !widget.busy,
                            onFocalDelta: _moveFocal,
                            onFocalCommit: _commitFocal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    IconButton(
                      key: const ValueKey<String>(
                        'swap-custom-skin-brightness',
                      ),
                      tooltip: AppI18n.tByLocaleCode(
                        widget.localeCode,
                        'settings.skin.custom.swap',
                      ),
                      onPressed: widget.busy ? null : widget.onSwap,
                      icon: const Icon(Icons.swap_horiz_rounded),
                    ),
                    const SizedBox(height: 12),
                    _ColorSwatches(
                      colors: widget.draft.candidateColors,
                      selected: widget.draft.seedColor,
                      enabled: !widget.busy,
                      onSelected: widget.onSeedSelected,
                    ),
                  ],
                ),
                if (widget.busy)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _moveFocal(double dx, double dy) {
    final current = _focal.value;
    _focal.value = Alignment(
      (current.x + dx).clamp(-1.0, 1.0),
      (current.y + dy).clamp(-1.0, 1.0),
    );
  }

  void _commitFocal() {
    final focal = _focal.value;
    if (focal.x == widget.draft.focalX && focal.y == widget.draft.focalY) {
      return;
    }
    widget.onFocalChanged(focal.x, focal.y);
  }

  Alignment _draftFocal(CustomSkinEditorDraft draft) {
    return Alignment(draft.focalX, draft.focalY);
  }
}

class _BrightnessPreview extends StatelessWidget {
  const _BrightnessPreview({
    required this.label,
    required this.brightness,
    required this.bytes,
    required this.assetPath,
    required this.seedColor,
    required this.focal,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.aspectRatio,
    required this.assetResolver,
    required this.enabled,
    required this.onFocalDelta,
    required this.onFocalCommit,
    super.key,
  });

  final String label;
  final Brightness brightness;
  final Uint8List? bytes;
  final String assetPath;
  final Color seedColor;
  final ValueListenable<Alignment> focal;
  final int sourceWidth;
  final int sourceHeight;
  final double aspectRatio;
  final AppSkinAssetResolver assetResolver;
  final bool enabled;
  final void Function(double dx, double dy) onFocalDelta;
  final VoidCallback onFocalCommit;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    return Column(
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: aspectRatio,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Focus(
                canRequestFocus: enabled,
                onKeyEvent: (_, event) {
                  if (!enabled || event is! KeyDownEvent) {
                    return KeyEventResult.ignored;
                  }
                  final delta = switch (event.logicalKey) {
                    LogicalKeyboardKey.arrowLeft => const Offset(-0.05, 0),
                    LogicalKeyboardKey.arrowRight => const Offset(0.05, 0),
                    LogicalKeyboardKey.arrowUp => const Offset(0, -0.05),
                    LogicalKeyboardKey.arrowDown => const Offset(0, 0.05),
                    _ => null,
                  };
                  if (delta == null) {
                    return KeyEventResult.ignored;
                  }
                  onFocalDelta(delta.dx, delta.dy);
                  onFocalCommit();
                  return KeyEventResult.handled;
                },
                child: GestureDetector(
                  onPanUpdate: enabled
                      ? (details) =>
                            _handlePan(details.delta, constraints.biggest)
                      : null,
                  onPanEnd: enabled ? (_) => onFocalCommit() : null,
                  onPanCancel: enabled ? onFocalCommit : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        ValueListenableBuilder<Alignment>(
                          valueListenable: focal,
                          builder: (context, alignment, _) {
                            return _CustomPreviewImage(
                              bytes: bytes,
                              assetPath: assetPath,
                              alignment: alignment,
                              assetResolver: assetResolver,
                            );
                          },
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: 30,
                            color: scheme.surface.withValues(alpha: 0.82),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    height: 5,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _handlePan(Offset delta, Size viewport) {
    final scale = math.max(
      viewport.width / sourceWidth,
      viewport.height / sourceHeight,
    );
    final overflowX = sourceWidth * scale - viewport.width;
    final overflowY = sourceHeight * scale - viewport.height;
    onFocalDelta(
      overflowX <= 0 ? 0 : -delta.dx * 2 / overflowX,
      overflowY <= 0 ? 0 : -delta.dy * 2 / overflowY,
    );
  }
}

class _ColorSwatches extends StatelessWidget {
  const _ColorSwatches({
    required this.colors,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final List<int> colors;
  final int selected;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      key: const ValueKey<String>('custom-skin-color-swatches'),
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        for (final value in colors)
          Semantics(
            selected: value == selected,
            button: true,
            child: InkResponse(
              key: ValueKey<String>('custom-skin-color-$value'),
              onTap: enabled ? () => onSelected(value) : null,
              radius: 24,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Color(value),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: value == selected
                        ? colorScheme.onSurface
                        : colorScheme.outlineVariant,
                    width: value == selected ? 3 : 1,
                  ),
                ),
                child: value == selected
                    ? Icon(
                        Icons.check_rounded,
                        size: 20,
                        color:
                            ThemeData.estimateBrightnessForColor(
                                  Color(value),
                                ) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _CustomPreviewImage extends StatefulWidget {
  const _CustomPreviewImage({
    required this.bytes,
    required this.assetPath,
    required this.alignment,
    required this.assetResolver,
  });

  final Uint8List? bytes;
  final String assetPath;
  final Alignment alignment;
  final AppSkinAssetResolver assetResolver;

  @override
  State<_CustomPreviewImage> createState() => _CustomPreviewImageState();
}

class _CustomPreviewImageState extends State<_CustomPreviewImage> {
  String? _activePath;
  AppSkinAssetResolver? _activeResolver;
  Future<MemoryImage?>? _load;

  @override
  Widget build(BuildContext context) {
    final inMemory = widget.bytes;
    if (inMemory != null) {
      return Image.memory(
        inMemory,
        fit: BoxFit.cover,
        alignment: widget.alignment,
        gaplessPlayback: true,
      );
    }
    _synchronize();
    return FutureBuilder<MemoryImage?>(
      future: _load,
      builder: (context, snapshot) {
        final provider = snapshot.data;
        if (provider == null) {
          return ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          );
        }
        return Image(
          image: provider,
          fit: BoxFit.cover,
          alignment: widget.alignment,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        );
      },
    );
  }

  void _synchronize() {
    if (_activePath == widget.assetPath &&
        _activeResolver == widget.assetResolver) {
      return;
    }
    _activePath = widget.assetPath;
    _activeResolver = widget.assetResolver;
    _load = _loadImage();
  }

  Future<MemoryImage?> _loadImage() async {
    final result = await widget.assetResolver.load(
      AppSkinAssetDescriptor(
        path: widget.assetPath,
        type: AppSkinAssetType.rasterImage,
        source: AppSkinAssetSource.applicationSupport,
      ),
    );
    if (result is! AppSkinAssetLoadSuccess) {
      return null;
    }
    final bytes = result.bytes;
    return MemoryImage(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  }
}
