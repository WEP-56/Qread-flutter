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

  bool _dataLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isLoggedIn = context.watch<UserProvider>().isLoggedIn;
    if (isLoggedIn && !_dataLoaded) {
      _dataLoaded = true;
      _loadData();
    } else if (!isLoggedIn) {
      _dataLoaded = false;
    }
  }

  void _loadData() {
    final token = context.read<UserProvider>().token;
    if (token != null) {
      final provider = context.read<BookshelfProvider>();
      provider.loadBookshelf(token, refresh: true);
    }
  }

  List<String> _getTabNames(BookshelfProvider provider) {
    final tabs = ['全部', '未分组', '有声书', '漫画'];
    for (final g in provider.groups) {
      if (g.groupName != null && !tabs.contains(g.groupName)) {
        tabs.add(g.groupName!);
      }
    }
    return tabs;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer2<UserProvider, BookshelfProvider>(
      builder: (context, userProvider, provider, _) {
        if (!userProvider.isLoggedIn) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.menu_book, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('请先登录'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text('去登录'),
                ),
              ],
            ),
          );
        }

        final tabNames = _getTabNames(provider);

        return Scaffold(
          appBar: AppBar(
            title: const Text('书架'),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => Navigator.pushNamed(context, '/search'),
              ),
              PopupMenuButton<String>(
                onSelected: (action) => _handleMenuAction(action),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'refresh', child: Text('刷新')),
                  const PopupMenuItem(value: 'add_group', child: Text('添加分组')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Group filter tabs
              if (tabNames.length > 1)
                Container(
                  height: 40,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    itemCount: tabNames.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final name = tabNames[index];
                      final isSelected = (index == 0 && provider.selectedGroup == null) ||
                          (name == provider.selectedGroup);
                      return ChoiceChip(
                        label: Text(name),
                        selected: isSelected,
                        onSelected: (_) {
                          provider.selectGroup(index == 0 ? null : name);
                        },
                        visualDensity: VisualDensity.compact,
                        selectedColor: const Color(0xFF009688).withOpacity(0.2),
                      );
                    },
                  ),
                ),
              // Book grid
              Expanded(
                child: _buildBookGrid(provider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBookGrid(BookshelfProvider provider) {
    if (provider.loading && provider.allBooks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null && provider.allBooks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(provider.error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('重试')),
          ],
        ),
      );
    }
    final books = provider.books;
    if (books.isEmpty) {
      return const Center(child: Text('书架空空如也，去发现添加吧'));
    }
    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: books.length,
        itemBuilder: (context, index) {
          return BookCard(book: books[index]);
        },
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'refresh':
        _dataLoaded = false;
        context.read<BookshelfProvider>().selectGroup(null);
        _loadData();
        break;
      case 'add_group':
        _showAddGroupDialog();
        break;
    }
  }

  void _showAddGroupDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加分组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '请输入分组名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(dialogContext);
              final token = context.read<UserProvider>().token;
              if (token != null) {
                final success = await context.read<BookshelfProvider>().addGroup(token, name);
                if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.read<BookshelfProvider>().error ?? '添加失败')),
                  );
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
