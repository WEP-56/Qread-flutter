import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/book.dart';
import '../../models/search_result.dart';
import '../../providers/bookshelf_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';

class ExploreBooksPageArgs {
  final String title;
  final String sourceName;
  final String sourceUrl;
  final String exploreUrl;

  const ExploreBooksPageArgs({
    required this.title,
    required this.sourceName,
    required this.sourceUrl,
    required this.exploreUrl,
  });
}

class ExploreBooksPage extends StatefulWidget {
  final ExploreBooksPageArgs args;

  const ExploreBooksPage({
    Key? key,
    required this.args,
  }) : super(key: key);

  @override
  State<ExploreBooksPage> createState() => _ExploreBooksPageState();
}

class _ExploreBooksPageState extends State<ExploreBooksPage> {
  final ScrollController _scrollController = ScrollController();

  List<SearchResult> _results = [];
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPage(refresh: true));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || !_hasMore) {
      return;
    }
    final threshold = _scrollController.position.maxScrollExtent - 240;
    if (_scrollController.position.pixels >= threshold) {
      _loadPage();
    }
  }

  Future<void> _loadPage({bool refresh = false}) async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    if (_loading || _loadingMore) return;

    final nextPage = refresh ? 1 : _page;
    setState(() {
      if (refresh) {
        _loading = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final response = await ApiService.instance.getExplore(
        token,
        widget.args.sourceUrl,
        widget.args.exploreUrl,
        page: nextPage,
      );

      final books = _parseResults(response);
      final hasMore = _parseHasMore(response, books.length);

      setState(() {
        if (refresh) {
          _results = books;
          _page = 2;
        } else {
          _results = _mergeResults(_results, books);
          _page = nextPage + 1;
        }
        _hasMore = hasMore;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  List<SearchResult> _parseResults(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List) {
      return _parseResultList(data);
    }
    if (data is Map) {
      for (final key in const ['books', 'list', 'data']) {
        final value = data[key];
        if (value is List) {
          return _parseResultList(value);
        }
      }
    }
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is List) return _parseResultList(decoded);
        if (decoded is Map && decoded['data'] is List) return _parseResultList(decoded['data']);
      } catch (_) {}
    }
    return [];
  }

  List<SearchResult> _parseResultList(List list) {
    return list
        .whereType<Map>()
        .map((item) => SearchResult.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  bool _parseHasMore(Map<String, dynamic> response, int count) {
    final data = response['data'];
    if (data is Map) {
      final next = data['next'] ?? data['hasNext'];
      if (next is bool) return next;
      if (next is num) return next != 0;
      if (next is String) return next == 'true' || next == '1';
    }
    return count > 0;
  }

  List<SearchResult> _mergeResults(List<SearchResult> current, List<SearchResult> incoming) {
    final merged = <String, SearchResult>{};
    for (final item in current) {
      merged['${item.bookUrl}_${item.origin}'] = item;
    }
    for (final item in incoming) {
      merged['${item.bookUrl}_${item.origin}'] = item;
    }
    return merged.values.toList();
  }

  Future<void> _addToBookshelf(SearchResult result) async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    final bookshelfProvider = context.read<BookshelfProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ApiService.instance.saveBook(
        token,
        Book(
          bookUrl: result.bookUrl,
          name: result.name,
          author: result.author,
          coverUrl: result.coverUrl,
          intro: result.intro,
          tocUrl: result.tocUrl,
          origin: result.origin,
          originName: result.originName,
          type: 0,
          group: 0,
        ),
      );
      if (!mounted) return;
      await bookshelfProvider.loadBookshelf(token, refresh: true);
      messenger.showSnackBar(
        SnackBar(content: Text('已加入书架：${result.name ?? ''}')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('加入书架失败: $e')),
      );
    }
  }

  void _showBookSheet(SearchResult result) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.name ?? '未命名书籍', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text('${result.author ?? '未知作者'} · ${result.originName ?? widget.args.sourceName}'),
              if ((result.latestChapterTitle ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('最新章节：${result.latestChapterTitle}'),
              ],
              if ((result.intro ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(result.intro!),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _addToBookshelf(result);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('加入书架'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.args.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: () => _loadPage(refresh: true),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadPage(refresh: true),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (_results.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadPage(refresh: true),
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('暂无发现结果')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPage(refresh: true),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.58,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _results.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _results.length) {
            return const Center(child: CircularProgressIndicator());
          }

          final result = _results[index];
          final coverUrl = result.coverUrl;
          return GestureDetector(
            onTap: () => _showBookSheet(result),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: coverUrl != null && coverUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  ApiService.instance.getCoverProxyUrl(
                                    coverUrl,
                                    sourceUrl: result.origin,
                                  ),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.book, size: 40, color: Colors.grey),
                                ),
                              )
                            : const Icon(Icons.book, size: 40, color: Colors.grey),
                      ),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: InkWell(
                          onTap: () => _addToBookshelf(result),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF009688).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.name ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
                Text(
                  result.author ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
