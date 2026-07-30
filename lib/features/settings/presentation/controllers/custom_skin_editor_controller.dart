import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show XFile;

import '../../../../app/config/app_config_controller.dart';
import '../../../../app/config/app_custom_skin_config.dart';
import '../../../../app/theme/skin/app_custom_skin_store.dart';
import '../../../../app/theme/skin/app_skin_registry.dart';
import '../../data/custom_skin_image_picker.dart';
import '../../data/custom_skin_image_processor.dart';

enum CustomSkinEditorPhase { empty, processing, ready, saving, failure }

class CustomSkinEditorDraft {
  const CustomSkinEditorDraft({
    required this.revision,
    required this.lightAssetPath,
    required this.darkAssetPath,
    required this.candidateColors,
    required this.seedColor,
    required this.focalX,
    required this.focalY,
    required this.sourceWidth,
    required this.sourceHeight,
    this.lightPreviewBytes,
    this.darkPreviewBytes,
    this.stagedRevision,
  });

  factory CustomSkinEditorDraft.fromConfig(AppCustomSkinConfig config) {
    return CustomSkinEditorDraft(
      revision: config.revision,
      lightAssetPath: config.lightAssetPath,
      darkAssetPath: config.darkAssetPath,
      candidateColors: config.candidateColors,
      seedColor: config.seedColor,
      focalX: config.focalX,
      focalY: config.focalY,
      sourceWidth: config.sourceWidth,
      sourceHeight: config.sourceHeight,
    );
  }

  factory CustomSkinEditorDraft.fromStaged(AppCustomSkinStagedRevision staged) {
    return CustomSkinEditorDraft(
      revision: staged.revision,
      lightAssetPath: staged.lightAssetPath,
      darkAssetPath: staged.darkAssetPath,
      candidateColors: staged.candidateColors,
      seedColor: staged.candidateColors.first,
      focalX: 0,
      focalY: 0,
      sourceWidth: staged.sourceWidth,
      sourceHeight: staged.sourceHeight,
      lightPreviewBytes: staged.lightBytes,
      darkPreviewBytes: staged.darkBytes,
      stagedRevision: staged,
    );
  }

  final String revision;
  final String lightAssetPath;
  final String darkAssetPath;
  final List<int> candidateColors;
  final int seedColor;
  final double focalX;
  final double focalY;
  final int sourceWidth;
  final int sourceHeight;
  final Uint8List? lightPreviewBytes;
  final Uint8List? darkPreviewBytes;
  final AppCustomSkinStagedRevision? stagedRevision;

  AppCustomSkinConfig toConfig() {
    return AppCustomSkinConfig(
      revision: revision,
      lightAssetPath: lightAssetPath,
      darkAssetPath: darkAssetPath,
      candidateColors: candidateColors,
      seedColor: seedColor,
      focalX: focalX,
      focalY: focalY,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
    );
  }

  CustomSkinEditorDraft selectSeed(int value) {
    return CustomSkinEditorDraft(
      revision: revision,
      lightAssetPath: lightAssetPath,
      darkAssetPath: darkAssetPath,
      candidateColors: candidateColors,
      seedColor: value,
      focalX: focalX,
      focalY: focalY,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      lightPreviewBytes: lightPreviewBytes,
      darkPreviewBytes: darkPreviewBytes,
      stagedRevision: stagedRevision,
    );
  }

  CustomSkinEditorDraft moveFocus(double x, double y) {
    return CustomSkinEditorDraft(
      revision: revision,
      lightAssetPath: lightAssetPath,
      darkAssetPath: darkAssetPath,
      candidateColors: candidateColors,
      seedColor: seedColor,
      focalX: x.clamp(-1, 1),
      focalY: y.clamp(-1, 1),
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      lightPreviewBytes: lightPreviewBytes,
      darkPreviewBytes: darkPreviewBytes,
      stagedRevision: stagedRevision,
    );
  }

  CustomSkinEditorDraft swapBrightness() {
    return CustomSkinEditorDraft(
      revision: revision,
      lightAssetPath: darkAssetPath,
      darkAssetPath: lightAssetPath,
      candidateColors: candidateColors,
      seedColor: seedColor,
      focalX: focalX,
      focalY: focalY,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      lightPreviewBytes: darkPreviewBytes,
      darkPreviewBytes: lightPreviewBytes,
      stagedRevision: stagedRevision,
    );
  }
}

class CustomSkinEditorState {
  const CustomSkinEditorState({
    required this.phase,
    required this.originalConfig,
    this.draft,
    this.errorKey,
    this.errorVersion = 0,
  });

  final CustomSkinEditorPhase phase;
  final AppCustomSkinConfig? originalConfig;
  final CustomSkinEditorDraft? draft;
  final String? errorKey;
  final int errorVersion;

