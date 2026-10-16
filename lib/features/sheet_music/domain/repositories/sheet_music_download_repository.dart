import 'dart:typed_data';

abstract class SheetMusicDownloadDestination {
  String? get directoryPath;
  Future<void> save(Uint8List bytes, String fileName);
}

abstract class SheetMusicDownloadRepository {
  /// 用户取消目录选择时返回 null；一次批量保存只询问一次。
  Future<SheetMusicDownloadDestination?> prepare(String title);

  Future<void> downloadPage({
    required SheetMusicDownloadDestination destination,
    required String url,
    required String title,
    required int pageIndex,
  });
}

class SheetMusicSaveException implements Exception {
  const SheetMusicSaveException(this.messageKey);
  final String messageKey;
}
