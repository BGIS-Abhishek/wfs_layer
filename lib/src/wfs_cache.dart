/// In-memory LRU-style cache for WFS responses.
library;

import 'package:flutter_map/flutter_map.dart';

/// A single cache entry holding a parsed GeoJSON response and metadata.
class WfsCacheEntry {
  /// The raw parsed GeoJSON response map.
  final Map<String, dynamic> data;

  /// When this entry was created.
  final DateTime timestamp;

  /// The map bounds for which this data was fetched.
  final LatLngBounds bounds;

  /// Creates a [WfsCacheEntry].
  WfsCacheEntry({
    required this.data,
    required this.timestamp,
    required this.bounds,
  });

  /// Returns `true` if this entry is older than [expiry].
  bool isExpired(Duration expiry) =>
      DateTime.now().difference(timestamp) > expiry;
}

/// Manages the in-memory cache for WFS feature responses.
///
/// Automatically evicts expired entries and caps the total
/// number of entries to [maxEntries] (default 50), keeping
/// the most recently fetched [retainCount] (default 30) entries.
///
/// You do not need to interact with this class directly — it is
/// used internally by [WfsLayer].
class WfsCache {
  /// Maximum number of cache entries before eviction runs.
  final int maxEntries;

  /// Number of entries to retain after eviction.
  final int retainCount;

  final Map<String, WfsCacheEntry> _store = {};

  /// Creates a [WfsCache].
  WfsCache({this.maxEntries = 50, this.retainCount = 30});

  /// Returns `true` if [key] exists and has not expired.
  bool has(String key, Duration expiry) {
    final entry = _store[key];
    if (entry == null) return false;
    if (entry.isExpired(expiry)) {
      _store.remove(key);
      return false;
    }
    return true;
  }

  /// Retrieves the cached data for [key], or `null` if absent/expired.
  Map<String, dynamic>? get(String key, Duration expiry) {
    if (!has(key, expiry)) return null;
    return _store[key]?.data;
  }

  /// Stores [data] under [key] for the given [bounds].
  void put(String key, Map<String, dynamic> data, LatLngBounds bounds) {
    _store[key] = WfsCacheEntry(
      data: data,
      timestamp: DateTime.now(),
      bounds: bounds,
    );
    _evict();
  }

  /// Removes all expired entries and trims to [retainCount] if over [maxEntries].
  void evictExpired(Duration expiry) {
    _store.removeWhere((_, entry) => entry.isExpired(expiry));
    _evict();
  }

  /// Clears all cached entries.
  void clear() => _store.clear();

  /// Returns the current number of cached entries.
  int get length => _store.length;

  void _evict() {
    if (_store.length <= maxEntries) return;

    final sorted = _store.entries.toList()
      ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

    final toRemove = _store.length - retainCount;
    for (var i = 0; i < toRemove; i++) {
      _store.remove(sorted[i].key);
    }
  }
}
