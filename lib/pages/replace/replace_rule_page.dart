import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../models/replace_rule.dart';
import '../../providers/replace_rule_provider.dart';
import '../../providers/user_provider.dart';
import 'replace_rule_editor_page.dart';

class ReplaceRulePage extends StatefulWidget {
  const ReplaceRulePage({Key? key}) : super(key: key);

  @override
  State<ReplaceRulePage> createState() => _ReplaceRulePageState();
}

class _ReplaceRulePageState extends State<ReplaceRulePage> {
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadRules());
    } else if (!isLoggedIn) {
      _dataLoaded = false;
    }
  }

  Future<void> _loadRules() async {
    final token = context.read<UserProvider>().token;
    if (token == null) return;
    await context.read<ReplaceRuleProvider>().loadRules(token, refresh: true);
  }

  String _token() => context.read<UserProvider>().token ?? '';

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final provider = context.watch<ReplaceRuleProvider>();

    return Scaffold(
      appBar: _buildAppBar(provider),
      body: _buildBody(userProvider, provider),
    );
  }

  PreferredSizeWidget _buildAppBar(ReplaceRuleProvider provider) {
    if (provider.selectMode) {
      return AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: provider.clearSelection,
        ),
        title: Text('已选 ${provider.selectedIds.length} 项'),
      );
    }

    return AppBar(
      title: _showSearch
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '搜索规则',
                border: InputBorder.none,
              ),
              onChanged: provider.setSearchQuery,
            )
          : const Text('替换规则'),
      actions: [
        IconButton(
          tooltip: '搜索',
          icon: Icon(_showSearch ? Icons.close : Icons.search),
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
        if (!provider.selectMode && !_showSearch)
          PopupMenuButton<String>(
            tooltip: '分组列表',
            icon: Icon(
              Icons.filter_list,
              color: provider.filterGroup.isNotEmpty
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onSelected: provider.setFilterGroup,
            itemBuilder: (context) => [
              CheckedPopupMenuItem<String>(
                value: '',
                checked: provider.filterGroup.isEmpty,
                child: const Text('全部分组'),
              ),
              CheckedPopupMenuItem<String>(
                value: ReplaceRuleProvider.ungroupedFilter,
                checked:
                    provider.filterGroup == ReplaceRuleProvider.ungroupedFilter,
                child: const Text('未分组'),
              ),
              ...provider.allGroups.map(
                (group) => CheckedPopupMenuItem<String>(
                  value: group,
                  checked: provider.filterGroup == group,
                  child: Text(group),
                ),
              ),
            ],
          ),
        if (!provider.selectMode && !_showSearch)
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'new', child: Text('新建规则')),
              PopupMenuItem(value: 'import_online', child: Text('网络导入')),
              PopupMenuItem(value: 'import_local', child: Text('本地导入')),
              PopupMenuItem(value: 'select', child: Text('批量管理')),
            ],
          ),
      ],
    );
  }

  Widget _buildBody(UserProvider userProvider, ReplaceRuleProvider provider) {
    if (!userProvider.isLoggedIn) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cleaning_services_outlined,
                size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('请先登录'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
              child: const Text('去登录'),
            ),
          ],
        ),
      );
    }

    if (provider.loading && provider.rules.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.rules.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(provider.error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadRules, child: const Text('重试')),
          ],
        ),
      );
    }

    final rules = provider.filteredRules;

    return Column(
      children: [
        if (!provider.selectMode) _buildHeader(provider),
        Expanded(
          child: rules.isEmpty ? _buildEmpty() : _buildList(provider, rules),
        ),
        if (provider.selectMode) _buildBatchBar(provider, rules.length),
      ],
    );
  }

  Widget _buildHeader(ReplaceRuleProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          _MetricChip(
            label: '总数',
            value: provider.rules.length.toString(),
          ),
          const SizedBox(width: 12),
          _MetricChip(
            label: '启用',
            value: provider.enabledCount.toString(),
          ),
          const Spacer(),
          if (provider.filterGroup.isNotEmpty)
            TextButton(
              onPressed: () => provider.setFilterGroup(''),
              child: const Text('清除筛选'),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return RefreshIndicator(
      onRefresh: _loadRules,
      child: ListView(
        children: const [
          SizedBox(height: 140),
          Icon(Icons.cleaning_services_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Center(child: Text('暂无规则')),
        ],
      ),
    );
  }

  Widget _buildList(ReplaceRuleProvider provider, List<ReplaceRule> rules) {
    return RefreshIndicator(
      onRefresh: _loadRules,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        itemCount: rules.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final rule = rules[index];
          final id = rule.id ?? '${rule.name}#$index';
          return Material(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              leading: Checkbox(
                value: provider.selectedIds.contains(id),
                onChanged: provider.selectMode
                    ? (_) => provider.toggleSelection(id)
                    : null,
              ),
              title: Text(
                rule.name.isEmpty ? '(未命名规则)' : rule.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                (rule.groupName?.trim().isEmpty ?? true)
                    ? '未分组'
                    : rule.groupName!.trim(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: SizedBox(
                width: 132,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Switch(
                      value: rule.isEnabled,
                      onChanged: provider.selectMode
                          ? null
                          : (_) => provider.toggleEnabled(_token(), rule),
                    ),
                    IconButton(
                      tooltip: '编辑',
                      onPressed: () => _openEditor(rule),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) => _handleRowAction(value, rule),
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'top', child: Text('置顶')),
                        PopupMenuItem(value: 'copy', child: Text('复制 JSON')),
                        PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                    ),
                  ],
                ),
              ),
              onTap: provider.selectMode
                  ? () => provider.toggleSelection(id)
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildBatchBar(ReplaceRuleProvider provider, int total) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            TextButton(
              onPressed: provider.selectAllFiltered,
              child: Text('全选 (${provider.selectedIds.length}/$total)'),
            ),
            TextButton(
              onPressed: provider.invertSelection,
              child: const Text('反选'),
            ),
            const Spacer(),
            TextButton(
              onPressed: provider.selectedIds.isEmpty
                  ? null
                  : () => provider.batchDelete(_token()),
              child: const Text('删除'),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'enable') {
                  await provider.batchSetEnabled(_token(), true);
                } else if (value == 'disable') {
                  await provider.batchSetEnabled(_token(), false);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'enable', child: Text('批量启用')),
                PopupMenuItem(value: 'disable', child: Text('批量禁用')),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Text('更多'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'new':
        await _openEditor(null);
        break;
      case 'import_online':
        await _showImportUrlDialog();
        break;
      case 'import_local':
        await _importLocalFile();
        break;
      case 'select':
        context.read<ReplaceRuleProvider>().toggleSelectMode();
        break;
    }
  }

  Future<void> _handleRowAction(String action, ReplaceRule rule) async {
    switch (action) {
      case 'top':
        await context
            .read<ReplaceRuleProvider>()
            .topRule(_token(), rule.id ?? '');
        break;
      case 'copy':
        await Clipboard.setData(
          ClipboardData(
            text:
                const JsonEncoder.withIndent('  ').convert(rule.toExportJson()),
          ),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已复制规则 JSON')),
        );
        break;
      case 'delete':
        await _confirmDelete(rule);
        break;
    }
  }

  Future<void> _showImportUrlDialog() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加网址'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入以 http:// 或 https:// 开头的网址',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.link),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isEmpty) return;
              Navigator.pop(ctx);
              await _importFromUrl(url);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromUrl(String url) async {
    try {
      final resp = await Dio().get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      final text = resp.data?.trim() ?? '';
      if (text.isEmpty) {
        throw Exception('链接没有返回内容');
      }
      if (!mounted) return;
      final provider = context.read<ReplaceRuleProvider>();
      final message = await provider.importRules(_token(), text);
      if (!mounted || message == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败: $e')),
      );
    }
  }

  Future<void> _importLocalFile() async {
    const typeGroup = XTypeGroup(
      label: 'json',
      extensions: <String>['json', 'txt'],
    );
    final file = await openFile(acceptedTypeGroups: <XTypeGroup>[typeGroup]);
    if (file == null) return;
    try {
      final text = await file.readAsString();
      if (!mounted) return;
      final provider = context.read<ReplaceRuleProvider>();
      final message = await provider.importRules(_token(), text);
      if (!mounted || message == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('读取文件失败: $e')),
      );
    }
  }

  Future<void> _openEditor(ReplaceRule? rule) async {
    final changed = await Navigator.pushNamed(
      context,
      AppRoutes.replaceRuleEditor,
      arguments: ReplaceRuleEditorPageArgs(
        title: rule == null ? '新建替换规则' : '替换规则编辑',
        initialRule: rule,
      ),
    );
    if (changed == true && mounted) {
      _loadRules();
    }
  }

  Future<void> _confirmDelete(ReplaceRule rule) async {
    final id = rule.id;
    if (id == null || id.isEmpty) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定要删除规则「${rule.name}」吗？'),
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
    await context.read<ReplaceRuleProvider>().deleteRule(_token(), id);
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _MetricChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
