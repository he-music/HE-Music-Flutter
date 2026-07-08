import 'dart:io';

import 'package:path_provider/path_provider.dart';

String get _downloadDirName => Platform.isIOS ? 'Downloads' : 'HEMusic';

class DownloadPathDataSource {
  Future<Directory> ensureDownloadDirectory() async {
    // iOS 不使用 getDownloadsDirectory()，直接用 Documents 目录
    // 确保文件在 Files app（"On My iPhone"）中可见
    final baseDir = Platform.isIOS
        ? await getApplicationDocumentsDirectory()
        : await getDownloadsDirectory() ??
              await getApplicationDocumentsDirectory();
    final targetDir = Directory('${baseDir.path}/$_downloadDirName');
    try {
      if (await targetDir.exists()) {
        return targetDir;
      }
      return await targetDir.create(recursive: true);
    } on FileSystemException {
      final fallbackBaseDir = await getApplicationDocumentsDirectory();
      final fallbackDir = Directory(
        '${fallbackBaseDir.path}/$_downloadDirName',
      );
      if (await fallbackDir.exists()) {
        return fallbackDir;
      }
      return fallbackDir.create(recursive: true);
    }
  }
}
