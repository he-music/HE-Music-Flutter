import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'config/app_environment.dart';
import '../core/audio/he_audio_handler.dart';
import 'app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await AppEnvironment.initialize();
  _setupHttpOverrides();
  await initHeAudioHandler();
  await _enableSystemStatusBar();
  runApp(const ProviderScope(child: HeMusicApp()));
}

Future<void> _enableSystemStatusBar() async {
  if (kIsWeb) {
    return;
  }
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
}

void _setupHttpOverrides() {
  if (kIsWeb) {
    return;
  }
  HttpOverrides.global = _AppHttpOverrides();
}

class _AppHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.userAgent =
        'Mozilla/5.0 (Linux; Android 13; Pixel 6) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';
    return client;
  }
}
