import 'package:flutter/material.dart';
import '../models/rss_source.dart';
import '../models/rss_article.dart';
import '../services/api_service.dart';
import '../services/local_cache_service.dart';

class RssProvider extends ChangeNotifier {
  List<RssSource> _sources = [];
  final Map<String, List<RssArticle>> _articles = {};
  bool _loading = false;
  String? _error;

  List<RssSource> get sources => _sources;
  Map<String, List<RssArticle>> get articles => _articles;
  bool get loading => _loading;
  String? get error => _error;

  String _cacheScope(String accessToken) =>
      LocalCacheService.instance.scopedKey('${accessToken}_rss');

  Future<void> loadSources(String accessToken, {bool refresh = false}) async {
    if (_loading) return;

    _loading = true;
    _error = null;
    if (refresh) {
      _sources = [];
    }
    notifyListeners();

    try {
      await _loadLocalCache(accessToken);

      // 尝试通过 Page+New 缓存接口获取
      final pageData = await ApiService.instance.getRssSourcesPage(accessToken);
      final data = pageData['data'] ?? pageData;
      final md5 = data['md5']?.toString();
      final totalPages = int.tryParse(data['page']?.toString() ?? '1') ?? 1;

      List<RssSource> allSources = [];

      if (md5 != null) {
        for (int page = 1; page <= totalPages; page++) {
          final sources = await ApiService.instance.getRssSourcesNew(
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
        allSources = await ApiService.instance.getRssSources(accessToken);
      }

      _sources = allSources;
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
      'rss_sources_${_cacheScope(accessToken)}',
    );
    if (list == null || _sources.isNotEmpty) return;
    _sources = list
        .whereType<Map>()
        .map((e) => RssSource.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    notifyListeners();
  }

  Future<void> _saveLocalCache(String accessToken) async {
    await LocalCacheService.instance.saveJson(
      'rss_sources_${_cacheScope(accessToken)}',
      _sources.map((source) => source.toJson()).toList(),
    );
  }

  Future<void> loadArticles(String accessToken, String sourceId,
      {String? sortUrl, int page = 1}) async {
    _loading = true;
    notifyListeners();

    try {
      final list = await ApiService.instance.getRssArticles(
        accessToken,
        sourceId,
        sortUrl: sortUrl,
        page: page,
      );
      _articles[sourceId] = list;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
