import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Installation identity for anonymous provider seeds, independent of accounts
/// and JWT device sessions. Logging out must never remove this preference.
class ClientInstanceIdStore {
  ClientInstanceIdStore({Future<SharedPreferences> Function()? loadPreferences})
    : _loadPreferences = loadPreferences ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _loadPreferences;
  static const storageKey = 'network.client_instance_id';
  Future<String>? _loading;

  Future<String> load() => _loading ??= _load().catchError((Object error) {
    _loading = null;
    throw error;
  });

  Future<String> _load() async {
    final prefs = await _loadPreferences();
    final stored = prefs.get(storageKey);
    if (stored is String && isValid(stored)) return stored;
    final id = const Uuid().v4();
    if (!await prefs.setString(storageKey, id)) {
      throw StateError('Could not persist client instance ID');
    }
    return id;
  }

  static bool isValid(String value) =>
      value.isNotEmpty &&
      value.length <= 128 &&
      value.codeUnits.every((unit) => unit >= 0x21 && unit <= 0x7e);
}

final clientInstanceIdStore = ClientInstanceIdStore();
