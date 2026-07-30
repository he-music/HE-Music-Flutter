import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_controller.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_custom_skin_config.dart';
import 'package:he_music_flutter/app/theme/skin/app_custom_skin_store.dart';
import 'package:he_music_flutter/features/settings/data/custom_skin_image_picker.dart';
import 'package:he_music_flutter/features/settings/data/custom_skin_image_processor.dart';
import 'package:he_music_flutter/features/settings/presentation/controllers/custom_skin_editor_controller.dart';
import 'package:image_picker/image_picker.dart' show XFile;

void main() {
  test('saved draft edits metadata without regenerating images', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_SavedAppConfigController.new),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      customSkinEditorControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final controller = container.read(
      customSkinEditorControllerProvider.notifier,
    );
    final initial = container.read(customSkinEditorControllerProvider).draft!;

    controller.swapBrightness();
    controller.selectSeed(0xFF654321);
    controller.setFocalPoint(0.4, -0.6);
    final edited = container.read(customSkinEditorControllerProvider);

    expect(edited.isDirty, isTrue);
    expect(edited.draft!.lightAssetPath, initial.darkAssetPath);
    expect(edited.draft!.darkAssetPath, initial.lightAssetPath);
    expect(edited.draft!.seedColor, 0xFF654321);
    expect(edited.draft!.focalX, 0.4);
    expect(edited.draft!.focalY, -0.6);
    expect(edited.draft!.stagedRevision, isNull);
  });

  test('a late first selection cannot replace the newer draft', () async {
    final picker = _QueuedPicker(<XFile>[XFile('/a.png'), XFile('/b.png')]);
    final processor = _ControlledProcessor();
    final store = _FakeStore();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_EmptyAppConfigController.new),
        customSkinImagePickerProvider.overrideWithValue(picker),
        customSkinImageProcessorProvider.overrideWithValue(processor),
        appCustomSkinStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      customSkinEditorControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final controller = container.read(
      customSkinEditorControllerProvider.notifier,
    );

    final first = controller.chooseImage();
    await Future<void>.delayed(Duration.zero);
    final second = controller.chooseImage();
    await Future<void>.delayed(Duration.zero);
    processor.complete('/b.png', _processed(0xFF222222));
    await second;
    processor.complete('/a.png', _processed(0xFF111111));
    await first;

    final draft = container.read(customSkinEditorControllerProvider).draft!;
    expect(draft.candidateColors, <int>[0xFF222222]);
    expect(draft.revision, 'revision_4280427042');
  });

  test(
    'an earlier picker result cannot replace a later picker result',
    () async {
      final picker = _ControlledPicker();
      final processor = _ControlledProcessor();
      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWith(_EmptyAppConfigController.new),
          customSkinImagePickerProvider.overrideWithValue(picker),
          customSkinImageProcessorProvider.overrideWithValue(processor),
          appCustomSkinStoreProvider.overrideWithValue(_FakeStore()),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        customSkinEditorControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final controller = container.read(
        customSkinEditorControllerProvider.notifier,
      );

      final first = controller.chooseImage();
      final second = controller.chooseImage();
      picker.complete(1, XFile('/b.png'));
      await Future<void>.delayed(Duration.zero);
      processor.complete('/b.png', _processed(0xFF222222));
      await second;
      picker.complete(0, XFile('/a.png'));
      await Future<void>.delayed(Duration.zero);
      processor.completeIfPending('/a.png', _processed(0xFF111111));
      await first;

      final draft = container.read(customSkinEditorControllerProvider).draft!;
      expect(draft.candidateColors, <int>[0xFF222222]);
      expect(draft.revision, 'revision_4280427042');
    },
  );

  test('failed delete keeps a staged replacement available', () async {
    final processor = _ControlledProcessor();
    final store = _FakeStore();
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWith(_FailingDeleteAppConfigController.new),
        customSkinImagePickerProvider.overrideWithValue(
          _QueuedPicker(<XFile>[XFile('/replacement.png')]),
        ),
        customSkinImageProcessorProvider.overrideWithValue(processor),
        appCustomSkinStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      customSkinEditorControllerProvider,
      (_, _) {},
    );
    addTearDown(subscription.close);
    final controller = container.read(
      customSkinEditorControllerProvider.notifier,
    );

    final replacing = controller.chooseImage();
    await Future<void>.delayed(Duration.zero);
    processor.complete('/replacement.png', _processed(0xFF222222));
    await replacing;

    expect(await controller.delete(), isFalse);
    final state = container.read(customSkinEditorControllerProvider);
    expect(state.draft?.stagedRevision, isNotNull);
    expect(store.discardedRevisions, isEmpty);
  });
}

