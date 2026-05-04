import 'package:flutter/material.dart';
import '../models/book_source.dart';
import '../services/api_service.dart';

class DiscoverProvider extends ChangeNotifier {
  List<BookSource> _exploreSources = [];
  bool _loading = false;
  String? _error;
  String? _md5;

  List<BookSource> get exploreSources => _exploreSources;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadExploreSources(String accessToken, {bool refresh = false}) async {
    if (_loading) return;

    _loading = true;
    _error = null;
    if (refresh) {
      _md5 = null;
      _exploreSources = [];
    }
    notifyListeners();

    try {
      // Step 1: 获取 md5
      if (_md5 == null) {
        final pageData = await ApiService.instance.getBookSourcesPage(accessToken);
        final data = pageData['data'] ?? pageData;
        _md5 = data['md5']?.toString();
      }

      // Step 2: 加载所有书源（分页）
      final allSources = <BookSource>[];
      int page = 1;
      while (true) {
        final sources = await ApiService.instance.getBookSourcesNew(
          accessToken,
          md5: _md5,
          page: page,
        );
        if (sources.isEmpty) break;
        allSources.addAll(sources);
        page++;
      }

      _exploreSources = allSources.where((s) => s.enabledExplore == true).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
