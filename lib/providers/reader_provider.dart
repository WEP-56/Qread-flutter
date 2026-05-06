import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../services/api_service.dart';
import '../services/local_cache_service.dart';
import '../services/storage_service.dart';

class ReaderProvider extends ChangeNotifier {
  Book? _book;
  List<Chapter> _chapters = [];
  Set<int> _readChapters = {};
  bool _loadingChapters = false;
  String? _error;

  // Prefetch cache: chapterIndex -> content text
  final Map<int, String> _prefetchCache = {};

  bool get useReplaceRule => _book?.useReplaceRule != false;

  Book? get book => _book;
  List<Chapter> get chapters => _chapters;
  Set<int> get readChapters => _readChapters;
  bool get loadingChapters => _loadingChapters;
  String? get error => _error;

  void setBook(Book book) {
    _book = book;
    _chapters = [];
    _readChapters = {};
    _prefetchCache.clear();
    _error = null;
    notifyListeners();
  }

  Future<void> loadChapters(String accessToken,
      {bool loadInitialContent = true}) async {
    if (_book == null) return;

    _loadingChapters = true;
    _error = null;
    notifyListeners();

    try {
      _chapters = await ApiService.instance.getChapterListNew(
        accessToken,
        _book!.bookUrl ?? '',
        _book!.origin ?? '',
        bookname: _book!.name,
        useReplaceRule: _book!.useReplaceRule == false ? 0 : 1,
      );

      try {
        final readStr = await ApiService.instance.getBookread(
          accessToken,
          _book!.bookUrl ?? '',
        );
        if (readStr.isNotEmpty) {
          _readChapters = readStr
              .split(',')
              .map((s) => int.tryParse(s.trim()) ?? -1)
              .where((i) => i >= 0)
              .toSet();
        }
      } catch (_) {}

      _loadingChapters = false;
      notifyListeners();
      if (loadInitialContent) {
        final initialIndex =
            (_book?.durChapterIndex ?? 0).clamp(0, _chapters.length - 1);
        await getChapterContent(accessToken, initialIndex);
      }
    } catch (e) {
      _error = e.toString();
      _loadingChapters = false;
      notifyListeners();
    }
  }

  Future<String> getChapterContent(String accessToken, int chapterIndex) async {
    if (_book == null || chapterIndex < 0 || chapterIndex >= _chapters.length) {
      return '';
    }

    if (_prefetchCache.containsKey(chapterIndex)) {
      return _prefetchCache[chapterIndex]!;
    }

    final cachedContent = await _readCachedChapterContent(chapterIndex);
    if (cachedContent != null) {
      _prefetchCache[chapterIndex] = cachedContent;
      return cachedContent;
    }

    final data = await ApiService.instance.getBookContentNew(
      accessToken,
      _book!.bookUrl ?? '',
      chapterIndex,
      _book!.origin ?? '',
      bookname: _book!.name,
      useReplaceRule: _book!.useReplaceRule == false ? 0 : 1,
    );
    final text = data['text']?.toString() ?? '';
    _prefetchCache[chapterIndex] = text;
    await _writeCachedChapterContent(chapterIndex, text);
    return text;
  }

  Future<void> markReadChapter(String accessToken, int chapterIndex) async {
    if (_book == null || chapterIndex < 0) return;
    _readChapters.add(chapterIndex);
    notifyListeners();
    try {
      await ApiService.instance.addreadchapter(
        accessToken,
        chapterIndex.toString(),
        _book!.bookUrl ?? '',
      );
    } catch (_) {}
  }

  Future<void> prefetchAround(String accessToken, int centerIndex) async {
    if (_book == null || _chapters.isEmpty) return;
    final storage = await StorageService.instance;
    final cacheCount = storage.readerChapterCacheCount;
    final keepIndices = <int>{};
    final prevCount = (cacheCount - 1) ~/ 2;
    final nextCount = cacheCount - 1 - prevCount;
    final startIndex = (centerIndex - prevCount).clamp(0, _chapters.length - 1);
    final lastIndex = (centerIndex + nextCount).clamp(0, _chapters.length - 1);
    for (var index = startIndex; index <= lastIndex; index++) {
      keepIndices.add(index);
      if (!_prefetchCache.containsKey(index)) {
        try {
          await getChapterContent(accessToken, index);
        } catch (_) {}
      }
    }

    _prefetchCache.removeWhere((key, _) => !keepIndices.contains(key));
    await _pruneChapterCaches(keepIndices);
  }

  Future<void> clearLocalChapterCache() async {
    _prefetchCache.clear();
  }

  Future<void> saveProgress(
    String accessToken, {
    required int chapterIndex,
    required double pos,
    String? chapterTitle,
  }) async {
    if (_book == null) return;
    final savedIndex = chapterIndex;
    final savedTitle = chapterTitle ??
        ((chapterIndex >= 0 && chapterIndex < _chapters.length)
            ? _chapters[chapterIndex].title
            : null) ??
        _book!.durChapterTitle;
    final savedPos = pos;
    try {
      await ApiService.instance.saveBookProgress(
        accessToken,
        url: _book!.bookUrl,
        title: savedTitle,
        index: savedIndex,
        pos: savedPos,
      );
      if (_book != null) {
        _book = Book(
          bookUrl: _book!.bookUrl,
          name: _book!.name,
          author: _book!.author,
          coverUrl: _book!.coverUrl,
          intro: _book!.intro,
          customCoverUrl: _book!.customCoverUrl,
          tocUrl: _book!.tocUrl,
          origin: _book!.origin,
          originName: _book!.originName,
          type: _book!.type,
          group: _book!.group,
          latestChapterTitle: _book!.latestChapterTitle,
          latestChapterTime: _book!.latestChapterTime,
          lastCheckTime: _book!.lastCheckTime,
          lastCheckCount: _book!.lastCheckCount,
          totalChapterNum: _book!.totalChapterNum,
          durChapterTitle: savedTitle,
          durChapterIndex: savedIndex,
          durChapterPos: savedPos.toInt(),
          canUpdate: _book!.canUpdate,
          order: _book!.order,
          useReplaceRule: _book!.useReplaceRule,
          variable: _book!.variable,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<String?> _readCachedChapterContent(int chapterIndex) async {
    if (_book?.bookUrl == null) return null;
    return LocalCacheService.instance.readChapterContent(
      bookUrl: _book!.bookUrl!,
      chapterIndex: chapterIndex,
      useReplaceRule: useReplaceRule,
    );
  }

  Future<void> _writeCachedChapterContent(int chapterIndex, String text) async {
    if (_book?.bookUrl == null || text.isEmpty) return;
    await LocalCacheService.instance.writeChapterContent(
      bookUrl: _book!.bookUrl!,
      chapterIndex: chapterIndex,
      useReplaceRule: useReplaceRule,
      content: text,
    );
  }

  Future<void> _pruneChapterCaches(Set<int> keepIndices) async {
    if (_book?.bookUrl == null) return;
    await LocalCacheService.instance.pruneChapterCache(
      bookUrl: _book!.bookUrl!,
      useReplaceRule: useReplaceRule,
      keepIndices: keepIndices,
    );
  }
}
