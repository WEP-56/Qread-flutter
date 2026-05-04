import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isLoggedIn = context.watch<UserProvider>().isLoggedIn;
    if (isLoggedIn && !_dataLoaded) {
      _dataLoaded = true;
      _loadSources();
    } else if (!isLoggedIn) {
      _dataLoaded = false;
    }
  }

  void _loadSources() {
    final token = context.read<UserProvider>().token;
    if (token != null) {
      context.read<RssProvider>().loadSources(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('订阅'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.pushNamed(context, '/rssSource'),
          ),
        ],
      ),
      body: Consumer2<UserProvider, RssProvider>(
        builder: (context, userProvider, provider, _) {
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
                  ElevatedButton(onPressed: _loadSources, child: const Text('重试')),
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

          final groups = <String, List<dynamic>>{};
          for (final source in provider.sources) {
            final group = source.sourceGroup ?? '未分组';
            groups.putIfAbsent(group, () => []).add(source);
          }

          return RefreshIndicator(
            onRefresh: () async {
              _dataLoaded = false;
              _loadSources();
            },
            child: ListView(
              children: groups.entries.map((entry) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        entry.key,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.8,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: entry.value.length,
                      itemBuilder: (context, index) {
                        return RssSourceCard(source: entry.value[index]);
                      },
                    ),
                  ],
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}