class _SavedAppConfigController extends AppConfigController {
  @override
  AppConfigState build() =>
      AppConfigState.initial.copyWith(customSkinConfig: _savedConfig());
}

class _EmptyAppConfigController extends AppConfigController {
  @override
  AppConfigState build() => AppConfigState.initial;
}

class _FailingDeleteAppConfigController extends _SavedAppConfigController {
  @override
  Future<void> deleteCustomSkin() async {
    throw StateError('delete failed');
  }
}

class _QueuedPicker implements CustomSkinImagePicker {
  _QueuedPicker(this.files);

  final List<XFile> files;
  var _index = 0;

  @override
  Future<XFile?> pickImage() async => files[_index++];

  @override
  Future<XFile?> recoverLostImage() async => null;
}

class _ControlledPicker implements CustomSkinImagePicker {
  final List<Completer<XFile?>> _pending = <Completer<XFile?>>[];

  @override
  Future<XFile?> pickImage() {
    final completer = Completer<XFile?>();
    _pending.add(completer);
    return completer.future;
  }

  void complete(int index, XFile? file) {
    _pending[index].complete(file);
  }

  @override
  Future<XFile?> recoverLostImage() async => null;
}

class _ControlledProcessor extends CustomSkinImageProcessor {
  final Map<String, Completer<CustomSkinProcessedImage>> _pending = {};

  @override
  Future<CustomSkinProcessedImage> process(XFile file) {
    return (_pending[file.path] ??= Completer<CustomSkinProcessedImage>())
        .future;
  }

  void complete(String name, CustomSkinProcessedImage value) {
    _pending[name]!.complete(value);
  }

  void completeIfPending(String name, CustomSkinProcessedImage value) {
    _pending[name]?.complete(value);
  }
}

class _FakeStore extends AppCustomSkinStore {
  _FakeStore()
    : super(applicationSupportDirectory: () async => Directory.systemTemp);

  @override
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
    return AppCustomSkinStagedRevision(
      revision: 'revision_${candidateColors.first}',
      fileExtension: fileExtension,
      lightBytes: lightBytes,
      darkBytes: darkBytes,
      candidateColors: candidateColors,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      outputWidth: outputWidth,
      outputHeight: outputHeight,
    );
  }

  final discardedRevisions = <String>[];

  @override
  Future<void> discardStaged(String revision) async {
    discardedRevisions.add(revision);
  }
}

CustomSkinProcessedImage _processed(int color) {
  return CustomSkinProcessedImage(
    lightBytes: Uint8List.fromList(const <int>[1]),
    darkBytes: Uint8List.fromList(const <int>[2]),
    fileExtension: 'jpg',
    candidateColors: <int>[color],
    sourceBrightness: CustomSkinImageBrightness.neutral,
    sourceWidth: 10,
    sourceHeight: 20,
    outputWidth: 10,
    outputHeight: 20,
  );
}

AppCustomSkinConfig _savedConfig() {
  return AppCustomSkinConfig(
    revision: 'revision_1',
    lightAssetPath: 'skins/custom_image/revision_1/wallpaper_light.jpg',
    darkAssetPath: 'skins/custom_image/revision_1/wallpaper_dark.jpg',
    candidateColors: const <int>[0xFF123456, 0xFF654321],
    seedColor: 0xFF123456,
    focalX: 0,
    focalY: 0,
    sourceWidth: 1200,
    sourceHeight: 1600,
  );
}
