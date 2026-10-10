/// Local diagnostic totals only. Contains no coordinates, URLs, user IDs, text,
/// or analytics upload. Backend requests are not provider request estimates.
class NetworkCounters {
  static final instance = NetworkCounters();
  final Map<String, int> _values = {};
  void increment(String category, [int amount = 1]) =>
      _values[category] = (_values[category] ?? 0) + amount;
  Map<String, int> get snapshot => Map.unmodifiable(_values);
  void reset() => _values.clear();
}
