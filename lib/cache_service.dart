import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CacheCategory { video, photo, file, sticker, other }

class CacheService {
  CacheService._();

  static final CacheService instance = CacheService._();

  final Map<CacheCategory, CacheManager> _managers =
      <CacheCategory, CacheManager>{};

  static const String _kNetworkUsageBytes = 'cache_network_usage_bytes';
  static const String _kCacheBytes = 'cache_cached_bytes_total';
  static const String _kCacheBytesVideo = 'cache_cached_bytes_video';
  static const String _kCacheBytesPhoto = 'cache_cached_bytes_photo';
  static const String _kCacheBytesFile = 'cache_cached_bytes_file';
  static const String _kCacheBytesSticker = 'cache_cached_bytes_sticker';
  static const String _kCacheBytesOther = 'cache_cached_bytes_other';
  static const String _kAutoDownloadMobile = 'cache_auto_download_mobile';
  static const String _kAutoDownloadWifi = 'cache_auto_download_wifi';
  static const String _kAutoDownloadRoaming = 'cache_auto_download_roaming';

  static const String _kMaxCacheBytes = 'cache_max_bytes';
  static const String _kMetaPrefix = 'cache_meta_';

  static const int _kMaxAgeDays = 30;

  CacheManager _managerFor(CacheCategory category) {
    // Separate caches so we can clear by category.
    return _managers.putIfAbsent(
      category,
      () => CacheManager(
        Config(
          'ras_${category.name}_cache',
          stalePeriod: const Duration(days: _kMaxAgeDays),
          maxNrOfCacheObjects: 500,
        ),
      ),
    );
  }

  String _bytesKeyFor(CacheCategory category) {
    switch (category) {
      case CacheCategory.video:
        return _kCacheBytesVideo;
      case CacheCategory.photo:
        return _kCacheBytesPhoto;
      case CacheCategory.file:
        return _kCacheBytesFile;
      case CacheCategory.sticker:
        return _kCacheBytesSticker;
      case CacheCategory.other:
        return _kCacheBytesOther;
    }
  }

  Future<SharedPreferences> get _prefs async {
    return SharedPreferences.getInstance();
  }

  Future<int> getAppDataSizeBytes() async {
    return 0;
  }

  Future<int> getCacheSizeBytes() async {
    final p = await _prefs;
    return p.getInt(_kCacheBytes) ?? 0;
  }

  Future<int?> getMaxCacheBytes() async {
    final p = await _prefs;
    final v = p.getInt(_kMaxCacheBytes);
    if (v == null) return null;
    if (v <= 0) return null;
    return v;
  }

  Future<void> setMaxCacheBytes(int? bytes) async {
    final p = await _prefs;
    if (bytes == null || bytes <= 0) {
      await p.remove(_kMaxCacheBytes);
    } else {
      await p.setInt(_kMaxCacheBytes, bytes);
    }
    await _enforceMaxCacheLimit();
  }

  String _metaKey(CacheCategory category) => '$_kMetaPrefix${category.name}';

