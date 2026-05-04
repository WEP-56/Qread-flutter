import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../services/api_service.dart';
import '../providers/bookshelf_provider.dart';
import '../providers/user_provider.dart';

class BookCard extends StatelessWidget {
  final Book book;

  const BookCard({Key? key, required this.book}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final coverUrl = book.customCoverUrl ?? book.coverUrl;
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/reader', arguments: book);
      },
      onLongPress: () => _showOptions(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: coverUrl != null && coverUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: ApiService.instance.getCoverProxyUrl(
                          coverUrl,
                          sourceUrl: book.origin,
                        ),
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        errorWidget: (_, __, ___) => const Icon(Icons.book, size: 40, color: Colors.grey),
                      ),
                    )
                  : const Icon(Icons.book, size: 40, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            book.name ?? '',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
          if (book.durChapterTitle != null)
            Text(
              book.durChapterTitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context) {
    final provider = context.read<BookshelfProvider>();
    final groups = ['未分组', ...provider.groups.map((g) => g.groupName ?? '').where((n) => n.isNotEmpty)];

    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.auto_stories),
              title: Text(book.name ?? '未知书名'),
              subtitle: Text(book.author ?? ''),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: const Text('继续阅读'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.pushNamed(context, '/reader', arguments: book);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('更新'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final token = context.read<UserProvider>().token;
                if (token != null) {
                  try {
                    await ApiService.instance.refreshBook(token, book.bookUrl ?? '');
                    context.read<BookshelfProvider>().loadBookshelf(token, refresh: true);
                  } catch (e) {
                    // ignore
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('修改类型'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showChangeTypeDialog(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('设置分组'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showGroupPicker(context, groups);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('移出书架', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(sheetContext);
                final token = context.read<UserProvider>().token;
                if (token != null) {
                  await context.read<BookshelfProvider>().removeBook(token, book);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeTypeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('修改类型'),
        children: [
          SimpleDialogOption(
            child: const Text('小说'),
            onPressed: () {
              Navigator.pop(dialogContext);
              _changeType(context, 0);
            },
          ),
          SimpleDialogOption(
            child: const Text('有声书'),
            onPressed: () {
              Navigator.pop(dialogContext);
              _changeType(context, 1);
            },
          ),
          SimpleDialogOption(
            child: const Text('漫画'),
            onPressed: () {
              Navigator.pop(dialogContext);
              _changeType(context, 2);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _changeType(BuildContext context, int type) async {
    final token = context.read<UserProvider>().token;
    if (token != null) {
      try {
        await ApiService.instance.changeBookType(token, book.bookUrl ?? '', type);
        context.read<BookshelfProvider>().loadBookshelf(token, refresh: true);
      } catch (e) {
        // ignore
      }
    }
  }

  void _showGroupPicker(BuildContext context, List<String> groups) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('选择分组', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            ...groups.map((g) => ListTile(
                  title: Text(g),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final token = context.read<UserProvider>().token;
                    if (token != null) {
                      await context.read<BookshelfProvider>().setBookGroup(
                            token,
                            g,
                            book.bookUrl ?? '',
                          );
                    }
                  },
                )),
          ],
        ),
      ),
    );
  }
}
