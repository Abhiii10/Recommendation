class IntelligenceCacheManager {
  final int maxEntries;
  final _values = <String, Object>{};
  final _order = <String>[];

  IntelligenceCacheManager({this.maxEntries = 128});

  T? get<T extends Object>(String key) {
    final value = _values[key];
    return value is T ? value : null;
  }

  void set(String key, Object value) {
    if (!_values.containsKey(key)) {
      _order.add(key);
    }
    _values[key] = value;
    while (_order.length > maxEntries) {
      final oldest = _order.removeAt(0);
      _values.remove(oldest);
    }
  }

  void clear() {
    _values.clear();
    _order.clear();
  }
}
