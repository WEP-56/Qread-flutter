import 'dart:convert';

enum SourceFieldType { text, checkbox, dropdown }

class SourceEditorField {
  final String path;
  final String label;
  final int maxLines;
  final String? hint;
  final SourceFieldType type;
  final List<String>? options;

  const SourceEditorField({
    required this.path,
    required this.label,
    this.maxLines = 1,
    this.hint,
    this.type = SourceFieldType.text,
    this.options,
  });
}

dynamic readPath(Map<String, dynamic> data, String path) {
  final parts = path.split('.');
  dynamic current = data;
  for (final part in parts) {
    if (current is Map<String, dynamic>) {
      current = current[part];
    } else {
      return null;
    }
  }
  return current;
}

void writePath(Map<String, dynamic> data, String path, dynamic value) {
  final parts = path.split('.');
  Map<String, dynamic> current = data;
  for (int i = 0; i < parts.length - 1; i++) {
    final part = parts[i];
    final next = current[part];
    if (next is Map<String, dynamic>) {
      current = next;
    } else {
      final created = <String, dynamic>{};
      current[part] = created;
      current = created;
    }
  }
  current[parts.last] = value;
}

Map<String, dynamic> decodeSourceJson(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) {
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }
  if (decoded is List) {
    if (decoded.isEmpty) return <String, dynamic>{};
    final first = decoded.first;
    if (first is Map<String, dynamic>) return first;
    if (first is Map) {
      return first.map((key, value) => MapEntry(key.toString(), value));
    }
  }
  throw const FormatException('Invalid source json');
}

String encodePrettyJson(Map<String, dynamic> data) {
  return const JsonEncoder.withIndent('  ').convert(data);
}
