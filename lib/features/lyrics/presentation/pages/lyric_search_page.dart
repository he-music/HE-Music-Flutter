import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_message_service.dart';
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final platformsAsync = ref.watch(onlinePlatformsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('搜索歌词')),
      body: SafeArea(
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                '为「${widget.target.title}」选择歌词',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _name,
                    enabled: _selecting == null,
                    decoration: const InputDecoration(labelText: '歌名'),
                    onChanged: (_) => _invalidate(),
                  ),
                  TextField(
                    controller: _artist,
                    enabled: _selecting == null,
                    decoration: const InputDecoration(
                      labelText: '歌手',
                      hintText: '多位歌手用顿号分隔',
                    ),
                    onChanged: (_) => _invalidate(),
                  ),
                ],
              ),
            ),
            platformsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: TextButton(
                  onPressed: () => ref.invalidate(onlinePlatformsProvider),
                  child: const Text('平台加载失败，重试'),
                ),
              ),
              data: (all) {
                final platforms = all
                    .where(
                      (p) =>
                          p.available &&
                          p.supports(PlatformFeatureSupportFlag.searchLyric),
                    )
                    .toList();
                if (platforms.isEmpty) {
                  return const Center(child: Text('暂无可用的歌词搜索平台'));
                }
                final selected =
                    platforms.where((p) => p.id == _platform).firstOrNull ??
                    platforms
                        .where((p) => p.id == widget.target.platform)
                        .firstOrNull ??
                    platforms.first;
                return Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          for (final platform in platforms)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(platform.name),
                                selected: platform.id == selected.id,
                                onSelected: _selecting != null
                                    ? null
                                    : (_) {
                                        _platform = platform.id;
                                        _invalidate();
                                      },
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: FilledButton.icon(
                        onPressed: _loading || _selecting != null
                            ? null
                            : () => _search(selected.id),
                        icon: const Icon(Icons.search),
                        label: const Text('搜索'),
                      ),
                    ),
                    if (_loading) const LinearProgressIndicator(),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_message!),
                      ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final candidate = _results[index];
                        final seconds = candidate.duration;
                        return ListTile(
                          title: Text(candidate.name),
                          subtitle: Text(
                            '${candidate.artistNames.join('、')} · ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                          ),
                          trailing: identical(candidate, _selecting)
                              ? const SizedBox.square(
                                  dimension: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.chevron_right),
                          onTap: _selecting == null
                              ? () => _select(candidate)
                              : null,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
