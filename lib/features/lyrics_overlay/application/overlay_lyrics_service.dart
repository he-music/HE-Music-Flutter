import 'dart:async';
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
  OverlayLyricsService({bool? isSupportedPlatform})
    : _isSupportedPlatform = isSupportedPlatform ?? Platform.isAndroid;

  final bool _isSupportedPlatform;
  Future<void> _windowOperation = Future<void>.value();
  Duration _lastSentPosition = Duration.zero;
  DateTime _lastSentTime = DateTime.fromMillisecondsSinceEpoch(0);

  static const _overlayHeight = 500;
  static const _positionThrottle = Duration(milliseconds: 100);

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
  Future<void> open() {
    if (!_isSupportedPlatform) return Future<void>.value();
    return _enqueueWindowOperation(_openWindow);
  }

  Future<void> _openWindow() async {
    if (await isActive()) return;
    final granted = await isPermissionGranted();
    if (!granted) {
      final result = await requestPermission();
      if (result != true) return;
    }
    final ready = Completer<void>();
    final subscription = FlutterOverlayWindow.overlayStatusListener.listen((
      showing,
    ) {
      if (showing && !ready.isCompleted) ready.complete();
    });
    try {
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
      // showOverlay 仅确认启动请求；窗口显示后通道才可用于同步状态和关闭。
      if (!await isActive()) {
        await ready.future.timeout(const Duration(seconds: 5));
      }
    } finally {
      await subscription.cancel();
    }
  }

  @override
  Future<void> close() {
    if (!_isSupportedPlatform) return Future<void>.value();
    return _enqueueWindowOperation(() async {
      if (!await isActive()) return;
      try {
        await FlutterOverlayWindow.closeOverlay().timeout(
          const Duration(seconds: 5),
        );
      } on TimeoutException {
        // 插件在窗口已由另一侧关闭时不返回结果，确认关闭后才视为完成。
        if (await isActive()) rethrow;
      }
    });
  }

  Future<void> _enqueueWindowOperation(Future<void> Function() operation) {
    final result = _windowOperation.then((_) => operation());
    // 单次失败交给调用者处理，不阻塞后续开启/关闭请求。
    _windowOperation = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return result;
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
