import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/features/download/presentation/widgets/download_quality_sheet.dart';
import 'package:he_music_flutter/features/player/domain/entities/player_quality_option.dart';
import 'package:he_music_flutter/shared/models/he_music_models.dart';

void main() {
  test(
    'build download quality options reverses quality choices and deduplicates',
    () {
      final qualities = buildDownloadQualityOptions(
        links: const <LinkInfo>[
          LinkInfo(
            quality: 999,
            format: 'flac',
            size: '123456789',
            url: 'https://example.com/song.flac',
            name: 'FLAC',
          ),
          LinkInfo(
            quality: 320,
            format: 'mp3',
            size: '12345678',
            url: 'https://example.com/song.mp3',
            name: '320MP3',
          ),
          LinkInfo(
            quality: 320,
            format: 'mp3',
            size: '12345678',
            url: 'https://example.com/song-dup.mp3',
            name: '320MP3',
          ),
          LinkInfo(
            quality: 128,
            format: 'mp3',
            size: '0',
            url: '',
            name: '128MP3',
          ),
        ],
        qualityDescriptions: const <String, String>{
          'FLAC': '无损音质',
          '320MP3': '高码率',
        },
      );

      expect(qualities, hasLength(3));
      expect(qualities.first.name, '128MP3');
      expect(qualities.first.url, isEmpty);
      expect(qualities[1].name, '320MP3');
      expect(qualities.last.name, 'FLAC');
      expect(qualities.last.description, '无损音质');
    },
  );

  testWidgets(
    'download quality sheet renders qualities and returns selection',
    (tester) async {
      PlayerQualityOption? selected;
      const qualities = <PlayerQualityOption>[
        PlayerQualityOption(
          name: 'FLAC',
          quality: 999,
          format: 'flac',
          url: 'https://example.com/song.flac',
          description: '无损音质',
          sizeBytes: 123456789,
        ),
        PlayerQualityOption(
          name: '320MP3',
          quality: 320,
          format: 'mp3',
          url: 'https://example.com/song.mp3',
          sizeBytes: 12345678,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: FilledButton(
                  onPressed: () async {
                    selected = await showDownloadQualitySheet(
                      context: context,
                      qualities: qualities,
                      selectedQualityName: 'FLAC',
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Choose Quality'), findsOneWidget);
      expect(find.text('FLAC · 无损音质'), findsOneWidget);
      expect(find.text('320MP3'), findsOneWidget);
      expect(find.text('flac · 118 MB'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      await tester.tap(find.text('320MP3'));
      await tester.pumpAndSettle();

      expect(selected?.name, '320MP3');
    },
  );
}
