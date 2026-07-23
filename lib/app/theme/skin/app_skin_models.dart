import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum AppSkinAssetType { rasterImage, svg, rive }

@immutable
class AppSkinAssetDescriptor {
  const AppSkinAssetDescriptor({
    required this.path,
    required this.type,
    this.themeColorSource,
  });

  final String path;
  final AppSkinAssetType type;
  final Color? themeColorSource;

  AppSkinAssetDescriptor copyWith({
    String? path,
    AppSkinAssetType? type,
    Color? themeColorSource,
    bool clearThemeColorSource = false,
  }) {
    return AppSkinAssetDescriptor(
      path: path ?? this.path,
      type: type ?? this.type,
      themeColorSource: clearThemeColorSource
          ? null
          : themeColorSource ?? this.themeColorSource,
    );
  }

  bool get isValid {
    final normalized = path.trim();
    return normalized == path &&
        normalized.startsWith('assets/skins/') &&
        !normalized.contains('..') &&
        normalized.length > 'assets/skins/'.length;
  }

  @override
  bool operator ==(Object other) {
    return other is AppSkinAssetDescriptor &&
        other.path == path &&
        other.type == type &&
        other.themeColorSource == themeColorSource;
  }

  @override
  int get hashCode => Object.hash(path, type, themeColorSource);
}

enum AppSkinAssetSlotKind { inherit, none, asset }

@immutable
class AppSkinAssetSlot {
  const AppSkinAssetSlot.inherit()
    : kind = AppSkinAssetSlotKind.inherit,
      descriptor = null;

  const AppSkinAssetSlot.none()
    : kind = AppSkinAssetSlotKind.none,
      descriptor = null;

  const AppSkinAssetSlot.asset(this.descriptor)
    : kind = AppSkinAssetSlotKind.asset;

  final AppSkinAssetSlotKind kind;
  final AppSkinAssetDescriptor? descriptor;

  AppSkinAssetSlot copyWith({AppSkinAssetDescriptor? descriptor}) {
    return switch (kind) {
      AppSkinAssetSlotKind.inherit => const AppSkinAssetSlot.inherit(),
      AppSkinAssetSlotKind.none => const AppSkinAssetSlot.none(),
      AppSkinAssetSlotKind.asset => AppSkinAssetSlot.asset(
        descriptor ?? this.descriptor!,
      ),
    };
  }

  bool get isResolved => kind != AppSkinAssetSlotKind.inherit;

  bool get isValid {
    return switch (kind) {
      AppSkinAssetSlotKind.inherit ||
      AppSkinAssetSlotKind.none => descriptor == null,
      AppSkinAssetSlotKind.asset => descriptor?.isValid ?? false,
    };
  }

  AppSkinAssetSlot resolve(AppSkinAssetSlot fallback) {
    return kind == AppSkinAssetSlotKind.inherit ? fallback : this;
  }

  @override
  bool operator ==(Object other) {
    return other is AppSkinAssetSlot &&
        other.kind == kind &&
        other.descriptor == descriptor;
  }

  @override
  int get hashCode => Object.hash(kind, descriptor);
}

sealed class AppSkinAnimationDescriptor {
  const AppSkinAnimationDescriptor();

  const factory AppSkinAnimationDescriptor.none() =
      AppSkinNoAnimationDescriptor;

  const factory AppSkinAnimationDescriptor.rive({
    required AppSkinAssetDescriptor asset,
    required String artboard,
    required String stateMachine,
    required BoxFit fit,
    required Alignment alignment,
    required double opacity,
  }) = AppSkinRiveAnimationDescriptor;

  bool get isValid;
}

final class AppSkinNoAnimationDescriptor extends AppSkinAnimationDescriptor {
  const AppSkinNoAnimationDescriptor();

  AppSkinNoAnimationDescriptor copyWith() => this;

  @override
  bool get isValid => true;

  @override
  bool operator ==(Object other) => other is AppSkinNoAnimationDescriptor;

  @override
  int get hashCode => 0;
}

final class AppSkinRiveAnimationDescriptor extends AppSkinAnimationDescriptor {
  const AppSkinRiveAnimationDescriptor({
    required this.asset,
    required this.artboard,
    required this.stateMachine,
    required this.fit,
    required this.alignment,
    required this.opacity,
  });

