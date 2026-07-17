import 'package:flutter/material.dart';

import '../../config/app_theme_accent.dart';
import '../skins/city_sound_creator_skin.dart';
import '../skins/classic_skin.dart';
import 'app_skin_models.dart';

class AppSkinRegistry {
  AppSkinRegistry(Iterable<AppSkinPackage> packages)
    : _skins = _buildRegistry(packages);

  factory AppSkinRegistry.builtIn(AppThemeAccent accent) {
    return AppSkinRegistry(<AppSkinPackage>[
      classicSkinForAccent(accent),
      citySoundCreatorSkin(),
    ]);
  }

  static const String classicId = 'classic';
  static const String citySoundCreatorId = 'city_sound_creator';
  static const Set<String> builtInIds = <String>{classicId, citySoundCreatorId};

  final Map<String, AppSkinPackage> _skins;

  List<AppSkinPackage> get skins =>
      List<AppSkinPackage>.unmodifiable(_skins.values);

  bool contains(String? id) => id != null && _skins.containsKey(id);

  String normalizeId(String? id) => contains(id) ? id! : classicId;

  AppSkinPackage resolve(String? id) {
    return _skins[normalizeId(id)]!;
  }

  static Map<String, AppSkinPackage> _buildRegistry(
    Iterable<AppSkinPackage> packages,
  ) {
    final source = packages.toList(growable: false);
    final seenIds = <String>{};
    for (final package in source) {
      if (!seenIds.add(package.metadata.id)) {
        throw StateError('Duplicate skin id: ${package.metadata.id}');
      }
    }
    final classic = source
        .where((package) => package.metadata.id == classicId)
        .firstOrNull;
    if (classic == null) {
      throw StateError('Skin registry requires classic');
    }
    _validatePackage(classic, requireResolvedSlots: true);

    final resolved = <String, AppSkinPackage>{};
    for (final package in source) {
      final value = package.metadata.id == classicId
          ? package
          : _resolveAgainstClassic(package, classic);
      _validatePackage(value, requireResolvedSlots: true);
      resolved[value.metadata.id] = value;
    }
    return Map<String, AppSkinPackage>.unmodifiable(resolved);
  }

  static AppSkinPackage _resolveAgainstClassic(
    AppSkinPackage package,
    AppSkinPackage classic,
  ) {
    final classicLightPreview = classic.metadata.lightPreview;
    final classicDarkPreview = classic.metadata.darkPreview;
    return package.copyWith(
      metadata: package.metadata.copyWith(
        lightPreview: package.metadata.lightPreview.resolve(
          classicLightPreview,
        ),
        darkPreview: package.metadata.darkPreview.resolve(classicDarkPreview),
      ),
      light: package.light.resolve(classic.light),
      dark: package.dark.resolve(classic.dark),
      icons: package.icons.resolve(classic.icons),
    );
  }

  static void _validatePackage(
    AppSkinPackage package, {
    required bool requireResolvedSlots,
  }) {
    final metadata = package.metadata;
    if (!RegExp(r'^[a-z][a-z0-9_]*$').hasMatch(metadata.id)) {
      throw StateError('Invalid skin id: ${metadata.id}');
    }
    if (metadata.nameKey.trim().isEmpty ||
        metadata.descriptionKey.trim().isEmpty) {
      throw StateError('Skin metadata is incomplete: ${metadata.id}');
    }
    _validateSlot(
      metadata.lightPreview,
      owner: '${metadata.id}.lightPreview',
      expectedType: AppSkinAssetType.rasterImage,
      requireResolved: requireResolvedSlots,
    );
    _validateSlot(
      metadata.darkPreview,
      owner: '${metadata.id}.darkPreview',
      expectedType: AppSkinAssetType.rasterImage,
      requireResolved: requireResolvedSlots,
    );
    _validateBrightness(
      metadata.id,
      package.light,
      expectedBrightness: Brightness.light,
      requireResolvedSlots: requireResolvedSlots,
    );
    _validateBrightness(
      metadata.id,
      package.dark,
      expectedBrightness: Brightness.dark,
      requireResolvedSlots: requireResolvedSlots,
    );
    if (package.icons.values.length != AppSkinIconRole.values.length) {
      throw StateError('Skin icon catalog is incomplete: ${metadata.id}');
    }
    for (final role in AppSkinIconRole.values) {
      final spec = package.icons[role];
      if (spec == null) {
        throw StateError('Missing skin icon role: ${metadata.id}.$role');
      }
      _validateSlot(
        spec.asset,
        owner: '${metadata.id}.$role',
        expectedType: AppSkinAssetType.svg,
        requireResolved: requireResolvedSlots,
      );
    }
  }

  static void _validateBrightness(
    String id,
    AppSkinBrightnessConfig config, {
    required Brightness expectedBrightness,
    required bool requireResolvedSlots,
  }) {
    if (config.colorScheme.brightness != expectedBrightness) {
      throw StateError('Skin brightness mismatch: $id.$expectedBrightness');
    }
    if (!config.surfaces.isValid || !config.geometry.isValid) {
      throw StateError('Invalid skin surface values: $id.$expectedBrightness');
    }
    _validateSlot(
      config.background.wallpaper,
      owner: '$id.$expectedBrightness.wallpaper',
      expectedType: AppSkinAssetType.rasterImage,
      requireResolved: requireResolvedSlots,
    );
    if (!config.background.animation.isValid) {
      throw StateError('Invalid skin animation: $id.$expectedBrightness');
    }
  }

  static void _validateSlot(
    AppSkinAssetSlot slot, {
    required String owner,
    required AppSkinAssetType expectedType,
    required bool requireResolved,
  }) {
    if (!slot.isValid || (requireResolved && !slot.isResolved)) {
      throw StateError('Invalid skin asset slot: $owner');
    }
    final descriptor = slot.descriptor;
    if (descriptor != null && descriptor.type != expectedType) {
      throw StateError('Unexpected skin asset type: $owner');
    }
  }
}
