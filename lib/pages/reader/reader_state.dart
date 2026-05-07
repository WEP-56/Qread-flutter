import 'package:flutter/material.dart';

import 'engine/engine.dart';
import 'widgets/reader_theme.dart';
import 'widgets/controller_overlay.dart';

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

  // ---- 预排版缓存 ----
  /// 预排版的下一章布局（包含 content 和 chapterTitle）
  ChapterLayout? prefetchedNextLayout;
  String? prefetchedNextContent;
  String? prefetchedNextTitle;
  int prefetchedNextChapterIndex = -1;

  /// 预排版的上一章布局
  ChapterLayout? prefetchedPrevLayout;
  String? prefetchedPrevContent;
  String? prefetchedPrevTitle;
  int prefetchedPrevChapterIndex = -1;

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
  ///
  /// 优先级：
  /// 1. openAtEnd 标记 → 返回极大值（映射到最后一页）
  /// 2. pendingChapterPosition → 直接使用
  /// 3. 如果正在请求的章节与已排版章节相同 → 使用当前 chapterPosition
  /// 4. 如果请求的章节与 book 保存的章节相同 → 使用保存的位置
  /// 5. 默认 → 0（首页）
  int resolveTargetChapterPosition(int bookDurChapterIndex, int? bookDurChapterPos) {
    // 最高优先级：跳到末尾
    if (pendingOpenChapterAtEnd) {
      return 1 << 30;
    }
    // 次高优先级：显式指定的位置
    if (pendingChapterPosition != null) {
      return pendingChapterPosition!;
    }
    // 以下分支只在 _rebuildPages（同章节重排）时才会走到
    // 对于 _openChapter（新章节），前两个分支一定能覆盖
    if (laidOutChapterIndex >= 0 &&
        laidOutChapterIndex == displayedChapterIndex(bookDurChapterIndex)) {
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

  /// 胶囊模式——控制器根据此值切换悬浮胶囊内容
  ControllerCapsuleMode get capsuleMode {
    if (autoPageRunning) return ControllerCapsuleMode.autoPage;
    if (ttsReading || ttsParagraphIndex >= 0) return ControllerCapsuleMode.tts;
    return ControllerCapsuleMode.normal;
  }
}
