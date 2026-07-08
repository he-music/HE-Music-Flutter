import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../domain/entities/online_platform.dart';
import '../providers/online_providers.dart';
import '../pages/online_search_hot_panel.dart';
import '../pages/online_search_suggest_panel.dart';

/// 搜索输入组件：搜索框 + 搜索历史/热门搜索 + 搜索建议
///
/// 可复用于桌面顶部栏和移动端搜索页。
/// 选中关键词或回车时通过 [onSearch] 回调通知外部。
class SearchInput extends ConsumerStatefulWidget {
  const SearchInput({
    required this.onSearch,
    this.autofocus = false,
    this.compact = false,
    super.key,
  });

  /// 选中关键词或回车时回调
  final ValueChanged<String> onSearch;

  /// 是否自动聚焦
  final bool autofocus;

  /// 紧凑模式：只显示搜索框，不显示热搜/建议面板（用于桌面顶部栏）
  final bool compact;

  @override
  ConsumerState<SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends ConsumerState<SearchInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  List<String> _historyKeywords = const <String>[];
  List<String> _hotKeywords = const <String>[];
  List<String> _suggestKeywords = const <String>[];
  bool _loadingHistory = true;
  bool _loadingHot = true;
  bool _loadingSuggestions = false;
  bool _showSuggestionPanel = false;
  Timer? _suggestDebounce;

