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
  bool _showBars = false;
  final PageController _pageController = PageController();
  final ScrollController _comicScrollController = ScrollController();
  final ScrollController _novelScrollController = ScrollController();
  double _fontSize = 18.0;
  double _lineHeight = 1.8;
  bool _autoNext = true;
  String? _token;
  bool _isComic = false;
  String _theme = 'light';
  String _pageMode = 'paged'; // 'paged' or 'scroll'

  // TTS state
  final TtsService _tts = TtsService();
  bool _ttsReading = false;

  // Bookmark state
  List<Bookmark> _bookmarks = [];
  Set<int> _bookmarkChapterIndices = {};
  String? _bookUrl;

  // Pagination state
  List<String> _pages = [];
  int _currentPage = 0;

  // Content that was used to build current pages (for invalidation)
  String _lastContent = '';
  double _lastFontSize = 0;
  double _lastLineHeight = 0;
  double _lastWidth = 0;
  double _lastHeight = 0;

  static const _keyFontSize = 'reader_font_size';
  static const _keyLineHeight = 'reader_line_height';
  static const _keyAutoNext = 'reader_auto_next';
  static const _keyTheme = 'reader_theme';
  static const _keyPageMode = 'reader_page_mode';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _comicScrollController.addListener(_onComicScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initBook());
  }

  @override
  void dispose() {
    _comicScrollController.removeListener(_onComicScroll);
    _comicScrollController.dispose();
    _novelScrollController.dispose();
    _pageController.dispose();
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
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, _fontSize);
    await prefs.setDouble(_keyLineHeight, _lineHeight);
    await prefs.setBool(_keyAutoNext, _autoNext);
    await prefs.setString(_keyTheme, _theme);
    await prefs.setString(_keyPageMode, _pageMode);
  }

  void _initBook() {
    final book = ModalRoute.of(context)?.settings.arguments as Book?;
    if (book == null) return;
    _token = context.read<UserProvider>().token;
    _isComic = book.type == 2;
    _bookUrl = book.bookUrl;
    _tts.init();
    final provider = context.read<ReaderProvider>();
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
      final rawList = await ApiService.instance.getBookmarks(_token!, _bookUrl!);
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
    if (!provider.loadingContent && provider.content.isNotEmpty && _token != null) {
      _buildPages(provider);
      _prefetchNextChapter(_token!);
      // If TTS is reading, auto-start reading new chapter
      if (_ttsReading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_ttsReading && mounted) {
            _readChapterWithTts(provider.content);
          }
        });
      }
    }
  }

  void _onComicScroll() {
    if (!_autoNext) return;
    if (!_comicScrollController.hasClients) return;
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
    return (_currentPage / _pages.length).clamp(0.0, 1.0);
  }

  Future<void> _saveProgress({double? pos}) async {
    if (_token != null) {
      await context.read<ReaderProvider>().saveProgress(_token!, pos: pos ?? _getProgress());
    }
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

  void _toggleBars() => setState(() => _showBars = !_showBars);

  Color _backgroundColor() {
    switch (_theme) {
      case 'dark':
        return const Color(0xFF1a1a2e);
      case 'sepia':
        return const Color(0xFFF5E6C8);
      default:
        return const Color(0xFFF5F0E8);
    }
  }

  Color _textColor() {
    switch (_theme) {
      case 'dark':
        return const Color(0xFFd0d0d0);
      case 'sepia':
        return const Color(0xFF5D4037);
      default:
        return const Color(0xFF333333);
    }
  }

  Color _dividerColor() {
    switch (_theme) {
      case 'dark':
        return const Color(0xFF3a3a5e);
      case 'sepia':
        return const Color(0xFFE8D5B0);
      default:
        return const Color(0xFFE0D8CC);
    }
  }

  // ============ Page splitting ============

  void _buildPages(ReaderProvider provider) {
    final content = provider.content;
    if (_isComic || _isHtmlContent(content)) {
      _pages = [];
      return;
    }

    // Scroll mode doesn't need pagination
    if (_pageMode == 'scroll') {
      _pages = content.split(RegExp(r'\n+')).where((p) => p.trim().isNotEmpty).toList();
      return;
    }

    // Check if we can reuse cached pages
    final size = MediaQuery.of(context).size;
    if (content == _lastContent &&
        _fontSize == _lastFontSize &&
        _lineHeight == _lastLineHeight &&
        _pageMode == 'paged' &&
        size.width == _lastWidth &&
        size.height == _lastHeight &&
        _pages.isNotEmpty) {
      return;
    }

    _lastContent = content;
    _lastFontSize = _fontSize;
    _lastLineHeight = _lastLineHeight;
    _lastWidth = size.width;
    _lastHeight = size.height;

    final availableWidth = size.width - 40;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomBar = _showBars ? 280.0 : 24.0;
    final availableHeight = size.height - topPadding - bottomBar - 32;

    final titleHeight = _measureText(provider.currentChapter?.title ?? '',
        fontSize: _fontSize + 4, fontWeight: FontWeight.bold, maxWidth: availableWidth) + 24;

    final paragraphs = content.split(RegExp(r'\n+')).where((p) => p.trim().isNotEmpty).toList();

    final newPages = <String>[];
    var currentPageText = '';
    var currentHeight = 0.0;
    var isFirstPage = true;

    for (final para in paragraphs) {
      final indented = '　　$para';
      final paraHeight = _measureText(indented,
          fontSize: _fontSize, lineHeight: _lineHeight, maxWidth: availableWidth) + 8;

      final pageLimit = isFirstPage ? availableHeight - titleHeight : availableHeight;

      if (currentHeight + paraHeight > pageLimit && currentPageText.isNotEmpty) {
        newPages.add(currentPageText);
        currentPageText = indented;
        currentHeight = paraHeight;
        isFirstPage = false;
      } else {
        if (currentPageText.isNotEmpty) currentPageText += '\n';
        currentPageText += indented;
        currentHeight += paraHeight;
      }
    }

    if (currentPageText.isNotEmpty) {
      newPages.add(currentPageText);
    }

    setState(() {
      _pages = newPages;
      _currentPage = 0;
    });
    _pageController.jumpToPage(0);
  }

  double _measureText(String text, {required double fontSize, double? lineHeight, FontWeight? fontWeight, required double maxWidth}) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize, height: lineHeight, fontWeight: fontWeight),
      ),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }

  // ============ Tap handling ============

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<ReaderProvider>(
        builder: (context, provider, _) {
          if (provider.book == null) {
            return const Center(child: Text('未选择书籍'));
          }
          return Stack(
            children: [
              GestureDetector(
                onTapUp: (details) => _handleTap(details, provider),
                child: _buildContent(provider),
              ),
              if (_showBars) _buildTopBar(provider),
              if (_showBars) _buildBottomBar(provider),
            ],
          );
        },
      ),
    );
  }

  void _handleTap(TapUpDetails details, ReaderProvider provider) {
    final x = details.localPosition.dx;
    final w = MediaQuery.of(context).size.width;

    if (_isComic) {
      if (x < w / 3) {
        _comicScrollUp();
      } else if (x > w * 2 / 3) {
        _comicScrollDown();
      } else {
        _toggleBars();
      }
      return;
    }

    // Novel scroll mode: tap to toggle bars only
    if (_pageMode == 'scroll') {
      _toggleBars();
      return;
    }

    // Novel paged mode: page flip
    if (x < w / 3) {
      _previousPage(provider);
    } else if (x > w * 2 / 3) {
      _nextPage(provider);
    } else {
      _toggleBars();
    }
  }

  void _previousPage(ReaderProvider provider) {
    if (_pages.isEmpty) return;
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      setState(() {
        _currentPage--;
      });
    } else if (provider.hasPrevious) {
      _saveProgress(pos: 0.0);
      if (_token != null) provider.previousChapter(_token!);
    }
  }

  void _nextPage(ReaderProvider provider) {
    if (_pages.isEmpty) return;
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      setState(() => _currentPage++);
    } else if (_autoNext && provider.hasNext) {
      // Auto-advance only when explicitly enabled AND on the last page
      _saveProgress(pos: 1.0);
      if (_token != null) provider.nextChapter(_token!);
    } else {
      // Last page: give feedback that they need to use the button
      _toggleBars();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已是本章最后一页，请使用底部「下一章」按钮'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _comicScrollUp() {
    if (!_comicScrollController.hasClients) return;
    final pageHeight = MediaQuery.of(context).size.height * 0.8;
    _comicScrollController.animateTo(
      (_comicScrollController.offset - pageHeight).clamp(0.0, _comicScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _comicScrollDown() {
    if (!_comicScrollController.hasClients) return;
    final pageHeight = MediaQuery.of(context).size.height * 0.8;
    _comicScrollController.animateTo(
      (_comicScrollController.offset + pageHeight).clamp(0.0, _comicScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
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

  // ============ Content ============

  Widget _buildContent(ReaderProvider provider) {
    final bg = _backgroundColor();

    if (provider.loadingChapters && provider.chapters.isEmpty) {
      return Scaffold(backgroundColor: bg, body: const Center(child: CircularProgressIndicator()));
    }

    if (provider.error != null && provider.chapters.isEmpty) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
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

    // Handle audio/file types
    final bookType = provider.book?.type ?? 0;
    if (bookType == 1) {
      return Scaffold(
        backgroundColor: bg,
        body: SafeArea(child: _buildAudioPlaceholder(provider)),
      );
    }
    if (bookType == 3) {
      return Scaffold(
        backgroundColor: bg,
        body: SafeArea(child: _buildFilePlaceholder()),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: provider.loadingContent && provider.content.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : provider.error != null && provider.content.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('加载章节失败\n${provider.error}',
                              style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _retry, child: const Text('重试')),
                      ],
                    ),
                  )
                : _isComic || _isHtmlContent(provider.content)
                    ? _buildComicContent(provider)
                    : _pageMode == 'scroll'
                        ? _buildScrollNovelContent(provider)
                        : _buildNovelContent(provider),
      ),
    );
  }

  // ============ Comic / HTML content ============

  bool _isHtmlContent(String content) {
    return RegExp(r'<\s*(img|p|div|br|a|span|table|video|source)', caseSensitive: false)
        .hasMatch(content);
  }

  String _proxyImages(String html) {
    final baseUrl = AppConstants.apiBase;
    return html.replaceAllMapped(
      RegExp(r"""<img\s[^>]*src\s*=\s*["']([^"']+)["'][^>]*>""", caseSensitive: false),
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
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _comicScrollController,
            padding: isComic ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              if (!isComic && provider.currentChapter?.title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16, left: 12, right: 12),
                  child: Text(provider.currentChapter!.title!,
                      style: TextStyle(fontSize: _fontSize + 4, fontWeight: FontWeight.bold, color: _textColor())),
                ),
              Html(
                data: _proxyImages(provider.content),
                style: {
                  'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
                  'img': Style(
                    margin: isComic ? Margins.zero : Margins.only(bottom: 8),
                    width: isComic ? Width(double.infinity) : null,
                  ),
                  'p': Style(
                    margin: Margins.only(bottom: 8),
                    fontSize: FontSize(_fontSize),
                    lineHeight: LineHeight(_lineHeight),
                    color: _textColor(),
                  ),
                },
              ),
            ],
          ),
        ),
        _buildProgressBar(provider),
      ],
    );
  }

  // ============ Type placeholders ============

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
            color: _ttsReading ? const Color(0xFF009688) : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text('有声书朗读', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            _ttsReading
                ? (provider.currentChapter?.title ?? '朗读中...')
                : '点击下方按钮开始朗读',
            style: TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_ttsReading) ...[
            // Progress bar
            SizedBox(
              width: 250,
              child: LinearProgressIndicator(
                value: hasContent ? (_tts.currentCharOffset / provider.content.length).clamp(0.0, 1.0) : null,
                backgroundColor: _dividerColor(),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF009688)),
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
                    _tts.state == TtsState.paused ? Icons.play_arrow : Icons.pause,
                    size: 40,
                  ),
                  onPressed: () {
                    if (_tts.state == TtsState.paused) {
                      _readChapterWithTts(provider.content);
                    } else {
                      _pauseTts();
                    }
                  },
                  tooltip: _tts.state == TtsState.paused ? '继续' : '暂停',
                ),
              ] else
                IconButton(
                  icon: const Icon(Icons.play_arrow, size: 48),
                  onPressed: _startTts,
                  tooltip: '开始朗读',
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (!_ttsReading) ...[
            // Speed control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('慢', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Slider(
                      value: _tts.rate,
                      min: 0.1, max: 1.0, divisions: 9,
                      onChanged: (v) => _tts.setRate(v),
                    ),
                  ),
                  const Text('快', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.swap_horiz),
              label: const Text('切换为小说模式'),
              onPressed: () {
                _changeBookType(provider, 0);
              },
            ),
          ],
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
          Text('该书籍为文件类型', style: TextStyle(color: _textColor(), fontSize: 16)),
          const SizedBox(height: 4),
          const Text('请使用外部应用打开', style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  // ============ Novel paginated content ============

  Widget _buildScrollNovelContent(ReaderProvider provider) {
    if (_pages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final textColor = _textColor();
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: _novelScrollController,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              if (provider.currentChapter?.title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(provider.currentChapter!.title!,
                      style: TextStyle(fontSize: _fontSize + 4, fontWeight: FontWeight.bold, color: textColor)),
                ),
              ..._pages.map((para) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('　　$para',
                        style: TextStyle(fontSize: _fontSize, color: textColor, height: _lineHeight)),
                  )),
            ],
          ),
        ),
        _buildProgressBar(provider),
      ],
    );
  }

  Widget _buildNovelContent(ReaderProvider provider) {
    if (_pages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final textColor = _textColor();

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (page) {
              setState(() => _currentPage = page);
            },
            itemBuilder: (context, pageIndex) {
              final isFirstPage = pageIndex == 0;
              return SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isFirstPage && provider.currentChapter?.title != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Text(provider.currentChapter!.title!,
                            style: TextStyle(fontSize: _fontSize + 4, fontWeight: FontWeight.bold, color: textColor)),
                      ),
                    ..._pages[pageIndex].split('\n').where((p) => p.trim().isNotEmpty).map((para) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(para,
                            style: TextStyle(fontSize: _fontSize, color: textColor, height: _lineHeight)),
                      );
                    }),
                    // Bottom spacer text showing page number
                    if (_showBars)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Center(
                          child: Text('${pageIndex + 1} / ${_pages.length}',
                              style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.3))),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        _buildProgressBar(provider),
      ],
    );
  }

  // ============ Progress bar ============

  Widget _buildProgressBar(ReaderProvider provider) {
    final total = provider.chapters.length;
    final current = provider.currentChapterIndex + 1;
    final progress = total > 0 ? current / total : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: _backgroundColor(),
      child: Row(
        children: [
          Text('$current/$total', style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: _dividerColor(),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF009688)),
            ),
          ),
          const SizedBox(width: 8),
          Text('${(progress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
        ],
      ),
    );
  }

  // ============ Top / Bottom bars ============

  Widget _buildTopBar(ReaderProvider provider) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: SafeArea(
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _saveProgress(pos: _getProgress());
                  Navigator.pop(context);
                },
              ),
              Expanded(
                child: Text(provider.book?.name ?? '',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                icon: Icon(
                  _hasBookmarkAtCurrent(provider) ? Icons.bookmark : Icons.bookmark_border,
                  color: _hasBookmarkAtCurrent(provider) ? const Color(0xFF009688) : null,
                ),
                tooltip: _hasBookmarkAtCurrent(provider) ? '删除书签' : '添加书签',
                onPressed: () => _toggleBookmark(provider),
              ),
              PopupMenuButton<String>(
                onSelected: (action) {
                  if (action == 'type') _showChangeTypeDialog(provider);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'type', child: Text('更改类型')),
                ],
              ),
              IconButton(icon: const Icon(Icons.list), onPressed: () => _showChapterList(provider)),
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
          children: [0, 1, 2, 3].map((t) {
            final labels = ['小说', '听书', '漫画', '文件'];
            final icons = [Icons.menu_book, Icons.headphones, Icons.image, Icons.insert_drive_file];
            return ListTile(
              leading: Radio<int>(
                value: t,
                groupValue: currentType,
                onChanged: (v) {
                  Navigator.pop(ctx);
                  if (v != null && v != currentType) _changeBookType(provider, v);
                },
              ),
              title: Row(children: [Icon(icons[t], size: 20), const SizedBox(width: 8), Text(labels[t])]),
              onTap: () {
                Navigator.pop(ctx);
                if (t != currentType) _changeBookType(provider, t);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ],
      ),
    );
  }

  Future<void> _changeBookType(ReaderProvider provider, int type) async {
    if (_token == null || _bookUrl == null) return;
    try {
      await ApiService.instance.changeBookType(_token!, _bookUrl!, type);
      if (mounted) {
        setState(() => _isComic = type == 2);
        provider.book?.type = type;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('书籍类型已更新，请重新进入章节')),
        );
        // Reload content with new type
        _buildPages(provider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更改类型失败: $e')),
        );
      }
    }
  }

  Widget _buildBottomBar(ReaderProvider provider) {
    final isNovel = !_isComic;
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: provider.hasPrevious ? _goToPreviousChapter : null,
                          child: const Text('上一章'),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: () => _showChapterList(provider),
                          child: Text(provider.currentChapter?.title ?? '目录',
                              overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: provider.hasNext ? _goToNextChapter : null,
                          child: const Text('下一章'),
                        ),
                      ),
                    ],
                  ),
                ),
                // Theme selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Text('主题', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'light', label: Text('浅色', style: TextStyle(fontSize: 11))),
                            ButtonSegment(value: 'dark', label: Text('深色', style: TextStyle(fontSize: 11))),
                            ButtonSegment(value: 'sepia', label: Text('护眼', style: TextStyle(fontSize: 11))),
                          ],
                          selected: {_theme},
                          onSelectionChanged: (v) {
                            setState(() => _theme = v.first);
                            _saveSettings();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (isNovel) ...[
                  const SizedBox(height: 8),
                  // Page mode
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text('翻页', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'paged', label: Text('覆盖', style: TextStyle(fontSize: 11))),
                              ButtonSegment(value: 'scroll', label: Text('滚动', style: TextStyle(fontSize: 11))),
                            ],
                            selected: {_pageMode},
                            onSelectionChanged: (v) {
                              setState(() => _pageMode = v.first);
                              _saveSettings();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _buildPages(context.read<ReaderProvider>());
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text('字号', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: _fontSize, min: 12, max: 32, divisions: 20,
                            label: _fontSize.round().toString(),
                            onChanged: (v) => setState(() => _fontSize = v),
                            onChangeEnd: (v) {
                              _saveSettings();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _buildPages(context.read<ReaderProvider>());
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        const Text('行距', style: TextStyle(fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: _lineHeight, min: 1.0, max: 3.0, divisions: 20,
                            label: _lineHeight.toStringAsFixed(1),
                            onChanged: (v) => setState(() => _lineHeight = v),
                            onChangeEnd: (v) {
                              _saveSettings();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                _buildPages(context.read<ReaderProvider>());
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Text('自动下一章', style: TextStyle(fontSize: 12)),
                      Switch(
                        value: _autoNext,
                        onChanged: (v) {
                          setState(() => _autoNext = v);
                          _saveSettings();
                        },
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        icon: Icon(_ttsReading ? Icons.stop : Icons.record_voice_over, size: 16),
                        label: Text(_ttsReading ? '停止朗读' : '朗读', style: const TextStyle(fontSize: 12)),
                        onPressed: () {
                          if (_ttsReading) {
                            _stopTts();
                          } else {
                            _startTts();
                          }
                        },
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.bookmark, size: 16),
                        label: const Text('书签列表', style: TextStyle(fontSize: 12)),
                        onPressed: () => _showBookmarkList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============ Chapter list ============

  void _showChapterList(ReaderProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7, minChildSize: 0.3, maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('目录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${provider.chapters.length} 章', style: const TextStyle(color: Colors.grey)),
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
                      selectedTileColor: const Color(0xFF009688).withValues(alpha: 0.1),
                      leading: hasBookmark
                          ? const Icon(Icons.bookmark, size: 16, color: Color(0xFF009688))
                          : null,
                      title: Text(chapter.title ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: isCurrent ? const Color(0xFF009688) : isRead ? Colors.grey : null,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          ),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: isCurrent
                          ? const Icon(Icons.play_arrow, size: 16, color: Color(0xFF009688))
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        _saveProgress(pos: _getProgress());
                        if (_token != null) provider.goToChapter(_token!, index);
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

  // ============ TTS ============

  Future<void> _startTts() async {
    final provider = context.read<ReaderProvider>();
    final text = provider.content;
    if (text.isEmpty) return;

    setState(() => _ttsReading = true);

    _tts.onChunkComplete = () {
      if (!_ttsReading || !mounted) return;
      final p = context.read<ReaderProvider>();
      if (p.hasNext && _autoNext && _token != null) {
        _saveProgress(pos: 1.0);
        p.nextChapter(_token!);
        // _onProviderChanged will pick up the new content if _ttsReading is still true
      } else {
        setState(() => _ttsReading = false);
      }
    };

    _readChapterWithTts(text);
  }

  void _readChapterWithTts(String text) {
    // Strip HTML tags for TTS
    final plain = text.replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (plain.isNotEmpty) {
      _tts.speakText(plain);
    }
  }

  void _pauseTts() {
    _tts.pause();
  }

  Future<void> _stopTts() async {
    setState(() => _ttsReading = false);
    _tts.onChunkComplete = null;
    await _tts.stop();
  }

  void _retry() {
    if (_token != null) {
      context.read<ReaderProvider>().loadChapters(_token!);
    }
  }

  // ============ Bookmarks ============

  bool _hasBookmarkAtCurrent(ReaderProvider provider) {
    return _bookmarks.any((m) =>
        m.chapterIndex == provider.currentChapterIndex && m.chapterPos != null);
  }

  Bookmark? _bookmarkAtCurrent(ReaderProvider provider) {
    final idx = provider.currentChapterIndex;
    for (final m in _bookmarks) {
      if (m.chapterIndex == idx && m.chapterPos != null) return m;
    }
    return null;
  }

  Future<void> _toggleBookmark(ReaderProvider provider) async {
    if (_token == null || _bookUrl == null) return;
    final existing = _bookmarkAtCurrent(provider);
    if (existing != null && existing.id != null) {
      // Delete
      try {
        await ApiService.instance.deleteBookmark(_token!, existing.id!);
        await _loadBookmarks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('书签已删除')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除书签失败: $e')),
          );
        }
      }
    } else {
      // Add
      try {
        final chapterName = provider.currentChapter?.title ?? '';
        final index = provider.currentChapterIndex;
        final pos = _getProgress();
        await ApiService.instance.addBookmark(_token!,
            url: _bookUrl!, name: chapterName, index: index, pos: pos);
        await _loadBookmarks();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('书签已添加')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('添加书签失败: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteBookmark(Bookmark mark) async {
    if (_token == null || mark.id == null) return;
    try {
      await ApiService.instance.deleteBookmark(_token!, mark.id!);
      await _loadBookmarks();
    } catch (e) {
      // ignore
    }
  }

  Future<void> _jumpToBookmark(Bookmark mark) async {
    if (_token == null) return;
    final provider = context.read<ReaderProvider>();
    final targetChapter = mark.chapterIndex ?? provider.currentChapterIndex;

    Navigator.pop(context); // close dialog
    _saveProgress(pos: _getProgress());
    await provider.goToChapter(_token!, targetChapter);
  }

  void _showBookmarkList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5, minChildSize: 0.3, maxChildSize: 0.8,
        expand: false,
        builder: (ctx, scrollController) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('书签', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text('${_bookmarks.length} 个', style: const TextStyle(color: Colors.grey)),
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
                              context.read<ReaderProvider>().currentChapterIndex;
                          return ListTile(
                            leading: const Icon(Icons.bookmark, color: Color(0xFF009688)),
                            title: Text(mark.chapterName ?? '',
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontWeight: isCurrentChapter ? FontWeight.bold : FontWeight.normal)),
                            subtitle: Text(
                              mark.createTime ?? '',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
