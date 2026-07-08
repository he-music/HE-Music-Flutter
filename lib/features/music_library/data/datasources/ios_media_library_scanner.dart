import 'package:flutter/services.dart';

/// iOS 媒体库扫描器
///
/// 通过 Method Channel 调用原生 Swift 代码查询 MPMediaQuery。
/// 返回的每个 track 包含：id, title, artist, album, duration, filePath, mimeType, size。
class IosMediaLibraryScanner {
  static const _channel = MethodChannel(
    'com.hemusic.music/media_library',
  );

  /// 请求媒体库访问权限
  Future<bool> requestPermission() async {
    final result = await _channel.invokeMethod<bool>('requestPermission');
    return result ?? false;
  }

  /// 扫描设备上的歌曲
  ///
  /// 返回原始 track 数据列表。
  /// 每个元素包含 id/title/artist/album/duration/filePath/mimeType/size 字段。
  Future<List<Map<String, dynamic>>> scanSongs() async {
    final result = await _channel.invokeMethod<List<dynamic>>('scanSongs');
    if (result == null) return const [];
    return result
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }
}
