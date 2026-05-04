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

  Future<void> loadExploreSources(String accessToken) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final sources = await ApiService.instance.getBookSourcesNew(accessToken);
      _exploreSources = sources.where((s) => s.enabledExplore == true).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
