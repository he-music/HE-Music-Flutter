import 'song_detail_content.dart';
import 'song_detail_relations.dart';

class SongDetailState {
  const SongDetailState({
    required this.loading,
    required this.relationsLoading,
    this.content,
    this.errorMessage,
    this.relations,
    this.relationsErrorMessage,
  });

  final bool loading;
  final bool relationsLoading;
  final SongDetailContent? content;
  final String? errorMessage;
  final SongDetailRelations? relations;
  final String? relationsErrorMessage;

  SongDetailState copyWith({
    bool? loading,
    bool? relationsLoading,
    SongDetailContent? content,
    String? errorMessage,
    SongDetailRelations? relations,
    String? relationsErrorMessage,
    bool clearContent = false,
    bool clearRelations = false,
    bool clearError = false,
    bool clearRelationsError = false,
  }) {
    return SongDetailState(
      loading: loading ?? this.loading,
      relationsLoading: relationsLoading ?? this.relationsLoading,
      content: clearContent ? null : content ?? this.content,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      relations: clearRelations ? null : relations ?? this.relations,
      relationsErrorMessage: clearRelationsError
          ? null
          : relationsErrorMessage ?? this.relationsErrorMessage,
    );
  }

  static const initial = SongDetailState(
    loading: false,
    relationsLoading: false,
  );
}
