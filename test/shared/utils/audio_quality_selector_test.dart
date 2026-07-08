import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_online_audio_quality.dart';
import 'package:he_music_flutter/shared/utils/audio_quality_selector.dart';

void main() {
  group('inferOnlineAudioQualityBucket', () {
    test(
      'should infer lossless and hi-res quality buckets from name and format',
      () {
        expect(
          inferOnlineAudioQualityBucket(
            name: 'Hi-Res',
            format: 'flac',
            bitrate: 999,
          ),
          AppOnlineAudioQuality.hires,
        );
        expect(
          inferOnlineAudioQualityBucket(
            name: 'FLAC',
            format: 'flac',
            bitrate: 999,
          ),
          AppOnlineAudioQuality.flac,
        );
        expect(
          inferOnlineAudioQualityBucket(
            name: 'Dolby Atmos',
            format: 'ec3',
            bitrate: 999,
          ),
          AppOnlineAudioQuality.dolby,
        );
      },
    );

    test('should infer mp3 buckets from bitrate when name is generic', () {
      expect(
        inferOnlineAudioQualityBucket(
          name: 'Standard',
          format: 'mp3',
          bitrate: 320,
        ),
        AppOnlineAudioQuality.mp3320,
      );
      expect(
        inferOnlineAudioQualityBucket(
          name: 'Standard',
          format: 'mp3',
          bitrate: 192,
        ),
        AppOnlineAudioQuality.mp3192,
      );
      expect(
        inferOnlineAudioQualityBucket(
          name: 'Standard',
          format: 'mp3',
          bitrate: 128,
        ),
        AppOnlineAudioQuality.mp3128,
      );
    });
  });

  group('selectPreferredAudioQuality', () {
    const items = <_QualityItem>[
      _QualityItem(name: '128k', quality: 128, format: 'mp3'),
      _QualityItem(name: '320k', quality: 320, format: 'mp3'),
      _QualityItem(name: 'FLAC', quality: 999, format: 'flac'),
    ];

    test('should prefer last selected quality when preference is auto', () {
      final selected = selectPreferredAudioQuality(
        items,
        preference: AppOnlineAudioQuality.auto,
        lastSelectedQualityName: 'FLAC',
        nameOf: (_QualityItem item) => item.name,
        formatOf: (_QualityItem item) => item.format,
        bitrateOf: (_QualityItem item) => item.quality,
      );

      expect(selected?.name, 'FLAC');
    });

    test(
      'should fallback by configured priority when auto has no remembered value',
      () {
        final selected = selectPreferredAudioQuality(
          const <_QualityItem>[
            _QualityItem(name: '128k', quality: 128, format: 'mp3'),
            _QualityItem(name: '320k', quality: 320, format: 'mp3'),
            _QualityItem(name: 'FLAC', quality: 999, format: 'flac'),
          ],
          preference: AppOnlineAudioQuality.auto,
          lastSelectedQualityName: null,
          nameOf: (_QualityItem item) => item.name,
          formatOf: (_QualityItem item) => item.format,
          bitrateOf: (_QualityItem item) => item.quality,
        );

        expect(selected?.name, '320k');
      },
    );

    test('should prefer exact configured quality when not auto', () {
      final selected = selectPreferredAudioQuality(
        items,
        preference: AppOnlineAudioQuality.flac,
        lastSelectedQualityName: '320k',
        nameOf: (_QualityItem item) => item.name,
        formatOf: (_QualityItem item) => item.format,
        bitrateOf: (_QualityItem item) => item.quality,
      );

      expect(selected?.name, 'FLAC');
    });

    test('should fallback to first item when no preference matches', () {
      final selected = selectPreferredAudioQuality(
        const <_QualityItem>[
          _QualityItem(name: 'AAC', quality: 96, format: 'aac'),
          _QualityItem(name: 'OGG', quality: 96, format: 'ogg'),
        ],
        preference: AppOnlineAudioQuality.master,
        lastSelectedQualityName: null,
        nameOf: (_QualityItem item) => item.name,
        formatOf: (_QualityItem item) => item.format,
        bitrateOf: (_QualityItem item) => item.quality,
      );

      expect(selected?.name, 'AAC');
    });
  });
}

class _QualityItem {
  const _QualityItem({
    required this.name,
    required this.quality,
    required this.format,
  });

  final String name;
  final int quality;
  final String format;
}
