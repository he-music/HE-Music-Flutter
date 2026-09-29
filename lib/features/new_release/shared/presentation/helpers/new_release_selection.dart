/// 优先使用列表中存在的首选项，否则选择第一项；空列表返回 null。
String? resolveNewReleaseSelectionId<T>(
  List<T> items,
  String? preferredId, {
  required String Function(T item) idOf,
}) {
  final normalizedPreferred = preferredId?.trim() ?? '';
  if (normalizedPreferred.isNotEmpty) {
    for (final item in items) {
      final id = idOf(item);
      if (id == normalizedPreferred) {
        return id;
      }
    }
  }
  return items.isEmpty ? null : idOf(items.first);
}
