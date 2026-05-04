import 'package:flutter/material.dart';
import '../models/rss_source.dart';
import '../models/rss_article.dart';
import '../services/api_service.dart';

class RssProvider extends ChangeNotifier {
  List<RssSource> _sources = [];
  Map<String, List<RssArticle>> _articles = {};
  bool _loading = false;
  String? _error;

  List<RssSource> get sources => _sources;
  Map<String, List<RssArticle>> get articles => _articles;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadSources(String accessToken, {bool refresh = false}) async {
    if (_loading) return;

    _loading = true;
    _error = null;
    if (refresh) {
      _sources = [];
    }
    notifyListeners();

    try {
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
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadArticles(String accessToken, String sourceId, {String? sortUrl, int page = 1}) async {
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
