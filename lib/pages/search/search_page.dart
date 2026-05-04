import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/bookshelf_provider.dart';
import '../../models/search_result.dart';
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

  Future<void> _search(String keyword) async {
    if (keyword.trim().isEmpty) return;
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    setState(() => _loading = true);
    try {
      _results = await ApiService.instance.searchBook(token, keyword);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _loading = false);
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? const Center(child: Text('输入关键词搜索'))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final result = _results[index];
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: result.coverUrl != null
                            ? Image.network(result.coverUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.book))
                            : const Icon(Icons.book),
                      ),
                      title: Text(result.name ?? ''),
                      subtitle: Text('${result.author ?? ''} · ${result.originName ?? ''}'),
                      onTap: () => _addToBookshelf(result),
                    );
                  },
                ),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已加入书架')));
      context.read<BookshelfProvider>().loadBooks(token, refresh: true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('添加失败: $e')));
    }
  }
}
