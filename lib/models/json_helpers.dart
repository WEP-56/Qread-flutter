// ignore_for_file: unused_element

int? toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v);
  if (v is bool) return v ? 1 : 0;
  return null;
}

double? toDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

bool? toBool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  if (v is int) return v != 0;
  if (v is double) return v != 0;
  if (v is String) {
    final s = v.toLowerCase();
    return s == 'true' || s == '1' || s == 'ok';
  }
  return null;
}

String? toStringVal(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

List<T>? toList<T>(dynamic v, T Function(dynamic) fromJson) {
  if (v == null) return null;
  if (v is List) {
    return v.map((e) => fromJson(e)).toList();
  }
  return null;
}
