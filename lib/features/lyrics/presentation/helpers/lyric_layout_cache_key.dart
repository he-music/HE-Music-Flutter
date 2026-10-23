/// Keeps the document signature shared instead of copying it into every line key.
/// Record equality compares both fields, so hash collisions cannot reuse a layout.
typedef LyricLayoutCacheKey = ({
  String documentSignature,
  String layoutSignature,
});
