import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/book.dart';
import '../../providers/bookshelf_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/book_card.dart';

class BookshelfPage extends StatefulWidget {
  const BookshelfPage({Key? key}) : super(key: key);

  @override
  State<BookshelfPage> createState() => _BookshelfPageState();
}

class _BookshelfPageState extends State<BookshelfPage>
    with AutomaticKeepAliveClientMixin {
  static const _bookshelfViewModeKey = 'bookshelf_view_mode';

  @override
  bool get wantKeepAlive => true;

  bool _dataLoaded = false;
  bool _selectionMode = false;
  bool _loadedViewMode = false;
  final Set<String> _selectedBookUrls = <String>{};
  final List<String> _actionLogs = <String>[];
  BookCardDisplayMode _displayMode = BookCardDisplayMode.compact;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tryLoadData();
    _loadViewModeIfNeeded();
  }

  void _tryLoadData() {
    final isLoggedIn = context.read<UserProvider>().isLoggedIn;
    if (isLoggedIn && !_dataLoaded) {
      _dataLoaded = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _loadData(refresh: true));
    } else if (!isLoggedIn) {
      _dataLoaded = false;
      _selectionMode = false;
      _selectedBookUrls.clear();
    }
  }

  Future<void> _loadViewModeIfNeeded() async {
    if (_loadedViewMode) return;
    _loadedViewMode = true;
    final storage = await StorageService.instance;
    final raw = storage.readString(_bookshelfViewModeKey);
    if (!mounted || raw == null) return;
    setState(() {
      _displayMode = raw == 'detailed'
          ? BookCardDisplayMode.detailed
          : BookCardDisplayMode.compact;
    });
  }

  Future<void> _saveViewMode(BookCardDisplayMode mode) async {
    final storage = await StorageService.instance;
    await storage.setString(
      _bookshelfViewModeKey,
      mode == BookCardDisplayMode.detailed ? 'detailed' : 'compact',
    );
  }

  Future<void> _loadData({bool refresh = false}) async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    await context
        .read<BookshelfProvider>()
        .loadBookshelf(token, refresh: refresh);
  }

  void _addLog(String message) {
    final now = DateTime.now();
    final stamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    _actionLogs.insert(0, '[$stamp] $message');
  }

  void _toggleSelectionMode([bool? enabled]) {
    setState(() {
      _selectionMode = enabled ?? !_selectionMode;
      if (!_selectionMode) {
        _selectedBookUrls.clear();
      }
    });
  }

  void _toggleBookSelection(Book book) {
    final url = book.bookUrl;
    if (url == null || url.isEmpty) return;
    setState(() {
      if (_selectedBookUrls.contains(url)) {
        _selectedBookUrls.remove(url);
      } else {
        _selectedBookUrls.add(url);
      }
    });
  }

  void _selectAll(List<Book> books) {
    setState(() {
      _selectedBookUrls
        ..clear()
        ..addAll(
          books
              .map((book) => book.bookUrl)
              .whereType<String>()
              .where((url) => url.isNotEmpty),
        );
    });
  }

  void _invertSelection(List<Book> books) {
    final allUrls = books
        .map((book) => book.bookUrl)
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toList();

    setState(() {
      final next = <String>{};
      for (final url in allUrls) {
        if (!_selectedBookUrls.contains(url)) {
          next.add(url);
        }
      }
      _selectedBookUrls
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedBookUrls.isEmpty) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定要从书架删除 ${_selectedBookUrls.length} 本书吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;
    if (!mounted) return;

    final token = context.read<UserProvider>().token;
    final provider = context.read<BookshelfProvider>();
    final messenger = ScaffoldMessenger.of(context);
    if (token == null) return;

    final urls = _selectedBookUrls.toList(growable: false);
    try {
      await provider.deleteBooks(token, urls);
      _addLog('批量删除 ${urls.length} 本书');
      if (!mounted) return;
      _toggleSelectionMode(false);
      messenger.showSnackBar(
        SnackBar(content: Text('已删除 ${urls.length} 本书')),
      );
    } catch (e) {
      _addLog('批量删除失败: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('删除失败: $e')),
      );
    }
  }

  Future<void> _refreshBookshelf() async {
    _addLog('开始刷新书架');
    await _loadData(refresh: true);
    _addLog('书架刷新完成');
  }

  Future<void> _refreshAllBooks() async {
    final token = context.read<UserProvider>().token;
    final books = context.read<BookshelfProvider>().allBooks;
    if (token == null || books.isEmpty) return;

    final refreshable = books
        .map((book) => book.bookUrl)
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    if (refreshable.isEmpty) return;

    final progress = ValueNotifier<int>(0);
    final total = refreshable.length;
    _addLog('开始一键刷新，共 $total 本');

    if (mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('一键刷新'),
            content: ValueListenableBuilder<int>(
              valueListenable: progress,
              builder: (_, value, __) {
                final ratio = total == 0 ? 0.0 : value / total;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('正在刷新 $value / $total'),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: ratio),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }

    var successCount = 0;
    var failCount = 0;
    for (final url in refreshable) {
      try {
        await ApiService.instance.refreshBook(token, url);
        successCount++;
      } catch (e) {
        failCount++;
        _addLog('刷新失败: $url, $e');
      } finally {
        progress.value++;
      }
    }

    progress.dispose();
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    await _loadData(refresh: true);
    _addLog('一键刷新完成，成功 $successCount，本失败 $failCount 本');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('刷新完成：成功 $successCount，本失败 $failCount 本')),
    );
  }

  Future<void> _setDisplayMode(BookCardDisplayMode mode) async {
    if (_displayMode == mode) return;
    setState(() {
      _displayMode = mode;
    });
    await _saveViewMode(mode);
    _addLog(mode == BookCardDisplayMode.detailed ? '切换到详细列表' : '切换到简略卡片');
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'refresh':
        await _refreshBookshelf();
        break;
      case 'refresh_all':
        await _refreshAllBooks();
        break;
      case 'add_local':
        _showUnavailableDialog(
          title: '添加本地',
          message: '当前仓库还没有接入本地书籍导入和本地阅读链路，这个入口先保留在书架菜单里。',
        );
        break;
      case 'groups':
        _showGroupManager();
        break;
      case 'logs':
        _showActionLogs();
        break;
    }
  }

  Future<void> _showRenameGroupDialog(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final token = context.read<UserProvider>().token;
    if (token == null) return;

    final nextName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重命名分组'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '请输入新的分组名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (nextName == null || nextName.isEmpty || nextName == currentName) return;
    if (!mounted) return;

    final provider = context.read<BookshelfProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await provider.renameGroup(token, currentName, nextName);
    if (!mounted) return;
    _addLog(
        success ? '分组重命名: $currentName -> $nextName' : '分组重命名失败: $currentName');
    messenger.showSnackBar(
      SnackBar(content: Text(success ? '已重命名分组' : '分组重命名失败')),
    );
  }

  Future<void> _showDeleteGroupDialog(String name) async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('删除分组'),
            content: Text('确定删除分组“$name”吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('删除'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    if (!mounted) return;

    final provider = context.read<BookshelfProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await provider.deleteGroup(token, name);
    if (!mounted) return;
    _addLog(success ? '删除分组: $name' : '删除分组失败: $name');
    messenger.showSnackBar(
      SnackBar(content: Text(success ? '已删除分组' : '删除分组失败')),
    );
  }

  void _showGroupManager() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return Consumer<BookshelfProvider>(
          builder: (_, provider, __) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.create_new_folder_outlined),
                  title: const Text('添加分组'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showAddGroupDialog();
                  },
                ),
                if (provider.groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Text('当前还没有自定义分组'),
                  )
                else
                  ...provider.groups
                      .where(
                          (group) => (group.groupName ?? '').trim().isNotEmpty)
                      .map(
                        (group) => ListTile(
                          title: Text(group.groupName!.trim()),
                          leading: const Icon(Icons.folder_outlined),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  _showRenameGroupDialog(
                                      group.groupName!.trim());
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  _showDeleteGroupDialog(
                                      group.groupName!.trim());
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showActionLogs() {
    final logs = _actionLogs;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.68,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    Text(
                      '书架日志',
                      style: Theme.of(sheetContext).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _actionLogs.clear();
                        });
                        Navigator.pop(sheetContext);
                      },
                      child: const Text('清空'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: logs.isEmpty
                    ? const Center(child: Text('暂无日志'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: logs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(logs[index]),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnavailableDialog({
    required String title,
    required String message,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
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
                final success = await context
                    .read<BookshelfProvider>()
                    .addGroup(token, name);
                _addLog(success ? '添加分组: $name' : '添加分组失败: $name');
                if (!success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            context.read<BookshelfProvider>().error ?? '添加失败')),
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final userProvider = context.watch<UserProvider>();
    final provider = context.watch<BookshelfProvider>();

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

    return Scaffold(
      appBar: _buildAppBar(provider),
      body: _buildBody(provider),
    );
  }

  PreferredSizeWidget _buildAppBar(BookshelfProvider provider) {
    final books = provider.allBooks;

    if (_selectionMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _toggleSelectionMode(false),
        ),
        title: Text('已选择 ${_selectedBookUrls.length} 本'),
        actions: [
          TextButton(
            onPressed: books.isEmpty ? null : () => _selectAll(books),
            child: const Text('全选'),
          ),
          TextButton(
            onPressed: books.isEmpty ? null : () => _invertSelection(books),
            child: const Text('反选'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除',
            onPressed: _selectedBookUrls.isEmpty ? null : _deleteSelected,
          ),
        ],
      );
    }

    final title = '书架(${books.length})';
    final switchIcon = _displayMode == BookCardDisplayMode.compact
        ? Icons.view_agenda_outlined
        : Icons.grid_view_rounded;

    return AppBar(
      title: Text(title),
      actions: [
        IconButton(
          icon: Icon(switchIcon),
          tooltip: _displayMode == BookCardDisplayMode.compact
              ? '切换到详细列表'
              : '切换到简略卡片',
          onPressed: () => _setDisplayMode(
            _displayMode == BookCardDisplayMode.compact
                ? BookCardDisplayMode.detailed
                : BookCardDisplayMode.compact,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: '批量管理',
          onPressed: books.isEmpty ? null : () => _toggleSelectionMode(true),
        ),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: '搜索',
          onPressed: () => Navigator.pushNamed(context, '/search'),
        ),
        PopupMenuButton<String>(
          onSelected: (action) => _handleMenuAction(action),
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'refresh', child: Text('更新书架')),
            PopupMenuItem(value: 'refresh_all', child: Text('一键刷新')),
            PopupMenuItem(value: 'add_local', child: Text('添加本地')),
            PopupMenuItem(value: 'groups', child: Text('分组管理')),
            PopupMenuItem(value: 'logs', child: Text('查看日志')),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(BookshelfProvider provider) {
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
            ElevatedButton(
              onPressed: _refreshBookshelf,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    final books = provider.allBooks;
    if (books.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refreshBookshelf,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Icon(Icons.collections_bookmark_outlined,
                size: 56, color: Colors.grey),
            SizedBox(height: 12),
            Center(child: Text('书架空空如也，去发现添加吧')),
          ],
        ),
      );
    }

    return _displayMode == BookCardDisplayMode.compact
        ? _buildCompactGrid(books)
        : _buildDetailedList(books);
  }

  Widget _buildCompactGrid(List<Book> books) {
    return RefreshIndicator(
      onRefresh: _refreshBookshelf,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.58,
          crossAxisSpacing: 16,
          mainAxisSpacing: 18,
        ),
        itemCount: books.length,
        itemBuilder: (context, index) {
          final book = books[index];
          return BookCard(
            book: book,
            displayMode: BookCardDisplayMode.compact,
            selectionMode: _selectionMode,
            selected: _selectedBookUrls.contains(book.bookUrl),
            onSelectionToggle: () => _toggleBookSelection(book),
          );
        },
      ),
    );
  }

  Widget _buildDetailedList(List<Book> books) {
    return RefreshIndicator(
      onRefresh: _refreshBookshelf,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        itemCount: books.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final book = books[index];
          return BookCard(
            book: book,
            displayMode: BookCardDisplayMode.detailed,
            selectionMode: _selectionMode,
            selected: _selectedBookUrls.contains(book.bookUrl),
            onSelectionToggle: () => _toggleBookSelection(book),
          );
        },
      ),
    );
  }
}
