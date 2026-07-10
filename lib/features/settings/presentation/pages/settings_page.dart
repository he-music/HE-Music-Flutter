import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_config_state.dart';
import '../../../../app/config/app_lyric_font_preset.dart';
import '../../../../app/config/app_lyric_highlight_color.dart';
import '../../../../app/config/app_lyric_highlight_mode.dart';
import '../../../../app/config/app_online_audio_quality.dart';
import '../../../../app/config/app_player_background_style.dart';
import '../../../../app/config/app_theme_accent.dart';
import '../../../../app/config/app_theme_mode.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/app_message_service.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../domain/settings_catalog.dart';
import '../../domain/settings_models.dart';
import 'settings_item_presentation_registry.dart';
import 'settings_navigation_registry.dart';
import '../widgets/settings_single_choice_sheet.dart';
import '../widgets/settings_tiles.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, GlobalKey> _itemAnchorKeys = <String, GlobalKey>{};

  Timer? _highlightResetTimer;
  String _searchQuery = '';
  String? _mobileSectionId;
  String? _highlightedItemId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _highlightResetTimer?.cancel();
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    return _buildMobileScaffold(context, config);
  }

  void _handleSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim();
    });
  }

  Widget _buildMobileScaffold(BuildContext context, AppConfigState config) {
    final showingSection = _mobileSectionId != null;
    final title = showingSection
        ? _sectionTitle(config, _mobileSectionId!)
        : AppI18n.t(config, 'settings.title');
    return PopScope(
      canPop: !showingSection,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !showingSection) return;
        _closeMobileSection();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: AppBackButton(
            onPressed: showingSection ? _closeMobileSection : null,
          ),
          title: Text(title),
        ),
        body: showingSection
            ? _buildSectionPanel(config: config, sectionId: _mobileSectionId!)
            : _buildMobileHome(config),
      ),
    );
  }

  Widget _buildMobileHome(AppConfigState config) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        _buildSearchField(config),
        const SizedBox(height: 16),
        if (_searchQuery.isNotEmpty)
          _buildSearchResults(config, isDesktop: false)
        else ...<Widget>[
          for (final section in settingsSections) ...<Widget>[
            SettingsSectionTile(
              icon: section.icon,
              title: _sectionTitle(config, section.id),
              onTap: () => _openSection(section.id),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }

  Widget _buildSearchField(AppConfigState config) {
    return TextField(
      key: const ValueKey<String>('settings-search-field'),
      controller: _searchController,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: AppI18n.t(config, 'settings.search.hint'),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      textInputAction: TextInputAction.search,
    );
  }

  Widget _buildSearchResults(AppConfigState config, {required bool isDesktop}) {
    final results = _searchResults(config);
    if (results.isEmpty) {
      return Center(child: Text(AppI18n.t(config, 'settings.search.empty')));
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: !isDesktop,
      itemCount: results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = results[index];
        return SettingsSearchResultTile(
          title: _searchPath(config, item),
          subtitle: _itemSearchSubtitle(config, item),
          onTap: () => _openSearchResult(
            sectionId: item.sectionId,
            itemId: item.id,
            isDesktop: isDesktop,
          ),
        );
      },
    );
  }

  Widget _buildSectionPanel({
    required AppConfigState config,
    required String sectionId,
    bool showSectionHeader = true,
  }) {
    final groups = _visibleGroupsForSection(sectionId, config);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureHighlightedItemVisible();
    });
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: <Widget>[
        if (showSectionHeader) ...<Widget>[
          Text(
            _sectionTitle(config, sectionId),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppI18n.t(config, group.titleKey),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              for (var index = 0; index < items.length; index++) ...<Widget>[
                _buildItemTile(config, items[index]),
                if (index < items.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemTile(AppConfigState config, SettingsItemNode item) {
    final navigationDestination = settingsNavigationDestinations[item.id];
    final tile = switch (item.id) {
      SettingsItemIds.themeMode => SettingsSelectTile(
        icon: item.icon,
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        trailingText: _themeModeLabel(config.themeMode, config),
        onTap: _openThemeModeSheet,
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.themeAccent => SettingsSelectTile(
        icon: item.icon,
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        trailingText: config.themeAccent.label,
        leadingTrailing: SettingsColorDot(color: _accentPreviewColor(config)),
        onTap: _openThemeAccentSheet,
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.monochrome => SettingsSwitchTile(
        icon: item.icon,
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        value: config.isMonochrome,
        onChanged: (_) =>
            ref.read(appConfigProvider.notifier).toggleMonochrome(),
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.playerBackgroundStyle => SettingsSelectTile(
        icon: item.icon,
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        trailingText: _playerBackgroundStyleLabel(
          config.playerBackgroundStyle,
          config,
        ),
        onTap: _openPlayerBackgroundStyleSheet,
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.onlineAudioQuality => SettingsSelectTile(
        icon: item.icon,
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        trailingText: config.onlineAudioQualityPreference.label,
        onTap: _openOnlineAudioQualitySheet,
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.lyricHighlightColor => SettingsSelectTile(
        icon: item.icon,
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        trailingText: _lyricHighlightSummary(config),
        leadingTrailing: SettingsColorDot(
          color: _lyricHighlightPreviewColor(config),
        ),
        onTap: _openLyricHighlightColorSheet,
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.lyricFontPreset => SettingsSelectTile(
        icon: item.icon,
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        trailingText: config.lyricFontPreset.label,
        onTap: _openLyricFontPresetSheet,
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.wordByWordLyric => SettingsSwitchTile(
        icon: item.icon,
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
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        value: config.enableDesktopLyric,
        onChanged: (value) =>
            ref.read(appConfigProvider.notifier).setEnableDesktopLyric(value),
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.desktopLyricLock => SettingsSwitchTile(
        icon: item.icon,
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
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        trailingText: _languageLabel(config.localeCode, config),
        onTap: _openLanguageSheet,
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.autoCheckUpdates => SettingsSwitchTile(
        icon: item.icon,
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        value: config.autoCheckUpdates,
        onChanged: (value) =>
            ref.read(appConfigProvider.notifier).setAutoCheckUpdates(value),
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.accountLogin => SettingsNavigationTile(
        icon: item.icon,
        title: AppI18n.t(config, item.titleKey),
        subtitle: settingsItemSubtitle(item.id, config),
        onTap: _openLogin,
        highlighted: _highlightedItemId == item.id,
      ),
      SettingsItemIds.accountLogout => SettingsActionTile(
        icon: item.icon,
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

  List<SettingsItemNode> _searchResults(AppConfigState config) {
    final query = _searchQuery.toLowerCase();
    return _visibleSettingsItems(config)
        .where((item) {
          final title = AppI18n.t(config, item.titleKey).toLowerCase();
          final section = _sectionTitle(config, item.sectionId).toLowerCase();
          final subtitle = _itemSearchSubtitle(config, item).toLowerCase();
          if (title.contains(query) ||
              section.contains(query) ||
              subtitle.contains(query)) {
            return true;
          }
          return item.keywords.any(
            (keyword) => keyword.toLowerCase().contains(query),
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
    if (itemId == SettingsItemIds.desktopLyric ||
        itemId == SettingsItemIds.desktopLyricLock) {
      return defaultTargetPlatform == TargetPlatform.android;
    }
    final loggedIn = config.authToken?.trim().isNotEmpty ?? false;
    if (itemId == SettingsItemIds.accountLogin) {
      return !loggedIn;
    }
    if (itemId == SettingsItemIds.accountProfile ||
        itemId == SettingsItemIds.accountPassword ||
        itemId == SettingsItemIds.deviceManagement ||
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
    setState(() {
      _mobileSectionId = sectionId;
      _highlightedItemId = highlightItemId;
    });
    _clearSearch();
    _scheduleHighlightReset(highlightItemId);
  }

  void _closeMobileSection() {
    setState(() {
      _mobileSectionId = null;
      _highlightedItemId = null;
    });
  }

  void _openSearchResult({
    required String sectionId,
    required String itemId,
    required bool isDesktop,
  }) {
    if (settingsNavigationDestinations.containsKey(itemId)) {
      _clearSearch();
      _openNavigationItem(itemId);
      return;
    }
    setState(() {
      _mobileSectionId = sectionId;
      _highlightedItemId = itemId;
    });
    _clearSearch();
    _scheduleHighlightReset(itemId);
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

  void _openNavigationItem(String itemId) {
    final destination = settingsNavigationDestinations[itemId];
    if (destination == null) {
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

  Future<void> _confirmLogout() async {
    final config = ref.read(appConfigProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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

  Future<void> _openThemeModeSheet() {
    final config = ref.read(appConfigProvider);
    return showSettingsSingleChoiceSheet<AppThemeMode>(
      context: context,
      title: AppI18n.t(config, 'settings.theme'),
      currentValue: config.themeMode,
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
              title: item.label,
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

  Future<void> _openOnlineAudioQualitySheet() {
    final config = ref.read(appConfigProvider);
    return showSettingsSingleChoiceSheet<AppOnlineAudioQuality>(
      context: context,
      title: AppI18n.t(config, 'settings.audio_quality'),
      currentValue: config.onlineAudioQualityPreference,
      options: AppOnlineAudioQuality.values
          .map(
            (item) => SettingsChoiceOption<AppOnlineAudioQuality>(
              value: item,
              title: item.label,
              subtitle: item.isAuto
                  ? AppOnlineAudioQuality.autoDescription(
                      lastSelectedQualityName:
                          config.lastSelectedOnlineAudioQualityName,
                    )
                  : item.tip,
              leading: const Icon(Icons.graphic_eq_rounded),
            ),
          )
          .toList(growable: false),
      onSelected: (value) {
        ref
            .read(appConfigProvider.notifier)
            .setOnlineAudioQualityPreference(value);
      },
    );
  }

  Future<void> _openPlayerBackgroundStyleSheet() {
    final config = ref.read(appConfigProvider);
    final options = <SettingsChoiceOption<AppPlayerBackgroundStyle>>[
      SettingsChoiceOption<AppPlayerBackgroundStyle>(
        value: AppPlayerBackgroundStyle.albumCover,
        title: _playerBackgroundStyleLabel(
          AppPlayerBackgroundStyle.albumCover,
          config,
        ),
        subtitle: AppI18n.t(
          config,
          'settings.player_background_style.album_cover.desc',
        ),
      ),
      SettingsChoiceOption<AppPlayerBackgroundStyle>(
        value: AppPlayerBackgroundStyle.fluid,
        title: _playerBackgroundStyleLabel(
          AppPlayerBackgroundStyle.fluid,
          config,
        ),
        subtitle: AppI18n.t(
          config,
          'settings.player_background_style.fluid.desc',
        ),
      ),
      SettingsChoiceOption<AppPlayerBackgroundStyle>(
        value: AppPlayerBackgroundStyle.artistPhoto,
        title: _playerBackgroundStyleLabel(
          AppPlayerBackgroundStyle.artistPhoto,
          config,
        ),
        subtitle: AppI18n.t(
          config,
          'settings.player_background_style.artist_photo.desc',
        ),
      ),
    ];
    return showSettingsSingleChoiceSheet<AppPlayerBackgroundStyle>(
      context: context,
      title: AppI18n.t(config, 'settings.player_background_style'),
      currentValue: config.playerBackgroundStyle,
      options: options,
      onSelected: (value) {
        ref.read(appConfigProvider.notifier).setPlayerBackgroundStyle(value);
      },
    );
  }

  Future<void> _openLyricHighlightColorSheet() {
    final config = ref.read(appConfigProvider);
    final options = <SettingsChoiceOption<String>>[
      SettingsChoiceOption<String>(
        value: AppLyricHighlightMode.auto.value,
        title: AppI18n.t(config, 'settings.choice.auto'),
        leading: SettingsColorDot(color: AppLyricHighlightColor.sky.color),
      ),
      ...AppLyricHighlightColor.values.map(
        (item) => SettingsChoiceOption<String>(
          value: 'preset:${item.value}',
          title: item.label,
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
    return showSettingsSingleChoiceSheet<AppLyricFontPreset>(
      context: context,
      title: AppI18n.t(config, 'settings.lyric_font_preset'),
      currentValue: config.lyricFontPreset,
      options: AppLyricFontPreset.values
          .map(
            (item) => SettingsChoiceOption<AppLyricFontPreset>(
              value: item,
              title: item.label,
            ),
          )
          .toList(growable: false),
      onSelected: (value) {
        ref.read(appConfigProvider.notifier).setLyricFontPreset(value);
      },
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

  String _playerBackgroundStyleLabel(
    AppPlayerBackgroundStyle style,
    AppConfigState config,
  ) {
    return switch (style) {
      AppPlayerBackgroundStyle.albumCover => AppI18n.t(
        config,
        'settings.player_background_style.album_cover',
      ),
      AppPlayerBackgroundStyle.fluid => AppI18n.t(
        config,
        'settings.player_background_style.fluid',
      ),
      AppPlayerBackgroundStyle.artistPhoto => AppI18n.t(
        config,
        'settings.player_background_style.artist_photo',
      ),
    };
  }

  String _lyricHighlightSummary(AppConfigState config) {
    return switch (config.lyricHighlightMode) {
      AppLyricHighlightMode.auto => AppI18n.t(config, 'settings.choice.auto'),
      AppLyricHighlightMode.custom => AppI18n.t(
        config,
        'settings.choice.custom',
      ),
      AppLyricHighlightMode.preset => config.lyricHighlightPreset.label,
    };
  }

  Color _lyricHighlightPreviewColor(AppConfigState config) {
    return switch (config.lyricHighlightMode) {
      AppLyricHighlightMode.custom =>
        config.lyricHighlightCustomColor == null
            ? AppLyricHighlightColor.sky.color
            : Color(config.lyricHighlightCustomColor!),
      AppLyricHighlightMode.auto => AppLyricHighlightColor.sky.color,
      AppLyricHighlightMode.preset => config.lyricHighlightPreset.color,
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
