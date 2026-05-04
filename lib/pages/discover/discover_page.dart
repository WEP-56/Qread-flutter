import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/discover_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/book_source.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({Key? key}) : super(key: key);

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSources());
  }

  void _loadSources() {
    final token = context.read<UserProvider>().token;
    if (token != null) {
      context.read<DiscoverProvider>().loadExploreSources(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('发现'),
        actions: [
          IconButton(
            icon: const Icon(Icons.source),
            onPressed: () => Navigator.pushNamed(context, '/sourceManage'),
          ),
        ],
      ),
      body: Consumer<DiscoverProvider>(
        builder: (context, provider, _) {
          if (provider.loading && provider.exploreSources.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.exploreSources.isEmpty) {
            return const Center(child: Text('暂无发现源，请先导入书源'));
          }

          final groups = <String, List<BookSource>>{};
          for (final source in provider.exploreSources) {
            final group = source.bookSourceGroup ?? '未分组';
            groups.putIfAbsent(group, () => []).add(source);
          }

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups.keys.elementAt(index);
              final sources = groups[group]!;
              return ExpansionTile(
                title: Text(group),
                initiallyExpanded: index == 0,
                children: sources.map((source) {
                  return ListTile(
                    title: Text(source.bookSourceName ?? ''),
                    subtitle: Text(source.bookSourceUrl ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showExplore(source),
                  );
                }).toList(),
              );
            },
          );
        },
      ),
    );
  }

  void _showExplore(BookSource source) {
    final exploreUrl = source.exploreUrl;
    if (exploreUrl == null || exploreUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该书源没有发现页')),
      );
      return;
    }

    final categories = exploreUrl.split('&&').map((e) {
      final parts = e.split('::');
      return MapEntry(parts.isNotEmpty ? parts[0] : '', parts.length > 1 ? parts[1] : parts[0]);
    }).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(source.bookSourceName ?? '发现', style: Theme.of(context).textTheme.titleLarge),
            ),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(categories[index].key),
                    onTap: () {
                      Navigator.pop(context);
                      _navigateToExplore(source, categories[index].value, categories[index].key);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToExplore(BookSource source, String url, String title) {
    // TODO: 导航到发现详情页
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('打开发现: $title')),
    );
  }
}
