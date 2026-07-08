import 'package:flutter/material.dart';

import 'overlay_lyrics_window.dart';

class OverlayLyricsApp extends StatelessWidget {
  const OverlayLyricsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const OverlayLyricsWindow(),
    );
  }
}
