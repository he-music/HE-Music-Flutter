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

  @override
  void initState() {
    super.initState();
    _assetResolver = widget.assetResolver ?? BundledAppSkinAssetResolver();
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
    final appliedSkinId = registry.normalizeId(config.skinId);
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = switch (constraints.maxWidth) {
          < 280 => 1,
          < 520 => 2,
          < 720 => 3,
          _ => 4,
        };
        return GridView.builder(
          key: const ValueKey<String>('skin-selection-grid'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: registry.skins.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 252,
          ),
          itemBuilder: (context, index) {
            final skin = registry.skins[index];
            return _SkinSummaryCard(
              skin: skin,
              applied: skin.metadata.id == appliedSkinId,
              localeCode: config.localeCode,
              assetResolver: _assetResolver,
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => _SkinDetailPage(
                      skinId: skin.metadata.id,
                      assetResolver: _assetResolver,
                    ),
                  ),
                );
              },
            );
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
    );
  }
}

class _SkinSummaryCard extends StatelessWidget {
  const _SkinSummaryCard({
    required this.skin,
    required this.applied,
    required this.localeCode,
    required this.assetResolver,
    required this.onTap,
  });

  final AppSkinPackage skin;
  final bool applied;
  final String localeCode;
  final AppSkinAssetResolver assetResolver;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      selected: applied,
      button: true,
      child: Card(
        key: ValueKey<String>('skin-choice-${skin.metadata.id}'),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: applied ? colorScheme.primary : colorScheme.outlineVariant,
            width: applied ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 88),
                      child: _SkinPreview(
                        skin: skin,
                        brightness: Brightness.light,
                        assetResolver: assetResolver,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    AppI18n.tByLocaleCode(localeCode, skin.metadata.nameKey),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 2),
                Visibility(
                  visible: applied,
                  maintainAnimation: true,
                  maintainSize: true,
                  maintainState: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          AppI18n.tByLocaleCode(
                            localeCode,
                            'settings.skin.applied',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkinDetailPage extends ConsumerWidget {
  const _SkinDetailPage({required this.skinId, required this.assetResolver});

  final String skinId;
  final AppSkinAssetResolver assetResolver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final registry = AppSkinRegistry.builtIn(config.themeAccent);
    final skin = registry.resolve(skinId);
    final applied = skin.metadata.id == registry.normalizeId(config.skinId);
    final localeCode = config.localeCode;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(AppI18n.tByLocaleCode(localeCode, skin.metadata.nameKey)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
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
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.topCenter,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 180,
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
                  const SizedBox(height: 24),
                  Text(
                    AppI18n.tByLocaleCode(
                      localeCode,
                      skin.metadata.descriptionKey,
                    ),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey<String>('apply-skin-button'),
                onPressed: applied
                    ? null
                    : () => ref
                          .read(appConfigProvider.notifier)
                          .setSkinId(skin.metadata.id),
                child: Text(
                  AppI18n.tByLocaleCode(
                    localeCode,
                    applied ? 'settings.skin.applied' : 'settings.skin.apply',
                  ),
                ),
              ),
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
