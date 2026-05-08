// cache_service.dart
class CacheService {
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _timestamps = {};
  static const Duration _ttl = Duration(minutes: 5);

  static T? get<T>(String key) {
    final ts = _timestamps[key];
    if (ts == null || DateTime.now().difference(ts) > _ttl) return null;
    return _cache[key] as T?;
  }

  static void set(String key, dynamic value) {
    _cache[key] = value;
    _timestamps[key] = DateTime.now();
  }

  static void clear() {
    _cache.clear();
    _timestamps.clear();
  }
}