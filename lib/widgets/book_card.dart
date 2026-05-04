import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/book.dart';
import '../../services/api_service.dart';

class BookCard extends StatelessWidget {
  final Book book;

  const BookCard({Key? key, required this.book}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final coverUrl = book.customCoverUrl ?? book.coverUrl;
    return GestureDetector(
      onTap: () {
        // TODO: 打开阅读器
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
              child: coverUrl != null && coverUrl!.isNotEmpty
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
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('书籍详情'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('更新'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('移出书架', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
