import 'package:icu_kit/icu_kit.dart' as icu;

// Each isolate reuses its own collator. Reading this value initializes ICU before
// SQLite installs its callback, rather than during a native comparison.
final Comparator<String> compareSongText = icu.IcuCollator(
  locale: 'zh-CN',
).compare;
