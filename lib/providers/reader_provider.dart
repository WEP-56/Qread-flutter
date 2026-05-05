import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/chapter.dart';
import '../services/api_service.dart';

class ReaderProvider extends ChangeNotifier {
  Book? _book;
  List<Chapter> _chapters = [];
  Set<int> _readChapters = {};
  int _currentChapterIndex = 0;
  String _content = '';
  bool _loadingChapters = false;
  bool _loadingContent = false;
  String? _error;

  // Prefetch cache: chapterIndex -> content text
  final Map<int, String> _prefetchCache = {};

  Book? get book => _book;
  List<Chapter> get chapters => _chapters;
  Set<int> get readChapters => _readChapters;
  int get currentChapterIndex => _currentChapterIndex;
  String get content => _content;
  bool get loadingChapters => _loadingChapters;
  bool get loadingContent => _loadingContent;
  String? get error => _error;
  Chapter? get currentChapter {
    if (_currentChapterIndex >= 0 && _currentChapterIndex < _chapters.length) {
      return _chapters[_currentChapterIndex];
    }
    return null;
  }
  bool get hasPrevious => _currentChapterIndex > 0;
  bool get hasNext => _currentChapterIndex < _chapters.length - 1;

  void setBook(Book book) {
    _book = book;
    _currentChapterIndex = book.durChapterIndex ?? 0;
    _content = '';
    _chapters = [];
    _readChapters = {};
    _prefetchCache.clear();
    _error = null;
    notifyListeners();
  }

  Future<void> loadChapters(String accessToken) async {
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

      if (_currentChapterIndex >= _chapters.length) {
        _currentChapterIndex = 0;
      }

      _loadingChapters = false;
      notifyListeners();

      await loadContent(accessToken, _currentChapterIndex);
    } catch (e) {
      _error = e.toString();
      _loadingChapters = false;
      notifyListeners();
    }
  }

  Future<void> loadContent(String accessToken, int chapterIndex, {bool silent = false}) async {
    if (_book == null || chapterIndex < 0 || chapterIndex >= _chapters.length) return;

    // Check prefetch cache first
    if (_prefetchCache.containsKey(chapterIndex)) {
      if (!silent) {
        _currentChapterIndex = chapterIndex;
        _content = _prefetchCache[chapterIndex]!;
        _loadingContent = false;
        _readChapters.add(chapterIndex);
        notifyListeners();
      }
      return;
    }

    if (!silent) {
      _currentChapterIndex = chapterIndex;
      _loadingContent = true;
      _error = null;
      notifyListeners();
    }

    try {
      final data = await ApiService.instance.getBookContentNew(
        accessToken,
        _book!.bookUrl ?? '',
        chapterIndex,
        _book!.origin ?? '',
        bookname: _book!.name,
      );
      final text = data['text']?.toString() ?? '';

      if (silent) {
        _prefetchCache[chapterIndex] = text;
        return;
      }

      _content = text;
      _loadingContent = false;
      notifyListeners();

      _readChapters.add(chapterIndex);
      try {
        await ApiService.instance.addreadchapter(
          accessToken,
          chapterIndex.toString(),
          _book!.bookUrl ?? '',
        );
      } catch (_) {}
    } catch (e) {
      if (!silent) {
        _error = e.toString();
        _loadingContent = false;
        notifyListeners();
      }
    }
  }

  Future<void> goToChapter(String accessToken, int index) async {
    if (index < 0 || index >= _chapters.length) return;
    await loadContent(accessToken, index);
  }

  Future<void> nextChapter(String accessToken) async {
    if (hasNext) {
      await loadContent(accessToken, _currentChapterIndex + 1);
    }
  }

  Future<void> previousChapter(String accessToken) async {
    if (hasPrevious) {
      await loadContent(accessToken, _currentChapterIndex - 1);
    }
  }

  Future<void> saveProgress(String accessToken, {double? pos}) async {
    if (_book == null) return;
    try {
      await ApiService.instance.saveBookProgress(
        accessToken,
        url: _book!.bookUrl,
        title: currentChapter?.title ?? _book!.durChapterTitle,
        index: _currentChapterIndex,
        pos: pos ?? 0.0,
      );
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
        durChapterTitle: currentChapter?.title ?? _book!.durChapterTitle,
        durChapterIndex: _currentChapterIndex,
        durChapterPos: pos?.toInt() ?? _book!.durChapterPos ?? 0,
        canUpdate: _book!.canUpdate,
        order: _book!.order,
        variable: _book!.variable,
      );
      notifyListeners();
    } catch (_) {}
  }
}
