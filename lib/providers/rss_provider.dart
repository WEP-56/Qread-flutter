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

  Future<void> loadSources(String accessToken) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _sources = await ApiService.instance.getRssSourcesNew(accessToken);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadArticles(String accessToken, String sourceUrl) async {
    _loading = true;
    notifyListeners();

    try {
      final list = await ApiService.instance.getRssArticles(accessToken, sourceUrl);
      _articles[sourceUrl] = list;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
