import 'package:flutter/material.dart';

import 'app/bootstrap.dart';
import 'features/lyrics_overlay/presentation/overlay_lyrics_window.dart';

Future<void> main() async {
  await bootstrap();
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const OverlayLyricsWindow(),
    ),
  );
}
