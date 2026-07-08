import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';

import '../../../../core/audio/audio_player_port.dart';
import '../../../player/presentation/providers/player_audio_provider.dart';
import '../../../player/presentation/providers/player_providers.dart';
import '../../domain/entities/lyric_document.dart';
import '../../domain/entities/lyric_request.dart';

class CurrentLyricStoreState {
  const CurrentLyricStoreState({
    this.request,
    this.document = const AsyncData<LyricDocument>(LyricDocument.empty()),
  });

  final LyricRequest? request;
  final AsyncValue<LyricDocument> document;
}

class CurrentLyricStoreController
    extends AsyncNotifier<CurrentLyricStoreState> {
  StreamSubscription<dynamic>? _customEventSubscription;

  @override
  Future<CurrentLyricStoreState> build() async {
    final audioPlayer = ref.watch(audioPlayerPortProvider);
    _customEventSubscription?.cancel();
    _customEventSubscription = audioPlayer.customEventStream.listen((event) {
      if (event is! Map || event['type'] != 'lyricState') {
        return;
      }
      unawaited(_refresh(audioPlayer));
    });
    ref.onDispose(() {
      _customEventSubscription?.cancel();
      _customEventSubscription = null;
    });
    return _loadState(audioPlayer);
  }

  Future<void> _refresh(AudioPlayerPort audioPlayer) async {
    state = await AsyncValue.guard(() => _loadState(audioPlayer));
  }

  Future<CurrentLyricStoreState> _loadState(AudioPlayerPort audioPlayer) async {
    final snapshot = await audioPlayer.getCurrentLyricState();
    return _toStoreState(snapshot);
  }
}

final currentLyricStoreProvider =
    AsyncNotifierProvider<CurrentLyricStoreController, CurrentLyricStoreState>(
      CurrentLyricStoreController.new,
    );

final currentLyricRequestProvider = Provider<LyricRequest?>((ref) {
  final state = ref.watch(currentLyricStoreProvider).value;
  return state?.request;
});

final currentLyricDocumentProvider = Provider<AsyncValue<LyricDocument>>((ref) {
  final state = ref.watch(currentLyricStoreProvider);
  return state.when(
    data: (value) => value.document,
    loading: () => const AsyncLoading<LyricDocument>(),
    error: (error, stackTrace) => AsyncError<LyricDocument>(error, stackTrace),
  );
});

final lyricPositionProvider = Provider<Duration>((ref) {
  return ref.watch(playerControllerProvider.select((state) => state.position));
});

final lyricsPrefetchBindingProvider = Provider<void>((ref) {
  // 在应用根部提前订阅歌词状态流，避免播放器页晚于后台切歌进入时丢失最后一次歌词事件。
  ref.watch(currentLyricStoreProvider);
});

CurrentLyricStoreState _toStoreState(CurrentLyricStateSnapshot snapshot) {
  if (snapshot.isLoading) {
    return CurrentLyricStoreState(
      request: snapshot.request,
      document: const AsyncLoading<LyricDocument>(),
    );
  }
  final errorMessage = _nullableString(snapshot.errorMessage);
  if (errorMessage != null) {
    return CurrentLyricStoreState(
      request: snapshot.request,
      document: AsyncError<LyricDocument>(
        StateError(errorMessage),
        StackTrace.current,
      ),
    );
  }
  return CurrentLyricStoreState(
    request: snapshot.request,
    document: AsyncData<LyricDocument>(snapshot.document),
  );
}

String? _nullableString(dynamic value) {
  if (value == null) {
    return null;
  }
  final normalized = '$value'.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}
