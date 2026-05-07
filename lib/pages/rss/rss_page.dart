import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/rss_source.dart';
import '../../providers/rss_provider.dart';
import '../../providers/user_provider.dart';
import '../../widgets/rss_source_card.dart';

class RssPage extends StatefulWidget {
  const RssPage({Key? key}) : super(key: key);

  @override
  State<RssPage> createState() => _RssPageState();
}

class _RssPageState extends State<RssPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _dataLoaded = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedGroup;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tryLoadData();
  }

  void _tryLoadData() {
    final isLoggedIn = context.read<UserProvider>().isLoggedIn;
    if (isLoggedIn && !_dataLoaded) {
      _dataLoaded = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _loadSources(refresh: true));
    } else if (!isLoggedIn) {
      _dataLoaded = false;
    }
  }

  Future<void> _loadSources({bool refresh = false}) async {
    final token = context.read<UserProvider>().token;
    if (token != null) {
      await context.read<RssProvider>().loadSources(token, refresh: refresh);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final userProvider = context.watch<UserProvider>();
    final provider = context.watch<RssProvider>();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 16,
        title: _buildSearchField(),
        actions: [
          _buildGroupMenuButton(provider.sources),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '订阅源管理',
            onPressed: () => Navigator.pushNamed(context, '/rssSource'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _buildBody(userProvider, provider),
    );
  }

  Widget _buildSearchField() {
    final theme = Theme.of(context);
    final activeQuery = _searchQuery.trim().isNotEmpty;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.28),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: '搜索订阅源',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: activeQuery
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildGroupMenuButton(List<RssSource> sources) {
    final groups = _collectGroups(sources);
    return PopupMenuButton<String>(
      tooltip: '切换分组',
      position: PopupMenuPosition.under,
      icon: Icon(
        Icons.filter_list_rounded,
        color: _selectedGroup == null
            ? null
            : Theme.of(context).colorScheme.primary,
      ),
      onSelected: (value) {
        setState(() {
          _selectedGroup = value == '__all__' ? null : value;
        });
      },
      itemBuilder: (context) => [
        CheckedPopupMenuItem<String>(
          value: '__all__',
          checked: _selectedGroup == null,
          child: const Text('全部分组'),
        ),
        ...groups.map(
          (group) => CheckedPopupMenuItem<String>(
            value: group,
            checked: _selectedGroup == group,
            child: Text(group),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(UserProvider userProvider, RssProvider provider) {
    if (!userProvider.isLoggedIn) {
      return const Center(child: Text('请先登录'));
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
            ElevatedButton(
              onPressed: () => _loadSources(refresh: true),
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    if (provider.sources.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.rss_feed, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('暂无RSS订阅源'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/rssSource'),
              child: const Text('添加订阅源'),
            ),
          ],
        ),
      );
    }

    final visibleSources = _filterSources(provider.sources);
    if (visibleSources.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadSources(refresh: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            if (_selectedGroup != null || _searchQuery.trim().isNotEmpty)
              _buildFilterBanner(),
            const SizedBox(height: 60),
            const Icon(Icons.search_off_rounded, size: 54, color: Colors.grey),
            const SizedBox(height: 12),
            const Center(child: Text('没有匹配的订阅源')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadSources(refresh: true),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.8,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: visibleSources.length +
            ((_selectedGroup != null || _searchQuery.trim().isNotEmpty)
                ? 1
                : 0),
        itemBuilder: (context, index) {
          if (_selectedGroup != null || _searchQuery.trim().isNotEmpty) {
            if (index == 0) {
              return _buildFilterBanner();
            }
            index -= 1;
          }

          return RssSourceCard(
            source: visibleSources[index],
            displayMode: RssSourceCardDisplayMode.grid,
          );
        },
      ),
    );
  }

  Widget _buildFilterBanner() {
    final theme = Theme.of(context);
    final parts = <String>[
      if (_selectedGroup != null) '分组：$_selectedGroup',
      if (_searchQuery.trim().isNotEmpty) '搜索：${_searchQuery.trim()}',
    ];
    return Container(
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.18),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              parts.join('  ·  '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _selectedGroup = null;
                _searchQuery = '';
              });
            },
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }

  List<String> _collectGroups(List<RssSource> sources) {
    final groups = <String>{};
    for (final source in sources) {
      final group = (source.sourceGroup ?? '').trim();
      if (group.isNotEmpty) {
        groups.add(group);
      }
    }
    final result = groups.toList(growable: false);
    result.sort();
    return result;
  }

  List<RssSource> _filterSources(List<RssSource> sources) {
    final query = _searchQuery.trim().toLowerCase();
    return sources.where((source) {
      final name = (source.sourceName ?? '').trim();
      final group = (source.sourceGroup ?? '').trim();
      final url = (source.sourceUrl ?? '').trim();

      final matchesGroup = _selectedGroup == null || group == _selectedGroup;
      final matchesSearch = query.isEmpty ||
          name.toLowerCase().contains(query) ||
          group.toLowerCase().contains(query) ||
          url.toLowerCase().contains(query);

      return matchesGroup && matchesSearch;
    }).toList(growable: false);
  }
}
