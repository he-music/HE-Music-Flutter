import 'app_player_style_models.dart';
import 'styles/artist_photo_player_style.dart';
import 'styles/cadenza_lyrics_player_style.dart';
import 'styles/cassette_player_style.dart';
import 'styles/classic_player_style.dart';
import 'styles/cover_gradient_player_backdrop.dart';
import 'styles/fluid_player_style.dart';
import 'styles/legacy_lyrics_option.dart';
import 'styles/monet_lyrics_player_style.dart';
import 'styles/partita_lyrics_player_style.dart';
import 'styles/radial_spectrum_player_style.dart';
import 'styles/vinyl_player_style.dart';

/// 封面（stage）轴注册表。
class AppPlayerStageRegistry {
  AppPlayerStageRegistry(Iterable<AppPlayerStageOption> options)
    : _options = _build(
        options,
        idOf: (option) => option.metadata.id,
        isValid: (option) => option.isValid,
      );

  factory AppPlayerStageRegistry.builtIn() {
    return AppPlayerStageRegistry(<AppPlayerStageOption>[
      classicPlayerStage,
      vinylPlayerStage,
      cassettePlayerStage,
      radialSpectrumPlayerStage,
    ]);
  }

  static const String classicId = 'classic';
  static const String vinylId = 'vinyl';
  static const String cassetteId = 'cassette';
  static const String radialSpectrumId = 'radial_spectrum';

  static const Set<String> builtInIds = <String>{
    classicId,
    vinylId,
    cassetteId,
    radialSpectrumId,
  };

  static final AppPlayerStageRegistry instance =
      AppPlayerStageRegistry.builtIn();

  final Map<String, AppPlayerStageOption> _options;

  List<AppPlayerStageOption> get options =>
      List<AppPlayerStageOption>.unmodifiable(_options.values);

  bool contains(String? id) => id != null && _options.containsKey(id);

  String normalizeId(String? id) => contains(id) ? id! : classicId;

  AppPlayerStageOption resolve(String? id) => _options[normalizeId(id)]!;
}

/// 背景（backdrop）轴注册表。
class AppPlayerBackdropRegistry {
  AppPlayerBackdropRegistry(Iterable<AppPlayerBackdropOption> options)
    : _options = _build(
        options,
        idOf: (option) => option.metadata.id,
        isValid: (option) => option.isValid,
      );

  factory AppPlayerBackdropRegistry.builtIn() {
    return AppPlayerBackdropRegistry(<AppPlayerBackdropOption>[
      coverGradientPlayerBackdrop,
      fluidPlayerBackdrop,
      artistPhotoPlayerBackdrop,
    ]);
  }

  static const String coverGradientId = 'cover_gradient';
  static const String fluidId = 'fluid';
  static const String artistPhotoId = 'artist_photo';

  static const Set<String> builtInIds = <String>{
    coverGradientId,
    fluidId,
    artistPhotoId,
  };

  static final AppPlayerBackdropRegistry instance =
      AppPlayerBackdropRegistry.builtIn();

  final Map<String, AppPlayerBackdropOption> _options;

  List<AppPlayerBackdropOption> get options =>
      List<AppPlayerBackdropOption>.unmodifiable(_options.values);

  bool contains(String? id) => id != null && _options.containsKey(id);

  String normalizeId(String? id) => contains(id) ? id! : coverGradientId;

  AppPlayerBackdropOption resolve(String? id) => _options[normalizeId(id)]!;
}

/// 歌词（lyric）轴注册表。
class AppPlayerLyricsRegistry {
  AppPlayerLyricsRegistry(Iterable<AppPlayerLyricsOption> options)
    : _options = _build(
        options,
        idOf: (option) => option.metadata.id,
        isValid: (option) => option.isValid,
      );

  factory AppPlayerLyricsRegistry.builtIn() {
    return AppPlayerLyricsRegistry(<AppPlayerLyricsOption>[
      legacyLyricsOption,
      monetLyricsOption,
      partitaLyricsOption,
      cadenzaLyricsOption,
    ]);
  }

  static const String legacyId = 'legacy';
  static const String monetId = 'monet_lyrics';
  static const String partitaId = 'partita_lyrics';
  static const String cadenzaId = 'cadenza_lyrics';

  static const Set<String> builtInIds = <String>{
    legacyId,
    monetId,
    partitaId,
    cadenzaId,
  };

  static final AppPlayerLyricsRegistry instance =
      AppPlayerLyricsRegistry.builtIn();

  final Map<String, AppPlayerLyricsOption> _options;

  List<AppPlayerLyricsOption> get options =>
      List<AppPlayerLyricsOption>.unmodifiable(_options.values);

  bool contains(String? id) => id != null && _options.containsKey(id);

  String normalizeId(String? id) => contains(id) ? id! : legacyId;

  AppPlayerLyricsOption resolve(String? id) => _options[normalizeId(id)]!;
}

Map<String, T> _build<T>(
  Iterable<T> options, {
  required String Function(T) idOf,
  required bool Function(T) isValid,
}) {
  final map = <String, T>{};
  for (final option in options) {
    final id = idOf(option);
    if (!isValid(option)) {
      throw StateError('Invalid player option: $id');
    }
    if (map.containsKey(id)) {
      throw StateError('Duplicate player option id: $id');
    }
    map[id] = option;
  }
  return Map<String, T>.unmodifiable(map);
}