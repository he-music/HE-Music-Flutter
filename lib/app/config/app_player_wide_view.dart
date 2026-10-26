/// Content shown above the shared controls in the wide player only.
enum AppPlayerWideView {
  cover,
  split,
  lyrics;

  static AppPlayerWideView parse(String? value) => switch (value) {
    'cover' => cover,
    'lyrics' => lyrics,
    _ => split,
  };
}