  final AppSkinAssetDescriptor asset;
  final String artboard;
  final String stateMachine;
  final BoxFit fit;
  final Alignment alignment;
  final double opacity;

  AppSkinRiveAnimationDescriptor copyWith({
    AppSkinAssetDescriptor? asset,
    String? artboard,
    String? stateMachine,
    BoxFit? fit,
    Alignment? alignment,
    double? opacity,
  }) {
    return AppSkinRiveAnimationDescriptor(
      asset: asset ?? this.asset,
      artboard: artboard ?? this.artboard,
      stateMachine: stateMachine ?? this.stateMachine,
      fit: fit ?? this.fit,
      alignment: alignment ?? this.alignment,
      opacity: opacity ?? this.opacity,
    );
  }

  @override
  bool get isValid {
    return asset.isValid &&
        asset.type == AppSkinAssetType.rive &&
        artboard.trim().isNotEmpty &&
        stateMachine.trim().isNotEmpty &&
        opacity >= 0 &&
        opacity <= 1;
  }

  @override
  bool operator ==(Object other) {
    return other is AppSkinRiveAnimationDescriptor &&
        other.asset == asset &&
        other.artboard == artboard &&
        other.stateMachine == stateMachine &&
        other.fit == fit &&
        other.alignment == alignment &&
        other.opacity == opacity;
  }

  @override
  int get hashCode {
    return Object.hash(asset, artboard, stateMachine, fit, alignment, opacity);
  }
}

@immutable
class AppSkinMetadata {
  const AppSkinMetadata({
    required this.id,
    required this.nameKey,
    required this.descriptionKey,
    required this.allowsManualAccent,
    required this.lightPreview,
    required this.darkPreview,
  });

  final String id;
  final String nameKey;
  final String descriptionKey;
  final bool allowsManualAccent;
  final AppSkinAssetSlot lightPreview;
  final AppSkinAssetSlot darkPreview;

  AppSkinMetadata copyWith({
    String? id,
    String? nameKey,
    String? descriptionKey,
    bool? allowsManualAccent,
    AppSkinAssetSlot? lightPreview,
    AppSkinAssetSlot? darkPreview,
  }) {
    return AppSkinMetadata(
      id: id ?? this.id,
      nameKey: nameKey ?? this.nameKey,
      descriptionKey: descriptionKey ?? this.descriptionKey,
      allowsManualAccent: allowsManualAccent ?? this.allowsManualAccent,
      lightPreview: lightPreview ?? this.lightPreview,
      darkPreview: darkPreview ?? this.darkPreview,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSkinMetadata &&
        other.id == id &&
        other.nameKey == nameKey &&
        other.descriptionKey == descriptionKey &&
        other.allowsManualAccent == allowsManualAccent &&
        other.lightPreview == lightPreview &&
        other.darkPreview == darkPreview;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      nameKey,
      descriptionKey,
      allowsManualAccent,
      lightPreview,
      darkPreview,
    );
  }
}

@immutable
class AppSkinColors {
  const AppSkinColors({
    required this.scaffoldBackground,
    required this.canvasBackground,
    required this.wallpaperFallback,
    required this.backgroundOverlay,
    required this.cardBackground,
    required this.inputBackground,
    required this.navigationBackground,
    required this.navigationIndicator,
    required this.bottomSheetBackground,
    required this.dialogBackground,
    required this.divider,
    required this.snackBarBackground,
    required this.fixedControlSurface,
    required this.scrollingContentSurface,
    required this.border,
    required this.selectionIndicator,
    required this.shadow,
  });

  final Color scaffoldBackground;
  final Color canvasBackground;
  final Color wallpaperFallback;
  final Color backgroundOverlay;
  final Color cardBackground;
  final Color inputBackground;
  final Color navigationBackground;
  final Color navigationIndicator;
  final Color bottomSheetBackground;
  final Color dialogBackground;
  final Color divider;
  final Color snackBarBackground;
  final Color fixedControlSurface;
  final Color scrollingContentSurface;
  final Color border;
  final Color selectionIndicator;
  final Color shadow;

