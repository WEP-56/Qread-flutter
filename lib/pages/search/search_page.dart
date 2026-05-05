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
  bool _loadingSources = false;
  bool _searching = false;
  int _completedSources = 0;
  int _totalSources = 0;
  List<BookSource> _enabledSources = [];
  String? _sourceError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSources());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSources() async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    setState(() {
      _loadingSources = true;
      _sourceError = null;
    });

    try {
      final pageData = await ApiService.instance.getBookSourcesPage(token);
      final data = pageData['data'] ?? pageData;
      final md5 = data['md5']?.toString();
      final totalPages = int.tryParse(data['page']?.toString() ?? '1') ?? 1;

      List<BookSource> allSources = [];
      if (md5 != null) {
        for (int p = 1; p <= totalPages; p++) {
          final sources = await ApiService.instance.getBookSourcesNew(
            token,
            md5: md5,
            page: p,
          );
          if (sources.isEmpty) break;
          allSources.addAll(sources);
        }
      }

      if (allSources.isEmpty) {
        allSources = await ApiService.instance.getBookSources(token);
      }

      if (mounted) {
        setState(() {
          _enabledSources = allSources
              .where((s) => s.enabled == true)
              .toList();
          _loadingSources = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sourceError = '加载书源失败: $e';
          _loadingSources = false;
        });
      }
    }
  }

  Future<void> _search(String keyword) async {
    if (keyword.trim().isEmpty) return;
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    // Reload sources if needed
    if (_enabledSources.isEmpty && !_loadingSources) {
      await _loadSources();
    }

    if (_enabledSources.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('没有可用的搜索书源，请先导入支持搜索的书源')),
        );
      }
      return;
    }

    setState(() {
      _searching = true;
      _results = [];
      _completedSources = 0;
      _totalSources = _enabledSources.length.clamp(0, 6);
    });

    // Multi-source parallel search - search up to 6 sources concurrently
    final searchSources = _enabledSources.take(6).toList();

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
    if (_loadingSources) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在加载书源...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_sourceError != null && _enabledSources.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_sourceError!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadSources, child: const Text('重试')),
          ],
        ),
      );
    }

    if (_enabledSources.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('没有可用的搜索书源'),
            const SizedBox(height: 8),
            const Text('请确保已导入支持搜索的书源，且处于启用状态',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSources,
              child: const Text('刷新书源'),
            ),
          ],
        ),
      );
    }

    if (_searching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              '搜索中 $_completedSources/$_totalSources ...',
              style: const TextStyle(color: Colors.grey),
            ),
            if (_totalSources > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(
                  value: _totalSources > 0 ? _completedSources / _totalSources : null,
                ),
              ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return const Center(child: Text('输入关键词搜索'));
    }

    return RefreshIndicator(
      onRefresh: _loadSources,
      child: ListView.builder(
        itemCount: _results.length,
        itemBuilder: (context, index) {
          final result = _results[index];
          return _SearchResultTile(
            result: result,
            onAdd: () => _addToBookshelf(result),
          );
        },
      ),
    );
  }

  Future<void> _addToBookshelf(SearchResult result) async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已加入书架')),
        );
        context.read<BookshelfProvider>().loadBookshelf(token, refresh: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加失败: $e')),
        );
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
