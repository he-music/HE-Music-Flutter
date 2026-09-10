# Preview test fonts

- `Roboto-*.ttf` provides deterministic Latin text for skin golden tests.
- `DroidSansFallback-PreviewSubset.ttf` provides only the Chinese glyphs listed
  in `preview_cjk_glyphs.txt`. It is derived from Android Open Source Project's
  `DroidSansFallback.ttf` and is used only by tests.

Both font families are distributed under Apache License 2.0. The license text
is retained in `LICENSE.txt`.

Regenerate the CJK subset with FontTools:

```sh
pyftsubset "$ANDROID_HOME/platforms/android-22/data/fonts/DroidSansFallback.ttf" \
  --text-file=test/assets/fonts/preview_cjk_glyphs.txt \
  --output-file=test/assets/fonts/DroidSansFallback-PreviewSubset.ttf \
  --layout-features='*' --glyph-names --symbol-cmap --legacy-cmap \
  --notdef-glyph --notdef-outline --recommended-glyphs \
  --name-IDs='*' --name-legacy --name-languages='*'
```

`DroidSansFallback-LyricSubset.ttf` uses the same AOSP source and license, with
`lyric_cjk_glyphs.txt` as its glyph list. Regenerate with the command above,
substituting the lyric glyph list and output filename.

`DroidSansFallback-LyricSearchSubset.ttf` is a separate AOSP/Apache-2.0 subset
for compact lyric-search widget screenshots. Its exact glyph list is
`lyric_search_cjk_glyphs.txt`; regenerate with the command above using those two
filenames. It shares `LICENSE.txt` and does not change production app assets.
The search fixture also applies these fonts to AppBar's independent title style.

Lyric-search screenshots are generated manually after UI changes for visual
review. Normal test runs check layout and interactions without comparing pixels.
To regenerate the three screenshots, run:

```sh
flutter test --update-goldens test/features/lyrics/presentation/pages/lyric_search_page_test.dart
```
