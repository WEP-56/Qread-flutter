import 'package:flutter/material.dart';
import '../models/book_source.dart';
import '../services/api_service.dart';

class DiscoverProvider extends ChangeNotifier {
  List<BookSource> _exploreSources = [];
  bool _loading = false;
  String? _error;

  List<BookSource> get exploreSources => _exploreSources;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadExploreSources(String accessToken, {bool refresh = false}) async {
    if (_loading) return;

    _loading = true;
    _error = null;
    if (refresh) {
      _exploreSources = [];
    }
    notifyListeners();

    try {
      // 尝试通过 Page+New 缓存接口获取
      final pageData = await ApiService.instance.getBookSourcesPage(accessToken);
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

      _exploreSources = allSources.where((s) => s.enabledExplore == true).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
