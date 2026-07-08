import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// 根据 artworkUrl 或 artworkBytes 构建图片 Provider。
///
/// artworkUrl 优先判断是否为本地文件路径（以 '/' 开头），
/// 是则使用 [FileImage]，否则按网络 URL 处理。
ImageProvider<Object>? artworkProvider(
  String? artworkUrl,
  Uint8List? artworkBytes,
) {
  if (artworkBytes != null && artworkBytes.isNotEmpty) {
    return MemoryImage(artworkBytes);
  }
  final value = artworkUrl?.trim() ?? '';
  if (value.isEmpty) {
    return null;
  }
  if (value.startsWith('/')) {
    return FileImage(File(value));
  }
  return CachedNetworkImageProvider(value);
}
