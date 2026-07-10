import 'dart:io' show Platform;

import 'package:audiotags/audiotags.dart' as at;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_message_service.dart';
import '../../../../app/config/app_config_controller.dart';
import '../../../../app/i18n/app_i18n.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../domain/entities/local_song.dart';
import '../providers/local_library_providers.dart';

/// 元数据编辑页
///
/// 编辑本地歌曲的元数据标签。
/// - Android/macOS：写回文件标签 + 更新 DB
/// - iOS：仅更新 DB（MPMediaQuery 文件不可写）
class MetadataEditPage extends ConsumerStatefulWidget {
  const MetadataEditPage({super.key, required this.song});

  final LocalSong song;

  @override
  ConsumerState<MetadataEditPage> createState() => _MetadataEditPageState();
}

class _MetadataEditPageState extends ConsumerState<MetadataEditPage> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _artistCtrl;
  late final TextEditingController _albumCtrl;
  late final TextEditingController _genreCtrl;
  late final TextEditingController _yearCtrl;
  bool _hasChanges = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.song.title);
    _artistCtrl = TextEditingController(text: widget.song.artist);
    _albumCtrl = TextEditingController(text: widget.song.album);
    _genreCtrl = TextEditingController(text: widget.song.genre);
    _yearCtrl = TextEditingController(text: widget.song.year?.toString() ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _albumCtrl.dispose();
    _genreCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final song = widget.song;
    // 仅对不可写入的文件（如 iOS 系统音乐库）显示降级提示
    final showIOSNotice =
        Platform.isIOS && widget.song.filePath.startsWith('ipod-library://');
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(AppI18n.t(config, 'local.edit.title')),
        actions: <Widget>[
          if (_hasChanges && !_saving)
            TextButton(
              onPressed: _save,
              child: Text(AppI18n.t(config, 'common.confirm')),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // iOS 降级提示
            if (showIOSNotice)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppI18n.t(config, 'local.edit.ios_notice'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            // 编辑字段
            _buildTextField(
              controller: _titleCtrl,
              label: AppI18n.t(config, 'local.edit.field.title'),
              onChanged: (_) => _markChanged(),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _artistCtrl,
              label: AppI18n.t(config, 'local.edit.field.artist'),
              onChanged: (_) => _markChanged(),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _albumCtrl,
              label: AppI18n.t(config, 'local.edit.field.album'),
              onChanged: (_) => _markChanged(),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _genreCtrl,
              label: AppI18n.t(config, 'local.edit.field.genre'),
              onChanged: (_) => _markChanged(),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _yearCtrl,
              label: AppI18n.t(config, 'local.edit.field.year'),
              keyboardType: TextInputType.number,
              onChanged: (_) => _markChanged(),
            ),
            const SizedBox(height: 24),
            // 文件信息只读区
            Text(
              AppI18n.t(config, 'local.edit.file_info'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              context,
              '格式',
              song.formatLabel.isNotEmpty ? song.formatLabel : song.mimeType,
            ),
            if (song.bitrate != null)
              _buildInfoRow(context, '比特率', '${song.bitrate} kbps'),
            if (song.sampleRate != null)
              _buildInfoRow(context, '采样率', '${song.sampleRate} Hz'),
            _buildInfoRow(context, '文件大小', _formatSize(song.size)),
            _buildInfoRow(context, '时长', _formatDuration(song.duration)),
            const SizedBox(height: 8),
            Text(
              song.filePath,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // 保存中状态
            if (_saving) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  AppI18n.t(config, 'local.edit.saving'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _save() async {
    final config = ref.read(appConfigProvider);
    setState(() => _saving = true);
    try {
      final song = widget.song;
      final newTitle = _titleCtrl.text.trim();
      final newArtist = _artistCtrl.text.trim();
      final newAlbum = _albumCtrl.text.trim();
      final newGenre = _genreCtrl.text.trim();
      final newYear = int.tryParse(_yearCtrl.text.trim());

      // 写回文件标签
      // iOS 上 MPMediaQuery 的文件（ipod-library://）不可写，沙盒文件可写
      final canWriteFile =
          !Platform.isIOS || !song.filePath.startsWith('ipod-library://');
      if (canWriteFile) {
        try {
          final tag = at.Tag(
            title: newTitle,
            artists: [newArtist],
            album: newAlbum,
            albumArtists: [newArtist],
            genre: newGenre,
            year: newYear,
            trackNumber: song.trackNumber,
            discNumber: song.discNumber,
            lyrics: song.embeddedLyrics,
            pictures: [],
          );
          await at.AudioTags.write(song.filePath, tag);
        } catch (_) {
          if (mounted) {
            AppMessageService.showError(
              AppI18n.t(config, 'local.edit.write_error'),
            );
          }
        }
      }

      // 更新 DB
      final dao = ref.read(localMusicDaoProvider);
      await dao.updateSongMetadata(
        songId: song.id,
        title: newTitle,
        artist: newArtist,
        album: newAlbum,
        genre: newGenre,
        year: newYear,
      );
      await dao.markMetadataEdited(song.id);

      if (mounted) {
        setState(() {
          _saving = false;
          _hasChanges = false;
        });
        AppMessageService.showSuccess(AppI18n.t(config, 'local.edit.saved'));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppMessageService.showError(
          '${AppI18n.t(config, 'local.edit.write_error')}: $e',
        );
      }
    }
  }
}
