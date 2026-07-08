class HomePlatform {
  const HomePlatform({
    required this.id,
    required this.name,
    required this.shortName,
    required this.status,
    required this.featureSupportFlag,
  });

  final String id;
  final String name;
  final String shortName;
  final int status;
  final BigInt featureSupportFlag;

  bool get available => status == 1;

  bool supports(BigInt flag) {
    return (featureSupportFlag & flag) != BigInt.zero;
  }

  factory HomePlatform.fromMap(Map<String, dynamic> raw) {
    final id = '${raw['id'] ?? ''}'.trim();
    final name = '${raw['name'] ?? ''}'.trim();
    if (id.isEmpty || name.isEmpty) {
      throw FormatException('Invalid platform payload: $raw');
    }
    return HomePlatform(
      id: id,
      name: name,
      shortName: _readShortName(raw, name),
      status: _readStatus(raw),
      featureSupportFlag: _readFeatureSupportFlag(raw),
    );
  }

  static String _readShortName(Map<String, dynamic> raw, String fallback) {
    final value = '${raw['shortname'] ?? ''}'.trim();
    return value.isEmpty ? fallback : value;
  }

  static int _readStatus(Map<String, dynamic> raw) {
    final value = raw['status'];
    if (value is int) {
      return value;
    }
    return int.tryParse('$value') ?? 0;
  }

  static BigInt _readFeatureSupportFlag(Map<String, dynamic> raw) {
    final value = raw['feature_support_flag'];
    if (value is BigInt) {
      return value;
    }
    if (value is int) {
      return BigInt.from(value);
    }
    return BigInt.tryParse('$value') ?? BigInt.zero;
  }
}
