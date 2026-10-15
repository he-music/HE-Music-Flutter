class SongDetailField {
  const SongDetailField({required this.label, required this.value});

  final String label;
  final String value;

  factory SongDetailField.fromMap(Map<String, dynamic> raw) => SongDetailField(
    label: raw['label'] as String? ?? '',
    value: raw['value'] as String? ?? '',
  );
}
