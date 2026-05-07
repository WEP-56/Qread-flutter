import 'package:flutter/material.dart';

import 'engine/engine.dart';
import 'widgets/reader_theme.dart';

/// 阅读器核心状态
///
/// 将原 _ReaderPageState 中散落的全局变量集中到此类，
/// 便于跨组件共享和调试。

class ReaderState with ChangeNotifier {
  // ---- 视图状态 ----
  bool showController = false;
  bool showAutoPageControls = true;
  bool loadingDisplayedChapter = false;
  bool initialChapterOpened = false;

  // ---- 阅读设置 ----
  double fontSize = 18.0;
  double lineHeight = 1.8;
  double autoPageInterval = 12.0;
  bool autoNext = true;
  String theme = 'light';
  String pageMode = 'paged';

  // ---- 章节状态 ----
  String displayedContent = '';
  int chapterRequestSerial = 0;
  int laidOutChapterIndex = -1;
  int chapterPosition = 0;
  int currentPage = 0;
  int? pendingChapterPosition;
  bool pendingOpenChapterAtEnd = false;

  // ---- 排版结果 ----
  List<ReaderParagraph> paragraphs = [];
  List<PageSlice> pages = [];
  Map<int, int> paragraphPageLookup = {};
  ChapterLayout? currentLayout;

  // ---- TTS ----
  bool ttsReading = false;
  bool continueTtsOnNextChapter = false;
  int ttsParagraphIndex = -1;
  int? ttsSleepMinutes;

  // ---- 自动翻页 ----
  bool autoPageRunning = false;

  // ---- 书籍类型 ----
  bool isComic = false;

  // ---- 元信息 ----
  DateTime now = DateTime.now();
  int? batteryLevel;
  double? chapterSliderValue;

  // ---- 视口 ----
  Size? pagedViewportSize;

  // ---- 缓存 ----
  final Map<String, ChapterLayout> layoutCache = {};

  void notify() => notifyListeners();

  // ---- 便捷方法 ----

  ReaderTheme get currentTheme => ReaderTheme.byName(theme);

  int displayedChapterIndex(int bookDurChapterIndex) {
    if (laidOutChapterIndex >= 0) return laidOutChapterIndex;
    return bookDurChapterIndex;
  }

  bool hasPreviousChapter(int chapterIndex) => chapterIndex > 0;

  bool hasNextChapter(int chapterIndex, int totalChapters) =>
      chapterIndex < totalChapters - 1;

  /// 消费待定位置
  void consumePendingPosition() {
    pendingChapterPosition = null;
    pendingOpenChapterAtEnd = false;
  }

  /// 解析目标章节位置
  int resolveTargetChapterPosition(int bookDurChapterIndex, int? bookDurChapterPos) {
    if (pendingOpenChapterAtEnd) {
      return 1 << 30;
    }
    if (pendingChapterPosition != null) {
      return pendingChapterPosition!;
    }
    if (laidOutChapterIndex == displayedChapterIndex(bookDurChapterIndex)) {
      return chapterPosition;
    }
    if (bookDurChapterIndex == displayedChapterIndex(bookDurChapterIndex)) {
      final savedPos = bookDurChapterPos ?? 0;
      if (savedPos > 1) return savedPos;
    }
    return 0;
  }

  int pageIndexForPosition(int position) {
    if (pages.isEmpty) return 0;
    if (position >= (1 << 29)) return pages.length - 1;
    for (var i = 0; i < pages.length; i++) {
      if (position <= pages[i].endPosition) return i;
    }
    return pages.length - 1;
  }

  String pageIndicatorLabel() {
    if (isComic || pageMode == 'scroll') {
      final total = paragraphs.isEmpty ? 1 : paragraphs.length;
      return '1/$total';
    }
    final total = pages.isEmpty ? 1 : pages.length;
    final current = total == 0 ? 1 : (currentPage + 1).clamp(1, total);
    return '$current/$total';
  }

  String formatTime() {
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String batteryLabel() => batteryLevel == null ? '--' : '$batteryLevel%';
}
