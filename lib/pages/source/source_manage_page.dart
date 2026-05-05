import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/routes.dart';
import '../../models/book_source.dart';
import '../../providers/source_manage_provider.dart';
import '../../providers/user_provider.dart';
import 'book_source_editor_page.dart';

class SourceManagePage extends StatefulWidget {
  const SourceManagePage({Key? key}) : super(key: key);

  @override
  State<SourceManagePage> createState() => _SourceManagePageState();
}

class _SourceManagePageState extends State<SourceManagePage> {
  bool _dataLoaded = false;
  bool _showSearch = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isLoggedIn = context.read<UserProvider>().isLoggedIn;
    if (isLoggedIn && !_dataLoaded) {
      _dataLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSources());
    } else if (!isLoggedIn) {
      _dataLoaded = false;
    }
  }

  Future<void> _loadSources() async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    await context.read<SourceManageProvider>().loadSources(token, refresh: true);
  }

  String _token() => context.read<UserProvider>().token ?? '';

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final provider = context.watch<SourceManageProvider>();

    return Scaffold(
      appBar: _buildAppBar(provider),
      body: _buildBody(userProvider, provider),
      floatingActionButton: provider.selectMode ? null : FloatingActionButton(
        onPressed: _openCreateEditor,
        child: const Icon(Icons.add),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(SourceManageProvider provider) {
    if (provider.selectMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => provider.clearSelection(),
        ),
        title: Text('已选 ${provider.selectedIds.length} 项'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: '全选',
            onPressed: () => provider.selectAll(),
          ),
        ],
      );
    }

    return AppBar(
      title: _showSearch
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '搜索书源名称/URL/分组...',
                border: InputBorder.none,
              ),
              onChanged: (v) => provider.setSearchQuery(v),
            )
          : const Text('书源管理'),
      actions: [
        IconButton(
          icon: Icon(_showSearch ? Icons.close : Icons.search),
          tooltip: '搜索',
          onPressed: () {
            setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchController.clear();
                provider.setSearchQuery('');
              }
            });
          },
        ),
        if (!_showSearch) ...[
          IconButton(
            icon: const Icon(Icons.checklist),
            tooltip: '批量管理',
            onPressed: () => provider.toggleSelectMode(),
          ),
          PopupMenuButton<String>(
            onSelected: (action) => _handleMenuAction(action),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'import', child: Text('导入书源')),
              const PopupMenuItem(value: 'export_all', child: Text('导出全部')),
              const PopupMenuItem(value: 'refresh', child: Text('刷新')),
            ],
          ),
        ],
      ],
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'import':
        _showImportDialog();
        break;
      case 'export_all':
        _exportAll();
        break;
      case 'refresh':
        _dataLoaded = false;
        _loadSources();
        break;
    }
  }

  Widget _buildBody(UserProvider userProvider, SourceManageProvider provider) {
    if (!userProvider.isLoggedIn) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.source_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('请先登录'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              child: const Text('去登录'),
            ),
          ],
        ),
      );
    }

    if (provider.loading && provider.sources.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.sources.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(provider.error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadSources, child: const Text('重试')),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (!provider.selectMode && provider.sources.isNotEmpty)
          _buildTopSection(provider),
        Expanded(
          child: provider.sources.isEmpty
              ? _buildEmptyView()
              : _buildSourceList(provider),
        ),
        if (provider.selectMode && provider.selectedIds.isNotEmpty)
          _buildBatchBar(provider),
      ],
    );
  }

  Widget _buildTopSection(SourceManageProvider provider) {
    return Column(
      children: [
        _SummaryCard(provider: provider),
        if (!provider.canEdit)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '当前账号为只读模式，仅可查看书源',
                    style: TextStyle(fontSize: 13, color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        if (provider.allGroups.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: provider.allGroups.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final g = provider.allGroups[index];
                final isSelected = g == provider.filterGroup;
                return FilterChip(
                  label: Text(g, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  onSelected: (_) => provider.setFilterGroup(g),
                  visualDensity: VisualDensity.compact,
                  selectedColor: const Color(0xFF009688).withValues(alpha: 0.2),
                );
              },
            ),
          ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildEmptyView() {
    return RefreshIndicator(
      onRefresh: _loadSources,
      child: ListView(
        children: [
          const SizedBox(height: 120),
          Column(
            children: [
              const Icon(Icons.source_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('暂无书源', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _openCreateEditor,
                icon: const Icon(Icons.add),
                label: const Text('新建书源'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSourceList(SourceManageProvider provider) {
    final grouped = provider.groupedSources;
    if (grouped.isEmpty) {
      return const Center(child: Text('无匹配结果'));
    }

    return RefreshIndicator(
      onRefresh: _loadSources,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
        children: grouped.entries.map((entry) {
          return _SourceGroupSection(
            title: entry.key,
            sources: entry.value,
            provider: provider,
            canEdit: provider.canEdit,
            onToggleEnabled: (s) => provider.toggleEnabled(_token(), s),
            onToggleExplore: (s) => provider.toggleExploreEnabled(_token(), s),
            onDelete: (s) => _confirmDelete(s),
            onTop: (s) => provider.topSourceItem(_token(), s.bookSourceUrl ?? ''),
            onBottom: (s) => provider.bottomSourceItem(_token(), s.bookSourceUrl ?? ''),
            onEdit: (s) => _showEditDialog(s),
            isSelected: (id) => provider.selectedIds.contains(id),
            onToggleSelect: (id) => provider.toggleSelection(id),
            selectMode: provider.selectMode,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBatchBar(SourceManageProvider provider) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SafeArea(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _BatchActionButton(
                label: '启用',
                icon: Icons.check_circle_outline,
                onTap: () => provider.batchSetEnabled(_token(), true),
              ),
              const SizedBox(width: 8),
              _BatchActionButton(
                label: '禁用',
                icon: Icons.block,
                onTap: () => provider.batchSetEnabled(_token(), false),
              ),
              const SizedBox(width: 8),
              _BatchActionButton(
                label: '开启发现',
                icon: Icons.explore,
                onTap: () => provider.batchSetExploreEnabled(_token(), true),
              ),
              const SizedBox(width: 8),
              _BatchActionButton(
                label: '关闭发现',
                icon: Icons.explore_off,
                onTap: () => provider.batchSetExploreEnabled(_token(), false),
              ),
              const SizedBox(width: 8),
              _BatchActionButton(
                label: '置顶',
                icon: Icons.vertical_align_top,
                onTap: () => provider.batchTop(_token()),
              ),
              const SizedBox(width: 8),
              _BatchActionButton(
                label: '置底',
                icon: Icons.vertical_align_bottom,
                onTap: () => provider.batchBottom(_token()),
              ),
              const SizedBox(width: 8),
              _BatchActionButton(
                label: '分组',
                icon: Icons.folder,
                onTap: () => _showBatchGroupDialog(),
              ),
              const SizedBox(width: 8),
              _BatchActionButton(
                label: '导出',
                icon: Icons.ios_share,
                onTap: () => _exportSelected(),
              ),
              const SizedBox(width: 8),
              _BatchActionButton(
                label: '删除',
                icon: Icons.delete_outline,
                color: Colors.red,
                onTap: () => _confirmBatchDelete(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ Dialogs ============

  void _confirmDelete(BookSource source) {
    final id = source.bookSourceUrl ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除书源「${source.bookSourceName ?? id}」吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SourceManageProvider>().deleteSource(_token(), id);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmBatchDelete() {
    final provider = context.read<SourceManageProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认批量删除'),
        content: Text('确定要删除选中的 ${provider.selectedIds.length} 个书源吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.batchDelete(_token());
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showImportDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入书源'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('粘贴书源 JSON 内容（支持单个或数组）',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText: '[{...}] 或 {...}',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(ctx);
              final provider = context.read<SourceManageProvider>();
              final msg = await provider.importSources(_token(), text);
              if (msg != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(msg)),
                );
              }
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BookSource source) async {
    final detail = await context.read<SourceManageProvider>().getSourceDetail(
      _token(),
      source.bookSourceUrl ?? '',
    );
    final jsonStr = detail?['data']?['json']?.toString() ?? '';

    if (!mounted) return;
    final changed = await Navigator.pushNamed(
      context,
      AppRoutes.bookSourceEditor,
      arguments: BookSourceEditorPageArgs(
        title: '编辑书源',
        id: source.bookSourceUrl,
        initialJson: jsonStr,
      ),
    );
    if (changed == true && mounted) {
      _loadSources();
    }
  }

  void _showBatchGroupDialog() {
    final groupController = TextEditingController();
    String st = '0'; // 0=添加分组, 1=移除分组
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('修改分组'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '0', label: Text('添加分组')),
                  ButtonSegment(value: '1', label: Text('移除分组')),
                ],
                selected: {st},
                onSelectionChanged: (v) => setDialogState(() => st = v.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: groupController,
                decoration: InputDecoration(
                  hintText: st == '0' ? '输入分组名称' : '输入要移除的分组名',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.read<SourceManageProvider>().batchEditGroup(
                  _token(),
                  st: st,
                  group: groupController.text.trim(),
                );
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportSelected() async {
    final provider = context.read<SourceManageProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final json = await provider.exportSelectedSources(_token());
    if (json != null && mounted) {
      await Clipboard.setData(ClipboardData(text: json));
      messenger.showSnackBar(
        SnackBar(
          content: Text('已导出 ${provider.selectedIds.length} 个书源 JSON 到剪贴板'),
        ),
      );
      provider.clearSelection();
    }
  }

  Future<void> _exportAll() async {
    final provider = context.read<SourceManageProvider>();
    final messenger = ScaffoldMessenger.of(context);
    provider.selectAll();
    final json = await provider.exportSelectedSources(_token());
    provider.clearSelection();
    if (json != null && mounted) {
      await Clipboard.setData(ClipboardData(text: json));
      messenger.showSnackBar(
        const SnackBar(content: Text('已导出全部书源 JSON 到剪贴板')),
      );
    }
  }

  Future<void> _openCreateEditor() async {
    final changed = await Navigator.pushNamed(
      context,
      AppRoutes.bookSourceEditor,
      arguments: const BookSourceEditorPageArgs(
        title: '新建书源',
        initialJson: '{}',
      ),
    );
    if (changed == true && mounted) {
      _loadSources();
    }
  }
}

// ============ Components ============

class _SummaryCard extends StatelessWidget {
  final SourceManageProvider provider;
  const _SummaryCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _MetricItem(label: '总数', value: provider.sources.length.toString()),
            const SizedBox(width: 24),
            _MetricItem(label: '启用', value: provider.enabledCount.toString()),
            const SizedBox(width: 24),
            _MetricItem(label: '发现', value: provider.exploreEnabledCount.toString()),
            const Spacer(),
            if (provider.filterGroup.isNotEmpty)
              Chip(
                label: Text(provider.filterGroup, style: const TextStyle(fontSize: 11)),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => provider.setFilterGroup(provider.filterGroup),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  final String label;
  final String value;
  const _MetricItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SourceGroupSection extends StatelessWidget {
  final String title;
  final List<BookSource> sources;
  final SourceManageProvider provider;
  final bool canEdit;
  final void Function(BookSource) onToggleEnabled;
  final void Function(BookSource) onToggleExplore;
  final void Function(BookSource) onDelete;
  final void Function(BookSource) onTop;
  final void Function(BookSource) onBottom;
  final void Function(BookSource) onEdit;
  final bool Function(String) isSelected;
  final void Function(String) onToggleSelect;
  final bool selectMode;

  const _SourceGroupSection({
    required this.title,
    required this.sources,
    required this.provider,
    required this.canEdit,
    required this.onToggleEnabled,
    required this.onToggleExplore,
    required this.onDelete,
    required this.onTop,
    required this.onBottom,
    required this.onEdit,
    required this.isSelected,
    required this.onToggleSelect,
    required this.selectMode,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...sources.map((source) => _SourceTile(
                  source: source,
                  canEdit: canEdit,
                  onToggleEnabled: () => onToggleEnabled(source),
                  onToggleExplore: () => onToggleExplore(source),
                  onDelete: () => onDelete(source),
                  onTop: () => onTop(source),
                  onBottom: () => onBottom(source),
                  onEdit: () => onEdit(source),
                  selected: isSelected(source.bookSourceUrl ?? ''),
                  onToggleSelect: () => onToggleSelect(source.bookSourceUrl ?? ''),
                  selectMode: selectMode,
                )),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final BookSource source;
  final bool canEdit;
  final VoidCallback onToggleEnabled;
  final VoidCallback onToggleExplore;
  final VoidCallback onDelete;
  final VoidCallback onTop;
  final VoidCallback onBottom;
  final VoidCallback onEdit;
  final bool selected;
  final VoidCallback onToggleSelect;
  final bool selectMode;

  const _SourceTile({
    required this.source,
    required this.canEdit,
    required this.onToggleEnabled,
    required this.onToggleExplore,
    required this.onDelete,
    required this.onTop,
    required this.onBottom,
    required this.onEdit,
    required this.selected,
    required this.onToggleSelect,
    required this.selectMode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: selectMode ? onToggleSelect : (canEdit ? onEdit : null),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? const Color(0xFF009688) : Colors.black12,
              width: selected ? 2 : 1,
            ),
            color: selected ? const Color(0xFF009688).withValues(alpha: 0.05) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (selectMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        selected ? Icons.check_box : Icons.check_box_outline_blank,
                        color: selected ? const Color(0xFF009688) : Colors.grey,
                        size: 20,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      source.bookSourceName ?? '未命名书源',
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!selectMode && canEdit)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 20,
                      constraints: const BoxConstraints(),
                      onSelected: (action) {
                        switch (action) {
                          case 'toggle':
                            onToggleEnabled();
                            break;
                          case 'toggleExplore':
                            onToggleExplore();
                            break;
                          case 'edit':
                            onEdit();
                            break;
                          case 'top':
                            onTop();
                            break;
                          case 'bottom':
                            onBottom();
                            break;
                          case 'delete':
                            onDelete();
                            break;
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(source.enabled == true ? '禁用' : '启用'),
                        ),
                        PopupMenuItem(
                          value: 'toggleExplore',
                          child: Text(source.enabledExplore == true ? '关闭发现' : '开启发现'),
                        ),
                        const PopupMenuItem(value: 'edit', child: Text('编辑')),
                        const PopupMenuItem(value: 'top', child: Text('置顶')),
                        const PopupMenuItem(value: 'bottom', child: Text('置底')),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('删除', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                source.bookSourceUrl ?? '',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if ((source.bookSourceComment ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  source.bookSourceComment!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _StatusChip(
                    label: source.enabled == true ? '已启用' : '已禁用',
                    color: source.enabled == true
                        ? const Color(0xFFE0F2F1)
                        : const Color(0xFFF5F5F5),
                    textColor: source.enabled == true
                        ? const Color(0xFF00695C)
                        : const Color(0xFF9E9E9E),
                  ),
                  _StatusChip(
                    label: source.enabledExplore == true ? '发现已启用' : '发现已禁用',
                    color: source.enabledExplore == true
                        ? const Color(0xFFE3F2FD)
                        : const Color(0xFFF5F5F5),
                    textColor: source.enabledExplore == true
                        ? const Color(0xFF1565C0)
                        : const Color(0xFF9E9E9E),
                  ),
                  if ((source.searchUrl ?? '').isNotEmpty)
                    const _StatusChip(
                      label: '支持搜索',
                      color: Color(0xFFFFF8E1),
                      textColor: Color(0xFFF57F17),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  const _StatusChip({
    required this.label,
    required this.color,
    this.textColor = const Color(0xFF616161),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, color: textColor),
      ),
    );
  }
}

class _BatchActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _BatchActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF009688);
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: c),
      label: Text(label, style: TextStyle(fontSize: 12, color: c)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        visualDensity: VisualDensity.compact,
        side: BorderSide(color: c.withValues(alpha: 0.3)),
      ),
    );
  }
}
