import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'app_skin_asset_resolver.dart';
import 'app_skin_models.dart';
import 'app_skin_theme.dart';
import '../skins/classic_skin.dart';

class AppSkinIcon extends StatefulWidget {
  const AppSkinIcon({
    required this.role,
    this.size,
    this.color,
    this.semanticLabel,
    this.assetResolver,
    super.key,
  });

  final AppSkinIconRole role;
  final double? size;
  final Color? color;
  final String? semanticLabel;
  final AppSkinAssetResolver? assetResolver;

  @override
  State<AppSkinIcon> createState() => _AppSkinIconState();
}

class _AppSkinIconState extends State<AppSkinIcon> {
  late AppSkinAssetResolver _assetResolver;
  AppSkinAssetDescriptor? _activeAsset;
  Future<AppSkinAssetLoadResult>? _assetLoad;

  @override
  void initState() {
    super.initState();
    _assetResolver = widget.assetResolver ?? BundledAppSkinAssetResolver();
  }

  @override
  void didUpdateWidget(covariant AppSkinIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetResolver != widget.assetResolver) {
      _assetResolver = widget.assetResolver ?? BundledAppSkinAssetResolver();
      _activeAsset = null;
      _assetLoad = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final skinTheme = Theme.of(context).extension<AppSkinTheme>();
    final spec = skinTheme?.icons[widget.role];
    final size = widget.size ?? IconTheme.of(context).size ?? 24;
    final color = widget.color ?? IconTheme.of(context).color;
    if (spec == null) {
      return Icon(
        classicIconForRole(widget.role),
        size: size,
        color: color,
        semanticLabel: widget.semanticLabel,
      );
    }
    final descriptor = spec.asset.descriptor;
    _synchronizeAsset(descriptor);
    final fallback = _fallback(spec, size: size, color: color);
    if (_assetLoad == null) {
      return fallback;
    }
    return FutureBuilder<AppSkinAssetLoadResult>(
      future: _assetLoad,
      builder: (context, snapshot) {
        final result = snapshot.data;
        if (result is! AppSkinAssetLoadSuccess) {
          return fallback;
        }
        final bytes = result.bytes;
        final source = descriptor?.themeColorSource;
        return SvgPicture.memory(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          width: size,
          height: size,
          fit: BoxFit.contain,
          semanticsLabel: widget.semanticLabel,
          excludeFromSemantics: widget.semanticLabel == null,
          colorMapper: source == null || color == null
              ? null
              : _ExactColorMapper(source: source, replacement: color),
          errorBuilder: (_, _, _) => fallback,
        );
      },
    );
  }

  Widget _fallback(
    AppSkinIconSpec spec, {
    required double size,
    required Color? color,
  }) {
    return Icon(
      spec.fallbackIcon,
      size: size,
      color: color,
      semanticLabel: widget.semanticLabel,
    );
  }

  void _synchronizeAsset(AppSkinAssetDescriptor? descriptor) {
    if (_activeAsset == descriptor) {
      return;
    }
    _activeAsset = descriptor;
    _assetLoad = descriptor == null ? null : _assetResolver.load(descriptor);
  }
}

@immutable
class _ExactColorMapper extends ColorMapper {
  const _ExactColorMapper({required this.source, required this.replacement});

  final Color source;
  final Color replacement;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    return color == source ? replacement : color;
  }

  @override
  bool operator ==(Object other) {
    return other is _ExactColorMapper &&
        other.source == source &&
        other.replacement == replacement;
  }

  @override
  int get hashCode => Object.hash(source, replacement);
}
