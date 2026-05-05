import 'dart:convert';

class RowUi {
  final String name;
  final String type; // "text", "password", "button"
  final String? action;
  final Map<String, dynamic>? style;

  const RowUi({
    required this.name,
    this.type = 'text',
    this.action,
    this.style,
  });

  factory RowUi.fromJson(Map<String, dynamic> json) {
    return RowUi(
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? 'text',
      action: json['action']?.toString(),
      style: json['style'] is Map<String, dynamic>
          ? json['style'] as Map<String, dynamic>
          : null,
    );
  }

  bool get isButton => type == 'button';
  bool get isPassword => type == 'password';
}

List<RowUi> parseLoginUi(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded
          .map((e) => RowUi.fromJson(e is Map<String, dynamic> ? e : {}))
          .toList();
    }
    return [];
  } catch (_) {
    return [];
  }
}

Map<String, String> defaultLoginData(List<RowUi> rows) {
  final data = <String, String>{};
  for (final row in rows) {
    if (!row.isButton) {
      data[row.name] = '';
    }
  }
  return data;
}
