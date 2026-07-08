bool hasValidAlbumId(String? albumId) {
  final normalized = albumId?.trim() ?? '';
  return normalized.isNotEmpty && normalized != '0';
}
