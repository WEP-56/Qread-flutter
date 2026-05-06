import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/constants.dart';
import '../../models/book.dart';
import '../../models/bookmark.dart';
import '../../providers/reader_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../../services/tts_service.dart';

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

  final PageController _pageController = PageController();
  final ScrollController _comicScrollController = ScrollController();
  final ScrollController _novelScrollController = ScrollController();
  final TtsService _tts = TtsService();
  final Battery _battery = Battery();

  ReaderProvider? _readerProvider;
  Timer? _metaTimer;
  Timer? _autoPageTimer;
  Timer? _ttsSleepTimer;

  bool _showController = false;
  bool _showAutoPageControls = true;
  bool _autoNext = true;
  bool _isComic = false;
  bool _autoPageRunning = false;
  bool _ttsReading = false;
  bool _continueTtsOnNextChapter = false;

  String _theme = 'light';
  String _pageMode = 'paged';
  String? _token;
  String? _bookUrl;

  double _fontSize = 18.0;
  double _lineHeight = 1.8;
  double _autoPageInterval = 12.0;

  int _currentPage = 0;
  int _ttsParagraphIndex = -1;
  int? _ttsSleepMinutes;
  int? _batteryLevel;
  double? _chapterSliderValue;

  DateTime _now = DateTime.now();

  List<Bookmark> _bookmarks = [];
  Set<int> _bookmarkChapterIndices = {};
  List<_ReaderParagraph> _paragraphs = [];
  List<_ReaderPageSlice> _pages = [];
  Map<int, int> _paragraphPageLookup = {};
  List<GlobalKey> _paragraphKeys = [];

  String _lastContent = '';
  double _lastFontSize = 0;
  double _lastLineHeight = 0;
  double _lastWidth = 0;
  double _lastHeight = 0;
  String _lastPageMode = '';

  @override
  void initState() {
    super.initState();
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
    if (_token != null) {
      context.read<ReaderProvider>().saveProgress(_token!, pos: _getProgress());
    }
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fontSize = prefs.getDouble(_keyFontSize) ?? 18.0;
      _lineHeight = prefs.getDouble(_keyLineHeight) ?? 1.8;
      _autoNext = prefs.getBool(_keyAutoNext) ?? true;
      _theme = prefs.getString(_keyTheme) ?? 'light';
      _pageMode = prefs.getString(_keyPageMode) ?? 'paged';
      _autoPageInterval = prefs.getDouble(_keyAutoPageInterval) ?? 12.0;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, _fontSize);
    await prefs.setDouble(_keyLineHeight, _lineHeight);
    await prefs.setBool(_keyAutoNext, _autoNext);
    await prefs.setString(_keyTheme, _theme);
    await prefs.setString(_keyPageMode, _pageMode);
    await prefs.setDouble(_keyAutoPageInterval, _autoPageInterval);
  }

  void _startMetaTicker() {
    _refreshBattery();
    _metaTimer?.cancel();
    _metaTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _refreshBattery();
      if (mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  Future<void> _refreshBattery() async {
    try {
      final level = await _battery.batteryLevel;
      if (!mounted) return;
      setState(() {
        _batteryLevel = level;
        _now = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    }
  }

  void _initBook() {
    final book = ModalRoute.of(context)?.settings.arguments as Book?;
    if (book == null) return;
    _token = context.read<UserProvider>().token;
    _isComic = book.type == 2;
    _bookUrl = book.bookUrl;
    _tts.init();
    final provider = context.read<ReaderProvider>();
    _readerProvider = provider;
    provider.setBook(book);
    provider.addListener(_onProviderChanged);
    if (_token != null) {
      provider.loadChapters(_token!);
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
    if (provider.loadingContent || provider.content.isEmpty || _token == null) {
      return;
    }

    _buildPages(provider);
    _prefetchNextChapter(_token!);

    if (_continueTtsOnNextChapter) {
      _continueTtsOnNextChapter = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_ttsReading) return;
        _prepareTtsParagraphs(provider.content);
        _speakParagraphAt(0);
      });
    }
  }

  void _onTtsStateChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onComicScroll() {
    if (!_autoNext || !_comicScrollController.hasClients) return;
    final maxExtent = _comicScrollController.position.maxScrollExtent;
    if (maxExtent <= 0) return;
    if (_comicScrollController.position.pixels >= maxExtent - 100) {
      final provider = context.read<ReaderProvider>();
      if (provider.hasNext && !provider.loadingContent && _token != null) {
        _goToNextChapter();
      }
    }
  }

  double _getProgress() {
    if (_isComic) {
      if (!_comicScrollController.hasClients) return 0.0;
      final max = _comicScrollController.position.maxScrollExtent;
      if (max <= 0) return 0.0;
      return (_comicScrollController.offset / max).clamp(0.0, 1.0);
    }
    if (_pageMode == 'scroll') {
      if (!_novelScrollController.hasClients) return 0.0;
      final max = _novelScrollController.position.maxScrollExtent;
      if (max <= 0) return 0.0;
      return (_novelScrollController.offset / max).clamp(0.0, 1.0);
    }
    if (_pages.isEmpty) return 0.0;
    return (_activePageIndex() / _pages.length).clamp(0.0, 1.0);
  }

  int _activePageIndex() {
    if (_pageController.hasClients) {
      final page = _pageController.page;
      if (page != null) {
        return page.round().clamp(0, _pages.isEmpty ? 0 : _pages.length - 1);
      }
    }
    if (_pages.isEmpty) return 0;
    return _currentPage.clamp(0, _pages.length - 1);
  }

  Future<void> _saveProgress({double? pos}) async {
    if (_token == null) return;
    await context
        .read<ReaderProvider>()
        .saveProgress(_token!, pos: pos ?? _getProgress());
  }

  Future<void> _prefetchNextChapter(String token) async {
    final provider = context.read<ReaderProvider>();
    if (!provider.hasNext) return;
    final nextIndex = provider.currentChapterIndex + 1;
    if (nextIndex >= provider.chapters.length) return;
    try {
      await provider.loadContent(token, nextIndex, silent: true);
    } catch (_) {}
  }

  void _toggleController() {
    if (_autoPageRunning) {
      setState(() => _showAutoPageControls = !_showAutoPageControls);
      return;
    }
    setState(() => _showController = !_showController);
  }

  Color _backgroundColor() {
    switch (_theme) {
      case 'dark':
        return const Color(0xFF101417);
      case 'sepia':
        return const Color(0xFFF4E7CF);
      default:
        return const Color(0xFFF7F1E6);
    }
  }

  Color _textColor() {
    switch (_theme) {
      case 'dark':
        return const Color(0xFFE4E7EB);
      case 'sepia':
        return const Color(0xFF5B4636);
      default:
        return const Color(0xFF2D2D2D);
    }
  }

  Color _secondaryTextColor() {
    switch (_theme) {
      case 'dark':
        return const Color(0xFF8C98A5);
      case 'sepia':
        return const Color(0xFF8B6F58);
      default:
        return const Color(0xFF8A8175);
    }
  }

  Color _dividerColor() {
    switch (_theme) {
      case 'dark':
        return const Color(0xFF23303A);
      case 'sepia':
        return const Color(0xFFDCC9A8);
      default:
        return const Color(0xFFE1D7C8);
    }
  }

  Color _highlightColor() {
    switch (_theme) {
      case 'dark':
        return const Color(0x33F4D35E);
      case 'sepia':
        return const Color(0x40D9A441);
      default:
        return const Color(0x40F0C36A);
    }
  }

  void _buildPages(ReaderProvider provider) {
    final content = provider.content;
    final plainParagraphs = _extractParagraphs(content);
    _paragraphs = [
      for (var i = 0; i < plainParagraphs.length; i++)
        _ReaderParagraph(index: i, text: plainParagraphs[i]),
    ];
    _paragraphKeys = List.generate(_paragraphs.length, (_) => GlobalKey());

    if (_isComic || _isHtmlContent(content)) {
      if (mounted) {
        setState(() {
          _pages = [];
          _paragraphPageLookup = {};
          _currentPage = 0;
        });
      }
      return;
    }

    if (_pageMode == 'scroll') {
      if (mounted) {
        setState(() {
          _pages = [];
          _paragraphPageLookup = {};
          _currentPage = 0;
        });
      }
      return;
    }

    final size = MediaQuery.of(context).size;
    if (content == _lastContent &&
        _fontSize == _lastFontSize &&
        _lineHeight == _lastLineHeight &&
        size.width == _lastWidth &&
        size.height == _lastHeight &&
        _lastPageMode == _pageMode &&
        _pages.isNotEmpty) {
      return;
    }

    _lastContent = content;
    _lastFontSize = _fontSize;
    _lastLineHeight = _lineHeight;
    _lastWidth = size.width;
    _lastHeight = size.height;
    _lastPageMode = _pageMode;

    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    const horizontalPadding = 24.0;
    const topPadding = 18.0;
    const chapterHeaderHeight = 30.0;
    const footerHeight = 22.0;
    const verticalPadding = 34.0;
    final availableWidth = size.width - horizontalPadding * 2;
    final availableHeight = size.height -
        safeTop -
        safeBottom -
        topPadding -
        chapterHeaderHeight -
        footerHeight -
        verticalPadding;

    final previousRatio =
        _pages.isEmpty ? 0.0 : (_currentPage / _pages.length).clamp(0.0, 1.0);
    final newPages = <_ReaderPageSlice>[];
    final lookup = <int, int>{};
    var currentParagraphs = <_ReaderParagraph>[];
    var currentHeight = 0.0;

    for (final paragraph in _paragraphs) {
      final text = '　　${paragraph.text}';
      final paragraphHeight = _measureText(
            text,
            fontSize: _fontSize,
            lineHeight: _lineHeight,
            maxWidth: availableWidth,
          ) +
          10;

      if (currentParagraphs.isNotEmpty &&
          currentHeight + paragraphHeight > availableHeight) {
        final pageIndex = newPages.length;
        newPages.add(_ReaderPageSlice(paragraphs: currentParagraphs));
        for (final item in currentParagraphs) {
          lookup[item.index] = pageIndex;
        }
        currentParagraphs = [paragraph];
        currentHeight = paragraphHeight;
      } else {
        currentParagraphs.add(paragraph);
        currentHeight += paragraphHeight;
      }
    }

    if (currentParagraphs.isNotEmpty) {
      final pageIndex = newPages.length;
      newPages.add(_ReaderPageSlice(paragraphs: currentParagraphs));
      for (final item in currentParagraphs) {
        lookup[item.index] = pageIndex;
      }
    }

    final targetPage = newPages.isEmpty
        ? 0
        : (previousRatio * newPages.length)
            .round()
            .clamp(0, newPages.length - 1);

    setState(() {
      _pages = newPages;
      _paragraphPageLookup = lookup;
      _currentPage = targetPage;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients || _pages.isEmpty) return;
      _pageController.jumpToPage(_currentPage.clamp(0, _pages.length - 1));
    });
  }

  List<String> _extractParagraphs(String content) {
    final plain = content
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('\r', '');
    return plain
        .split(RegExp(r'\n+'))
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  double _measureText(
    String text, {
    required double fontSize,
    double? lineHeight,
    FontWeight? fontWeight,
    required double maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          height: lineHeight,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor(),
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
              if (_showController && !_autoPageRunning) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _toggleController,
                    child:
                        Container(color: Colors.black.withValues(alpha: 0.18)),
                  ),
                ),
                _buildControllerChrome(provider),
              ],
              if (_autoPageRunning && _showAutoPageControls)
                _buildAutoPageOverlay(provider),
            ],
          );
        },
      ),
    );
  }

  void _handleTap(TapUpDetails details, ReaderProvider provider) {
    if (_autoPageRunning) {
      _toggleController();
      return;
    }

    if (_showController) return;

    final x = details.localPosition.dx;
    final width = MediaQuery.of(context).size.width;

    if (_isComic) {
      if (x < width / 3) {
        _comicScrollUp();
      } else if (x > width * 2 / 3) {
        _comicScrollDown();
      } else {
        _toggleController();
      }
      return;
    }

    if (_pageMode == 'scroll') {
      _toggleController();
      return;
    }

    if (x < width / 3) {
      _previousPage(provider);
    } else if (x > width * 2 / 3) {
      _nextPage(provider);
    } else {
      _toggleController();
    }
  }

  void _previousPage(ReaderProvider provider) {
    if (_pages.isEmpty) return;
    final currentPage = _activePageIndex();
    if (currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      setState(() => _currentPage = currentPage - 1);
    } else if (provider.hasPrevious) {
      _saveProgress(pos: 0.0);
      if (_token != null) provider.previousChapter(_token!);
    }
  }

  void _nextPage(ReaderProvider provider) {
    if (_pages.isEmpty) return;
    final currentPage = _activePageIndex();
    if (currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
      setState(() => _currentPage = currentPage + 1);
    } else if (_autoNext && provider.hasNext) {
      _saveProgress(pos: 1.0);
      if (_token != null) provider.nextChapter(_token!);
    } else {
      setState(() => _showController = true);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已到本章末页'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _comicScrollUp() {
    if (!_comicScrollController.hasClients) return;
    final pageHeight = MediaQuery.of(context).size.height * 0.8;
    _comicScrollController.animateTo(
      (_comicScrollController.offset - pageHeight)
          .clamp(0.0, _comicScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
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

  void _goToPreviousChapter() {
    _saveProgress(pos: _getProgress());
    if (_token != null) context.read<ReaderProvider>().previousChapter(_token!);
  }

  void _goToNextChapter() {
    _saveProgress(pos: _getProgress());
    if (_token != null) context.read<ReaderProvider>().nextChapter(_token!);
  }

  Widget _buildContent(ReaderProvider provider) {
    final bg = _backgroundColor();

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
    if (bookType == 1) {
      return SafeArea(child: _buildAudioPlaceholder(provider));
    }
    if (bookType == 3) {
      return SafeArea(child: _buildFilePlaceholder());
    }

    return SafeArea(
      child: provider.loadingContent && provider.content.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null && provider.content.isEmpty
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
              : _isComic || _isHtmlContent(provider.content)
                  ? _buildComicContent(provider)
                  : _pageMode == 'scroll'
                      ? _buildScrollNovelContent(provider)
                      : _buildNovelContent(provider),
    );
  }

  bool _isHtmlContent(String content) {
    return RegExp(
      r'<\s*(img|p|div|br|a|span|table|video|source)',
      caseSensitive: false,
    ).hasMatch(content);
  }

  String _proxyImages(String html) {
    final baseUrl = AppConstants.apiBase;
    return html.replaceAllMapped(
      RegExp(r"""<img\s[^>]*src\s*=\s*["']([^"']+)["'][^>]*>""",
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

  Widget _buildComicContent(ReaderProvider provider) {
    final isComic = _isComic;
    final textColor = _textColor();
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _comicScrollController,
            padding: isComic
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              if (!isComic) _buildChapterHeader(provider),
              if (!isComic) const SizedBox(height: 12),
              Html(
                data: _proxyImages(provider.content),
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
                    fontSize: FontSize(_fontSize),
                    lineHeight: LineHeight(_lineHeight),
                    color: textColor,
                  ),
                },
              ),
            ],
          ),
        ),
        _buildReadingFooter(provider),
      ],
    );
  }

  Widget _buildAudioPlaceholder(ReaderProvider provider) {
    final textColor = _textColor();
    final hasContent = provider.content.isNotEmpty;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _ttsReading ? Icons.multitrack_audio : Icons.headphones,
            size: 64,
            color: _ttsReading ? const Color(0xFF00A88F) : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '有声书朗读',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _ttsReading
                ? (provider.currentChapter?.title ?? '朗读中...')
                : '点击下方按钮开始朗读',
            style: TextStyle(color: _secondaryTextColor(), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_ttsReading) ...[
            SizedBox(
              width: 250,
              child: LinearProgressIndicator(
                value: hasContent && _paragraphs.isNotEmpty
                    ? ((_ttsParagraphIndex + 1) / _paragraphs.length)
                        .clamp(0.0, 1.0)
                    : null,
                backgroundColor: _dividerColor(),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF00A88F)),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_ttsReading) ...[
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
          Text(
            '该书籍为文件类型',
            style: TextStyle(color: _textColor(), fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '请使用外部应用打开',
            style: TextStyle(color: _secondaryTextColor(), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollNovelContent(ReaderProvider provider) {
    if (_paragraphs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChapterHeader(provider),
          const SizedBox(height: 14),
          Expanded(
            child: ListView.builder(
              controller: _novelScrollController,
              padding: EdgeInsets.zero,
              itemCount: _paragraphs.length,
              itemBuilder: (context, index) => KeyedSubtree(
                key: _paragraphKeys[index],
                child: _buildParagraph(_paragraphs[index]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildReadingFooter(provider),
        ],
      ),
    );
  }

  Widget _buildNovelContent(ReaderProvider provider) {
    if (_pages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return PageView.builder(
      controller: _pageController,
      itemCount: _pages.length,
      onPageChanged: (page) => setState(() => _currentPage = page),
      itemBuilder: (context, index) {
        final page = _pages[index];
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChapterHeader(provider),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final paragraph in page.paragraphs)
                        _buildParagraph(paragraph),
                    ],
                  ),
                ),
              ),
              _buildReadingFooter(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChapterHeader(ReaderProvider provider) {
    return Text(
      provider.currentChapter?.title ?? provider.book?.durChapterTitle ?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        color: _secondaryTextColor(),
      ),
    );
  }

  Widget _buildParagraph(_ReaderParagraph paragraph) {
    final highlighted = paragraph.index == _ttsParagraphIndex;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      decoration: BoxDecoration(
        color: highlighted ? _highlightColor() : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '　　${paragraph.text}',
        style: TextStyle(
          fontSize: _fontSize,
          color: _textColor(),
          height: _lineHeight,
        ),
      ),
    );
  }

  Widget _buildReadingFooter(ReaderProvider provider) {
    return Row(
      children: [
        Text(
          _formatTime(_now),
          style: TextStyle(fontSize: 11, color: _secondaryTextColor()),
        ),
        const Spacer(),
        Text(
          _pageIndicatorLabel(),
          style: TextStyle(fontSize: 11, color: _secondaryTextColor()),
        ),
        const Spacer(),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.battery_std, size: 13, color: _secondaryTextColor()),
            const SizedBox(width: 4),
            Text(
              _batteryLevel == null ? '--' : '$_batteryLevel%',
              style: TextStyle(fontSize: 11, color: _secondaryTextColor()),
            ),
          ],
        ),
      ],
    );
  }

  String _pageIndicatorLabel() {
    if (_isComic || _pageMode == 'scroll') {
      final total = _paragraphs.isEmpty ? 1 : _paragraphs.length;
      final current = _paragraphs.isEmpty
          ? 1
          : ((_getProgress().clamp(0.0, 0.9999) * total).floor() + 1)
              .clamp(1, total);
      return '$current/$total';
    }
    final total = _pages.isEmpty ? 1 : _pages.length;
    final current = total == 0 ? 1 : (_activePageIndex() + 1).clamp(1, total);
    return '$current/$total';
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildControllerChrome(ReaderProvider provider) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      _saveProgress(pos: _getProgress());
                      Navigator.pop(context);
                    },
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _hasBookmarkAtCurrent(provider)
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      color: _hasBookmarkAtCurrent(provider)
                          ? const Color(0xFF00A88F)
                          : Colors.white,
                    ),
                    onPressed: () => _toggleBookmark(provider),
                  ),
                  PopupMenuButton<String>(
                    color: const Color(0xFF1B232B),
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (action) {
                      if (action == 'type') _showChangeTypeDialog(provider);
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: 'type',
                        child:
                            Text('更改类型', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _ttsReading || _tts.state == TtsState.paused
                  ? _buildTtsController(provider)
                  : _buildNormalController(provider),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNormalController(ReaderProvider provider) {
    return Container(
      key: const ValueKey('normal-controller'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xE61A222B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildControllerInfo(provider),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildControllerAction(
                icon: Icons.auto_awesome_motion_outlined,
                label: '自动翻页',
                onTap: _startAutoPageMode,
              ),
              _buildControllerAction(
                icon: Icons.play_circle_outline,
                label: '朗读',
                onTap: _startTts,
              ),
              _buildControllerAction(
                icon: _theme == 'dark'
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                label: _theme == 'dark' ? '浅色' : '深色',
                onTap: _toggleReaderTheme,
              ),
              const SizedBox(width: 72),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              TextButton(
                onPressed: provider.hasPrevious ? _goToPreviousChapter : null,
                child: const Text('上一章'),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: provider.chapters.isEmpty
                        ? 0
                        : (_chapterSliderValue ??
                                provider.currentChapterIndex.toDouble())
                            .clamp(
                                0, (provider.chapters.length - 1).toDouble()),
                    min: 0,
                    max: provider.chapters.isEmpty
                        ? 1
                        : (provider.chapters.length - 1)
                            .toDouble()
                            .clamp(1, double.infinity),
                    onChanged: provider.chapters.isEmpty
                        ? null
                        : (value) {
                            setState(() => _chapterSliderValue = value);
                          },
                    onChangeEnd: provider.chapters.isEmpty
                        ? null
                        : (value) {
                            setState(() => _chapterSliderValue = null);
                            final target = value.round();
                            if (target != provider.currentChapterIndex &&
                                _token != null) {
                              _saveProgress(pos: _getProgress());
                              provider.goToChapter(_token!, target);
                            }
                          },
                  ),
                ),
              ),
              TextButton(
                onPressed: provider.hasNext ? _goToNextChapter : null,
                child: const Text('下一章'),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _buildSheetEntry(
                  icon: Icons.list_alt_outlined,
                  label: '目录',
                  onTap: () => _showChapterList(provider),
                ),
              ),
              Expanded(
                child: _buildSheetEntry(
                  icon: Icons.tune_outlined,
                  label: '设置',
                  onTap: () => _showReadingSettingsSheet(provider),
                ),
              ),
              Expanded(
                child: _buildSheetEntry(
                  icon: Icons.bookmark_outline,
                  label: '书签',
                  onTap: _showBookmarkList,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTtsController(ReaderProvider provider) {
    final total = _paragraphs.isEmpty ? 1 : _paragraphs.length;
    final current =
        _ttsParagraphIndex < 0 ? 0 : (_ttsParagraphIndex + 1).clamp(1, total);
    return Container(
      key: const ValueKey('tts-controller'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xE61A222B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildControllerInfo(provider),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: total <= 0 ? 0 : (current / total).clamp(0.0, 1.0),
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00A88F)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '段落 $current / $total',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const Spacer(),
              Text(
                '语速 ${_tts.rate.toStringAsFixed(1)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _stopTts,
                icon: const Icon(Icons.stop_circle_outlined,
                    color: Colors.white, size: 34),
              ),
              const SizedBox(width: 20),
              IconButton(
                onPressed:
                    _tts.state == TtsState.paused ? _resumeTts : _pauseTts,
                icon: Icon(
                  _tts.state == TtsState.paused
                      ? Icons.play_circle_fill
                      : Icons.pause_circle_filled,
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSheetEntry(
                  icon: Icons.timer_outlined,
                  label:
                      _ttsSleepMinutes == null ? '定时' : '$_ttsSleepMinutes分钟',
                  onTap: _showTtsTimerSheet,
                ),
              ),
              Expanded(
                child: _buildSheetEntry(
                  icon: Icons.list_alt_outlined,
                  label: '目录',
                  onTap: () => _showChapterList(provider),
                ),
              ),
              Expanded(
                child: _buildSheetEntry(
                  icon: Icons.settings_voice_outlined,
                  label: '听书设置',
                  onTap: _showTtsSettingsSheet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControllerInfo(ReaderProvider provider) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                provider.book?.name ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                provider.currentChapter?.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                provider.book?.originName ?? provider.book?.origin ?? '未知书源',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          splashRadius: 20,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('换源搜索入口待接入')),
            );
          },
          icon: const Icon(Icons.travel_explore_outlined, color: Colors.white),
        ),
        IconButton(
          splashRadius: 20,
          onPressed: _applyReplaceRules,
          icon: Icon(
            Icons.refresh,
            color: provider.book?.useReplaceRule == false
                ? Colors.white
                : const Color(0xFF00A88F),
          ),
        ),
      ],
    );
  }

  Widget _buildControllerAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetEntry({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _buildAutoPageOverlay(ReaderProvider provider) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xD91A222B),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _changeAutoPageInterval(-1),
                icon: const Icon(Icons.remove, color: Colors.white),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '自动翻页',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_autoPageInterval.toStringAsFixed(0)} 秒',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _changeAutoPageInterval(1),
                icon: const Icon(Icons.add, color: Colors.white),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _stopAutoPageMode,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('停止'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startAutoPageMode() {
    final provider = context.read<ReaderProvider>();
    _stopTts();
    setState(() {
      _autoPageRunning = true;
      _showAutoPageControls = true;
      _showController = false;
    });
    _restartAutoPageTimer(provider);
  }

  void _restartAutoPageTimer(ReaderProvider provider) {
    _autoPageTimer?.cancel();
    _autoPageTimer = Timer.periodic(
      Duration(milliseconds: (_autoPageInterval * 1000).round()),
      (_) => _performAutoPageStep(provider),
    );
    _saveSettings();
  }

  void _performAutoPageStep(ReaderProvider provider) {
    if (!mounted) return;
    if (_isComic) {
      if (_comicScrollController.hasClients &&
          _comicScrollController.offset >=
              _comicScrollController.position.maxScrollExtent - 30) {
        if (_autoNext && provider.hasNext) {
          _goToNextChapter();
        } else {
          _stopAutoPageMode();
        }
      } else {
        _comicScrollDown();
      }
      return;
    }

    if (_pageMode == 'scroll') {
      if (!_novelScrollController.hasClients) return;
      final target = (_novelScrollController.offset +
              MediaQuery.of(context).size.height * 0.75)
          .clamp(0.0, _novelScrollController.position.maxScrollExtent);
      if (target >= _novelScrollController.position.maxScrollExtent - 20) {
        if (_autoNext && provider.hasNext) {
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

    final wasLastPage = _activePageIndex() >= _pages.length - 1;
    _nextPage(provider);
    if (wasLastPage && (!provider.hasNext || !_autoNext)) {
      _stopAutoPageMode();
    }
  }

  void _changeAutoPageInterval(double delta) {
    final provider = context.read<ReaderProvider>();
    setState(() {
      _autoPageInterval = (_autoPageInterval + delta).clamp(3.0, 60.0);
    });
    if (_autoPageRunning) {
      _restartAutoPageTimer(provider);
    } else {
      _saveSettings();
    }
  }

  void _stopAutoPageMode() {
    _autoPageTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _autoPageRunning = false;
      _showAutoPageControls = true;
    });
  }

  void _toggleReaderTheme() {
    setState(() {
      _theme = _theme == 'dark' ? 'light' : 'dark';
    });
    _saveSettings();
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
      await provider.goToChapter(token, provider.currentChapterIndex);
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
                  if (mounted) _buildPages(context.read<ReaderProvider>());
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
                    const Text(
                      '阅读设置',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const SizedBox(width: 56, child: Text('字号')),
                        Expanded(
                          child: Slider(
                            value: _fontSize,
                            min: 12,
                            max: 32,
                            divisions: 20,
                            label: _fontSize.round().toString(),
                            onChanged: (value) => commit(
                                () => _fontSize = value,
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
                            value: _lineHeight,
                            min: 1.2,
                            max: 2.6,
                            divisions: 14,
                            label: _lineHeight.toStringAsFixed(1),
                            onChanged: (value) => commit(
                                () => _lineHeight = value,
                                rebuildPages: true),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('自动下一章'),
                      value: _autoNext,
                      onChanged: (value) => commit(() => _autoNext = value),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('翻页模式'),
                      trailing: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'paged', label: Text('覆盖')),
                          ButtonSegment(value: 'scroll', label: Text('滚动')),
                        ],
                        selected: {_pageMode},
                        onSelectionChanged: (value) {
                          commit(() => _pageMode = value.first,
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
                        selected: {_theme},
                        onSelectionChanged: (value) =>
                            commit(() => _theme = value.first),
                      ),
                    ),
                    if (!_isComic)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('自动翻页间隔'),
                        subtitle:
                            Text('${_autoPageInterval.toStringAsFixed(0)} 秒'),
                        trailing: SizedBox(
                          width: 180,
                          child: Slider(
                            value: _autoPageInterval,
                            min: 3,
                            max: 60,
                            divisions: 57,
                            onChanged: (value) =>
                                commit(() => _autoPageInterval = value),
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
                    const Text(
                      '听书设置',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
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
                          final label = locale.isEmpty ? id : '$id ($locale)';
                          return DropdownMenuItem<String>(
                            value: id,
                            child: Text(
                              label,
                              overflow: TextOverflow.ellipsis,
                            ),
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
              const Text(
                '定时停止',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              for (final minutes in <int?>[null, 15, 30, 60])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(minutes == null ? '关闭定时' : '$minutes 分钟后停止'),
                  trailing: _ttsSleepMinutes == minutes
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
    setState(() => _ttsSleepMinutes = minutes);
    if (minutes == null) return;
    _ttsSleepTimer = Timer(Duration(minutes: minutes), () async {
      await _stopTts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('朗读已按定时停止')),
      );
    });
  }

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
                    const Text(
                      '目录',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Text(
                      '${provider.chapters.length} 章',
                      style: const TextStyle(color: Colors.grey),
                    ),
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
                    final isCurrent = index == provider.currentChapterIndex;
                    final isRead = provider.readChapters.contains(index);
                    final hasBookmark = _bookmarkChapterIndices.contains(index);
                    return ListTile(
                      dense: true,
                      selected: isCurrent,
                      selectedTileColor:
                          const Color(0xFF00A88F).withValues(alpha: 0.10),
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
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal,
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
                        if (_token != null) {
                          provider.goToChapter(_token!, index);
                        }
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
                color: type == currentType ? const Color(0xFF00A88F) : null,
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
      setState(() => _isComic = type == 2);
      provider.book?.type = type;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('书籍类型已更新，请重新进入章节')),
      );
      _buildPages(provider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更改类型失败: $e')),
      );
    }
  }

  Future<void> _startTts() async {
    final provider = context.read<ReaderProvider>();
    final text = provider.content;
    if (text.isEmpty) return;

    _stopAutoPageMode();
    _prepareTtsParagraphs(text);
    if (_paragraphs.isEmpty) return;

    setState(() {
      _ttsReading = true;
      _continueTtsOnNextChapter = false;
      _showController = true;
    });

    await _speakParagraphAt(_ttsParagraphIndex >= 0 ? _ttsParagraphIndex : 0);
  }

  void _prepareTtsParagraphs(String text) {
    if (_paragraphs.isNotEmpty) return;
    final paragraphs = _extractParagraphs(text);
    _paragraphs = [
      for (var i = 0; i < paragraphs.length; i++)
        _ReaderParagraph(index: i, text: paragraphs[i]),
    ];
    _paragraphKeys = List.generate(_paragraphs.length, (_) => GlobalKey());
  }

  Future<void> _speakParagraphAt(int index) async {
    if (!_ttsReading || index < 0 || index >= _paragraphs.length) return;
    setState(() => _ttsParagraphIndex = index);
    _focusParagraph(index);

    _tts.onChunkComplete = () {
      if (!_ttsReading || !mounted) return;
      final nextIndex = index + 1;
      if (nextIndex < _paragraphs.length) {
        _speakParagraphAt(nextIndex);
        return;
      }

      final provider = context.read<ReaderProvider>();
      if (_autoNext && provider.hasNext && _token != null) {
        _continueTtsOnNextChapter = true;
        _saveProgress(pos: 1.0);
        provider.nextChapter(_token!);
      } else {
        _stopTts();
      }
    };

    await _tts.speakText(_paragraphs[index].text);
  }

  void _focusParagraph(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_pageMode == 'paged') {
        final pageIndex = _paragraphPageLookup[index];
        if (pageIndex != null &&
            _pageController.hasClients &&
            pageIndex != _currentPage) {
          _pageController.animateToPage(
            pageIndex,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
          setState(() => _currentPage = pageIndex);
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
    if (_ttsParagraphIndex < 0 && _paragraphs.isNotEmpty) {
      _ttsParagraphIndex = 0;
    }
    if (!_ttsReading) {
      setState(() => _ttsReading = true);
    }
    await _speakParagraphAt(
        _ttsParagraphIndex.clamp(0, _paragraphs.length - 1));
  }

  Future<void> _stopTts() async {
    _tts.onChunkComplete = null;
    _ttsSleepTimer?.cancel();
    await _tts.stop();
    if (!mounted) return;
    setState(() {
      _ttsReading = false;
      _continueTtsOnNextChapter = false;
      _ttsParagraphIndex = -1;
      _ttsSleepMinutes = null;
    });
  }

  void _retry() {
    if (_token != null) {
      context.read<ReaderProvider>().loadChapters(_token!);
    }
  }

  bool _hasBookmarkAtCurrent(ReaderProvider provider) {
    return _bookmarks.any(
      (mark) =>
          mark.chapterIndex == provider.currentChapterIndex &&
          mark.chapterPos != null,
    );
  }

  Bookmark? _bookmarkAtCurrent(ReaderProvider provider) {
    final idx = provider.currentChapterIndex;
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
      final chapterName = provider.currentChapter?.title ?? '';
      final index = provider.currentChapterIndex;
      final pos = _getProgress();
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
    final targetChapter = mark.chapterIndex ?? provider.currentChapterIndex;
    Navigator.pop(context);
    _saveProgress(pos: _getProgress());
    await provider.goToChapter(_token!, targetChapter);
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
                    const Text(
                      '书签',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
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
                          final isCurrentChapter = mark.chapterIndex ==
                              context
                                  .read<ReaderProvider>()
                                  .currentChapterIndex;
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
}

class _ReaderParagraph {
  const _ReaderParagraph({
    required this.index,
    required this.text,
  });

  final int index;
  final String text;
}

class _ReaderPageSlice {
  const _ReaderPageSlice({
    required this.paragraphs,
  });

  final List<_ReaderParagraph> paragraphs;
}
