import 'package:flutter/services.dart';

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
  BundledAppSkinAssetResolver({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  @override
  Future<AppSkinAssetLoadResult> load(AppSkinAssetDescriptor descriptor) async {
    if (!descriptor.isValid) {
      return AppSkinAssetLoadFailure(
        ArgumentError.value(descriptor.path, 'path', '非法皮肤资源路径'),
      );
    }
    try {
      return AppSkinAssetLoadSuccess(await _bundle.load(descriptor.path));
    } catch (error, stackTrace) {
      return AppSkinAssetLoadFailure(error, stackTrace);
    }
  }
}
