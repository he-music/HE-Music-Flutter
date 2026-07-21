import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/skin/app_skin_asset_resolver.dart';
import '../../../../app/theme/skin/app_skin_background.dart';
import '../../../../app/theme/skin/app_skin_models.dart';
import '../../../../app/theme/skin/app_skin_registry.dart';
import '../../../../app/theme/skin/app_skin_surface.dart';
import '../../../../shared/widgets/app_back_button.dart';

class SkinSelectionPage extends ConsumerStatefulWidget {
  const SkinSelectionPage({
    this.embedded = false,
    this.assetResolver,
    super.key,
  });

  final bool embedded;
  final AppSkinAssetResolver? assetResolver;

  @override
  ConsumerState<SkinSelectionPage> createState() => _SkinSelectionPageState();
}

class _SkinSelectionPageState extends ConsumerState<SkinSelectionPage> {
  late AppSkinAssetResolver _assetResolver;
  late String _appliedSkinId;
  late String _candidateSkinId;

  @override
  void initState() {
    super.initState();
    _assetResolver = widget.assetResolver ?? BundledAppSkinAssetResolver();
    final config = ref.read(appConfigProvider);
    final registry = AppSkinRegistry.builtIn(config.themeAccent);
    _appliedSkinId = registry.normalizeId(config.skinId);
    _candidateSkinId = _appliedSkinId;
  }

  @override
  void didUpdateWidget(covariant SkinSelectionPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetResolver != widget.assetResolver) {
      _assetResolver = widget.assetResolver ?? BundledAppSkinAssetResolver();
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final registry = AppSkinRegistry.builtIn(config.themeAccent);
    final content = ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: registry.skins.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final skin = registry.skins[index];
        return _SkinChoiceCard(
          skin: skin,
          selected: skin.metadata.id == _candidateSkinId,
          applied: skin.metadata.id == _appliedSkinId,
          localeCode: config.localeCode,
          assetResolver: _assetResolver,
          onTap: () {
            setState(() {
              _candidateSkinId = skin.metadata.id;
            });
          },
        );
      },
    );
    if (widget.embedded) {
      return content;
    }
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(AppI18n.t(config, 'settings.skin.selection.title')),
      ),
      body: content,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          key: const ValueKey<String>('apply-skin-button'),
          onPressed: _candidateSkinId == _appliedSkinId
              ? null
              : () => _applyCandidate(registry),
          child: Text(AppI18n.t(config, 'settings.skin.apply')),
        ),
      ),
    );
  }

  void _applyCandidate(AppSkinRegistry registry) {
    if (!registry.contains(_candidateSkinId)) {
      setState(() {
        _candidateSkinId = registry.normalizeId(_candidateSkinId);
      });
      return;
    }
    ref.read(appConfigProvider.notifier).setSkinId(_candidateSkinId);
    setState(() {
      _appliedSkinId = _candidateSkinId;
    });
  }
}

class _SkinChoiceCard extends StatelessWidget {
  const _SkinChoiceCard({
    required this.skin,
    required this.selected,
    required this.applied,
    required this.localeCode,
    required this.assetResolver,
    required this.onTap,
  });

