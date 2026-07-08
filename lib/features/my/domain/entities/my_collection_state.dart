import 'my_favorite_item.dart';
import 'my_favorite_type.dart';

class MyCollectionState {
  const MyCollectionState({
    required this.loading,
    required this.selectedType,
    required this.playlists,
    required this.artists,
    required this.albums,
    this.errorMessage,
  });

  final bool loading;
  final MyFavoriteType selectedType;
  final List<MyFavoriteItem> playlists;
  final List<MyFavoriteItem> artists;
  final List<MyFavoriteItem> albums;
  final String? errorMessage;

  List<MyFavoriteItem> get selectedItems {
    return switch (selectedType) {
      MyFavoriteType.playlists => playlists,
      MyFavoriteType.artists => artists,
      MyFavoriteType.albums => albums,
      MyFavoriteType.songs => const <MyFavoriteItem>[],
    };
  }

  MyCollectionState copyWith({
    bool? loading,
    MyFavoriteType? selectedType,
    List<MyFavoriteItem>? playlists,
    List<MyFavoriteItem>? artists,
    List<MyFavoriteItem>? albums,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MyCollectionState(
      loading: loading ?? this.loading,
      selectedType: selectedType ?? this.selectedType,
      playlists: playlists ?? this.playlists,
      artists: artists ?? this.artists,
      albums: albums ?? this.albums,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  static const initial = MyCollectionState(
    loading: false,
    selectedType: MyFavoriteType.playlists,
    playlists: <MyFavoriteItem>[],
    artists: <MyFavoriteItem>[],
    albums: <MyFavoriteItem>[],
  );
}
