import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_skin_models.dart';

sealed class AppSkinAssetLoadResult {
  const AppSkinAssetLoadResult();
}

final class AppSkinAssetLoadSuccess extends AppSkinAssetLoadResult {
  const AppSkinAssetLoadSuccess(this.bytes);

  final ByteData bytes;
}

final class AppSkinAssetLoadFailure extends AppSkinAssetLoadResult {
  const AppSkinAssetLoadFailure(this.error, [this.stackTrace]);

  final Object error;
  final StackTrace? stackTrace;
}

abstract interface class AppSkinAssetResolver {
  Future<AppSkinAssetLoadResult> load(AppSkinAssetDescriptor descriptor);
}

class BundledAppSkinAssetResolver implements AppSkinAssetResolver {
  BundledAppSkinAssetResolver({
    AssetBundle? bundle,
    Future<Directory> Function()? applicationSupportDirectory,
  }) : _bundle = bundle ?? rootBundle,
       _applicationSupportDirectory =
           applicationSupportDirectory ?? getApplicationSupportDirectory;

  final AssetBundle _bundle;
  final Future<Directory> Function() _applicationSupportDirectory;

  @override
  Future<AppSkinAssetLoadResult> load(AppSkinAssetDescriptor descriptor) async {
    if (!descriptor.isValid) {
      return AppSkinAssetLoadFailure(
        ArgumentError.value(descriptor.path, 'path', '非法皮肤资源路径'),
      );
    }
    try {
      final bytes = switch (descriptor.source) {
        AppSkinAssetSource.bundled => await _bundle.load(descriptor.path),
        AppSkinAssetSource.applicationSupport => await _loadManagedFile(
          descriptor.path,
        ),
      };
      return AppSkinAssetLoadSuccess(bytes);
    } catch (error, stackTrace) {
      return AppSkinAssetLoadFailure(error, stackTrace);
    }
  }

  Future<ByteData> _loadManagedFile(String relativePath) async {
    final root = await _applicationSupportDirectory();
    final file = File(
      p.joinAll(<String>[root.path, ...relativePath.split('/')]),
    );
    final bytes = await file.readAsBytes();
    return ByteData.sublistView(bytes);
  }
}
