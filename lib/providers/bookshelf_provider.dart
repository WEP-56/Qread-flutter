import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/book_group.dart';
import '../services/api_service.dart';

class BookshelfProvider extends ChangeNotifier {
  List<Book> _books = [];
  List<BookGroup> _groups = [];
  bool _loading = false;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasMore = true;
  String? _error;
  String? _md5;
  String? _selectedGroup; // null = 全部

  List<Book> get books => _selectedGroup == null
      ? _books
      : _books.where((b) => _matchGroup(b, _selectedGroup!)).toList();
  List<Book> get allBooks => _books;
  List<BookGroup> get groups => _groups;
  bool get loading => _loading;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String? get selectedGroup => _selectedGroup;

  bool _matchGroup(Book book, String groupName) {
    if (groupName == '未分组') {
      return book.group == null || book.group == 0;
    }
    if (groupName == '有声书') {
      return book.type == 1;
    }
    if (groupName == '漫画') {
      return book.type == 2;
    }
    // Custom group: Book.group is an int matching BookGroup.groupId
    BookGroup? targetGroup;
    for (final g in _groups) {
      if (g.groupName == groupName) {
        targetGroup = g;
        break;
      }
    }
    if (targetGroup != null) {
      return book.group == targetGroup.groupId;
    }
    return false;
  }

  void selectGroup(String? groupName) {
    _selectedGroup = groupName;
    notifyListeners();
  }

  Future<void> loadBookshelf(String accessToken, {bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _books = [];
      _md5 = null;
    }

    if (_loading) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // Step 1: Get page info (md5 + total pages)
      if (_md5 == null) {
        final pageData = await ApiService.instance.getBookshelfPage(accessToken);
        _md5 = pageData['md5']?.toString();
        _totalPages = int.tryParse(pageData['page']?.toString() ?? '1') ?? 1;

        // Also load groups
        if (_md5 != null) {
          try {
            _groups = await ApiService.instance.getgroupNew(accessToken, _md5!);
          } catch (_) {
            // Groups may fail, continue without
          }
        }
      }

      if (_currentPage > _totalPages) {
        _hasMore = false;
        _loading = false;
        notifyListeners();
        return;
      }

      // Step 2: Load books for current page
      final newBooks = await ApiService.instance.getBookshelfNew(
        accessToken,
        md5: _md5,
        page: _currentPage,
      );

      if (refresh) {
        _books = newBooks;
      } else {
        _books.addAll(newBooks);
      }
      _hasMore = _currentPage < _totalPages;
      _currentPage++;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadGroups(String accessToken) async {
    try {
      _groups = await ApiService.instance.getBookGroups(accessToken);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> addGroup(String accessToken, String name) async {
    try {
      final result = await ApiService.instance.addgroup(accessToken, name);
      if (result['isSuccess'] == true) {
        await loadGroups(accessToken);
        return true;
      }
      _error = result['errorMsg'] ?? '添加分组失败';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteGroup(String accessToken, String name) async {
    try {
      final result = await ApiService.instance.delgroup(accessToken, name);
      if (result['isSuccess'] == true) {
        _groups.removeWhere((g) => g.groupName == name);
        if (_selectedGroup == name) _selectedGroup = null;
        notifyListeners();
        return true;
      }
      _error = result['errorMsg'] ?? '删除分组失败';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> renameGroup(String accessToken, String oldname, String newname) async {
    try {
      final result = await ApiService.instance.editgroup(accessToken, oldname, newname);
      if (result['isSuccess'] == true) {
        await loadGroups(accessToken);
        return true;
      }
      _error = result['errorMsg'] ?? '重命名分组失败';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> setBookGroup(String accessToken, String groupName, String bookUrl) async {
    try {
      final result = await ApiService.instance.setgroup(
        accessToken,
        name: groupName == '全部' ? null : groupName,
        url: bookUrl,
      );
      if (result['isSuccess'] == true) {
        // Refresh bookshelf
        await loadBookshelf(accessToken, refresh: true);
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
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

  Future<bool> removeBook(String accessToken, Book book) async {
    try {
      final result = await ApiService.instance.deleteBook(accessToken, book);
      if (result['isSuccess'] == true) {
        _books.removeWhere((b) => b.bookUrl == book.bookUrl);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update a single book in the list (e.g., after progress save)
  void updateBook(Book updatedBook) {
    final idx = _books.indexWhere((b) => b.bookUrl == updatedBook.bookUrl);
    if (idx >= 0) {
      _books[idx] = updatedBook;
      notifyListeners();
    }
  }
}
