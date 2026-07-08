class MyProfile {
  const MyProfile({
    required this.id,
    required this.username,
    required this.nickname,
    required this.email,
    required this.status,
    required this.avatarUrl,
  });

  final String id;
  final String username;
  final String nickname;
  final String email;
  final int status;
  final String avatarUrl;
}