  Future<Map<String, dynamic>> _loadMeta(CacheCategory category) async {
    final p = await _prefs;
    final raw = p.getString(_metaKey(category));
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      final obj = jsonDecode(raw);
      if (obj is Map<String, dynamic>) return obj;
      if (obj is Map) return obj.cast<String, dynamic>();
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _saveMeta(
    CacheCategory category,
    Map<String, dynamic> meta,
  ) async {
    final p = await _prefs;
    await p.setString(_metaKey(category), jsonEncode(meta));
  }

  Future<void> _touchUrl(
    CacheCategory category,
    String url, {
    int? size,
  }) async {
    final meta = await _loadMeta(category);
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = meta[url];
    final m = <String, dynamic>{};
    if (existing is Map) {
      m.addAll(existing.cast<String, dynamic>());
    }
    m['last'] = now;
    if (size != null) m['size'] = size;
    meta[url] = m;

    // keep prefs bounded
    if (meta.length > 700) {
      final entries = meta.entries.toList();
      entries.sort((a, b) {
        final al = (a.value is Map) ? ((a.value as Map)['last'] ?? 0) : 0;
        final bl = (b.value is Map) ? ((b.value as Map)['last'] ?? 0) : 0;
        return (al as int).compareTo(bl as int);
      });
      for (int i = 0; i < 200; i++) {
        meta.remove(entries[i].key);
      }
    }

    await _saveMeta(category, meta);
  }

  Future<void> _enforceMaxCacheLimit() async {
    final maxBytes = await getMaxCacheBytes();
    if (maxBytes == null) return;

    final p = await _prefs;
    int total = p.getInt(_kCacheBytes) ?? 0;
    if (total <= maxBytes) return;

    final candidates =
        <({CacheCategory cat, String url, int last, int size})>[];
    for (final c in CacheCategory.values) {
      final meta = await _loadMeta(c);
      for (final e in meta.entries) {
        final v = e.value;
        if (v is! Map) continue;
        final last = (v['last'] ?? 0) is int ? v['last'] as int : 0;
        final size = (v['size'] ?? 0) is int ? v['size'] as int : 0;
        if (size <= 0) continue;
        candidates.add((cat: c, url: e.key, last: last, size: size));
      }
    }
    candidates.sort((a, b) => a.last.compareTo(b.last));

    for (final item in candidates) {
      if (total <= maxBytes) break;
      try {
        await _managerFor(item.cat).removeFile(item.url);
      } catch (_) {
        // ignore
      }

      final catKey = _bytesKeyFor(item.cat);
      final catBytes = p.getInt(catKey) ?? 0;
      await p.setInt(catKey, (catBytes - item.size).clamp(0, 1 << 62));
      total = (total - item.size).clamp(0, 1 << 62);
      await p.setInt(_kCacheBytes, total);

      final meta = await _loadMeta(item.cat);
      meta.remove(item.url);
      await _saveMeta(item.cat, meta);
    }
  }

  Future<int> getCacheSizeBytesByCategory(CacheCategory category) async {
    final p = await _prefs;
    return p.getInt(_bytesKeyFor(category)) ?? 0;
  }

  Future<Map<CacheCategory, int>> getCacheBreakdownBytes() async {
    final Map<CacheCategory, int> out = <CacheCategory, int>{};
    for (final c in CacheCategory.values) {
      out[c] = await getCacheSizeBytesByCategory(c);
    }
    return out;
  }

  Future<List<String>> getCachedUrlsByCategory(
    CacheCategory category, {
    int limit = 400,
  }) async {
    final meta = await _loadMeta(category);
    final entries = meta.entries.toList();
    entries.sort((a, b) {
      final al = (a.value is Map) ? ((a.value as Map)['last'] ?? 0) : 0;
      final bl = (b.value is Map) ? ((b.value as Map)['last'] ?? 0) : 0;
      return (bl as int).compareTo(al as int);
    });

    final out = <String>[];
    for (final e in entries) {
      if (out.length >= limit) break;
      final url = e.key;
      try {
        final cached = await _managerFor(category).getFileFromCache(url);
        final file = cached?.file;
        if (file != null && await file.exists()) {
          out.add(url);
        }
      } catch (_) {
        // ignore
      }
    }
    return out;
  }

  Future<bool> shouldAutoDownload() async {
    final List<ConnectivityResult> result = await Connectivity()
        .checkConnectivity();

    if (result.contains(ConnectivityResult.none)) {
      return false;
    }

    if (result.contains(ConnectivityResult.wifi)) {
      return getAutoDownloadWifi();
    }

    if (result.contains(ConnectivityResult.mobile)) {
      return getAutoDownloadMobile();
    }

    // Roaming detection is platform-specific; for now treat unknown as roaming.
    return getAutoDownloadRoaming();
  }

  Future<int> getNetworkUsageBytes() async {
    final p = await _prefs;
    return p.getInt(_kNetworkUsageBytes) ?? 0;
  }

  Future<void> addNetworkUsageBytes(int delta) async {
    if (delta <= 0) return;
    final p = await _prefs;
    final current = p.getInt(_kNetworkUsageBytes) ?? 0;
    await p.setInt(_kNetworkUsageBytes, current + delta);
  }

  Future<void> addCachedBytes(int delta) async {
    if (delta <= 0) return;
    final p = await _prefs;
    final current = p.getInt(_kCacheBytes) ?? 0;
    await p.setInt(_kCacheBytes, current + delta);
  }

  Future<void> addCachedBytesByCategory(
    CacheCategory category,
    int delta,
  ) async {
    if (delta <= 0) return;
    final p = await _prefs;
    final key = _bytesKeyFor(category);
    final current = p.getInt(key) ?? 0;
    await p.setInt(key, current + delta);
    // Also maintain total.
    final totalCurrent = p.getInt(_kCacheBytes) ?? 0;
    await p.setInt(_kCacheBytes, totalCurrent + delta);
  }

  Future<File?> getFileFromCache(
    String url, {
    CacheCategory category = CacheCategory.other,
  }) async {
    try {
      final cached = await _managerFor(category).getFileFromCache(url);
      if (cached?.file != null) {
        await _touchUrl(category, url);
      }
      return cached?.file;
    } catch (_) {
      return null;
    }
  }

  Future<File?> getOrDownloadFile(
    String url, {
    required bool allowDownload,
    bool forceDownload = false,
    CacheCategory category = CacheCategory.other,
  }) async {
    if (!forceDownload) {
      final cached = await getFileFromCache(url, category: category);
      if (cached != null) return cached;
    }
    if (!allowDownload) return null;

    try {
      // If not cached, download and account traffic/cache by file size.
      final info = await _managerFor(category).downloadFile(url);
      final file = info.file;
      final size = await file.length();
      await addNetworkUsageBytes(size);
      await addCachedBytesByCategory(category, size);
      await _touchUrl(category, url, size: size);
      await _enforceMaxCacheLimit();
      return file;
    } catch (_) {
      return null;
    }
  }

  Future<bool> getAutoDownloadMobile() async {
    final p = await _prefs;
    return p.getBool(_kAutoDownloadMobile) ?? false;
  }

  Future<bool> getAutoDownloadWifi() async {
    final p = await _prefs;
    return p.getBool(_kAutoDownloadWifi) ?? true;
  }

  Future<bool> getAutoDownloadRoaming() async {
    final p = await _prefs;
    return p.getBool(_kAutoDownloadRoaming) ?? false;
  }

  Future<void> setAutoDownloadMobile(bool value) async {
    final p = await _prefs;
    await p.setBool(_kAutoDownloadMobile, value);
  }

  Future<void> setAutoDownloadWifi(bool value) async {
    final p = await _prefs;
    await p.setBool(_kAutoDownloadWifi, value);
  }

  Future<void> setAutoDownloadRoaming(bool value) async {
    final p = await _prefs;
    await p.setBool(_kAutoDownloadRoaming, value);
  }

  Future<void> clearCache() async {
    await clearCacheByCategory(null);
  }

  Future<void> clearCacheByCategory(CacheCategory? category) async {
    if (category == null) {
      for (final c in CacheCategory.values) {
        await clearCacheByCategory(c);
      }
      final p = await _prefs;
      await p.setInt(_kCacheBytes, 0);
      return;
    }

    final p = await _prefs;
    final key = _bytesKeyFor(category);
    final currentCat = p.getInt(key) ?? 0;

    try {
      await _managerFor(category).emptyCache();
    } catch (_) {
      // ignore
    }

    await p.setInt(key, 0);
    if (currentCat > 0) {
      final totalCurrent = p.getInt(_kCacheBytes) ?? 0;
      final nextTotal = (totalCurrent - currentCat).clamp(0, 1 << 62);
      await p.setInt(_kCacheBytes, nextTotal);
    }

    await p.remove(_metaKey(category));
  }

  Future<void> clearAllData() async {
    await clearCache();
    final p = await _prefs;
    await p.setInt(_kNetworkUsageBytes, 0);
  }
}
