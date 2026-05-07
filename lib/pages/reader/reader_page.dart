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
      final initialPos = provider.book?.durChapterPos ?? 0;
      final openAtEnd = initialPos > 1 << 29;
      _openChapter(
        initialIndex,
        chapterPosition: initialPos > 1 ? initialPos.round() : 0,
        openAtEnd: openAtEnd,
      );
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
    provider.saveProgress(
      _token!,
      chapterIndex: chapterIndex,
      chapterTitle: chapter?.title,
      pos: _getProgress(),
    );
  }

  Future<void> _saveProgress({double? pos}) async {
    if (_token == null) return;
    final provider = context.read<ReaderProvider>();
    final chapter = _displayedChapter(provider);
    await provider.saveProgress(
      _token!,
      chapterIndex: _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0),
      chapterTitle: chapter?.title,
      pos: pos ?? _getProgress(),
    );
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

    // 检查布局缓存（不显示 loading）
    final content = await provider.getChapterContent(token, chapterIndex);
    if (!mounted || requestSerial != _state.chapterRequestSerial) return;

    // 解析目标位置
    final targetPosition =
        _state.resolveTargetChapterPosition(
          provider.book?.durChapterIndex ?? 0,
          provider.book?.durChapterPos?.round(),
        );

    final chapterTitle = chapterIndex < provider.chapters.length
        ? provider.chapters[chapterIndex].title
        : null;

    // 排版
    final layout = _layoutChapter(
      content: content,
      chapterTitle: chapterTitle,
      chapterIndex: chapterIndex,
      targetPosition: targetPosition,
    );

    // 用新排版结果计算目标页码（而非 _state.pages，后者还是旧章节的数据）
    final targetPage = _paginationEngine
        .pageIndexForPosition(layout.pages, targetPosition)
        .clamp(0, layout.pages.length - 1);
    final normalizedPosition = layout.pages.isEmpty
        ? 0
        : layout.pages[targetPage].startPosition;

    // 先创建新 PageController，再 setState —— 避免中间状态 rebuild
    // 使用旧 controller 导致 PageView 跳到错误页码
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

    // dispose 旧 controller（在新 controller 已就位后）
    oldController.dispose();

    _paragraphKeys =
        List.generate(_state.paragraphs.length, (_) => GlobalKey());
    _state.consumePendingPosition();

    // 在 setState 之后再更新 book 的章节信息，避免 saveProgress 的
    // notifyListeners 在中间状态触发 Consumer rebuild
    provider.book?.durChapterIndex = chapterIndex;
    provider.book?.durChapterTitle = chapterTitle ?? '';

    await _prefetchNextChapter(token, chapterIndex);

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
    try {
      // 预取内容到 provider 缓存
      await provider.getChapterContent(token, nextIndex);
    } catch (_) {}
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
      _openChapter(chapterIndex - 1, openAtEnd: true);
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
      _openChapter(chapterIndex + 1, chapterPosition: 0);
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
              if (_state.showController && !_state.autoPageRunning) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _toggleController,
                    child: Container(
                        color: Colors.black.withOpacity(0.18)),
                  ),
                ),
                ControllerOverlay(
                  provider: provider,
                  bookName: provider.book?.name ?? '',
                  chapterTitle: _displayedChapter(provider)?.title ?? '',
                  sourceName:
                      provider.book?.originName ?? provider.book?.origin ?? '未知书源',
                  hasBookmark: _hasBookmarkAtCurrent(provider),
                  useReplaceRule: provider.book?.useReplaceRule == true,
                  isTtsActive: _state.ttsReading,
                  ttsState: _tts.state,
                  ttsRate: _tts.rate,
                  autoPageRunning: _state.autoPageRunning,
                  autoPageInterval: _state.autoPageInterval,
                  chapterIndex: _state.displayedChapterIndex(provider.book?.durChapterIndex ?? 0),
                  totalChapters: provider.chapters.length,
                  chapterSliderValue: _state.chapterSliderValue,
                  ttsParagraphIndex: _state.ttsParagraphIndex,
                  totalParagraphs: _state.paragraphs.length,
                  onBack: () {
                    _saveProgress(pos: _getProgress());
                    Navigator.pop(context);
                  },
                  onToggleBookmark: () => _toggleBookmark(provider),
                  onShowChangeType: () => _showChangeTypeDialog(provider),
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
                  onShowBookmarks: _showBookmarkList,
                  onSwitchSource: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('换源搜索入口待接入')),
                    );
                  },
                  onApplyReplaceRules: _applyReplaceRules,
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
    setState(() {
      _state.ttsReading = true;
      _state.continueTtsOnNextChapter = false;
      _state.showController = true;
    });
    await _speakParagraphAt(
        _state.ttsParagraphIndex >= 0 ? _state.ttsParagraphIndex : 0);
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

            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('阅读设置',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const SizedBox(width: 56, child: Text('字号')),
                        Expanded(
                          child: Slider(
                            value: _state.fontSize,
                            min: 12,
                            max: 32,
                            divisions: 20,
                            label: _state.fontSize.round().toString(),
                            onChanged: (value) => commit(
                                () => _state.fontSize = value,
                                rebuildPages: true),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 56, child: Text('行距')),
                        Expanded(
                          child: Slider(
                            value: _state.lineHeight,
                            min: 1.2,
                            max: 2.6,
                            divisions: 14,
                            label: _state.lineHeight.toStringAsFixed(1),
                            onChanged: (value) => commit(
                                () => _state.lineHeight = value,
                                rebuildPages: true),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('自动下一章'),
                      value: _state.autoNext,
                      onChanged: (value) =>
                          commit(() => _state.autoNext = value),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('翻页模式'),
                      trailing: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'paged', label: Text('覆盖')),
                          ButtonSegment(value: 'scroll', label: Text('滚动')),
                        ],
                        selected: {_state.pageMode},
                        onSelectionChanged: (value) {
                          commit(() => _state.pageMode = value.first,
                              rebuildPages: true);
                        },
                      ),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('主题'),
                      trailing: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'light', label: Text('浅色')),
                          ButtonSegment(value: 'dark', label: Text('深色')),
                          ButtonSegment(value: 'sepia', label: Text('护眼')),
                        ],
                        selected: {_state.theme},
                        onSelectionChanged: (value) =>
                            commit(() => _state.theme = value.first),
                      ),
                    ),
                    if (!_state.isComic)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('自动翻页间隔'),
                        subtitle: Text(
                            '${_state.autoPageInterval.toStringAsFixed(0)} 秒'),
                        trailing: SizedBox(
                          width: 180,
                          child: Slider(
                            value: _state.autoPageInterval,
                            min: 3,
                            max: 60,
                            divisions: 57,
                            onChanged: (value) =>
                                commit(() => _state.autoPageInterval = value),
                          ),
                        ),
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('目录'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _showChapterList(provider);
                      },
                    ),
                  ],
                ),
              ),
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
}
