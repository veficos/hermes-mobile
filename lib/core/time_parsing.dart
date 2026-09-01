/// Parse Hermes REST/gateway timestamps. Numeric values below 1e11 are epoch
/// seconds; larger numeric values are epoch milliseconds. Strings are ISO-8601.
DateTime? parseHermesTime(dynamic value, {bool isUtc = true}) {
  if (value is String) return DateTime.tryParse(value);
  if (value is! num) return null;
  final raw = value.toInt();
  final millis = raw.abs() < 100000000000 ? raw * 1000 : raw;
  return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: isUtc);
}

int? parseHermesEpochMillis(dynamic value) =>
    parseHermesTime(value)?.millisecondsSinceEpoch;
