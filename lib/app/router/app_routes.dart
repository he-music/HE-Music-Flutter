abstract final class AppRoutes {
  static const home = '/';
  static String get homeMy => Uri(
    path: home,
    queryParameters: const <String, String>{'tab': 'my'},
  ).toString();
  static const login = '/login';
  static const loginQrScan = '/login/qr-scan';
  static const loginQrConfirm = '/login/qr-confirm';
  static const captcha = '/captcha';
  static const library = '/library';
  static const localGenre = '/local/genre';
  static const localMetadataEdit = '/local/edit';
  static const player = '/player';
  static const downloads = '/downloads';
  static const online = '/online';
  static const onlineSearch = '/online/search';
  static const parseSourceUrl = '/online/parse';
  static const onlineComments = '/online/comments';
  static const settings = '/settings';
  static const about = '/settings/about';
  static const settingsProfile = '/settings/profile';
  static const settingsPassword = '/settings/password';
  static const settingsDevice = '/settings/device';
  static const discoverDetail = '/discover/detail';
  static const artistDetail = '/artist/detail';
  static const artistPlaza = '/artist/plaza';
  static const newSong = '/new-song';
  static const newAlbum = '/new-album';
  static const playlistPlaza = '/playlist/plaza';
  static const videoPlaza = '/video/plaza';
  static const radioPlaza = '/radio/plaza';
  static const playlistDetail = '/playlist/detail';
  static const userPlaylistDetail = '/my/playlist/detail';
  static const albumDetail = '/album/detail';
  static const songDetail = '/song/detail';
  static const videoDetail = '/video/detail';
  static const rankingList = '/ranking-list';
  static const rankingDetail = '/ranking';
  static const my = '/my';
  static const myHistory = '/my/history';
  static const myCollection = '/my/collection';
}
