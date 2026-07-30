import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart' as picker;

abstract interface class CustomSkinImagePicker {
  Future<XFile?> pickImage();

  Future<XFile?> recoverLostImage();
}

typedef CustomSkinFileSelector =
    Future<XFile?> Function(List<XTypeGroup> acceptedTypeGroups);

class PlatformCustomSkinImagePicker implements CustomSkinImagePicker {
  PlatformCustomSkinImagePicker({
    picker.ImagePicker? imagePicker,
    CustomSkinFileSelector? fileSelector,
    TargetPlatform? platform,
  }) : _imagePicker = imagePicker ?? picker.ImagePicker(),
       _fileSelector = fileSelector ?? _selectFile,
       _platform = platform ?? defaultTargetPlatform;

  static const XTypeGroup _images = XTypeGroup(
    label: 'Images',
    extensions: <String>['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'],
    mimeTypes: <String>[
      'image/jpeg',
      'image/png',
      'image/webp',
      'image/heic',
      'image/heif',
    ],
  );

  final picker.ImagePicker _imagePicker;
  final CustomSkinFileSelector _fileSelector;
  final TargetPlatform _platform;

  @override
  Future<XFile?> pickImage() {
    return switch (_platform) {
      TargetPlatform.android || TargetPlatform.iOS => _imagePicker.pickImage(
        source: picker.ImageSource.gallery,
      ),
      TargetPlatform.macOS => _fileSelector(const <XTypeGroup>[_images]),
      _ => Future<XFile?>.error(UnsupportedError('当前平台不支持选择自定义皮肤图片')),
    };
  }

  @override
  Future<XFile?> recoverLostImage() async {
    if (_platform != TargetPlatform.android) {
      return null;
    }
    final response = await _imagePicker.retrieveLostData();
    if (response.isEmpty) {
      return null;
    }
    final exception = response.exception;
    if (exception != null) {
      throw exception;
    }
    final files = response.files;
    if (files != null && files.isNotEmpty) {
      return files.first;
    }
    return response.file;
  }
}

Future<XFile?> _selectFile(List<XTypeGroup> acceptedTypeGroups) {
  return openFile(acceptedTypeGroups: acceptedTypeGroups);
}