  static const List<String> _defaultHotKeywords = <String>[
    '周杰伦',
    '林俊杰',
    '邓紫棋',
    '毛不易',
    '陈奕迅',
    '张杰',
    'Taylor Swift',
    'Adele',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.autofocus) {
      _focusNode.requestFocus();
    }
    Future.microtask(() {
      _loadHistory();
      _loadHotKeywords();
    });
  }

  @override
  void dispose() {
    _suggestDebounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── 数据加载 ──

  Future<void> _loadHistory() async {
    try {
      final keywords = await ref
          .read(onlineSearchRepositoryProvider)
          .getSearchHistory();
      if (!mounted) return;
      setState(() {
        _historyKeywords = keywords;
        _loadingHistory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingHistory = false);
    }
  }

  Future<void> _loadHotKeywords() async {
    final platformId = _firstPlatformIdSupportingFeature(
      PlatformFeatureSupportFlag.getSearchHotkey,
    );
    if (platformId == null) {
      if (!mounted) return;
      setState(() {
        _hotKeywords = _defaultHotKeywords;
        _loadingHot = false;
      });
      return;
    }
    try {
      final cached = ref
          .read(searchHotKeywordsCacheProvider.notifier)
          .getCached(platformId);
      if (cached != null && cached.keywords.isNotEmpty && mounted) {
        setState(() {
          _hotKeywords = cached.keywords;
          _loadingHot = false;
        });
      }
      final hot = await ref
          .read(searchHotKeywordsCacheProvider.notifier)
          .ensureKeywords(platformId);
      if (!mounted) return;
      setState(() {
        _hotKeywords = hot;
        _loadingHot = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hotKeywords = _defaultHotKeywords;
        _loadingHot = false;
      });
    }
  }

  // ── 搜索建议 ──

  void _onChanged(String value) {
    final keyword = value.trim();
    if (keyword.isNotEmpty) {
      if (!_showSuggestionPanel) {
        setState(() => _showSuggestionPanel = true);
      }
      _scheduleLoadSuggestions(keyword);
      return;
    }
    _suggestDebounce?.cancel();
    setState(() {
      _showSuggestionPanel = false;
      _loadingSuggestions = false;
      _suggestKeywords = const <String>[];
    });
  }

  void _scheduleLoadSuggestions(String keyword) {
    _suggestDebounce?.cancel();
    _suggestDebounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_loadSuggestions(keyword));
    });
  }

  Future<void> _loadSuggestions(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty || !mounted) return;
    setState(() => _loadingSuggestions = true);

    var suggested = const <String>[];
    final suggestPlatformId = _firstPlatformIdSupportingFeature(
      PlatformFeatureSupportFlag.getSearchSuggest,
    );
    if (suggestPlatformId != null) {
      try {
        suggested = await ref
            .read(onlineSearchRepositoryProvider)
            .fetchSearchSuggestions(
              keyword: query,
              platform: suggestPlatformId,
            );
      } catch (_) {
        suggested = const <String>[];
      }
    }
    if (!mounted) return;
    if (_controller.text.trim() != query) return;

    final local = _localSuggestions(query);
    final merged = <String>[...suggested, ...local];
    final deduped = <String>[];
    for (final item in merged) {
      final trimmed = item.trim();
      if (trimmed.isEmpty || deduped.contains(trimmed)) continue;
      deduped.add(trimmed);
    }
    setState(() {
      _loadingSuggestions = false;
      _suggestKeywords = deduped.take(18).toList(growable: false);
    });
  }

  List<String> _localSuggestions(String keyword) {
    final query = keyword.toLowerCase();
    final source = <String>[..._historyKeywords, ..._hotKeywords];
    return source
        .where((value) => value.toLowerCase().contains(query))
        .toList(growable: false);
  }

  // ── 搜索操作 ──

  Future<void> _onTapKeyword(String keyword) async {
    final normalized = keyword.trim();
    if (normalized.isEmpty) return;
    // 保存搜索历史
    await ref.read(onlineSearchRepositoryProvider).saveSearchKeyword(keyword);
    if (!mounted) return;
    // 更新 controller 显示
    _controller.value = TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
    setState(() => _showSuggestionPanel = false);
    widget.onSearch(normalized);
  }

  void _onSubmit(String value) {
    final keyword = value.trim();
    if (keyword.isEmpty) return;
    _onTapKeyword(keyword);
  }

  void _onClearHistory() async {
    await ref.read(onlineSearchRepositoryProvider).clearSearchHistory();
    if (!mounted) return;
    setState(() => _historyKeywords = const <String>[]);
  }

  // ── 工具方法 ──

  String? _firstPlatformIdSupportingFeature(BigInt featureFlag) {
    final allPlatforms = ref.read(onlinePlatformsProvider).value;
    if (allPlatforms == null || allPlatforms.isEmpty) return null;
    for (final platform in allPlatforms) {
      if (platform.available && platform.supports(featureFlag)) {
        return platform.id;
      }
    }
    return null;
  }

  bool _shouldReloadHotKeywordsAfterPlatformLoad() {
    return !_loadingHot &&
        (_hotKeywords.isEmpty || _isDefaultHotKeywords(_hotKeywords));
  }

  bool _hasHotKeywordPlatform(List<OnlinePlatform>? platforms) {
    if (platforms == null || platforms.isEmpty) {
      return false;
    }
    return platforms.any(
      (platform) =>
          platform.available &&
          platform.supports(PlatformFeatureSupportFlag.getSearchHotkey),
    );
  }

  bool _isDefaultHotKeywords(List<String> values) {
    if (values.length != _defaultHotKeywords.length) {
      return false;
    }
    for (var index = 0; index < values.length; index++) {
      if (values[index] != _defaultHotKeywords[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<OnlinePlatform>>>(onlinePlatformsProvider, (
      previous,
      next,
    ) {
      final previousHadHotPlatform = _hasHotKeywordPlatform(previous?.value);
      final nextHasHotPlatform = _hasHotKeywordPlatform(next.value);
      if (previousHadHotPlatform ||
          !nextHasHotPlatform ||
          !_shouldReloadHotKeywordsAfterPlatformLoad()) {
        return;
      }
      unawaited(_loadHotKeywords());
    });
    final config = ref.watch(appConfigProvider);
    final keyword = _controller.text.trim();
    final isCompact = widget.compact;
    final showSuggest =
        !isCompact && _showSuggestionPanel && keyword.isNotEmpty;
    final showHot = !isCompact && !showSuggest;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 搜索输入框
        SizedBox(
          height: 42,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            onChanged: _onChanged,
            onSubmitted: _onSubmit,
            decoration: InputDecoration(
              hintText: AppI18n.t(config, 'home.search'),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              suffixIcon: keyword.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _controller.clear();
                        _onChanged('');
                      },
                    )
                  : null,
            ),
          ),
        ),
        // 搜索建议
        if (showSuggest)
          OnlineSearchSuggestPanel(
            loading: _loadingSuggestions,
            suggestions: _suggestKeywords,
            onTapKeyword: _onTapKeyword,
          ),
        // 搜索历史 + 热门搜索
        if (showHot)
          OnlineSearchHotPanel(
            localeCode: config.localeCode,
            historyKeywords: _historyKeywords,
            hotKeywords: _hotKeywords,
            loadingHistory: _loadingHistory,
            loadingHot: _loadingHot,
            onTapKeyword: _onTapKeyword,
            onClearHistory: _onClearHistory,
          ),
      ],
    );
  }
}
