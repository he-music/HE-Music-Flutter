import 'package:just_audio/just_audio.dart';

const heAudioUserAgent =
    'Mozilla/5.0 (Linux; Android 13; Pixel 6) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

AudioPlayer createHeAudioPlayer() {
  // 仅为 User-Agent 启动本地代理会在 macOS release 沙箱下触发 localhost 绑定失败。
  return AudioPlayer(
    userAgent: heAudioUserAgent,
    useProxyForRequestHeaders: false,
  );
}
