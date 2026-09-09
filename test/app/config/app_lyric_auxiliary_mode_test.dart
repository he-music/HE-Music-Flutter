import 'package:flutter_test/flutter_test.dart';
import 'package:he_music_flutter/app/config/app_config_data_source.dart';
import 'package:he_music_flutter/app/config/app_config_state.dart';
import 'package:he_music_flutter/app/config/app_lyric_auxiliary_mode.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_document.dart';
import 'package:he_music_flutter/features/lyrics/domain/entities/lyric_line.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const both = LyricDocument(
    lines: [
      LyricLine(
        start: Duration.zero,
        text: 'original',
        translation: 'translation',
        romanization: 'roma',
      ),
    ],
  );
  const roma = LyricDocument(
    lines: [
      LyricLine(start: Duration.zero, text: 'original', romanization: 'roma'),
    ],
  );
  test(
    'preference cycles available content and fallback never mutates preference',
    () {
      const preference = AppLyricAuxiliaryMode.translation;
      expect(preference.effective(roma), AppLyricAuxiliaryMode.romanization);
      expect(preference.project(roma).lines.single.translation, 'roma');
      expect(preference.next(roma), AppLyricAuxiliaryMode.off);
      expect(preference.effective(both), AppLyricAuxiliaryMode.translation);
      expect(preference.next(both), AppLyricAuxiliaryMode.romanization);
      expect(
        AppLyricAuxiliaryMode.romanization.next(both),
        AppLyricAuxiliaryMode.off,
      );
      expect(
        AppLyricAuxiliaryMode.off.next(both),
        AppLyricAuxiliaryMode.translation,
      );
      final off = AppLyricAuxiliaryMode.off.project(both).lines.single;
      expect(off.text, 'original');
      expect(off.translation, isEmpty);
      expect(off.romanization, isEmpty);
    },
  );
  test('global preference persists across configuration reload', () async {
    SharedPreferences.setMockInitialValues({});
    const source = AppConfigDataSource();
    expect(
      (await source.load()).lyricAuxiliaryMode,
      AppLyricAuxiliaryMode.translation,
    );
    await source.save(
      AppConfigState.initial.copyWith(
        lyricAuxiliaryMode: AppLyricAuxiliaryMode.off,
      ),
    );
    expect((await source.load()).lyricAuxiliaryMode, AppLyricAuxiliaryMode.off);
  });
}
