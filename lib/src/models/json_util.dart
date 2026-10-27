int asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? asIntOrNull(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double asDouble(Object? value, [double fallback = 0]) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

bool asBool(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  return fallback;
}

String asString(Object? value, [String fallback = '']) {
  if (value is String) return value;
  return fallback;
}

String? asStringOrNull(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

List<String> asStringList(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) item.toString()];
}

Map<String, Object?> asMap(Object? value) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<Map<String, Object?>> asMapList(Object? value) {
  if (value is! List) return const [];
  return [for (final item in value) asMap(item)];
}
