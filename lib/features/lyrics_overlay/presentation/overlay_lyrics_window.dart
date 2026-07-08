import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lyric/core/lyric_model.dart' as flm;
import 'package:flutter_lyric/core/lyric_style.dart';
import 'package:flutter_lyric/flutter_lyric.dart' as fl;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../lyrics/domain/entities/lyric_document.dart';
import '../../lyrics/domain/entities/lyric_line.dart' as domain;
import '../data/overlay_message.dart';

class OverlayLyricsWindow extends StatefulWidget {
  const OverlayLyricsWindow({super.key});

  @override
  State<OverlayLyricsWindow> createState() => _OverlayLyricsWindowState();
}

class _OverlayLyricsWindowState extends State<OverlayLyricsWindow> {
  final _controller = fl.LyricController();

  LyricDocument? _document;
  int _highlightColorValue = 0xFF4FC3F7;
  int _fontPresetIndex = 1;
  bool _enableWordByWord = false;
  bool _locked = false;
  String? _loadedKey;

  StreamSubscription<dynamic>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = FlutterOverlayWindow.overlayListener.listen(
      _onMessage,
      onError: (e) {}, // 静默忽略消息解析错误，防止 overlay 进程崩溃
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onMessage(dynamic data) {
    if (data is! Map) return;
    final OverlayMessage msg;
    try {
      msg = OverlayMessage.fromJson(Map<String, dynamic>.from(data));
    } catch (_) {
      return;
    }
    switch (msg) {
      case OverlayLyricDocMessage(:final document):
        setState(() {
          _document = document;
          _loadDocumentIfNeeded();
        });
      case OverlayPositionMessage(:final positionMs):
        _controller.setProgress(
          Duration(milliseconds: positionMs) +
              const Duration(milliseconds: 200),
        );
      case OverlayTrackChangedMessage():
        break;
      case OverlayStyleUpdateMessage(
        :final highlightColorValue,
        :final fontPresetIndex,
        :final enableWordByWord,
      ):
        setState(() {
          _highlightColorValue = highlightColorValue;
          _fontPresetIndex = fontPresetIndex;
          _enableWordByWord = enableWordByWord;
          _loadedKey = null;
        });
      case OverlayLockStateMessage(:final locked):
        _applyLock(locked);
        setState(() {
          _locked = locked;
        });
      case OverlayCloseMessage():
        FlutterOverlayWindow.closeOverlay();
    }
  }

  Future<void> _applyLock(bool locked) async {
    await FlutterOverlayWindow.updateFlag(
      locked ? OverlayFlag.clickThrough : OverlayFlag.defaultFlag,
    );
  }

  Future<void> _sendClose() async {
    final prefs = await SharedPreferences.getInstance();
    unawaited(prefs.setBool('app_config.enable_desktop_lyric', false));
    unawaited(
      FlutterOverlayWindow.shareData(const OverlayCloseMessage().toJson()),
    );
    FlutterOverlayWindow.closeOverlay();
  }

  Future<void> _toggleLock() async {
    final newLocked = !_locked;
    final prefs = await SharedPreferences.getInstance();
    unawaited(prefs.setBool('app_config.enable_desktop_lyric_lock', newLocked));
    unawaited(
      FlutterOverlayWindow.shareData(
        OverlayLockStateMessage(newLocked).toJson(),
      ),
    );
    _applyLock(newLocked);
    setState(() => _locked = newLocked);
  }

  void _loadDocumentIfNeeded() {
    final document = _document;
    if (document == null || document.isEmpty) return;
    final key =
        '${document.offset}:${document.lines.length}:$_enableWordByWord';
    if (_loadedKey == key) return;
    _loadedKey = key;
    _controller.loadLyricModel(_buildLyricModel(document));
  }

  flm.LyricModel _buildLyricModel(LyricDocument doc) {
    return flm.LyricModel(
      tags: <String, String>{'offset': doc.offset.toString()},
      lines: doc.lines
          .map(
            (line) => flm.LyricLine(
              start: line.start,
              end: line.end,
              text: line.text,
              translation: _translationText(line),
              words: !_enableWordByWord || line.tokens.isEmpty
                  ? null
                  : line.tokens
                        .map(
                          (t) => flm.LyricWord(
                            text: t.text,
                            start: line.start + t.startOffset,
                            end: line.start + t.endOffset,
                          ),
                        )
                        .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  String? _translationText(domain.LyricLine line) {
    final t = line.translation.trim();
    if (t.isNotEmpty) return t;
    final r = line.romanization.trim();
    return r.isNotEmpty ? r : null;
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;
    final sizes = _resolveFontSizes();
    final highlightColor = Color(_highlightColorValue);

    final style = LyricStyle(
      textStyle: TextStyle(fontSize: sizes.$1, color: Colors.white54),
      activeStyle: TextStyle(
        fontSize: sizes.$2,
        color: Colors.white,
        fontWeight: FontWeight.w500,
      ),
      translationStyle: TextStyle(fontSize: sizes.$3, color: Colors.white54),
      translationActiveColor: Colors.white,
      lineTextAlign: TextAlign.center,
      lineGap: 12,
      translationLineGap: 4,
      contentAlignment: CrossAxisAlignment.center,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      selectionAnchorPosition: 0.5,
      fadeRange: FadeRange(top: 30, bottom: 30),
      selectedColor: Colors.white,
      selectedTranslationColor: Colors.white,
      scrollDuration: const Duration(milliseconds: 240),
      selectionAlignment: MainAxisAlignment.center,
      selectionAutoResumeDuration: const Duration(milliseconds: 320),
      activeAutoResumeDuration: const Duration(milliseconds: 3000),
      enableSwitchAnimation: false,
      selectionAutoResumeMode: SelectionAutoResumeMode.neverResume,
      activeHighlightColor: highlightColor,
      disableTouchEvent: true,
    );

    return Material(
      color: Colors.black.withValues(alpha: _locked ? 0.0 : 0.3),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          IgnorePointer(
            ignoring: _locked,
            child: Opacity(
              opacity: _locked ? 0.0 : 1.0,
              child: _TitleBar(
                locked: _locked,
                onClose: _sendClose,
                onToggleLock: _toggleLock,
              ),
            ),
          ),
          Expanded(
            child: document == null || document.isEmpty
                ? const Center(
                    child: Text(
                      '暂无歌词',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  )
                : fl.LyricView(
                    controller: _controller,
                    style: style,
                    width: double.infinity,
                    height: double.infinity,
                  ),
          ),
        ],
      ),
    );
  }

  (double inactive, double active, double translation) _resolveFontSizes() {
    return switch (_fontPresetIndex) {
      0 => (12.0, 16.0, 9.0),
      2 => (16.0, 22.0, 12.0),
      _ => (14.0, 18.0, 10.0),
    };
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.locked,
    required this.onClose,
    required this.onToggleLock,
  });

  final bool locked;
  final VoidCallback onClose;
  final VoidCallback onToggleLock;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: onToggleLock,
            child: Icon(
              locked ? Icons.lock : Icons.lock_open,
              color: Colors.white54,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close, color: Colors.white54, size: 16),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
