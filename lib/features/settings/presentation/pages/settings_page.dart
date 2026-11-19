import '../widgets/lyric_storage_settings_tile.dart';
import 'dart:async';
import 'package:dio/dio.dart';

import 'package:flutter/foundation.dart';
import '../../../../shared/widgets/app_alert_dialog.dart';
import '../../../../shared/widgets/app_dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../shared/widgets/app_adaptive_controls.dart';
import '../../../../shared/widgets/app_list_tile.dart';
import '../../../../app/theme/app_ui_theme.dart';
import '../../../../shared/constants/layout_tokens.dart';
import '../../../../shared/widgets/app_content_width.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_ui_style.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/config/app_lyric_highlight_color.dart';
import '../../../../app/config/app_lyric_highlight_mode.dart';
import '../../../../app/config/app_online_audio_quality.dart';
import '../../../../app/config/app_theme_accent.dart';
import '../../../../app/config/app_theme_mode.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/app_message_service.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/skin/app_skin_icon.dart';
import '../../../../app/theme/skin/app_skin_models.dart';
import '../../../../app/theme/skin/app_skin_registry.dart';
import '../../../../app/theme/skin/app_skin_surface.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/app_search_field.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../domain/settings_catalog.dart';
import '../../../../core/network/network_error_message.dart';
import '../../../home/presentation/providers/home_page_providers.dart';
import '../../data/providers/account_settings_providers.dart';
import '../../domain/settings_models.dart';
import 'about_page.dart';
import 'settings_item_presentation_registry.dart';
import 'settings_navigation_registry.dart';
import '../widgets/settings_single_choice_sheet.dart';
import '../widgets/lyric_appearance_settings_sheet.dart';
import '../widgets/settings_tiles.dart';
import '../widgets/audio_cache_settings_tile.dart';
import '../../../../core/audio/cache/audio_cache_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({
    this.sectionId,
    this.highlightedItemId,
    this.initialDestinationId,
    super.key,
  });

  final String? sectionId;
  final String? highlightedItemId;
  final String? initialDestinationId;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, GlobalKey> _itemAnchorKeys = <String, GlobalKey>{};

  Timer? _highlightResetTimer;
  String? _highlightedItemId;
  late String? _selectedSectionId = widget.sectionId;
  late String? _selectedDestinationId = widget.initialDestinationId;

  bool get _usesSplitView {
    final size = MediaQuery.sizeOf(context);
    return size.width >= LayoutTokens.desktopBreakpoint && size.height >= 480;
  }

  bool _resettingRecommendationIdentity = false;
  @override
  void initState() {
    super.initState();
    _highlightedItemId = widget.highlightedItemId;
    _scheduleHighlightReset(_highlightedItemId);
  }

  @override
  void didUpdateWidget(covariant SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sectionId == widget.sectionId &&
        oldWidget.initialDestinationId == widget.initialDestinationId &&
        oldWidget.highlightedItemId == widget.highlightedItemId) {
      return;
    }
    _selectedSectionId = widget.sectionId;
    _selectedDestinationId = widget.initialDestinationId;
    _highlightedItemId = widget.highlightedItemId;
    _highlightResetTimer?.cancel();
    _scheduleHighlightReset(_highlightedItemId);
  }

  @override
  void dispose() {
    _highlightResetTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    return _buildScaffold(context, config);
  }

  Widget _buildScaffold(BuildContext context, AppConfigState config) {
    final splitView = _usesSplitView;
    final cupertinoSplit = splitView && AppUiTheme.usesCupertino(context);
    final destination = settingsNavigationDestinations[_selectedDestinationId];
    final sectionId =
        destination?.sectionId ??
        _selectedSectionId ??
        (splitView ? SettingsSectionIds.appearance : null);
    final title =
        destination?.title(config) ??
        (sectionId == null
            ? AppI18n.t(config, 'settings.title')
            : _sectionTitle(config, sectionId));
    final showDetail = sectionId != null || destination != null;
    final hasLocalDestination =
        destination != null &&
        destination.itemId != widget.initialDestinationId;
    final VoidCallback? onBack = hasLocalDestination
        ? _closeDestination
        : !splitView &&
              (_selectedSectionId != widget.sectionId ||
                  _selectedDestinationId != widget.initialDestinationId)
        ? _restoreInitialSelection
        : null;

    return PopScope<Object?>(
      canPop: onBack == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onBack?.call();
      },
      child: AppContentWidth(
        maxWidth: splitView ? double.infinity : LayoutTokens.maxContentWidth,
        child: Scaffold(
          key: ValueKey<String>('settings-page-${widget.sectionId ?? 'home'}'),
          appBar: cupertinoSplit
              ? null
              : AppNavigationBar(
                  leading: AppBackButton(onPressed: onBack),
                  title: Text(
                    splitView ? AppI18n.t(config, 'settings.title') : title,
                  ),
                ),
          body: !showDetail
              ? _buildHome(config)
              : SafeArea(
                  top: cupertinoSplit,
                  bottom: false,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (splitView) ...[
                        SizedBox(
                          width: cupertinoSplit
                              ? (MediaQuery.sizeOf(context).width * 0.24).clamp(
                                  256.0,
                                  316.0,
                                )
                              : 280,
                          child: _buildSidebar(
                            config,
                            sectionId,
                            cupertino: cupertinoSplit,
                            showBack: !hasLocalDestination,
                          ),
                        ),
                        if (cupertinoSplit)
                          const SizedBox(width: 8)
                        else
                          const VerticalDivider(width: 1),
                      ],
                      Expanded(
                        key: const ValueKey('settings-detail-pane'),
                        child: AppContentWidth(
                          maxWidth: cupertinoSplit ? 920 : double.infinity,
                          child: Padding(
                            padding: cupertinoSplit
                                ? const EdgeInsets.symmetric(horizontal: 16)
                                : EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (cupertinoSplit)
                                  _buildCupertinoDetailToolbar(
                                    title: title,
                                    onBack: hasLocalDestination
                                        ? _closeDestination
                                        : null,
                                  )
                                else if (splitView)
                                  Padding(
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                          24,
                                          16,
                                          24,
                                          0,
                                        ),
                                    child: Semantics(
                                      header: true,
                                      child: Text(
                                        title,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  key: const ValueKey('settings-detail-body'),
                                  child: AppContentWidth(
                                    maxWidth: splitView ? double.infinity : 720,
                                    child: KeyedSubtree(
                                      key: ValueKey(
                                        destination?.itemId ?? sectionId,
                                      ),
                                      child: destination != null
                                          ? SafeArea(
                                              top: false,
                                              child: destination.detailBuilder(
                                                hasLocalDestination
                                                    ? _closeDestination
                                                    : null,
                                              ),
                                            )
                                          : _buildSectionPanel(
                                              config: config,
                                              sectionId: sectionId!,
                                              showOverview: cupertinoSplit,
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCupertinoDetailToolbar({
    required String title,
    required VoidCallback? onBack,
  }) => Padding(
    key: const ValueKey('settings-detail-toolbar'),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Row(
        children: [
          if (onBack != null)
            AppBackButton(onPressed: onBack)
          else
            const SizedBox(width: 44),
          Expanded(
            child: Semantics(
              header: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    ),
  );
  Widget _buildSidebar(
    AppConfigState config,
    String? sectionId, {
    required bool cupertino,
    required bool showBack,
  }) {
    final entries = [
      for (final section in settingsSections)
        _SettingsSidebarEntry(
          title: _sectionTitle(config, section.id),
          iconRole: settingsSectionIconRole(section.id),
          selected: sectionId == section.id,
          cupertino: cupertino,
          onTap: () => _openSection(section.id),
        ),
    ];
    final list = ListView(
      key: const ValueKey('settings-sidebar'),
      primary: false,
      padding: cupertino
          ? const EdgeInsets.fromLTRB(12, 4, 12, 16)
          : const EdgeInsets.fromLTRB(12, 16, 12, 24),
      children: [
        _buildSearchField(config),
        const SizedBox(height: 16),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchController,
          builder: (context, value, child) {
            final query = value.text.trim();
            if (query.isNotEmpty) {
              return _buildSearchResults(config, query: query);
            }
            return child!;
          },
          child: cupertino
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: entries,
                )
              : AppListSection(children: entries),
        ),
      ],
    );
    if (!cupertino) return list;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        12,
        8,
        0,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      child: AppSkinSurface(
        key: const ValueKey('settings-sidebar-surface'),
        role: AppSkinSurfaceRole.scrollingContent,
        borderRadius: BorderRadius.circular(20),
        showDecoration: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 14, 4),
              child: Row(
                children: [
                  if (showBack)
                    const AppBackButton()
                  else
                    const SizedBox(width: 12, height: 44),
                  Expanded(
                    child: Text(
                      AppI18n.t(config, 'settings.title'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: list),
          ],
        ),
      ),
    );
  }

  Widget _buildHome(AppConfigState config) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= LayoutTokens.desktopBreakpoint
          ? 2
          : 1;
      final tileWidth =
          (constraints.maxWidth - 32 - (columns - 1) * 12) / columns;
      return ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _buildSearchField(config),
          const SizedBox(height: 16),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (context, value, child) {
              final query = value.text.trim();
              if (query.isNotEmpty) {
                return _buildSearchResults(config, query: query);
              }
              if (AppUiTheme.usesCupertino(context)) {
                return AppListSection(
                  children: [
                    for (final section in settingsSections)
                      AppListTile(
                        leading: AppSkinIcon(
                          role: settingsSectionIconRole(section.id),
                        ),
                        title: Text(_sectionTitle(config, section.id)),
                        showChevron: true,
                        onTap: () => _openSection(section.id),
                      ),
                  ],
                );
              }
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final section in settingsSections)
                    SizedBox(
                      width: tileWidth,
                      child: SettingsSectionTile(
                        icon: section.icon,
                        iconRole: settingsSectionIconRole(section.id),
                        title: _sectionTitle(config, section.id),
                        onTap: () => _openSection(section.id),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      );
    },
  );

  Widget _buildSearchField(AppConfigState config) => AppSearchField(
    key: const ValueKey<String>('settings-search-field'),
    controller: _searchController,
    placeholderPrimary: AppI18n.t(config, 'settings.search.hint'),
  );

  Widget _buildSearchResults(AppConfigState config, {required String query}) {
    final results = _searchResults(config, query);
    if (results.isEmpty) {
      return Center(child: Text(AppI18n.t(config, 'settings.search.empty')));
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = results[index];
        return SettingsSearchResultTile(
          title: _searchPath(config, item),
          subtitle: _itemSearchSubtitle(config, item),
          onTap: () =>
              _openSearchResult(sectionId: item.sectionId, itemId: item.id),
        );
      },
    );
  }

  Widget _buildSectionPanel({
    required AppConfigState config,
    required String sectionId,
    required bool showOverview,
  }) {
    final groups = _visibleGroupsForSection(sectionId, config);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureHighlightedItemVisible();
    });
    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        showOverview ? 8 : 16,
        16,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      children: <Widget>[
        if (showOverview) ...[
          _SettingsSectionOverview(
            iconRole: settingsSectionIconRole(sectionId),
            description: AppI18n.t(
              config,
              'settings.section.$sectionId.summary',
            ),
          ),
          const SizedBox(height: 22),
        ],
        for (var index = 0; index < groups.length; index++) ...<Widget>[
          _buildSettingsGroupCard(config, groups[index]),
          if (index < groups.length - 1) const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildSettingsGroupCard(
    AppConfigState config,
    SettingsGroupNode group,
  ) {
    final items = _visibleItemsForGroup(group.id, config);
    return AppListSection(
      header: Text(AppI18n.t(config, group.titleKey)),
      children: [for (final item in items) _buildItemTile(config, item)],
    );
  }

  Widget _buildItemTile(AppConfigState config, SettingsItemNode item) {
    if (item.id == SettingsItemIds.about) {
      return AboutPage(key: _anchorKeyForItem(item.id), inline: true);
    }
    final navigationDestination = settingsNavigationDestinations[item.id];
    late final currentSkin = AppSkinRegistry.withCustom(
      config.themeAccent,
      config.customSkinConfig,
    ).resolve(config.skinId);
    late final supportsSkinAnimation =
        currentSkin.light.background.animation.supportsAnimation ||
        currentSkin.dark.background.animation.supportsAnimation;
    final tile = switch (item.id) {
      SettingsItemIds.automaticLyricCache => const LyricStorageSettingsTile(
        manual: false,
      ),
      SettingsItemIds.manualLyrics => const LyricStorageSettingsTile(
        manual: true,
      ),
      SettingsItemIds.resetLyricOffsets =>
        const ResetLyricOffsetsSettingsTile(),
      SettingsItemIds.playbackAudioCache ||
      SettingsItemIds.cellularAudioCache ||
      SettingsItemIds.audioCacheLimit ||
      SettingsItemIds.clearAudioCache => AudioCacheSettingsTile(
        item: item,
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.uiStyle => SettingsSelectTile(
        icon: item.icon,
        iconRole: settingsItemIconRole(item.id),
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        trailingText: AppI18n.t(
          config,
          'settings.ui_style.${config.uiStylePreference.name}',
        ),
        onTap: _openUiStyleSheet,
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.themeMode => SettingsSelectTile(
        icon: item.icon,
        iconRole: settingsItemIconRole(item.id),
        title: AppI18n.t(config, item.titleKey),
        trailingText: _themeModeLabel(config.themeMode, config),
        onTap: _openThemeModeSheet,
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.themeAccent => SettingsSelectTile(
        icon: item.icon,
        iconRole: settingsItemIconRole(item.id),
        title: AppI18n.t(config, item.titleKey),
        trailingText: currentSkin.metadata.allowsManualAccent
            ? settingsThemeAccentLabel(config.themeAccent, config)
            : AppI18n.t(config, 'settings.theme_accent.follows_skin'),
        leadingTrailing: currentSkin.metadata.allowsManualAccent
            ? SettingsColorDot(color: _accentPreviewColor(config))
            : null,
        onTap: currentSkin.metadata.allowsManualAccent
            ? _openThemeAccentSheet
            : null,
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.skin => SettingsSelectTile(
        icon: item.icon,
        iconRole: settingsItemIconRole(item.id),
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        trailingText: AppI18n.t(config, currentSkin.metadata.nameKey),
        onTap: () => _openNavigationItem(item.id),
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.skinAnimation => SettingsSwitchTile(
        icon: item.icon,
        iconRole: settingsItemIconRole(item.id),
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        value: config.enableSkinAnimation,
        enabled: supportsSkinAnimation,
        onChanged: supportsSkinAnimation
            ? (value) => ref
                  .read(appConfigProvider.notifier)
                  .setEnableSkinAnimation(value)
            : null,
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.contentBackground => SettingsSwitchTile(
        icon: item.icon,
        iconRole: settingsItemIconRole(item.id),
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        value: config.showContentBackground,
        onChanged: (value) => ref
            .read(appConfigProvider.notifier)
            .setShowContentBackground(value),
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.monochrome => SettingsSwitchTile(
        icon: item.icon,
        iconRole: settingsItemIconRole(item.id),
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        value: config.isMonochrome,
        onChanged: (_) =>
            ref.read(appConfigProvider.notifier).toggleMonochrome(),
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.wifiOnlineAudioQuality => SettingsSelectTile(
        icon: item.icon,
        iconRole: settingsItemIconRole(item.id),
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        trailingText: settingsOnlineAudioQualityLabel(
          config.wifiOnlineAudioQualityPreference,
          config,
        ),
        onTap: () => _openOnlineAudioQualitySheet(
          titleKey: 'settings.audio_quality.wifi',
          currentValue: config.wifiOnlineAudioQualityPreference,
          onSelected: ref
              .read(appConfigProvider.notifier)
              .setWifiOnlineAudioQualityPreference,
        ),
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.cellularOnlineAudioQuality => SettingsSelectTile(
        icon: item.icon,
        iconRole: settingsItemIconRole(item.id),
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        trailingText: settingsOnlineAudioQualityLabel(
          config.cellularOnlineAudioQualityPreference,
          config,
        ),
        onTap: () => _openOnlineAudioQualitySheet(
          titleKey: 'settings.audio_quality.cellular',
          currentValue: config.cellularOnlineAudioQualityPreference,
          onSelected: ref
              .read(appConfigProvider.notifier)
              .setCellularOnlineAudioQualityPreference,
        ),
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.lyricHighlightColor => SettingsSelectTile(
        icon: item.icon,
        iconRole: settingsItemIconRole(item.id),
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        trailingText: _lyricHighlightSummary(config),
        leadingTrailing: SettingsColorDot(
          color: lyricSettingsHighlightPreviewColor(config),
        ),
        onTap: _openLyricHighlightColorSheet,
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.lyricFontPreset => SettingsSelectTile(
        icon: item.icon,
        iconRole: settingsItemIconRole(item.id),
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        trailingText: settingsLyricFontPresetLabel(
          config.lyricFontPreset,
          config,
        ),
        onTap: _openLyricFontPresetSheet,
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.wordByWordLyric => SettingsSwitchTile(
        icon: item.icon,
        iconRole: settingsItemIconRole(item.id),
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        value: config.enableWordByWordLyric,
        onChanged: (value) => ref
            .read(appConfigProvider.notifier)
            .setEnableWordByWordLyric(value),
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.desktopLyric => SettingsSwitchTile(
        icon: item.icon,
        iconRole: settingsItemIconRole(item.id),
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        value: config.enableDesktopLyric,
        onChanged: (value) =>
            ref.read(appConfigProvider.notifier).setEnableDesktopLyric(value),
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.desktopLyricLock => SettingsSwitchTile(
        icon: item.icon,
        iconRole: settingsItemIconRole(item.id),
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        value: config.enableDesktopLyricLock,
        enabled: config.enableDesktopLyric,
        onChanged: config.enableDesktopLyric
            ? (value) => ref
                  .read(appConfigProvider.notifier)
                  .setEnableDesktopLyricLock(value)
            : null,
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.language => SettingsSelectTile(
        icon: item.icon,
        iconRole: settingsItemIconRole(item.id),
        title: AppI18n.t(config, item.titleKey),
        trailingText: _languageLabel(config.localeCode, config),
        onTap: _openLanguageSheet,
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.autoCheckUpdates => SettingsSwitchTile(
        icon: item.icon,
        iconRole: settingsItemIconRole(item.id),
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        value: config.autoCheckUpdates,
        onChanged: (value) =>
            ref.read(appConfigProvider.notifier).setAutoCheckUpdates(value),
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.accountLogin => SettingsNavigationTile(
        icon: item.icon,
        iconRole: settingsItemIconRole(item.id),
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        onTap: _openLogin,
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.resetRecommendationIdentity => SettingsActionTile(
        icon: item.icon,
        iconRole: settingsItemIconRole(item.id),
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        onTap: _resettingRecommendationIdentity
            ? null
            : _confirmResetRecommendationIdentity,
        busy: _resettingRecommendationIdentity,
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.accountLogout => SettingsActionTile(
        icon: item.icon,
        iconRole: settingsItemIconRole(item.id),
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        onTap: _confirmLogout,
        destructive: true,
        highlighted: _highlightedItemId == item.id,
      ),
      _
          when item.kind == SettingsItemKind.navigation &&
              navigationDestination != null =>
        SettingsNavigationTile(
          icon: item.icon,
          iconRole: settingsItemIconRole(item.id),
          title: AppI18n.t(config, item.titleKey),
          subtitle: settingsItemSubtitle(item.id, config),
          onTap: () => _openNavigationItem(item.id),
          highlighted: _highlightedItemId == item.id,
        ),
      _ => const SizedBox.shrink(),
    };
    return KeyedSubtree(
      key: ValueKey<String>('settings-item-${item.id}'),
      child: Container(key: _anchorKeyForItem(item.id), child: tile),
    );
  }

  List<SettingsItemNode> _searchResults(AppConfigState config, String query) {
    final normalizedQuery = query.toLowerCase();
    return _visibleSettingsItems(config)
        .where((item) {
          final title = AppI18n.t(config, item.titleKey).toLowerCase();
          final section = _sectionTitle(config, item.sectionId).toLowerCase();
          final subtitle = _itemSearchSubtitle(config, item).toLowerCase();
          if (title.contains(normalizedQuery) ||
              section.contains(normalizedQuery) ||
              subtitle.contains(normalizedQuery)) {
            return true;
          }
          return item.keywords.any(
            (keyword) => keyword.toLowerCase().contains(normalizedQuery),
          );
        })
        .toList(growable: false);
  }

  List<SettingsGroupNode> _visibleGroupsForSection(
    String sectionId,
    AppConfigState config,
  ) {
    return groupsForSection(sectionId)
        .where((group) => _isGroupVisible(group.id, config))
        .toList(growable: false);
  }

  List<SettingsItemNode> _visibleItemsForGroup(
    String groupId,
    AppConfigState config,
  ) {
    return itemsForGroup(
      groupId,
    ).where((item) => _isItemVisible(item.id, config)).toList(growable: false);
  }

  List<SettingsItemNode> _visibleSettingsItems(AppConfigState config) {
    return settingsItems
        .where((item) => _isItemVisible(item.id, config))
        .toList(growable: false);
  }

  bool _isGroupVisible(String groupId, AppConfigState config) {
    if (groupId == SettingsGroupIds.lyricsDesktop) {
      return defaultTargetPlatform == TargetPlatform.android;
    }
    return _visibleItemsForGroup(groupId, config).isNotEmpty;
  }

  bool _isItemVisible(String itemId, AppConfigState config) {
    if (SettingsItemIds.audioCacheItems.contains(itemId)) {
      return ref.read(audioCacheRuntimeProvider)?.capabilityEnabled ?? false;
    }
    if (itemId == SettingsItemIds.desktopLyric ||
        itemId == SettingsItemIds.desktopLyricLock) {
      return defaultTargetPlatform == TargetPlatform.android;
    }
    if (itemId == SettingsItemIds.githubDownloadAcceleration) {
      return defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS;
    }
    final loggedIn = config.authToken?.trim().isNotEmpty ?? false;
    if (itemId == SettingsItemIds.accountLogin) {
      return !loggedIn;
    }
    if (itemId == SettingsItemIds.accountProfile ||
        itemId == SettingsItemIds.accountPassword ||
        itemId == SettingsItemIds.deviceManagement ||
        itemId == SettingsItemIds.resetRecommendationIdentity ||
        itemId == SettingsItemIds.accountLogout) {
      return loggedIn;
    }
    return true;
  }

  String _searchPath(AppConfigState config, SettingsItemNode item) {
    return '${_sectionTitle(config, item.sectionId)} / ${AppI18n.t(config, item.titleKey)}';
  }

  String _itemSearchSubtitle(AppConfigState config, SettingsItemNode item) {
    return settingsItemSubtitle(item.id, config);
  }

  void _openSection(String sectionId, {String? highlightItemId}) {
    _clearSearch();
    if (_usesSplitView) {
      _highlightResetTimer?.cancel();
      setState(() {
        _selectedSectionId = sectionId;
        _selectedDestinationId = null;
        _highlightedItemId = highlightItemId;
      });
      _scheduleHighlightReset(highlightItemId);
      return;
    }
    context.push(
      AppRoutes.settingsSectionLocation(
        sectionId,
        highlightedItemId: highlightItemId,
      ),
    );
  }

  void _openSearchResult({required String sectionId, required String itemId}) {
    if (settingsNavigationDestinations.containsKey(itemId)) {
      _clearSearch();
      _openNavigationItem(itemId);
      return;
    }
    _openSection(sectionId, highlightItemId: itemId);
  }

  void _restoreInitialSelection() {
    _highlightResetTimer?.cancel();
    setState(() {
      _selectedSectionId = widget.sectionId;
      _selectedDestinationId = widget.initialDestinationId;
      _highlightedItemId = null;
    });
  }

  void _clearSearch() {
    _searchController.clear();
  }

  void _scheduleHighlightReset(String? itemId) {
    if (itemId == null) {
      return;
    }
    _highlightResetTimer?.cancel();
    _highlightResetTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || _highlightedItemId != itemId) {
        return;
      }
      setState(() {
        _highlightedItemId = null;
      });
    });
  }

  void _ensureHighlightedItemVisible() {
    final itemId = _highlightedItemId;
    if (itemId == null) {
      return;
    }
    final context = _anchorKeyForItem(itemId).currentContext;
    if (context == null) {
      return;
    }
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
    );
  }

  GlobalKey _anchorKeyForItem(String itemId) {
    return _itemAnchorKeys.putIfAbsent(itemId, GlobalKey.new);
  }

  void _closeDestination() {
    setState(() => _selectedDestinationId = null);
  }

  void _openNavigationItem(String itemId) {
    final destination = settingsNavigationDestinations[itemId];
    if (destination == null) {
      return;
    }
    if (_usesSplitView) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _selectedSectionId = destination.sectionId;
        _selectedDestinationId = itemId;
      });
      return;
    }
    context.push(destination.mobileRoute);
  }

  void _openLogin() {
    context.push(
      Uri(
        path: AppRoutes.login,
        queryParameters: const <String, String>{'redirect': AppRoutes.settings},
      ).toString(),
    );
  }

  Future<void> _confirmResetRecommendationIdentity() async {
    if (_resettingRecommendationIdentity) {
      return;
    }
    final config = ref.read(appConfigProvider);
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: Text(
          AppI18n.t(config, 'settings.recommendation_identity.confirm.title'),
        ),
        content: Text(
          AppI18n.t(config, 'settings.recommendation_identity.confirm.message'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppI18n.t(config, 'common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              AppI18n.t(config, 'settings.recommendation_identity.confirm'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _resettingRecommendationIdentity = true);
    try {
      await ref
          .read(accountSettingsApiClientProvider)
          .resetRecommendationIdentity();
      await ref
          .read(homePageControllerProvider.notifier)
          .refreshRecommendations();
      if (!mounted) {
        return;
      }
      AppMessageService.showSuccess(
        AppI18n.t(config, 'settings.recommendation_identity.success'),
      );
    } on DioException catch (error) {
      if (!mounted) {
        return;
      }
      final message = error.response == null
          ? AppI18n.t(config, 'settings.recommendation_identity.uncertain')
          : NetworkErrorMessage.resolve(error, localeCode: config.localeCode) ??
                AppI18n.t(config, 'settings.recommendation_identity.failed');
      AppMessageService.showError(message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppMessageService.showError(
        NetworkErrorMessage.resolve(error, localeCode: config.localeCode) ??
            AppI18n.t(config, 'settings.recommendation_identity.failed'),
      );
    } finally {
      if (mounted) {
        setState(() => _resettingRecommendationIdentity = false);
      }
    }
  }

  Future<void> _confirmLogout() async {
    final config = ref.read(appConfigProvider);
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AppAlertDialog(
        title: Text(AppI18n.t(config, 'settings.logout.confirm.title')),
        content: Text(AppI18n.t(config, 'settings.logout.confirm.message')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(AppI18n.t(config, 'common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppI18n.t(config, 'settings.logout')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await ref.read(onlineControllerProvider.notifier).logout();
    if (!mounted) {
      return;
    }
    AppMessageService.showSuccess(AppI18n.t(config, 'settings.logout.done'));
    context.go(AppRoutes.home);
  }

  Future<void> _openUiStyleSheet() {
    final config = ref.read(appConfigProvider);
    return showSettingsSingleChoiceSheet<AppUiStylePreference>(
      context: context,
      title: AppI18n.t(config, 'settings.ui_style'),
      currentValue: config.uiStylePreference,
      cupertinoFooter: AppI18n.t(config, 'settings.ui_style.selection_hint'),
      options: [
        for (final preference in AppUiStylePreference.values)
          SettingsChoiceOption(
            value: preference,
            title: AppI18n.t(config, 'settings.ui_style.${preference.name}'),
            subtitle: AppUiTheme.usesCupertino(context)
                ? null
                : AppI18n.t(
                    config,
                    'settings.ui_style.${preference.name}.desc',
                  ),
          ),
      ],
      onSelected: (preference) =>
          ref.read(appConfigProvider.notifier).setUiStylePreference(preference),
    );
  }

  Future<void> _openThemeModeSheet() {
    final config = ref.read(appConfigProvider);
    return showSettingsSingleChoiceSheet<AppThemeMode>(
      context: context,
      title: AppI18n.t(config, 'settings.theme'),
      currentValue: config.themeMode,
      useCupertinoActionSheet: true,
      options: AppThemeMode.values
          .map(
            (item) => SettingsChoiceOption<AppThemeMode>(
              value: item,
              title: _themeModeLabel(item, config),
            ),
          )
          .toList(growable: false),
      onSelected: (value) {
        ref.read(appConfigProvider.notifier).setThemeMode(value);
      },
    );
  }

  Future<void> _openThemeAccentSheet() {
    final config = ref.read(appConfigProvider);
    return showSettingsSingleChoiceSheet<AppThemeAccent>(
      context: context,
      title: AppI18n.t(config, 'settings.theme_accent'),
      currentValue: config.themeAccent,
      options: AppThemeAccent.values
          .map(
            (item) => SettingsChoiceOption<AppThemeAccent>(
              value: item,
              title: settingsThemeAccentLabel(item, config),
              leading: SettingsColorDot(color: item.lightSeed),
            ),
          )
          .toList(growable: false),
      onSelected: (value) {
        ref.read(appConfigProvider.notifier).setThemeAccent(value);
      },
    );
  }

  Future<void> _openLanguageSheet() {
    final config = ref.read(appConfigProvider);
    return showSettingsSingleChoiceSheet<String>(
      context: context,
      title: AppI18n.t(config, 'settings.language'),
      currentValue: config.localeCode,
      useCupertinoActionSheet: true,
      options: <SettingsChoiceOption<String>>[
        SettingsChoiceOption<String>(
          value: 'system',
          title: AppI18n.t(config, 'settings.lang.system'),
        ),
        SettingsChoiceOption<String>(
          value: 'zh',
          title: AppI18n.t(config, 'settings.lang.zh_cn'),
        ),
        SettingsChoiceOption<String>(
          value: 'en',
          title: AppI18n.t(config, 'settings.lang.en'),
        ),
      ],
      onSelected: (value) {
        ref.read(appConfigProvider.notifier).setLocaleCode(value);
      },
    );
  }

  Future<void> _openOnlineAudioQualitySheet({
    required String titleKey,
    required AppOnlineAudioQuality currentValue,
    required ValueChanged<AppOnlineAudioQuality> onSelected,
  }) {
    final config = ref.read(appConfigProvider);
    return showSettingsSingleChoiceSheet<AppOnlineAudioQuality>(
      context: context,
      title: AppI18n.t(config, titleKey),
      currentValue: currentValue,
      options: AppOnlineAudioQuality.values
          .map(
            (item) => SettingsChoiceOption<AppOnlineAudioQuality>(
              value: item,
              title: settingsOnlineAudioQualityLabel(item, config),
              subtitle: item.isAuto && AppUiTheme.usesCupertino(context)
                  ? AppI18n.t(config, 'settings.audio_quality.auto_hint')
                  : settingsOnlineAudioQualityDescription(item, config),
              leading: AppUiTheme.usesCupertino(context)
                  ? null
                  : const Icon(Icons.graphic_eq_rounded),
            ),
          )
          .toList(growable: false),
      onSelected: onSelected,
    );
  }

  Future<void> _openLyricHighlightColorSheet() {
    final config = ref.read(appConfigProvider);
    final options = <SettingsChoiceOption<String>>[
      SettingsChoiceOption<String>(
        value: AppLyricHighlightMode.auto.value,
        title: AppI18n.t(config, 'settings.choice.auto'),
        leading: const Icon(Icons.auto_awesome_rounded),
      ),
      ...AppLyricHighlightColor.values.map(
        (item) => SettingsChoiceOption<String>(
          value: 'preset:${item.value}',
          title: settingsLyricHighlightColorLabel(item, config),
          leading: SettingsColorDot(color: item.color),
        ),
      ),
    ];
    return showSettingsSingleChoiceSheet<String>(
      context: context,
      title: AppI18n.t(config, 'settings.lyric_highlight_color'),
      currentValue: _lyricHighlightChoiceValue(config),
      options: options,
      onSelected: (value) {
        if (value == AppLyricHighlightMode.auto.value) {
          ref
              .read(appConfigProvider.notifier)
              .setLyricHighlightMode(AppLyricHighlightMode.auto);
          return;
        }
        final presetValue = value.replaceFirst('preset:', '');
        ref
            .read(appConfigProvider.notifier)
            .setLyricHighlightPreset(
              AppLyricHighlightColor.fromValue(presetValue),
            );
      },
    );
  }

  Future<void> _openLyricFontPresetSheet() {
    final config = ref.read(appConfigProvider);
    return showLyricFontPresetSettingsSheet(
      context: context,
      config: config,
      onSelected: ref.read(appConfigProvider.notifier).setLyricFontPreset,
    );
  }

  String _themeModeLabel(AppThemeMode mode, AppConfigState config) {
    return switch (mode) {
      AppThemeMode.system => AppI18n.t(config, 'my.theme.system'),
      AppThemeMode.light => AppI18n.t(config, 'my.theme.light'),
      AppThemeMode.dark => AppI18n.t(config, 'my.theme.dark'),
    };
  }

  String _languageLabel(String localeCode, AppConfigState config) {
    return switch (localeCode) {
      'system' => AppI18n.t(config, 'settings.lang.system'),
      'en' => AppI18n.t(config, 'settings.lang.en'),
      _ => AppI18n.t(config, 'settings.lang.zh_cn'),
    };
  }

  String _sectionTitle(AppConfigState config, String sectionId) {
    final section = sectionById(sectionId);
    return AppI18n.t(config, section.titleKey);
  }

  Color _accentPreviewColor(AppConfigState config) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark
        ? config.themeAccent.darkSeed
        : config.themeAccent.lightSeed;
  }

  String _lyricHighlightSummary(AppConfigState config) {
    return switch (config.lyricHighlightMode) {
      AppLyricHighlightMode.auto => AppI18n.t(config, 'settings.choice.auto'),
      AppLyricHighlightMode.custom => AppI18n.t(
        config,
        'settings.choice.custom',
      ),
      AppLyricHighlightMode.preset => settingsLyricHighlightColorLabel(
        config.lyricHighlightPreset,
        config,
      ),
    };
  }

  String _lyricHighlightChoiceValue(AppConfigState config) {
    return switch (config.lyricHighlightMode) {
      AppLyricHighlightMode.auto => AppLyricHighlightMode.auto.value,
      AppLyricHighlightMode.custom => AppLyricHighlightMode.custom.value,
      AppLyricHighlightMode.preset =>
        'preset:${config.lyricHighlightPreset.value}',
    };
  }
}

class _SettingsSectionOverview extends StatelessWidget {
  const _SettingsSectionOverview({
    required this.iconRole,
    required this.description,
  });

  final AppSkinIconRole iconRole;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return AppSkinSurface(
      key: const ValueKey('settings-section-overview'),
      role: AppSkinSurfaceRole.scrollingContent,
      showDecoration: false,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: AppSkinIcon(role: iconRole, size: 24, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSidebarEntry extends StatelessWidget {
  const _SettingsSidebarEntry({
    required this.title,
    required this.iconRole,
    required this.selected,
    required this.cupertino,
    required this.onTap,
  });

  final String title;
  final AppSkinIconRole iconRole;
  final bool selected;
  final bool cupertino;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = colors.primary;
    final tile = AppListTile(
      title: Text(
        title,
        style: cupertino && selected
            ? TextStyle(color: accent, fontWeight: FontWeight.w600)
            : null,
      ),
      leading: cupertino
          ? Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: AppSkinIcon(role: iconRole, size: 17, color: accent),
            )
          : AppSkinIcon(role: iconRole),
      contentPadding: cupertino
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
          : null,
      trailing: !cupertino && selected
          ? const ExcludeSemantics(child: Icon(Icons.check))
          : null,
      onTap: onTap,
    );
    return Semantics(
      selected: selected,
      child: cupertino
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ColoredBox(
                color: selected
                    ? colors.onSurface.withValues(alpha: 0.09)
                    : Colors.transparent,
                child: tile,
              ),
            )
          : tile,
    );
  }
}
