import 'package:flutter/material.dart';

import 'models.dart';
import 'pagination_engine.dart';

/// 页面工厂
///
/// 管理当前/前一页/后一页的排版数据，支持跨章节预加载。
/// 参照 legado 的 TextPageFactory 设计：
/// - 维护 curPage / prevPage / nextPage 三个滑动窗口
/// - 章节末尾时 nextPage 自动指向下一章首页
/// - 章节开头时 prevPage 自动指向上一章末页
///
/// 这使得翻页动画可以跨章节，不会出现空白间隙。

typedef ChapterContentLoader = Future<String> Function(int chapterIndex);
typedef OnChapterSwitched = void Function(int chapterIndex, int pageIndex);

class PageFactory {
  final PaginationEngine _engine = PaginationEngine();

  /// 布局缓存 key → ChapterLayout
  final Map<String, ChapterLayout> _layoutCache = {};

  /// 当前章节排版结果
  ChapterLayout? _currentLayout;

  /// 预取的下一章排版结果
  ChapterLayout? _prefetchedNextLayout;

  /// 预取的上一章排版结果
  ChapterLayout? _prefetchedPrevLayout;

  /// 当前页码
  int _currentPageIndex = 0;

  /// 章节内容加载器
  ChapterContentLoader? _contentLoader;

  /// 当前视口参数（用于缓存判断）
  double _fontSize = 18.0;
  double _lineHeight = 1.8;
  Size _viewportSize = Size.zero;
  double _safeTop = 0;
  double _safeBottom = 0;
  int _currentChapterIndex = -1;

  // ---- 公开访问器 ----

  ChapterLayout? get currentLayout => _currentLayout;
  int get currentPageIndex => _currentPageIndex;
  int get currentChapterIndex => _currentChapterIndex;

  /// 当前页
  PageSlice? get currentPage {
    if (_currentLayout == null ||
        _currentPageIndex < 0 ||
        _currentPageIndex >= _currentLayout!.pages.length) {
      return null;
    }
    return _currentLayout!.pages[_currentPageIndex];
  }

  /// 下一页（可能跨章节）
  PageSlice? get nextPage {
    if (_currentLayout == null) return null;
    if (_currentPageIndex + 1 < _currentLayout!.pages.length) {
      return _currentLayout!.pages[_currentPageIndex + 1];
    }
    // 当前章节末尾 → 下一章首页
    return _prefetchedNextLayout?.pages.isNotEmpty == true
        ? _prefetchedNextLayout!.pages.first
        : null;
  }

  /// 上一页（可能跨章节）
  PageSlice? get prevPage {
    if (_currentLayout == null) return null;
    if (_currentPageIndex > 0) {
      return _currentLayout!.pages[_currentPageIndex - 1];
    }
    // 当前章节开头 → 上一章末页
    return _prefetchedPrevLayout?.pages.isNotEmpty == true
        ? _prefetchedPrevLayout!.pages.last
        : null;
  }

  /// 总页数
  int get pageCount => _currentLayout?.pages.length ?? 0;

  /// 是否在当前章节最后一页
  bool get isLastPageOfChapter =>
      _currentLayout != null &&
      _currentPageIndex >= _currentLayout!.pages.length - 1;

  /// 是否在当前章节第一页
  bool get isFirstPageOfChapter => _currentPageIndex <= 0;

  bool get hasNextPage => nextPage != null;
  bool get hasPrevPage => prevPage != null;

  /// 是否有下一章
  bool get hasNextChapter => _prefetchedNextLayout != null;

  /// 是否有上一章
  bool get hasPrevChapter => _prefetchedPrevLayout != null;

  // ---- 配置 ----

  void configure({
    required double fontSize,
    required double lineHeight,
    required Size viewportSize,
    required double safeTop,
    required double safeBottom,
    required ChapterContentLoader contentLoader,
  }) {
    _fontSize = fontSize;
    _lineHeight = lineHeight;
    _viewportSize = viewportSize;
    _safeTop = safeTop;
    _safeBottom = safeBottom;
    _contentLoader = contentLoader;
  }

  // ---- 核心操作 ----

  /// 排版当前章节
  ///
  /// [content] 章节内容
  /// [chapterTitle] 章节标题
  /// [chapterIndex] 章节索引
  /// [targetPosition] 目标位置（字符偏移），0=首页，>= 1<<29=末页
  /// [totalChapters] 总章节数（用于预取判断）
  ChapterLayout layoutChapter({
    required String content,
    required String? chapterTitle,
    required int chapterIndex,
    int targetPosition = 0,
    int? totalChapters,
  }) {
    _currentChapterIndex = chapterIndex;

    // 检查缓存
    final cacheKey = ChapterLayout.cacheKey(
      chapterIndex,
      content.hashCode,
      _fontSize,
      _lineHeight,
      _viewportSize.width,
      _viewportSize.height,
      'paged',
    );

    if (_layoutCache.containsKey(cacheKey)) {
      _currentLayout = _layoutCache[cacheKey]!;
    } else {
      _currentLayout = _engine.paginate(
        content: content,
        chapterTitle: chapterTitle,
        chapterIndex: chapterIndex,
        fontSize: _fontSize,
        lineHeight: _lineHeight,
        viewportSize: _viewportSize,
        safeTop: _safeTop,
        safeBottom: _safeBottom,
      );
      _layoutCache[cacheKey] = _currentLayout!;
    }

    // 确定目标页码
    _currentPageIndex = _engine.pageIndexForPosition(
      _currentLayout!.pages,
      targetPosition,
    ).clamp(0, _currentLayout!.pages.length - 1);

    return _currentLayout!;
  }

