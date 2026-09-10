import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/theme/skin/app_skin_surface.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/online_platform_tabs.dart';
import '../../../online/domain/entities/online_platform.dart';
import '../../../online/presentation/providers/online_providers.dart';
import '../../../player/domain/entities/player_track.dart';
import '../providers/lyrics_providers.dart';
import '../../domain/entities/lyric_candidate.dart';
import '../../domain/entities/lyric_request.dart';

class LyricSearchPage extends ConsumerStatefulWidget {
  const LyricSearchPage({required this.target, super.key});
  final PlayerTrack target;
  @override
  ConsumerState<LyricSearchPage> createState() => _LyricSearchPageState();
}

class _LyricSearchPageState extends ConsumerState<LyricSearchPage> {
  late final _name = TextEditingController(text: widget.target.title);
  late final _artist = TextEditingController(
    text: widget.target.artist == '未知歌手' ? '' : widget.target.artist ?? '',
  );
  String? _platform;
  int _generation = 0;
  bool _loading = false;
  LyricCandidate? _selecting;
  List<LyricCandidate> _results = [];
  String? _message;
  final Map<String, Future<List<LyricCandidate>>> _pending = {};

  bool _platformSyncScheduled = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(onlinePlatformsProvider, (_, _) {
      if (_platformSyncScheduled) return;
      _platformSyncScheduled = true;
      // Platform providers may resolve during build; dispatch after the frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _platformSyncScheduled = false;
        _syncPlatform();
      });
    }, fireImmediately: true);
  }

  void _syncPlatform() {
    if (!mounted || _selecting != null) return;
    final all = ref.read(onlinePlatformsProvider).asData?.value;
    if (all == null) return;
    final platforms = _eligiblePlatforms(all);
    final selected =
        platforms.where((p) => p.id == _platform).firstOrNull ??
        platforms.where((p) => p.id == widget.target.platform).firstOrNull ??
        platforms.firstOrNull;
    if (_platform == selected?.id) return;
    _platform = selected?.id;
    _invalidate();
    if (_platform != null) _search(_platform!);
  }

  List<OnlinePlatform> _eligiblePlatforms(List<OnlinePlatform> all) => all
      .where(
        (p) =>
            p.available && p.supports(PlatformFeatureSupportFlag.searchLyric),
      )
      .toList();

  void _changePlatform(String platform) {
    if (_selecting != null || platform == _platform) return;
    _platform = platform;
    _invalidate();
    _search(platform);
  }

  void _submit() {
    if (_selecting != null || _platform == null) return;
    final all = ref.read(onlinePlatformsProvider).asData?.value;
    if (all == null || !_eligiblePlatforms(all).any((p) => p.id == _platform)) {
      return;
    }
    _search(_platform!);
  }

  void _invalidate() {
    setState(() {
      _generation++;
      _results = [];
      _loading = false;
      _message = null;
    });
  }

  @override
  void dispose() {
    _generation++;
    _name.dispose();
    _artist.dispose();
    super.dispose();
  }

  Future<void> _search(String platform) async {
    final name = _name.text.trim();
    final artists = _artist.text
        .split(RegExp('[、,，]'))
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    if (name.isEmpty || artists.isEmpty) {
      setState(() => _message = '请补齐歌名和歌手');
      return;
    }
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _message = null;
      _results = [];
    });
    final key = '$platform\u0000$name\u0000${artists.join('\u0000')}';
    final client = ref.read(onlineApiClientProvider);
    final future = _pending.putIfAbsent(
      key,
      () => client.searchLyricCandidates(
        platform: platform,
        name: name,
        artistNames: artists,
        albumName: widget.target.album ?? '',
        duration: widget.target.duration?.inSeconds ?? 0,
      ),
    );
    try {
      final results = await future;
      if (!mounted || generation != _generation) return;
      setState(() {
        _results = results;
        _message = results.isEmpty ? '没有找到歌词，试试其他平台或关键词' : null;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _message = '歌词搜索失败，请重试');
    } finally {
      if (identical(_pending[key], future)) _pending.remove(key);
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _select(LyricCandidate candidate) async {
    if (_selecting != null) return;
    setState(() => _selecting = candidate);
    final target = LyricRequest(
      trackId: widget.target.id,
      platform: widget.target.platform,
      localPath: widget.target.path,
    );
    final store = ref.read(lyricStoreProvider);
    final token = store.beginSelection(target);
    try {
      final bundle = await ref
          .read(onlineApiClientProvider)
          .fetchLyricCandidate(candidate);
      if (!mounted) return;
      await store.saveManual(
        target,
        bundle,
        sourcePlatform: candidate.platform,
        sourceId: candidate.id,
        title: widget.target.title,
        artist: widget.target.artist ?? '',
        token: token,
      );
      if (!mounted) return;
      AppMessageService.showSuccess('已更换歌词');
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        AppMessageService.showError('更换歌词失败：$error');
        setState(() => _selecting = null);
        // Reconcile refreshes deferred while the candidate was being saved.
        _syncPlatform();
      }
    }
  }

  Widget _inputRow(String label, TextEditingController controller) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 12),
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Semantics(
            label: label,
            child: TextField(
              controller: controller,
              enabled: _selecting == null,
              style: theme.textTheme.bodyMedium,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: label == '歌名' ? '请输入歌名' : '请输入歌手',
                filled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: const UnderlineInputBorder(),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: .5),
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
                disabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                suffixIcon: IconButton(
                  tooltip: '清空$label',
                  onPressed: _selecting != null || controller.text.isEmpty
                      ? null
                      : () {
                          controller.clear();
                          _invalidate();
                        },
                  icon: const Icon(Icons.close, size: 18),
                ),
              ),
              onChanged: (_) => _invalidate(),
              onSubmitted: (_) => _submit(),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final platformsAsync = ref.watch(onlinePlatformsProvider);
    final platforms = _eligiblePlatforms(platformsAsync.asData?.value ?? []);
    final canSearch =
        _selecting == null && platforms.any((p) => p.id == _platform);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(onPressed: () => Navigator.of(context).pop()),
        title: const Text('搜索歌词', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
            onPressed: canSearch ? _submit : null,
            child: const Text('搜索'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  '为「${widget.target.title}」选择歌词',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: platformsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => TextButton(
                    onPressed: () => ref.invalidate(onlinePlatformsProvider),
                    child: const Text('平台加载失败，重试'),
                  ),
                  data: (_) => platforms.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('暂无可用的歌词搜索平台'),
                        )
                      : ExcludeFocus(
                          excluding: _selecting != null,
                          child: AbsorbPointer(
                            absorbing: _selecting != null,
                            child: OnlinePlatformTabs(
                              platforms: platforms,
                              selectedId: _platform,
                              requiredFeatureFlag:
                                  PlatformFeatureSupportFlag.searchLyric,
                              onSelected: _changePlatform,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _inputRow('歌名', _name),
                    const SizedBox(height: 10),
                    _inputRow('歌手', _artist),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                      child: Text(
                        '多位歌手用顿号或中英文逗号分隔',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading ||
                (platformsAsync.isLoading && !platformsAsync.hasValue))
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            if (_message != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_message!, style: theme.textTheme.bodyMedium),
                ),
              ),
            SliverList.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final candidate = _results[index];
                final seconds = candidate.duration;
                final artistNames = candidate.artistNames
                    .map((name) => name.trim())
                    .where((name) => name.isNotEmpty)
                    .join(' / ');
                return AppSkinContentSurface(
                  child: ListTile(
                    title: Text(
                      candidate.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      artistNames.isEmpty ? '-' : artistNames,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: identical(candidate, _selecting)
                        ? const SizedBox.square(
                            dimension: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : seconds > 0
                        ? Text(
                            '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                            style: theme.textTheme.bodySmall,
                          )
                        : null,
                    onTap: _selecting == null ? () => _select(candidate) : null,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