  bool get isDirty {
    final current = draft;
    if (current == null) {
      return false;
    }
    return current.toConfig() != originalConfig;
  }

  bool get canDelete => originalConfig != null;

  bool canApplyFor(String appliedSkinId) {
    return draft != null &&
        phase != CustomSkinEditorPhase.saving &&
        (isDirty || appliedSkinId != AppSkinRegistry.customImageId);
  }
}

class CustomSkinEditorController extends Notifier<CustomSkinEditorState> {
  var _generation = 0;
  var _initialized = false;
  String? _unpublishedRevision;

  @override
  CustomSkinEditorState build() {
    final config = ref.read(appConfigProvider).customSkinConfig;
    final store = ref.read(appCustomSkinStoreProvider);
    final draft = config == null
        ? null
        : CustomSkinEditorDraft.fromConfig(config);
    ref.onDispose(() {
      _generation++;
      final revision = _unpublishedRevision;
      if (revision != null) {
        unawaited(store.discardStaged(revision).catchError((_) {}));
      }
    });
    return CustomSkinEditorState(
      phase: draft == null
          ? CustomSkinEditorPhase.empty
          : CustomSkinEditorPhase.ready,
      originalConfig: config,
      draft: draft,
    );
  }

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    final generation = ++_generation;
    try {
      final recovered = await ref
          .read(customSkinImagePickerProvider)
          .recoverLostImage();
      if (!ref.mounted || generation != _generation || recovered == null) {
        return;
      }
      await _processImage(recovered, generation: generation);
    } catch (_) {
      if (ref.mounted && generation == _generation) {
        _setFailure('settings.skin.custom.error.pick');
      }
    }
  }

  Future<void> chooseImage() async {
    final generation = ++_generation;
    try {
      final selected = await ref
          .read(customSkinImagePickerProvider)
          .pickImage();
      if (!ref.mounted || generation != _generation) {
        return;
      }
      if (selected == null) {
        _restoreIdleState();
        return;
      }
      await _processImage(selected, generation: generation);
    } catch (_) {
      if (ref.mounted && generation == _generation) {
        _setFailure('settings.skin.custom.error.pick');
      }
    }
  }

  void selectSeed(int color) {
    final draft = state.draft;
    if (draft == null || !draft.candidateColors.contains(color)) {
      return;
    }
    _setReady(draft.selectSeed(color));
  }

  void setFocalPoint(double x, double y) {
    final draft = state.draft;
    if (draft == null) {
      return;
    }
    _setReady(draft.moveFocus(x, y));
  }

  void swapBrightness() {
    final draft = state.draft;
    if (draft == null) {
      return;
    }
    _setReady(draft.swapBrightness());
  }

  Future<bool> apply() async {
    final draft = state.draft;
    final appliedSkinId = ref.read(appConfigProvider).skinId;
    if (draft == null || !state.canApplyFor(appliedSkinId)) {
      return false;
    }
    if (!state.isDirty) {
      ref
          .read(appConfigProvider.notifier)
          .setSkinId(AppSkinRegistry.customImageId);
      return true;
    }
    state = CustomSkinEditorState(
      phase: CustomSkinEditorPhase.saving,
      originalConfig: state.originalConfig,
      draft: draft,
    );
    final staged = draft.stagedRevision;
    var published = false;
    try {
      if (staged != null) {
        await ref.read(appCustomSkinStoreProvider).publish(staged);
        published = true;
      }
      if (!ref.mounted) {
        if (published && staged != null) {
          await ref.read(appCustomSkinStoreProvider).restoreStaging(staged);
        }
        return false;
      }
      final config = draft.toConfig();
      await ref.read(appConfigProvider.notifier).applyCustomSkin(config);
      if (!ref.mounted) {
        return true;
      }
      _unpublishedRevision = null;
      state = CustomSkinEditorState(
        phase: CustomSkinEditorPhase.ready,
        originalConfig: config,
        draft: CustomSkinEditorDraft.fromConfig(config),
      );
      return true;
    } catch (_) {
      if (published && staged != null) {
        try {
          await ref.read(appCustomSkinStoreProvider).restoreStaging(staged);
        } catch (_) {
          _unpublishedRevision = null;
        }
      }
      if (ref.mounted) {
        _setFailure('settings.skin.custom.error.save', draft: draft);
      }
      return false;
    }
  }

  Future<bool> delete() async {
    if (!state.canDelete || state.phase == CustomSkinEditorPhase.saving) {
      return false;
    }
    final previous = state;
    state = CustomSkinEditorState(
      phase: CustomSkinEditorPhase.saving,
      originalConfig: previous.originalConfig,
      draft: previous.draft,
    );
    try {
      await ref.read(appConfigProvider.notifier).deleteCustomSkin();
      if (ref.mounted) {
        _unpublishedRevision = null;
        state = const CustomSkinEditorState(
          phase: CustomSkinEditorPhase.empty,
          originalConfig: null,
        );
      }
      return true;
    } catch (_) {
      if (ref.mounted) {
        final customStillExists =
            ref.read(appConfigProvider).customSkinConfig != null;
        if (customStillExists) {
          _setFailure(
            'settings.skin.custom.error.delete',
            draft: previous.draft,
          );
        } else {
          state = CustomSkinEditorState(
            phase: CustomSkinEditorPhase.failure,
            originalConfig: null,
            errorKey: 'settings.skin.custom.error.cleanup',
            errorVersion: previous.errorVersion + 1,
          );
        }
      }
      return false;
    }
  }

  Future<void> _processImage(XFile selected, {required int generation}) async {
    final previousDraft = state.draft;
    state = CustomSkinEditorState(
      phase: CustomSkinEditorPhase.processing,
      originalConfig: state.originalConfig,
      draft: previousDraft,
    );
    try {
      final processed = await ref
          .read(customSkinImageProcessorProvider)
          .process(selected);
      if (!ref.mounted || generation != _generation) {
        return;
      }
      final staged = await ref
          .read(appCustomSkinStoreProvider)
          .stage(
            lightBytes: processed.lightBytes,
            darkBytes: processed.darkBytes,
            fileExtension: processed.fileExtension,
            candidateColors: processed.candidateColors,
            sourceWidth: processed.sourceWidth,
            sourceHeight: processed.sourceHeight,
            outputWidth: processed.outputWidth,
            outputHeight: processed.outputHeight,
          );
      if (!ref.mounted || generation != _generation) {
        await ref
            .read(appCustomSkinStoreProvider)
            .discardStaged(staged.revision);
        return;
      }
      final previousRevision = _unpublishedRevision;
      _unpublishedRevision = staged.revision;
      _setReady(CustomSkinEditorDraft.fromStaged(staged));
      if (previousRevision != null && previousRevision != staged.revision) {
        unawaited(
          ref
              .read(appCustomSkinStoreProvider)
              .discardStaged(previousRevision)
              .catchError((_) {}),
        );
      }
    } on CustomSkinImageException catch (error) {
      if (ref.mounted && generation == _generation) {
        _setFailure(_errorKey(error.error), draft: previousDraft);
      }
    } catch (_) {
      if (ref.mounted && generation == _generation) {
        _setFailure(
          'settings.skin.custom.error.processing',
          draft: previousDraft,
        );
      }
    }
  }

  void _restoreIdleState() {
    final draft = state.draft;
    state = CustomSkinEditorState(
      phase: draft == null
          ? CustomSkinEditorPhase.empty
          : CustomSkinEditorPhase.ready,
      originalConfig: state.originalConfig,
      draft: draft,
      errorVersion: state.errorVersion,
    );
  }

  void _setReady(CustomSkinEditorDraft draft) {
    state = CustomSkinEditorState(
      phase: CustomSkinEditorPhase.ready,
      originalConfig: state.originalConfig,
      draft: draft,
      errorVersion: state.errorVersion,
    );
  }

  void _setFailure(String errorKey, {CustomSkinEditorDraft? draft}) {
    state = CustomSkinEditorState(
      phase: CustomSkinEditorPhase.failure,
      originalConfig: state.originalConfig,
      draft: draft ?? state.draft,
      errorKey: errorKey,
      errorVersion: state.errorVersion + 1,
    );
  }
}

String _errorKey(CustomSkinImageError error) {
  return switch (error) {
    CustomSkinImageError.fileTooLarge =>
      'settings.skin.custom.error.file_too_large',
    CustomSkinImageError.tooManyPixels =>
      'settings.skin.custom.error.too_many_pixels',
    CustomSkinImageError.animated => 'settings.skin.custom.error.animated',
    CustomSkinImageError.noVisiblePixels =>
      'settings.skin.custom.error.no_visible_pixels',
    CustomSkinImageError.unsupportedOrDamaged =>
      'settings.skin.custom.error.unsupported',
    CustomSkinImageError.processingFailed =>
      'settings.skin.custom.error.processing',
  };
}

final customSkinImagePickerProvider = Provider<CustomSkinImagePicker>((ref) {
  return PlatformCustomSkinImagePicker();
});

final customSkinImageProcessorProvider = Provider<CustomSkinImageProcessor>((
  ref,
) {
  return const CustomSkinImageProcessor();
});

final customSkinEditorControllerProvider =
    NotifierProvider.autoDispose<
      CustomSkinEditorController,
      CustomSkinEditorState
    >(CustomSkinEditorController.new);
