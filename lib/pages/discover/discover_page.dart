import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/routes.dart';
import '../../models/book_source.dart';
import '../../providers/discover_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/api_service.dart';
import 'explore_books_page.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({Key? key}) : super(key: key);

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _dataLoaded = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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
      await context.read<DiscoverProvider>().loadExploreSources(
            token,
            refresh: refresh,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final userProvider = context.watch<UserProvider>();
    final provider = context.watch<DiscoverProvider>();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 16,
        title: _buildSearchField(),
        actions: [
          _buildGroupMenuButton(provider.exploreSources),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(userProvider, provider),
    );
  }

  Widget _buildSearchField() {
    final theme = Theme.of(context);
    final activeQuery = _searchController.text.trim().isNotEmpty;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(24),
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
          hintText: '筛选发现',
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

  Widget _buildGroupMenuButton(List<BookSource> sources) {
    final groups = _collectGroups(sources);
    return PopupMenuButton<String>(
      tooltip: '分组筛选',
      position: PopupMenuPosition.under,
      icon: const Icon(Icons.tune_rounded),
      onSelected: (value) {
        if (value == '__all__') {
          _searchController.clear();
          setState(() {
            _searchQuery = '';
          });
          return;
        }
        final query = 'group:$value';
        _searchController.value = TextEditingValue(
          text: query,
          selection: TextSelection.collapsed(offset: query.length),
        );
        setState(() {
          _searchQuery = query;
        });
      },
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: '__all__',
          child: Text('全部分组'),
        ),
        ...groups.map(
          (group) => PopupMenuItem<String>(
            value: group,
            child: Text(group),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(UserProvider userProvider, DiscoverProvider provider) {
    if (!userProvider.isLoggedIn) {
      return const Center(child: Text('请先登录'));
    }
    if (provider.loading && provider.exploreSources.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null && provider.exploreSources.isEmpty) {
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
    if (provider.exploreSources.isEmpty) {
      return const Center(child: Text('暂无可用书源'));
    }

    final visibleSources = _filterSources(provider.exploreSources);
    if (visibleSources.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadSources(refresh: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            _buildActiveSearchBanner(),
            const SizedBox(height: 64),
            const Icon(Icons.explore_off_rounded, size: 52, color: Colors.grey),
            const SizedBox(height: 12),
            const Center(child: Text('没有匹配的发现书源')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadSources(refresh: true),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
        itemCount: visibleSources.length + (_hasActiveSearch ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (_hasActiveSearch) {
            if (index == 0) {
              return _buildActiveSearchBanner();
            }
            index -= 1;
          }

          final source = visibleSources[index];
          return _DiscoverSourceTile(
            source: source,
            onTap: () => _showExplore(source),
          );
        },
      ),
    );
  }

  Widget _buildActiveSearchBanner() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _searchQuery.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
            child: const Text('清除'),
          ),
        ],
      ),
    );
  }

  bool get _hasActiveSearch => _searchQuery.trim().isNotEmpty;

  List<String> _collectGroups(List<BookSource> sources) {
    final groups = <String>{};
    for (final source in sources) {
      final group = (source.bookSourceGroup ?? '').trim();
      if (group.isNotEmpty) {
        groups.add(group);
      }
    }
    return groups.toList(growable: false);
  }

  List<BookSource> _filterSources(List<BookSource> sources) {
    final query = _searchQuery.trim();
    if (query.isEmpty) {
      return sources;
    }

    final lowerQuery = query.toLowerCase();
    String? groupFilter;
    String? textFilter;

    if (lowerQuery.startsWith('group:')) {
      groupFilter = query.substring(6).trim();
    } else {
      textFilter = query;
    }

    return sources.where((source) {
      final group = (source.bookSourceGroup ?? '').trim();
      final name = (source.bookSourceName ?? '').trim();
      final url = (source.bookSourceUrl ?? '').trim();

      final matchesGroup = groupFilter == null ||
          group.toLowerCase().contains(groupFilter.toLowerCase());
      final matchesText = textFilter == null ||
          name.toLowerCase().contains(textFilter.toLowerCase()) ||
          group.toLowerCase().contains(textFilter.toLowerCase()) ||
          url.toLowerCase().contains(textFilter.toLowerCase());

      return matchesGroup && matchesText;
    }).toList(growable: false);
  }

  void _showExplore(BookSource source) {
    final accessToken = context.read<UserProvider>().token;
    if (accessToken == null) return;

    _showExploreCategories(source, accessToken);
  }

  Future<void> _showExploreCategories(
    BookSource source,
    String accessToken,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ApiService.instance.getBookSourcesExploreUrl(
        accessToken,
        source.bookSourceUrl ?? '',
      );
      if (result['isSuccess'] != true) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('获取发现分类失败')),
        );
        return;
      }

      final data = result['data'];
      final foundRaw = data?['found'];
      final categories = _parseCategories(foundRaw);

      if (categories.isEmpty) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('该书源没有发现页')),
        );
        return;
      }

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.56,
          minChildSize: 0.32,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, controller) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        source.bookSourceName ?? '发现',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return Material(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        title: Text(categories[index].key),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.pop(context);
                          _navigateToExplore(
                            source,
                            categories[index].value,
                            categories[index].key,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('加载失败: $e')),
      );
    }
  }

  List<MapEntry<String, String>> _parseCategories(dynamic foundRaw) {
    if (foundRaw == null) return [];

    if (foundRaw is List) {
      return foundRaw.whereType<Map>().map((e) {
        final title = (e['title'] ?? e['name'] ?? '').toString();
        final url = (e['url'] ?? '').toString();
        return MapEntry(title, url.isNotEmpty ? url : title);
      }).toList();
    }

    final found = foundRaw.toString().trim();
    if (found.isEmpty) return [];

    if (found.startsWith('[')) {
      try {
        final list = jsonDecode(found) as List;
        return list.whereType<Map>().map((e) {
          final title = (e['title'] ?? e['name'] ?? '').toString();
          final url = (e['url'] ?? '').toString();
          return MapEntry(title, url.isNotEmpty ? url : title);
        }).toList();
      } catch (_) {}
    }

    return found
        .split(RegExp(r'(&&|\n)+'))
        .map((e) {
          final parts = e.split('::');
          return MapEntry(
            parts.isNotEmpty ? parts[0].trim() : '',
            parts.length > 1
                ? parts[1].trim()
                : (parts.isNotEmpty ? parts[0].trim() : ''),
          );
        })
        .where((e) => e.key.isNotEmpty)
        .toList();
  }

  void _navigateToExplore(BookSource source, String url, String title) {
    Navigator.pushNamed(
      context,
      AppRoutes.discoverExplore,
      arguments: ExploreBooksPageArgs(
        title: title,
        sourceName: source.bookSourceName ?? '',
        sourceUrl: source.bookSourceUrl ?? '',
        exploreUrl: url,
      ),
    );
  }
}

class _DiscoverSourceTile extends StatelessWidget {
  final BookSource source;
  final VoidCallback onTap;

  const _DiscoverSourceTile({
    required this.source,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (source.bookSourceName ?? '').trim();
    final group = (source.bookSourceGroup ?? '').trim();
    final accentColor = _accentFromSource(name.isNotEmpty ? name : group);
    final surfaceColor = Color.alphaBlend(
      accentColor.withValues(alpha: 0.12),
      theme.cardColor,
    );

    return Material(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isNotEmpty ? name.characters.first : '源',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (group.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        group,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color
                              ?.withValues(alpha: 0.66),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _accentFromSource(String seed) {
    const palette = [
      Color(0xFFE85D3F),
      Color(0xFF4B8BFF),
      Color(0xFF35A97A),
      Color(0xFFF0A53A),
      Color(0xFF8B63F6),
      Color(0xFFE05C92),
    ];
    if (seed.isEmpty) {
      return palette.first;
    }
    return palette[seed.codeUnits.fold<int>(0, (sum, unit) => sum + unit) %
        palette.length];
  }
}
