import 'package:flutter/material.dart';
import '../models/book_source.dart';
import '../services/api_service.dart';
import '../services/local_cache_service.dart';

class DiscoverProvider extends ChangeNotifier {
  List<BookSource> _exploreSources = [];
  bool _loading = false;
  String? _error;

  List<BookSource> get exploreSources => _exploreSources;
  bool get loading => _loading;
  String? get error => _error;

  String _cacheScope(String accessToken) =>
      LocalCacheService.instance.scopedKey('${accessToken}_discover');

  Future<void> loadExploreSources(String accessToken,
      {bool refresh = false}) async {
    if (_loading) return;

    _loading = true;
    _error = null;
    if (refresh) {
      _exploreSources = [];
    }
    notifyListeners();

    try {
      await _loadLocalCache(accessToken);

      // 尝试通过 Page+New 缓存接口获取
      final pageData =
          await ApiService.instance.getBookSourcesPage(accessToken);
      final data = pageData['data'] ?? pageData;
      final md5 = data['md5']?.toString();
      final totalPages = int.tryParse(data['page']?.toString() ?? '1') ?? 1;

      List<BookSource> allSources = [];

      if (md5 != null) {
        for (int page = 1; page <= totalPages; page++) {
          final sources = await ApiService.instance.getBookSourcesNew(
            accessToken,
            md5: md5,
            page: page,
          );
          if (sources.isEmpty) break;
          allSources.addAll(sources);
        }
      }

      // Fallback: 如果缓存接口返回空，直接获取
      if (allSources.isEmpty) {
        allSources = await ApiService.instance.getBookSources(accessToken);
      }

      _exploreSources =
          allSources.where((s) => s.enabledExplore == true).toList();
      await _saveLocalCache(accessToken);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadLocalCache(String accessToken) async {
    final list = await LocalCacheService.instance.readJsonList(
      'discover_sources_${_cacheScope(accessToken)}',
    );
    if (list == null || _exploreSources.isNotEmpty) return;
    _exploreSources = list
        .whereType<Map>()
        .map((e) => BookSource.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    notifyListeners();
  }

  Future<void> _saveLocalCache(String accessToken) async {
    await LocalCacheService.instance.saveJson(
      'discover_sources_${_cacheScope(accessToken)}',
      _exploreSources.map((source) => source.toJson()).toList(),
    );
  }
}
