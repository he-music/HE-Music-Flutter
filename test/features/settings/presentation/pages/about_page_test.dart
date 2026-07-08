import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/settings/presentation/pages/about_page.dart';
import 'package:he_music_flutter/features/update/domain/entities/update_current_app_info.dart';
import 'package:he_music_flutter/features/update/presentation/providers/update_providers.dart';

void main() {
  testWidgets('about page shows centered logo section', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentAppInfoProvider.overrideWith(
            (ref) async => const UpdateCurrentAppInfo(
              appName: 'HE Music',
              version: '1.0.0',
              buildNumber: '1',
            ),
          ),
        ],
        child: const MaterialApp(home: AboutPage()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('about-logo')), findsOneWidget);
  });
}
