import 'app_player_style_models.dart';
import 'styles/artist_photo_player_style.dart';
import 'styles/cadenza_lyrics_player_style.dart';
import 'styles/cassette_player_style.dart';
import 'styles/classic_player_style.dart';
import 'styles/fluid_player_style.dart';
import 'styles/monet_lyrics_player_style.dart';
import 'styles/partita_lyrics_player_style.dart';
import 'styles/radial_spectrum_player_style.dart';
import 'styles/vinyl_player_style.dart';

class AppPlayerStyleRegistry {
  AppPlayerStyleRegistry(Iterable<AppPlayerStylePackage> packages)
    : _styles = _buildRegistry(packages);

  factory AppPlayerStyleRegistry.builtIn() {
    return AppPlayerStyleRegistry(const <AppPlayerStylePackage>[
      classicPlayerStyle,
      fluidPlayerStyle,
      vinylPlayerStyle,
      cassettePlayerStyle,
      artistPhotoPlayerStyle,
      radialSpectrumPlayerStyle,
      monetLyricsPlayerStyle,
      partitaLyricsPlayerStyle,
      cadenzaLyricsPlayerStyle,
    ]);
  }

  static const String classicId = 'classic';
  static const String fluidId = 'fluid';
  static const String vinylId = 'vinyl';
  static const String cassetteId = 'cassette';
  static const String artistPhotoId = 'artist_photo';
  static const String radialSpectrumId = 'radial_spectrum';
  static const String monetLyricsId = 'monet_lyrics';
  static const String partitaLyricsId = 'partita_lyrics';
  static const String cadenzaLyricsId = 'cadenza_lyrics';
  static const Set<String> builtInIds = <String>{
    classicId,
    fluidId,
    vinylId,
    cassetteId,
    artistPhotoId,
    radialSpectrumId,
    monetLyricsId,
    partitaLyricsId,
    cadenzaLyricsId,
  };

  static final AppPlayerStyleRegistry instance =
      AppPlayerStyleRegistry.builtIn();

  final Map<String, AppPlayerStylePackage> _styles;

  List<AppPlayerStylePackage> get styles =>
      List<AppPlayerStylePackage>.unmodifiable(_styles.values);

  bool contains(String? id) => id != null && _styles.containsKey(id);

  String normalizeId(String? id) => contains(id) ? id! : classicId;

  AppPlayerStylePackage resolve(String? id) {
    return _styles[normalizeId(id)]!;
  }

  static Map<String, AppPlayerStylePackage> _buildRegistry(
    Iterable<AppPlayerStylePackage> packages,
  ) {
    final styles = <String, AppPlayerStylePackage>{};
    for (final package in packages) {
      final id = package.metadata.id;
      if (!package.isValid) {
        throw StateError('Invalid player style package: $id');
      }
      if (styles.containsKey(id)) {
        throw StateError('Duplicate player style id: $id');
      }
      styles[id] = package;
    }
    if (!styles.containsKey(classicId)) {
      throw StateError('Player style registry requires classic');
    }
    return Map<String, AppPlayerStylePackage>.unmodifiable(styles);
  }
}
