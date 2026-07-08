import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/shared/widgets/app_network_image.dart';

void main() {
  group('AppNetworkImage', () {
    testWidgets('空 URL 时显示 fallback', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AppNetworkImage(
            url: '  ',
            width: 48,
            height: 48,
            fallback: Icon(Icons.music_note_rounded),
          ),
        ),
      );

      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('请求失败时显示 fallback', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AppNetworkImage(
            url: 'https://example.invalid/cover.png',
            width: 48,
            height: 48,
            fallback: Icon(Icons.music_note_rounded),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    });
  });

  group('AppNetworkAvatar', () {
    testWidgets('空 URL 时显示 fallback 图标', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const AppNetworkAvatar(
            imageUrl: '',
            radius: 18,
            fallbackIcon: Icons.person_rounded,
          ),
        ),
      );

      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
    });
  });
}

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}
