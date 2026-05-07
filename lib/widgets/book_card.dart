import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/book.dart';
import '../providers/bookshelf_provider.dart';
import '../providers/user_provider.dart';
import '../services/api_service.dart';

enum BookCardDisplayMode {
  compact,
  detailed,
}

class BookCard extends StatelessWidget {
  final Book book;
  final BookCardDisplayMode displayMode;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onSelectionToggle;

  const BookCard({
    Key? key,
    required this.book,
    this.displayMode = BookCardDisplayMode.compact,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectionToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final child = displayMode == BookCardDisplayMode.detailed
        ? _buildDetailedCard(context)
        : _buildCompactCard(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: selectionMode ? onSelectionToggle : () => _openReader(context),
        onLongPress:
            selectionMode ? onSelectionToggle : () => _showOptions(context),
        child: child,
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: _buildCover(context, radius: 16)),
              if (_unreadCount > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: _UnreadBadge(count: _unreadCount),
                ),
              if (selectionMode)
                Positioned(
                  top: 8,
                  left: 8,
                  child: _SelectionBadge(selected: selected),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          book.name ?? '',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _buildDetailedCard(BuildContext context) {
    final theme = Theme.of(context);
    final author = (book.author ?? '').trim();
    final source = (book.originName ?? '').trim();
    final totalChapters = book.totalChapterNum;
    final latestTitle = (book.latestChapterTitle ?? '').trim();
    final readTitle = (book.durChapterTitle ?? '').trim();
    final metaParts = <String>[
      if (author.isNotEmpty) author,
      if (totalChapters != null && totalChapters > 0) '共$totalChapters章',
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.45)
              : theme.dividerColor.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                width: 76,
                height: 104,
                child: _buildCover(context, radius: 12),
              ),
              if (selectionMode)
                Positioned(
                  top: 6,
                  left: 6,
                  child: _SelectionBadge(selected: selected),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                if (metaParts.isNotEmpty)
                  Text(
                    metaParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.72),
                    ),
                  ),
                if (readTitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '已读：$readTitle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.72),
                    ),
                  ),
                ],
                if (source.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '来源：$source',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.72),
                    ),
                  ),
                ],
                if (latestTitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${_formatRelativeTime()}：$latestTitle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color
                          ?.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_unreadCount > 0) _UnreadBadge(count: _unreadCount),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCover(BuildContext context, {required double radius}) {
    final coverUrl = book.customCoverUrl ?? book.coverUrl;
    final placeholder = Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.menu_book_rounded,
        size: radius * 2.3,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );

    if (coverUrl == null || coverUrl.isEmpty) {
      return placeholder;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: ApiService.instance.getCoverProxyUrl(
          coverUrl,
          sourceUrl: book.origin,
        ),
        fit: BoxFit.cover,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      ),
    );
  }

  int get _unreadCount {
    final total = book.totalChapterNum;
    if (total == null || total <= 0) return 0;
    final currentIndex = book.durChapterIndex ?? -1;
    final unread = total - (currentIndex + 1);
    return unread > 0 ? unread : 0;
  }

  String _formatRelativeTime() {
    final raw = book.latestChapterTime ?? book.lastCheckTime;
    if (raw == null || raw <= 0) {
      return '最近更新';
    }

    final millis = raw > 1000000000000 ? raw : raw * 1000;
    final target = DateTime.fromMillisecondsSinceEpoch(millis);
    final diff = DateTime.now().difference(target);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${target.month}月${target.day}日';
  }

  void _openReader(BuildContext context) {
    Navigator.pushNamed(context, '/reader', arguments: book);
  }

  void _showOptions(BuildContext context) {
    final provider = context.read<BookshelfProvider>();
    final groups = [
      '未分组',
      ...provider.groups
          .map((g) => g.groupName ?? '')
          .where((name) => name.isNotEmpty),
    ];

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
                _openReader(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('更新'),
              onTap: () async {
                Navigator.pop(sheetContext);
                final token = context.read<UserProvider>().token;
                final provider = context.read<BookshelfProvider>();
                if (token != null) {
                  try {
                    await ApiService.instance
                        .refreshBook(token, book.bookUrl ?? '');
                    if (!context.mounted) return;
                    provider.loadBookshelf(token, refresh: true);
                  } catch (_) {
                    // Keep behavior consistent with existing implementation.
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
                final provider = context.read<BookshelfProvider>();
                if (token != null) {
                  await provider.removeBook(token, book);
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
    final provider = context.read<BookshelfProvider>();
    if (token != null) {
      try {
        await ApiService.instance
            .changeBookType(token, book.bookUrl ?? '', type);
        if (!context.mounted) return;
        provider.loadBookshelf(token, refresh: true);
      } catch (_) {
        // Keep behavior consistent with existing implementation.
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
              child: Text(
                '选择分组',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            ...groups.map(
              (group) => ListTile(
                title: Text(group),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final token = context.read<UserProvider>().token;
                  if (token != null) {
                    await context.read<BookshelfProvider>().setBookGroup(
                          token,
                          group,
                          book.bookUrl ?? '',
                        );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  final int count;

  const _UnreadBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFFFF5A4D),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SelectionBadge extends StatelessWidget {
  final bool selected;

  const _SelectionBadge({required this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primary
            : Colors.black.withValues(alpha: 0.45),
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.92), width: 1.5),
      ),
      child: Icon(
        selected ? Icons.check_rounded : Icons.circle_outlined,
        size: 16,
        color: Colors.white,
      ),
    );
  }
}
