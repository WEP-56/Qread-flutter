import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../providers/reader_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/book.dart';

class ReaderPage extends StatefulWidget {
  const ReaderPage({Key? key}) : super(key: key);

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  bool _showBars = false;
  final ScrollController _scrollController = ScrollController();
  double _fontSize = 18.0;
  double _lineHeight = 1.8;
  String? _token;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final book = ModalRoute.of(context)?.settings.arguments as Book?;
      if (book != null) {
        _token = context.read<UserProvider>().token;
        final provider = context.read<ReaderProvider>();
        provider.setBook(book);
        if (_token != null) {
          provider.loadChapters(_token!);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    if (_token != null) {
      context.read<ReaderProvider>().saveProgress(_token!);
    }
    super.dispose();
  }

  Future<void> _saveProgress() async {
    if (_token != null) {
      await context.read<ReaderProvider>().saveProgress(_token!);
    }
  }

  void _toggleBars() {
    setState(() => _showBars = !_showBars);
  }

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
              // Main content
              GestureDetector(
                onTap: _toggleBars,
                child: _buildContent(provider),
              ),

              // Top bar
              if (_showBars) _buildTopBar(provider),

              // Bottom bar
              if (_showBars) _buildBottomBar(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(ReaderProvider provider) {
    if (provider.loadingChapters) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F0E8),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (provider.error != null && provider.chapters.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F0E8),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(provider.error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _retry,
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
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
                          child: Text(
                            '加载章节失败\n${provider.error}',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _retry,
                          child: const Text('重试'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: _buildReadableContent(provider),
                      ),
                      _buildProgressBar(provider),
                    ],
                  ),
      ),
    );
  }

  Widget _buildReadableContent(ReaderProvider provider) {
    final chapter = provider.currentChapter;
    final paragraphs = provider.content.split(RegExp(r'\n+'));

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: paragraphs.length + 1, // +1 for chapter title
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Text(
              chapter?.title ?? '',
              style: TextStyle(
                fontSize: _fontSize + 4,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF333333),
                height: _lineHeight,
              ),
            ),
          );
        }
        final para = paragraphs[index - 1].trim();
        if (para.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '　　$para',
            style: TextStyle(
              fontSize: _fontSize,
              color: const Color(0xFF333333),
              height: _lineHeight,
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressBar(ReaderProvider provider) {
    final total = provider.chapters.length;
    final current = provider.currentChapterIndex + 1;
    final progress = total > 0 ? current / total : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: const Color(0xFFF5F0E8),
      child: Row(
        children: [
          Text(
            '$current/$total',
            style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE0D8CC),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF009688)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(progress * 100).toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(ReaderProvider provider) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  _saveProgress();
                  Navigator.pop(context);
                },
              ),
              Expanded(
                child: Text(
                  provider.book?.name ?? '',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.list),
                onPressed: () => _showChapterList(provider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(ReaderProvider provider) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Chapter navigation
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: provider.hasPrevious ? _previousChapter : null,
                        child: const Text('上一章'),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () => _showChapterList(provider),
                        child: Text(
                          provider.currentChapter?.title ?? '目录',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: provider.hasNext ? _nextChapter : null,
                        child: const Text('下一章'),
                      ),
                    ),
                  ],
                ),
              ),
              // Font size slider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('字号', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _fontSize,
                        min: 12,
                        max: 32,
                        divisions: 20,
                        label: _fontSize.round().toString(),
                        onChanged: (v) => setState(() => _fontSize = v),
                      ),
                    ),
                  ],
                ),
              ),
              // Line height slider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Text('行距', style: TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: _lineHeight,
                        min: 1.0,
                        max: 3.0,
                        divisions: 20,
                        label: _lineHeight.toStringAsFixed(1),
                        onChanged: (v) => setState(() => _lineHeight = v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showChapterList(ReaderProvider provider) {
    final token = context.read<UserProvider>().token;

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
                    const Text('目录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    final isCurrent = index == provider.currentChapterIndex;
                    final isRead = provider.readChapters.contains(index);

                    return ListTile(
                      dense: true,
                      selected: isCurrent,
                      selectedTileColor: const Color(0xFF009688).withOpacity(0.1),
                      title: Text(
                        chapter.title ?? '',
                        style: TextStyle(
                          fontSize: 14,
                          color: isCurrent
                              ? const Color(0xFF009688)
                              : isRead
                                  ? Colors.grey
                                  : null,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: isCurrent
                          ? const Icon(Icons.play_arrow, size: 16, color: Color(0xFF009688))
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        if (token != null) {
                          provider.goToChapter(token, index);
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

  void _previousChapter() {
    final token = context.read<UserProvider>().token;
    if (token != null) {
      context.read<ReaderProvider>().previousChapter(token);
      _scrollController.jumpTo(0);
    }
  }

  void _nextChapter() {
    final token = context.read<UserProvider>().token;
    if (token != null) {
      context.read<ReaderProvider>().nextChapter(token);
      _scrollController.jumpTo(0);
    }
  }

  void _retry() {
    final token = context.read<UserProvider>().token;
    if (token != null) {
      context.read<ReaderProvider>().loadChapters(token);
    }
  }
}
