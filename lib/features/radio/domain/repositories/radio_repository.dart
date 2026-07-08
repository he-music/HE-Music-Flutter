import '../../../../shared/models/he_music_models.dart';

/// 电台数据访问的抽象接口。
abstract class RadioRepository {
  /// 获取指定平台的电台分组列表。
  Future<List<RadioGroupInfo>> fetchGroups({required String platform});

  /// 获取指定电台的歌曲列表。
  Future<List<SongInfo>> fetchSongs({
    required String id,
    required String platform,
    int pageIndex = 1,
    int pageSize = 50,
  });
}