  final AppSkinPackage skin;
  final bool selected;
  final bool applied;
  final String localeCode;
  final AppSkinAssetResolver assetResolver;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: Card(
        key: ValueKey<String>('skin-choice-${skin.metadata.id}'),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            AppI18n.tByLocaleCode(
                              localeCode,
                              skin.metadata.nameKey,
                            ),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppI18n.tByLocaleCode(
                              localeCode,
                              skin.metadata.descriptionKey,
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (applied) ...<Widget>[
                            const SizedBox(height: 8),
                            Text(
                              AppI18n.tByLocaleCode(
                                localeCode,
                                'settings.skin.applied',
                              ),
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: colorScheme.primary),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (selected) ...<Widget>[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.check_circle_rounded,
                        color: colorScheme.primary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (final brightness in const <Brightness>[
                      Brightness.light,
                      Brightness.dark,
                    ]) ...<Widget>[
                      if (brightness == Brightness.dark)
                        const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: <Widget>[
                            Text(
                              AppI18n.tByLocaleCode(
                                localeCode,
                                brightness == Brightness.light
                                    ? 'my.theme.light'
                                    : 'my.theme.dark',
                              ),
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 104,
                                ),
                                child: _SkinPreview(
                                  skin: skin,
                                  brightness: brightness,
                                  assetResolver: assetResolver,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkinPreview extends StatelessWidget {
  const _SkinPreview({
    required this.skin,
    required this.brightness,
    required this.assetResolver,
  });

  final AppSkinPackage skin;
  final Brightness brightness;
  final AppSkinAssetResolver assetResolver;

  @override
  Widget build(BuildContext context) {
    final preview = brightness == Brightness.dark
        ? skin.metadata.darkPreview
        : skin.metadata.lightPreview;
    final suffix = '${skin.metadata.id}-${brightness.name}';
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          key: ValueKey<String>('skin-preview-${brightness.name}'),
          fit: StackFit.expand,
          children: <Widget>[
            _ResolvedSkinPreview(
              descriptor: preview.descriptor,
              assetResolver: assetResolver,
              imageKey: ValueKey<String>('skin-preview-image-$suffix'),
              fallback: KeyedSubtree(
                key: ValueKey<String>('skin-preview-live-$suffix'),
                child: _LiveSkinPreview(skin: skin, brightness: brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResolvedSkinPreview extends StatefulWidget {
  const _ResolvedSkinPreview({
    required this.descriptor,
    required this.assetResolver,
    required this.imageKey,
    required this.fallback,
  });

  final AppSkinAssetDescriptor? descriptor;
  final AppSkinAssetResolver assetResolver;
  final Key imageKey;
  final Widget fallback;

  @override
  State<_ResolvedSkinPreview> createState() => _ResolvedSkinPreviewState();
}

class _ResolvedSkinPreviewState extends State<_ResolvedSkinPreview> {
  AppSkinAssetDescriptor? _activeDescriptor;
  Future<MemoryImage?>? _imageLoad;

  @override
  void didUpdateWidget(covariant _ResolvedSkinPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetResolver != widget.assetResolver) {
      _activeDescriptor = null;
      _imageLoad = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _synchronizeImage(widget.descriptor);
    if (_imageLoad == null) {
      return widget.fallback;
    }
    return FutureBuilder<MemoryImage?>(
      future: _imageLoad,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return ColoredBox(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          );
        }
        final imageProvider = snapshot.data;
        if (imageProvider == null) {
          return widget.fallback;
        }
        return Image(
          key: widget.imageKey,
          image: imageProvider,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
          errorBuilder: (_, _, _) => widget.fallback,
        );
      },
    );
  }

  void _synchronizeImage(AppSkinAssetDescriptor? descriptor) {
    if (_activeDescriptor == descriptor) {
      return;
    }
    _activeDescriptor = descriptor;
    _imageLoad = descriptor == null ? null : _loadImage(descriptor);
  }

  Future<MemoryImage?> _loadImage(AppSkinAssetDescriptor descriptor) async {
    final result = await widget.assetResolver.load(descriptor);
    if (result is! AppSkinAssetLoadSuccess) {
      return null;
    }
    final bytes = result.bytes;
    return MemoryImage(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  }
}

class _LiveSkinPreview extends StatelessWidget {
  const _LiveSkinPreview({required this.skin, required this.brightness});

  final AppSkinPackage skin;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final theme = brightness == Brightness.dark
        ? AppTheme.dark(skin)
        : AppTheme.light(skin);
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) {
          final colors = Theme.of(context).colorScheme;
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              AppSkinBackgroundLayer(skin: skin, enableAnimation: false),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
                child: Column(
                  children: <Widget>[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 48,
                        height: 5,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 9),
                    AppSkinSurface(
                      role: AppSkinSurfaceRole.search,
                      borderRadius: BorderRadius.circular(6),
                      child: const SizedBox(height: 18),
                    ),
                    const SizedBox(height: 9),
                    Expanded(
                      child: Column(
                        children: List<Widget>.generate(
                          4,
                          (index) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: AppSkinSurface(
                                role: AppSkinSurfaceRole.scrollingContent,
                                borderRadius: BorderRadius.circular(5),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    AppSkinSurface(
                      role: AppSkinSurfaceRole.miniPlayer,
                      borderRadius: BorderRadius.circular(6),
                      child: const SizedBox(height: 20),
                    ),
                    const SizedBox(height: 4),
                    AppSkinSurface(
                      role: AppSkinSurfaceRole.navigation,
                      borderRadius: BorderRadius.circular(6),
                      child: const SizedBox(height: 22),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
