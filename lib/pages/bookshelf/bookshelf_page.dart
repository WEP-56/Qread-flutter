import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/bookshelf_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/book_card.dart';

class BookshelfPage extends StatefulWidget {
  const BookshelfPage({Key? key}) : super(key: key);

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBooks());
  }

  void _loadBooks() {
    final token = context.read<UserProvider>().token;
    if (token != null) {
      context.read<BookshelfProvider>().loadBooks(token, refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('书架'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.pushNamed(context, '/search'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBooks,
          ),
        ],
      ),
      body: Consumer<BookshelfProvider>(
        builder: (context, provider, _) {
          if (provider.loading && provider.books.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.books.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(provider.error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _loadBooks, child: const Text('重试')),
                ],
              ),
            );
          }
          if (provider.books.isEmpty) {
            return const Center(child: Text('书架空空如也，去发现添加吧'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.65,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: provider.books.length,
            itemBuilder: (context, index) {
              return BookCard(book: provider.books[index]);
            },
          );
        },
      ),
    );
  }
}
