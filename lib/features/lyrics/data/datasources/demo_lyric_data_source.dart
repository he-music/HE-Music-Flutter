const _demoLyrics = <String, String>{
  'soundhelix-1': '''
[00:00.00]SoundHelix Song 1
[00:12.00]Instrumental intro starts
[00:24.00]Beat and strings are building
[00:36.00]Main section comes in
[00:48.00]Keep listening to the groove
[01:00.00]Transition to the next phrase
[01:12.00]Melody repeats with variation
[01:24.00]Bridge section starts now
[01:36.00]Back to the main section
[01:48.00]Outro keeps fading forward
''',
  'soundhelix-2': '''
[00:00.00]SoundHelix Song 2
[00:10.00]Piano lead enters
[00:22.00]Rhythm grows stronger
[00:34.00]Texture opens wider
[00:46.00]Hook motif appears
[00:58.00]Second phrase response
[01:10.00]Bridge with pad layer
[01:22.00]Return to central theme
[01:34.00]Ending section starts
''',
  'soundhelix-3': '''
[00:00.00]SoundHelix Song 3
[00:14.00]Slow ambient opening
[00:28.00]Kick and bass arrive
[00:42.00]Lead line repeats
[00:56.00]Harmony moves upward
[01:10.00]Breakdown with soft pad
[01:24.00]Full rhythm resumes
[01:38.00]Closing passage begins
''',
};

class DemoLyricDataSource {
  Future<String?> fetchRawLyric(String trackId) async {
    return _demoLyrics[trackId];
  }
}
