import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../app/theme/glass/app_glass_scope.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../domain/entities/update_release.dart';
import '../../domain/entities/update_version.dart';
import '../providers/update_providers.dart';

class ReleaseHistoryPage extends ConsumerStatefulWidget {
  const ReleaseHistoryPage({super.key, this.latestVersion});

  final String? latestVersion;

  @override
  ConsumerState<ReleaseHistoryPage> createState() => _ReleaseHistoryPageState();
}

class _ReleaseHistoryPageState extends ConsumerState<ReleaseHistoryPage> {
  final _releases = <String, UpdateRelease>{};
  int _page = 1;
  bool _loading = false;
  bool _failed = false;
  bool _hasMore = true;
  bool _showEarlier = false;
  UpdateVersion? _current;
  UpdateVersion? _latest;
  UpdateVersion? _newestLoaded;
  String? _selected;
  bool _initialSelectionMade = false;
  final _scrollController = ScrollController();
  final _headerKeys = <String, GlobalKey>{};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _latest = widget.latestVersion == null
        ? null
        : UpdateVersion.tryParse(widget.latestVersion!);
    _load();
  }

  List<UpdateRelease> get _visible {
    final items = _releases.values.where((release) {
      if (_latest == null || _showEarlier) return true;
      return release.version.compareTo(_latest!) <= 0 &&
          (_current == null || release.version.compareTo(_current!) >= 0);
    }).toList();
    items.sort((a, b) => b.version.compareTo(a.version));
    return items;
  }

  Future<void> _load() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      if (_current == null) {
        final info = await ref.read(currentAppInfoProvider.future);
        if (!mounted) return;
        _current = UpdateVersion.tryParse(info.version);
      }
      final previousCount = _visible.length;
      // GitHub 按发布时间分页，不能遇到旧版本就停止，否则会漏掉晚发布的版本。
      do {
        final result = await ref.read(releaseHistoryPageProvider(_page).future);
        if (!mounted) return;
        for (final release in result.releases) {
          _releases[release.version.normalized] = release;
          if (_newestLoaded == null ||
              release.version.compareTo(_newestLoaded!) > 0) {
            _newestLoaded = release.version;
          }
        }
        _hasMore = result.hasMore;
        _page++;
      } while (_hasMore && _visible.length == previousCount);
    } catch (_) {
      if (!mounted) return;
      ref.invalidate(releaseHistoryPageProvider(_page));
      if (_current == null) ref.invalidate(currentAppInfoProvider);
      _failed = true;
    }
    if (mounted) {
      setState(() {
        _loading = false;
        if (!_initialSelectionMade && _visible.isNotEmpty) {
          _selected = _visible.first.version.normalized;
          _initialSelectionMade = true;
        }
      });
    }
  }

  String _t(String key) =>
      AppI18n.tByLocaleCode(ref.read(appConfigProvider).localeCode, key);

  @override
  Widget build(BuildContext context) {
    ref.watch(appConfigProvider.select((config) => config.localeCode));
    final title = Text(_t('update.history.title'));
    final glassEnabled = AppGlassScope.isEnabled(context);
    final body = SafeArea(top: !glassEnabled, child: _buildBody(context));
    if (glassEnabled) {
      return Material(
        type: MaterialType.transparency,
        child: GlassScaffold(
          extendBody: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: GlassAppBar(
            title: title,
            leading: GlassIconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.appPopOrGo(),
            ),
          ),
          body: body,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(leading: const AppBackButton(), title: title),
      body: body,
    );
  }

  Widget _buildBody(BuildContext context) {
    final releases = _visible;
    if (releases.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_latest != null && !_showEarlier && _current != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Text(
                    _t(
                      'update.history.since',
                    ).replaceAll('{version}', 'v${_current!.normalized}'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (releases.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Text(
                    _t(
                      _failed
                          ? 'update.history.failed'
                          : 'update.history.empty',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final release in releases) ...[
                _versionEntry(release),
                Divider(
                  height: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ],
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (_failed && releases.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    _t('update.history.failed'),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_failed || _hasMore || (_latest != null && !_showEarlier))
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      if (_failed || _hasMore)
                        TextButton(
                          onPressed: _loading ? null : _load,
                          child: Text(
                            _t(
                              _failed ? 'common.retry' : 'update.history.more',
                            ),
                          ),
                        ),
                      if (_latest != null && !_showEarlier)
                        TextButton(
                          onPressed: () => setState(() => _showEarlier = true),
                          child: Text(_t('update.history.earlier')),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleVersion(String version) {
    final headerKey = _headerKeys[version]!;
    final before = headerKey.currentContext?.findRenderObject() as RenderBox?;
    final previousY = before?.localToGlobal(Offset.zero).dy;
    setState(() => _selected = _selected == version ? null : version);
    // 上方的长日志收起后保持被点击的标题可见，避免用户丢失阅读位置。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || previousY == null) {
        return;
      }
      final after = headerKey.currentContext?.findRenderObject() as RenderBox?;
      if (after == null) return;
      final position = _scrollController.position;
      final offset =
          position.pixels + after.localToGlobal(Offset.zero).dy - previousY;
      _scrollController.jumpTo(
        offset.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    });
  }

  Widget _versionEntry(UpdateRelease release) {
    final version = release.version.normalized;
    final expanded = version == _selected;
    final newest = _latest ?? _newestLoaded;
    final isLatest = newest != null && release.version.compareTo(newest) == 0;
    final isCurrent =
        _current != null && release.version.compareTo(_current!) == 0;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final date = release.publishedAt.toLocal();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: expanded,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: _headerKeys.putIfAbsent(version, GlobalKey.new),
              borderRadius: BorderRadius.circular(12),
              onTap: () => _toggleVersion(version),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'v$version',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (isLatest)
                                Text(
                                  _t('update.history.latest'),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              if (isCurrent)
                                Text(
                                  _t('update.history.current'),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 24),
            child: _details(release),
          ),
      ],
    );
  }

  Widget _details(UpdateRelease release) {
    return MarkdownBody(
      data: release.releaseNotes.isEmpty
          ? _t('settings.about.release_notes.empty')
          : release.releaseNotes,
      imageBuilder: (_, _, alt) => Text(alt ?? ''),
      onTapLink: (_, href, _) async {
        final uri = href == null ? null : Uri.tryParse(href);
        if (uri == null ||
            !uri.hasAuthority ||
            (uri.scheme != 'https' && uri.scheme != 'http')) {
          return;
        }
        try {
          if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
              mounted) {
            AppMessageService.showError(_t('settings.about.open_failed'));
          }
        } catch (_) {
          if (mounted) {
            AppMessageService.showError(_t('settings.about.open_failed'));
          }
        }
      },
    );
  }
}
