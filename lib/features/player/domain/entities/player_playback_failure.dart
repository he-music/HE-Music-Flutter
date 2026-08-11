class PlayerPlaybackFailure {
  const PlayerPlaybackFailure({
    required this.transitionId,
    required this.code,
    required this.retryable,
    required this.message,
  });

  final int transitionId;
  final String code;
  final bool retryable;
  final String message;
}
