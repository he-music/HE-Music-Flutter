class ArtistDetailPageChunk<T> {
  const ArtistDetailPageChunk({
    required this.items,
    required this.hasMore,
    required this.nextPageIndex,
  });

  final List<T> items;
  final bool hasMore;
  final int nextPageIndex;
}