  /// 前进一页，返回是否跨章节
  ///
  /// 如果返回 true，表示已经切换到下一章，调用方需要
  /// 加载新章节内容并调用 [layoutChapter]。
  bool moveNext() {
    if (_currentLayout == null) return false;

    if (_currentPageIndex + 1 < _currentLayout!.pages.length) {
      _currentPageIndex++;
      return false;
    }

    // 当前章节末尾
    if (_prefetchedNextLayout != null) {
      // 切换到预取的下一章
      _switchToPrefetchedNext();
      return true;
    }

    return false; // 没有下一页了
  }

  /// 后退一页，返回是否跨章节
  bool movePrev() {
    if (_currentLayout == null) return false;

    if (_currentPageIndex > 0) {
      _currentPageIndex--;
      return false;
    }

    // 当前章节开头
    if (_prefetchedPrevLayout != null) {
      _switchToPrefetchedPrev();
      return true;
    }

    return false; // 没有上一页了
  }

  /// 跳转到指定页码
  void jumpToPage(int pageIndex) {
    if (_currentLayout == null) return;
    _currentPageIndex = pageIndex.clamp(0, _currentLayout!.pages.length - 1);
  }

  /// 根据位置跳转
  void jumpToPosition(int position) {
    if (_currentLayout == null) return;
    _currentPageIndex = _engine
        .pageIndexForPosition(_currentLayout!.pages, position)
        .clamp(0, _currentLayout!.pages.length - 1);
  }

  // ---- 预取 ----

  /// 预取下一章排版
  Future<void> prefetchNextChapter({
    required int nextChapterIndex,
    required String? nextChapterTitle,
  }) async {
    if (_contentLoader == null) return;
    try {
      final content = await _contentLoader!(nextChapterIndex);
      final cacheKey = ChapterLayout.cacheKey(
        nextChapterIndex,
        content.hashCode,
        _fontSize,
        _lineHeight,
        _viewportSize.width,
        _viewportSize.height,
        'paged',
      );

      if (_layoutCache.containsKey(cacheKey)) {
        _prefetchedNextLayout = _layoutCache[cacheKey]!;
      } else {
        _prefetchedNextLayout = _engine.paginate(
          content: content,
          chapterTitle: nextChapterTitle,
          chapterIndex: nextChapterIndex,
          fontSize: _fontSize,
          lineHeight: _lineHeight,
          viewportSize: _viewportSize,
          safeTop: _safeTop,
          safeBottom: _safeBottom,
        );
        _layoutCache[cacheKey] = _prefetchedNextLayout!;
      }
    } catch (_) {
      _prefetchedNextLayout = null;
    }
  }

  /// 预取上一章排版
  Future<void> prefetchPrevChapter({
    required int prevChapterIndex,
    required String? prevChapterTitle,
  }) async {
    if (_contentLoader == null) return;
    try {
      final content = await _contentLoader!(prevChapterIndex);
      final cacheKey = ChapterLayout.cacheKey(
        prevChapterIndex,
        content.hashCode,
        _fontSize,
        _lineHeight,
        _viewportSize.width,
        _viewportSize.height,
        'paged',
      );

      if (_layoutCache.containsKey(cacheKey)) {
        _prefetchedPrevLayout = _layoutCache[cacheKey]!;
      } else {
        _prefetchedPrevLayout = _engine.paginate(
          content: content,
          chapterTitle: prevChapterTitle,
          chapterIndex: prevChapterIndex,
          fontSize: _fontSize,
          lineHeight: _lineHeight,
          viewportSize: _viewportSize,
          safeTop: _safeTop,
          safeBottom: _safeBottom,
        );
        _layoutCache[cacheKey] = _prefetchedPrevLayout!;
      }
    } catch (_) {
      _prefetchedPrevLayout = null;
    }
  }

  /// 清除预取数据
  void clearPrefetch() {
    _prefetchedNextLayout = null;
    _prefetchedPrevLayout = null;
  }

  /// 清除所有缓存
  void clearCache() {
    _layoutCache.clear();
    _prefetchedNextLayout = null;
    _prefetchedPrevLayout = null;
  }

  /// 重置
  void reset() {
    _currentLayout = null;
    _currentPageIndex = 0;
    _currentChapterIndex = -1;
    clearPrefetch();
  }

  // ---- 内部方法 ----

  void _switchToPrefetchedNext() {
    _prefetchedPrevLayout = _currentLayout;
    _currentLayout = _prefetchedNextLayout;
    _prefetchedNextLayout = null;
    _currentChapterIndex = _currentLayout?.chapterIndex ?? _currentChapterIndex;
    _currentPageIndex = 0;
  }

  void _switchToPrefetchedPrev() {
    _prefetchedNextLayout = _currentLayout;
    _currentLayout = _prefetchedPrevLayout;
    _prefetchedPrevLayout = null;
    _currentChapterIndex = _currentLayout?.chapterIndex ?? _currentChapterIndex;
    _currentPageIndex = _currentLayout != null
        ? _currentLayout!.pages.length - 1
        : 0;
  }
}
