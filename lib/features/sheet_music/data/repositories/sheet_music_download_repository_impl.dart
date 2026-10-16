import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';

import '../../domain/repositories/sheet_music_download_repository.dart';

class SheetMusicDownloadRepositoryImpl implements SheetMusicDownloadRepository {
  SheetMusicDownloadRepositoryImpl(
    this._dio, {
    Future<String?> Function()? selectDirectory,
  }) : _selectDirectory = selectDirectory ?? _pickDirectory;

  final Dio _dio;
  final Future<String?> Function() _selectDirectory;

  static Future<String?> _pickDirectory() => getDirectoryPath();

  @override
  Future<SheetMusicDownloadDestination?> prepare(String title) async {
    if (kIsWeb) {
      throw const SheetMusicSaveException('sheet_music.download_unsupported');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        final permission = await Permission.photosAddOnly.request();
        if (!permission.isGranted && !permission.isLimited) {
          throw const SheetMusicSaveException('sheet_music.permission_denied');
        }
        return _GalleryDestination();
      case TargetPlatform.android:
        final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
        // MediaStore 在 Android 10+ 保存新文件不需要读取整个相册的权限。
        if (sdk < 29 && !(await Permission.storage.request()).isGranted) {
          throw const SheetMusicSaveException('sheet_music.permission_denied');
        }
        return _GalleryDestination();
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        final selected = await _selectDirectory();
        if (selected == null) return null;
        final folder = await Directory(
          p.join(
            selected,
            '${sheetMusicFileStem(title)}_${DateTime.now().millisecondsSinceEpoch}',
          ),
        ).create(recursive: true);
        return _DirectoryDestination(folder);
      case TargetPlatform.fuchsia:
        throw const SheetMusicSaveException('sheet_music.download_unsupported');
    }
  }

  @override
  Future<void> downloadPage({
    required SheetMusicDownloadDestination destination,
    required String url,
    required String title,
    required int pageIndex,
  }) async {
    // 图片 URL 可能来自第三方 CDN，使用独立传输，避免向外部地址附加 API Token。
    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw const SheetMusicSaveException('sheet_music.image_failed');
    }
    final bytes = Uint8List.fromList(data);
    final mime = lookupMimeType('', headerBytes: bytes);
    final extension = mime == null ? null : extensionFromMime(mime);
    if (mime == null || !mime.startsWith('image/') || extension == null) {
      throw const SheetMusicSaveException('sheet_music.invalid_image');
    }
    final number = '${pageIndex + 1}'.padLeft(3, '0');
    await destination.save(
      bytes,
      '${sheetMusicFileStem(title)}_$number.$extension',
    );
  }
}

String sheetMusicFileStem(String title) {
  final sanitized = title
      .trim()
      .replaceAll(RegExp(r'[\x00-\x1f\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'[. ]+$'), '');
  if (sanitized.isEmpty) return 'sheet_music';
  // 按 Unicode 码点截取，避免破坏 emoji；留出页码和扩展名空间。
  return String.fromCharCodes(sanitized.runes.take(48));
}

class _DirectoryDestination extends SheetMusicDownloadDestination {
  _DirectoryDestination(this.directory);
  final Directory directory;

  @override
  String get directoryPath => directory.path;

  @override
  Future<void> save(Uint8List bytes, String fileName) async {
    await File(
      p.join(directory.path, fileName),
    ).writeAsBytes(bytes, flush: true);
  }
}

class _GalleryDestination extends SheetMusicDownloadDestination {
  @override
  String? get directoryPath => null;

  @override
  Future<void> save(Uint8List bytes, String fileName) async {
    final folder = await Directory(
      (await getTemporaryDirectory()).path,
    ).createTemp('he_sheet_music_');
    final file = File(p.join(folder.path, fileName));
    try {
      await file.writeAsBytes(bytes, flush: true);
      // saveFile 直接复制原图，避免 saveImage 对谱面重编码导致细线模糊。
      final result = await SaverGallery.saveFile(
        filePath: file.path,
        fileName: fileName,
        androidRelativePath: 'Pictures/HE Music/sheet_music',
        skipIfExists: false,
      );
      if (!result.isSuccess) {
        throw const SheetMusicSaveException('sheet_music.save_failed');
      }
    } finally {
      if (await folder.exists()) await folder.delete(recursive: true);
    }
  }
}
