import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../config/app_custom_skin_config.dart';

class AppCustomSkinStagedRevision {
  const AppCustomSkinStagedRevision({
    required this.revision,
    required this.fileExtension,
    required this.lightBytes,
    required this.darkBytes,
    required this.candidateColors,
    required this.sourceWidth,
    required this.sourceHeight,
    required this.outputWidth,
    required this.outputHeight,
  });

  final String revision;
  final String fileExtension;
  final Uint8List lightBytes;
  final Uint8List darkBytes;
  final List<int> candidateColors;
  final int sourceWidth;
  final int sourceHeight;
  final int outputWidth;
  final int outputHeight;

  String get lightAssetPath =>
      'skins/custom_image/$revision/wallpaper_light.$fileExtension';

  String get darkAssetPath =>
      'skins/custom_image/$revision/wallpaper_dark.$fileExtension';

  AppCustomSkinConfig createConfig({
    required int seedColor,
    required double focalX,
    required double focalY,
    required bool swapped,
  }) {
    return AppCustomSkinConfig(
      revision: revision,
      lightAssetPath: swapped ? darkAssetPath : lightAssetPath,
      darkAssetPath: swapped ? lightAssetPath : darkAssetPath,
      candidateColors: candidateColors,
      seedColor: seedColor,
      focalX: focalX,
      focalY: focalY,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    );
  }
}

class AppCustomSkinStore {
  AppCustomSkinStore({
    Future<Directory> Function()? applicationSupportDirectory,
    String Function()? revisionFactory,
  }) : _applicationSupportDirectory =
           applicationSupportDirectory ?? getApplicationSupportDirectory,
       _revisionFactory = revisionFactory ?? _newRevision;

  final Future<Directory> Function() _applicationSupportDirectory;
  final String Function() _revisionFactory;

  Future<AppCustomSkinStagedRevision> stage({
    required Uint8List lightBytes,
    required Uint8List darkBytes,
    required String fileExtension,
    required List<int> candidateColors,
    required int sourceWidth,
    required int sourceHeight,
    required int outputWidth,
    required int outputHeight,
  }) async {
    final revision = _revisionFactory();
    if (!_isValidRevision(revision)) {
      throw ArgumentError.value(revision, 'revision', '非法资源版本');
    }
    if (fileExtension != 'jpg' && fileExtension != 'png') {
      throw ArgumentError.value(fileExtension, 'fileExtension', '非法图片扩展名');
    }
    final root = await _rootDirectory();
    final staging = Directory(p.join(root.path, '.staging', revision));
    try {
      await staging.create(recursive: true);
      final lightFile = File(
        p.join(staging.path, 'wallpaper_light.$fileExtension'),
      );
      final darkFile = File(
        p.join(staging.path, 'wallpaper_dark.$fileExtension'),
      );
      await lightFile.writeAsBytes(lightBytes, flush: true);
      await darkFile.writeAsBytes(darkBytes, flush: true);
      final lightInfo = await _decodeImageInfo(await lightFile.readAsBytes());
      final darkInfo = await _decodeImageInfo(await darkFile.readAsBytes());
      if (lightInfo != darkInfo ||
          lightInfo.width != outputWidth ||
          lightInfo.height != outputHeight) {
        throw StateError('自定义皮肤派生图尺寸不一致');
      }
      return AppCustomSkinStagedRevision(
        revision: revision,
        fileExtension: fileExtension,
        lightBytes: lightBytes,
        darkBytes: darkBytes,
        candidateColors: candidateColors,
        sourceWidth: sourceWidth,
        sourceHeight: sourceHeight,
        outputWidth: outputWidth,
        outputHeight: outputHeight,
      );
    } catch (_) {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<void> publish(AppCustomSkinStagedRevision staged) async {
    final root = await _rootDirectory();
    final staging = Directory(p.join(root.path, '.staging', staged.revision));
    final published = Directory(p.join(root.path, staged.revision));
    if (!await staging.exists() || await published.exists()) {
      throw StateError('自定义皮肤草稿版本不可发布');
    }
    await staging.rename(published.path);
  }

  Future<void> restoreStaging(AppCustomSkinStagedRevision staged) async {
    final root = await _rootDirectory();
    final published = Directory(p.join(root.path, staged.revision));
    final staging = Directory(p.join(root.path, '.staging', staged.revision));
    if (!await published.exists()) {
      return;
    }
    await staging.parent.create(recursive: true);
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
    await published.rename(staging.path);
  }

  Future<void> discardStaged(String revision) async {
    final directory = await _revisionDirectory(revision, staging: true);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> deleteRevision(String revision) async {
    final directory = await _revisionDirectory(revision);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<bool> validateConfig(AppCustomSkinConfig config) async {
    try {
      final support = await _applicationSupportDirectory();
      final lightFile = _managedFile(support, config.lightAssetPath);
      final darkFile = _managedFile(support, config.darkAssetPath);
      if (!await lightFile.exists() || !await darkFile.exists()) {
        return false;
      }
      final lightInfo = await _decodeImageInfo(await lightFile.readAsBytes());
      final darkInfo = await _decodeImageInfo(await darkFile.readAsBytes());
      return lightInfo == darkInfo;
    } catch (_) {
      return false;
    }
  }

  Future<void> cleanupOrphans(AppCustomSkinConfig? current) async {
    final root = await _rootDirectory();
    final staging = Directory(p.join(root.path, '.staging'));
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory || p.basename(entry.path) == current?.revision) {
        continue;
      }
      await entry.delete(recursive: true);
    }
  }

  Future<void> deleteAll() async {
    final root = await _rootDirectory(create: false);
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }

  Future<Directory> _rootDirectory({bool create = true}) async {
    final support = await _applicationSupportDirectory();
    final root = Directory(p.join(support.path, 'skins', 'custom_image'));
    if (create) {
      await root.create(recursive: true);
    }
    return root;
  }

  Future<Directory> _revisionDirectory(
    String revision, {
    bool staging = false,
  }) async {
    if (!_isValidRevision(revision)) {
      throw ArgumentError.value(revision, 'revision', '非法资源版本');
    }
    final root = await _rootDirectory();
    return Directory(
      staging
          ? p.join(root.path, '.staging', revision)
          : p.join(root.path, revision),
    );
  }

  File _managedFile(Directory support, String relativePath) {
    if (!AppCustomSkinConfig.isManagedAssetPath(relativePath)) {
      throw ArgumentError.value(relativePath, 'relativePath', '非法托管资源路径');
    }
    return File(p.joinAll(<String>[support.path, ...relativePath.split('/')]));
  }
}

bool _isValidRevision(String value) {
  return RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_-]{0,95}$').hasMatch(value);
}

Future<({int width, int height})> _decodeImageInfo(Uint8List bytes) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? decoded;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    codec = await descriptor.instantiateCodec();
    if (codec.frameCount != 1) {
      throw StateError('自定义皮肤派生图不是静态图片');
    }
    final frame = await codec.getNextFrame();
    decoded = frame.image;
    return (width: decoded.width, height: decoded.height);
  } finally {
    decoded?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

String _newRevision() {
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  final random = const Uuid().v4().replaceAll('-', '').substring(0, 12);
  return '${timestamp}_$random';
}
