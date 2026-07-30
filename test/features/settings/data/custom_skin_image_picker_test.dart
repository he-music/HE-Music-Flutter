import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/settings/data/custom_skin_image_picker.dart';
import 'package:image_picker/image_picker.dart' as picker;

void main() {
  test('mobile picker requests only the system gallery', () async {
    final imagePicker = _FakeImagePicker(picked: XFile('/mobile.jpg'));
    final port = PlatformCustomSkinImagePicker(
      imagePicker: imagePicker,
      platform: TargetPlatform.iOS,
    );

    final result = await port.pickImage();

    expect(result?.name, 'mobile.jpg');
    expect(imagePicker.requestedSource, picker.ImageSource.gallery);
  });

  test(
    'macOS picker uses the file selector and accepts cancellation',
    () async {
      List<XTypeGroup>? groups;
      final port = PlatformCustomSkinImagePicker(
        platform: TargetPlatform.macOS,
        fileSelector: (accepted) async {
          groups = accepted;
          return null;
        },
      );

      expect(await port.pickImage(), isNull);
      expect(groups, hasLength(1));
      expect(groups!.single.extensions, containsAll(<String>['jpg', 'heic']));
    },
  );

  test('Android lost data returns the recovered image', () async {
    final imagePicker = _FakeImagePicker(
      lost: picker.LostDataResponse(
        file: XFile('/recovered.png'),
        type: picker.RetrieveType.image,
      ),
    );
    final port = PlatformCustomSkinImagePicker(
      imagePicker: imagePicker,
      platform: TargetPlatform.android,
    );

    expect((await port.recoverLostImage())?.name, 'recovered.png');
  });
}

class _FakeImagePicker extends picker.ImagePicker {
  _FakeImagePicker({this.picked, picker.LostDataResponse? lost})
    : lost = lost ?? picker.LostDataResponse.empty();

  final XFile? picked;
  final picker.LostDataResponse lost;
  picker.ImageSource? requestedSource;

  @override
  Future<XFile?> pickImage({
    required picker.ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    picker.CameraDevice preferredCameraDevice = picker.CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    requestedSource = source;
    return picked;
  }

  @override
  Future<picker.LostDataResponse> retrieveLostData() async => lost;
}
