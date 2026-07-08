class NewReleasePageResult<T> {
  const NewReleasePageResult({required this.list, required this.hasMore});

  final List<T> list;
  final bool hasMore;
}
