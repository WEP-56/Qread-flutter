import 'dart:async';

import 'package:battery_plus/battery_plus.dart' as bp;
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants.dart';
import '../../models/book.dart';
import '../../models/bookmark.dart';
import '../../models/chapter.dart';
import '../../providers/reader_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../../services/tts_service.dart';
import 'engine/engine.dart';
import 'reader_state.dart';
import 'widgets/widgets.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({Key? key}) : super(key: key);

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  static const _keyFontSize = 'reader_font_size';
  static const _keyLineHeight = 'reader_line_height';
  static const _keyAutoNext = 'reader_auto_next';
  static const _keyTheme = 'reader_theme';
  static const _keyPageMode = 'reader_page_mode';
  static const _keyAutoPageInterval = 'reader_auto_page_interval';
  static const _keyProgressChapterPrefix = 'reader_progress_ch_';
  static const _keyProgressPosPrefix = 'reader_progress_pos_';
  static const _keyScreenWakelock = 'reader_screen_wakelock';
  static const _keyShowPageNumber = 'reader_show_page_number';
  static const _keyVolumeKeyFlip = 'reader_volume_key_flip';
  static const _keyShowBottomBar = 'reader_show_bottom_bar';
  static const _keyShowTopBar = 'reader_show_top_bar';

  late PageController _pageController;
  final ScrollController _comicScrollController = ScrollController();
  final ScrollController _novelScrollController = ScrollController();
  final TtsService _tts = TtsService();
  final bp.Battery _battery = bp.Battery();
  final PaginationEngine _paginationEngine = PaginationEngine();

  ReaderProvider? _readerProvider;
  Timer? _metaTimer;
  Timer? _autoPageTimer;
  Timer? _ttsSleepTimer;

  String? _token;
  String? _bookUrl;

  List<Bookmark> _bookmarks = [];
  Set<int> _bookmarkChapterIndices = {};
  List<GlobalKey> _paragraphKeys = [];

  // 使用集中状态对象
  final ReaderState _state = ReaderState();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadSettings();
    _comicScrollController.addListener(_onComicScroll);
    _tts.addListener(_onTtsStateChanged);
    _startMetaTicker();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initBook());
  }

  @override
  void dispose() {
    _readerProvider?.removeListener(_onProviderChanged);
    _metaTimer?.cancel();
    _autoPageTimer?.cancel();
    _ttsSleepTimer?.cancel();
    _comicScrollController.removeListener(_onComicScroll);
    _comicScrollController.dispose();
    _novelScrollController.dispose();
    _pageController.dispose();
    _tts.removeListener(_onTtsStateChanged);
    _tts.stop();
    _saveProgressSync();
    super.dispose();
  }

  // ============================================================
  // 设置持久化
  // ============================================================

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _state.fontSize = prefs.getDouble(_keyFontSize) ?? 18.0;
      _state.lineHeight = prefs.getDouble(_keyLineHeight) ?? 1.8;
      _state.autoNext = prefs.getBool(_keyAutoNext) ?? true;
      _state.theme = prefs.getString(_keyTheme) ?? 'light';
      _state.pageMode = prefs.getString(_keyPageMode) ?? 'paged';
      _state.autoPageInterval =
          prefs.getDouble(_keyAutoPageInterval) ?? 12.0;
      _state.screenWakelock = prefs.getBool(_keyScreenWakelock) ?? true;
      _state.showPageNumber = prefs.getBool(_keyShowPageNumber) ?? true;
      _state.volumeKeyFlip = prefs.getBool(_keyVolumeKeyFlip) ?? false;
      _state.showBottomBar = prefs.getBool(_keyShowBottomBar) ?? true;
      _state.showTopBar = prefs.getBool(_keyShowTopBar) ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, _state.fontSize);
    await prefs.setDouble(_keyLineHeight, _state.lineHeight);
    await prefs.setBool(_keyAutoNext, _state.autoNext);
    await prefs.setString(_keyTheme, _state.theme);
    await prefs.setString(_keyPageMode, _state.pageMode);
    await prefs.setDouble(_keyAutoPageInterval, _state.autoPageInterval);
    await prefs.setBool(_keyScreenWakelock, _state.screenWakelock);
    await prefs.setBool(_keyShowPageNumber, _state.showPageNumber);
    await prefs.setBool(_keyVolumeKeyFlip, _state.volumeKeyFlip);
    await prefs.setBool(_keyShowBottomBar, _state.showBottomBar);
    await prefs.setBool(_keyShowTopBar, _state.showTopBar);
  }

  // ============================================================
  // 元信息（时间、电量）
  // ============================================================

  void _startMetaTicker() {
    _refreshBattery();
    _metaTimer?.cancel();
    _metaTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _refreshBattery();
      if (mounted) setState(() => _state.now = DateTime.now());
    });
  }

  Future<void> _refreshBattery() async {
    try {
      final level = await _battery.batteryLevel;
      if (!mounted) return;
      setState(() {
        _state.batteryLevel = level;
        _state.now = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _state.now = DateTime.now());
    }
  }

  // ============================================================
  // 初始化
  // ============================================================

  void _initBook() {
    final book = ModalRoute.of(context)?.settings.arguments as Book?;
    if (book == null) return;
    _token = context.read<UserProvider>().token;
    _state.isComic = book.type == 2;
    _bookUrl = book.bookUrl;
    _tts.init();
    final provider = context.read<ReaderProvider>();
    _readerProvider = provider;
    provider.setBook(book);
    provider.addListener(_onProviderChanged);
    if (_token != null) {
      provider.loadChapters(_token!, loadInitialContent: false);
      _loadBookmarks();
    }
  }

  Future<void> _loadBookmarks() async {
    if (_token == null || _bookUrl == null) return;
    try {
      final rawList =
          await ApiService.instance.getBookmarks(_token!, _bookUrl!);
      final marks = rawList.map((e) => Bookmark.fromJson(e)).toList();
      if (!mounted) return;
      setState(() {
        _bookmarks = marks;
        _bookmarkChapterIndices = marks
            .where((m) => m.chapterIndex != null)
            .map((m) => m.chapterIndex!)
            .toSet();
      });
    } catch (_) {}
  }

  void _onProviderChanged() {
    if (!mounted) return;
    final provider = context.read<ReaderProvider>();
    if (_token != null &&
        !_state.initialChapterOpened &&
        !provider.loadingChapters &&
        provider.chapters.isNotEmpty) {
      _state.initialChapterOpened = true;
      final initialIndex = (provider.book?.durChapterIndex ?? 0)
          .clamp(0, provider.chapters.length - 1);
      // 优先从本地读取页级进度
      _loadProgressLocalPos().then((localPos) {
        if (!mounted) return;
        int chapterPos;
        if (localPos != null && localPos > 1) {
          chapterPos = localPos.round();
        } else {
          final serverPos = provider.book?.durChapterPos ?? 0;
          chapterPos = serverPos > 1 ? serverPos : 0;
        }
        final openAtEnd = chapterPos > 1 << 29;
        _openChapter(
          initialIndex,
          chapterPosition: chapterPos,
          openAtEnd: openAtEnd,
        );
      });
    }
  }

  void _onTtsStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onComicScroll() {
    if (!_state.autoNext || !_comicScrollController.hasClients) return;
    final maxExtent = _comicScrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return;
    if (_comicScrollController.position.pixels >= maxExtent - 100) {
      final provider = context.read<ReaderProvider>();
      if (_state.hasNextChapter(
              _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0),
              provider.chapters.length) &&
          !_state.loadingDisplayedChapter &&
          _token != null) {
        _goToNextChapter();
      }
    }
  }

  // ============================================================
  // 进度与位置
  // ============================================================

  double _getProgress() {
    if (_state.isComic) {
      if (!_comicScrollController.hasClients) return 0.0;
      final max = _comicScrollController.position.maxScrollExtent;
      if (max <= 0) return 0.0;
      return (_comicScrollController.offset / max).clamp(0.0, 1.0);
    }
    if (_state.pageMode == 'scroll') {
      if (!_novelScrollController.hasClients) return 0.0;
      final max = _novelScrollController.position.maxScrollExtent;
      if (max <= 0) return 0.0;
      return (_novelScrollController.offset / max).clamp(0.0, 1.0);
    }
    return _state.chapterPosition.toDouble();
  }

  int _activePageIndex() {
    if (_pageController.hasClients) {
      final page = _pageController.page;
      if (page != null) {
        return page
            .round()
            .clamp(0, _state.pages.isEmpty ? 0 : _state.pages.length - 1);
      }
    }
    if (_state.pages.isEmpty) return 0;
    return _state.currentPage.clamp(0, _state.pages.length - 1);
  }

  Chapter? _displayedChapter(ReaderProvider provider) {
    final index = _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0);
    if (index < 0 || index >= provider.chapters.length) return null;
    return provider.chapters[index];
  }

  void _saveProgressSync() {
    if (_token == null) return;
    final provider = _readerProvider;
    if (provider == null) return;
    final chapterIndex =
        _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0);
    final chapter = chapterIndex >= 0 && chapterIndex < provider.chapters.length
        ? provider.chapters[chapterIndex]
        : null;
    final pos = _getProgress();
    provider.saveProgress(
      _token!,
      chapterIndex: chapterIndex,
      chapterTitle: chapter?.title,
      pos: pos,
    );
    // 同步保存到本地
    _saveProgressLocal(chapterIndex, pos);
  }

  Future<void> _saveProgress({double? pos}) async {
    if (_token == null) return;
    final provider = context.read<ReaderProvider>();
    final chapter = _displayedChapter(provider);
    final chapterIndex = _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0);
    final savePos = pos ?? _getProgress();

    // 保存到远端
    await provider.saveProgress(
      _token!,
      chapterIndex: chapterIndex,
      chapterTitle: chapter?.title,
      pos: savePos,
    );

    // 同时保存到本地（确保页级进度不丢失）
    _saveProgressLocal(chapterIndex, savePos);
  }

  /// 保存阅读进度到本地 SharedPreferences
  void _saveProgressLocal(int chapterIndex, double pos) {
    if (_bookUrl == null) return;
    final encodedUrl = _bookUrl!.replaceAll('/', '_').replaceAll(':', '_');
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('$_keyProgressChapterPrefix$encodedUrl', chapterIndex);
      prefs.setDouble('$_keyProgressPosPrefix$encodedUrl', pos);
    });
  }

  /// 从本地读取阅读进度
  Future<int?> _loadProgressLocalChapter() async {
    if (_bookUrl == null) return null;
    final encodedUrl = _bookUrl!.replaceAll('/', '_').replaceAll(':', '_');
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_keyProgressChapterPrefix$encodedUrl');
  }

  Future<double?> _loadProgressLocalPos() async {
    if (_bookUrl == null) return null;
    final encodedUrl = _bookUrl!.replaceAll('/', '_').replaceAll(':', '_');
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('$_keyProgressPosPrefix$encodedUrl');
  }

  // ============================================================
  // 章节加载
  // ============================================================

  Future<void> _openChapter(
    int chapterIndex, {
    int chapterPosition = 0,
    bool openAtEnd = false,
  }) async {
    final token = _token;
    if (token == null) return;
    final provider = context.read<ReaderProvider>();
    if (chapterIndex < 0 || chapterIndex >= provider.chapters.length) return;

    final requestSerial = ++_state.chapterRequestSerial;
    _state.pendingChapterPosition = openAtEnd ? null : chapterPosition;
    _state.pendingOpenChapterAtEnd = openAtEnd;

    // 检查是否已预排版——如果是，直接同步切换（零等待）
    ChapterLayout? preLayout;
    String? preContent;
    String? preTitle;

    if (_state.prefetchedNextChapterIndex == chapterIndex &&
        _state.prefetchedNextLayout != null) {
      preLayout = _state.prefetchedNextLayout;
      preContent = _state.prefetchedNextContent;
      preTitle = _state.prefetchedNextTitle;
    } else if (_state.prefetchedPrevChapterIndex == chapterIndex &&
        _state.prefetchedPrevLayout != null) {
      preLayout = _state.prefetchedPrevLayout;
      preContent = _state.prefetchedPrevContent;
      preTitle = _state.prefetchedPrevTitle;
    }

    ChapterLayout layout;
    String content;
    String? chapterTitle;

    if (preLayout != null && preContent != null) {
      // 使用预排版结果，跳过网络请求和排版计算
      layout = preLayout;
      content = preContent;
      chapterTitle = preTitle;
    } else {
      // 走完整的异步流程
      content = await provider.getChapterContent(token, chapterIndex);
      if (!mounted || requestSerial != _state.chapterRequestSerial) return;

      chapterTitle = chapterIndex < provider.chapters.length
          ? provider.chapters[chapterIndex].title
          : null;

      layout = _layoutChapter(
        content: content,
        chapterTitle: chapterTitle,
        chapterIndex: chapterIndex,
        targetPosition: 0,
      );
    }

    // 解析目标位置
    final targetPosition =
        _state.resolveTargetChapterPosition(
          provider.book?.durChapterIndex ?? 0,
          provider.book?.durChapterPos?.round(),
        );

    // 用新排版结果计算目标页码
    final targetPage = _paginationEngine
        .pageIndexForPosition(layout.pages, targetPosition)
        .clamp(0, layout.pages.length - 1);
    final normalizedPosition = layout.pages.isEmpty
        ? 0
        : layout.pages[targetPage].startPosition;

    // 先创建新 PageController，再 setState
    final oldController = _pageController;
    _pageController = PageController(initialPage: targetPage);

    // 一次性更新所有状态
    setState(() {
      _state.loadingDisplayedChapter = false;
      _state.displayedContent = content;
      _state.laidOutChapterIndex = chapterIndex;
      _state.paragraphs = layout.paragraphs;
      _state.pages = layout.pages;
      _state.paragraphPageLookup = layout.paragraphPageLookup;
      _state.currentLayout = layout;
      _state.currentPage = targetPage;
      _state.chapterPosition = normalizedPosition;
    });

    // dispose 旧 controller
    oldController.dispose();

    _paragraphKeys =
        List.generate(_state.paragraphs.length, (_) => GlobalKey());
    _state.consumePendingPosition();

    provider.book?.durChapterIndex = chapterIndex;
    provider.book?.durChapterTitle = chapterTitle ?? '';

    // 清除已使用的预排版缓存
    if (_state.prefetchedNextChapterIndex == chapterIndex) {
      _state.prefetchedNextLayout = null;
      _state.prefetchedNextContent = null;
      _state.prefetchedNextTitle = null;
      _state.prefetchedNextChapterIndex = -1;
    }
    if (_state.prefetchedPrevChapterIndex == chapterIndex) {
      _state.prefetchedPrevLayout = null;
      _state.prefetchedPrevContent = null;
      _state.prefetchedPrevTitle = null;
      _state.prefetchedPrevChapterIndex = -1;
    }

    // 后台预取上下章节
    await _prefetchNextChapter(token, chapterIndex);
    _prefetchPrevChapter(token, chapterIndex);

    if (_state.continueTtsOnNextChapter) {
      _state.continueTtsOnNextChapter = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_state.ttsReading) return;
        _prepareTtsParagraphs(_state.displayedContent);
        _speakParagraphAt(0);
      });
    }
  }

  /// 排版章节（使用新引擎）
  ChapterLayout _layoutChapter({
    required String content,
    required String? chapterTitle,
    required int chapterIndex,
    int targetPosition = 0,
  }) {
    final size = _state.pagedViewportSize ?? MediaQuery.of(context).size;
    final safeTop =
        _state.pagedViewportSize == null ? MediaQuery.of(context).padding.top : 0.0;
    final safeBottom = _state.pagedViewportSize == null
        ? MediaQuery.of(context).padding.bottom
        : 0.0;

    final cacheKey = ChapterLayout.cacheKey(
      chapterIndex,
      content.hashCode,
      _state.fontSize,
      _state.lineHeight,
      size.width,
      size.height,
      _state.pageMode,
    );

    if (_state.layoutCache.containsKey(cacheKey)) {
      return _state.layoutCache[cacheKey]!;
    }

    final layout = _paginationEngine.paginate(
      content: content,
      chapterTitle: chapterTitle,
      chapterIndex: chapterIndex,
      fontSize: _state.fontSize,
      lineHeight: _state.lineHeight,
      viewportSize: size,
      safeTop: safeTop,
      safeBottom: safeBottom,
    );

    _state.layoutCache[cacheKey] = layout;
    return layout;
  }


  Future<void> _prefetchNextChapter(String token, int chapterIndex) async {
    final provider = context.read<ReaderProvider>();
    final nextIndex = chapterIndex + 1;
    if (nextIndex >= provider.chapters.length) return;

    // 如果已经预排版过同一章节，跳过
    if (_state.prefetchedNextChapterIndex == nextIndex &&
        _state.prefetchedNextLayout != null) return;

    try {
      final content = await provider.getChapterContent(token, nextIndex);
      if (!mounted) return;

      final chapterTitle = nextIndex < provider.chapters.length
          ? provider.chapters[nextIndex].title
          : null;

      final layout = _layoutChapter(
        content: content,
        chapterTitle: chapterTitle,
        chapterIndex: nextIndex,
      );

      _state.prefetchedNextLayout = layout;
      _state.prefetchedNextContent = content;
      _state.prefetchedNextTitle = chapterTitle;
      _state.prefetchedNextChapterIndex = nextIndex;
    } catch (_) {
      _state.prefetchedNextLayout = null;
      _state.prefetchedNextChapterIndex = -1;
    }
  }

  Future<void> _prefetchPrevChapter(String token, int chapterIndex) async {
    final provider = context.read<ReaderProvider>();
    final prevIndex = chapterIndex - 1;
    if (prevIndex < 0) return;

    // 如果已经预排版过同一章节，跳过
    if (_state.prefetchedPrevChapterIndex == prevIndex &&
        _state.prefetchedPrevLayout != null) return;

    try {
      final content = await provider.getChapterContent(token, prevIndex);
      if (!mounted) return;

      final chapterTitle = prevIndex < provider.chapters.length
          ? provider.chapters[prevIndex].title
          : null;

      final layout = _layoutChapter(
        content: content,
        chapterTitle: chapterTitle,
        chapterIndex: prevIndex,
      );

      _state.prefetchedPrevLayout = layout;
      _state.prefetchedPrevContent = content;
      _state.prefetchedPrevTitle = chapterTitle;
      _state.prefetchedPrevChapterIndex = prevIndex;
    } catch (_) {
      _state.prefetchedPrevLayout = null;
      _state.prefetchedPrevChapterIndex = -1;
    }
  }

  // ============================================================
  // 翻页
  // ============================================================

  void _handleTap(TapUpDetails details, ReaderProvider provider) {
    if (_state.autoPageRunning) {
      setState(() => _state.showAutoPageControls = !_state.showAutoPageControls);
      return;
    }

    final width = MediaQuery.of(context).size.width;

    if (_state.pageMode == 'scroll') {
      _toggleController();
      return;
    }

    if (width > 0 && details.globalPosition.dx < width / 3) {
      _previousPage(provider);
    } else if (width > 0 && details.globalPosition.dx > width * 2 / 3) {
      _nextPage(provider);
    } else {
      _toggleController();
    }
  }

  void _previousPage(ReaderProvider provider) {
    if (_state.pages.isEmpty) return;
    final currentPage = _activePageIndex();
    if (currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      final previousPage = _state.pages[currentPage - 1];
      setState(() {
        _state.currentPage = currentPage - 1;
        _state.chapterPosition = previousPage.startPosition;
      });
    } else {
      final chapterIndex = _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0);
      if (chapterIndex <= 0) return;
      _saveProgress(pos: _state.chapterPosition.toDouble());
      // 如果上一章已预排版，直接同步切换（零等待）
      if (_state.prefetchedPrevChapterIndex == chapterIndex - 1 &&
          _state.prefetchedPrevLayout != null) {
        _switchToPrevChapter();
      } else {
        _openChapter(chapterIndex - 1, openAtEnd: true);
      }
    }
  }

  void _nextPage(ReaderProvider provider) {
    if (_state.pages.isEmpty) return;
    final currentPage = _activePageIndex();
    if (currentPage < _state.pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      final nextPage = _state.pages[currentPage + 1];
      setState(() {
        _state.currentPage = currentPage + 1;
        _state.chapterPosition = nextPage.startPosition;
      });
    } else if (_state.autoNext) {
      final chapterIndex = _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0);
      if (chapterIndex >= provider.chapters.length - 1) {
        setState(() => _state.showController = true);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已到本章末页'),
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }
      _saveProgress(pos: _state.chapterPosition.toDouble());
      // 如果下一章已预排版，直接同步切换（零等待）
      if (_state.prefetchedNextChapterIndex == chapterIndex + 1 &&
          _state.prefetchedNextLayout != null) {
        _switchToNextChapter();
      } else {
        _openChapter(chapterIndex + 1, chapterPosition: 0);
      }
    } else {
      setState(() => _state.showController = true);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已到本章末页'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  /// 使用预排版结果同步切换到下一章（零等待）
  void _switchToNextChapter() {
    final layout = _state.prefetchedNextLayout!;
    final content = _state.prefetchedNextContent!;
    final chapterTitle = _state.prefetchedNextTitle;
    final chapterIndex = _state.prefetchedNextChapterIndex;

    final targetPage = 0; // 下一章从首页开始
    final normalizedPosition = layout.pages.isEmpty
        ? 0
        : layout.pages[targetPage].startPosition;

    // 当前章节变成"上一章"的预排版
    _state.prefetchedPrevLayout = _state.currentLayout;
    _state.prefetchedPrevContent = _state.displayedContent;
    _state.prefetchedPrevTitle = _displayedChapter(
      context.read<ReaderProvider>())?.title;
    _state.prefetchedPrevChapterIndex = _state.laidOutChapterIndex;

    // 清除下一章预排版（需要在后台重新预取）
    _state.prefetchedNextLayout = null;
    _state.prefetchedNextContent = null;
    _state.prefetchedNextTitle = null;
    _state.prefetchedNextChapterIndex = -1;

    // 创建新 PageController
    final oldController = _pageController;
    _pageController = PageController(initialPage: targetPage);

    setState(() {
      _state.loadingDisplayedChapter = false;
      _state.displayedContent = content;
      _state.laidOutChapterIndex = chapterIndex;
      _state.paragraphs = layout.paragraphs;
      _state.pages = layout.pages;
      _state.paragraphPageLookup = layout.paragraphPageLookup;
      _state.currentLayout = layout;
      _state.currentPage = targetPage;
      _state.chapterPosition = normalizedPosition;
    });

    oldController.dispose();
    _paragraphKeys = List.generate(_state.paragraphs.length, (_) => GlobalKey());

    final provider = context.read<ReaderProvider>();
    provider.book?.durChapterIndex = chapterIndex;
    provider.book?.durChapterTitle = chapterTitle ?? '';

    // 后台预取新的下一章
    if (_token != null) {
      _prefetchNextChapter(_token!, chapterIndex);
    }
  }

  /// 使用预排版结果同步切换到上一章（零等待）
  void _switchToPrevChapter() {
    final layout = _state.prefetchedPrevLayout!;
    final content = _state.prefetchedPrevContent!;
    final chapterTitle = _state.prefetchedPrevTitle;
    final chapterIndex = _state.prefetchedPrevChapterIndex;

    final targetPage = layout.pages.length - 1; // 上一章从末页开始
    final normalizedPosition = layout.pages.isEmpty
        ? 0
        : layout.pages[targetPage].startPosition;

    // 当前章节变成"下一章"的预排版
    _state.prefetchedNextLayout = _state.currentLayout;
    _state.prefetchedNextContent = _state.displayedContent;
    _state.prefetchedNextTitle = _displayedChapter(
      context.read<ReaderProvider>())?.title;
    _state.prefetchedNextChapterIndex = _state.laidOutChapterIndex;

    // 清除上一章预排版（需要在后台重新预取）
    _state.prefetchedPrevLayout = null;
    _state.prefetchedPrevContent = null;
    _state.prefetchedPrevTitle = null;
    _state.prefetchedPrevChapterIndex = -1;

    // 创建新 PageController
    final oldController = _pageController;
    _pageController = PageController(initialPage: targetPage);

    setState(() {
      _state.loadingDisplayedChapter = false;
      _state.displayedContent = content;
      _state.laidOutChapterIndex = chapterIndex;
      _state.paragraphs = layout.paragraphs;
      _state.pages = layout.pages;
      _state.paragraphPageLookup = layout.paragraphPageLookup;
      _state.currentLayout = layout;
      _state.currentPage = targetPage;
      _state.chapterPosition = normalizedPosition;
    });

    oldController.dispose();
    _paragraphKeys = List.generate(_state.paragraphs.length, (_) => GlobalKey());

    final provider = context.read<ReaderProvider>();
    provider.book?.durChapterIndex = chapterIndex;
    provider.book?.durChapterTitle = chapterTitle ?? '';

    // 后台预取新的上一章
    if (_token != null) {
      _prefetchPrevChapter(_token!, chapterIndex);
    }
  }

  void _toggleController() {
    if (_state.autoPageRunning) {
      setState(() => _state.showAutoPageControls = !_state.showAutoPageControls);
      return;
    }
    setState(() => _state.showController = !_state.showController);
  }

  void _goToPreviousChapter() {
    final provider = context.read<ReaderProvider>();
    final chapterIndex = _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0);
    if (chapterIndex <= 0) return;
    _saveProgress(pos: _getProgress());
    _openChapter(chapterIndex - 1, openAtEnd: true);
  }

  void _goToNextChapter() {
    final provider = context.read<ReaderProvider>();
    final chapterIndex = _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0);
    if (chapterIndex >= provider.chapters.length - 1) return;
    _saveProgress(pos: _getProgress());
    _openChapter(chapterIndex + 1, chapterPosition: 0);
  }

  // ============================================================
  // 内容构建
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _state.currentTheme.background,
      body: Consumer<ReaderProvider>(
        builder: (context, provider, _) {
          if (provider.book == null) {
            return const Center(child: Text('未选择书籍'));
          }
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _handleTap(details, provider),
                  child: _buildContent(provider),
                ),
              ),
              if (_state.showController) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _toggleController,
                    child: Container(
                        color: Colors.black.withOpacity(0.18)),
                  ),
                ),
                ControllerOverlay(
                  data: ReaderControllerViewData(
                    bookName: provider.book?.name ?? '',
                    chapterTitle: _displayedChapter(provider)?.title ?? '',
                    sourceName:
                        provider.book?.originName ?? provider.book?.origin ?? '未知书源',
                    hasBookmark: _hasBookmarkAtCurrent(provider),
                    replaceRuleEnabled: provider.book?.useReplaceRule == true,
                    themeName: _state.theme,
                    capsuleMode: _state.capsuleMode,
                    ttsState: _tts.state,
                    ttsRate: _tts.rate,
                    autoPageInterval: _state.autoPageInterval,
                    chapterIndex: _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0),
                    totalChapters: provider.chapters.length,
                    chapterSliderValue: _state.chapterSliderValue,
                    ttsParagraphIndex: _state.ttsParagraphIndex,
                    totalParagraphs: _state.paragraphs.length,
                  ),
                  callbacks: ReaderControllerCallbacks(
                    onBack: () {
                      _saveProgress(pos: _getProgress());
                      Navigator.pop(context);
                    },
                    onShowMore: () => _showMorePanel(provider),
                    onRefresh: _applyReplaceRules,
                    onToggleBookmark: () => _toggleBookmark(provider),
                    onStartAutoPage: _startAutoPageMode,
                    onStartTts: _startTts,
                    onToggleTheme: _toggleReaderTheme,
                    onPrevChapter: _goToPreviousChapter,
                    onNextChapter: _goToNextChapter,
                    onChapterSliderChanged: (value) {
                      setState(() => _state.chapterSliderValue = value);
                    },
                    onChapterSliderEnd: (value) {
                      setState(() => _state.chapterSliderValue = null);
                      final target = value.round();
                      final ci = _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0);
                      if (target != ci && _token != null) {
                        _saveProgress(pos: _getProgress());
                        _openChapter(target, chapterPosition: 0);
                      }
                    },
                    onShowChapterList: () => _showChapterList(provider),
                    onShowSettings: () => _showReadingSettingsSheet(provider),
                    onStopTts: _stopTts,
                    onPauseTts: _pauseTts,
                    onResumeTts: _resumeTts,
                    onShowTtsTimer: _showTtsTimerSheet,
                    onShowTtsSettings: _showTtsSettingsSheet,
                    onStopAutoPage: _stopAutoPageMode,
                    onDecreaseAutoPageInterval: () =>
                        _changeAutoPageInterval(-1),
                    onIncreaseAutoPageInterval: () =>
                        _changeAutoPageInterval(1),
                  ),
                ),
              ],
              if (_state.autoPageRunning && _state.showAutoPageControls)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xD91A222B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => _changeAutoPageInterval(-1),
                            icon: const Icon(Icons.remove,
                                color: Colors.white),
                          ),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('自动翻页',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 13)),
                                const SizedBox(height: 4),
                                Text(
                                  '${_state.autoPageInterval.toStringAsFixed(0)} 秒',
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _changeAutoPageInterval(1),
                            icon:
                                const Icon(Icons.add, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: _stopAutoPageMode,
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: const Text('停止'),
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(ReaderProvider provider) {
    final bg = _state.currentTheme.background;

    if (provider.loadingChapters && provider.chapters.isEmpty) {
      return ColoredBox(
        color: bg,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.error != null && provider.chapters.isEmpty) {
      return ColoredBox(
        color: bg,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(provider.error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _retry, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    final bookType = provider.book?.type ?? 0;
    if (bookType == 1) return SafeArea(child: _buildAudioPlaceholder(provider));
    if (bookType == 3) return SafeArea(child: _buildFilePlaceholder());

    return SafeArea(
      child: _state.loadingDisplayedChapter && _state.displayedContent.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null && _state.displayedContent.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          '加载章节失败\n${provider.error}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _retry, child: const Text('重试')),
                    ],
                  ),
                )
              : _state.isComic ||
                      PaginationEngine.isHtmlContent(_state.displayedContent)
                  ? _buildComicContent(provider)
                  : _state.pageMode == 'scroll'
                      ? _buildScrollNovelContent(provider)
                      : _buildPagedNovelContent(provider),
    );
  }

  Widget _buildPagedNovelContent(ReaderProvider provider) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_state.pagedViewportSize == null ||
            (_state.pagedViewportSize!.width - size.width).abs() > 1 ||
            (_state.pagedViewportSize!.height - size.height).abs() > 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _state.pagedViewportSize = size);
            _rebuildPages(provider);
          });
        }

        if (_state.pages.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final chapterTitle =
            _displayedChapter(provider)?.title ?? provider.book?.durChapterTitle ?? '';

        return PagedReader(
          key: ValueKey('chapter_${_state.laidOutChapterIndex}'),
          pages: _state.pages,
          pageController: _pageController,
          theme: _state.currentTheme,
          fontSize: _state.fontSize,
          lineHeight: _state.lineHeight,
          chapterTitle: chapterTitle,
          currentPage: _state.currentPage,
          totalPages: _state.pages.length,
          ttsParagraphIndex: _state.ttsParagraphIndex,
          timeLabel: _state.formatTime(),
          batteryLabel: _state.batteryLabel(),
          showTopBar: _state.showTopBar,
          showBottomBar: _state.showBottomBar,
          showPageNumber: _state.showPageNumber,
          onPageChanged: (page) {
            final position =
                _state.pages.isEmpty ? 0 : _state.pages[page].startPosition;
            setState(() {
              _state.currentPage = page;
              _state.chapterPosition = position;
            });
          },
        );
      },
    );
  }

  Widget _buildScrollNovelContent(ReaderProvider provider) {
    if (_state.paragraphs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final chapterTitle =
        _displayedChapter(provider)?.title ?? provider.book?.durChapterTitle ?? '';

    return ScrollReader(
      paragraphs: _state.paragraphs,
      scrollController: _novelScrollController,
      theme: _state.currentTheme,
      fontSize: _state.fontSize,
      lineHeight: _state.lineHeight,
      chapterTitle: chapterTitle,
      ttsParagraphIndex: _state.ttsParagraphIndex,
      pageIndicator: _state.pageIndicatorLabel(),
      timeLabel: _state.formatTime(),
      batteryLabel: _state.batteryLabel(),
    );
  }

  Widget _buildComicContent(ReaderProvider provider) {
    final isComic = _state.isComic;
    final textColor = _state.currentTheme.text;
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _comicScrollController,
            padding: isComic
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              Html(
                data: _proxyImages(_state.displayedContent),
                style: {
                  'body': Style(
                    margin: Margins.zero,
                    padding: HtmlPaddings.zero,
                  ),
                  'img': Style(
                    margin: isComic ? Margins.zero : Margins.only(bottom: 8),
                    width: isComic ? Width(double.infinity) : null,
                  ),
                  'p': Style(
                    margin: Margins.only(bottom: 10),
                    fontSize: FontSize(_state.fontSize),
                    lineHeight: LineHeight(_state.lineHeight),
                    color: textColor,
                  ),
                },
              ),
            ],
          ),
        ),
        _buildComicFooter(provider),
      ],
    );
  }

  Widget _buildComicFooter(ReaderProvider provider) {
    final theme = _state.currentTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      child: Row(
        children: [
          Text(_state.formatTime(),
              style: TextStyle(fontSize: 11, color: theme.secondaryText)),
          const Spacer(),
          Text(_state.pageIndicatorLabel(),
              style: TextStyle(fontSize: 11, color: theme.secondaryText)),
          const Spacer(),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.battery_std, size: 13, color: theme.secondaryText),
              const SizedBox(width: 4),
              Text(_state.batteryLabel(),
                  style: TextStyle(fontSize: 11, color: theme.secondaryText)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPlaceholder(ReaderProvider provider) {
    final theme = _state.currentTheme;
    final displayedChapter = _displayedChapter(provider);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _state.ttsReading ? Icons.multitrack_audio : Icons.headphones,
            size: 64,
            color: _state.ttsReading
                ? const Color(0xFF00A88F)
                : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text('有声书朗读',
              style: TextStyle(
                  color: theme.text, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            _state.ttsReading
                ? (displayedChapter?.title ?? '朗读中...')
                : '点击下方按钮开始朗读',
            style: TextStyle(color: theme.secondaryText, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_state.ttsReading) ...[
            SizedBox(
              width: 250,
              child: LinearProgressIndicator(
                value: _state.paragraphs.isNotEmpty
                    ? ((_state.ttsParagraphIndex + 1) / _state.paragraphs.length)
                        .clamp(0.0, 1.0)
                    : null,
                backgroundColor: theme.divider,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF00A88F)),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_state.ttsReading) ...[
                IconButton(
                  icon: const Icon(Icons.stop, size: 32),
                  onPressed: _stopTts,
                  tooltip: '停止',
                ),
                const SizedBox(width: 24),
                IconButton(
                  icon: Icon(
                    _tts.state == TtsState.paused
                        ? Icons.play_arrow
                        : Icons.pause,
                    size: 40,
                  ),
                  onPressed:
                      _tts.state == TtsState.paused ? _resumeTts : _pauseTts,
                ),
              ] else
                IconButton(
                  icon: const Icon(Icons.play_arrow, size: 48),
                  onPressed: _startTts,
                  tooltip: '开始朗读',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilePlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('该书籍为文件类型',
              style: TextStyle(color: _state.currentTheme.text, fontSize: 16)),
          const SizedBox(height: 4),
          Text('请使用外部应用打开',
              style: TextStyle(color: _state.currentTheme.secondaryText, fontSize: 14)),
        ],
      ),
    );
  }

  String _proxyImages(String html) {
    final baseUrl = AppConstants.apiBase;
    return html.replaceAllMapped(
      RegExp(
          r"""<img\s[^>]*src\s*=\s*["']([^"']+)["'][^>]*>""",
          caseSensitive: false),
      (match) {
        final fullTag = match.group(0) ?? '';
        final src = match.group(1) ?? '';
        if (src.isEmpty || src.startsWith('$baseUrl/proxypng')) return fullTag;
        final proxied = '$baseUrl/proxypng?url=${Uri.encodeComponent(src)}';
        return fullTag.replaceFirst(src, proxied);
      },
    );
  }

  void _rebuildPages(ReaderProvider provider) {
    if (_state.pageMode != 'paged' ||
        _state.displayedContent.isEmpty ||
        _state.isComic ||
        PaginationEngine.isHtmlContent(_state.displayedContent)) {
      return;
    }

    final targetPosition = _state.resolveTargetChapterPosition(
      provider.book?.durChapterIndex ?? 0,
      provider.book?.durChapterPos?.round(),
    );

    final chapterTitle =
        _displayedChapter(provider)?.title ?? provider.book?.durChapterTitle;

    final layout = _layoutChapter(
      content: _state.displayedContent,
      chapterTitle: chapterTitle,
      chapterIndex: _state.laidOutChapterIndex,
      targetPosition: targetPosition,
    );

    final targetPage = _paginationEngine
        .pageIndexForPosition(layout.pages, targetPosition)
        .clamp(0, layout.pages.length - 1);
    final normalizedPosition = layout.pages.isEmpty
        ? 0
        : layout.pages[targetPage].startPosition;

    setState(() {
      _state.paragraphs = layout.paragraphs;
      _state.pages = layout.pages;
      _state.paragraphPageLookup = layout.paragraphPageLookup;
      _state.currentLayout = layout;
      _state.currentPage = targetPage;
      _state.chapterPosition = normalizedPosition;
    });

    _paragraphKeys = List.generate(_state.paragraphs.length, (_) => GlobalKey());
    // 先创建新 controller，再 dispose 旧的
    final oldCtrl = _pageController;
    _pageController = PageController(initialPage: targetPage);
    oldCtrl.dispose();
    _state.consumePendingPosition();
  }

  // ============================================================
  // 自动翻页
  // ============================================================

  void _startAutoPageMode() {
    final provider = context.read<ReaderProvider>();
    _stopTts();
    setState(() {
      _state.autoPageRunning = true;
      _state.showAutoPageControls = true;
      _state.showController = false;
    });
    _restartAutoPageTimer(provider);
  }

  void _restartAutoPageTimer(ReaderProvider provider) {
    _autoPageTimer?.cancel();
    _autoPageTimer = Timer.periodic(
      Duration(milliseconds: (_state.autoPageInterval * 1000).round()),
      (_) => _performAutoPageStep(provider),
    );
    _saveSettings();
  }

  void _performAutoPageStep(ReaderProvider provider) {
    if (!mounted) return;
    if (_state.isComic) {
      if (_comicScrollController.hasClients &&
          _comicScrollController.offset >=
              _comicScrollController.position.maxScrollExtent - 30) {
        if (_state.autoNext &&
            _state.hasNextChapter(
                _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0),
                provider.chapters.length)) {
          _goToNextChapter();
        } else {
          _stopAutoPageMode();
        }
      } else {
        _comicScrollDown();
      }
      return;
    }

    if (_state.pageMode == 'scroll') {
      if (!_novelScrollController.hasClients) return;
      final target = (_novelScrollController.offset +
              MediaQuery.of(context).size.height * 0.75)
          .clamp(0.0, _novelScrollController.position.maxScrollExtent);
      if (target >= _novelScrollController.position.maxScrollExtent - 20) {
        if (_state.autoNext &&
            _state.hasNextChapter(
                _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0),
                provider.chapters.length)) {
          _goToNextChapter();
        } else {
          _stopAutoPageMode();
        }
      } else {
        _novelScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
      return;
    }

    final wasLastPage = _activePageIndex() >= _state.pages.length - 1;
    _nextPage(provider);
    if (wasLastPage &&
        (!_state.hasNextChapter(
                _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0),
                provider.chapters.length) ||
            !_state.autoNext)) {
      _stopAutoPageMode();
    }
  }

  void _comicScrollDown() {
    if (!_comicScrollController.hasClients) return;
    final pageHeight = MediaQuery.of(context).size.height * 0.8;
    _comicScrollController.animateTo(
      (_comicScrollController.offset + pageHeight)
          .clamp(0.0, _comicScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  void _changeAutoPageInterval(double delta) {
    final provider = context.read<ReaderProvider>();
    setState(() {
      _state.autoPageInterval =
          (_state.autoPageInterval + delta).clamp(3.0, 60.0);
    });
    if (_state.autoPageRunning) {
      _restartAutoPageTimer(provider);
    } else {
      _saveSettings();
    }
  }

  void _stopAutoPageMode() {
    _autoPageTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _state.autoPageRunning = false;
      _state.showAutoPageControls = true;
    });
  }

  void _toggleReaderTheme() {
    setState(() {
      _state.theme = ReaderTheme.nextTheme(_state.theme);
    });
    _saveSettings();
  }

  // ============================================================
  // TTS
  // ============================================================

  Future<void> _startTts() async {
    final text = _state.displayedContent;
    if (text.isEmpty) return;
    _stopAutoPageMode();
    _prepareTtsParagraphs(text);
    if (_state.paragraphs.isEmpty) return;

    // 找到当前页面第一个段落作为 TTS 起始位置
    int startParagraphIndex;
    if (_state.ttsParagraphIndex >= 0) {
      // 已有 TTS 位置，继续使用
      startParagraphIndex = _state.ttsParagraphIndex;
    } else if (_state.pages.isNotEmpty && _state.currentPage < _state.pages.length) {
      // 从当前页面的第一个段落开始
      final currentPageLines = _state.pages[_state.currentPage].lines;
      startParagraphIndex = currentPageLines.isNotEmpty
          ? currentPageLines.first.paragraphIndex
          : 0;
    } else {
      startParagraphIndex = 0;
    }

    setState(() {
      _state.ttsReading = true;
      _state.continueTtsOnNextChapter = false;
      _state.showController = true;
    });
    await _speakParagraphAt(startParagraphIndex);
  }

  void _prepareTtsParagraphs(String text) {
    if (_state.paragraphs.isNotEmpty) return;
    final layout = _paginationEngine.paginate(
      content: text,
      chapterTitle: null,
      chapterIndex: _state.laidOutChapterIndex,
      fontSize: _state.fontSize,
      lineHeight: _state.lineHeight,
      viewportSize: _state.pagedViewportSize ?? MediaQuery.of(context).size,
      safeTop: MediaQuery.of(context).padding.top,
      safeBottom: MediaQuery.of(context).padding.bottom,
    );
    setState(() {
      _state.paragraphs = layout.paragraphs;
    });
    _paragraphKeys = List.generate(_state.paragraphs.length, (_) => GlobalKey());
  }

  Future<void> _speakParagraphAt(int index) async {
    if (!_state.ttsReading || index < 0 || index >= _state.paragraphs.length) {
      return;
    }
    setState(() => _state.ttsParagraphIndex = index);
    _focusParagraph(index);

    _tts.onChunkComplete = () {
      if (!_state.ttsReading || !mounted) return;
      final nextIndex = index + 1;
      if (nextIndex < _state.paragraphs.length) {
        _speakParagraphAt(nextIndex);
        return;
      }
      final provider = context.read<ReaderProvider>();
      final ci = _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0);
      if (_state.autoNext &&
          _state.hasNextChapter(ci, provider.chapters.length) &&
          _token != null) {
        _state.continueTtsOnNextChapter = true;
        _saveProgress(pos: 1.0);
        _openChapter(ci + 1, chapterPosition: 0);
      } else {
        _stopTts();
      }
    };

    await _tts.speakText(_state.paragraphs[index].text);
  }

  void _focusParagraph(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_state.pageMode == 'paged') {
        final pageIndex = _state.paragraphPageLookup[index];
        if (pageIndex != null &&
            _pageController.hasClients &&
            pageIndex != _state.currentPage) {
          _pageController.animateToPage(
            pageIndex,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
          setState(() {
            _state.currentPage = pageIndex;
            _state.chapterPosition =
                _state.pages[pageIndex].startPosition;
          });
        }
        return;
      }
      if (index < 0 || index >= _paragraphKeys.length) return;
      final targetContext = _paragraphKeys[index].currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 220),
          alignment: 0.18,
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pauseTts() async {
    await _tts.pause();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _resumeTts() async {
    if (_state.ttsParagraphIndex < 0 && _state.paragraphs.isNotEmpty) {
      _state.ttsParagraphIndex = 0;
    }
    if (!_state.ttsReading) {
      setState(() => _state.ttsReading = true);
    }
    await _speakParagraphAt(
        _state.ttsParagraphIndex.clamp(0, _state.paragraphs.length - 1));
  }

  Future<void> _stopTts() async {
    _tts.onChunkComplete = null;
    _ttsSleepTimer?.cancel();
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _state.ttsReading = false;
      _state.continueTtsOnNextChapter = false;
      _state.ttsParagraphIndex = -1;
      _state.ttsSleepMinutes = null;
    });
  }

  // ============================================================
  // 书签
  // ============================================================

  bool _hasBookmarkAtCurrent(ReaderProvider provider) {
    final currentIndex = _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0);
    return _bookmarks.any(
      (mark) => mark.chapterIndex == currentIndex && mark.chapterPos != null,
    );
  }

  Bookmark? _bookmarkAtCurrent(ReaderProvider provider) {
    final idx = _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0);
    for (final mark in _bookmarks) {
      if (mark.chapterIndex == idx && mark.chapterPos != null) return mark;
    }
    return null;
  }

  Future<void> _toggleBookmark(ReaderProvider provider) async {
    if (_token == null || _bookUrl == null) return;
    final existing = _bookmarkAtCurrent(provider);
    if (existing != null && existing.id != null) {
      try {
        await ApiService.instance.deleteBookmark(_token!, existing.id!);
        await _loadBookmarks();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('书签已删除')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除书签失败: $e')),
        );
      }
      return;
    }
    try {
      final chapterName = _displayedChapter(provider)?.title ?? '';
      final index = _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0);
      final pos = _state.chapterPosition.toDouble();
      await ApiService.instance.addBookmark(
        _token!,
        url: _bookUrl!,
        name: chapterName,
        index: index,
        pos: pos,
      );
      await _loadBookmarks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('书签已添加')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('添加书签失败: $e')),
      );
    }
  }

  Future<void> _deleteBookmark(Bookmark mark) async {
    if (_token == null || mark.id == null) return;
    try {
      await ApiService.instance.deleteBookmark(_token!, mark.id!);
      await _loadBookmarks();
    } catch (_) {}
  }

  Future<void> _jumpToBookmark(Bookmark mark) async {
    if (_token == null) return;
    final provider = context.read<ReaderProvider>();
    final targetChapter =
        mark.chapterIndex ?? _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0);
    Navigator.pop(context);
    _saveProgress(pos: _getProgress());
    await _openChapter(targetChapter,
        chapterPosition: mark.chapterPos?.round() ?? 0);
  }

  // ============================================================
  // 底部弹窗
  // ============================================================

  void _showChapterList(ReaderProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('目录',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${provider.chapters.length} 章',
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: provider.chapters.length,
                  itemBuilder: (context, index) {
                    final chapter = provider.chapters[index];
                    final ci = _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0);
                    final isCurrent = index == ci;
                    final isRead = provider.readChapters.contains(index);
                    final hasBookmark = _bookmarkChapterIndices.contains(index);
                    return ListTile(
                      dense: true,
                      selected: isCurrent,
                      selectedTileColor:
                          const Color(0xFF00A88F).withOpacity(0.10),
                      leading: hasBookmark
                          ? const Icon(Icons.bookmark,
                              size: 16, color: Color(0xFF00A88F))
                          : null,
                      title: Text(
                        chapter.title ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: isCurrent
                              ? const Color(0xFF00A88F)
                              : isRead
                                  ? Colors.grey
                                  : null,
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isCurrent
                          ? const Icon(Icons.play_arrow,
                              size: 16, color: Color(0xFF00A88F))
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        _saveProgress(pos: _getProgress());
                        _openChapter(index, chapterPosition: 0);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBookmarkList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (ctx, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('书签',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${_bookmarks.length} 个',
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _bookmarks.isEmpty
                    ? const Center(child: Text('暂无书签'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: _bookmarks.length,
                        itemBuilder: (context, index) {
                          final mark = _bookmarks[index];
                          final provider = context.read<ReaderProvider>();
                          final isCurrentChapter =
                              mark.chapterIndex ==
                                  _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0);
                          return ListTile(
                            leading: const Icon(Icons.bookmark,
                                color: Color(0xFF00A88F)),
                            title: Text(
                              mark.chapterName ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: isCurrentChapter
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              mark.createTime ?? '',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => _deleteBookmark(mark),
                            ),
                            onTap: () => _jumpToBookmark(mark),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showReadingSettingsSheet(ReaderProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, sheetSetState) {
            void commit(VoidCallback fn, {bool rebuildPages = false}) {
              setState(fn);
              sheetSetState(() {});
              _saveSettings();
              if (rebuildPages) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _rebuildPages(context.read<ReaderProvider>());
                });
              }
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.85,
              expand: false,
              builder: (_, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 拖拽指示条
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Text('阅读设置',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),

                      // ---- 字号 ----
                      _SettingRow(
                        label: '字号',
                        value: _state.fontSize.round().toString(),
                        child: Slider(
                          value: _state.fontSize,
                          min: 12,
                          max: 32,
                          divisions: 20,
                          label: _state.fontSize.round().toString(),
                          onChanged: (v) => commit(
                              () => _state.fontSize = v,
                              rebuildPages: true),
                        ),
                      ),

                      // ---- 行距 ----
                      _SettingRow(
                        label: '行距',
                        value: _state.lineHeight.toStringAsFixed(1),
                        child: Slider(
                          value: _state.lineHeight,
                          min: 1.2,
                          max: 2.6,
                          divisions: 14,
                          label: _state.lineHeight.toStringAsFixed(1),
                          onChanged: (v) => commit(
                              () => _state.lineHeight = v,
                              rebuildPages: true),
                        ),
                      ),

                      const Divider(height: 24),

                      // ---- 翻页模式 ----
                      _SettingRow(
                        label: '翻页模式',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ChoiceChip('覆盖', _state.pageMode == 'paged', () {
                              commit(() => _state.pageMode = 'paged',
                                  rebuildPages: true);
                            }),
                            const SizedBox(width: 8),
                            _ChoiceChip('滚动', _state.pageMode == 'scroll', () {
                              commit(() => _state.pageMode = 'scroll',
                                  rebuildPages: true);
                            }),
                          ],
                        ),
                      ),

                      // ---- 主题 ----
                      _SettingRow(
                        label: '主题',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ChoiceChip('浅色', _state.theme == 'light', () {
                              commit(() => _state.theme = 'light');
                            }),
                            const SizedBox(width: 6),
                            _ChoiceChip('深色', _state.theme == 'dark', () {
                              commit(() => _state.theme = 'dark');
                            }),
                            const SizedBox(width: 6),
                            _ChoiceChip('护眼', _state.theme == 'sepia', () {
                              commit(() => _state.theme = 'sepia');
                            }),
                          ],
                        ),
                      ),

                      const Divider(height: 24),

                      // ---- 自动下一章 ----
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('自动下一章'),
                        value: _state.autoNext,
                        onChanged: (v) => commit(() => _state.autoNext = v),
                      ),

                      // ---- 屏幕常亮 ----
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('屏幕常亮'),
                        value: _state.screenWakelock,
                        onChanged: (v) => commit(() {
                          _state.screenWakelock = v;
                          _applyWakelock();
                        }),
                      ),

                      const Divider(height: 24),

                      // ---- 显示页码 ----
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('显示页码'),
                        value: _state.showPageNumber,
                        onChanged: (v) => commit(() => _state.showPageNumber = v),
                      ),

                      // ---- 底部区域 ----
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('底部区域'),
                        subtitle: const Text('时间、电量、页码', style: TextStyle(fontSize: 12)),
                        value: _state.showBottomBar,
                        onChanged: (v) => commit(() => _state.showBottomBar = v),
                      ),

                      // ---- 顶部区域 ----
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('顶部区域'),
                        subtitle: const Text('章节序号、章节名', style: TextStyle(fontSize: 12)),
                        value: _state.showTopBar,
                        onChanged: (v) => commit(() => _state.showTopBar = v),
                      ),

                      // ---- 音量键翻页 ----
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('音量键翻页'),
                        value: _state.volumeKeyFlip,
                        onChanged: (v) => commit(() => _state.volumeKeyFlip = v),
                      ),

                      // ---- 自动翻页间隔 ----
                      if (!_state.isComic)
                        _SettingRow(
                          label: '翻页间隔',
                          value: '${_state.autoPageInterval.toStringAsFixed(0)}秒',
                          child: Slider(
                            value: _state.autoPageInterval,
                            min: 3,
                            max: 60,
                            divisions: 57,
                            label: _state.autoPageInterval.toStringAsFixed(0),
                            onChanged: (v) => commit(
                                () => _state.autoPageInterval = v),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showTtsSettingsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, sheetSetState) {
            final voices = _tts.voices;
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('听书设置',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const SizedBox(width: 56, child: Text('语速')),
                        Expanded(
                          child: Slider(
                            value: _tts.rate,
                            min: 0.1,
                            max: 1.0,
                            divisions: 9,
                            label: _tts.rate.toStringAsFixed(1),
                            onChanged: (value) async {
                              await _tts.setRate(value);
                              if (mounted) {
                                setState(() {});
                                sheetSetState(() {});
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (voices.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _tts.selectedVoiceId,
                        decoration: const InputDecoration(
                          labelText: '语音',
                          border: OutlineInputBorder(),
                        ),
                        items: voices.map((voice) {
                          final id =
                              (voice['name'] ?? voice['identifier']).toString();
                          final locale = (voice['locale'] ?? '').toString();
                          final label =
                              locale.isEmpty ? id : '$id ($locale)';
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(label,
                                overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (value) async {
                          if (value == null) return;
                          await _tts.setVoiceById(value);
                          if (mounted) {
                            setState(() {});
                            sheetSetState(() {});
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showTtsTimerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('定时停止',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              for (final minutes in <int?>[null, 15, 30, 60])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title:
                      Text(minutes == null ? '关闭定时' : '$minutes 分钟后停止'),
                  trailing: _state.ttsSleepMinutes == minutes
                      ? const Icon(Icons.check, color: Color(0xFF00A88F))
                      : null,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _setTtsSleepTimer(minutes);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _setTtsSleepTimer(int? minutes) {
    _ttsSleepTimer?.cancel();
    setState(() => _state.ttsSleepMinutes = minutes);
    if (minutes == null) return;
    _ttsSleepTimer = Timer(Duration(minutes: minutes), () async {
      await _stopTts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('朗读已按定时停止')),
      );
    });
  }

  /// 更多面板——低频功能入口
  void _showMorePanel(ReaderProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: const Text('书签'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showBookmarkList();
                },
              ),
              ListTile(
                leading: const Icon(Icons.travel_explore_outlined),
                title: const Text('换源'),
                subtitle: Text(
                  provider.book?.originName ?? '当前书源',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('换源搜索入口待接入')),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.refresh,
                  color: provider.book?.useReplaceRule == true
                      ? const Color(0xFF00A88F)
                      : null,
                ),
                title: const Text('净化规则'),
                subtitle: Text(
                  provider.book?.useReplaceRule == true ? '已启用' : '未启用',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _applyReplaceRules();
                },
              ),
              ListTile(
                leading: const Icon(Icons.category_outlined),
                title: const Text('更改类型'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showChangeTypeDialog(provider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangeTypeDialog(ReaderProvider provider) {
    final currentType = provider.book?.type ?? 0;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('更改书籍类型'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [0, 1, 2, 3].map((type) {
            final labels = ['小说', '听书', '漫画', '文件'];
            final icons = [
              Icons.menu_book,
              Icons.headphones,
              Icons.image,
              Icons.insert_drive_file,
            ];
            return ListTile(
              leading: Icon(
                type == currentType
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color:
                    type == currentType ? const Color(0xFF00A88F) : null,
              ),
              title: Row(
                children: [
                  Icon(icons[type], size: 20),
                  const SizedBox(width: 8),
                  Text(labels[type]),
                ],
              ),
              onTap: () {
                Navigator.pop(ctx);
                if (type != currentType) _changeBookType(provider, type);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeBookType(ReaderProvider provider, int type) async {
    if (_token == null || _bookUrl == null) return;
    try {
      await ApiService.instance.changeBookType(_token!, _bookUrl!, type);
      if (!mounted) return;
      setState(() => _state.isComic = type == 2);
      provider.book?.type = type;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('书籍类型已更新，请重新进入章节')),
      );
      _rebuildPages(provider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更改类型失败: $e')),
      );
    }
  }

  Future<void> _applyReplaceRules() async {
    final token = _token;
    final bookUrl = _bookUrl;
    if (token == null || bookUrl == null) return;
    final provider = context.read<ReaderProvider>();
    try {
      await ApiService.instance.updateUseReplaceRule(
        token,
        url: bookUrl,
        useReplaceRule: 1,
      );
      provider.book?.useReplaceRule = true;
      await _openChapter(
          _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0),
          chapterPosition: _state.chapterPosition);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已应用净化规则并刷新当前章节')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('应用净化规则失败: $e')),
      );
    }
  }

  void _retry() {
    if (_token != null) {
      final provider = context.read<ReaderProvider>();
      if (provider.chapters.isEmpty) {
        provider.loadChapters(_token!, loadInitialContent: false);
      } else {
        _openChapter(
            _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0),
            chapterPosition: _state.chapterPosition);
      }
    }
  }

  void _applyWakelock() {
    // wakelock 屏幕常亮——后续可接入 wakelock_plus 插件
    // 当前为占位方法，预留设置入口
  }
}

// ============================================================
// 设置面板辅助组件
// ============================================================

/// 设置行：左侧标签 + 右侧控件
class _SettingRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget child;

  const _SettingRow({
    required this.label,
    this.value,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(child: child),
          if (value != null)
            SizedBox(
              width: 48,
              child: Text(
                value!,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 选择芯片
class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip(this.label, this.selected, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00A88F) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: selected ? Colors.white : Colors.grey.shade700,
            fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