  AppSkinColors copyWith({
    Color? scaffoldBackground,
    Color? canvasBackground,
    Color? wallpaperFallback,
    Color? backgroundOverlay,
    Color? cardBackground,
    Color? inputBackground,
    Color? navigationBackground,
    Color? navigationIndicator,
    Color? bottomSheetBackground,
    Color? dialogBackground,
    Color? divider,
    Color? snackBarBackground,
    Color? fixedControlSurface,
    Color? scrollingContentSurface,
    Color? border,
    Color? selectionIndicator,
    Color? shadow,
  }) {
    return AppSkinColors(
      scaffoldBackground: scaffoldBackground ?? this.scaffoldBackground,
      canvasBackground: canvasBackground ?? this.canvasBackground,
      wallpaperFallback: wallpaperFallback ?? this.wallpaperFallback,
      backgroundOverlay: backgroundOverlay ?? this.backgroundOverlay,
      cardBackground: cardBackground ?? this.cardBackground,
      inputBackground: inputBackground ?? this.inputBackground,
      navigationBackground: navigationBackground ?? this.navigationBackground,
      navigationIndicator: navigationIndicator ?? this.navigationIndicator,
      bottomSheetBackground:
          bottomSheetBackground ?? this.bottomSheetBackground,
      dialogBackground: dialogBackground ?? this.dialogBackground,
      divider: divider ?? this.divider,
      snackBarBackground: snackBarBackground ?? this.snackBarBackground,
      fixedControlSurface: fixedControlSurface ?? this.fixedControlSurface,
      scrollingContentSurface:
          scrollingContentSurface ?? this.scrollingContentSurface,
      border: border ?? this.border,
      selectionIndicator: selectionIndicator ?? this.selectionIndicator,
      shadow: shadow ?? this.shadow,
    );
  }

