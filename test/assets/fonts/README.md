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
