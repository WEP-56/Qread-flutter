import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/bookshelf_provider.dart';
import '../../models/search_result.dart';
import '../../models/book_source.dart';
import '../../models/book.dart';
import '../../services/api_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  List<SearchResult> _results = [];
  bool _loading = false;
  bool _searching = false;
  int _completedSources = 0;
  int _totalSources = 0;
  List<BookSource> _enabledSources = [];

  @override
  void initState() {
    super.initState();
    _loadSources();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSources() async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    try {
      final pageData = await ApiService.instance.getBookSourcesPage(token);
      final md5 = pageData['md5']?.toString();
      final totalPages = int.tryParse(pageData['page']?.toString() ?? '1') ?? 1;

      List<BookSource> allSources = [];
      for (int p = 1; p <= totalPages; p++) {
        final sources = await ApiService.instance.getBookSourcesNew(
          token,
          md5: md5,
          page: p,
        );
        allSources.addAll(sources);
      }

      _enabledSources = allSources.where((s) => s.enabled == true && s.searchUrl != null && s.searchUrl!.isNotEmpty).toList();
    } catch (_) {}
  }

  Future<void> _search(String keyword) async {
    if (keyword.trim().isEmpty) return;
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    setState(() {
      _loading = true;
      _searching = true;
      _results = [];
      _completedSources = 0;
      _totalSources = _enabledSources.length;
    });

    // If no sources loaded, try single-source search
    if (_enabledSources.isEmpty) {
      try {
        final results = await ApiService.instance.searchBook(token, keyword);
        if (mounted) {
          setState(() {
            _results = results;
            _loading = false;
            _searching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _loading = false;
            _searching = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
      return;
    }

    // Multi-source parallel search - search first 6 sources concurrently
    final searchSources = _enabledSources.take(6).toList();
    _totalSources = searchSources.length;

    final futures = searchSources.map((source) async {
      try {
        final results = await ApiService.instance.searchBook(
          token,
          keyword,
          bookSourceUrl: source.bookSourceUrl,
        );
        if (mounted) {
          setState(() => _completedSources++);
        }
        return results;
      } catch (_) {
        if (mounted) {
          setState(() => _completedSources++);
        }
        return <SearchResult>[];
      }
    });

    final allResults = await Future.wait(futures);

    // Merge results, deduplicate by bookUrl+origin
    final merged = <String, SearchResult>{};
    for (final list in allResults) {
      for (final r in list) {
        final key = '${r.bookUrl}_${r.origin}';
        if (!merged.containsKey(key)) {
          merged[key] = r;
        }
      }
    }

    if (mounted) {
      setState(() {
        _results = merged.values.toList();
        _loading = false;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索书名或作者',
            border: InputBorder.none,
          ),
          onSubmitted: _search,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _search(_controller.text),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _searching ? '搜索中 $_completedSources/$_totalSources ...' : '加载中...',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(child: Text('输入关键词搜索'));
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        return _SearchResultTile(
          result: result,
          onAdd: () => _addToBookshelf(result),
        );
      },
    );
  }

  Future<void> _addToBookshelf(SearchResult result) async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    try {
      await ApiService.instance.saveBook(token, Book(
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
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入书架')));
        context.read<BookshelfProvider>().loadBookshelf(token, refresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('添加失败: $e')));
      }
    }
  }
}

class _SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onAdd;

  const _SearchResultTile({required this.result, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final coverUrl = result.coverUrl;
    return ListTile(
      leading: Container(
        width: 40,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
        child: coverUrl != null && coverUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  ApiService.instance.getCoverProxyUrl(coverUrl, sourceUrl: result.origin),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.book),
                ),
              )
            : const Icon(Icons.book),
      ),
      title: Text(result.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${result.author ?? ''} · ${result.originName ?? ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.add_box_outlined),
        onPressed: onAdd,
        tooltip: '加入书架',
      ),
      onTap: onAdd,
    );
  }
}