  static AppSkinColors lerp(AppSkinColors a, AppSkinColors b, double t) {
    return AppSkinColors(
      scaffoldBackground: Color.lerp(
        a.scaffoldBackground,
        b.scaffoldBackground,
        t,
      )!,
      canvasBackground: Color.lerp(a.canvasBackground, b.canvasBackground, t)!,
      wallpaperFallback: Color.lerp(
        a.wallpaperFallback,
        b.wallpaperFallback,
        t,
      )!,
      backgroundOverlay: Color.lerp(
        a.backgroundOverlay,
        b.backgroundOverlay,
        t,
      )!,
      cardBackground: Color.lerp(a.cardBackground, b.cardBackground, t)!,
      inputBackground: Color.lerp(a.inputBackground, b.inputBackground, t)!,
      navigationBackground: Color.lerp(
        a.navigationBackground,
        b.navigationBackground,
        t,
      )!,
      navigationIndicator: Color.lerp(
        a.navigationIndicator,
        b.navigationIndicator,
        t,
      )!,
      bottomSheetBackground: Color.lerp(
        a.bottomSheetBackground,
        b.bottomSheetBackground,
        t,
      )!,
      dialogBackground: Color.lerp(a.dialogBackground, b.dialogBackground, t)!,
      divider: Color.lerp(a.divider, b.divider, t)!,
      snackBarBackground: Color.lerp(
        a.snackBarBackground,
        b.snackBarBackground,
        t,
      )!,
      fixedControlSurface: Color.lerp(
        a.fixedControlSurface,
        b.fixedControlSurface,
        t,
      )!,
      scrollingContentSurface: Color.lerp(
        a.scrollingContentSurface,
        b.scrollingContentSurface,
        t,
      )!,
      border: Color.lerp(a.border, b.border, t)!,
      selectionIndicator: Color.lerp(
        a.selectionIndicator,
        b.selectionIndicator,
        t,
      )!,
      shadow: Color.lerp(a.shadow, b.shadow, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSkinColors &&
        other.scaffoldBackground == scaffoldBackground &&
        other.canvasBackground == canvasBackground &&
        other.wallpaperFallback == wallpaperFallback &&
        other.backgroundOverlay == backgroundOverlay &&
        other.cardBackground == cardBackground &&
        other.inputBackground == inputBackground &&
        other.navigationBackground == navigationBackground &&
        other.navigationIndicator == navigationIndicator &&
        other.bottomSheetBackground == bottomSheetBackground &&
        other.dialogBackground == dialogBackground &&
        other.divider == divider &&
        other.snackBarBackground == snackBarBackground &&
        other.fixedControlSurface == fixedControlSurface &&
        other.scrollingContentSurface == scrollingContentSurface &&
        other.border == border &&
        other.selectionIndicator == selectionIndicator &&
        other.shadow == shadow;
  }

  @override
  int get hashCode => Object.hashAll(<Object>[
    scaffoldBackground,
    canvasBackground,
    wallpaperFallback,
    backgroundOverlay,
    cardBackground,
    inputBackground,
    navigationBackground,
    navigationIndicator,
    bottomSheetBackground,
    dialogBackground,
    divider,
    snackBarBackground,
    fixedControlSurface,
    scrollingContentSurface,
    border,
    selectionIndicator,
    shadow,
  ]);
}

@immutable
class AppSkinSurfaces {
  const AppSkinSurfaces({
    required this.searchOpacity,
    required this.miniPlayerOpacity,
    required this.navigationOpacity,
    required this.scrollingContentOpacity,
    required this.bottomSheetOpacity,
  });

  final double searchOpacity;
  final double miniPlayerOpacity;
  final double navigationOpacity;
  final double scrollingContentOpacity;
  final double bottomSheetOpacity;

  bool get isValid =>
      _isOpacity(searchOpacity) &&
      _isOpacity(miniPlayerOpacity) &&
      _isOpacity(navigationOpacity) &&
      _isOpacity(scrollingContentOpacity) &&
      _isOpacity(bottomSheetOpacity);

  AppSkinSurfaces copyWith({
    double? searchOpacity,
    double? miniPlayerOpacity,
    double? navigationOpacity,
    double? scrollingContentOpacity,
    double? bottomSheetOpacity,
  }) {
    return AppSkinSurfaces(
      searchOpacity: searchOpacity ?? this.searchOpacity,
      miniPlayerOpacity: miniPlayerOpacity ?? this.miniPlayerOpacity,
      navigationOpacity: navigationOpacity ?? this.navigationOpacity,
      scrollingContentOpacity:
          scrollingContentOpacity ?? this.scrollingContentOpacity,
      bottomSheetOpacity: bottomSheetOpacity ?? this.bottomSheetOpacity,
    );
  }

  static AppSkinSurfaces lerp(AppSkinSurfaces a, AppSkinSurfaces b, double t) {
    return AppSkinSurfaces(
      searchOpacity: _lerpDouble(a.searchOpacity, b.searchOpacity, t),
      miniPlayerOpacity: _lerpDouble(
        a.miniPlayerOpacity,
        b.miniPlayerOpacity,
        t,
      ),
      navigationOpacity: _lerpDouble(
        a.navigationOpacity,
        b.navigationOpacity,
        t,
      ),
      scrollingContentOpacity: _lerpDouble(
        a.scrollingContentOpacity,
        b.scrollingContentOpacity,
        t,
      ),
      bottomSheetOpacity: _lerpDouble(
        a.bottomSheetOpacity,
        b.bottomSheetOpacity,
        t,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSkinSurfaces &&
        other.searchOpacity == searchOpacity &&
        other.miniPlayerOpacity == miniPlayerOpacity &&
        other.navigationOpacity == navigationOpacity &&
        other.scrollingContentOpacity == scrollingContentOpacity &&
        other.bottomSheetOpacity == bottomSheetOpacity;
  }

  @override
  int get hashCode => Object.hash(
    searchOpacity,
    miniPlayerOpacity,
    navigationOpacity,
    scrollingContentOpacity,
    bottomSheetOpacity,
  );
}

@immutable
class AppSkinGeometry {
  const AppSkinGeometry({
    required this.controlRadius,
    required this.cardRadius,
    required this.bottomSheetRadius,
    required this.blurSigma,
    required this.borderWidth,
    required this.shadowOpacity,
    required this.shadowBlurRadius,
    required this.shadowOffset,
    required this.showNavigationIndicatorPill,
  });

  final double controlRadius;
  final double cardRadius;
  final double bottomSheetRadius;
  final double blurSigma;
  final double borderWidth;
  final double shadowOpacity;
  final double shadowBlurRadius;
  final Offset shadowOffset;
  final bool showNavigationIndicatorPill;

  bool get isValid =>
      _isNonNegativeFinite(controlRadius) &&
      _isNonNegativeFinite(cardRadius) &&
      _isNonNegativeFinite(bottomSheetRadius) &&
      _isNonNegativeFinite(blurSigma) &&
      _isNonNegativeFinite(borderWidth) &&
      _isOpacity(shadowOpacity) &&
      _isNonNegativeFinite(shadowBlurRadius) &&
      shadowOffset.dx.isFinite &&
      shadowOffset.dy.isFinite;

  AppSkinGeometry copyWith({
    double? controlRadius,
    double? cardRadius,
    double? bottomSheetRadius,
    double? blurSigma,
    double? borderWidth,
    double? shadowOpacity,
    double? shadowBlurRadius,
    Offset? shadowOffset,
    bool? showNavigationIndicatorPill,
  }) {
    return AppSkinGeometry(
      controlRadius: controlRadius ?? this.controlRadius,
      cardRadius: cardRadius ?? this.cardRadius,
      bottomSheetRadius: bottomSheetRadius ?? this.bottomSheetRadius,
      blurSigma: blurSigma ?? this.blurSigma,
      borderWidth: borderWidth ?? this.borderWidth,
      shadowOpacity: shadowOpacity ?? this.shadowOpacity,
      shadowBlurRadius: shadowBlurRadius ?? this.shadowBlurRadius,
      shadowOffset: shadowOffset ?? this.shadowOffset,
      showNavigationIndicatorPill:
          showNavigationIndicatorPill ?? this.showNavigationIndicatorPill,
    );
  }

  static AppSkinGeometry lerp(AppSkinGeometry a, AppSkinGeometry b, double t) {
    return AppSkinGeometry(
      controlRadius: _lerpDouble(a.controlRadius, b.controlRadius, t),
      cardRadius: _lerpDouble(a.cardRadius, b.cardRadius, t),
      bottomSheetRadius: _lerpDouble(
        a.bottomSheetRadius,
        b.bottomSheetRadius,
        t,
      ),
      blurSigma: _lerpDouble(a.blurSigma, b.blurSigma, t),
      borderWidth: _lerpDouble(a.borderWidth, b.borderWidth, t),
      shadowOpacity: _lerpDouble(a.shadowOpacity, b.shadowOpacity, t),
      shadowBlurRadius: _lerpDouble(a.shadowBlurRadius, b.shadowBlurRadius, t),
      shadowOffset: Offset.lerp(a.shadowOffset, b.shadowOffset, t)!,
      showNavigationIndicatorPill: t < 0.5
          ? a.showNavigationIndicatorPill
          : b.showNavigationIndicatorPill,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSkinGeometry &&
        other.controlRadius == controlRadius &&
        other.cardRadius == cardRadius &&
        other.bottomSheetRadius == bottomSheetRadius &&
        other.blurSigma == blurSigma &&
        other.borderWidth == borderWidth &&
        other.shadowOpacity == shadowOpacity &&
        other.shadowBlurRadius == shadowBlurRadius &&
        other.shadowOffset == shadowOffset &&
        other.showNavigationIndicatorPill == showNavigationIndicatorPill;
  }

  @override
  int get hashCode => Object.hash(
    controlRadius,
    cardRadius,
    bottomSheetRadius,
    blurSigma,
    borderWidth,
    shadowOpacity,
    shadowBlurRadius,
    shadowOffset,
    showNavigationIndicatorPill,
  );
}

@immutable
class AppSkinBackgroundConfig {
  const AppSkinBackgroundConfig({
    required this.wallpaper,
    required this.animation,
    required this.fit,
    required this.alignment,
    required this.overlayColor,
  });

  final AppSkinAssetSlot wallpaper;
  final AppSkinAnimationDescriptor animation;
  final BoxFit fit;
  final Alignment alignment;
  final Color overlayColor;

  AppSkinBackgroundConfig copyWith({
    AppSkinAssetSlot? wallpaper,
    AppSkinAnimationDescriptor? animation,
    BoxFit? fit,
    Alignment? alignment,
    Color? overlayColor,
  }) {
    return AppSkinBackgroundConfig(
      wallpaper: wallpaper ?? this.wallpaper,
      animation: animation ?? this.animation,
      fit: fit ?? this.fit,
      alignment: alignment ?? this.alignment,
      overlayColor: overlayColor ?? this.overlayColor,
    );
  }

  AppSkinBackgroundConfig resolve(AppSkinBackgroundConfig fallback) {
    return copyWith(wallpaper: wallpaper.resolve(fallback.wallpaper));
  }

  static AppSkinBackgroundConfig lerp(
    AppSkinBackgroundConfig a,
    AppSkinBackgroundConfig b,
    double t,
  ) {
    return AppSkinBackgroundConfig(
      wallpaper: t < 0.5 ? a.wallpaper : b.wallpaper,
      animation: t < 0.5 ? a.animation : b.animation,
      fit: t < 0.5 ? a.fit : b.fit,
      alignment: Alignment.lerp(a.alignment, b.alignment, t)!,
      overlayColor: Color.lerp(a.overlayColor, b.overlayColor, t)!,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSkinBackgroundConfig &&
        other.wallpaper == wallpaper &&
        other.animation == animation &&
        other.fit == fit &&
        other.alignment == alignment &&
        other.overlayColor == overlayColor;
  }

  @override
  int get hashCode {
    return Object.hash(wallpaper, animation, fit, alignment, overlayColor);
  }
}

@immutable
class AppSkinBrightnessConfig {
  const AppSkinBrightnessConfig({
    required this.colorScheme,
    required this.colors,
    required this.surfaces,
    required this.geometry,
    required this.background,
  });

  final ColorScheme colorScheme;
  final AppSkinColors colors;
  final AppSkinSurfaces surfaces;
  final AppSkinGeometry geometry;
  final AppSkinBackgroundConfig background;

  AppSkinBrightnessConfig copyWith({
    ColorScheme? colorScheme,
    AppSkinColors? colors,
    AppSkinSurfaces? surfaces,
    AppSkinGeometry? geometry,
    AppSkinBackgroundConfig? background,
  }) {
    return AppSkinBrightnessConfig(
      colorScheme: colorScheme ?? this.colorScheme,
      colors: colors ?? this.colors,
      surfaces: surfaces ?? this.surfaces,
      geometry: geometry ?? this.geometry,
      background: background ?? this.background,
    );
  }

  AppSkinBrightnessConfig resolve(AppSkinBrightnessConfig fallback) {
    return copyWith(background: background.resolve(fallback.background));
  }

  static AppSkinBrightnessConfig lerp(
    AppSkinBrightnessConfig a,
    AppSkinBrightnessConfig b,
    double t,
  ) {
    return AppSkinBrightnessConfig(
      colorScheme: ColorScheme.lerp(a.colorScheme, b.colorScheme, t),
      colors: AppSkinColors.lerp(a.colors, b.colors, t),
      surfaces: AppSkinSurfaces.lerp(a.surfaces, b.surfaces, t),
      geometry: AppSkinGeometry.lerp(a.geometry, b.geometry, t),
      background: AppSkinBackgroundConfig.lerp(a.background, b.background, t),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSkinBrightnessConfig &&
        other.colorScheme == colorScheme &&
        other.colors == colors &&
        other.surfaces == surfaces &&
        other.geometry == geometry &&
        other.background == background;
  }

  @override
  int get hashCode {
    return Object.hash(colorScheme, colors, surfaces, geometry, background);
  }
}

enum AppSkinIconRole {
  navigationHome,
  navigationHomeSelected,
  navigationMy,
  navigationMySelected,
  homeRanking,
  homePlaylist,
  homeArtist,
  homeVideo,
  homeRadio,
  search,
  searchSubmit,
  searchHistoryClear,
  back,
  forward,
  more,
  close,
  scan,
  settings,
  miniPlayerPlay,
  miniPlayerPause,
  miniPlayerQueue,
  queueClear,
  songFavorite,
  songUnfavorite,
  songPlay,
  songPlayNext,
  songAddToQueue,
  songDownload,
  songShare,
  songDetails,
  songAddToPlaylist,
  songRemove,
  songDelete,
  songWatchVideo,
  songComments,
  songAlbum,
  songArtist,
  songCopyName,
  songCopyId,
  songSearchSameName,
  batchSelectAll,
  batchDeselectAll,
  batchPlay,
  batchAddToQueue,
  batchAddToPlaylist,
  batchDownload,
  myHistory,
  myLocalMusic,
  localLibraryScan,
  localLibraryClear,
  myDownloads,
  myCollection,
  myCollectionRefresh,
  myCollectionRemove,
  myPlaylist,
  myPlaylistCreate,
  settingsAppearance,
  settingsPlayback,
  settingsLyrics,
  settingsGeneral,
  settingsAccount,
  settingsThemeMode,
  settingsThemeAccent,
  settingsSkin,
  settingsSkinAnimation,
  settingsMonochrome,
  settingsPlayerBackground,
  settingsAudioQuality,
  settingsLyricHighlight,
  settingsLyricFont,
  settingsWordByWord,
  settingsDesktopLyric,
  settingsDesktopLyricLock,
  settingsLanguage,
  settingsAutoUpdate,
  settingsAbout,
  settingsAccountProfile,
  settingsLogin,
  settingsPassword,
  settingsDevices,
  settingsLogout,
}

@immutable
class AppSkinIconSpec {
  const AppSkinIconSpec({required this.asset, required this.fallbackIcon});

  final AppSkinAssetSlot asset;
  final IconData fallbackIcon;

  AppSkinIconSpec copyWith({AppSkinAssetSlot? asset, IconData? fallbackIcon}) {
    return AppSkinIconSpec(
      asset: asset ?? this.asset,
      fallbackIcon: fallbackIcon ?? this.fallbackIcon,
    );
  }

  AppSkinIconSpec resolve(AppSkinIconSpec fallback) {
    return AppSkinIconSpec(
      asset: asset.resolve(fallback.asset),
      fallbackIcon: fallbackIcon,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppSkinIconSpec &&
        other.asset == asset &&
        other.fallbackIcon == fallbackIcon;
  }

  @override
  int get hashCode => Object.hash(asset, fallbackIcon);
}

@immutable
class AppSkinIconCatalog {
  AppSkinIconCatalog(Map<AppSkinIconRole, AppSkinIconSpec> values)
    : values = Map<AppSkinIconRole, AppSkinIconSpec>.unmodifiable(values);

  final Map<AppSkinIconRole, AppSkinIconSpec> values;

  AppSkinIconSpec? operator [](AppSkinIconRole role) => values[role];

  AppSkinIconCatalog copyWith({
    Map<AppSkinIconRole, AppSkinIconSpec> overrides =
        const <AppSkinIconRole, AppSkinIconSpec>{},
  }) {
    return AppSkinIconCatalog(<AppSkinIconRole, AppSkinIconSpec>{
      ...values,
      ...overrides,
    });
  }

  AppSkinIconCatalog resolve(AppSkinIconCatalog fallback) {
    return AppSkinIconCatalog(<AppSkinIconRole, AppSkinIconSpec>{
      for (final role in AppSkinIconRole.values)
        if (values[role] != null && fallback.values[role] != null)
          role: values[role]!.resolve(fallback.values[role]!),
    });
  }

  @override
  bool operator ==(Object other) {
    return other is AppSkinIconCatalog && mapEquals(other.values, values);
  }

  @override
  int get hashCode => Object.hashAll(
    AppSkinIconRole.values.map((role) => Object.hash(role, values[role])),
  );
}

@immutable
class AppSkinPackage {
  const AppSkinPackage({
    required this.metadata,
    required this.light,
    required this.dark,
    required this.icons,
  });

  final AppSkinMetadata metadata;
  final AppSkinBrightnessConfig light;
  final AppSkinBrightnessConfig dark;
  final AppSkinIconCatalog icons;

  AppSkinPackage copyWith({
    AppSkinMetadata? metadata,
    AppSkinBrightnessConfig? light,
    AppSkinBrightnessConfig? dark,
    AppSkinIconCatalog? icons,
  }) {
    return AppSkinPackage(
      metadata: metadata ?? this.metadata,
      light: light ?? this.light,
      dark: dark ?? this.dark,
      icons: icons ?? this.icons,
    );
  }

  AppSkinBrightnessConfig configFor(Brightness brightness) {
    return brightness == Brightness.dark ? dark : light;
  }

  @override
  bool operator ==(Object other) {
    return other is AppSkinPackage &&
        other.metadata == metadata &&
        other.light == light &&
        other.dark == dark &&
        other.icons == icons;
  }

  @override
  int get hashCode => Object.hash(metadata, light, dark, icons);
}

bool _isOpacity(double value) => value >= 0 && value <= 1;

bool _isNonNegativeFinite(double value) => value.isFinite && value >= 0;

double _lerpDouble(double a, double b, double t) => a + (b - a) * t;
