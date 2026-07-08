import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';

import '../../app/config/app_config_controller.dart';
import '../../app/i18n/app_i18n.dart';

Future<void> showDetailCoverPreview({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String imageUrl,
}) async {
  final config = ref.read(appConfigProvider);
  final normalizedUrl = imageUrl.trim();
  if (normalizedUrl.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppI18n.t(config, 'cover.preview.empty'))),
    );
    return;
  }
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'detail-cover-preview',
    barrierColor: const Color.fromRGBO(0, 0, 0, 0.92),
    pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Center(
                  child: Image.network(
                    normalizedUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }
                      return const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white70,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              top: 8,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(0, 0, 0, 0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PreviewAction(
                    icon: Icons.download_rounded,
                    tooltip: AppI18n.t(config, 'cover.preview.save'),
                    onTap: () async {
                      if (!context.mounted) {
                        return;
                      }
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            AppI18n.t(config, 'cover.preview.saving'),
                          ),
                        ),
                      );
                      final success = await _saveCoverToGallery(
                        imageUrl: normalizedUrl,
                        title: title,
                      );
                      if (!context.mounted) {
                        return;
                      }
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? AppI18n.t(config, 'cover.preview.saved')
                                : AppI18n.t(
                                    config,
                                    'cover.preview.save_failed',
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _PreviewAction(
                    icon: Icons.close_rounded,
                    tooltip: AppI18n.t(config, 'cover.preview.close'),
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PreviewAction extends StatelessWidget {
  const _PreviewAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color.fromRGBO(0, 0, 0, 0.35),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

Future<bool> _saveCoverToGallery({
  required String imageUrl,
  required String title,
}) async {
  final hasPermission = await _requestGalleryPermission();
  if (!hasPermission) {
    return false;
  }

  try {
    final response = await Dio().get<List<int>>(
      imageUrl,
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      return false;
    }

    final result = await SaverGallery.saveImage(
      Uint8List.fromList(bytes),
      quality: 100,
      fileName: _buildCoverFileName(title),
      androidRelativePath: 'Pictures/HE Music/covers',
      skipIfExists: false,
    );
    return result.isSuccess;
  } catch (_) {
    return false;
  }
}

Future<bool> _requestGalleryPermission() async {
  if (Platform.isIOS) {
    final status = await Permission.photosAddOnly.request();
    return status.isGranted || status.isLimited;
  }

  if (Platform.isAndroid) {
    await Permission.storage.request();
    return true;
  }

  return false;
}

String _buildCoverFileName(String title) {
  final normalized = title.trim().isEmpty ? 'cover' : title.trim();
  final sanitized = normalized.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  return '${sanitized}_cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
}
