import 'dart:developer' as dev;
import 'dart:io' show Platform;

import 'package:flutter_overlay_window/flutter_overlay_window.dart';

import '../../../app/config/app_config_state.dart';
import '../../../app/config/app_lyric_highlight_color.dart';
import '../../../app/config/app_lyric_highlight_mode.dart';
import '../../lyrics/domain/entities/lyric_document.dart';
import '../data/overlay_message.dart';
import '../domain/services/overlay_channel_service.dart';

class OverlayLyricsService implements OverlayChannelService {
  Duration _lastSentPosition = Duration.zero;
  DateTime _lastSentTime = DateTime.fromMillisecondsSinceEpoch(0);

  static const _overlayHeight = 500;
  static const _positionThrottle = Duration(milliseconds: 100);
  static final bool _isSupportedPlatform = Platform.isAndroid;

  @override
  Stream<OverlayMessage> get overlayToMainMessages {
    if (!_isSupportedPlatform) return const Stream<OverlayMessage>.empty();
    return FlutterOverlayWindow.overlayListener
        .where((data) => data is Map)
        .map(
          (data) =>
              OverlayMessage.fromJson(Map<String, dynamic>.from(data as Map)),
        );
  }

  @override
  Future<bool> isPermissionGranted() {
    if (!_isSupportedPlatform) return Future.value(false);
    return FlutterOverlayWindow.isPermissionGranted();
  }

  @override
  Future<bool?> requestPermission() {
    if (!_isSupportedPlatform) return Future.value(false);
    return FlutterOverlayWindow.requestPermission();
  }

  @override
  Future<bool> isActive() {
    if (!_isSupportedPlatform) return Future.value(false);
    return FlutterOverlayWindow.isActive();
  }

  @override
  Future<void> open() async {
    if (!_isSupportedPlatform) return;
    final granted = await isPermissionGranted();
    if (!granted) {
      final result = await requestPermission();
      if (result != true) return;
    }
    await FlutterOverlayWindow.showOverlay(
      height: _overlayHeight,
      width: WindowSize.matchParent,
      alignment: OverlayAlignment.center,
      enableDrag: true,
      positionGravity: PositionGravity.auto,
      flag: OverlayFlag.defaultFlag,
      overlayTitle: 'HE-Music 歌词',
      overlayContent: '桌面歌词已开启',
    );
  }

  @override
  Future<void> close() {
    if (!_isSupportedPlatform) return Future<void>.value();
    return FlutterOverlayWindow.closeOverlay();
  }

  @override
  Future<void> lock() async {
    dev.log('lock() called', name: 'OverlayLyrics');
    await sendLockState(true);
  }

  @override
  Future<void> unlock() async {
    dev.log('unlock() called', name: 'OverlayLyrics');
    await sendLockState(false);
  }

  Future<void> sendLockState(bool locked) async {
    if (!_isSupportedPlatform) return;
    await FlutterOverlayWindow.shareData(
      OverlayLockStateMessage(locked).toJson(),
    );
  }

  @override
  Future<void> sendDocument(
    LyricDocument document,
    AppConfigState config, {
    int? autoHighlightColorValue,
  }) async {
    if (!_isSupportedPlatform) return;
    final color = resolveOverlayLyricHighlightColor(
      config,
      autoHighlightColorValue: autoHighlightColorValue,
    );
    await FlutterOverlayWindow.shareData(
      OverlayLyricDocMessage(document).toJson(),
    );
    await FlutterOverlayWindow.shareData(
      OverlayStyleUpdateMessage(
        highlightColorValue: color,
        fontPresetIndex: config.lyricFontPreset.index,
        enableWordByWord: config.enableWordByWordLyric,
      ).toJson(),
    );
  }

  @override
  Future<void> sendPosition(Duration position) async {
    if (!_isSupportedPlatform) return;
    final now = DateTime.now();
    if (now.difference(_lastSentTime) < _positionThrottle &&
        position == _lastSentPosition) {
      return;
    }
    _lastSentPosition = position;
    _lastSentTime = now;
    await FlutterOverlayWindow.shareData(
      OverlayPositionMessage(position.inMilliseconds).toJson(),
    );
  }

  @override
  Future<void> sendTrackChanged({
    required String title,
    required String artist,
  }) async {
    if (!_isSupportedPlatform) return;
    await FlutterOverlayWindow.shareData(
      OverlayTrackChangedMessage(title: title, artist: artist).toJson(),
    );
  }

  @override
  Future<void> sendStyleUpdate(
    AppConfigState config, {
    int? autoHighlightColorValue,
  }) async {
    if (!_isSupportedPlatform) return;
    final color = resolveOverlayLyricHighlightColor(
      config,
      autoHighlightColorValue: autoHighlightColorValue,
    );
    await FlutterOverlayWindow.shareData(
      OverlayStyleUpdateMessage(
        highlightColorValue: color,
        fontPresetIndex: config.lyricFontPreset.index,
        enableWordByWord: config.enableWordByWordLyric,
      ).toJson(),
    );
  }

  @override
  Future<void> sendClose() async {
    if (!_isSupportedPlatform) return;
    await FlutterOverlayWindow.shareData(const OverlayCloseMessage().toJson());
  }
}

int resolveOverlayLyricHighlightColor(
  AppConfigState config, {
  int? autoHighlightColorValue,
}) {
  return switch (config.lyricHighlightMode) {
    AppLyricHighlightMode.preset =>
      config.lyricHighlightPreset.color.toARGB32(),
    AppLyricHighlightMode.custom =>
      config.lyricHighlightCustomColor ??
          AppLyricHighlightColor.sky.color.toARGB32(),
    AppLyricHighlightMode.auto =>
      autoHighlightColorValue ?? AppLyricHighlightColor.sky.color.toARGB32(),
  };
}
