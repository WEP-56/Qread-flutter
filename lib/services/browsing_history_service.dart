import 'dart:convert';

import '../models/book.dart';
import 'storage_service.dart';

class BrowsingHistoryService {
  static BrowsingHistoryService? _instance;
  static BrowsingHistoryService get instance =>
      _instance ??= BrowsingHistoryService._();

  static const _keyHistory = 'profile_browsing_history_books';
  static const _maxItems = 30;

  BrowsingHistoryService._();

  Future<List<Book>> loadHistory() async {
    final storage = await StorageService.instance;
    final raw = storage.readString(_keyHistory);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((item) => Book.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    } catch (_) {
      return [];
    }
  }

  Future<void> recordBook(Book book) async {
    final history = await loadHistory();
    history.removeWhere((item) => item.bookUrl == book.bookUrl);
    history.insert(0, _sanitizeBook(book));
    if (history.length > _maxItems) {
      history.removeRange(_maxItems, history.length);
    }

    final storage = await StorageService.instance;
    await storage.setString(
      _keyHistory,
      jsonEncode(history.map((item) => item.toJson()).toList()),
    );
  }

  Book _sanitizeBook(Book book) {
    return Book(
      bookUrl: book.bookUrl,
      name: book.name,
      author: book.author,
      coverUrl: book.coverUrl,
      customCoverUrl: book.customCoverUrl,
      tocUrl: book.tocUrl,
      origin: book.origin,
      originName: book.originName,
      intro: book.intro,
      type: book.type,
      totalChapterNum: book.totalChapterNum,
      latestChapterTitle: book.latestChapterTitle,
      latestChapterTime: book.latestChapterTime,
      lastCheckTime: book.lastCheckTime,
    );
  }
}
