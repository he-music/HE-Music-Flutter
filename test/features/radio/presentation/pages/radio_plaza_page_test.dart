import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/online/domain/entities/online_platform.dart';
import 'package:he_music_flutter/features/online/presentation/providers/online_providers.dart';
import 'package:he_music_flutter/features/radio/presentation/pages/radio_plaza_page.dart';
import 'package:he_music_flutter/shared/widgets/plaza_loading_skeleton.dart';

void main() {
  testWidgets('电台广场首次加载应显示平台、分组和内容骨架', (tester) async {
    final platformsCompleter = Completer<List<OnlinePlatform>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onlinePlatformsProvider.overrideWith(
            () => _TestOnlinePlatformsController(platformsCompleter.future),
          ),
        ],
        child: const MaterialApp(home: RadioPlazaPage()),
      ),
    );
    await tester.pump();

    expect(find.byType(PlazaPlatformTabsSkeleton), findsNWidgets(2));
    expect(find.byType(PlazaGridSkeleton), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    platformsCompleter.complete(const <OnlinePlatform>[]);
    await tester.pumpAndSettle();
  });
}

class _TestOnlinePlatformsController extends OnlinePlatformsController {
  _TestOnlinePlatformsController(this.platformsFuture);

  final Future<List<OnlinePlatform>> platformsFuture;

  @override
  Future<List<OnlinePlatform>> build() => platformsFuture;
}
