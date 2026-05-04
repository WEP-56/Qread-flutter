import 'package:flutter/material.dart';
import '../models/book.dart';
import '../services/api_service.dart';

class BookshelfProvider extends ChangeNotifier {
  List<Book> _books = [];
  bool _loading = false;
  int _currentPage = 1;
  bool _hasMore = true;
  String? _error;

  List<Book> get books => _books;
  bool get loading => _loading;
  bool get hasMore => _hasMore;
  String? get error => _error;

  Future<void> loadBooks(String accessToken, {bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _books = [];
    }

    if (_loading || !_hasMore) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final newBooks = await ApiService.instance.getBookshelfNew(
        accessToken,
        page: _currentPage,
      );
      if (refresh) {
        _books = newBooks;
      } else {
        _books.addAll(newBooks);
      }
      _hasMore = newBooks.length >= 20;
      _currentPage++;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> deleteBooks(String accessToken, List<String> bookUrls) async {
    try {
      await ApiService.instance.deleteBooks(accessToken, bookUrls);
      _books.removeWhere((b) => bookUrls.contains(b.bookUrl));
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
