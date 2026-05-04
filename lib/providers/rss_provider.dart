import 'package:flutter/material.dart';
import '../models/rss_source.dart';
import '../models/rss_article.dart';
import '../services/api_service.dart';

class RssProvider extends ChangeNotifier {
  List<RssSource> _sources = [];
  Map<String, List<RssArticle>> _articles = {};
  bool _loading = false;
  String? _error;
  String? _md5;

  List<RssSource> get sources => _sources;
  Map<String, List<RssArticle>> get articles => _articles;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadSources(String accessToken, {bool refresh = false}) async {
    if (_loading) return;

    _loading = true;
    _error = null;
    if (refresh) {
      _md5 = null;
      _sources = [];
    }
    notifyListeners();

    try {
      // Step 1: 获取 md5
      if (_md5 == null) {
        final pageData = await ApiService.instance.getRssSourcesPage(accessToken);
        final data = pageData['data'] ?? pageData;
        _md5 = data['md5']?.toString();
      }

      // Step 2: 加载 RSS 源
      _sources = await ApiService.instance.getRssSourcesNew(
        accessToken,
        md5: _md5,
        page: 1,
      );
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
